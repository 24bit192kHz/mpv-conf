### Miscellaneous Commands

`ignore`

Use this to "block" keys that should be unbound, and do nothing. Useful for
disabling default bindings, without disabling all bindings with
`--input-default-bindings=no`.

`drop-buffers`

Drop audio/video/demuxer buffers, and restart from fresh. Might help with
unseekable streams that are going out of sync.
This command might be changed or removed in the future.

`dump-cache <start> <end> <filename>`

Dump the current cache to the given filename. The `<filename>` file is
overwritten if it already exists. `<start>` and `<end>` give the
time range of what to dump. If no data is cached at the given time range,
nothing may be dumped (creating a file with no packets).

Dumping a larger part of the cache will freeze the player. No effort was
made to fix this, as this feature was meant mostly for creating small
excerpts.

See `--stream-record` for various caveats that mostly apply to this
command too, as both use the same underlying code for writing the output
file.

If `<filename>` is an empty string, an ongoing `dump-cache` is stopped.

If `<end>` is `no`, then continuous dumping is enabled. Then, after
dumping the existing parts of the cache, anything read from network is
appended to the cache as well. This behaves similar to `--stream-record`
(although it does not conflict with that option, and they can be both active
at the same time).

If the `<end>` time is after the cache, the command will _not_ wait and
write newly received data to it.

The end of the resulting file may be slightly damaged or incomplete at the
end. (Not enough effort was made to ensure that the end lines up properly.)

Note that this command will finish only once dumping ends. That means it
works similar to the `screenshot` command, just that it can block much
longer. If continuous dumping is used, the command will not finish until
playback is stopped, an error happens, another `dump-cache` command is
run, or an API like `mp.abort_async_command` was called to explicitly stop
the command. See [Synchronous vs. Asynchronous](manual-input-commands-1.md).

Note

This was mostly created for network streams. For local files, there may
be much better methods to create excerpts and such. There are tons of
much more user-friendly Lua scripts, that will re-encode parts of a file
by spawning a separate instance of `ffmpeg`. With network streams,
this is not that easily possible, as the stream would have to be
downloaded again. Even if `--stream-record` is used to record the
stream to the local filesystem, there may be problems, because the
recorded file is still written to.

This command is experimental, and all details about it may change in the
future.

`ab-loop`

Cycle through A-B loop states. The first command will set the `A` point
(the `ab-loop-a` property); the second the `B` point, and the third
will clear both points.

`ab-loop-dump-cache <filename>`

Essentially calls `dump-cache` with the current AB-loop points as
arguments. Like `dump-cache`, this will overwrite the file at
`<filename>`. Likewise, if the B point is set to `no`, it will enter
continuous dumping after the existing cache was dumped.

The author reserves the right to remove this command if enough motivation
is found to move this functionality to a trivial Lua script.

`ab-loop-align-cache`

Re-adjust the A/B loop points to the start and end within the cache the
`ab-loop-dump-cache` command will (probably) dump. Basically, it aligns
the times on keyframes. The guess might be off especially at the end (due to
granularity issues due to remuxing). If the cache shrinks in the meantime,
the points set by the command will not be the effective parameters either.

This command has an even more uncertain future than `ab-loop-dump-cache`
and might disappear without replacement if the author decides it's useless.

`begin-vo-dragging`

Begin window dragging if supported by the current VO. This command should
only be called while a mouse button is being pressed, otherwise it will
be ignored. The exact effect of this command depends on the VO implementation
of window dragging. For example, on Windows and macOS only the left mouse
button can begin window dragging, while X11 and Wayland allow other mouse
buttons.

`context-menu`

Show context menu on the video window. See [Context Menu](manual-context-menu-script.md) section for details.

Undocumented commands: `ao-reload` (experimental/internal).

