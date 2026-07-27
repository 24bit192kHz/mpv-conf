This is a string list option. See [List Options](manual-options-track.md) for details. Use
`--help=playlist-exts` to see the default extensions.

`--autoload-files=<yes|no>`

Automatically load/select external files (default: yes).

If set to `no`, then do not automatically load external files as specified
by `--sub-auto`, `--audio-file-auto` and `--cover-art-auto`. If
external files are forcibly added (like with `--sub-files`), they will
not be auto-selected.

This does not affect playlist expansion, redirection, or other loading of
referenced files like with ordered chapters.

`--stream-record=<file>`

Write received/read data from the demuxer to the given output file. The
output file will always be overwritten without asking. The output format
is determined by the extension of the output file.

Switching streams or seeking during recording might result in recording
being stopped and/or broken files. Use with care.

Seeking outside of the demuxer cache will result in "skips" in the output
file, but seeking within  the demuxer cache should not affect recording. One
exception is when you seek back far enough to exceed the forward buffering
size, in which case the cache stops actively reading. This will return in
dropped data if it's a live stream.

If this is set at runtime, the old file is closed, and the new file is
opened. Note that this will write only data that is appended at the end of
the cache, and the already cached data cannot be written. You can try the
`dump-cache` command as an alternative.

External files (`--audio-file` etc.) are ignored by this, it works on the
"main" file only. Using this with files using ordered chapters or EDL files
will also not work correctly in general.

There are some glitches with this because it uses FFmpeg's libavformat for
writing the output file. For example, it's typical that it will only work if
the output format is the same as the input format. This is the case even if
it works with the `ffmpeg` tool. One reason for this is that `ffmpeg`
and its libraries contain certain hacks and workarounds for these issues,
that are unavailable to outside users.

`--lavfi-complex=<string>`

Set a "complex" libavfilter filter, which means a single filter graph can
take input from multiple source audio and video tracks. The graph can result
in a single audio or video output (or both).

Currently, the filter graph labels are used to select the participating
input tracks and audio/video output. The following rules apply:

- A label of the form `aidN` selects audio track N as input (e.g.
`aid1`).

- A label of the form `vidN` selects video track N as input.

- A label named `ao` will be connected to the audio output.

- A label named `vo` will be connected to the video output.

Each label can be used only once. If you want to use e.g. an audio stream
for multiple filters, you need to use the `asplit` filter. Multiple
video or audio outputs are not possible, but you can use filters to merge
them into one.

It's not possible to change the tracks connected to the filter at runtime,
unless you explicitly change the `lavfi-complex` property and set new
track assignments. When the graph is changed, the track selection is changed
according to the used labels as well.

Other tracks, as long as they're not connected to the filter, and the
corresponding output is not connected to the filter, can still be freely
changed with the normal methods.

Note that the normal filter chains (`--af`, `--vf`) are applied between
the complex graphs (e.g. `ao` label) and the actual output.

Examples

- `--lavfi-complex='[aid1] [aid2] amix [ao]'`
Play audio track 1 and 2 at the same time.

- `--lavfi-complex='[vid1] [vid2] vstack [vo]'`
Stack video track 1 and 2 and play them at the same time. Note that
both tracks need to have the same width, or filter initialization
will fail (you can add `scale` filters before the `vstack` filter
to fix the size).
To load a video track from another file, you can use
`--external-file=other.mkv`.

- `--lavfi-complex='[vid1] [vid2] [vid3] hstack=inputs=3 [vo]'`
Use the inputs option to stack more than 2 tracks.

- `--lavfi-complex='[aid1] asplit [t1] [ao] ; [t1] showvolume [t2] ; [vid1] [t2] overlay [vo]'`
Play audio track 1, and overlay the measured volume for each speaker
over video track 1.

See the FFmpeg libavfilter documentation for details on the available
filters.

`--metadata-codepage=<codepage>`

Codepage for various input metadata (default: `auto`). This affects how
file tags, chapter titles, etc. are interpreted. In most cases, this merely
evaluates to UTF-8 as non-UTF-8 codepages are obscure.

See `--sub-codepage` option on how codepages are specified and further
details regarding autodetection and codepage conversion. (The underlying
code is the same.)

Conversion is not applied to metadata that is updated at runtime.

`--clipboard-backends=<backend1,backend2,...[,]>`

Specify a priority list of the clipboard backends to be used.
You can also pass `help` to get a complete list of compiled in backends.

If the list is not empty, it enables native clipboard support for the
specified backends. This allows reading and writing to the `clipboard`
property to get and set clipboard contents.

Native clipboard support is enabled by default. To disable this, remove
all backends in this list with `--clipboard-backends-clr`.

Note that the default clipboard backends are subject to change,
and must not be relied upon.

The following clipboard backends are implemented:

`win32`

Windows backend.

`mac`

macOS backend.

`x11`

X11 backend. This backend is only available if the X server
supports the `Xfixes` extension.

`wayland`

Wayland backend. This backend is only available if the compositor
supports the `ext-data-control-v1` protocol.

`vo`

VO backend. Requires an active VO window, and support differs across
platforms. Currently, this is used as a fallback for Wayland
compositors without support for the `ext-data-control-v1`
protocol, or if the `wayland` backend is disabled.

This is an object settings list option. See [List Options](manual-options-track.md) for details.

`--clipboard-monitor=<yes|no>`

Enable clipboard monitoring so that the `clipboard` property can be
observed for content changes (default: no). This only affects clipboard
implementations which use polling to monitor clipboard updates.
Other platforms currently ignore this option and always/never notify
changes.

On Wayland, this option only has effect on the `wayland` backend, and
not for the `vo` backend. See `current-clipboard-backend` property for
more details.

`--clipboard-xwayland=<yes|no>`

Enable X11 clipboard backend in suspected Wayland environments
(default: no).

Depending on the Wayland compositor, using X11 backend may result in mpv
unable to acquire clipboard data from native Wayland clients. Disabling the
X11 backend when Wayland backend is unavailable makes mpv fallback to the
VO backend which allows clipboard to work properly.

`--register`

(Windows only) (available also as mpv-register helper)

Registers mpv as a media player on Windows. This includes adding registry
entries to associate mpv with media files and protocols, as well as enabling
autoplay handlers for Blu-ray, DVD, and CD-Audio.

Note that the registration is done in-place, so the current mpv.exe path will
be used. If you move mpv after registering it, you can re-run this command to
update the registry entries. You can also `--unregister` at any time and
using any mpv binary that supports this command, it doesn't have to be
specifically the one that was used to register it.
