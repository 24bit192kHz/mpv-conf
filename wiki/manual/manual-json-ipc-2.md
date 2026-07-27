## Asynchronous commands

Command can be run asynchronously. This behaves exactly as with normal command
execution, except that execution is not blocking. Other commands can be sent
while it's executing, and command completion can be arbitrarily reordered.

The `async` field controls this. If present, it must be a boolean. If missing,
`false` is assumed.

For example, this initiates an asynchronous command:

```
{ "command": ["screenshot"], "request_id": 123, "async": true }
```

And this is the completion:

```
{"request_id":123,"error":"success","data":null}
```

By design, you will not get a confirmation that the command was started. If a
command is long running, sending the message will not lead to any reply until
much later when the command finishes.

Some commands execute synchronously, but these will behave like asynchronous
commands that finished execution immediately.

Cancellation of asynchronous commands is available in the libmpv API, but has
not yet been implemented in the IPC protocol.

## Commands with named arguments

If the `command` field is a JSON object, named arguments are expected. This
is described in the C API `mpv_command_node()` documentation (the
`MPV_FORMAT_NODE_MAP` case). In some cases, this may make commands more
readable, while some obscure commands basically require using named arguments.

Currently, only "proper" commands (as listed by [List of Input Commands](manual-list-of-commands-1.md))
support named arguments.

## Commands

In addition to the commands described in [List of Input Commands](manual-list-of-commands-1.md), a few
extra commands can also be used as part of the protocol:

`client_name`

Return the name of the client as string. This is the string `ipc-N` with
N being an integer number.

`get_time_us`

Return the current mpv internal time in microseconds as a number. This is
basically the system time, with an arbitrary offset.

`get_property`

Return the value of the given property. The value will be sent in the data
field of the replay message.

Example:

```
{ "command": ["get_property", "volume"] }
{ "data": 50.0, "error": "success" }
```

`get_property_string`

Like `get_property`, but the resulting data will always be a string.

Example:

```
{ "command": ["get_property_string", "volume"] }
{ "data": "50.000000", "error": "success" }
```

`set_property`

Set the given property to the given value. See [Properties](manual-properties.md) for more
information about properties.

Example:

```
{ "command": ["set_property", "pause", true] }
{ "error": "success" }
```

`set_property_string`

Alias for `set_property`. Both commands accept native values and strings.

`observe_property`

Watch a property for changes. If the given property is changed, then an
event of type `property-change` will be generated

Example:

```
{ "command": ["observe_property", 1, "volume"] }
{ "error": "success" }
{ "event": "property-change", "id": 1, "data": 52.0, "name": "volume" }
```

Warning

If the connection is closed, the IPC client is destroyed internally,
and the observed properties are unregistered. This happens for example
when sending commands to a socket with separate `socat` invocations.
This can make it seem like property observation does not work. You must
keep the IPC connection open to make it work.

`observe_property_string`

Like `observe_property`, but the resulting data will always be a string.

Example:

```
{ "command": ["observe_property_string", 1, "volume"] }
{ "error": "success" }
{ "event": "property-change", "id": 1, "data": "52.000000", "name": "volume" }
```

`unobserve_property`

Undo `observe_property` or `observe_property_string`. This requires the
numeric id passed to the observed command as argument.

Example:

```
{ "command": ["unobserve_property", 1] }
{ "error": "success" }
```

`request_log_messages`

Enable output of mpv log messages. They will be received as events. The
parameter to this command is the log-level (see `mpv_request_log_messages`
C API function).

Log message output is meant for humans only (mostly for debugging).
Attempting to retrieve information by parsing these messages will just
lead to breakages with future mpv releases. Instead, make a feature request,
and ask for a proper event that returns the information you need.

`enable_event`, `disable_event`

Enables or disables the named event. Mirrors the `mpv_request_event` C
API function. If the string `all` is used instead of an event name, all
events are enabled or disabled.

By default, most events are enabled, and there is not much use for this
command.

`get_version`

Returns the client API version the C API of the remote mpv instance
provides.

See also: `DOCS/client-api-changes.rst`.

## UTF-8

Normally, all strings are in UTF-8. Sometimes it can happen that strings are
in some broken encoding (often happens with file tags and such, and filenames
on many Unixes are not required to be in UTF-8 either). This means that mpv
sometimes sends invalid JSON. If that is a problem for the client application's
parser, it should filter the raw data for invalid UTF-8 sequences and perform
the desired replacement, before feeding the data to its JSON parser.

mpv will not attempt to construct invalid UTF-8 with broken "u" escape
sequences. This includes surrogate pairs.

