
The primaries in use as string. (Exact values subject to change.)

`video-params/gamma`

The gamma function in use as string. (Exact values subject to change.)

`video-params/sig-peak` (deprecated)

The video file's tagged signal peak as float.

`video-params/light`

The light type in use as a string. (Exact values subject to change.)

`video-params/chroma-location`

Chroma location as string. (Exact values subject to change.)

`video-params/rotate`

Intended display rotation in degrees (clockwise).

`video-params/stereo-in`

Source file stereo 3D mode. (See the `format` video filter's
`stereo-in` option.)

`video-params/alpha`

Alpha type. If the format has no alpha channel, this will be unavailable
(but in future releases, it could change to `no`). If alpha is
present, this is set to `straight` or `premul`.

`video-params/min-luma`

Minimum luminance, as reported by HDR10 metadata (in cd/m²)

`video-params/max-luma`

Maximum luminance, as reported by HDR10 metadata (in cd/m²)

`video-params/max-cll`

Maximum content light level, as reported by HDR10 metadata (in cd/m²)

`video-params/max-fall`

Maximum frame average light level, as reported by HDR10 metadata (in cd/m²)

`video-params/scene-max-r`

MaxRGB of a scene for R component, as reported by HDR10+ metadata (in cd/m²)

`video-params/scene-max-g`

MaxRGB of a scene for G component, as reported by HDR10+ metadata (in cd/m²)

`video-params/scene-max-b`

MaxRGB of a scene for B component, as reported by HDR10+ metadata (in cd/m²)

`video-params/max-pq-y`

Maximum PQ luminance of a frame, as reported by peak detection (in PQ, 0-1)

`video-params/avg-pq-y`

Average PQ luminance of a frame, as reported by peak detection (in PQ, 0-1)

`video-params/prim-red-x`, `video-params/prim-red-y`

Red primary chromaticity coordinates, available only if differs from `video-params/primaries`

`video-params/prim-green-x`, `video-params/prim-green-y`

Green primary chromaticity coordinates, available only if differs from `video-params/primaries`

`video-params/prim-blue-x`, `video-params/prim-blue-y`

Blue primary chromaticity coordinates, available only if differs from `video-params/primaries`

`video-params/prim-white-x`, `video-params/prim-white-y`

White point chromaticity coordinates, available only if differs from `video-params/primaries`

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_MAP
    "pixelformat"       MPV_FORMAT_STRING
    "hw-pixelformat"    MPV_FORMAT_STRING
    "w"                 MPV_FORMAT_INT64
    "h"                 MPV_FORMAT_INT64
    "dw"                MPV_FORMAT_INT64
    "dh"                MPV_FORMAT_INT64
    "aspect"            MPV_FORMAT_DOUBLE
    "par"               MPV_FORMAT_DOUBLE
    "colormatrix"       MPV_FORMAT_STRING
    "colorlevels"       MPV_FORMAT_STRING
    "primaries"         MPV_FORMAT_STRING
    "gamma"             MPV_FORMAT_STRING
    "sig-peak"          MPV_FORMAT_DOUBLE
    "light"             MPV_FORMAT_STRING
    "chroma-location"   MPV_FORMAT_STRING
    "rotate"            MPV_FORMAT_INT64
    "stereo-in"         MPV_FORMAT_STRING
    "average-bpp"       MPV_FORMAT_INT64
    "alpha"             MPV_FORMAT_STRING
    "min-luma"          MPV_FORMAT_DOUBLE
    "max-luma"          MPV_FORMAT_DOUBLE
    "max-cll"           MPV_FORMAT_DOUBLE
    "max-fall"          MPV_FORMAT_DOUBLE
    "scene-max-r"       MPV_FORMAT_DOUBLE
    "scene-max-g"       MPV_FORMAT_DOUBLE
    "scene-max-b"       MPV_FORMAT_DOUBLE
    "max-pq-y"          MPV_FORMAT_DOUBLE
    "avg-pq-y"          MPV_FORMAT_DOUBLE
    "prim-red-x"        MPV_FORMAT_DOUBLE
    "prim-red-y"        MPV_FORMAT_DOUBLE
    "prim-green-x"      MPV_FORMAT_DOUBLE
    "prim-green-y"      MPV_FORMAT_DOUBLE
    "prim-blue-x"       MPV_FORMAT_DOUBLE
    "prim-blue-y"       MPV_FORMAT_DOUBLE
    "prim-white-x"      MPV_FORMAT_DOUBLE
    "prim-white-y"      MPV_FORMAT_DOUBLE
```

`dwidth`, `dheight`

Video display size. This is the video size after filters and aspect scaling
have been applied. The actual video window size can still be different
from this, e.g. if the user resized the video window manually.

These have the same values as `video-out-params/dw` and
`video-out-params/dh`.

`video-dec-params`

Exactly like `video-params`, but no overrides applied.

`video-out-params`

Same as `video-params`, but after video filters have been applied. If
there are no video filters in use, this will contain the same values as
`video-params`. Note that this is still not necessarily what the video
window uses, since the user can change the window size, and all real VOs
do their own scaling independently from the filter chain.

Has the same sub-properties as `video-params`.

`video-target-params`

Same as `video-params`, but with the target properties that VO outputs to.

Has the same sub-properties as `video-params`.

`video-frame-info`

Approximate information of the current frame. Note that if any of these
are used on OSD, the information might be off by a few frames due to OSD
redrawing and frame display being somewhat disconnected, and you might
have to pause and force a redraw.

This has a number of sub-properties:

`video-frame-info/picture-type`

The type of the picture. It can be "I" (intra), "P" (predicted), "B"
(bi-dir predicted) or unavailable.

`video-frame-info/interlaced`

Whether the content of the frame is interlaced.

`video-frame-info/tff`

If the content is interlaced, whether the top field is displayed first.

`video-frame-info/repeat`

Whether the frame must be delayed when decoding.

`video-frame-info/gop-timecode`

String with the GOP timecode encoded in the frame.

`video-frame-info/smpte-timecode`

String with the SMPTE timecode encoded in the frame.

`video-frame-info/estimated-smpte-timecode`

