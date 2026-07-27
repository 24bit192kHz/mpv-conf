# LUA SCRIPTING

mpv can load Lua scripts. (See [Script location](manual-lua-scripting-1.md).)

mpv provides the built-in module `mp`, which contains functions to send
commands to the mpv core and to retrieve information about playback state, user
settings, file information, and so on.

Technically, the Lua code uses the client API internally.

## Example

A script which leaves fullscreen mode when the player is paused:

```
function on_pause_change(name, value)
    if value == true then
        mp.set_property("fullscreen", "no")
    end
end
mp.observe_property("pause", "bool", on_pause_change)
```

## Script location

Scripts can be passed to the `--script` option, and are automatically loaded
from the `scripts` subdirectory of the mpv configuration directory (usually
`~/.config/mpv/scripts/`).

A script can be a single file. The file extension is used to select the
scripting backend to use for it. For Lua, it is `.lua`. If the extension is
not recognized, an error is printed. (If an error happens, the extension is
either mistyped, or the backend was not compiled into your mpv binary.)

mpv internally loads the script's name by stripping the `.lua` extension and
replacing all nonalphanumeric characters with `_`. E.g., `my-tools.lua`
becomes `my_tools`. If there are several scripts with the same name, it is
made unique by appending a number. This is the name returned by
`mp.get_script_name()`.

Entries with `.disable` extension are always ignored.

If a script is a directory (either if a directory is passed to `--script`,
or any sub-directories in the script directory, such as for example
`~/.config/mpv/scripts/something/`), then the directory represents a single
script. The player will try to load a file named `main.x`, where `x` is
replaced with the file extension. For example, if `main.lua` exists, it is
loaded with the Lua scripting backend.

You must not put any other files or directories that start with `main.` into
the script's top level directory. If the script directory contains for example
both `main.lua` and `main.js`, only one of them will be loaded (and which
one depends on mpv internals that may change any time). Likewise, if there is
for example `main.foo`, your script will break as soon as mpv adds a backend
that uses the `.foo` file extension.

mpv also appends the top level directory of the script to the start of Lua's
package path so you can import scripts from there too. Be aware that this will
shadow Lua libraries that use the same package path. (Single file scripts do not
include mpv specific directories in the Lua package path. This was silently
changed in mpv 0.32.0.)

Using a script directory is the recommended way to package a script that
consists of multiple source files, or requires other files (you can use
`mp.get_script_directory()` to get the location and e.g. load data files).

Making a script a git repository, basically a repository which contains a
`main.lua` file in the root directory, makes scripts easily updateable
(without the dangers of auto-updates). Another suggestion is to use git
submodules to share common files or libraries.

## Details on the script initialization and lifecycle

Your script will be loaded by the player at program start from the `scripts`
configuration subdirectory, or from a path specified with the `--script`
option. Some scripts are loaded internally (like `--osc`). Each script runs in
its own thread. Your script is first run "as is", and once that is done, the event loop
is entered. This event loop will dispatch events received by mpv and call your
own event handlers which you have registered with `mp.register_event`, or
timers added with `mp.add_timeout` or similar. Note that since the
script starts execution concurrently with player initialization, some properties
may not be populated with meaningful values until the relevant subsystems have
initialized. Rather than retrieving these properties at the top of scripts, you
should use `mp.observe_property` or read them within event handlers.

When the player quits, all scripts will be asked to terminate. This happens via
a `shutdown` event, which by default will make the event loop return. If your
script got into an endless loop, mpv will probably behave fine during playback,
but it won't terminate when quitting, because it's waiting on your script.

Internally, the C code will call the Lua function `mp_event_loop` after
loading a Lua script. This function is normally defined by the default prelude
loaded before your script (see `player/lua/defaults.lua` in the mpv sources).
The event loop will wait for events and dispatch events registered with
`mp.register_event`. It will also handle timers added with `mp.add_timeout`
and similar (by waiting with a timeout).

Since mpv 0.6.0, the player will wait until the script is fully loaded before
continuing normal operation. The player considers a script as fully loaded as
soon as it starts waiting for mpv events (or it exits). In practice this means
the player will more or less hang until the script returns from the main chunk
(and `mp_event_loop` is called), or the script calls `mp_event_loop` or
`mp.dispatch_events` directly. This is done to make it possible for a script
to fully setup event handlers etc. before playback actually starts. In older
mpv versions, this happened asynchronously. With mpv 0.29.0, this changes
slightly, and it merely waits for scripts to be loaded in this manner before
starting playback as part of the player initialization phase. Scripts run though
initialization in parallel. This might change again.

