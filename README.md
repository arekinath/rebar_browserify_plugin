# Rebar JS Browserify Plugin

Browserify your JavaScript files when building your Erlang OTP
application.

## Installation

Specify ```rebar_browserify_plugin``` as a dependency in your ```rebar.config```.

```erlang
{deps, [
       {rebar_browserify_plugin, ".*",
        {git, "git://github.com/arekinath/rebar_browserify_plugin", {branch, "master"}}}
]}.
```

Then, configure as a plugin in your ```rebar.config```.

```erlang
{plugins, [rebar_browserify_plugin]}.
```

## Configuration

In your ```rebar.config```.

```erlang
{browserify, [
    {src_dir,    "js_src"},
    {out_dir,    "priv/js"},
    {entry_files, [ "app.js" ]}
]}.
```
