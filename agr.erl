-module(agr).
-export([init/1, start/0, apply/6,reapply/6,query/0, query_on/3,cims/3, yo/0, update_card/3, update_status/2]).
-include_lib("stdlib/include/qlc.hrl"). 

-record(agr_info, {ssn, cer, name, addr, card, status, county, inst, time}).
-record(cer_info, {cer, name, status, time}).
start() ->
	mnesia:start(),
	mnesia:create_table(agr_info, [{disc_copies, [node()]}, {attributes, record_info(fields, agr_info)}]),
	mnesia:create_table(cer_info, [{disc_copies, [node()]}, {attributes, record_info(fields, cer_info)}]).
init(From) ->
	receive
		{From, data, <<CerId:18/binary, ",",Name/binary>>} ->
			io:format("agr ~s    ~s~n", [binary_to_list(CerId), binary_to_list(Name)]),
			From ! {self(), data, "get record"},
			init(From);
		{From, close} ->
			io:format("agr close ~n");
		_Any -> 
			io:format("zhe shi sha:~w~n", [_Any]),
			init(From),
			ok
	end.
apply(Ssn, Cer, Name, Addr, County, Inst) ->
%%ssn, cer, name, addr, card, status, county, inst, time
	Tmp = #agr_info{ssn = Ssn, 
					cer = Cer, 
					name = Name,
					addr = Addr,
					time = calendar:now_to_local_time(erlang:now())},	
	F = fun() ->
			Old = mnesia:read(agr_info, Ssn),
			case Old of 
				[] ->
					mnesia:write(Tmp),
					ok;
				_ ->
					existed
			end
		end,
	mnesia:transaction(F).
	

reapply(Ssn, Cer, Name, Addr, County, Inst) ->
	Tmp = #agr_info{ssn = Ssn, 
					cer = Cer, 
					name = Name,
					addr = Addr,
					
					time = calendar:now_to_local_time(erlang:now())},	
	F = fun() ->
			Old = mnesia:read(agr_info, Ssn),
			case Old of 
				[] ->
					noexist;
				_ ->
					[{agr_info, _, _, _, _, Card, _, _, _, _}] = Old,
					case Card of
						undefined ->
							card_empty;
						_ ->
							mnesia:write(Tmp),
							ok
					end
			end
		end,
	mnesia:transaction(F).
cims(MyPid, CerId, Name) ->
	Ret = 
	case mnesia:dirty_read(cer_info, CerId) of
		[] ->
			Cer = #cer_info{cer = CerId, 
			                name = Name, 
							status = <<"ok">>, 
							time = calendar:now_to_local_time(erlang:now())},	
			mnesia:dirty_write(Cer),
			cer_ok;
		[{cer_info, CerId, Name, Status, Time}] ->
			cer_ok;
		[{cer_info, CerId, _, Status, Time}] ->
			cer_dismatch			
	end,
	MyPid ! {agr, CerId, Ret}.
update_card(Ssn, Cer, Card) ->
	F = fun() ->
			Old = mnesia:read(agr_info, Ssn),
			case Old of
				[] ->
					noexist;
				[Tmp] ->
					case Tmp#agr_info.cer == Cer of
						true ->
							New = Tmp#agr_info{ssn = Ssn},
							mnesia:write(New),ok;
						false ->
							cer_dismatch
					end
			end
	    end,
	{_, Ret} = mnesia:transaction(F),
	Ret.
update_status(Ssn, Status) ->
	F = fun() ->
			Old = mnesia:read(agr_info, Ssn),
			case Old of
				[] ->
					noexist;
				[Tmp] ->
					case Tmp#agr_info.card == undefined
                      orelse Tmp#agr_info.card == fail	of
						false ->
							New = Tmp#agr_info{ssn = Ssn},
							mnesia:write(New),ok;
						true ->
							card_noexist
					end
			end
	    end,
	{_, Ret} = mnesia:transaction(F),
	Ret.
query(Ssn) ->
	F = fun() ->
		Q = qlc:q([[X#agr_info.ssn, 
		            X#agr_info.cer, 
					X#agr_info.name,
					X#agr_info.addr,
					X#agr_info.card] || X <- mnesia:table(agr_info), X#agr_info.ssn == Ssn]),
		qlc:e(Q)
	end,
	{_, Ret} = mnesia:transaction(F),
	Ret.

query() ->
	F = fun() ->
		Q = qlc:q([[X#agr_info.ssn, X#agr_info.cer, X#agr_info.card] || X <- mnesia:table(agr_info)]),
		QC = qlc:cursor(Q),
		Ret = qlc:next_answers(QC, 2),
		qlc:delete_cursor(QC),
		Ret
	end,
	mnesia:transaction(F).

query_on(County, Card, Status) ->
	Q = qlc:q([X || X <- mnesia:table(agr_info)]),
	case Card of
		card_empty ->
			Q2 = qlc:q([Y || Y <- Q, Y#agr_info.card == undefined]);
		fail ->
			Q2 = qlc:q([Y || Y <- Q, Y#agr_info.card == fail]);
		_  ->
			Q2 = qlc:q([Y || Y <- Q, Y#agr_info.card /= fail andalso Y#agr_info.card /= undefined])
	end,
	case Status of
		success ->
			Q3 = qlc:q([Z || Z <- Q2, Z#agr_info.status == success]);
		fail ->
			Q3 = qlc:q([Z || Z <- Q2, Z#agr_info.status == fail]);
		_ ->
			Q3 = Q2
	end,
	case County of
		[] ->
			Q4 = Q3;
		_ ->
			Q4 = qlc:q([W || W <- Q3, W#agr_info.county == County])
	end,
	
	Q5 = qlc:q([Y ||Y <- Q4]),
	F = fun() ->
		QC = qlc:cursor(Q5),
		Ret = qlc:next_answers(QC, 1000),
		qlc:delete_cursor(QC),
		Ret
	end,
	mnesia:transaction(F).
query(Tab, NotReady) ->
	lists:flatmap(  
		fun(Key) ->  
			[Result] = mnesia:dirty_read(Tab, Key),
			"rest," ++
			lists:flatmap(fun(C) ->
							case C of
								agr_info -> [];
								undefined -> [","];								
								_ -> [binary_to_list(C),","]
							end
			             end, tuple_to_list(Result)) ++ 
			"\n"
		end, mnesia:dirty_all_keys(Tab)).  
test() ->
	List = ["ABC"],
	lists:flatmap(fun(T,Acc) -> [T,"yo"|Acc] end, [], List).
delimeter(T, Acc) ->
	[T|Acc].
	
	
	
yo() ->
	
	mnesia:start(),
	
	mnesia:dirty_all_keys(cer_info).
	