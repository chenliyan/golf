-module(role).
-export([init/1]).
init(Ws) ->
	login(Ws).
login(Ws) ->
	receive
		{Ws, data, <<"login",Who/binary>>} ->
			io:format("role.create.ets.[~p]~n", [self()]),
			Ws ! {self(), data, "login success."},
			CerAgr = ets:new(cer_agr, [set]),
			AgrCer = ets:new(agr_cer, [set]),
			loop(Ws, Who, AgrCer, CerAgr);
		{Ws, data, <<"admin", Admin/binary>>} ->
			admin(Ws);
		{Ws, data, Number} ->
			Ws ! {self(), data, Number},
			login(Ws);
		{Ws, close} ->
			io:format("role.notlogined.gohome.[~p]~n", [self()]),
			ok;
		_Any ->
			io:format("role.gohome.[~p]~n", [self()]),
			io:format("role.unrecog~w~n", [_Any])		
	end.
loop(Ws, Who, AgrCer, CerAgr) ->
	receive
		{Ws, close} ->
			io:format("role.gohome[~p]~n", [self()]),
			ok;
		{Ws, data, <<Method:5/binary, ":", AgrId:13/binary,",",CerId:18/binary, ",", Name/binary>>} ->
			io:format("Name is ~p~n", [Name]),
			case Method of
				<<"check">> ->
					loop_check_req(Ws, Who, AgrCer, CerAgr, Method, AgrId, CerId, Name);
				<<"uplod">> ->
					loop_check_req(Ws, Who, AgrCer, CerAgr, Method, AgrId, CerId, Name);
				_ ->
					Ws ! {self(), data, <<"unrecog methodd">>},
					loop(Ws, Who, AgrCer, CerAgr)					
			end;
		{Ws, data, Unknown} ->
			io:format("role.get~w~n", [Unknown]),
			loop(Ws, Who, AgrCer, CerAgr);
		{agr, CerId, Ret} ->
			loop_check_res(Ws, Who, AgrCer, CerAgr, CerId, Ret);
		_Any ->
			io:format("role.gohome[~p]~n", [self()]),
			io:format("role.unknown:~p~n", [_Any])
	end.
	
loop_check_req(Ws, Who, AgrCer, CerAgr, Method, AgrId, CerId, Name) ->
	io:format("insert, ~p, ~p~n", [AgrId, CerId]),
	ets:insert(AgrCer, {AgrId, Method, CerId, Name}),
	ets:insert(CerAgr, {CerId, AgrId}),
	spawn(agr, cims, [self(), CerId, Name]),
	loop(Ws, Who, AgrCer, CerAgr).
	
loop_check_res(Ws, Who, AgrCer, CerAgr, CerId, Ret) ->
	io:format("take, ~p~n",  [CerId]),
	[{_, AgrId}] = ets:take(CerAgr, CerId),
	io:format("take, ~p~n", [AgrId]),
	[{_, Method, _, Name}] = ets:take(AgrCer, AgrId),
	io:format("check.res.AgrId is ~p, Method is ~p, Name is omit~n", [AgrId, Method]),
	if
		Ret == cer_noexist ->
			io:format("branch 1~n"),
			Ws ! {self(), data, <<"resp:", AgrId/binary, "cer.nomatch">>},
			loop(Ws, Who, AgrCer, CerAgr);
		Method == <<"check">> ->
			Ws ! {self(), data, <<"resp:", AgrId/binary, "cer check ok">>},
			loop(Ws, Who, AgrCer, CerAgr);
		Method == <<"uplod">> ->
			io:format("branch 2~n"),
			loop_upload(Ws, Who, AgrCer, CerAgr, AgrId, CerId, Name, [], [], []);
		true ->
			io:format("branch 3~n"),
			loop(Ws, Who, AgrCer, CerAgr)
	end.

loop_upload(Ws, Who, AgrCer, CerAgr, AgrId, CerId, Name, County, Inst, Option) ->
	Ret = agr:upload(AgrId, CerId, Name, County, Inst, Option),
	Ws ! {self(), data, <<"resp:", AgrId/binary>>},
	loop(Ws, Who, AgrCer, CerAgr).
	
admin(Ws) ->
	receive
		{Ws, data, <<"q.rpt", Report/binary>>} ->
			Ws ! {self(), data, <<"report", Report/binary>>},
			admin(Ws);
		{Ws, data, _Any} ->
			admin(Ws)
	end.
