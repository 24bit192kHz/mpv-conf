# JSON IPC

mpv can be controlled by external programs using the JSON-based IPC protocol.
It can be enabled by specifying the path to a unix socket or a named pipe using
the option `--input-ipc-server`, or the file descriptor number of a unix socket
or a named pipe using `--input-ipc-client`.
Clients can connect to this socket and send commands to the player or receive
events from it.

Warning

This is not intended to be a secure network protocol. It is explicitly
insecure: there is no authentication, no encryption, and the commands
themselves are insecure too. For example, the `run` command is exposed,
which can run arbitrary system commands. The use-case is controlling the
player locally. This is not different from the MPlayer slave protocol.

## Socat example

You can use the `socat` tool to send commands (and receive replies) from the
shell. Assuming mpv was started with:

```
mpv file.mkv --input-ipc-server=/tmp/mpvsocket
```

Then you can control it using socat:

```
> echo '{ "command": ["get_property", "playback-time"] }' | socat - /tmp/mpvsocket
{"data":190.482000,"error":"success"}
```

In this case, socat copies data between stdin/stdout and the mpv socket
connection.

See the `--idle` option how to make mpv start without exiting immediately or
playing a file.

It's also possible to send input.conf style text-only commands:

```
> echo 'show-text ${playback-time}' | socat - /tmp/mpvsocket
```

But you won't get a reply over the socket. (This particular command shows the
playback time on the player's OSD.)

## Command Prompt example

Unfortunately, it's not as easy to test the IPC protocol on Windows, since
Windows ports of socat (in Cygwin and MSYS2) don't understand named pipes. In
the absence of a simple tool to send and receive from bidirectional pipes, the
`echo` command can be used to send commands, but not receive replies from the
command prompt.

Assuming mpv was started with:

```
mpv file.mkv --input-ipc-server=\\.\pipe\mpvsocket
```

You can send commands from a command prompt:

```
echo show-text ${playback-time} >\\.\pipe\mpvsocket
```

To be able to simultaneously read and write from the IPC pipe, like on Linux,
it's necessary to write an external program that uses overlapped file I/O (or
some wrapper like .NET's NamedPipeClientStream.)

You can open the pipe in PuTTY as "serial" device. This is not very
comfortable, but gives a way to test interactively without having to write code.

## Protocol

The protocol uses UTF-8-only JSON as defined by RFC-8259. Unlike standard JSON,
"u" escape sequences are not allowed to construct surrogate pairs. To avoid
getting conflicts, encode all text characters including and above codepoint
U+0020 as UTF-8. mpv might output broken UTF-8 in corner cases (see "UTF-8"
section below).

Clients can execute commands on the player by sending JSON messages of the
following form:

```
{ "command": ["command_name", "param1", "param2", ...] }
```

where `command_name` is the name of the command to be executed, followed by a
list of parameters. Parameters must be formatted as native JSON values
(integers, strings, booleans, ...). Every message **must** be terminated with
`\n`. Additionally, `\n` must not appear anywhere inside the message. In
practice this means that messages should be minified before being sent to mpv.

mpv will then send back a reply indicating whether the command was run
correctly, and an additional field holding the command-specific return data (it
can also be null).

```
{ "error": "success", "data": null }
```

mpv will also send events to clients with JSON messages of the following form:

```
{ "event": "event_name" }
```

where `event_name` is the name of the event. Additional event-specific fields
can also be present. See [List of events](manual-list-of-commands-1.md) for a list of all supported events.

Because events can occur at any time, it may be difficult at times to determine
which response goes with which command. Commands may optionally include a
`request_id` which, if provided in the command request, will be copied
verbatim into the response. mpv does not interpret the `request_id` in any
way; it is solely for the use of the requester. The only requirement is that
the `request_id` field must be an integer (a number without fractional parts
in the range `-2^63..2^63-1`). Using other types is deprecated and will
currently show a warning. In the future, this will raise an error.

For example, this request:

```
{ "command": ["get_property", "time-pos"], "request_id": 100 }
```

Would generate this response:

```
{ "error": "success", "data": 1.468135, "request_id": 100 }
```

If you don't specify a `request_id`, command replies will set it to 0.

All commands, replies, and events are separated from each other with a line
break character (`\n`).

If the first character (after skipping whitespace) is not `{`, the command
will be interpreted as non-JSON text command, as they are used in input.conf
(or `mpv_command_string()` in the client API). Additionally, lines starting
with `#` and empty lines are ignored.

Currently, embedded 0 bytes terminate the current line, but you should not
rely on this.

## Data flow

Currently, the mpv-side IPC implementation does not service the socket while a
command is executed and the reply is written. It is for example not possible
that other events, that happened during the execution of the command, are
written to the socket before the reply is written.

This might change in the future. The only guarantee is that replies to IPC
messages are sent in sequence.

Also, since socket I/O is inherently asynchronous, it is possible that you read
unrelated event messages from the socket, before you read the reply to the
previous command you sent. In this case, these events were queued by the mpv
side before it read and started processing your command message.

If the mpv-side IPC implementation switches away from blocking writes and
blocking command execution, it may attempt to send events at any time.

You can also use asynchronous commands, which can return in any order, and
which do not block IPC protocol interaction at all while the command is
executed in the background.

