%%%-------------------------------------------------------------------
%%% @author Heinz N. Gies <>
%%% @copyright (C) 2012, Heinz N. Gies
%%% @doc
%%%
%%% @end
%%% Created : 20 Apr 2012 by Heinz N. Gies <>
%%%-------------------------------------------------------------------
-module(wiggle).

%% API
-export([start/0]).

%%%===================================================================
%%% API
%%%===================================================================

start() ->
    application:start(crypto),
    application:start(public_key),
    application:start(ssl),
    application:start(lhttpc),
    application:start(erllibcloudapi),
    application:start(cowboy),
    application:start(wiggle).
    

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

%%%===================================================================
%%% Internal functions
%%%===================================================================
