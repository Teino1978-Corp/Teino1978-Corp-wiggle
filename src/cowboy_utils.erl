%%%-------------------------------------------------------------------
%%% @author Heinz N. Gies <>
%%% @copyright (C) 2012, Heinz N. Gies
%%% @doc
%%%
%%% @end
%%% Created : 20 Apr 2012 by Heinz N. Gies <>
%%%-------------------------------------------------------------------
-module(cowboy_utils).

%% API
-export([set_path/2]).

-include("http.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

set_path(Req, Path) ->
    Req#http_req{path = Path}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
