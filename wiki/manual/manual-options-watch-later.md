## Watch Later

`--save-position-on-quit`

Always save the current playback position on quit, and also when the
`loadfile` command is used to replace the current playlist. When this file
is played again later, the player will seek to the old playback position on
start. This does not happen if playback of a file is stopped in other ways.
For example, going to the next file in the playlist will not save the
position, and will start playback at beginning the next time the file is
played.

This behavior is disabled by default, but is always available when quitting
the player with Shift+Q.

See [RESUMING PLAYBACK](manual-resuming-playback.md).

`--watch-later-dir=

`

The directory in which to store the "watch later" temporary files.

`--watch-later-directory` is an alias for `--watch-later-dir`.

If this option is unset, the files will be stored in a subdirectory
named "watch_later" underneath the local state directory
(usually `~/.local/state/mpv/`).

`--resume-playback=<yes|no>`

Restore playback position from the `watch_later` configuration
subdirectory, usually `~/.config/mpv/watch_later/` (default: yes).

`--resume-playback-check-mtime=<yes|no>`

Only restore the playback position from the `watch_later` configuration
subdirectory (usually `~/.config/mpv/watch_later/`) if the file's
modification time is the same as at the time of saving. This may prevent
skipping forward in files with the same name which have different content.
(Default: `no`)

`--watch-later-options=option1,option2,...`

The options that are saved in "watch later" files if they have been changed
since when mpv started. These values will be restored the next time the
files are played. Note that the playback position is saved via the `start`
option.

When removing options, existing watch later data won't be modified and will
still be applied fully, but new watch later data won't contain these
options.

See `--help=watch-later-options` for the list of the properties that are
restored by default.

This is a string list option. See [List Options](manual-options-track.md) for details.

Examples

- `--watch-later-options-remove=sid`
The subtitle track selection will not be restored.

- `--watch-later-options-remove=volume`
`--watch-later-options-remove=mute`
The volume and mute state won't be saved to watch later files.

- `--watch-later-options=start`
No option will be saved to watch later files, except the playback
position.

`--write-filename-in-watch-later-config`

Prepend the watch later config files with the name of the file they refer
to. This is simply written as comment on the top of the file.

Warning

This option may expose privacy-sensitive information and is thus
disabled by default.

`--ignore-path-in-watch-later-config`

Ignore path (i.e. use filename only) when using watch later feature.
(Default: disabled)

## Watch History

`--save-watch-history`

Whether to save which files are played. These can be then selected with the
default `g-h` key binding.

Warning

This option may expose privacy-sensitive information and is thus
disabled by default.

`--watch-history-path=

`

The path in which to store the watch history. Default:
`~~state/watch_history.jsonl` (see [FILES](manual-files.md)).

This file contains one JSON object per line. Its `time` field is the UNIX
timestamp when the file was opened, its `path` field is the normalized
path, and its `title` field is the title when it was available.
