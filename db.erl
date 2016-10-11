-module(db).
-export([start/0]).
-record(person, {name,
                 age = 0,
                 address = unknown,
                 salary = 0,
                 children = []}).
-record(agr_info, {agr_id, cer_id, name, card_id,status,  county, inst, time}).
-record(cer_info, (cer_id, name, status, time}).
start() ->
	mnesia:create_table(person,
    [{ram_copies, [node()]},
     {attributes, record_info(fields, person)}]),
	Trans = fun() ->
		Person = #person{name = "damiao", age = 30},
		mnesia:write(Person)
	end,
	mnesia:transaction(Trans).
	
read() ->
	mnesia:read()
	 