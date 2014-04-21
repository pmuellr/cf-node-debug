# Licensed under the Apache License. See footer for details.

path = require "path"

_    = require "underscore"
nopt = require "nopt"

cfProxy = require "./cf-debug-proxy"
utils   = require "./utils"

cli = exports

#-------------------------------------------------------------------------------
cli.main = (args) ->
    help() if args.length is 0
    help() if args[0] in ["?", "-?", "--?"]

    opts =
        break:     [ "b", Boolean ]
        websocket: [ "w", String,  "__debug__" ]
        verbose:   [ "v", Boolean,  ]
        help:      [ "h", Boolean ]

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

    cfProxy.run args, opts

    return

#-------------------------------------------------------------------------------
help = ->
    console.log """
        #{utils.PROGRAM} [options] -- commmand

            command      is the node command line to start your application

        options:

            -b --break       break at start of program (default: false)
            -w --websocket   websocket url to expose   (default: "__debug__")
            -v --verbose     be verbose

        This program does the following:

        - starts the specified application
          - it's PORT environment variable will be changed to port PORT+1
          - it will be launched with the appropriate node debug option

        - starts a proxy server on the PORT environment variable

        - sends non-debug traffic (ie, not prefixed by --websocket option) to
          the specified application

        - sends debug traffic (ie, prefixed by --websocket option) to the
          v8 debug port (5858)

        example:

            #{utils.PROGRAM} -b -w debug -- node server.js

        This will run the command `node server.js` under debug and pause at
        the first line of the app.

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
