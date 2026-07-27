# JAVASCRIPT

JavaScript support in mpv is near identical to its Lua support. Use this section
as reference on differences and availability of APIs, but otherwise you should
refer to the Lua documentation for API details and general scripting in mpv.

## Example

JavaScript code which leaves fullscreen mode when the player is paused:

```
function on_pause_change(name, value) {
    if (value == true)
        mp.set_property("fullscreen", "no");
}
mp.observe_property("pause", "bool", on_pause_change);
```

## Similarities with Lua

mpv tries to load a script file as JavaScript if it has a `.js` extension, but
otherwise, the documented Lua options, script directories, loading, etc apply to
JavaScript files too.

Script initialization and lifecycle is the same as with Lua, and most of the Lua
functions in the modules `mp`, `mp.utils`, `mp.msg`, `mp.options` and
`mp.input` are available to JavaScript with identical APIs - including running
commands, getting/setting properties, registering events/key-bindings/hooks,
etc.

## Differences from Lua

No need to load modules. `mp`, `mp.utils`,  `mp.msg`, `mp.options` and
`mp.input` are preloaded, and you can use e.g. `var cwd =
mp.utils.getcwd();` without prior setup.

Errors are slightly different. Where the Lua APIs return `nil` for error,
the JavaScript ones return `undefined`. Where Lua returns `something, error`
JavaScript returns only `something` - and makes `error` available via
`mp.last_error()`. Note that only some of the functions have this additional
`error` value - typically the same ones which have it in Lua.

Standard APIs are preferred. For instance `setTimeout` and `JSON.stringify`
are available, but `mp.add_timeout` and `mp.utils.format_json` are not.

No standard library. This means that interaction with anything outside of mpv is
limited to the available APIs, typically via `mp.utils`. However, some file
functions were added, and CommonJS `require` is available too - where the
loaded modules have the same privileges as normal scripts.

## Language features - ECMAScript 5

The scripting backend which mpv currently uses is MuJS - a compatible minimal
ES5 interpreter. As such, `String.substring` is implemented for instance,
while the common but non-standard `String.substr` is not. Please consult the
MuJS pages on language features and platform support - [https://mujs.com](https://mujs.com) .

## Unsupported Lua APIs and their JS alternatives

`mp.add_timeout(seconds, fn)`  JS: `id = setTimeout(fn, ms)`

`mp.add_periodic_timer(seconds, fn)`  JS: `id = setInterval(fn, ms)`

`utils.parse_json(str [, trail])`  JS: `JSON.parse(str)`

`utils.format_json(v)`  JS: `JSON.stringify(v)`

`utils.to_string(v)`  see `dump` below.

`mp.get_next_timeout()` see event loop below.

`mp.dispatch_events([allow_wait])` see event loop below.

## Scripting APIs - identical to Lua

(LE) - Last-Error, indicates that `mp.last_error()` can be used after the
call to test for success (empty string) or failure (non empty reason string).
Where the Lua APIs use `nil` to indicate error, JS APIs use `undefined`.

`mp.command(string)` (LE)

`mp.commandv(arg1, arg2, ...)` (LE)

`mp.command_native(table [,def])` (LE)

`id = mp.command_native_async(table [,fn])` (LE) Notes: `id` is true-thy on
success, `error` is empty string on success.

`mp.abort_async_command(id)`

`mp.del_property(name)` (LE)

`mp.get_property(name [,def])` (LE)

`mp.get_property_osd(name [,def])` (LE)

`mp.get_property_bool(name [,def])` (LE)

`mp.get_property_number(name [,def])` (LE)

`mp.get_property_native(name [,def])` (LE)

`mp.set_property(name, value)` (LE)

`mp.set_property_bool(name, value)` (LE)

`mp.set_property_number(name, value)` (LE)

`mp.set_property_native(name, value)` (LE)

`mp.get_time()`

`mp.add_key_binding(key, name|fn [,fn [,flags]])`

`mp.add_forced_key_binding(...)`

`mp.remove_key_binding(name)`

`mp.register_event(name, fn)`

`mp.unregister_event(fn)`

`mp.observe_property(name, type, fn)`

`mp.unobserve_property(fn)`

`mp.get_opt(key)`

`mp.get_script_name()`

`mp.get_script_directory()`

`mp.osd_message(text [,duration])`

`mp.get_wakeup_pipe()`

`mp.register_idle(fn)`

`mp.unregister_idle(fn)`

`mp.enable_messages(level)`

`mp.register_script_message(name, fn)`

`mp.unregister_script_message(name)`

`mp.create_osd_overlay(format)`

`mp.get_osd_size()`  (returned object has properties: width, height, aspect)

`mp.msg.log(level, ...)`

`mp.msg.fatal(...)`

`mp.msg.error(...)`

`mp.msg.warn(...)`

`mp.msg.info(...)`

`mp.msg.verbose(...)`

`mp.msg.debug(...)`

`mp.msg.trace(...)`

`mp.utils.getcwd()` (LE)

`mp.utils.readdir(path [, filter])` (LE)

`mp.utils.file_info(path)` (LE) Note: like lua - this does NOT expand
meta-paths like `~~/foo` (other JS file functions do expand meta paths).

`mp.utils.split_path(path)`

`mp.utils.join_path(p1, p2)`

`mp.utils.subprocess(t)`

`mp.utils.subprocess_detached(t)`

`mp.utils.get_env_list()`

`mp.utils.getpid()` (LE)

`mp.add_hook(type, priority, fn(hook))`

`mp.options.read_options(obj [, identifier [, on_update]])` (types:
string/boolean/number)

`mp.input.get(obj)`

`mp.input.select(obj)`

`mp.input.terminate()`
