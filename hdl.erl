-module(hdl).
-export([ws_establish/1]).

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
			Pid = spawn_link(role, init, [self()]),
			io:format("ws.spawn.role[~w]~n", [Pid]),
			inet:setopts(Socket, [{active, once}]),
			loop(Socket, Pid, <<>>);
		_Any ->
			io:format("ws.abnormal~n"),
			ws_establish(Socket)
	end.
loop(S, P, Acc) ->
	receive
		{tcp, S, Data} ->
			io:format("."),
			Bin = list_to_binary(Data),
			loop_parse(S, P, <<Acc/binary, Bin/binary>>);
		{tcp_closed, S} ->
			P ! {self(), close},
			io:format("ws.gohome~n");
		{P, data, Text} ->
			send_data(S, Text),
			loop(S, P, Acc);
		_Any ->
			io:format("ws.unrecog~w~n", [_Any]),
			loop(S, P, Acc)
	end.
loop_parse(S, P, Head) when byte_size(Head) < 5 ->
	%%io:format("len[~p], next round~n", [byte_size(Head)]),
	loop(S, P, Head);
loop_parse(S, P, Head) ->
	io:format("len->[~p]~n", [byte_size(Head)]),
	<<F:1, 0:3, 1:4, 1:1, Len:7, ExtRest/bits>> = Head,
	case Len of
		126 ->
			<<AllLen:16, MaskRest/bits>> = ExtRest;
		127 ->
			<<AllLen:64, MaskRest/bits>> = ExtRest;
		_   ->
			AllLen = Len,
			MaskRest = ExtRest
	end,
	%%io:format("wslen[~p]~n", [Len]),
	<<MaskKey:32, Rest/bits>> = MaskRest,
	ActLen = iolist_size(Rest),
	if 
		AllLen > ActLen ->
			inet:setopts(S, [{active,once}]),
			loop(S, P, Head);
		true ->
			inet:setopts(S, [{active,once}]),
			<<Pay:AllLen/binary, NextHead/binary >> = Rest,
			Text = websocket_unmask(Pay, MaskKey, <<>>),
			P ! {self(), data, Text},
			loop_parse(S, P, NextHead)
	end.

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