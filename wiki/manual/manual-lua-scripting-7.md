- rename `max_size` to `capture_size`

- set `capture_stdout` field to `true` if unset

- set `name` field to `subprocess`

- call `mp.command_native(copied_t)`

- if the command failed, create a dummy result table

- copy `error_string` to `error` field if the string is non-empty

- return the result table

It is recommended to use `mp.command_native` or `mp.command_native_async`
directly, instead of calling this legacy wrapper. It is for compatibility
only.

See the `subprocess` documentation for semantics and further parameters.

`utils.subprocess_detached(t)`

Runs an external process and detaches it from mpv's control.

The parameter `t` is a table. The function reads the following entries:

> `args`
>
>
> Array of strings of the same semantics as the `args` used in the
> `subprocess` function.

The function returns `nil`.

This is a legacy wrapper around calling the `run` command with
`mp.commandv` and other functions.

`utils.getpid()`

Returns the process ID of the running mpv process. This can be used to identify
the calling mpv when launching (detached) subprocesses.

`utils.get_env_list()`

Returns the C environment as a list of strings. (Do not confuse this with
the Lua "environment", which is an unrelated concept.)

`utils.parse_json(str [, trail])`

Parses the given string argument as JSON, and returns it as a Lua table. On
error, returns `nil, error`. (Currently, `error` is just a string
reading `error`, because there is no fine-grained error reporting of any
kind.)

The returned value uses similar conventions as `mp.get_property_native()`
to distinguish empty objects and arrays.

If the `trail` parameter is `true` (or any value equal to `true`),
then trailing non-whitespace text is tolerated by the function, and the
trailing text is returned as 3rd return value. (The 3rd return value is
always there, but with `trail` set, no error is raised.)

`utils.format_json(v)`

Format the given Lua table (or value) as a JSON string and return it. On
error, returns `nil, error`. (Errors usually only happen on value types
incompatible with JSON.)

The argument value uses similar conventions as `mp.set_property_native()`
to distinguish empty objects and arrays.

`utils.to_string(v)`

Turn the given value into a string. Formats tables and their contents. This
doesn't do anything special; it is only needed because Lua is terrible.

## mp.input functions

This module lets scripts get textual input from the user using the console
REPL.

`input.get(table)`

Show the console to let the user enter text.

The following entries of `table` are read:

`prompt`

The string to be displayed before the input field.

`submit`

A callback invoked when the user presses Enter. The first argument is
the text in the console.

`keep_open`

Whether to keep the console open on submit. Defaults to `false`.

`opened`

A callback invoked when the console is shown. This can be used to
present a list of options with `input.set_log()`.

`edited`

A callback invoked when the text changes. The first argument is the text
in the console.

`complete`

A callback invoked when the user edits the text or moves the cursor. The
first argument is the text before the cursor. The callback should return
a table of the string candidate completion values and the 1-based cursor
position from which the completion starts. console will show the
completions that fuzzily match the text between this position and the
cursor and allow selecting them.

The third and optional return value is a string that will be appended to
the input line without displaying it in the completions.

`autoselect_completion`

Whether to automatically select the first completion on submit if one
wasn't already manually selected. Defaults to `false`.

`closed`

A callback invoked when the console is hidden, either because
`input.terminate()` was invoked from the other callbacks, or because
the user closed it with a key binding. The first argument is the text in
the console, and the second argument is the cursor position.

`default_text`

A string to pre-fill the input field with.

`cursor_position`

The initial cursor position, starting from 1.

`history_path`

If specified, the path to save and load the history of the entered
lines.

`id`

An identifier that determines which input history and log buffer to use
among the ones stored for `input.get()` calls. Defaults to the calling
script name with `prompt` appended.

`input.terminate()`

Close the console.

`input.log(message, style, terminal_style)`

Add a line to the log buffer. `style` can contain additional ASS tags to
apply to `message`, and `terminal_style` can contain escape sequences
that are used when the console is displayed in the terminal.

`input.log_error(message)`

Helper to add a line to the log buffer with the same color as the one used
for commands that error. Useful when the user submits invalid input.

`input.set_log(log)`

Replace the entire log buffer.

`log` is a table of strings, or tables with `text`, `style` and
`terminal_style` keys.

Example:

```
input.set_log({
    "regular text",
    {
        text = "error text",
        style = "{\\c&H7a77f2&}",
        terminal_style = "\027[31m",
    }
})
```

`input.select(table)`

Specify a list of items that are presented to the user for selection.

The following entries of `table` are read:

`prompt`
