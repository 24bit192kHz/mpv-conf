milliseconds (default: 100). Some Matroska files with ordered chapters
have inaccurate chapter end timestamps, causing a small gap between the
end of one chapter and the start of the next one when they should match.
If the end of one playback part is less than the given threshold away from
the start of the next one then keep playing video normally over the
chapter change instead of doing a seek.

`--chapter-seek-threshold=<seconds>`

Distance in seconds from the beginning of a chapter within which a backward
chapter seek will go to the previous chapter (default: 5.0). Past this
threshold, a backward chapter seek will go to the beginning of the current
chapter instead. A negative value means always go back to the previous
chapter.

`--hr-seek=<no|absolute|yes|default>`

Select when to use precise seeks that are not limited to keyframes. Such
seeks require decoding video from the previous keyframe up to the target
position and so can take some time depending on decoding performance. For
some video formats, precise seeks are disabled. This option selects the
default choice to use for seeks; it is possible to explicitly override that
default in the definition of key bindings and in input commands.
| no: | Never use precise seeks. |
| --- | --- |
| absolute: | Use precise seeks if the seek is to an absolute position in the
file, such as a chapter seek, but not for relative seeks like
the default behavior of arrow keys. |
| default: | Like `absolute`, but enable hr-seeks in audio-only cases. The
exact behavior is implementation specific and may change with
new releases (default). |
| yes: | Use precise seeks whenever possible. |
| always: | Same as `yes` (for compatibility). |

`--hr-seek-demuxer-offset=<seconds>`

This option exists to work around failures to do precise seeks (as in
`--hr-seek`) caused by bugs or limitations in the demuxers for some file
formats. Some demuxers fail to seek to a keyframe before the given target
position, going to a later position instead. The value of this option is
subtracted from the time stamp given to the demuxer. Thus, if you set this
option to 1.5 and try to do a precise seek to 60 seconds, the demuxer is
told to seek to time 58.5, which hopefully reduces the chance that it
erroneously goes to some time later than 60 seconds. The downside of
setting this option is that precise seeks become slower, as video between
the earlier demuxer position and the real target may be unnecessarily
decoded.

`--hr-seek-framedrop=<yes|no>`

Allow the video decoder to drop frames during seek, if these frames are
before the seek target. If this is enabled, precise seeking can be faster,
but if you're using video filters which modify timestamps or add new
frames, it can lead to precise seeking skipping the target frame. This
e.g. can break frame backstepping when deinterlacing is enabled.

Default: `yes`

`--index=<mode>`

Controls how to seek in files. Note that if the index is missing from a
file, it will be built on the fly by default, so you don't need to change
this. But it might help with some broken files.
| default: | use an index if the file has one, or build it if missing |
| --- | --- |
| recreate: | don't read or use the file's index |

Note

This option only works if the underlying media supports seeking
(i.e. not with stdin, pipe, etc).

`--load-unsafe-playlists`

Load URLs from playlists which are considered unsafe (default: no). This
includes special protocols and anything that doesn't refer to normal files.
Local files and HTTP links on the other hand are always considered safe.

In addition, if a playlist is loaded while this is set, the added playlist
entries are not marked as originating from network or potentially unsafe
location. (Instead, the behavior is as if the playlist entries were provided
directly to mpv command line or `loadfile` command.)

`--access-references=<yes|no>`

Follow any references in the file being opened (default: yes). Disabling
this is helpful if the file is automatically scanned (e.g. thumbnail
generation). If the thumbnail scanner for example encounters a playlist
file, which contains network URLs, and the scanner should not open these,
enabling this option will prevent it. This option also disables ordered
chapters, mov reference files, opening of archives, and a number of other
features.

On older FFmpeg versions, this will not work in some cases. Some FFmpeg
demuxers might not respect this option.

This option does not prevent opening of paired subtitle files and such. Use
`--autoload-files=no` to prevent this.

This option does not always work if you open non-files (for example using
`dvd://directory` would open a whole bunch of files in the given
directory). Prefixing the filename with `./` if it doesn't start with
a `/` will avoid this.

`--loop-playlist=<N|inf|force|no>`, `--loop-playlist`

Loops playback `N` times. A value of `1` plays it one time (default),
`2` two times, etc. `inf` means forever. `no` is the same as `1` and
disables looping. If several files are specified on command line, the
entire playlist is looped. `--loop-playlist` is the same as
`--loop-playlist=inf`.

The `force` mode is like `inf`, but does not skip playlist entries
which have been marked as failing. This means the player might waste CPU
time trying to loop a file that doesn't exist. But it might be useful for
playing webradios under very bad network conditions.

`--loop-file=<N|inf|no>`, `--loop=<N|inf|no>`

Loop a single file N times. `inf` means forever, `no` means normal
playback. For compatibility, `--loop-file` and `--loop-file=yes` are
also accepted, and are the same as `--loop-file=inf`.

The difference to `--loop-playlist` is that this doesn't loop the playlist,
just the file itself. If the playlist contains only a single file, the
difference between the two option is that this option performs a seek on
loop, instead of reloading the file.

Note

`--loop-file` counts the number of times it causes the player to
seek to the beginning of the file, not the number of full playthroughs. This
means `--loop-file=1` will end up playing the file twice. Contrast with
`--loop-playlist`, which counts the number of full playthroughs.

`--loop` is an alias for this option.

`--ab-loop-a=<time>`, `--ab-loop-b=<time>`

Set loop points. If playback passes the `b` timestamp, it will seek to
the `a` timestamp. Seeking past the `b` point doesn't loop (this is
intentional).

If `a` is after `b`, the behavior is as if the points were given in
the right order, and the player will seek to `b` after crossing through
`a`. This is different from old behavior, where looping was disabled (and
as a bug, looped back to `a` on the end of the file).

If either options are set to `no` (or unset), looping is disabled. This
is different from old behavior, where an unset `a` implied the start of
the file, and an unset `b` the end of the file.

The loop-points can be adjusted at runtime with the corresponding
properties. See also `ab-loop` command.

`--ab-loop-count=<N|inf>`

Run A-B loops only N times, then ignore the A-B loop points (default: inf).
`inf` means that looping goes on forever. If this option is set to 0, A-B
looping is ignored, and even the `ab-loop` command will not enable looping
again (the command will show `(disabled)` on the OSD message if both loop
points are set, but `ab-loop-count` is 0).

`--ordered-chapters=<yes|no>`

Enable support for Matroska ordered chapters. mpv will load and
search for video segments from other files, and will also respect any
chapter order specified for the main file (default: yes).

`--ordered-chapters-files=

`

Loads the given file as playlist, and tries to use the files contained in
it as reference files when opening a Matroska file that uses ordered
chapters. This overrides the normal mechanism for loading referenced
files by scanning the same directory the main file is located in.

Useful for loading ordered chapter files that are not located on the local
filesystem, or if the referenced files are in different directories.

Note: a playlist can be as simple as a text file containing filenames
separated by newlines.

`--chapters-file=<filename>`

Load chapters from this file, instead of using the chapter metadata found
in the main file.

This accepts a media file (like mkv) or even a pseudo-format like ffmetadata
and uses its chapters to replace the current file's chapters. This doesn't
work with OGM or XML chapters directly.

`--sstep=<sec>`

