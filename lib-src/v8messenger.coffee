# Licensed under the Apache License. See footer for details.

#-------------------------------------------------------------------------------
# friendly API to interact with the V8 debugger
#
# for message objects to send and receive, see:
#     https://code.google.com/p/v8/wiki/DebuggerProtocol
#-------------------------------------------------------------------------------

net    = require "net"
events = require "events"

q = require "q"

utils = require "./utils"

#-------------------------------------------------------------------------------
exports.create = (port) ->
  return new V8Messenger port

#-------------------------------------------------------------------------------
# Communicate with the V8 debugger via messages.
#
# Instances of this class are event emitters.
#
# events emitted:
#    v8-event (v8 event packet) - a packet from the v8 debugger
#    close    (null)            - the v8 debugger connection closed
#    error    (Error)           - an error occurred somewhere
#-------------------------------------------------------------------------------
class V8Messenger extends events.EventEmitter

  #---------------------------------------------------------------------------
  # create a new messenger for a V8 debugger running at the specified port
  #---------------------------------------------------------------------------
  constructor: (port) ->
    @_deferred = {}
    @_seq = 1
    @_initMessage()

    @_socket = net.connect port

    @_socket.setEncoding "utf8"

    @_socket.on "connect", =>
      utils.vlog "connected to v8 debugger"

    @_socket.on "data", (data) => @_onData data

    @_socket.on "error", (err) => @emit "error", err

    @_socket.on "close", =>
      utils.vlog "disconnected from v8 debugger"
      @emit "close"

  #---------------------------------------------------------------------------
  # close the debugger connection
  #---------------------------------------------------------------------------
  close: ->
    return unless @_socket?

    @_socket.end()
    @_socket.destroy()
    @_socket = null

  #---------------------------------------------------------------------------
  # Send a V8 request packet, return a promise on the response packet.
  # The packet `type` and `seq` properties will be set for you.
  #---------------------------------------------------------------------------
  send: (packet) ->
    return unless @_socket?

    packet.type = "request"
    packet.seq   = @_seq++

    @_deferreds[packet.seq] = q.defer()

    packetString = JSON.stringify packet
    packetString = "Content-Length: #{packetString.length}\r\n\r\n#{packetString}"

    @_socket.write packetString, "utf8"

    return @_deferreds[packet.seq].promise

  #---------------------------------------------------------------------------
  _onMessage: (body) ->
    msg = JSON.parse body

    if msg.type is "event"
      @emit "v8-event", msg
      return

    deferred = @_deferreds[msg.request_seq]
    return unless deferred?

    delete @_deferreds[msg.request_seq]

    if msg.success
      deferred.resolve msg
      return

    err = new Error msg.message
    err.isV8 = true
    deferred.reject err

  #---------------------------------------------------------------------------
  _onData: (data) ->
    return unless @_socket?

    @buffer += data

    while true

        # reading the body
        if !@inHeaders

          # if we don"t have enough content, return
          return if @buffer.length < @contentLength

          # got enough content, emit message, start over
          body    = @buffer.substr 0, @contentLength
          @buffer = @buffer.substr @contentLength

          @_onMessage body
          @_initMessage()

          continue

        # reading headers
        delim = @buffer.indexOf "\r\n"

        # dangling header, return
        if -1 == delim
          return

        # split line
        line    = @buffer.substr line, delim
        @buffer = @buffer.substr delim + 2

        # empty line, now reading body so start over
        if line == ""
          @inHeaders = false
          continue

        # header line, split it
        delim = line.indexOf ":"
        if -1 == delim
          key = line
          val = ""
        else
          key = (line.substr 0, delim).trim()
          val = (line.substr delim + 1).trim()

        # set the header, and check for Content-Length
        @headers[key] = val

        if key == "Content-Length"
          @contentLength = parseInt val, 10

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
