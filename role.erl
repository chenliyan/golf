-module(role).
-export([init/1]).
init(From) ->
	login(From).
login(From) ->
	From ! {self(), data, "pls login"},
	receive
		{From, data, <<"login",End/binary>>} ->
			From ! {self(), data, "login success."},
			loop(From);
		{From, data, _} ->
			login(From);
		{From, close} ->
			ok;
		_Any ->
			io:format("role.unrecog~w~n", [_Any])		
	end.
loop(From) ->
	receive
		{From, data, <<"query">>} ->
			Alldata = agr:query(),
			From ! {self(), data, Alldata},
			loop(From);
		{From, data, <<"query:", CerId:18/binary>>} ->
			loop(From);
		{From, data, <<"upload:",AgrId:13/binary,",",CerId:18/binary, ",", Name/binary>>} ->
			Ret = agr:upload(AgrId, CerId, Name),
			From ! {self(), data, <<"resp,",AgrId/binary,",good">>},
			loop(From);
		{From, data, Unknown} ->
			io:format("role.unknon~w~n", [Unknown]),
			loop(From)
	end.
	

	