%% Feel free to use, reuse and abuse the code in this file.

%% @doc Hello world handler.
-module(wiggle_network_handler).
-include("wiggle.hrl").

-define(CACHE, network).
-define(LIST_CACHE, network_list).

-export([allowed_methods/3,
         get/1,
         permission_required/1,
         read/2,
         create/3,
         write/3,
         delete/2]).

-ignore_xref([allowed_methods/3,
              get/1,
              permission_required/1,
              read/2,
              create/3,
              write/3,
              delete/2]).

allowed_methods(_Version, _Token, [_Network, <<"metadata">>|_]) ->
    [<<"PUT">>, <<"DELETE">>];

allowed_methods(_Version, _Token, [_Network, <<"ipranges">>, _]) ->
    [<<"PUT">>, <<"DELETE">>];

allowed_methods(_Version, _Token, []) ->
    [<<"GET">>, <<"POST">>];

allowed_methods(_Version, _Token, [_Network]) ->
    [<<"GET">>, <<"PUT">>, <<"DELETE">>].

get(State = #state{path = [Network | _]}) ->
    Start = now(),
    R = case application:get_env(wiggle, network_ttl) of
            {ok, {TTL1, TTL2}} ->
                wiggle_handler:timeout_cache_with_invalid(
                  ?CACHE, Network, TTL1, TTL2, not_found,
                  fun() -> libsniffle:network_get(Network) end);
            _ ->
                libsniffle:network_get(Network)
        end,
    ?MSniffle(?P(State), Start),
    R.

permission_required(#state{method = <<"GET">>, path = []}) ->
    {ok, [<<"cloud">>, <<"networks">>, <<"list">>]};

permission_required(#state{method = <<"POST">>, path = []}) ->
    {ok, [<<"cloud">>, <<"networks">>, <<"create">>]};

permission_required(#state{method = <<"GET">>, path = [Network]}) ->
    {ok, [<<"networks">>, Network, <<"get">>]};

permission_required(#state{method = <<"DELETE">>, path = [Network]}) ->
    {ok, [<<"networks">>, Network, <<"delete">>]};

permission_required(#state{method = <<"PUT">>, path = [_Network]}) ->
    {ok, [<<"cloud">>, <<"networks">>, <<"create">>]};

permission_required(#state{method = <<"PUT">>,
                           path = [Network, <<"ipranges">>,  _]}) ->
    {ok, [<<"networks">>, Network, <<"edit">>]};

permission_required(#state{method = <<"DELETE">>,
                           path = [Network, <<"ipranges">>, _]}) ->
    {ok, [<<"networks">>, Network, <<"edit">>]};

permission_required(#state{method = <<"PUT">>,
                           path = [Network, <<"metadata">> | _]}) ->
    {ok, [<<"networks">>, Network, <<"edit">>]};

permission_required(#state{method = <<"DELETE">>,
                           path = [Network, <<"metadata">> | _]}) ->
    {ok, [<<"networks">>, Network, <<"edit">>]};

permission_required(_State) ->
    undefined.

%%--------------------------------------------------------------------
%% GET
%%--------------------------------------------------------------------

read(Req, State = #state{token = Token, path = [], full_list=FullList, full_list_fields=Filter}) ->
    Start = now(),
    {ok, Permissions} = wiggle_handler:get_persmissions(Token),
    ?MSnarl(?P(State), Start),
    Start1 = now(),
    Permission = [{must, 'allowed',
                   [<<"networks">>, {<<"res">>, <<"uuid">>}, <<"get">>],
                   Permissions}],
    Fun = wiggle_handler:list_fn(fun libsniffle:network_list/2, Permission,
                                 FullList, Filter),
    Res1 = case application:get_env(wiggle, network_list_ttl) of
               {ok, {TTL1, TTL2}} ->
                   wiggle_handler:timeout_cache(
                     ?LIST_CACHE, {Token, FullList, Filter}, TTL1, TTL2, Fun);
               _ ->
                   Fun()
           end,
    ?MSniffle(?P(State), Start1),
    {Res1, Req, State};

read(Req, State = #state{path = [_Network], obj = Obj}) ->
    {Obj, Req, State}.

%%--------------------------------------------------------------------
%% PUT
%%--------------------------------------------------------------------

create(Req, State = #state{path = [], version = Version}, Data) ->
    {ok, Network} = jsxd:get(<<"name">>, Data),
    Start = now(),
    case libsniffle:network_create(Network) of
        {ok, UUID} ->
            ?MSniffle(?P(State), Start),
            e2qc:teardown(?LIST_CACHE),
            {{true, <<"/api/", Version/binary, "/networks/", UUID/binary>>}, Req, State#state{body = Data}};
        duplicate ->
            ?MSniffle(?P(State), Start),
            {ok, Req1} = cowboy_req:reply(409, Req),
            {halt, Req1, State}
    end.

write(Req, State = #state{
                      path = [Network, <<"ipranges">>, IPrange]}, _Data) ->
    Start = now(),
    e2qc:evict(?CACHE, Network),
    case libsniffle:network_add_iprange(Network, IPrange) of
        ok ->
            ?MSniffle(?P(State), Start),
            {true, Req, State};
        _ ->
            ?MSniffle(?P(State), Start),
            {false, Req, State}
    end;

write(Req, State = #state{method = <<"POST">>, path = []}, _) ->
    {true, Req, State};

write(Req, State = #state{path = [Network, <<"metadata">> | Path]}, [{K, V}]) ->
    Start = now(),
    e2qc:evict(?CACHE, Network),
    e2qc:teardown(?LIST_CACHE),
    libsniffle:network_set(Network, Path ++ [K], jsxd:from_list(V)),
    ?MSniffle(?P(State), Start),
    {true, Req, State};

write(Req, State, _Body) ->
    {false, Req, State}.

%%--------------------------------------------------------------------
%% DEETE
%%--------------------------------------------------------------------

delete(Req, State = #state{path = [Network, <<"metadata">> | Path]}) ->
    Start = now(),
    e2qc:evict(?CACHE, Network),
    e2qc:teardown(?LIST_CACHE),
    libsniffle:network_set(Network, Path, delete),
    ?MSniffle(?P(State), Start),
    {true, Req, State};

delete(Req, State = #state{path = [Network, <<"ipranges">>, IPRange]}) ->
    Start = now(),
    e2qc:evict(?CACHE, Network),
    e2qc:teardown(?LIST_CACHE),
    libsniffle:network_remove_iprange(Network, IPRange),
    ?MSniffle(?P(State), Start),
    {true, Req, State};

delete(Req, State = #state{path = [Network]}) ->
    Start = now(),
    e2qc:evict(?CACHE, Network),
    e2qc:teardown(?LIST_CACHE),
    ok = libsniffle:network_delete(Network),
    ?MSniffle(?P(State), Start),
    {true, Req, State}.
