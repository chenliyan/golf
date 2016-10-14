-module(role).
-export([init/1]).
init(From) ->
	login(From).
login(From) ->
	From ! {self(), data, "pls login"},
	receive
		{From, data, <<"login",User/binary>>} ->
			io:format("role.create.ets.[~p]~n", [self()]),
			From ! {self(), data, "login success."},
			CerAgr = ets:new(cer_agr, [set]),
			AgrCer = ets:new(agr_cer, [set]),
			loop(From, AgrCer, CerAgr);
		{From, data, _} ->
			login(From);
		{From, close} ->
			io:format("role.notlogined.gohome.[~p]~n", [self()]),
			ok;
		_Any ->
			io:format("role.gohome.[~p]~n", [self()]),
			io:format("role.unrecog~w~n", [_Any])		
	end.
loop(From, AgrCer,CerAgr) ->
	receive
		{From, close} ->
			io:format("role.gohome[~p]~n", [self()]),
			ok;
		{From, data, <<"query:", CerId:18/binary>>} ->
			loop(From, AgrCer,CerAgr);
		{From, data, <<"upload:",AgrId:13/binary,",",CerId:18/binary, ",", Name/binary>>} ->
			ets:insert(AgrCer, {AgrId, CerId, Name}),
			ets:insert(CerAgr, {CerId, AgrId}),
			spawn(agr, cims, [self(), CerId, Name]),			
			From ! {self(), data, <<"resp,",AgrId/binary,",checking...">>},
			loop(From, AgrCer,CerAgr);
		{role, CerId, Ret} ->
			[{_, AgrId}] = ets:take(CerAgr, CerId),
			[{_, _, Name}] = ets:take(AgrCer, AgrId),
			case Ret of
				cer_null ->
					From ! {self(), data, <<"resp,", AgrId/binary, ",cer_id_null">>};
				cer_dismatch ->
					From ! {self(), data, <<"resp,", AgrId/binary, ",cer_id_dismatch">>};					
				cer_ok ->
					From ! {self(), data, <<"resp,", AgrId/binary, ",cer_ok">>},
					case agr:upload(AgrId, CerId, Name) of
						ok ->
							From ! {self(), data, <<"resp,", AgrId/binary, ",uploaded">>};
						existed ->
							From ! {self(), data, <<"resp,", AgrId/binary, ",already existed">>}
					end
			end,
			loop(From, AgrCer,CerAgr);
		{From, data, Unknown} ->
			io:format("role.get~w~n", [Unknown]),
			loop(From, AgrCer,CerAgr);
		_Any ->
			io:format("role.gohome[~p]~n", [self()]),
			io:format("role.unknown:~p~n", [_Any])
	end.
cims() ->
	ok.
	