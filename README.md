node-cf-debug-proxy - proxy requests to multiple servers based on url
================================================================================

The `cf-debug-proxy` package provides debugging capability for your node
applications while running on Cloud Foundry.  It launches two apps -
`node-inspector` and your application, and acts as an HTTP proxy.  It will
proxy *most* of the requests to your application, and debugger-specific
requests to `node-inspector`.



installation
================================================================================

*eventually...*

    npm install cf-debug-proxy



usage
================================================================================

    cf-debug-proxy [options] program arg arg arg ...

`cf-debug-proxy` will run the specified program and the node-inspector debugger,
side-by-side, proxying debugger-specific HTTP requests to the debugger, and
everything else to the specified program.  It's assumed the program you are
running provides an HTTP server.

options
--------------------------------------------------------------------------------

    -d --debug-prefix   URL prefix of requests sent to the debugger
    -b --break          have the debugger pause at the beginning of the program
    -v --verbose        generate lots of diagnostic messages

The default value for `--debug-prefix` is `/--debugger`.

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

* add a dependency of `cf-debug-proxy` to your `package.json` file

* change your start command to:

      node_modules/.bin/cf-debug-proxy node-stuff

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
