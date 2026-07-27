## Program Behavior

`--help`, `--h`

Show short summary of options.

You can also pass a string to this option, which will list all top-level
options which contain the string in the name, e.g. `--h=scale` for all
options that contain the word `scale`. The special string `*` lists
all top-level options.

`-v`

Increment verbosity level, one level for each `-v` found on the command
line.

`--version, -V`

Print version string and exit.

`--no-config`

Do not load default configuration or any user files. This prevents loading of
both the user-level and system-wide `mpv.conf` and `input.conf` files. Other
user files are blocked as well, such as resume playback files and cache files.
This option only takes effect when used as a command line flag.

Note

Files explicitly requested by command line options, like
`--include` or `--use-filedir-conf`, will still be loaded.

See also: `--config-dir`.

`--list-options`

Prints all available options.

`--list-properties`

Print a list of the available properties.

`--list-protocols`

Print a list of the supported protocols.

`--log-file=

`

Opens the given path for writing, and print log messages to it. Existing
files will be truncated. The log level is at least `-v -v`, but
can be raised via `--msg-level` (the option cannot lower it below the
forced minimum log level).

A special case is the macOS bundle, it will create a log file at
`~/Library/Logs/mpv.log` by default.

`--config-dir=

`

Force a different configuration directory. If this is set, the given
directory is used to load configuration files, and all other configuration
directories are ignored. This means the global mpv configuration directory
as well as per-user directories are ignored, and overrides through
environment variables (`MPV_HOME`) are also ignored.

Note that the cache and state paths (`~~/cache`, `~~/state`) are not
considered "configuration" and keep their auto-detection logic.

Note that the `--no-config` option takes precedence over this option.

`--dump-stats=<filename>`

Write certain statistics to the given file. The file is truncated on
opening. The file will contain raw samples, each with a timestamp. To
make this file into a readable, the script `TOOLS/stats-conv.py` can be
used (which currently displays it as a graph).

This option is useful for debugging only.

`--idle=<no|yes|once>`

Makes mpv wait idly instead of quitting when there is no file to play.
Mostly useful in input mode, where mpv can be controlled through input
commands. (Default: `no`)

`once` will only idle at start and let the player close once the
first playlist has finished playing back.

`--include=<configuration-file>`

Specify configuration file to be parsed after the default ones.

`--load-scripts=<yes|no>`

If set to `no`, don't auto-load scripts from the `scripts`
configuration subdirectory (usually `~/.config/mpv/scripts/`).
(Default: `yes`)

`--script=<filename>`, `--scripts=file1.lua:file2.lua:...`

Load a Lua script. The second option allows you to load multiple scripts by
separating them with the path separator (`:` on Unix, `;` on Windows).

`--scripts` is a path list option. See [List Options](manual-options-track.md) for details.

`--script-opt=<key=value>`, `--script-opts=key1=value1,key2=value2,...`

Set options for scripts. A script can query an option by key. If an
option is used and what semantics the option value has depends entirely on
the loaded scripts. Values not claimed by any scripts are ignored.

Each use of the `--script-opt` option will add another option to the
internal list, while `--script-opts` takes a list of options at once,
and overwrites the internal list with it. The latter is a key/value list
option. See [List Options](manual-options-track.md) for details.

`--merge-files`

Pretend that all files passed to mpv are concatenated into a single, big
file. This uses timeline/EDL support internally.

`--profile=

`

Use the given profile(s), `--profile=help` displays a list of the
defined profiles.

`--reset-on-next-file=<all|option1,option2,...>`

Normally, mpv will try to keep all settings when playing the next file on
the playlist, even if they were changed by the user during playback. (This
behavior is the opposite of MPlayer's, which tries to reset all settings
when starting next file.)

Default: Do not reset anything.

This can be changed with this option. It accepts a list of options, and
mpv will reset the value of these options on playback start to the initial
value. The initial value is either the default value, or as set by the
config file or command line.

The special name `all` resets as many options as possible.

This is a string list option. See [List Options](manual-options-track.md) for details.

Examples

- `--reset-on-next-file=pause`
Reset pause mode when switching to the next file.

- `--reset-on-next-file=fullscreen,speed`
Reset fullscreen and playback speed settings if they were changed
during playback.

- `--reset-on-next-file=all`
Try to reset all settings that were changed during playback.

`--show-profile=

`

Show the description and content of a profile. Lists all profiles if no
parameter is provided.

`--use-filedir-conf`

Look for a file-specific configuration file in the same directory as the
file that is being played. See [File-specific Configuration Files](manual-configuration-files-1.md).

Warning

May be dangerous if playing from untrusted media.

`--ytdl=<yes|no>`

Enable the youtube-dl hook-script. It will look at the input URL, and will
play the video located on the website. This works with many streaming sites,
not just the one that the script is named after. This requires a recent
version of youtube-dl to be installed on the system (default: yes).

If the script can't do anything with an URL, it will do nothing.

This accepts a set of options, which can be passed to it with the
`--script-opts` option (using `ytdl_hook-` as prefix):

`try_ytdl_first=<yes|no>`

If 'yes' will try parsing the URL with youtube-dl first, instead of the
default where it's only after mpv failed to open it. This mostly depends
on whether most of your URLs need youtube-dl parsing.

