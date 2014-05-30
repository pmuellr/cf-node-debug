# Licensed under the Apache License. See footer for details.

path          = require "path"
child_process = require "child_process"

q          = require "q"
_          = require "underscore"
http       = require "http"
cfenv      = require "cfenv"
httpProxy  = require "http-proxy"
websocket  = require "websocket"

utils       = require "./utils"

#-------------------------------------------------------------------------------
appEnv = cfenv.getAppEnv()

PORT_PROXY  = appEnv.port
PORT_TARGET = appEnv.port + 1
PORT_DEBUG  = appEnv.port + 2
PORT_V8     = 5858

URL_TARGET  = "http://localhost:#{PORT_TARGET}"
URL_DEBUG   = "http://localhost:#{PORT_DEBUG}"

ProxyTarget = new httpProxy.createProxyServer
  target:
    host: "localhost"
    port: PORT_TARGET

ProxyDebug = new httpProxy.createProxyServer
  target:
    host: "localhost"
    port: PORT_DEBUG

PRE_T = "target:"
PRE_D = "debug: "
PRE_P = "proxy:"

#-------------------------------------------------------------------------------
exports.run = (args, opts) ->
  utils.vlog "version: #{utils.VERSION}"
  utils.vlog "args:    #{args.join ' '}"
  utils.vlog "opts:    #{utils.JL opts}"

  target = startTarget args, opts
  debugr = startDebugger opts
  startProxy opts

  process.on "exit", (code) ->
    utils.log "#{PRE_P} exiting; code: #{code}"
    kill "target",   target
    kill "debugger", debugr

#-------------------------------------------------------------------------------
kill = (label, proc) ->
  try
    utils.log "killing #{label}"
    proc.kill()
  catch e
    utils.log "killing #{label}; exception: #{e}"

#-------------------------------------------------------------------------------
startTarget = (args, opts) ->
  args = args.trim().split /\s+/ if _.isString args
  args.shift() if args[0] is "node"

  if opts.break
    args.unshift "--debug-brk"
  else
    args.unshift "--debug"

  env = _.clone process.env
  env.PORT          = PORT_TARGET
  env.VCAP_APP_PORT = PORT_TARGET

  stdio =  ["ignore", "pipe", "pipe"]

  options = {env, stdio}

  utils.log "#{PRE_T} starting `node #{args.join ' '}`"
  child = child_process.spawn "node", args, options

  child.stdout.pipe(process.stdout)
  child.stderr.pipe(process.stderr)

  child.on "error", (err)  -> utils.log "#{PRE_T} exception: #{err}"
  child.on "exit",  (code) -> utils.log "#{PRE_T} exited with code: #{code}"

  return child

#-------------------------------------------------------------------------------
startDebugger = (opts) ->
  args = ["node_modules/.bin/node-inspector", "--web-port=#{PORT_DEBUG}"]

  stdio =  ["ignore", "pipe", "pipe"]

  options = {stdio}

  utils.log "#{PRE_D} starting `node #{args.join ' '}`"
  child = child_process.spawn "node", args, options

  child.stdout.pipe(process.stdout)
  child.stderr.pipe(process.stderr)

  child.on "error", (err)  -> utils.log "#{PRE_D} exception: #{err}"
  child.on "exit",  (code) -> utils.log "#{PRE_D} exited with code: #{code}"

  return child

#-------------------------------------------------------------------------------
startProxy = (opts) ->
  debugPrefix = opts["debug-prefix"]

  ProxyTarget.on "error", (err, request, response) ->
    utils.log "#{PRE_P} target exception: #{err}"
    response.writeHead 500, "Content-Type": "text/plain"
    response.end "error processing request; check server console."

  ProxyDebug.on "error", (err, request, response) ->
    utils.log "#{PRE_P} debug exception: #{err}"
    response.writeHead 500, "Content-Type": "text/plain"
    response.end "error processing request; check server console."

  proxyServer = http.createServer (request, response) ->
    [empty, root, rest...] = request.url.split path.sep

    if root is debugPrefix
      request.url = "/#{rest.join '/'}"
      ProxyDebug.web request, response
    else
      ProxyTarget.web request, response

  proxyServer.on "upgrade", (request, socket, head) ->
    [empty, root, rest...] = request.url.split path.sep

    if root is debugPrefix
      request.url = "/#{rest.join '/'}"
      ProxyDebug.ws request, socket, head
    else
      ProxyTarget.ws request, socket, head


  utils.log "#{PRE_P} starting server at: #{appEnv.url}"
  utils.log "#{PRE_P} access debugger at: #{appEnv.url}/#{debugPrefix}/inspector.html"

  proxyServer.listen PORT_PROXY

#-------------------------------------------------------------------------------
# Copyright IBM Corp. 2014
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#-------------------------------------------------------------------------------
