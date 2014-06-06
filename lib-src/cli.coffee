# Licensed under the Apache License. See footer for details.

path = require "path"

_    = require "underscore"
nopt = require "nopt"

cfNodeDebug = require "./cf-node-debug"
utils       = require "./utils"

cli = exports

#-------------------------------------------------------------------------------
cli.main = (args) ->
    help() if args.length is 0
    help() if args[0] in ["?", "-?", "--?"]

    opts =
        auth:           [ "a", String ]
        break:          [ "b", Boolean ]
        "debug-prefix": [ "d", String,  "--debugger" ]
        verbose:        [ "v", Boolean,  ]
        help:           [ "h", Boolean ]

    longOpts   = {}
    shortOpts  = {}
    defValues  = {}
    for name, opt of opts
        [shortName, type, defValue] = opt
        defValue = false if type is Boolean

        shortOpts[shortName] = "--#{name}"
        longOpts[name]       = type

        defValues[name] = defValue if defValue?

    parsed = nopt longOpts, shortOpts, args, 0

    help() if parsed.help

    args = parsed.argv.remain
    opts = _.pick parsed, _.keys longOpts
    opts = _.defaults opts, defValues

    help() if args.length is 0

    utils.verbose opts.verbose

    debugPrefix = opts["debug-prefix"].trim()
    if debugPrefix is ""
      utils.logError "the value of the --debug-prefix option must be a non-empty string"

    if debugPrefix.match /\/+/
      utils.logError "the value of the --debug-prefix option must not a slash"

    cfNodeDebug.run args, opts

#-------------------------------------------------------------------------------
help = ->
    console.log """
    usage:

        cf-node-debug [options] -- program arg arg ...

    `program arg arg ...` is what you would pass to `node` to start your program.

    options:

        -a --auth           authentication (see below)
        -d --debug-prefix   URL prefix of requests sent to the debugger
        -b --break          have the debugger pause at the beginning of the program
        -v --verbose        generate diagnostic messages

    The default debug-prefix is `--debugger`.

    Note that the `--` token is **REQUIRED** if your program or any arguments
    start with `-`.  Otherwise it's optional.

    This program does the following:

    - starts the specified node application with arguments
      - it's PORT environment variable will be changed to port PORT+1
      - it will be launched with the appropriate node debug option

    - starts node-inspector on PORT+2

    - starts a proxy server on the PORT environment variable

    - sends non-debug traffic (ie, not prefixed by `--debug-prefix` option) to
      the specified application

    - sends debug traffic (ie, prefixed by `--debug-prefix` option) to
      node-inspector

    example:

        cf-node-debug -- server.js

    authentication:

    When you use cf-node-debug, you need to specify authentication parameters
    to access the debugger.  This is to keep random internet people from accessing
    your application's innards via the debugger.

    You can specify the authentication parameters via the `-a` / `--auth` option,
    or via the `CF_NODE_DEBUG_AUTH` environment variable, or via a Cloud Foundry
    service.  In all cases, the authentication parameters are specified as
    a string of the form:

        scheme:parms

    Currently the only scheme supported is `local`, and the parms for this
    scheme are the userid and password separated by a `:`.  Thus, the
    authentication parameter of

        local:joeuser:dumbsecret

    indicates you should log in with the userid `joeuser` and password `dumbsecret`
    when prompted.
      
    version: #{utils.VERSION}; for more info: #{utils.HOMEPAGE}
    """

    process.exit 1

#-------------------------------------------------------------------------------
cli.main.call null, (process.argv.slice 2) if require.main is module

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
