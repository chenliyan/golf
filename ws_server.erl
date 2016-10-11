-module(ws_server).
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
		gen_tcp:send(Socket, Handshake),
		send_data(Socket, "here could send time"),
		Pid = spawn(fun() -> agr:init() end),
		loop(Socket, Pid);
	_Any ->
		ws_establish(Socket)
	end.
loop(Socket, Pid) ->
	receive
		{tcp, Socket, Data} ->
			Text = websocket_data(Data),
			send_data(Socket, "check"),
			Pid ! {self(), Data},
			io:format("server get data ~s", Data),
			loop(Socket, Pid);
		{error, closed} ->
			ok;
		{From, Ret} ->
			send_data(Socket, Ret),
			loop(Socket, Pid);
		_Any ->
			loop(Socket, Pid)
	end.
	
websocket_data(Data) when is_list(Data) ->
    websocket_data(list_to_binary(Data));
websocket_data(<< 1:1, 0:3, 1:4, 1:1, Len:7, MaskKey:32, Rest/bits >>) when Len < 126 ->
    <<End:Len/binary, _/bits>> = Rest,
    Text = websocket_unmask(End, MaskKey, <<>>),
    Text;
websocket_data(_) ->
    <<>>. 
websocket_unmask(<<>>, _, Unmasked) ->
    Unmasked;
websocket_unmask(<< O:32, Rest/bits >>, MaskKey, Acc) ->
    T = O bxor MaskKey,
    websocket_unmask(Rest, MaskKey, << Acc/binary, T:32 >>);
websocket_unmask(<< O:24 >>, MaskKey, Acc) ->
    << MaskKey2:24, _:8 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:24 >>;
websocket_unmask(<< O:16 >>, MaskKey, Acc) ->
    << MaskKey2:16, _:16 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:16 >>;
websocket_unmask(<< O:8 >>, MaskKey, Acc) ->
    << MaskKey2:8, _:24 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:8 >>.
	
send_data(Socket, Payload) ->
    Len = iolist_size(Payload),
    BinLen = payload_length_to_binary(Len),
    gen_tcp:send(Socket, [<< 1:1, 0:3, 1:4, 0:1, BinLen/bits >>, Payload]).

payload_length_to_binary(N) ->
    case N of
        N when N =< 125 -> << N:7 >>;
        N when N =< 16#ffff -> << 126:7, N:16 >>;
        N when N =< 16#7fffffffffffffff -> << 127:7, N:64 >>
    end.	