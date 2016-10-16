-module(agr).
-export([init/1, start/0, upload/6,query/0,cims/3]).

-record(agr_info, {agr_id, cer_id, name, card_id,status,  county, inst, time}).
-record(cer_info, {cer_id, name, status, time}).
start() ->
	mnesia:start(),
	mnesia:create_table(agr_info, [{ram_copies, [node()]}, {attributes, record_info(fields, agr_info)}]),
	mnesia:create_table(cer_info, [{ram_copies, [node()]}, {attributes, record_info(fields, cer_info)}]).
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
	Tmp = #agr_info{agr_id = AgrId, cer_id = CerId, name = Name,
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
	query(agr_info).
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
	F = fun() ->

MatchHead = #agr_info{ _ = '_' },

Guard = [],

Result = ['$_'],

mnesia:select(y_account, [{MatchHead, Guard, Result}])

end,

mnesia:transaction(F).
	