-module(role).
-export([init/1]).
init(From) ->
	login(From).
login(From) ->
	From ! {self(), data, "Enter username and password."},
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
			Alldata = query_all(),
			From ! {self(), data, Alldata},
			loop(From);
		{From, data, <<"query:", CerId:18/binary>>} ->
			loop(From);
		{From, data, <<"upload:",CerId:18/binary, Name/binary>>} ->
			Ret = insert(),
			From ! {self(), data, Ret},
			loop(From);
		{From, data, Unknown} ->
			io:format("role.unknon~w~n", [Unknown]),
			loop(From)
	end.
query_all() ->
	agr:query().
	
insert() ->
	io:format("role.insert~n"),
	"insert good".
	