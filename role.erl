-module(role).
-export([init/1]).
init(From) ->
	login(From).
login(From) ->
	From ! {self(), data, "pls login"},
	receive
		{From, data, <<"login",End/binary>>} ->
			From ! {self(), data, "login success."},
			ets:new(cer_agr, [set, named_table]),
			ets:new(agr_cer, [set, named_table]),
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
			ets:insert(agr_cer, {AgrId, CerId, Name}),
			ets:insert(cer_agr, {CerId, AgrId}),
			spawn(agr, cims, [self(), CerId, Name]),			
			From ! {self(), data, <<"resp,",AgrId/binary,",checking...">>},
			loop(From);
		{role, CerId, Ret} ->
			[{_, AgrId}] = ets:take(cer_agr, CerId),
			[{_, _, Name}] = ets:take(agr_cer, AgrId),
			case Ret of
				cer_id_null ->
					From ! {self(), data, <<"resp,", AgrId/binary, ",cer_id_null">>};
				cer_id_dismatch ->
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
			loop(From);
		{From, data, Unknown} ->
			io:format("role.get~w~n", [Unknown]),
			loop(From);
		_Any ->
			io:format("role.unknown:~p~n", _Any)
	end.
cims() ->
	ok.
	