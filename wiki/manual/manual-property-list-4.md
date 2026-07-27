Whether the player is currently seeking, or otherwise trying to restart
playback. (It's possible that it returns `yes`/true while a file is
loaded. This is because the same underlying code is used for seeking and
resyncing.)

`mixer-active`

Whether the audio mixer is active.

This option is relatively useless. Before mpv 0.18.1, it could be used to
infer behavior of the `volume` property.

`ao-volume` (RW)

System volume. This property is available only if mpv audio output is
currently active, and only if the underlying implementation supports volume
control. What this option does, or how the value is interpreted depends on
the API. For example, on ALSA this usually changes system-wide audio volume
on a linear curve, while with PulseAudio this controls per-application volume
on a cubic curve.

`ao-mute` (RW)

Similar to `ao-volume`, but controls the mute state. May be unimplemented
even if `ao-volume` works.

`audio-params`

Audio format as output by the audio decoder.
This has a number of sub-properties:

`audio-params/format`

The sample format as string. This uses the same names as used in other
places of mpv.

`audio-params/samplerate`

Samplerate.

`audio-params/channels`

The channel layout as a string. This is similar to what the
`--audio-channels` accepts.

`audio-params/hr-channels`

As `channels`, but instead of the possibly cryptic actual layout
sent to the audio device, return a hopefully more human readable form.
(Usually only `audio-out-params/hr-channels` makes sense.)

`audio-params/channel-count`

Number of audio channels. This is redundant to the `channels` field
described above.

When querying the property with the client API using `MPV_FORMAT_NODE`,
or with Lua `mp.get_property_native`, this will return a mpv_node with
the following contents:

```
MPV_FORMAT_NODE_MAP
    "format"            MPV_FORMAT_STRING
    "samplerate"        MPV_FORMAT_INT64
    "channels"          MPV_FORMAT_STRING
    "channel-count"     MPV_FORMAT_INT64
    "hr-channels"       MPV_FORMAT_STRING
```

`audio-out-params`

Same as `audio-params`, but the format of the data written to the audio
API.

`colormatrix`

Redirects to `video-params/colormatrix`. This parameter (as well as
similar ones) can be overridden with the `format` video filter.

`colormatrix-input-range`

See `colormatrix`.

`colormatrix-primaries`

See `colormatrix`.

`hwdec` (RW)

Reflects the `--hwdec` option.

Writing to it may change the currently used hardware decoder, if possible.
(Internally, the player may reinitialize the decoder, and will perform a
seek to refresh the video properly.) You can watch the other hwdec
properties to see whether this was successful.

Unlike in mpv 0.9.x and before, this does not return the currently active
hardware decoder. Since mpv 0.18.0, `hwdec-current` is available for
this purpose.

`hwdec-current`

The current hardware decoding in use. If decoding is active, return one of
the values used by the `hwdec` option/property. `no` indicates
software decoding. If no decoder is loaded, the property is unavailable.

`hwdec-interop`

This returns the currently loaded hardware decoding/output interop driver.
This is known only once the VO has opened (and possibly later). With some
VOs (like `gpu`), this might be never known in advance, but only when
the decoder attempted to create the hw decoder successfully. (Using
`--gpu-hwdec-interop` can load it eagerly.) If there are multiple
drivers loaded, they will be separated by `,`.

If no VO is active or no interop driver is known, this property is
unavailable.

This does not necessarily use the same values as `hwdec`. There can be
multiple interop drivers for the same hardware decoder, depending on
platform and VO.

`width`, `height`

Video size. This uses the size of the video as decoded, or if no video
frame has been decoded yet, the (possibly incorrect) container indicated
size.

`video-params`

Video parameters, as output by the decoder (with overrides like aspect
etc. applied). This has a number of sub-properties:

`video-params/pixelformat`

The pixel format as string. This uses the same names as used in other
places of mpv.

`video-params/hw-pixelformat`

The underlying pixel format as string. This is relevant for some cases
of hardware decoding and unavailable otherwise.

`video-params/average-bpp`

Average bits-per-pixel as integer. Subsampled planar formats use a
different resolution, which is the reason this value can sometimes be
odd or confusing. Can be unavailable with some formats.

`video-params/w`, `video-params/h`

Video size as integers, with no aspect correction applied.

`video-params/dw`, `video-params/dh`

Video size as integers, scaled for correct aspect ratio.

`video-params/crop-x`, `video-params/crop-y`

Crop offset of the source video frame.

`video-params/crop-w`, `video-params/crop-h`

Video size after cropping.

`video-params/aspect`

Display aspect ratio as double.

`video-params/aspect-name`

Display aspect ratio name as string. The name corresponds to motion
picture film format that introduced given aspect ratio in film.

`video-params/par`

Pixel aspect ratio.

`video-params/sar`

Storage aspect ratio.

`video-params/sar-name`

Storage aspect ratio name as string.

`video-params/colormatrix`

The colormatrix in use as string. (Exact values subject to change.)

`video-params/colorlevels`

The colorlevels as string. (Exact values subject to change.)

`video-params/primaries`
