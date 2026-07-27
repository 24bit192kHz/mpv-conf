### Execution Commands

`run <command> [<arg1> [<arg2> [...]]]`

Run the given command. Unlike in MPlayer/mplayer2 and earlier versions of
mpv (0.2.x and older), this doesn't call the shell. Instead, the command
is run directly, with each argument passed separately. Each argument is
expanded like in [Property Expansion](manual-property-list-1.md).

This command has a variable number of arguments, and cannot be used with
named arguments.

The program is run in a detached way. mpv doesn't wait until the command
is completed, but continues playback right after spawning it.

To get the old behavior, use `/bin/sh` and `-c` as the first two
arguments.

Example

`run "/bin/sh" "-c" "echo ${title} > /tmp/playing"`

This is not a particularly good example, because it doesn't handle
escaping, and a specially prepared file might allow an attacker to
execute arbitrary shell commands. It is recommended to write a small
shell script, and call that with `run`.

`subprocess`

Similar to `run`, but gives more control about process execution to the
caller, and does not detach the process.

You can avoid blocking until the process terminates by running this command
asynchronously. (For example `mp.command_native_async()` in Lua scripting.)

This has the following named arguments. The order of them is not guaranteed,
so you should always call them with named arguments, see [Named arguments](manual-input-commands-1.md).

`args` (`MPV_FORMAT_NODE_ARRAY[MPV_FORMAT_STRING]`)

Array of strings with the command as first argument, and subsequent
command line arguments following. This is just like the `run` command
argument list.

The first array entry is either an absolute path to the executable, or
a filename with no path components, in which case the executable is
searched in the directories in the `PATH` environment variable. On
Unix, this is equivalent to `posix_spawnp` and `execvp` behavior.

`playback_only` (`MPV_FORMAT_FLAG`)

Boolean indicating whether the process should be killed when playback
of the current playlist entry terminates (optional, default: true). If
enabled, stopping playback will automatically kill the process, and you
can't start it outside of playback.

`capture_size` (`MPV_FORMAT_INT64`)

Integer setting the maximum number of stdout plus stderr bytes that can
be captured (optional, default: 64MB). If the number of bytes exceeds
this, capturing is stopped. The limit is per captured stream.

`capture_stdout` (`MPV_FORMAT_FLAG`)

Capture all data the process outputs to stdout and return it once the
process ends (optional, default: no).

`capture_stderr` (`MPV_FORMAT_FLAG`)

Same as `capture_stdout`, but for stderr.

`detach` (`MPV_FORMAT_FLAG`)

Whether to run the process in detached mode (optional, default: no). In
this mode, the process is run in a new process session, and the command
does not wait for the process to terminate. If neither
`capture_stdout` nor `capture_stderr` have been set to true,
the command returns immediately after the new process has been started,
otherwise the command will read as long as the pipes are open.

`env` (`MPV_FORMAT_NODE_ARRAY[MPV_FORMAT_STRING]`)

Set a list of environment variables for the new process (default: empty).
If an empty list is passed, the environment of the mpv process is used
instead. (Unlike the underlying OS mechanisms, the mpv command cannot
start a process with empty environment. Fortunately, that is completely
useless.) The format of the list is as in the `execle()` syscall. Each
string item defines an environment variable as in `NAME=VALUE`.

On Lua, you may use `utils.get_env_list()` to retrieve the current
environment if you e.g. simply want to add a new variable.

`stdin_data` (`MPV_FORMAT_STRING`)

Feed the given string to the new process' stdin. Since this is a string,
you cannot pass arbitrary binary data. If the process terminates or
closes the pipe before all data is written, the remaining data is
silently discarded. Probably does not work on win32.

`passthrough_stdin` (`MPV_FORMAT_FLAG`)

If enabled, wire the new process' stdin to mpv's stdin (default: no).
Before mpv 0.33.0, this argument did not exist, but the behavior was as
if this was set to true.

The command returns the following result (as `MPV_FORMAT_NODE_MAP`):

`status` (`MPV_FORMAT_INT64`)

Typically this is the process exit code (0 or positive) if the process
terminates normally, or negative for other errors (failed to start,
terminated by mpv, and others).  The meaning of negative values is
undefined, other than meaning error (and does not correspond to OS low
level exit status values).

On Windows, it can happen that a negative return value is returned even
if the process terminates normally, because the win32 `UINT` exit
code is assigned to an `int` variable before being set as `int64_t`
field in the result map. This might be fixed later.

`stdout` (`MPV_FORMAT_BYTE_ARRAY`)

Captured stdout stream, limited to `capture_size`.

`stderr` (`MPV_FORMAT_BYTE_ARRAY`)

Same as `stdout`, but for stderr.

`error_string` (`MPV_FORMAT_STRING`)

Empty string if the process terminated normally. The string `killed`
if the process was terminated in an unusual way. The string `init` if
the process could not be started.

On Windows, `killed` is only returned when the process has been
killed by mpv as a result of `playback_only` being set to true.

`killed_by_us` (`MPV_FORMAT_FLAG`)

Whether the process has been killed by mpv, for example as a result of
`playback_only` being set to true, aborting the command (e.g. by
`mp.abort_async_command()`), or if the player is about to exit.

Note that the command itself will always return success as long as the
parameters are correct. Whether the process could be spawned or whether
it was somehow killed or returned an error status has to be queried from
the result value.

This command can be asynchronously aborted via API. Also see [Asynchronous
command details](manual-input-commands-1.md). Only the `run` command can start processes in a truly
detached way.

Note

The subprocess will always be terminated on player exit if it
wasn't started in detached mode, even if `playback_only` is
false.

Warning

Don't forget to set the `playback_only` field to false if you want
the command to run while the player is in idle mode, or if you don't
want the end of playback to kill the command.

Example

```
local r = mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stdout = true,
    args = {"cat", "/proc/cpuinfo"},
})
if r.status == 0 then
    print("result: " .. r.stdout)
end
```

This is a fairly useless Lua example, which demonstrates how to run
a process in a blocking manner, and retrieving its stdout output.

`quit []`

Exit the player. If an argument is given, it's used as process exit code.

`quit-watch-later []`

Exit player, and store current playback position. Playing that file later
will seek to the previous position on start. The (optional) argument is
exactly as in the `quit` command. See [RESUMING PLAYBACK](manual-resuming-playback.md).

