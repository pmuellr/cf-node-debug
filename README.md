cf-node-debug - proxy requests to multiple servers based on url
================================================================================

The `cf-node-debug` package provides debugging capability for your node
applications while running on Cloud Foundry.  It launches two apps -
`node-inspector` and your application, and acts as an HTTP proxy.  It will
proxy *most* of the requests to your application, and debugger-specific
requests to `node-inspector`.



installation
================================================================================

    npm install cf-node-debug

Make sure you add `cf-node-debug` to your `package.json` as well.



usage
================================================================================

    cf-node-debug [options] -- commmand arg arg ...

`command arg arg ...` is the node command line to start your application

options:

    -d --debug-prefix   URL prefix of requests sent to the debugger
    -b --break          have the debugger pause at the beginning of the program
    -v --verbose        generate diagnostic messages

The default debug-prefix is `--debugger`.

Note that the `--` token is **REQUIRED** if your node command line
contains any arguments that start with `-`.  Otherwise it's optional.

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

    cf-node-debug -- node server.js

assumptions
--------------------------------------------------------------------------------

The main assumption is that your program is running on CloudFoundry, and thus
determines the HTTP port it will be using based on the `PORT` environment
variable.



quick start
================================================================================

Let's say you've developed a node application `node-stuff`, and you use the
cf start command `node node-stuff` to start your app.  

To debug this app:

* add a dependency of `cf-node-debug` to your `package.json` file

* change your start command to:

      node_modules/.bin/cf-node-debug node-stuff

* re-push your application



hacking
================================================================================

If you want to modify the source to play with it, you'll also want to have the
`jbuild` program installed.

To install `jbuild` on Windows, use the command

    npm -g install jbuild

To install `jbuild` on Mac or Linux, use the command

    sudo npm -g install jbuild

The `jbuild` command runs tasks defined in the `jbuild.coffee` file.  The
task you will most likely use is `watch`, which you can run with the
command:

    jbuild watch

When you run this command, the application will be built from source, the server
started, and tests run.  When you subsequently edit and then save one of the
source files, the application will be re-built, the server re-started, and the
tests re-run.  For ever.  Use Ctrl-C to exit the `jbuild watch` loop.

You can run those build, server, and test tasks separately.  Run `jbuild`
with no arguments to see what tasks are available, along with a short
description of them.



license
================================================================================

Apache License, Version 2.0

<http://www.apache.org/licenses/LICENSE-2.0.html>
