
mpv on the other hand is stream oriented, and does not allow filters to
seek. (And it would not make sense to allow it, because it would ruin
performance.) Filters get frames sequentially in playback direction, and
cannot request them out of order.

To compensate for this mismatch, mpv allows the filter to access frames
within a certain window. `buffered-frames` controls the size of this
window. Most VapourSynth filters happen to work with this, because mpv
requests frames sequentially increasing from it, and most filters only
require frames "close" to the requested frame.

If the filter requests a frame that has a higher frame number than the
highest buffered frame, new frames will be decoded until the requested
frame number is reached. Excessive frames will be flushed out in a FIFO
manner (there are only at most `buffered-frames` in this buffer).

If the filter requests a frame that has a lower frame number than the
lowest buffered frame, the request cannot be satisfied, and an error
is returned to the filter. This kind of error is not supposed to happen
in a "proper" VapourSynth environment. What exactly happens depends on
the filters involved.

Increasing this buffer will not improve performance. Rather, it will
waste memory, and slow down seeks (when enough frames to fill the buffer
need to be decoded at once). It is only needed to prevent the error
described in the previous paragraph.

How many frames a filter requires depends on filter implementation
details, and mpv has no way of knowing. A scale filter might need only
1 frame, an interpolation filter may require a small number of frames,
and the `Reverse` filter will require an infinite number of frames.

If you want reliable operation to the full extend VapourSynth is
capable, use `vspipe`.

The actual number of buffered frames also depends on the value of the
`concurrent-frames` option. Currently, both option values are
multiplied to get the final buffer size.

`concurrent-frames`

Number of frames that should be requested in parallel. The
level of concurrency depends on the filter and how quickly mpv can
decode video to feed the filter. This value should probably be
proportional to the number of cores on your machine. Most time,
making it higher than the number of cores can actually make it
slower.

Technically, mpv will call the VapourSynth `getFrameAsync` function
in a loop, until there are `concurrent-frames` frames that have not
been returned by the filter yet. This also assumes that the rest of the
mpv filter chain reads the output of the `vapoursynth` filter quickly
enough. (For example, if you pause the player, filtering will stop very
soon, because the filtered frames are waiting in a queue.)

Actual concurrency depends on many other factors.

By default, this uses the special value `auto`, which sets the option
to the number of detected logical CPU cores.

`user-data`

Optional arbitrary string that is passed to the script. Default to empty
string if not set.

The following `.vpy` script variables are defined by mpv:

`video_in`

The mpv video source as vapoursynth clip. Note that this has an
incorrect (very high) length set, which confuses many filters. This is
necessary, because the true number of frames is unknown. You can use the
`Trim` filter on the clip to reduce the length.

`video_in_dw`, `video_in_dh`

Display size of the video. Can be different from video size if the
video does not use square pixels (e.g. DVD).

`container_fps`

FPS value as reported by file headers. This value can be wrong or
completely broken (e.g. 0 or NaN). Even if the value is correct,
if another filter changes the real FPS (by dropping or inserting
frames), the value of this variable will not be useful. Note that
the `--container-fps-override` command line option overrides this value.

Useful for some filters which insist on having a FPS.

`display_fps`

Refresh rate of the current display. Note that this value can be 0.

`display_res`

Resolution of the current display. This is an integer array with the
first entry corresponding to the width and the second entry corresponding
to the height. These values can be 0. Note that this will not respond to
monitor changes and may not work on all platforms.

`user_data`

User data passed from the filter. This variable always exists, and defaults
to empty string.

`vavpp`

VA-API video post processing. Requires the system to support VA-API,
i.e. Linux/BSD only. Works with `--vo=vaapi` and `--vo=gpu` only.
Currently deinterlaces. This filter is automatically inserted if
deinterlacing is requested (either using the `d` key, by default mapped to
the command `cycle deinterlace`, or the `--deinterlace` option).

`deint=<method>`

Select the deinterlacing algorithm.

no

Don't perform deinterlacing.

auto

Select the best quality deinterlacing algorithm (default). This
goes by the order of the options as documented, with
`motion-compensated` being considered best quality.

first-field

Show only first field.

bob

bob deinterlacing.

weave, motion-adaptive, motion-compensated

Advanced deinterlacing algorithms. Whether these actually work
depends on the GPU hardware, the GPU drivers, driver bugs, and
mpv bugs.

`<interlaced-only>`

| no: | Deinterlace all frames (default). |
| --- | --- |
| yes: | Only deinterlace frames marked as interlaced. |

`reversal-bug=<yes|no>`

| no: | Use the API as it was interpreted by older Mesa drivers. While
this interpretation was more obvious and intuitive, it was
apparently wrong, and not shared by Intel driver developers. |
| --- | --- |
| yes: | Use Intel interpretation of surface forward and backwards
references (default). This is what Intel drivers and newer Mesa
drivers expect. Matters only for the advanced deinterlacing
algorithms. |

`vdpaupp`

VDPAU video post processing. Works with `--vo=vdpau` and `--vo=gpu`
only. This filter is automatically inserted if deinterlacing is requested
(either using the `d` key, by default mapped to the command
`cycle deinterlace`, or the `--deinterlace` option). When enabling
deinterlacing, it is always preferred over software deinterlacer filters
if the `vdpau` VO is used, and also if `gpu` is used and hardware
decoding was activated at least once (i.e. vdpau was loaded).

`sharpen=<-1-1>`

For positive values, apply a sharpening algorithm to the video, for
negative values a blurring algorithm (default: 0).

`denoise=<0-1>`

Apply a noise reduction algorithm to the video (default: 0; no noise
reduction).

`deint=<yes|no>`

Whether deinterlacing is enabled (default: no). If enabled, it will use
the mode selected with `deint-mode`.

`deint-mode=<first-field|bob|temporal|temporal-spatial>`

Select deinterlacing mode (default: temporal).

Note that there's currently a mechanism that allows the `vdpau` VO to
change the `deint-mode` of auto-inserted `vdpaupp` filters. To avoid
confusion, it's recommended not to use the `--vo=vdpau` suboptions
related to filtering.

first-field

