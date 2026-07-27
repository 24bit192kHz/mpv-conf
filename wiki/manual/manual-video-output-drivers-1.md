# VIDEO OUTPUT DRIVERS

Video output drivers are interfaces to different video output facilities. The
syntax is:

`--vo=<driver1,driver2,...[,]>`

Specify a priority list of video output drivers to be used.

If the list has a trailing `,`, mpv will fall back on drivers not contained
in the list.

This is an object settings list option. See [List Options](manual-options-track.md) for details.

Note

See `--vo=help` for a list of compiled-in video output drivers.

The recommended output driver is `--vo=gpu-next`, which is the default.
All other drivers are for compatibility or special purposes. If the default
does not work, it will fallback to other drivers (in the same order as
listed by `--vo=help`).

Note that the default video output driver is subject to change, and must
not be relied upon. If a certain VO needs to be used (e.g. for `libmpv`
rendering API), it must be explicitly specified.

Available video output drivers are:

`gpu-next`

Video renderer based on `libplacebo`. This supports almost the same set
of features as `--vo=gpu`. See [GPU renderer options](manual-options-gpu-1.md) for a list.

Should generally be faster and higher quality, while also implementing some
features specific to `gpu-next`, but some features may be intentionally
omitted or there may be functional differences to `--vo=gpu`.
See here for a list of known differences:

[https://github.com/mpv-player/mpv/wiki/GPU-Next-vs-GPU](https://github.com/mpv-player/mpv/wiki/GPU-Next-vs-GPU)

`gpu`

General purpose, customizable, GPU-accelerated video output driver. It
supports extended scaling methods, dithering, color management, custom
shaders, HDR, and more.

See [GPU renderer options](manual-options-gpu-1.md) for options specific to this VO.

By default, mpv utilizes settings that balance quality and performance.
Additionally, two predefined profiles are available: `fast` for maximum
performance and `high-quality` for superior rendering quality. You can
apply a specific profile using the `--profile=<name>` option and inspect
its contents using `--show-profile=<name>`.

This VO abstracts over several possible graphics APIs and windowing
contexts, which can be influenced using the `--gpu-api` and
`--gpu-context` options.

Hardware decoding over OpenGL-interop is supported to some degree. Note
that in this mode, some corner case might not be gracefully handled, and
color space conversion and chroma upsampling is generally in the hand of
the hardware decoder APIs.

`gpu` makes use of FBOs by default. Sometimes you can achieve better
quality or performance by changing the `--fbo-format` option to
`rgb16f`, `rgb32f` or `rgb`. Known problems include Mesa/Intel not
accepting `rgb16`, Mesa sometimes not being compiled with float texture
support, and some macOS setups being very slow with `rgb16` but fast
with `rgb32f`. If you have problems, you can also try enabling the
`--gpu-dumb-mode=yes` option.

`xv` (X11 only)

Uses the XVideo extension to enable hardware-accelerated display. This is
the most compatible VO on X, but may be low-quality, and has issues with
OSD and subtitle display.

Note

This driver is for compatibility with old systems.

The following global options are supported by this video output:

`--xv-adaptor=<number>`

Select a specific XVideo adapter (check xvinfo results).

`--xv-port=<number>`

Select a specific XVideo port.

`--xv-ck=<cur|use|set>`

Select the source from which the color key is taken (default: cur).

cur

The default takes the color key currently set in Xv.

use

Use but do not set the color key from mpv (use the `--colorkey`
option to change it).

set

Same as use but also sets the supplied color key.

`--xv-ck-method=<none|man|bg|auto>`

Sets the color key drawing method (default: man).

none

Disables color-keying.

man

Draw the color key manually (reduces flicker in some cases).

bg

Set the color key as window background.

auto

Let Xv draw the color key.

`--xv-colorkey=<number>`

Changes the color key to an RGB value of your choice. `0x000000` is
black and `0xffffff` is white.

`--xv-buffers=<number>`

Number of image buffers to use for the internal ringbuffer (default: 2).
Increasing this will use more memory, but might help with the X server
not responding quickly enough if video FPS is close to or higher than
the display refresh rate.

`x11` (X11 only)

Shared memory video output driver without hardware acceleration that works
whenever X11 is present.

Since mpv 0.30.0, you may need to use `--profile=sw-fast` to get decent
performance.

Note

This is a fallback only, and should not be normally used.

`vdpau` (X11 only)

Uses the VDPAU interface to display and optionally also decode video.
Hardware decoding is used with `--hwdec=vdpau`. Note that there is
absolutely no reason to use this, other than compatibility. We strongly
recommend that you use `--vo=gpu` with `--hwdec=nvdec` instead.

Note

Earlier versions of mpv (and MPlayer, mplayer2) provided sub-options
to tune vdpau post-processing, like `deint`, `sharpen`, `denoise`,
`chroma-deint`, `pullup`, `hqscaling`. These sub-options are
deprecated, and you should use the `vdpaupp` video filter instead.

The following global options are supported by this video output:

`--vo-vdpau-sharpen=<-1-1>`

(Deprecated. See note about `vdpaupp`.)

For positive values, apply a sharpening algorithm to the video, for
negative values a blurring algorithm (default: 0).

`--vo-vdpau-denoise=<0-1>`

(Deprecated. See note about `vdpaupp`.)

Apply a noise reduction algorithm to the video (default: 0; no noise
reduction).

`--vo-vdpau-chroma-deint`

(Deprecated. See note about `vdpaupp`.)

Makes temporal deinterlacers operate both on luma and chroma (default).
Use no-chroma-deint to solely use luma and speed up advanced
deinterlacing. Useful with slow video memory.

`--vo-vdpau-pullup`

(Deprecated. See note about `vdpaupp`.)

