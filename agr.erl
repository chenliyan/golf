-module(agr).
-export([start/0]).
init() ->
	receive
		{From, upload, agr_info, AgrRecord} ->
			Ret = upload_agr(AgrRecord),
			From ! Ret,
			init();
		{From, query, cer_info, Person} ->
			query_cer(Person),
			init();
		_Any -> 
			ok
	end.
upload_agr(Person) ->
	Val = mnesia:dirty_read(agr_info, Person),
	case Val of 
	no_exist ->
		mnesia:dirty_write(agr_info, Person),
		{AgrId, _} = Person,
		to_string(AgrId,uploaded).
	exist ->
		existed.
	end.