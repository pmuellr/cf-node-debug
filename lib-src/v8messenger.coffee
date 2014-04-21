# Licensed under the Apache License. See footer for details.

net    = require "net"
events = require "events"

q = require "q"

utils  = require "../common/utils"

exports.create = (port) ->
  return new V8Messenger socket

#-------------------------------------------------------------------------------
# emits:
#    "event", V8 event message
#-------------------------------------------------------------------------------
class V8Messenger extends events.EventEmitter

  #---------------------------------------------------------------------------
  constructor: (socket) ->
    @_deferred = {}
    @_seq = 1
    @_initMessage()

    socket.on "data", (data) => @_onData data

  #---------------------------------------------------------------------------
  # send a V8 request message, return a promise on the response message
  #---------------------------------------------------------------------------
  send: (msg) ->
    msg.type = "request"
    msg.seq   = @_seq++

    @_deferreds[msg.seq] = q.defer()

    msgString = JSON.stringify msg
    msgString = "Content-Length: #{msgString.length}\r\n\r\n#{msgString}"

    socket.write msgString, "utf8"

    return @_deferreds[msg.seq].promise

  #---------------------------------------------------------------------------
  _initMessage: ->
    @inHeaders     = true
    @headers       = {}
    @buffer        = ""
    @contentLength = 0

  #---------------------------------------------------------------------------
  _onMessage: (body) ->
    msg = JSON.parse body

    if msg.type is "event"
      @emit "event", body

    else
      deferred = @_deferreds[msg.request_seq]
      return unless deferred?

      delete @_deferreds[msg.request_seq]

      if msg.success
        deferred.resolve msg
      else
        err = new Error msg.message
        err.isV8 = true
        deferred.reject err

  #---------------------------------------------------------------------------
  _onData: (data) ->
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
          key = utils.trim line.substr 0, delim
          val = utils.trim line.substr delim + 1

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
