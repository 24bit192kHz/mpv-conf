## Flat command syntax

This is the syntax used in input.conf, and referred to "input.conf syntax" in
a number of other places.

```

`  ::= [

]  ()*`
` ::= ( | "  " | '  ' | `X  X`)`
```

`command_name` is an unquoted string with the command name itself. See
[List of Input Commands](manual-list-of-commands-1.md) for a list.

Arguments are separated by whitespaces even if the command expects only one
argument. Arguments with whitespaces or other special characters must be quoted,
or the command cannot be parsed correctly.

Double quotes interpret JSON/C-style escaping, like `\t` or `\"` or `\\`.
JSON escapes according to RFC 8259, minus surrogate pair escapes. This is the
only form which allows newlines at the value - as `\n`.

Single quotes take the content literally, and cannot include the single-quote
character at the value.

Custom quotes also take the content literally, but are more flexible than single
quotes. They start with ``` (back-quote) followed by any ASCII character,
and end at the first occurrence of the same pair in reverse order, e.g.
``-foo-`` or ```bar```. The final pair sequence is not allowed at the
value - in these examples `-`` and ```` respectively. In the second
example the last character of the value also can't be a back-quote.

Mixed quoting at the same argument, like `'foo'"bar"`, is not supported.

Note that argument parsing and property expansion happen at different stages.
First, arguments are determined as described above, and then, where applicable,
properties are expanded - regardless of argument quoting. However, expansion
can still be prevented with the `raw` prefix or `$>`. See [Input Command
Prefixes](manual-input-commands-1.md) and [Property Expansion](manual-property-list-1.md).

## Commands specified as arrays

This applies to certain APIs, such as `mp.commandv()` or
`mp.command_native()` (with array parameters) in Lua scripting, or
`mpv_command()` or `mpv_command_node()` (with MPV_FORMAT_NODE_ARRAY) in the
C libmpv client API.

The command as well as all arguments are passed as a single array. Similar to
the [Flat command syntax](manual-input-commands-1.md), you can first pass prefixes as strings (each as
separate array item), then the command name as string, and then each argument
as string or a native value.

Since these APIs pass arguments as separate strings or native values, they do
not expect quotes, and do support escaping. Technically, there is the input.conf
parser, which first splits the command string into arguments, and then invokes
argument parsers for each argument. The input.conf parser normally handles
quotes and escaping. The array command APIs mentioned above pass strings
directly to the argument parsers, or can sidestep them by the ability to pass
non-string values.

Property expansion is disabled by default for these APIs. This can be changed
with the `expand-properties` prefix. See [Input Command Prefixes](manual-input-commands-1.md).

Sometimes commands have string arguments, that in turn are actually parsed by
other components (e.g. filter strings with `vf add`) - in these cases, you
you would have to double-escape in input.conf, but not with the array APIs.

For complex commands, consider using [Named arguments](manual-input-commands-1.md) instead, which should
give slightly more compatibility. Some commands do not support named arguments
and inherently take an array, though.

## Named arguments

This applies to certain APIs, such as `mp.command_native()` (with tables that
have string keys) in Lua scripting, or `mpv_command_node()` (with
MPV_FORMAT_NODE_MAP) in the C libmpv client API.

The name of the command is provided with a `name` string field. The name of
each command is defined in each command description in the
[List of Input Commands](manual-list-of-commands-1.md). `--input-cmdlist` also lists them. See the
`subprocess` command for an example.

Some commands do not support named arguments (e.g. `run` command). You need
to use APIs that pass arguments as arrays.

Named arguments are not supported in the "flat" input.conf syntax, which means
you cannot use them for key bindings in input.conf at all.

Property expansion is disabled by default for these APIs. This can be changed
with the `expand-properties` prefix. See [Input Command Prefixes](manual-input-commands-1.md).

## Input Command Prefixes

These prefixes are placed between key name and the actual command. Multiple
prefixes can be specified. They are separated by whitespace.

`osd-auto`

Use the default behavior for this command. This is the default for
`input.conf` commands. Some libmpv/scripting/IPC APIs do not use this as
default, but use `no-osd` instead.

`no-osd`

Do not use any OSD for this command.

`osd-bar`

If possible, show a bar with this command. Seek commands will show the
progress bar, property changing commands may show the newly set value.

`osd-msg`

If possible, show an OSD message with this command. Seek command show
the current playback time, property changing commands show the newly set
value as text.

`osd-msg-bar`

Combine osd-bar and osd-msg.

`raw`

Do not expand properties in string arguments. (Like `"${property-name}"`.)
This is the default for some libmpv/scripting/IPC APIs.

`expand-properties`

All string arguments are expanded as described in [Property Expansion](manual-property-list-1.md).
This is the default for `input.conf` commands.

`repeatable`

For some commands, keeping a key pressed doesn't run the command repeatedly.
This prefix forces enabling key repeat in any case. For a list of commands:
the first command determines the repeatability of the whole list (up to and
including version 0.33 - a list was always repeatable).

`nonrepeatable`

For some commands, keeping a key pressed runs the command repeatedly.
This prefix forces disabling key repeat in any case.

`nonscalable`

When some commands (e.g. `add`) are bound to scalable keys associated to a
high-precision input device like a touchpad (e.g. `WHEEL_UP`), the value
specified in the command is scaled to smaller steps based on the high
resolution input data if available.
This prefix forces disabling this behavior, so the value is always changed
in the discrete unit specified in the key binding.

`async`

Allow asynchronous execution (if possible). Note that only a few commands
will support this (usually this is explicitly documented). Some commands
are asynchronous by default (or rather, their effects might manifest
after completion of the command). The semantics of this flag might change
in the future. Set it only if you don't rely on the effects of this command
being fully realized when it returns. See [Synchronous vs. Asynchronous](manual-input-commands-1.md).

`sync`

Allow synchronous execution (if possible). Normally, all commands are
synchronous by default, but some are asynchronous by default for
compatibility with older behavior.

All of the osd prefixes are still overridden by the global `--osd-level`
settings.

