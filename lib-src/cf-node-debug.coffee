# Licensed under the Apache License. See footer for details.

fs            = require "fs"
path          = require "path"
crypto        = require "crypto"
stream        = require "stream"
child_process = require "child_process"

q              = require "q"
_              = require "underscore"
http           = require "http"
cfenv          = require "cfenv"
express        = require "express"
passport       = require "passport"
httpProxy      = require "http-proxy"
bodyParser     = require "body-parser"
handlebars     = require "handlebars"
clientSessions = require "client-sessions"

auth  = require "./auth"
utils = require "./utils"

DebuggerIndexHTML         = path.join __dirname, "..", "web-debugger", "index.html"
DebuggerIndexHTML         = fs.readFileSync DebuggerIndexHTML, "utf8"
DebuggerIndexHTMLTemplate = handlebars.compile DebuggerIndexHTML

#-------------------------------------------------------------------------------
appEnv = cfenv.getAppEnv()

PORT_PROXY  = appEnv.port
PORT_TARGET = appEnv.port + 1
PORT_DEBUG  = appEnv.port + 2
PORT_V8     = 5858

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

ClientSessions = null

#-------------------------------------------------------------------------------
exports.run = (args, opts) ->
  opts.break       = !! opts.break
  opts.verbose     = !! opts.verbose
  opts.debugPrefix = "--debugger" unless opts.debugPrefix?

  match = opts.debugPrefix.match /\/*(.*)\/*/
  opts.debugPrefix = "/#{match[1]}"

  utils.vlog "version: #{utils.VERSION}"
  utils.vlog "args:    #{args.join ' '}"
  utils.vlog "opts:    #{utils.JL opts}"

  # get auth

  service = appEnv.getService /cf-node-debug/

  cliAuth = opts.auth
  envAuth = process.env.CF_NODE_DEBUG_AUTH
  svcAuth = service?.credentials?.auth

  svrAuthString = cliAuth || envAuth || svcAuth || "local::"
  svrAuth       = auth.parseAuthSpec svrAuthString

  notAccessible = "debugger won't be accessible"

  if not svrAuth?
    utils.log "unable to parse auth `#{svrAuthString}`; #{notAccessible}"
  else if svrAuth.type isnt "local"
    utils.log "invalid auth type for `#{svrAuthString}`: `#{svrAuth.type}`; #{notAccessible}"
  else if svrAuth.userid is ""
    utils.log "empty userid for `#{svrAuthString}`; #{notAccessible}"
  else if svrAuth.password is ""
    utils.log "empty password for `#{svrAuthString}`; #{notAccessible}"
  else
    auth.setUser
      userid:   svrAuth.userid
      password: svrAuth.password

  password = svrAuth?.password
  password = "crap" unless password?
  password = "crap" if password is ""

  sessionOptions =
    cookieName:  "cf-node-debug"
    requestKey:  "session"
    secret:      password
    duration:    1000 * 60 * 60 * 24 * 7 * 2 # 2 weeks
    cookie:
      path:      "#{opts.debugPrefix}/"
      ephemeral: false
      httpOnly:  true
      secure:    false

  ClientSessions = clientSessions sessionOptions

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
    args.unshift "--debug-brk=" + opts.v8Port
  else
    args.unshift "--debug=" + opts.v8Port

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
  nodeInspector = require.resolve("node-inspector")
  nodeInspector = path.join nodeInspector, "..", "..", ".bin", "node-inspector"
  nodeInspector = path.relative process.cwd(), nodeInspector

  args = [nodeInspector, "--web-port=#{PORT_DEBUG}"]

  stdio =  ["ignore", "pipe", "pipe"]

  options = {stdio}

  utils.log "#{PRE_D} starting `node #{args.join ' '}`"
  child = child_process.spawn "node", args, options

  class FilterStream extends stream.Transform
    constructor: (options) ->
      super

    _transform: (chunk, enc, cb) ->
      s = chunk.toString("utf8")
      s = s.replace /Visit .* to start debugging\.\n/, ""
      s = new Buffer(s, "utf8")
      @push s, enc
      cb()

  filterStream = new FilterStream()
  child.stdout.pipe(filterStream).pipe(process.stdout)
  child.stderr.pipe(process.stderr)

  child.on "error", (err)  -> utils.log "#{PRE_D} exception: #{err}"
  child.on "exit",  (code) -> utils.log "#{PRE_D} exited with code: #{code}"

  return child

#-------------------------------------------------------------------------------
startProxy = (opts) ->
  debugPrefix      = opts.debugPrefix
  debugPrefixSlash = "#{debugPrefix}/"

  ProxyTarget.on "error", (err, request, response) ->
    utils.log "#{PRE_P} target exception: #{err}"

    socket = request
    if response.writeHead?
      response.writeHead 500, "Content-Type": "text/plain"
      response.end "error processing request; check server console."
    else if socket.close?
      socket.close()

  ProxyDebug.on "error", (err, request, response) ->
    utils.log "#{PRE_P} debug exception: #{err}"

    socket = request
    if response.writeHead?
      response.writeHead 500, "Content-Type": "text/plain"
      response.end "error processing request; check server console."
    else if socket.close?
      socket.close()

  #-----------------------------------------------------------------------------
  bowerPath = path.join __dirname, "..", "bower"
  debugPath = path.join __dirname, "..", "web-debugger", "cf-node-debug"

  debugApp = express.Router()
  debugApp.use ClientSessions
  debugApp.use bodyParser()
  debugApp.use passport.initialize()
  debugApp.use setIsAuthenticated
  debugApp.use "/bower",         express.static bowerPath
  debugApp.use "/cf-node-debug", express.static debugPath

  debugApp.get "/", (request, response) ->

    unless request.originalUrl.match /.*\/$/
      response.redirect debugPrefixSlash
      return

    message = request.session.message
    if message? and message.length
      messageShow = ""
    else
      messageShow = "hidden"

    request.session.message = ""

    data =
      userid:      request.session.userid || "[not logged in]"
      message:     message
      messageShow: messageShow
      loggedOut:   ""
      loggedIn:    ""

    if request.isAuthenticated
      data.loggedOut = "hidden"

    else
      data.loggedIn  = "hidden"

    indexHTML = DebuggerIndexHTMLTemplate data

    response.send indexHTML

  debugApp.get  "/login",  (request, response, next) ->
    response.redirect debugPrefixSlash

  debugApp.post "/login",  (request, response, next) ->
    authr = passport.authenticate "local", (err, user, info) ->
      if err?
        request.session.message = err.message
        return response.redirect debugPrefixSlash

      unless user
        request.session.message = info.message
        return response.redirect debugPrefixSlash

      request.session.userid   = user.userid
      request.session.password = user.password

      response.redirect debugPrefixSlash

    authr request, response, next

  debugApp.post "/logout", (request, response) ->
    request.session.userid   = ""
    request.session.password = ""

    response.redirect debugPrefixSlash

  debugApp.get  "/logout", (request, response, next) ->
    response.redirect debugPrefixSlash

  debugApp.use (request, response, next) ->
    return next() if request.isAuthenticated

    response.redirect debugPrefixSlash

  debugApp.use ProxyDebug.web.bind ProxyDebug

  #-----------------------------------------------------------------------------
  proxyApp = express()

  proxyApp.use debugPrefix, debugApp
  proxyApp.use ProxyTarget.web.bind ProxyTarget

  #-----------------------------------------------------------------------------
  proxyServer = http.createServer proxyApp

  proxyServer.on "upgrade", (request, socket, head) ->
    [empty, root, rest...] = request.url.split path.sep

    unless "/#{root}" is debugPrefix
      ProxyTarget.ws request, socket, head
      return

    ClientSessions request, {}, ->
      setIsAuthenticated request, {}, ->
        return socket.destroy() unless request.isAuthenticated

        ProxyDebug.ws request, socket, head

  utils.log "#{PRE_P} starting server at: #{appEnv.url}"
  utils.log "#{PRE_P} access debugger at: #{appEnv.url}#{debugPrefix}/inspector.html"

  proxyServer.listen PORT_PROXY

#-------------------------------------------------------------------------------
setIsAuthenticated = (request, response, next) ->
  {userid, password} = request.session
  user = auth.getUser()

  request.isAuthenticated = false

  if (userid is user.userid) and (password is user.password)
    request.isAuthenticated = true

  next()

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
