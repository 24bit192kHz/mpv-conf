## Miscellaneous

`--display-tags=tag1,tags2,...`

Set the list of tags that should be displayed on the terminal and stats.
Tags that are in the list, but are not present in the played file, will not
be shown. If a value ends with `*`, all tags are matched by prefix (though
there is no general globbing). Just passing `*` essentially filtering.

The default includes a common list of tags, call mpv with `--list-options`
to see it.

This is a string list option. See [List Options](manual-options-track.md) for details.

`--mf-fps=<value>`

Framerate used when decoding from multiple PNG or JPEG files with `mf://`
(default: 1).

`--mf-type=<value>`

Input file type for `mf://` (available: jpeg, png, tga, sgi). By default,
this is guessed from the file extension.

`--stream-dump=<destination-filename>`

Instead of playing a file, read its byte stream and write it to the given
destination file. The destination is overwritten. Can be useful to test
network-related behavior.

`--stream-lavf-o=opt1=value1,opt2=value2,...`

Set AVOptions on streams opened with libavformat. Unknown or misspelled
options are silently ignored. (They are mentioned in the terminal output
in verbose mode, i.e. `--v`. In general we can't print errors, because
other options such as e.g. user agent are not available with all protocols,
and printing errors for unknown options would end up being too noisy.)

This is a key/value list option. See [List Options](manual-options-track.md) for details.

`--backdrop-type=<auto|none|mica|acrylic|mica-alt>`

(Windows only)
Controls the backdrop/border style.
| auto: | Default Windows behavior |
| --- | --- |
| none: | The backdrop will be black or white depending on the system's theme settings. |
| mica: | Enables the Mica style, which is the default on Windows 11. |
| acrylic: | Enables the Acrylic style (frosted glass look). |
| mica-alt: | Same as Mica, except reversed. |

`--window-affinity=<default|excludefromcmcapture|monitor>`

(Windows only)
Controls the window affinity behavior of mpv.
| default: | Default Windows behavior |
| --- | --- |
| excludefromcapture: |
|  | mpv's window will be completely excluded from capture by external applications or screen recording software. |
| monitor: | Blacks out the mpv window |

`--vo-mmcss-profile=<name>`

(Windows only)
Set the MMCSS profile for the video renderer thread (default: `Playback`).

`--priority=

`

(Windows only)
Set process priority for mpv according to the predefined priorities
available under Windows.

Possible values of `

`:
idle|belownormal|normal|abovenormal|high|realtime

Warning

Using realtime priority can cause system lockup.

`--media-controls=<yes|no>`

(Windows only)
Enable integration of media control interface SystemMediaTransportControls.

Windows may display "Unknown app" or show a missing mpv icon in the media
control panel. To fully support it, you need to register mpv using the
`--register` command.

Default: yes (except for libmpv)

`--force-media-title=<string>`

Force the contents of the `media-title` property to this value. Useful
for scripts which want to set a title, without overriding the user's
setting in `--title`.

`--external-files=<file-list>`

Load a file and add all of its tracks. This is useful to play different
files together (for example audio from one file, video from another), or
for advanced `--lavfi-complex` used (like playing two video files at
the same time).

Unlike `--sub-files` and `--audio-files`, this includes all tracks, and
does not cause default stream selection over the "proper" file. This makes
it slightly less intrusive. (In mpv 0.28.0 and before, this was not quite
strictly enforced.)

This is a path list option. See [List Options](manual-options-track.md) for details.

`--external-file=<file>`

CLI/config file only alias for `--external-files-append`. Each use of this
option will add a new external file.

`--cover-art-files=<file-list>`

Use an external file as cover art while playing audio. This makes it appear
on the track list and subject to automatic track selection. Options like
`--audio-display` control whether such tracks are supposed to be selected.

(The difference to loading a file with `--external-files` is that video
tracks will be marked as being pictures, which affects the auto-selection
method. If the passed file is a video, only the first frame will be decoded
and displayed. Enabling the cover art track during playback may show a
random frame if the source file is a video. Normally you're not supposed to
pass videos to this option, so this paragraph describes the behavior
coincidentally resulting from implementation details.)

This is a path list option. See [List Options](manual-options-track.md) for details.

`--cover-art-file=<file>`

CLI/config file only alias for `--cover-art-files-append`. Each use of this
option will add a new external file.

`--cover-art-auto=<no|exact|fuzzy|all>`

Whether to load _external_ cover art automatically. Similar to
`--sub-auto` and `--audio-file-auto`. If a video already has tracks
(which are not marked as cover art), external cover art will not be loaded.
| no: | Don't automatically load cover art. |
| --- | --- |
| exact: | Load the media filename with an image file extension (default). |
| fuzzy: | Load all cover art containing the media filename. |
| all: | Load all images in the current directory. |

See `--cover-art-files` for details about what constitutes cover art.

See `--audio-display` how to control display of cover art (this can be
used to disable cover art that is part of the file).

`--image-exts=ext1,ext2,...`

Image file extensions to try to match when using `--cover-art-auto`,
`--autocreate-playlist` or `--directory-filter-types`.

This is a string list option. See [List Options](manual-options-track.md) for details.
Use `--help=image-exts` to see default extensions.

`--cover-art-whitelist=filename1,filename2,...`

Filenames to load as cover art, sorted by descending priority. They are
combined with the extensions in `--image-exts`. This has no
effect if `cover-art-auto` is `no`.

Default: `AlbumArt,Album,cover,front,AlbumArtSmall,Folder,.folder,thumb`

This is a string list option. See [List Options](manual-options-track.md) for details.

`--video-exts=ext1,ext2,...`

Video file extensions to try to match when using `--autocreate-playlist` or
`--directory-filter-types`.

This is a string list option. See [List Options](manual-options-track.md) for details.
Use `--help=video-exts` to see default extensions.

`--archive-exts=ext1,ext2,...`

Archive file extensions to try to match when using `--autocreate-playlist`
or `--directory-filter-types`.

This is a string list option. See [List Options](manual-options-track.md) for details. Use
`--help=archive-exts` to see the default extensions.

`--playlist-exts=ext1,ext2,...`

Playlist file extensions to try to match when using
`--autocreate-playlist` or `--directory-filter-types`.

