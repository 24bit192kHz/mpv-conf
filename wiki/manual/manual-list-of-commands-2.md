### Property Manipulation

`set <name> <value>`

Set the given property or option to the given value.

`del <name>`

Delete the given property. Most properties cannot be deleted.

`add <name> [<value>]`

Add the given value to the property or option. On overflow or underflow,
clamp the property to the maximum. If `<value>` is omitted, assume `1`.

Whether or not key-repeat is enabled by default depends on the property.
Currently properties with continuous values are repeatable by default (like
`volume`), while discrete values are not (like `osd-level`).

This is a scalable command. See the documentation of `nonscalable` input
command prefix in [Input Command Prefixes](manual-input-commands-1.md) for details.

`multiply <name> <value>`

Similar to `add`, but multiplies the property or option with the numeric
value.

`cycle <name> [<value>]`

Cycle the given property or option. The second argument can be `up` or
`down` to set the cycle direction. On overflow, set the property back to
the minimum, on underflow set it to the maximum. If `up` or `down` is
omitted, assume `up`.

Whether or not key-repeat is enabled by default depends on the property.
Currently properties with continuous values are repeatable by default (like
`volume`), while discrete values are not (like `osd-level`).

This is a scalable command. See the documentation of `nonscalable` input
command prefix in [Input Command Prefixes](manual-input-commands-1.md) for details.

`cycle-values [<"!reverse">]

 <value1> [<value2> [...]]`

Cycle through a list of values. Each invocation of the command will set the
given property to the next value in the list. The command will use the
current value of the property/option, and use it to determine the current
position in the list of values. Once it has found it, it will set the
next value in the list (wrapping around to the first item if needed).

This command has a variable number of arguments, and cannot be used with
named arguments.

The special argument `!reverse` can be used to cycle the value list in
reverse. The only advantage is that you don't need to reverse the value
list yourself when adding a second key binding for cycling backwards.

`change-list <name> <operation> <value>`

This command changes list options as described in [List Options](manual-options-track.md). The
`<name>` parameter is the normal option name, while `<operation>` is
the suffix or action used on the option.

Some operations take no value, but the command still requires the value
parameter. In these cases, the value must be an empty string.

Example

`change-list glsl-shaders append file.glsl`

Add a filename to the `glsl-shaders` list. The command line
equivalent is `--glsl-shaders-append=file.glsl` or alternatively
`--glsl-shader=file.glsl`.

### Playlist Manipulation

`playlist-next [<flags>]`

Go to the next entry on the playlist.

First argument:

weak (default)

If the last file on the playlist is currently played, do nothing.

force

Terminate playback if there are no more files on the playlist.

`playlist-prev [<flags>]`

Go to the previous entry on the playlist.

First argument:

weak (default)

If the first file on the playlist is currently played, do nothing.

force

Terminate playback if the first file is being played.

`playlist-next-playlist`

Go to the next entry on the playlist with a different `playlist-path`.

`playlist-prev-playlist`

Go to the first of the previous entries on the playlist with a different
`playlist-path`.

`playlist-play-index <integer|current|none>`

Start (or restart) playback of the given playlist index. In addition to the
0-based playlist entry index, it supports the following values:

<current>

The current playlist entry (as in `playlist-current-pos`) will be
played again (unload and reload). If none is set, playback is stopped.
(In corner cases, `playlist-current-pos` can point to a playlist entry
even if playback is currently inactive,

<none>

Playback is stopped. If idle mode (`--idle`) is enabled, the player
will enter idle mode, otherwise it will exit.

This command is similar to `loadfile` in that it only manipulates the
state of what to play next, without waiting until the current file is
unloaded, and the next one is loaded.

Setting `playlist-pos` or similar properties can have a similar effect to
this command. However, it's more explicit, and guarantees that playback is
restarted if for example the new playlist entry is the same as the previous
one.

`loadfile <url> [<flags> [<index> [<options>]]]`

Load the given file or URL and play it. Technically, this is just a playlist
manipulation command (which either replaces the playlist or adds an entry
to it). Actual file loading happens independently. For example, a
`loadfile` command that replaces the current file with a new one returns
before the current file is stopped, and the new file even begins loading.

Second argument:

<replace> (default)

Stop playback of the current file, and play the new file immediately.

<append>

Append the file to the playlist.

<append-play>

Append the file, and if nothing is currently playing, start playback.
(Always starts with the added file, even if the playlist was not empty
before running this command.)

<insert-next>

Insert the file into the playlist, directly after the current entry.

<insert-next-play>

Insert the file next, and if nothing is currently playing, start playback.
(Always starts with the added file, even if the playlist was not empty
before running this command.)

<insert-at>

Insert the file into the playlist, at the index given in the third
argument.

<insert-at-play>

Insert the file at the index given in the third argument, and if nothing
is currently playing, start playback. (Always starts with the added
file, even if the playlist was not empty before running this command.)

The third argument is an insertion index, used only by the `insert-at` and
`insert-at-play` actions. When used with those actions, the new item will
be inserted at the index position in the playlist, or appended to the end if
index is less than 0 or greater than the size of the playlist. This argument
will be ignored for all other actions. This argument is added in mpv 0.38.0.

The fourth argument is a list of options and values which should be set
while the file is playing. It is of the form `opt1=value1,opt2=value2,..`.
When using the client API, this can be a `MPV_FORMAT_NODE_MAP` (or a Lua
table), however the values themselves must be strings currently. These
