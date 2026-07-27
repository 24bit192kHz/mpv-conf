Show only first field.

bob

Bob deinterlacing.

temporal

Motion-adaptive temporal deinterlacing. May lead to A/V desync
with slow video hardware and/or high resolution.

temporal-spatial

Motion-adaptive temporal deinterlacing with edge-guided spatial
interpolation. Needs fast video hardware.

`chroma-deint`

Makes temporal deinterlacers operate both on luma and chroma (default).
Use no-chroma-deint to solely use luma and speed up advanced
deinterlacing. Useful with slow video memory.

`pullup`

Try to apply inverse telecine, needs motion adaptive temporal
deinterlacing.

`interlaced-only=<yes|no>`

If `yes`, only deinterlace frames marked as interlaced (default: no).

`hqscaling=<0-9>`

0

Use default VDPAU scaling (default).

1-9

Apply high quality VDPAU scaling (needs capable hardware).

`d3d11vpp`

Direct3D 11 video post-processing. Requires a D3D11 context and works best
with hardware decoding. Software frames are automatically uploaded to hardware
for processing.

`format`

Convert to the selected image format, e.g., nv12, p010, etc. (default: don't change).
Format names can be queried with `--vf=d3d11vpp=format=help`.
Note that only a limited subset is supported, and actual support depends
on your hardware. Normally, this shouldn't be changed unless some
processing only works with a specific format, in which case it can be
selected here.

`deint=<yes|no>`

Whether deinterlacing is enabled (default: no).

`scale`

Scaling factor for the video frames (default: 1.0).

`scaling-mode=<standard,intel,nvidia>`

Select the scaling mode to be used. Note that this only enables the
appropriate processing extensions; whether it actually works or not
depends on your hardware and the settings in your GPU driver's control
panel (default: standard).

standard

Default scaling mode as decided by d3d11vpp implementation.

intel

Intel Video Super Resolution.

nvidia

NVIDIA RTX Super Resolution.

`interlaced-only=<yes|no>`

If `yes`, only deinterlace frames marked as interlaced (default: no).

`mode=<blend|bob|adaptive|mocomp|ivctc|none>`

Tries to select a video processor with the given processing capability.
If a video processor supports multiple capabilities, it is not clear
which algorithm is actually selected. `none` always falls back. On
most if not all hardware, this option will probably do nothing, because
a video processor usually supports all modes or none.

`nvidia-true-hdr`

Enable NVIDIA RTX Video HDR processing.

`fingerprint=...`

Compute video frame fingerprints and provide them as metadata. Actually, it
currently barely deserved to be called `fingerprint`, because it does not
compute "proper" fingerprints, only tiny downscaled images (but which can be
used to compute image hashes or for similarity matching).

The main purpose of this filter is to support the `skip-logo.lua` script.
If this script is dropped, or mpv ever gains a way to load user-defined
filters (other than VapourSynth), this filter will be removed. Due to the
"special" nature of this filter, it will be removed without warning.

The intended way to read from the filter is using `vf-metadata` (also
see `clear-on-query` filter parameter). The property will return a list
of key/value pairs as follows:

```
fp0.pts = 1.2345
fp0.hex = 1234abcdef...bcde
fp1.pts = 1.4567
fp1.hex = abcdef1234...6789
...
fpN.pts = ...
fpN.hex = ...
type = gray-hex-16x16
```

Each `fp<N>` entry is for a frame. The `pts` entry specifies the
timestamp of the frame (within the filter chain; in simple cases this is
the same as the display timestamp). The `hex` field is the hex encoded
fingerprint, whose size and meaning depend on the `type` filter option.
The `type` field has the same value as the option the filter was created
with.

This returns the frames that were filtered since the last query of the
property. If `clear-on-query=no` was set, a query doesn't reset the list
of frames. In both cases, a maximum of 10 frames is returned. If there are
more frames, the oldest frames are discarded. Frames are returned in filter
order.

(This doesn't return a structured list for the per-frame details because the
internals of the `vf-metadata` mechanism suck. The returned format may
change in the future.)

This filter uses zimg for speed and profit. However, it will fallback to
libswscale in a number of situations: lesser pixel formats, unaligned data
pointers or strides, or if zimg fails to initialize for unknown reasons. In
these cases, the filter will use more CPU. Also, it will output different
fingerprints, because libswscale cannot perform the full range expansion we
normally request from zimg. As a consequence, the filter may be slower and
not work correctly in random situations.

`type=...`

What fingerprint to compute. Available types are:
| gray-hex-8x8: | grayscale, 8 bit, 8x8 size |
| --- | --- |
| gray-hex-16x16: | grayscale, 8 bit, 16x16 size (default) |

Both types simply remove all colors, downscale the image, concatenate
all pixel values to a byte array, and convert the array to a hex string.

`clear-on-query=yes|no`

Clear the list of frame fingerprints if the `vf-metadata` property for
this filter is queried (default: yes). This requires some care by the
user. Some types of accesses might query the filter multiple times,
which leads to lost frames.

`print=yes|no`

Print computed fingerprints to the terminal (default: no). This is
mostly for testing and such. Scripts should use `vf-metadata` to
read information from this filter instead.

`gpu=...`

Convert video to RGB using the Vulkan or OpenGL renderer normally used with
`--vo=gpu`. In case of OpenGL, this requires that the EGL implementation
supports off-screen rendering on the default display. (This is the case with
Mesa.)

Sub-options:

`api=<type>`

The value `type` selects the rendering API. You can also pass
`help` to get a complete list of compiled in backends.

egl

EGL (default if available)

vulkan

Vulkan
