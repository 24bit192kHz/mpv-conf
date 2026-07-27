## Synchronous vs. Asynchronous

The `async` and `sync` prefix matter only for how the issuer of the command
waits on the completion of the command. Normally it does not affect how the
command behaves by itself. There are the following cases:

- Normal input.conf commands are always run asynchronously. Slow running
commands are queued up or run in parallel.

- "Multi" input.conf commands (1 key binding, concatenated with `;`) will be
executed in order, except for commands that are async (either prefixed with
`async`, or async by default for some commands). The async commands are
run in a detached manner, possibly in parallel to the remaining sync commands
in the list.

- Normal Lua and libmpv commands (e.g. `mpv_command()`) are run in a blocking
manner, unless the `async` prefix is used, or the command is async by
default. This means in the sync case the caller will block, even if the core
continues playback. Async mode runs the command in a detached manner.

- Async libmpv command API (e.g. `mpv_command_async()`) never blocks the
caller, and always notify their completion with a message. The `sync` and
`async` prefixes make no difference.

- Lua also provides APIs for running async commands, which behave similar to the
C counterparts.

- In all cases, async mode can still run commands in a synchronous manner, even
in detached mode. This can for example happen in cases when a command does not
have an  asynchronous implementation. The async libmpv API still never blocks
the caller in these cases.

Before mpv 0.29.0, the `async` prefix was only used by screenshot commands,
and made them run the file saving code in a detached manner. This is the
default now, and `async` changes behavior only in the ways mentioned above.

Currently the following commands have different waiting characteristics with
sync vs. async: sub-add, audio-add, sub-reload, audio-reload,
rescan-external-files, screenshot, screenshot-to-file, dump-cache,
ab-loop-dump-cache.

## Asynchronous command details

On the API level, every asynchronous command is bound to the context which
started it. For example, an asynchronous command started by `mpv_command_async`
is bound to the `mpv_handle` passed to the function. Only this `mpv_handle`
receives the completion notification (`MPV_EVENT_COMMAND_REPLY`), and only
this handle can abort a still running command directly. If the `mpv_handle` is
destroyed, any still running async. commands started by it are terminated.

The scripting APIs and JSON IPC give each script/connection its own implicit
`mpv_handle`.

If the player is closed, the core may abort all pending async. commands on its
own (like a forced `mpv_abort_async_command()` call for each pending command
on behalf of the API user). This happens at the same time `MPV_EVENT_SHUTDOWN`
is sent, and there is no way to prevent this.

## Input Sections

Input sections group a set of bindings, and enable or disable them at once.
In `input.conf`, each key binding is assigned to an input section, rather
than actually having explicit text sections.

See also: `enable-section` and `disable-section` commands.

Predefined bindings:

`default`

Bindings without input section are implicitly assigned to this section. It
is enabled by default during normal playback.

`encode`

Section which is active in encoding mode. It is enabled exclusively, so
that bindings in the `default` sections are ignored.
