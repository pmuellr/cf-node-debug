# Licensed under the Apache License. See footer for details.

#-------------------------------------------------------------------------------
# use this file with jbuild: https://www.npmjs.org/package/jbuild
# install jbuild with:
#    linux/mac: sudo npm -g install jbuild
#    windows:        npm -g install jbuild
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
tasks = defineTasks exports,
  watch: "watch for source file changes, then run build, test and server"
  serve: "run the test server stand-alone"
  build: "build the server"
  test:  "run tests"

WatchSpec = """
  lib-src/      lib-src/**/*
  tests/        tests/**/*
  web-debugger/ web-debugger/**/*
  """

PidFile   = "tmp/server.pid"

#-------------------------------------------------------------------------------
mkdir "-p", "tmp"

#-------------------------------------------------------------------------------
tasks.build = ->
  log "running build"

  unless test "-d", "node_modules"
    exec "npm install"

    log ""
    log "---------------------------------------"
    log "exiting jbuild because of `npm install`"
    log "---------------------------------------"

    process.exit 1

  unless test "-d", "bower_components"
    exec "bower install jquery#2.1"
    exec "bower install bootstrap#3.1"
    rm "-rf", "bower"

  unless test "-d", "bower"
    bc = "bower_components/bootstrap/dist"
    br = "bower/bootstrap"

    mkdir "-p", "#{br}/css"
    mkdir "-p", "#{br}/fonts"
    mkdir "-p", "#{br}/js"

    cp "#{bc}/css/bootstrap-theme.min.css", "#{br}/css"
    cp "#{bc}/css/bootstrap-theme.css.map", "#{br}/css"
    cp "#{bc}/css/bootstrap.min.css",       "#{br}/css"
    cp "#{bc}/css/bootstrap.css.map",       "#{br}/css"
    cp "#{bc}/fonts/*",                     "#{br}/fonts"
    cp "#{bc}/js/bootstrap.min.js",         "#{br}/js"

    bc = "bower_components/jquery/dist"
    br = "bower/jquery"

    mkdir "-p", "#{br}"
    cp "#{bc}/jquery.min.js",  "#{br}"
    cp "#{bc}/jquery.min.map", "#{br}"

  cleanDir "lib"

  log "- compiling server coffee files"
  coffee "--output lib lib-src"

#-------------------------------------------------------------------------------
tasks.watch = ->
  watchIter()

  watch
    files: WatchSpec.split /\s+/
    run:   watchIter

  watchFiles "jbuild.coffee" :->
    log "jbuild file changed; exiting"
    process.exit 0

#-------------------------------------------------------------------------------
tasks.serve = ->
  serveDelayed()

#-------------------------------------------------------------------------------
serveDelayed = ->
  log "running server"

  args = "bin/cf-node-debug.js --break --auth local:foo:bar -- tests/server.js"
  args = args.split(/\s+/)

  server.start PidFile, "node", args

#-------------------------------------------------------------------------------
tasks.test = ->
  log "running tests"

  tests = "tests/test-*.coffee"

  options =
    ui:         "bdd"
    reporter:   "spec"
    slow:       300
    compilers:  "coffee:coffee-script"
    require:    "coffee-script/register"

  options = for key, val of options
    "--#{key} #{val}"

  options = options.join " "

  mocha "#{options} #{tests}", silent:true, (code, output) ->
    console.log "test results:\n#{output}"

#-------------------------------------------------------------------------------
watchIter = ->
  tasks.build()
  tasks.test()
  tasks.serve()

#-------------------------------------------------------------------------------
cleanDir = (dir) ->
  mkdir "-p", dir
  rm "-rf", "#{dir}/*"

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
