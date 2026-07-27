Try to apply inverse telecine, needs motion adaptive temporal
deinterlacing.

`--vo-vdpau-hqscaling=<0-9>`

(Deprecated. See note about `vdpaupp`.)

0

Use default VDPAU scaling (default).

1-9

Apply high quality VDPAU scaling (needs capable hardware).

`--vo-vdpau-fps=<number>`

Override autodetected display refresh rate value (the value is needed
for framedrop to allow video playback rates higher than display
refresh rate, and for vsync-aware frame timing adjustments). Default 0
means use autodetected value. A positive value is interpreted as a
refresh rate in Hz and overrides the autodetected value. A negative
value disables all timing adjustment and framedrop logic.

`--vo-vdpau-composite-detect`

NVIDIA's current VDPAU implementation behaves somewhat differently
under a compositing window manager and does not give accurate frame
timing information. With this option enabled, the player tries to
detect whether a compositing window manager is active. If one is
detected, the player disables timing adjustments as if the user had
specified `fps=-1` (as they would be based on incorrect input). This
means timing is somewhat less accurate than without compositing, but
with the composited mode behavior of the NVIDIA driver, there is no
hard playback speed limit even without the disabled logic. Enabled by
default, use `--vo-vdpau-composite-detect=no` to disable.

`--vo-vdpau-queuetime-windowed=<number>` and `queuetime-fs=<number>`

Use VDPAU's presentation queue functionality to queue future video
frame changes at most this many milliseconds in advance (default: 50).
See below for additional information.

`--vo-vdpau-output-surfaces=<2-15>`

Allocate this many output surfaces to display video frames (default:
3). See below for additional information.

`--vo-vdpau-colorkey=<#RRGGBB|#AARRGGBB>`

Set the VDPAU presentation queue background color, which in practice
is the colorkey used if VDPAU operates in overlay mode (default:
`#020507`, some shade of black). If the alpha component of this value
is 0, the default VDPAU colorkey will be used instead (which is usually
green).

`--vo-vdpau-force-yuv`

Never accept RGBA input. This means mpv will insert a filter to convert
to a YUV format before the VO. Sometimes useful to force availability
of certain YUV-only features, like video equalizer or deinterlacing.

Using the VDPAU frame queuing functionality controlled by the queuetime
options makes mpv's frame flip timing less sensitive to system CPU load and
allows mpv to start decoding the next frame(s) slightly earlier, which can
reduce jitter caused by individual slow-to-decode frames. However, the
NVIDIA graphics drivers can make other window behavior such as window moves
choppy if VDPAU is using the blit queue (mainly happens if you have the
composite extension enabled) and this feature is active. If this happens on
your system and it bothers you then you can set the queuetime value to 0 to
disable this feature. The settings to use in windowed and fullscreen mode
are separate because there should be no reason to disable this for
fullscreen mode (as the driver issue should not affect the video itself).

You can queue more frames ahead by increasing the queuetime values and the
`output_surfaces` count (to ensure enough surfaces to buffer video for a
certain time ahead you need at least as many surfaces as the video has
frames during that time, plus two). This could help make video smoother in
some cases. The main downsides are increased video RAM requirements for
the surfaces and laggier display response to user commands (display
changes only become visible some time after they're queued). The graphics
driver implementation may also have limits on the length of maximum
queuing time or number of queued surfaces that work well or at all.

`direct3d` (Windows only)

Video output driver that uses the Direct3D interface.

Note

This driver is for compatibility with systems that don't provide
proper OpenGL drivers, and where ANGLE does not perform well.

The following global options are supported by this video output:

`--vo-direct3d-disable-texture-align`

Normally texture sizes are always aligned to 16. With this option
enabled, the video texture will always have exactly the same size as
the video itself.

Debug options. These might be incorrect, might be removed in the future,
might crash, might cause slow downs, etc. Contact the developers if you
actually need any of these for performance or proper operation.

`--vo-direct3d-force-power-of-2`

Always force textures to power of 2, even if the device reports
non-power-of-2 texture sizes as supported.

`--vo-direct3d-texture-memory=<mode>`

Only affects operation with shaders/texturing enabled, and (E)OSD.
Possible values:

`default` (default)

Use `D3DPOOL_DEFAULT`, with a `D3DPOOL_SYSTEMMEM` texture for
locking. If the driver supports `D3DDEVCAPS_TEXTURESYSTEMMEMORY`,
`D3DPOOL_SYSTEMMEM` is used directly.

`default-pool`

Use `D3DPOOL_DEFAULT`. (Like `default`, but never use a
shadow-texture.)

`default-pool-shadow`

Use `D3DPOOL_DEFAULT`, with a `D3DPOOL_SYSTEMMEM` texture for
locking. (Like `default`, but always force the shadow-texture.)

`managed`

Use `D3DPOOL_MANAGED`.

`scratch`

Use `D3DPOOL_SCRATCH`, with a `D3DPOOL_SYSTEMMEM` texture for
locking.

`--vo-direct3d-swap-discard`

Use `D3DSWAPEFFECT_DISCARD`, which might be faster.
Might be slower too, as it must(?) clear every frame.

`--vo-direct3d-exact-backbuffer`

Always resize the backbuffer to window size.

`sdl`

SDL 2.0+ Render video output driver, depending on system with or without
hardware acceleration. Should work on all platforms supported by SDL 2.0.
For tuning, refer to your copy of the file `SDL_hints.h`.

Note

This driver is for compatibility with systems that don't provide
proper graphics drivers.

The following global options are supported by this video output:

`--sdl-sw`

Continue even if a software renderer is detected.

`--sdl-switch-mode`

Instruct SDL to switch the monitor video mode when going fullscreen.

`dmabuf-wayland`

Experimental Wayland output driver designed for use with either drm stateless
or VA API hardware decoding. The driver is designed to avoid any GPU to CPU copies,
and to perform scaling and color space conversion using fixed-function hardware,
if available, rather than GPU shaders. This frees up GPU resources for other tasks.
It is highly recommended to use this VO with the appropriate `--hwdec` option such
as `auto-safe`. It can still work in some circumstances without `--hwdec` due to
mpv's internal conversion filters, but this is not recommended as it's a needless
extra step. Correct output depends on support from your GPU, drivers, and compositor.
This requires the compositor and mpv to support `color-management-v1` to
accurately display colorspaces that are different from the compositor
default (bt.601 in most cases).

Warning

This driver is not required for mpv to work on Wayland. `vo=gpu`
and `vo=gpu-next` will switch to the appropriate Wayland context
automatically. This driver is experimental and generally lower quality
than `gpu`/`gpu-next`.

`vaapi`

Intel VA API video output driver with support for hardware decoding. Note
that there is absolutely no reason to use this, other than compatibility.
