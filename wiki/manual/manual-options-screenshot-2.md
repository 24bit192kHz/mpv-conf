`--screenshot-webp-lossless=<yes|no>`

Write lossless WebP files. `--screenshot-webp-quality` is ignored if this
is set. The default is no.

`--screenshot-webp-quality=<0-100>`

Set the WebP quality level. Higher means better quality. The default is 75.

`--screenshot-webp-compression=<0-6>`

Set the WebP compression level. Higher means better compression, but takes
more CPU time. Note that this also affects the screenshot quality when used
with lossy WebP files. The default is 4.

`--screenshot-jxl-distance=<0-15>`

Set the JPEG XL Butteraugli distance. Lower means better quality. Lossless
is 0.0, and 1.0 is approximately equivalent to JPEG quality 90 for
photographic content. Use 0.1 for "visually lossless" screenshots. The
default is 1.0.

`--screenshot-jxl-effort=<1-9>`

Set the JPEG XL compression effort. Higher effort (usually) means better
compression, but takes more CPU time. The default is 4.

`--screenshot-avif-encoder=<encoder>`

Specify the AV1 encoder to be used by libavcodec for encoding avif
screenshots.

Default: `libaom-av1`

`--screenshot-avif-pixfmt=<format>`

Specify the pixel format for the libavcodec encoder. Defaults to empty,
which lets mpv pick one close to the source format.

`--screenshot-avif-opts=key1=value1,key2=value2,...`

Specifies libavcodec options for selected encoder. For more information,
consult the FFmpeg documentation.

Default: `usage=allintra,crf=0,cpu-used=8`

Note: the default is only guaranteed to work with the libaom-av1 encoder.
Above options may not be valid and or optimal for other encoders.

This is a key/value list option. See [List Options](manual-options-track.md) for details.

Example

"`--screenshot-avif-opts=crf=23,aq-mode=complexity`"

sets the crf to 23 and quantization (aq-mode) to complexity based.

`--screenshot-sw=<yes|no>`

Whether to use software rendering for screenshots (default: no).

If set to no, the screenshot will be rendered by the current VO (only vo_gpu
or vo_gpu_next currently). The advantage is that this will (probably) always
show up as in the video window, because the same code is used for rendering.
But since the renderer needs to be reinitialized, this can be slow and
interrupt playback.

If set to yes, the software scaler is used to convert the video to RGB (or
whatever the target screenshot requires). In this case, conversion will
run in a separate thread and will probably not interrupt playback. The
software renderer may lack some capabilities, such as HDR rendering.
If `window` mode is used, the image will also be scaled in software
which may not accurately reflect the actual visible result.
