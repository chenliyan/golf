-module(websocker_server).
-export([start/0, start/1]).

start() ->
	start(8889).
	
start(Port) ->
	{ok, Listen} = gen_tcp:listen(Port, [{packet,raw}, {reuseaddr,true}, {active, true}]),
	accept(Listen).
	
accept(Listen) ->
	{ok, Socket} = gen_tcp:accept(Listen),
	Pid = spawn(fun()-> ws_establish(Socket)  end),
	gen_tcp:controlling_process(Socket, Pid),
	accept(Listen).
	
ws_establish(Socket) ->
	receive
		{tcp, Socket, Data} ->
		Key = list_to_binary(lists:last(string:tokens(hd(lists:filter(fun(S) -> lists:prefix("Sec-WebSocket-Key:", S) end, string:tokens(Data, "\r\n"))), ": "))),
		Challenge = base64:encode(crypto:sha(<< Key/binary, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" >>)),
		Handshake =
            ["HTTP/1.1 101 Switching Protocols\r\n",
             "connection: Upgrade\r\n",
             "upgrade: websocket\r\n",
             "sec-websocket-accept: ", Challenge, "\r\n",
             "\r\n",<<>>],
		gen_tcp:send(Socket, Handshake);
	_Any ->
		ws_establish(Socket)
	end.
	