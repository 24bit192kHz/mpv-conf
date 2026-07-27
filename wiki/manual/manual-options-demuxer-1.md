## Demuxer

`--demuxer=<[+]name>`

Force demuxer type. Use a '+' before the name to force it; this will skip
some checks. Give the demuxer name as printed by `--demuxer=help`.

`--demuxer-lavf-analyzeduration=<value>`

Maximum length in seconds to analyze the stream properties.

`--demuxer-lavf-probe-info=<yes|no|auto|nostreams>`

Whether to probe stream information (default: auto). Technically, this
controls whether libavformat's `avformat_find_stream_info()` function
is called. Usually it's safer to call it, but it can also make startup
slower.

The `auto` choice (the default) tries to skip this for a few know-safe
whitelisted formats, while calling it for everything else.

The `nostreams` choice only calls it if and only if the file seems to
contain no streams after opening (helpful in cases when calling the function
is needed to detect streams at all, such as with FLV files).

`--demuxer-lavf-probescore=<1-100>`

Minimum required libavformat probe score. Lower values will require
less data to be loaded (makes streams start faster), but makes file
format detection less reliable. Can be used to force auto-detected
libavformat demuxers, even if libavformat considers the detection not
reliable enough. (Default: 26.)

`--demuxer-lavf-allow-mimetype=<yes|no>`

Allow deriving the format from the HTTP MIME type (default: yes). Set
this to no in case playing things from HTTP mysteriously fails, even
though the same files work from local disk.

This is default in order to reduce latency when opening HTTP streams.

`--demuxer-lavf-format=<name>`

Force a specific libavformat demuxer.

`--demuxer-lavf-hacks=<yes|no>`

By default, some formats will be handled differently from other formats
by explicitly checking for them. Most of these compensate for weird or
imperfect behavior from libavformat demuxers. Passing `no` disables
these. For debugging and testing only.

`--demuxer-lavf-o=<key>=<value>[,<key>=<value>[,...]]`

Pass AVOptions to libavformat demuxer.

Note, a patch to make the *o=* unneeded and pass all unknown options
through the AVOption system is welcome. A full list of AVOptions can
be found in the FFmpeg manual. Note that some options may conflict
with mpv options.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

Example

`--demuxer-lavf-o=fflags=+ignidx`

`--demuxer-lavf-probesize=<value>`

Maximum amount of data to probe during the detection phase. In the
case of MPEG-TS this value identifies the maximum number of TS packets
to scan.

`--demuxer-lavf-buffersize=<value>`

Size of the stream read buffer allocated for libavformat in bytes
(default: 32768). Lowering the size could lower latency. Note that
libavformat might reallocate the buffer internally, or not fully use all
of it.

`--demuxer-lavf-linearize-timestamps=<yes|no|auto>`

Attempt to linearize timestamp resets in demuxed streams (default: auto).
This was tested only for single audio streams. It's unknown whether it
works correctly for video (but likely won't). Note that the implementation
is slightly incorrect either way, and will introduce a discontinuity by
about 1 codec frame size.

The `auto` mode enables this for OGG audio stream. This covers the common
and annoying case of OGG web radio streams. Some of these will reset
timestamps to 0 every time a new song begins. This breaks the mpv seekable
cache, which can't deal with timestamp resets. Note that FFmpeg/libavformat's
seeking API can't deal with this either; it's likely that if this option
breaks this even more, while if it's disabled, you can at least seek within
the first song in the stream. Well, you won't get anything useful either
way if the seek is outside of mpv's cache.

`--demuxer-lavf-propagate-opts=<yes|no>`

Propagate FFmpeg-level options to recursively opened connections (default:
yes). This is needed because FFmpeg will apply these settings to nested
AVIO contexts automatically. On the other hand, this could break in certain
situations - it's the FFmpeg API, you just can't win.

This affects in particular the `--timeout` option and anything passed
with `--demuxer-lavf-o`.

If this option is deemed unnecessary at some point in the future, it will
be removed without notice.

`--demuxer-mkv-subtitle-preroll=<yes|index|no>`

Try harder to show embedded soft subtitles when seeking somewhere. Normally,
it can happen that the subtitle at the seek target is not shown due to how
some container file formats are designed. The subtitles appear only if
seeking before or exactly to the position a subtitle first appears. To
make this worse, subtitles are often timed to appear a very small amount
before the associated video frame, so that seeking to the video frame
typically does not demux the subtitle at that position.

Enabling this option makes the demuxer start reading data a bit before the
seek target, so that subtitles appear correctly. Note that this makes
seeking slower, and is not guaranteed to always work. It only works if the
subtitle is close enough to the seek target.

Works with the internal Matroska demuxer only. Always enabled for absolute
and hr-seeks, and this option changes behavior with relative or imprecise
seeks only.

You can use the `--demuxer-mkv-subtitle-preroll-secs` option to specify
how much data the demuxer should pre-read at most in order to find subtitle
packets that may overlap. Setting this to 0 will effectively disable this
preroll mechanism. Setting a very large value can make seeking very slow,
and an extremely large value would completely reread the entire file from
start to seek target on every seek - seeking can become slower towards the
end of the file. The details are messy, and the value is actually rounded
down to the cluster with the previous video keyframe.

Some files, especially files muxed with newer mkvmerge versions, have
information embedded that can be used to determine what subtitle packets
overlap with a seek target. In these cases, mpv will reduce the amount
of data read to a minimum. (Although it will still read *all* data between
the cluster that contains the first wanted subtitle packet, and the seek
target.) If the `index` choice (which is the default) is specified, then
prerolling will be done only if this information is actually available. If
this method is used, the maximum amount of data to skip can be additionally
controlled by `--demuxer-mkv-subtitle-preroll-secs-index` (it still uses
the value of the option without `-index` if that is higher).

See also `--hr-seek-demuxer-offset` option. This option can achieve a
similar effect, but only if hr-seek is active. It works with any demuxer,
but makes seeking much slower, as it has to decode audio and video data
instead of just skipping over it.

`--demuxer-mkv-subtitle-preroll-secs=<value>`

See `--demuxer-mkv-subtitle-preroll`.

`--demuxer-mkv-subtitle-preroll-secs-index=<value>`

See `--demuxer-mkv-subtitle-preroll`.

`--demuxer-mkv-probe-start-time=<yes|no>`

Check the start time of Matroska files (default: yes). This simply reads the
first cluster timestamps and assumes it is the start time. Technically, this
also reads the first timestamp, which may increase latency by one frame
(which may be relevant for live streams).

`--demuxer-mkv-probe-video-duration=<yes|no|full>`

When opening the file, seek to the end of it, and check what timestamp the
last video packet has, and report that as file duration. This is strictly
for compatibility with Haali only. In this mode, it's possible that opening
will be slower (especially when playing over http), or that behavior with
broken files is much worse. So don't use this option.

The `yes` mode merely uses the index and reads a small number of blocks
from the end of the file. The `full` mode actually traverses the entire
file and can make a reliable estimate even without an index present (such
as partial files).

`--demuxer-mkv-crop-compat=<yes|no>`

Enable compatibility mode for files that do not fully comply with the
Matroska specification. (default: yes)

Most files containing cropping metadata require this mode to display correctly.

If this option is enabled, crop metadata will be applied before calculating
the video's aspect ratio, ensuring it is cropped accordingly. If this option
is disabled, the image will be cropped first and then stretched to match
DisplayWidth and DisplayHeight.

According to the Matroska specification, the Pixel Aspect Ratio (PAR) should
