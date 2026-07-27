## Terminal

`--quiet`

Make console output less verbose; in particular, prevents the status line
(i.e. AV: 3.4 (00:00:03.37) / 5320.6 ...) from being displayed.
Particularly useful on slow terminals or broken ones which do not properly
handle carriage return (i.e. `\r`).

See also: `--really-quiet` and `--msg-level`.

`--really-quiet`

Display even less output and status messages than with `--quiet`.

`--terminal=<yes|no>`

`--terminal=no` disables any use of the terminal and stdin/stdout/stderr.
This completely silences any message output.

Unlike `--really-quiet`, this disables input and terminal initialization
as well.

`--msg-color=<yes|no>`

Enable colorful console output on terminals (default: yes).

`--msg-level=<module1=level1,module2=level2,...>`

Control verbosity directly for each module. The `all` module changes the
verbosity of all the modules. The verbosity changes from this option are
applied in order from left to right, and each item can override a previous
one.

Run mpv with `--msg-level=all=trace` to see all messages mpv outputs. You
can use the module names printed in the output (prefixed to each line in
`[...]`) to limit the output to interesting modules.

This also affects `--log-file`, and in certain cases libmpv API logging.

Note

Some messages are printed before the command line is parsed and are
therefore not affected by `--msg-level`. To control these messages,
you have to use the `MPV_VERBOSE` environment variable; see
[ENVIRONMENT VARIABLES](manual-environment-variables.md) for details.

Available levels:

> | no: | complete silence |
| --- | --- |
| fatal: | fatal messages only |
| error: | error messages |
| warn: | warning messages |
| info: | informational messages |
| status: | status messages (default) |
| v: | verbose messages |
| debug: | debug messages |
| trace: | very noisy debug messages |

Example

```
mpv --msg-level=ao/sndio=no
```

Completely silences the output of ao_sndio, which uses the log
prefix `[ao/sndio]`.

```
mpv --msg-level=all=warn,ao/alsa=error
```

Only show warnings or worse, and let the ao_alsa output show errors
only.

`--term-osd=<auto|no|force>`

Control whether OSD messages are shown on the console when no video output
is available (default: auto).
| auto: | use terminal OSD if no video output active |
| --- | --- |
| no: | disable terminal OSD |
| force: | use terminal OSD even if video output active |

The `auto` mode also enables terminal OSD if `--video-osd=no` was set.

`--term-osd-bar=<yes|no>`

Enable printing a progress bar under the status line on the terminal.
(Disabled by default.)

`--term-osd-bar-chars=<string>`

Customize the `--term-osd-bar` feature. The string is expected to
consist of 5 characters (start, left space, position indicator,
right space, end). You can use Unicode characters, but note that double-
width characters will not be treated correctly.

Default: `[-+-]`.

`--term-playing-msg=<string>`

Print out a string after starting playback. The string is expanded for
properties, e.g. `--term-playing-msg='file: ${filename}'` will print the string
`file:` followed by a space and the currently played filename.

See [Property Expansion](manual-property-list-1.md).

`--term-status-msg=<string>`

Print out a custom string during playback instead of the standard status
line. Expands properties. See [Property Expansion](manual-property-list-1.md).

`--term-title=<string>`

Set the terminal title. Currently, this simply concatenates the escape
sequence setting the window title with the provided (property expanded)
string. This will mess up if the expanded string contain bytes that end the
escape sequence, or if the terminal does not understand the sequence. The
latter probably includes the regrettable win32.

Expands properties. See [Property Expansion](manual-property-list-1.md).

`--msg-module`

Prepend module name to each console message.

`--msg-time`

Prepend timing information to each console message. The time is in
seconds since the player process was started (technically, slightly
later actually), using a monotonic time source depending on the OS. This
is `CLOCK_MONOTONIC` on sane UNIX variants.
