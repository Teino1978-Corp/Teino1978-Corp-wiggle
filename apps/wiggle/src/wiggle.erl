-module(wiggle).

-export([start/0]).

-ignore_xref([start/0]).

start() ->
    application:start(mdns_client_lib),
    application:start(libsnarlmatch),
    application:start(libsnarl),
    application:start(libsniffle),
    application:start(jsx),
    application:start(lager),
    application:start(mimetypes),
    application:start(cowboy),
    application:start(wiggle).

