-module(agr).
-export([init/0, start/0]).

-record(agr_info, {agr_id, cer_id, name, card_id,status,  county, inst, time}).
-record(cer_info, {cer_id, name, status, time}).
start() ->
	mnesia:create_table(agr_info, [{ram_copies, [node()]}, {attributes, record_info(fields, agr_info)}]),
	mnesia:create_table(cer_info, [{ram_copies, [node()]}, {attributes, record_info(fields, cer_info)}]).
init() ->
	receive
		{From, <<"upload", Data>>} ->
			Ret = upload_agr(Data),
			From ! Ret,
			init();
		{From, <<Other>>} ->
			io:format("un supported data ~s", Other),
			init();
		_Any -> 
			io:format("zhe shi sha");
			ok
	end.
upload_agr(Data) ->
	[Id, Name] = binary:split(<<Data>>,
	Person = #cer_info{cer_id = Id, name = Name},
	mnesia:dirty_write(agr_info, Person),
	"write_ok".