## Input

`--native-keyrepeat=<yes|no>`

Use system settings for keyrepeat delay and rate, instead of
`--input-ar-delay` and `--input-ar-rate` (default: no).
Whether this applies depends on the VO backend and how it handles
keyboard input. Does not apply to terminal input.

`--native-touch=<yes|no>`

(Windows only)
For platforms which send emulated mouse inputs for touch-unaware clients,
such as Windows, use system native touch events, instead of receiving them
as emulated mouse events (default: no). This is required for multi-touch
support for these platforms.

Note that this option has no effect on other platforms: either native touch
is not supported by mpv, or the platform does not give an option to receive
emulated mouse inputs (so native touch is always enabled, e.g. Wayland).

`--input-ar-delay`

Delay in milliseconds before we start to autorepeat a key (default: 200).
Set it to 0 to disable.

`--input-ar-rate`

Number of key presses to generate per second on autorepeat (default: 40).

`--input-conf=<filename>`

Specify input configuration file other than the default location in the mpv
configuration directory (usually `~/.config/mpv/input.conf`).

`--input-default-bindings=<yes|no>`

Enable default-level ("weak") key bindings (default: yes). These are bindings
which config files like `input.conf` can override. It currently affects the
builtin key bindings, and keys which scripts bind using `mp.add_key_binding`
(but not `mp.add_forced_key_binding` because this overrides `input.conf`).

`--input-builtin-bindings=<yes|no>`

Enable loading of built-in key bindings during start-up (default: yes). This
option is applied only during (lib)mpv initialization, and if disabled then it
will not be not possible to enable them later. May be useful to libmpv clients.

`--input-builtin-dragging=<yes|no>`

Enable the built-in window-dragging behavior (default: yes). Setting it to no
disables the built-in dragging behavior. Note that unlike the `window-dragging`
option, this option only affects VOs which support the `begin-vo-dragging`
command, and does not disable window dragging initialized with the command.

`--input-cmdlist`

Prints all commands that can be bound to keys.

`--input-commands=<cmd1,cmd2,...>`

Define a list of commands for mpv to run. The syntax is the same as format
as `input.conf` but without the key binding argument at the beginning.
When this option is set at startup, the commands will run after audio and
video playback are about to begin if applicable (in idle mode with no file,
it will run immediately). When changing values at runtime, the commands will
also run as soon as possible.

This is a string list option. See [List Options](manual-options-track.md) for details.

Example

`--input-commands="playlist-play-index 1,set ao-volume 40"`

sets the playlist index to 1 and the ao-volume to 40

`--input-doubleclick-time=<milliseconds>`

Time in milliseconds to recognize two consecutive button presses as a
double-click (default: 300).

`--input-keylist`

Prints all keys that can be bound to commands.

`--input-key-fifo-size=<2-65000>`

Specify the size of the FIFO that buffers key events (default: 7). If it
is too small, some events may be lost. The main disadvantage of setting it
to a very large value is that if you hold down a key triggering some
particularly slow command then the player may be unresponsive while it
processes all the queued commands.

`--input-test`

Input test mode. Instead of executing commands on key presses, mpv
will show the keys and the bound commands on the OSD. Has to be used
with a dummy video, and the normal ways to quit the player will not
work (key bindings that normally quit will be shown on OSD only, just
like any other binding). See [INPUT.CONF](manual-input-conf.md).

`--input-terminal=<yes|no>`

`--input-terminal=no` prevents the player from reading key events from
standard input. Useful when reading data from standard input. This is
automatically enabled when `-` is found on the command line. There are
situations where you have to set it manually, e.g. if you open
`/dev/stdin` (or the equivalent on your system), use stdin in a playlist
or intend to read from stdin later on via the loadfile or loadlist input
commands.

`--input-ipc-server=<filename>`

Enable the IPC support and create the listening socket at the given path.

On Linux and Unix, the given path is a regular filesystem path. On Windows,
named pipes are used, so the path refers to the pipe namespace
(`\\.\pipe\<name>`). If the `\\.\pipe\` prefix is missing, mpv will add
it automatically before creating the pipe, so
`--input-ipc-server=/tmp/mpv-socket` and
`--input-ipc-server=\\.\pipe\tmp\mpv-socket` are equivalent for IPC on
Windows.

See [JSON IPC](manual-json-ipc-1.md) for details.

`--input-ipc-client=fd://<N>`

Connect a single IPC client to the given FD. This is somewhat similar to
`--input-ipc-server`, except no socket is created, and instead the passed
FD is treated like a socket connection received from `accept()`. In
practice, you could pass either a FD created by `socketpair()`, or a pipe.
In both cases, you must make sure that the FD is actually inherited by mpv
(do not set the POSIX `CLOEXEC` flag).

The player quits when the connection is closed.

This is somewhat similar to the removed `--input-file` option, except it
supports only integer FDs, and cannot open actual paths.

Example

`--input-ipc-client=fd://123`

Note

To use this option on Windows, the fd must refer to a wrapped
(created by `_open_osfhandle`) named pipe server handle with a client
already connected. The named pipe must be created duplex with overlapped
IO and inheritable handles. The program communicates with mpv through
the client handle.

Warning

Writing to the `input-ipc-server` option at runtime will start another
instance of an IPC client handler for the `input-ipc-client` option,
because initialization is bundled, and this thing is stupid. This is a
bug. Writing to `input-ipc-client` at runtime will start another IPC
client handler for the new value, without stopping the old one, even if
the FD value is the same (but the string is different e.g. due to
whitespace). This is not a bug.

`--input-gamepad=<yes|no>`

Enable/disable SDL2 Gamepad support. Disabled by default.

`--input-cursor=<yes|no>`

Permit mpv to receive pointer events reported by the video output
driver. Necessary to use the OSC. Support depends on the VO in use.

`--input-cursor-passthrough=<yes|no>`

Tell the backend windowing system to allow pointer events to passthrough
the mpv window. This allows windows under mpv to instead receive pointer
events as if the mpv window was never there.

`--input-media-keys=<yes|no>`

On systems where mpv can choose between receiving media keys or letting
the system handle them - this option controls whether mpv should receive
them.

Default: yes (except for libmpv). macOS and Windows only, because elsewhere
mpv doesn't have a choice - the system decides whether to send media keys
to mpv. For instance, on X11 or Wayland, system-wide media keys are not
implemented. Whether media keys work when the mpv window is focused is
implementation-defined.

`--input-preprocess-wheel=<yes|no>`

Preprocess `WHEEL_*` events so that while scrolling on the horizontal
or vertical direction, the events aren't generated for another direction
even when the two directions are scrolled together (default: yes).

This preprocessing can be beneficial for preventing accidentally seeking
