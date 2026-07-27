
`--vd-lavc-bitexact`

Only use bit-exact algorithms in all decoding steps (for codec testing).

`--vd-lavc-fast` (MPEG-1/2 and H.264 only)

Enable optimizations which do not comply with the format specification and
potentially cause problems, like simpler dequantization, simpler motion
compensation, assuming use of the default quantization matrix, assuming YUV
4:2:0 and skipping a few checks to detect damaged bitstreams.

`--vd-lavc-o=<key>=<value>[,<key>=<value>[,...]]`

Pass AVOptions to libavcodec decoder. Note, a patch to make the `o=`
unneeded and pass all unknown options through the AVOption system is
welcome. A full list of AVOptions can be found in the FFmpeg manual.

Some options which used to be direct options can be set with this
mechanism, like `bug`, `gray`, `idct`, `ec`, `vismv`,
`skip_top` (was `st`), `skip_bottom` (was `sb`), `debug`.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

Example

`--vd-lavc-o=debug=pict`

`--vd-lavc-show-all=<yes|no>`

Show even broken/corrupt frames (default: no). If this option is set to
no, libavcodec won't output frames that were either decoded before an
initial keyframe was decoded, or frames that are recognized as corrupted.

`--vd-lavc-skiploopfilter=<skipvalue>` (H.264, HEVC only)

Skips the loop filter (AKA deblocking) during decoding. Since
the filtered frame is supposed to be used as reference for decoding
dependent frames, this has a worse effect on quality than not doing
deblocking on e.g. MPEG-2 video. But at least for high bitrate HDTV,
this provides a big speedup with little visible quality loss.
Codecs other than H.264 or HEVC may have partial support for this option
(often only `all` and `none`).

`<skipvalue>` can be one of the following:
| none: | Never skip. |
| --- | --- |
| default: | Skip useless processing steps (e.g. 0 size packets in AVI). |
| nonref: | Skip frames that are not referenced (i.e. not used for
decoding other frames, the error cannot "build up"). |
| bidir: | Skip B-Frames. |
| nonkey: | Skip all frames except keyframes. |
| all: | Skip all frames. |

`--vd-lavc-skipidct=<skipvalue>` (MPEG-1/2/4 only)

Skips the IDCT step. This degrades quality a lot in almost all cases
(see skiploopfilter for available skip values).

`--vd-lavc-skipframe=<skipvalue>`

Skips decoding of frames completely. Big speedup, but jerky motion and
sometimes bad artifacts (see skiploopfilter for available skip values).

`--vd-lavc-framedrop=<skipvalue>`

Set framedropping mode used with `--framedrop` (see skiploopfilter for
available skip values).

`--vd-lavc-threads=<N>`

Number of threads to use for decoding. Whether threading is actually
supported depends on codec (default: 0). 0 means autodetect number of cores
on the machine and use that, up to the maximum of 16. You can set more than
16 threads manually.

`--vd-lavc-assume-old-x264=<yes|no>`

Assume the video was encoded by an old, buggy x264 version (default: no).
Normally, this is autodetected by libavcodec. But if the bitstream contains
no x264 version info (or it was somehow skipped), and the stream was in fact
encoded by an old x264 version (build 150 or earlier), and if the stream
uses 4:4:4 chroma, then libavcodec will by default show corrupted video.
This option sets the libavcodec `x264_build` option to `150`, which
means that if the stream contains no version info, or was not encoded by
x264 at all, it assumes it was encoded by the old version. Enabling this
option is pretty safe if you want your broken files to work, but in theory
this can break on streams not encoded by x264, or if a stream encoded by a
newer x264 version contains no version info.

`--vd-apply-cropping`

Certain video codecs support cropping, meaning that only a sub-rectangle of
the decoded frame is intended for display. This option controls how cropping
is handled by libavcodec. Cropping during decoding has certain limitations
with regards to alignment and hardware decoding. If this option is enabled,
decoder will apply the crop, else VO will handle it. Enabled by default.

`--swapchain-depth=<N>`

Allow up to N in-flight frames. This essentially controls the frame
latency. Increasing the swapchain depth can improve pipelining and prevent
missed vsyncs, but increases visible latency. This option only mandates an
upper limit, the implementation can use a lower latency than requested
internally. A setting of 1 means that the VO will wait for every frame to
become visible before starting to render the next frame. (Default: 2)
