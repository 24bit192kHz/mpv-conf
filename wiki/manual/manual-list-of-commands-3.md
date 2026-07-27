options are set during playback, and restored to the previous value at end
of playback (see [Per-File Options](manual-usage-1.md)).

Warning

Since mpv 0.38.0, an insertion index argument is added as the third argument.
This breaks all existing uses of this command which make use of the argument
to include the list of options to be set while the file is playing. To address
this problem, the third argument now needs to be set to -1 if the fourth
argument needs to be used.

`loadlist <url> [<flags> [<index>]]`

Load the given playlist file or URL (like `--playlist`).

Second argument:

<replace> (default)

Stop playback and replace the internal playlist with the new one.

<append>

Append the new playlist at the end of the current internal playlist.

<append-play>

Append the new playlist, and if nothing is currently playing, start
playback. (Always starts with the new playlist, even if the internal
playlist was not empty before running this command.)

<insert-next>

Insert the new playlist into the current internal playlist, directly
after the current entry.

<insert-next-play>

Insert the new playlist, and if nothing is currently playing, start
playback. (Always starts with the new playlist, even if the internal
playlist was not empty before running this command.)

<insert-at>

Insert the new playlist at the index given in the third argument.

<insert-at-play>

Insert the new playlist at the index given in the third argument, and if
nothing is currently playing, start playback. (Always starts with the
new playlist, even if the internal playlist was not empty before running
this command.)

The third argument is an insertion index, used only by the `insert-at` and
`insert-at-play` actions. When used with those actions, the new playlist
will be inserted at the index position in the internal playlist, or appended
to the end if index is less than 0 or greater than the size of the internal
playlist. This argument will be ignored for all other actions.

`playlist-clear`

Clear the playlist, except the currently played file.

`playlist-remove <index>`

Remove the playlist entry at the given index. Index values start counting
with 0. The special value `current` removes the current entry. Note that
removing the current entry also stops playback and starts playing the next
entry.

`playlist-move <index1> <index2>`

Move the playlist entry at index1, so that it takes the place of the
entry index2. (Paradoxically, the moved playlist entry will not have
the index value index2 after moving if index1 was lower than index2,
because index2 refers to the target entry, not the index the entry
will have after moving.)

`playlist-shuffle`

Shuffle the playlist. This is similar to what is done on start if the
`--shuffle` option is used.

`playlist-unshuffle`

Attempt to revert the previous `playlist-shuffle` command. This works
only once (multiple successive `playlist-unshuffle` commands do nothing).
May not work correctly if new recursive playlists have been opened since
a `playlist-shuffle` command.

### Track Manipulation

`sub-add <url> [<flags> [<title> [<lang>]]]`

Load the given subtitle file or stream. By default, it is selected as
current subtitle  after loading.

The `flags` argument is one of the following values:

<select>

> Select the subtitle immediately (default).

<auto>

> Don't select the subtitle. (Or in some special situations, let the
> default stream selection mechanism decide.)

<cached>

> Select the subtitle. If a subtitle with the same filename was already
> added, that one is selected, instead of loading a duplicate entry.
> (In this case, title/language are ignored, and if the was changed since
> it was loaded, these changes won't be reflected.)

Additionally the following flags can be added with a `+`:

<hearing-impaired>

> Marks the track as suitable for the hearing impaired.

<visual-impaired>

> Marks the track as suitable for the visually impaired.

<forced>

> Marks the track as forced.

<default>

> Marks the track as default.

<attached-picture> (only for `video-add`)

> Marks the track as an attached picture, same as `albumart` argument
> for ``video-add`.

The `title` argument sets the track title in the UI.

The `lang` argument sets the track language, and can also influence
stream selection with `flags` set to `auto`.

`sub-remove [<id>]`

Remove the given subtitle track. If the `id` argument is missing, remove
the current track. (Works on external subtitle files only.)

`sub-reload [<id>]`

Reload the given subtitle tracks. If the `id` argument is missing, reload
the current track. (Works on external subtitle files only.)

This works by unloading and re-adding the subtitle track.

`sub-step <skip> [<flags>]`

Change subtitle timing such, that the subtitle event after the next
`<skip>` subtitle events is displayed. `<skip>` can be negative to step
backwards.

Secondary argument:

primary (default)

Steps through the primary subtitles.

secondary

Steps through the secondary subtitles.

`audio-add <url> [<flags> [<title> [<lang>]]]`

Load the given audio file. See `sub-add` command.

`audio-remove [<id>]`

Remove the given audio track. See `sub-remove` command.

`audio-reload [<id>]`

Reload the given audio tracks. See `sub-reload` command.

`video-add <url> [<flags> [<title> [<lang> [<albumart>]]]]`

Load the given video file. See `sub-add` command for common options.

`albumart` (`MPV_FORMAT_FLAG`)

If enabled, mpv will load the given video as album art.

`video-remove [<id>]`

Remove the given video track. See `sub-remove` command.

