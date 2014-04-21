// Licensed under the Apache License. See footer for details.

var http = require("http")

var cfEnv = require("cf-env")

var cfCore = cfEnv.getCore()

var server = http.createServer(cbHandleRequest)

log("starting at url: " + cfCore.url)
server.listen(cfCore.port, cfCore.bind, cbListening)

//------------------------------------------------------------------------------
function cbHandleRequest(request, response) {
	log("request for " + request.url)
  response.writeHead(200, {"Content-Type": "text/plain"})
  response.end("you requested " + request.url)
}

//------------------------------------------------------------------------------
function cbListening(request, response) {
	log("server started  at url: " + cfCore.url)
}

//------------------------------------------------------------------------------
function log(message) {
	console.log("app server: " + message)
}

/*
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
*/