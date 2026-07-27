# FILES

Note that this section assumes Linux/BSD. On other platforms the paths may be different.
For Windows-specifics, see [FILES ON WINDOWS](manual-files-on-windows.md) section.

All configuration files should be encoded in UTF-8.

`/usr/local/etc/mpv/mpv.conf`

mpv system-wide settings (depends on `--prefix` passed to configure - mpv
in default configuration will use `/usr/local/etc/mpv/` as config
directory, while most Linux distributions will set it to `/etc/mpv/`).

`~/.cache/mpv`

The standard cache directory. Certain options within mpv may cause it to write
cache files to disk. This can be overridden by environment variables, in
ascending order:
| 1: | If `$XDG_CACHE_HOME` is set, then the derived cache directory
will be `$XDG_CACHE_HOME/mpv`. |
| --- | --- |
| 2: | If `$MPV_HOME` is set, then the derived cache directory will be
`$MPV_HOME`. |

If the directory does not exist, mpv will try to create it automatically.

`~/.config/mpv`

The standard configuration directory. This can be overridden by environment
variables, in ascending order:
| 1: | If `$XDG_CONFIG_HOME` is set, then the derived configuration directory
will be `$XDG_CONFIG_HOME/mpv`. |
| --- | --- |
| 2: | If `$MPV_HOME` is set, then the derived configuration directory will be
`$MPV_HOME`. |

If this directory, nor the original configuration directory (see below) do
not exist, mpv tries to create this directory automatically.

`~/.mpv/`

The original (pre 0.5.0) configuration directory. It will continue to be
read if present. If this directory is present and the standard configuration
directory is not present, then cache files and watch later config files will
also be written to this directory.

If both this directory and the standard configuration directory are
present, configuration will be read from both with the standard
configuration directory content taking precedence. However, you should
fully migrate to the standard directory and a warning will be shown in
this situation.

`~/.config/mpv/mpv.conf`

mpv user settings (see [CONFIGURATION FILES](manual-configuration-files-1.md) section)

`~/.config/mpv/input.conf`

key bindings (see [INPUT.CONF](manual-input-conf.md) section)

`~/.config/mpv/fonts.conf`

Fontconfig fonts.conf that is customized for mpv. You should include system
fonts.conf in this file or mpv would not know about fonts that you already
have in the system.

Only available when libass is built with fontconfig.

`~/.config/mpv/subfont.ttf`

fallback subtitle font

`~/.config/mpv/fonts/`

Default location for `--sub-fonts-dir` (see [Subtitles](manual-options-subtitles-1.md)) and
`--osd-fonts-dir` (see [OSD](manual-options-osd-1.md)).

`~/.config/mpv/scripts/`

All files in this directory are loaded as if they were passed to the
`--script` option. They are loaded in alphabetical order.

The `--load-scripts=no` option disables loading these files.

See [Script location](manual-lua-scripting-1.md) for details.

`~/.local/state/mpv/watch_later/`

Contains temporary config files needed for resuming playback of files with
the watch later feature. See for example the `Q` key binding, or the
`quit-watch-later` input command.

This can be overridden by environment variables, in ascending order:
| 1: | If `$XDG_STATE_HOME` is set, then the derived watch later directory
will be `$XDG_STATE_HOME/mpv/watch_later`. |
| --- | --- |
| 2: | If `$MPV_HOME` is set, then the derived watch later directory will be
`$MPV_HOME/watch_later`. |

Each file is a small config file which is loaded if the corresponding media
file is loaded. It contains the playback position and some (not necessarily
all) settings that were changed during playback. The filenames are hashed
from the full paths of the media files. It's in general not possible to
extract the media filename from this hash. However, you can set the
`--write-filename-in-watch-later-config` option, and the player will
add the media filename to the contents of the resume config file.

`~/.config/mpv/script-opts/osc.conf`

This is loaded by the OSC script. See the [ON SCREEN CONTROLLER](manual-on-screen-controller-1.md) docs
for details.

Other files in this directory are specific to the corresponding scripts
as well, and the mpv core doesn't touch them.
