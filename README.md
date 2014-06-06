cf-node-debug - a node debugger for Cloud Foundry
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



authentication
--------------------------------------------------------------------------------

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

Cloud Foundry users should use a user-provided service to set the
authentication parameters.  To do this, you need to create a user-provided
service whose name has `cf-node-debug` in it somewhere, and has one
property `auth`, whose value will be the same as described above.  You
should then bind this service to all apps that you want to debug.

example:

Run this command to create a service named `cf-node-debug`:

    cf cups cf-node-debug -p auth

You will be prompted for value of the `auth` property; enter something like

    local:joeuser:dumbsecret

You should then see a message that service got created.

You can then bind the service to your app with the following command:

    cf bind-service my-app cf-node-debug



assumptions
--------------------------------------------------------------------------------

The main assumption is that your program is running on CloudFoundry, and thus
determines the HTTP port it will be using based on the `PORT` environment
variable.

In addition, it's assumed that you won't be using the path specified by
the `--debug-prefix` option in your application, as these URLs will be
redirected to the debugger.



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

icon composed from:

* https://github.com/voodootikigod/logo.js/
* http://commons.wikimedia.org/wiki/File:Bedbug_(PSF).png
