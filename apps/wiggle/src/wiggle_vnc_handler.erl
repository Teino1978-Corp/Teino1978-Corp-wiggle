-module(wiggle_vnc_handler).
-behaviour(cowboy_http_handler).
-behaviour(cowboy_http_websocket_handler).
-export([init/3, handle/2, terminate/2]).
-export([websocket_init/3, websocket_handle/3,
         websocket_info/3, websocket_terminate/3]).

init({_Any, http}, Req, []) ->
    case cowboy_http_req:header('Upgrade', Req) of
        {undefined, Req2} -> {ok, Req2, undefined};
        {<<"websocket">>, _Req2} -> {upgrade, protocol, cowboy_http_websocket};
        {<<"WebSocket">>, _Req2} -> {upgrade, protocol, cowboy_http_websocket}
    end.

handle(Req, State) ->
    io:format("~p~n", [Req]),
    {ok, Req1} =  cowboy_http_req:reply(200, [], <<"">>, Req),
    {ok, Req1, State}.

terminate(_Req, _State) ->
    ok.

websocket_init(_Any, Req, []) ->
    {[<<"api">>, '_', <<"vms">>, ID, <<"vnc">>], Req1} = cowboy_http_req:path(Req),
    {ok, Req2} = cowboy_http_req:set_resp_header(
                   <<"Access-Control-Allow-Headers">>,
                   <<"X-Snarl-Token">>, Req1),
    {ok, Req3} = cowboy_http_req:set_resp_header(
                   <<"Access-Control-Expose-Headers">>,
                   <<"X-Snarl-Token">>, Req2),
    {ok, Req4} = cowboy_http_req:set_resp_header(
                   <<"Allow-Access-Control-Credentials">>,
                   <<"true">>, Req3),
    {Token, Req5} = case cowboy_http_req:header(<<"X-Snarl-Token">>, Req4) of
                        {undefined, ReqX} ->
                            {TokenX, ReqX1} = cowboy_http_req:cookie(<<"X-Snarl-Token">>, ReqX),
                            {TokenX, ReqX1};
                        {TokenX, ReqX} ->
                            {ok, ReqX1} = cowboy_http_req:set_resp_header(<<"X-Snarl-Token">>, TokenX, ReqX),
                            {TokenX, ReqX1}
                    end,
    case libsnarl:allowed({token, Token}, [<<"vms">>, ID, <<"console">>]) of
        true ->
            case libsniffle:vm_attribute_get(ID, <<"info">>) of
                {ok, Info} ->
                    Host = proplists:get_value(<<"vnc-host">>, Info),
                    Port = proplists:get_value(<<"vnc-port">>, Info),
                    case gen_tcp:connect(binary_to_list(Host), Port,
                                         [binary,{nodelay, true}, {packet, 0}]) of
                        {ok, Socket} ->
                            gen_tcp:controlling_process(Socket, self()),
                            Req6 = cowboy_http_req:compact(Req5),
                            {ok, Req6, {Socket}, hibernate};
                        _ ->
                            Req6 = cowboy_http_req:compact(Req5),
                            {ok, Req6, undefined, hibernate}
                    end;
                E ->
                    {ok, Req6} = cowboy_http_req:reply(505, [{'Content-Type', <<"text/html">>}],
                                                       list_to_binary(io_lib:format("~p", E)), Req5),
                    {shutdown, Req6}
            end;
        false ->
            {ok, Req6} = cowboy_http_req:reply(401, [{'Content-Type', <<"text/html">>}], <<"">>, Req5),
            {shutdown, Req6}
    end.

websocket_handle({text, Msg}, Req, {Socket} = State) ->
    gen_tcp:send(Socket, base64:decode(Msg)),
    {ok, Req, State};

websocket_handle(_Any, Req, State) ->
    {ok, Req, State}.

websocket_info({tcp,_Socket,Data}, Req, State) ->
    {reply, {text, base64:encode(Data)}, Req, State};

websocket_info(_Info, Req, State) ->
    {ok, Req, State, hibernate}.

websocket_terminate(_Reason, _Req, {Socket} = _State) ->
    Socket ! {ws, closed},
    gen_tcp:close(Socket),
    ok.