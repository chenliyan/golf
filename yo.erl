-module(yo).
-export([start/3, service/3]).
start(SessionId, Env, Input) ->
	io:format("start is called").
	
service(SessionId, Env, Input) ->
	
	mod_esi:deliver(SessionId, [
  "Content-Type: text/html\r\n\r\n", 
  "start\n"
 ]),
 file:write_file("receive", Input),
 [_|T2] = string:tokens(Input, "\r\n\r\n\r\n"),
 [_|T3] = T2,
 [_|T4] = T3,
	mod_esi:deliver(SessionId, [
  T4
 ]),
 
	mod_esi:deliver(SessionId, [
  "Content-Type: text/html\r\n\r\n", 
  "end\n"
 ]).
 
upload(SessionId, Env, Input) ->
	ok.