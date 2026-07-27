`video-reload [<id>]`

Reload the given video tracks. See `sub-reload` command.

`rescan-external-files [<mode>]`

Rescan external files according to the current `--sub-auto`,
`--audio-file-auto` and `--cover-art-auto` settings. This can be used
to auto-load external files *after* the file was loaded.

The `mode` argument is one of the following:

<reselect> (default)

Select the default audio and subtitle streams, which typically selects
external files with the highest preference. (The implementation is not
perfect, and could be improved on request.)

<keep-selection>

Do not change current track selections.

### Text Manipulation

`print-text <text>`

Print text to stdout. The string can contain properties (see
[Property Expansion](manual-property-list-1.md)). Take care to put the argument in quotes.

`expand-text <text>`

Property-expand the argument and return the expanded string. This can be
used only through the client API or from a script using
`mp.command_native`. (see [Property Expansion](manual-property-list-1.md)).

`expand-path <text>`

Expand a path's double-tilde placeholders into a platform-specific path.
As `expand-text`, this can only be used through the client API or from
a script using `mp.command_native`.

Example

`mp.osd_message(mp.command_native({"expand-path", "~~home/"}))`

This line of Lua would show the location of the user's mpv
configuration directory on the OSD.

`normalize-path <filename>`

Return a canonical representation of the path `filename` by converting it
to an absolute path, removing consecutive slashes, removing `.`
components, resolving `..` components, and converting slashes to
backslashes on Windows. Symlinks are not resolved unless the platform is
Unix-like and one of the path components is `..`. If `filename` is a
URL, it is returned unchanged. This can only be used through the client API
or from a script using `mp.command_native`.

Example

`mp.osd_message(mp.command_native({"normalize-path", "/foo//./bar"}))`

This line of Lua prints "/foo/bar" on the OSD.

`escape-ass <text>`

Modify `text` so that commands and functions that interpret ASS tags,
such as `osd-overlay` and `mp.create_osd_overlay`, will display it
verbatim, and return it. This can only be used through the client API or
from a script using `mp.command_native`.

Example

`mp.osd_message(mp.command_native({"escape-ass", "foo {bar}"}))`

This line of Lua prints "foo \{bar}" on the OSD.

### Configuration Commands

`apply-profile <name> [<mode>]`

Apply the contents of a named profile. This is like using `profile=name`
in a config file, except you can map it to a key binding to change it at
runtime.

The mode argument:

`apply`

Apply the profile. Default if the argument is omitted.

`restore`

Restore options set by a previous `apply-profile` command for this
profile. Only works if the profile has `profile-restore` set to a
relevant mode. Prints a warning if nothing could be done. See
[Runtime profiles](manual-configuration-files-1.md) for details.

`load-config-file <filename>`

Load a configuration file, similar to the `--include` option. If the file
was already included, its previous options are not reset before it is
reparsed.

`write-watch-later-config`

Write the resume config file that the `quit-watch-later` command writes,
but continue playback normally.

`delete-watch-later-config [<filename>]`

Delete any existing resume config file that was written by
`quit-watch-later` or `write-watch-later-config`. If a filename is
specified, then the deleted config is for that file; otherwise, it is the
same one as would be written by `quit-watch-later` or
`write-watch-later-config` in the current circumstance.

