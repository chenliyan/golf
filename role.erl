-module(role).
-export([init/1]).
-include_lib("stdlib/include/qlc.hrl"). 

init(H) ->
	login(H).
login(H) ->
	receive
		{H, data, <<"login",Who/binary>>} ->
			%%io:format("role.create.ets.[~p]~n", [self()]),
			H ! {self(), data, "login success."},
			CerAgr = ets:new(cer_agr, [set]),
			AgrCer = ets:new(agr_cer, [set]),
			loop(H, Who, AgrCer, CerAgr);
		{H, data, <<"admin", _/binary>>} ->
			H ! {self(), data, "admin mode"},
			admin(H);
		{H, data, Number} ->
			H ! {self(), data, Number},
			login(H);
		{H, close} ->
			%%io:format("role.notlogined.gohome.[~p]~n", [self()]),
			ok;
		_Any ->
			io:format("role.unrecog~p ~p~n", [self(), _Any])		
	end.
loop(H, W, A, C) ->
	receive
		{H, close} ->
			%%io:format("role.gohome[~p]~n", [self()]),
			ok;
		{H, data, <<Method:5/binary,":", BinPeport/binary>>} ->
			Tokens = string:tokens(binary_to_list(BinPeport), ","),
			case length(Tokens) of
				4 ->
					loop_check_req(H, W, A, C, Method, Tokens);
				_ ->
					H ! {self(), data, "info: error."},
					loop(H, W, A, C)
			end;
		{H, data, Unknown} ->
			io:format("role.get~w~n", [Unknown]),
			loop(H, W, A, C);
		{agr, Cer, Ret} ->
			loop_check_res(H, W, A, C, Cer, Ret);
		_Any ->
			io:format("role.unknown:~p~n", [_Any])
	end.
	
loop_check_req(H, W, A, C, Method, Report) ->
	[Ssn, Cer, Name, Addr] = Report,
	Ret = ets:lookup(A, Ssn) ++ ets:lookup(C, Cer),
	io:format("que.~p~n", [Ret]),
	case  Ret of
		[] ->
			io:format("ins,~p ~p~n", [Ssn, Cer]),
			ets:insert(A, {Ssn, Method, Cer, Name, Addr}),
			ets:insert(C, {Cer, Ssn}),
			spawn(agr, cims, [self(), Cer, Name]);
		_ ->
			ok
	end,
	loop(H, W, A, C).
	
loop_check_res(H, W, A, C, Cer, Ret) ->
	io:format("tak, ~p~n", [Cer]),
	[{_, Ssn}] = ets:take(C, Cer),
	io:format("ssn ~p~n", [Ssn]),
	[{_, Method, _, Name, Addr}] = ets:take(A, Ssn),
	if
		Ret == cer_noexist ->
			%%io:format("branch 1~n"),
			H ! {self(), data, "resp," ++ Ssn ++ ",cer.noexist"},
			loop(H, W, A, C);
		Ret == cer_dismatch ->
			H ! {self(), data, "resp," ++ Ssn ++ ",cer.nomatch"};			
		Method == <<"check">> ->
			H ! {self(), data, "resp," ++ Ssn ++ ",cer check ok"},
			loop(H, W, A, C);
		Method == <<"apply">> ->
			loop_apply(H, W, A, C, Ssn, Cer, Name, Addr);
		Method == <<"reapp">> ->
			loop_reapp(H, W, A, C, Ssn, Cer, Name, Addr);
		true ->
			%%io:format("unknown method~n"),
			loop(H, W, A, C)
	end.

loop_apply(H, W, A, C, Ssn, Cer, Name,Addr) ->
	{atomic, Ret} = agr:apply(Ssn, Cer, Name, Addr, [], []),
	case Ret of
		existed ->
			Out = "existed";
		ok ->
			Out = "app ok"
	end,
	H ! {self(), data, "resp," ++ Ssn ++"," ++ Out},
	loop(H, W, A, C).
	
loop_reapp(H, W, A, C, Ssn, Cer, Name, Addr) ->
	{atomic, Ret} = agr:reapply(Ssn, Cer, Name, Addr, [], []),
	case Ret of
		noexist ->
			Out = "noexist";
		card_empty ->
			Out = "card_empty";
		ok ->
			Out = "app ok"
	end,
	H ! {self(), data, "resp," ++ Ssn ++ "," ++ Out},
	loop(H, W, A, C).
	
admin(H) ->
	receive
		{H, data, <<"query">>} ->			
			Ret = agr:query(),
			[H ! {self(), data, <<"rest,", AgrId/binary, ",", CerId/binary, ",", Name/binary>> } || [AgrId, CerId, Name] <- Ret],
			admin(H);
		{H, data, _Any} ->
			%%io:format("ill~p~n", [_Any]),
			H ! {self(), data, <<"illeageal data">>},
			admin(H)
	end.
