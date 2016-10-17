-module(agr).
-export([init/1, start/0, upload/6,query/0,cims/3, yo/0]).
-include_lib("stdlib/include/qlc.hrl"). 

-record(test_info, {agr_id, cer_id, name, card_id,status,  inst, time}).
-record(agr_info, {agr_id, cer_id, name, card_id,status,  county, inst, time}).
-record(cer_info, {cer_id, name, status, time}).
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
upload(AgrId, CerId, Name, County, Inst, Option) ->
	io:format("before pack~n"),
	Tmp = #agr_info{agr_id = AgrId, 
					cer_id = CerId, 
					name = Name,
					card_id = [], status = [],  
					county = County, 
					inst = Inst, 
					time = calendar:now_to_local_time(erlang:now())},
	case Option of 
		<<"force">> ->
			mnesia:dirty_write(Tmp);
		_ ->
			upload(AgrId, Tmp)
	end.
upload(AgrId, Tmp) ->
	Ori = mnesia:dirty_read(agr_info, AgrId),
	case Ori of
		[] ->			
			mnesia:dirty_write(Tmp),
			ok;
		_ ->
			existed
	end.
cims(MyPid, CerId, Name) ->
	Ret = 
	case mnesia:dirty_read(cer_info, CerId) of
		[] ->
			Cer = #cer_info{cer_id = CerId, 
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
query() ->
	F = fun() ->
		Q = qlc:q([[X#agr_info.agr_id, X#agr_info.cer_id, X#agr_info.card_id] || X <- mnesia:table(agr_info), X#agr_info.card_id > []]),
		qlc:e(Q)
	end,
	{_, Ret} = mnesia:transaction(F),
	Ret.
query(Tab) ->
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
	