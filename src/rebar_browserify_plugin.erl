%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et
%% -------------------------------------------------------------------
%%
%% rebar: Erlang Build Tools
%%
%% Copyright (c) 2012 Christopher Meiklejohn (cmeiklejohn@basho.com)
%% Copyright (c) 2015 Alex Wilson (alex@cooperi.net)
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% -------------------------------------------------------------------

%% The rebar_browserify_plugin module is a plugin for rebar that combines
%% javascript files using browserify.
%%
%% Configuration options should be placed in rebar.config under
%% 'browserify'.  Available options include:
%%
%%  src_dir: where to find javascript files to compile
%%            "js_src" by default
%%
%%  out_dir: where to put compressed javascript files
%%           "priv/js" by default
%%
%%  entry_files: entry point files to run through browserify
%%
%%  options: extra options to pass directly to browserify
%%
%% The default settings are the equivalent of:
%%   {browserify, [
%%               {src_dir, "js_src"},
%%               {out_dir, "priv/js"},
%%               {options, []}
%%              ]}.
%%
%% An example of compressing a series of javascript files:
%%
%%   {browserify, [
%%      {src_dir, "js_src"},
%%      {out_dir, "priv/js"},
%%      {entry_files, ["app.js"]}
%%   ]}.
%%

-module(rebar_browserify_plugin).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([compile/2, clean/2]).

-export([browserify/3]).

%% ===================================================================
%% Public API
%% ===================================================================
-spec compile(rebar_config:config(), _) -> ok.
compile(Config, _AppFile) ->
    Options = options(Config),
    OutDir = option(out_dir, Options),
    SrcDir = option(src_dir, Options),
    Entries = option(entry_files, Options),
    ExtOpts = option(options, Options),
    Targets = [{normalize_path(Ent, OutDir),
                normalize_path(Ent, SrcDir)}
               || Ent <- Entries],
    browserify_each(Targets, ExtOpts).

-spec clean(rebar_config:config(), _) -> ok.
clean(Config, _AppFile) ->
    Options = options(Config),
    OutDir = option(out_dir, Options),
    Compressions = option(entry_files, Options),
    Targets = [normalize_path(Ent, OutDir)
               || Ent <- Compressions],
    delete_each(Targets).

-spec browserify(string(), string(), [{atom(), string()}]) -> ok.
browserify(Source, Destination, Options) ->
    case needs_update(Source, Destination) of
        true ->
            Cmd = lists:flatten(["browserify ", string:join([[$',O,$'] || O <- Options], " "), " '", Source, "' -o '", Destination, $']),
            ShOpts = [{use_stdout, false}, return_on_error],
            case rebar_utils:sh(Cmd, ShOpts) of
                {ok, _} ->
                    io:format("Browserified ~s to ~s~n", [Source, Destination]);
                {error, Reason} ->
                    rebar_log:log(error, "Browserifying asset ~s failed:~n  ~p~n",
                           [Source, Reason]),
                    _ = file:delete(Destination),
                    rebar_utils:abort()
            end;
        false ->
            ok
    end.

%% ===================================================================
%% Internal functions
%% ===================================================================

options(Config) ->
    rebar_config:get_local(Config, browserify, []).

option(Option, Options) ->
    proplists:get_value(Option, Options, default(Option)).

default(src_dir) -> "js_src";
default(out_dir)  -> "priv/js";
default(options) -> [];
default(entry_files) -> [].

normalize_path(Path, Basedir) -> filename:join([Basedir, Path]).

needs_update(Source, Destination) ->
    filelib:last_modified(Destination) < filelib:last_modified(Source).

delete_each([]) ->
    ok;
delete_each([First | Rest]) ->
    case file:delete(First) of
        ok ->
            ok;
        {error, enoent} ->
            ok;
        {error, Reason} ->
            rebar_log:log(error, "Failed to delete ~s: ~p\n", [First, Reason])
    end,
    delete_each(Rest).

browserify_each([], _Options) ->
    ok;
browserify_each([{Destination, Source} | Rest], Options) ->
    browserify(Source, Destination, Options),
    browserify_each(Rest, Options).

