# FILES ON WINDOWS

On win32 (if compiled with MinGW, but not Cygwin), the default config file
locations are different. They are generally located under `%APPDATA%/mpv/`.
For example, the path to mpv.conf is `%APPDATA%/mpv/mpv.conf`, which maps to
a system and user-specific path, for example

> `C:\users\USERNAME\AppData\Roaming\mpv\mpv.conf`

You can find the exact path by running `echo %APPDATA%\mpv\mpv.conf` in cmd.exe.

Other config files (such as `input.conf`) are in the same directory. See the
[FILES](manual-files.md) section above.

The cache directory is located at `%LOCALAPPDATA%/mpv/cache`.

The watch_later directory is located at `%LOCALAPPDATA%/mpv/watch_later`.

The environment variable `$MPV_HOME` completely overrides these, like on
UNIX.

If a directory named `portable_config` next to the mpv.exe exists, all
config will be loaded from this directory only. Watch later config files and
cache files are written to this directory as well. (This exists on Windows
only and is redundant with `$MPV_HOME`. However, since Windows is very
scripting unfriendly, a wrapper script just setting `$MPV_HOME`, like you
could do it on other systems, won't work. `portable_config` is provided for
convenience to get around this restriction.)

Config files located in the same directory as `mpv.exe` are loaded with
lower priority. Some config files are loaded only once, which means that
e.g. of 2 `input.conf` files located in two config directories, only the
one from the directory with higher priority will be loaded.

A third config directory with the lowest priority is the directory named `mpv`
in the same directory as `mpv.exe`. This used to be the directory with the
highest priority, but is now discouraged to use and might be removed in the
future.

Note that mpv likes to mix `/` and `\` path separators for simplicity.
kernel32.dll accepts this, but cmd.exe does not.
