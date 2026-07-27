
`mp.input.log(message, style)`

`mp.input.log_error(message)`

`mp.input.set_log(log)`

`exit()` (global)

## Additional utilities

`mp.last_error()`

If used after an API call which updates last error, returns an empty string
if the API call succeeded, or a non-empty error reason string otherwise.

`Error.stack` (string)

When using `try { ... } catch(e) { ... }`, then `e.stack` is the stack
trace of the error - if it was created using the `Error(...)` constructor.

`print` (global)

A convenient alias to `mp.msg.info`.

`dump` (global)

Like `print` but also expands objects and arrays recursively.

`mp.utils.getenv(name)`

Returns the value of the host environment variable `name`, or
`undefined` if the variable is not defined.

`mp.utils.get_user_path(path)`

Trivial wrapper of the `expand-path` mpv command, returns a string.
`read_file`, `write_file`, `append_file` and `require` already
expand the path internally and accept mpv meta-paths like `~~desktop/foo`.

`mp.utils.read_file(fname [,max])`

Returns the content of file `fname` as string. If `max` is provided and
not negative, limit the read to `max` bytes.

`mp.utils.write_file(fname, str)`

(Over)write file `fname` with text content `str`. `fname` must be
prefixed with `file://` as simple protection against accidental arguments
switch, e.g. `mp.utils.write_file("file://~/abc.txt", "hello world")`.

`mp.utils.append_file(fname, str)`

Same as `mp.utils.write_file` if the file `fname` does not exist. If it
does exist then append instead of overwrite.

Note: `read_file`, `write_file` and `append_file` throw on errors, allow
text content only.

`mp.get_time_ms()`

Same as `mp.get_time()` but in ms instead of seconds.

`mp.get_script_file()`

Returns the file name of the current script.

`mp.utils.compile_js(fname, content_str)`

Compiles the JS code `content_str` as file name `fname` (without loading
anything from the filesystem), and returns it as a function. Very similar
to a `Function` constructor, but shows at stack traces as `fname`.

`mp.module_paths`

Global modules search paths array for the `require` function (see below).

## Timers (global)

The standard HTML/node.js timers are available:

`id = setTimeout(fn [,duration [,arg1 [,arg2...]]])`

`id = setTimeout(code_string [,duration])`

`clearTimeout(id)`

`id = setInterval(fn [,duration [,arg1 [,arg2...]]])`

`id = setInterval(code_string [,duration])`

`clearInterval(id)`

`setTimeout` and `setInterval` return id, and later call `fn` (or execute
`code_string`) after `duration` ms. Interval also repeat every `duration`.

`duration` has a minimum and default value of 0, `code_string` is
a plain string which is evaluated as JS code, and `[,arg1 [,arg2..]]` are used
as arguments (if provided) when calling back `fn`.

The `clear...(id)` functions cancel timer `id`, and are irreversible.

Note: timers always call back asynchronously, e.g. `setTimeout(fn)` will never
call `fn` before returning. `fn` will be called either at the end of this
event loop iteration or at a later event loop iteration. This is true also for
intervals - which also never call back twice at the same event loop iteration.

Additionally, timers are processed after the event queue is empty, so it's valid
to use `setTimeout(fn)` as a one-time idle observer.

## CommonJS modules and `require(id)`

CommonJS Modules are a standard system where scripts can export common functions
for use by other scripts. Specifically, a module is a script which adds
properties (functions, etc) to its pre-existing `exports` object, which
another script can access with `require(module-id)`. This runs the module and
returns its `exports` object. Further calls to `require` for the same module
will return its cached `exports` object without running the module again.

Modules and `require` are supported, standard compliant, and generally similar
to node.js. However, most node.js modules won't run due to missing modules such
as `fs`, `process`, etc, but some node.js modules with minimal dependencies
do work. In general, this is for mpv modules and not a node.js replacement.

A `.js` file extension is always added to `id`, e.g. `require("./foo")`
will load the file `./foo.js` and return its `exports` object.

An id which starts with `./` or `../` is relative to the script or module
which `require` it. Otherwise it's considered a top-level id (CommonJS term).

Top-level id is evaluated as absolute filesystem path if possible, e.g. `/x/y`
or `~/x`. Otherwise it's considered a global module id and searched according
to `mp.module_paths` in normal array order, e.g. `require("x")` tries to
load `x.js` at one of the array paths, and id `foo/x` tries to load `x.js`
inside dir `foo` at one of the paths.

The `mp.module_paths` array is empty by default except for scripts which are
loaded as a directory where it contains one item - `<directory>/modules/` .
The array may be updated from a script (or using custom init - see below) which
will affect future calls to `require` for global module id's which are not
already loaded/cached.

No `global` variable, but a module's `this` at its top lexical scope is the
global object - also in strict mode. If you have a module which needs `global`
as the global object, you could do `this.global = this;` before `require`.

Functions and variables declared at a module don't pollute the global object.

## Custom initialization

After mpv initializes the JavaScript environment for a script but before it
loads the script - it tries to run the file `init.js` at the root of the mpv
configuration directory. Code at this file can update the environment further
for all scripts. E.g. if it contains `mp.module_paths.push("/foo")` then
`require` at all scripts will search global module id's also at `/foo`
(do NOT do `mp.module_paths = ["/foo"];` because this will remove existing
paths - like `<script-dir>/modules` for scripts which load from a directory).

The custom-init file is ignored if mpv is invoked with `--no-config`.

Before mpv 0.34, the file name was `.init.js` (with dot) at the same dir.

