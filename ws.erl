-module(ws).
-export([start/1]).

start(Port) ->
	spawn(fun() -> start(Port, 1) end).
	
start(Port,Ver) ->
	io:format("ws ~w start~n", [Ver]),
	{ok, Listen} = gen_tcp:listen(Port, [{packet,raw}, {reuseaddr,true}, {active, once}]),
	accept(Listen).
	
accept(Listen) ->
	{ok, Socket} = gen_tcp:accept(Listen),
	Pid = spawn(hdl, ws_establish, [Socket]),
	gen_tcp:controlling_process(Socket, Pid),
	accept(Listen).
	
