-module(cam).
-export([start/0]).
start() ->
	Url = "http://www.vmall.com",
	file:write_file("body.html", "123"),

	PostHeaders = [	{"Accept","*/*"},
				{"Accept-Encoding","deflate, sdch, br"},
				{"Access-Control-Request-Headers","authorization, content-type"},
				{"Access-Control-Request-Method","POST"},
				{"Connection","keep-alive"},
				{"Host","zhihu-web-analytics.zhihu.com"},
				{"Original","null"},
				{"User-Agent","Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36"}
			  ],
	PostHeadersWithCookie = lists:append(PostHeaders, [httpc:cookie_header(Url)]),
	ssl:start(),
	inets:start(),
	httpc:set_options([{cookies, enabled}]),
	{ok, {Line, Headers, Body}}= httpc:request(get, {Url,PostHeadersWithCookie}, [{ssl,[]}],[]),
	file:write_file("header.txt", term_to_binary(Headers)),
	file:write_file("body.html", Body).

