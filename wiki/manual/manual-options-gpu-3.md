`--error-diffusion=<kernel>`

The error diffusion kernel to use when `--dither=error-diffusion` is set.

`simple`

Propagate error to only two adjacent pixels. Fastest but low quality.

`sierra-lite`

Fast with reasonable quality. This is the default.

`floyd-steinberg`

Most notable error diffusion kernel.

`atkinson`

Looks different from other kernels because only fraction of errors will
be propagated during dithering. A typical use case of this kernel is
saving dithered screenshot (in window mode). This kernel produces
slightly smaller file, with still reasonable dithering quality.

There are other kernels (use `--error-diffusion=help` to list) but most of
them are much slower and demanding even larger amount of shared memory.
Among these kernels, `burkes` achieves a good balance between performance
and quality, and probably is the one you want to try first.

`--gpu-debug`

Enables GPU debugging. What this means depends on the API type. For OpenGL,
it calls `glGetError()`, and requests a debug context. For Vulkan, it
enables validation layers.

`--opengl-swapinterval=<n>`

Interval in displayed frames between two buffer swaps. 1 is equivalent to
enable VSYNC, 0 to disable VSYNC. Defaults to 1 if not specified.

Note that this depends on proper OpenGL vsync support. On some platforms
and drivers, this only works reliably when in fullscreen mode. It may also
require driver-specific hacks if using multiple monitors, to ensure mpv
syncs to the right one. Compositing window managers can also lead to bad
results, as can missing or incorrect display FPS information (see
`--display-fps-override`).

`--egl-config-id=<ID>`

(EGL only)
Select EGLConfig with specific EGL_CONFIG_ID.
Rendering surfaces and contexts will be created using this EGLConfig.
You can use `--msg-level=vo=trace` to obtain a list of available configs.

`--egl-output-format=<auto|rgb8|rgba8|rgb10|rgb10_a2|rgb16|rgba16|rgb16f|rgba16f|rgb32f|rgba32f>`

(EGL only)
Select a specific EGL output format to utilize for OpenGL rendering.
This option is mutually exclusive with `--egl-config-id`.
"auto" is the default, which will pick the first usable config
based on the order given by the driver.

All formats are not available.
A fatal error is caused if an unavailable format is selected.

Note

There is no reliable API to query desktop bit depth in EGL.
You can manually set this option
according to the bit depth of your display.
This option also affects the auto-detection of `--dither-depth`.

Note

Unlike  `--d3d11-output-format`, this option also takes effect with `--vo=gpu-next`.

`--vulkan-device=<device name|UUID>`

The name or UUID of the Vulkan device to use for rendering and presentation. Use
`--vulkan-device=help` to see the list of available devices and their
names and UUIDs. If left unspecified, the first enumerated hardware Vulkan
device will be used.

`--vulkan-swap-mode=<mode>`

Controls the presentation mode of the vulkan swapchain. This is similar
to the `--opengl-swapinterval` option.

auto

Use the preferred swapchain mode for the vulkan context. (Default)

fifo

Non-tearing, vsync blocked. Similar to "VSync on".

fifo-relaxed

Tearing, vsync blocked. Late frames will tear instead of stuttering.

mailbox

Non-tearing, not vsync blocked. Similar to "triple buffering".

immediate

Tearing, not vsync blocked. Similar to "VSync off".

`--vulkan-queue-count=<1..8>`

Controls the number of VkQueues used for rendering (limited by how many
your device supports). In theory, using more queues could enable some
parallelism between frames (when using a `--swapchain-depth` higher than
1), but it can also slow things down on hardware where there's no true
parallelism between queues. (Default: 1)

`--vulkan-async-transfer`

Enables the use of async transfer queues on supported vulkan devices. Using
them allows transfer operations like texture uploads and blits to happen
concurrently with the actual rendering, thus improving overall throughput
and power consumption. Enabled by default, and should be relatively safe.

`--vulkan-async-compute`

Enables the use of async compute queues on supported vulkan devices. Using
this, in theory, allows out-of-order scheduling of compute shaders with
graphics shaders, thus enabling the hardware to do more effective work while
waiting for pipeline bubbles and memory operations. Not beneficial on all
GPUs. It's worth noting that if async compute is enabled, and the device
supports more compute queues than graphics queues (bound by the restrictions
set by `--vulkan-queue-count`), mpv will internally try and prefer the
use of compute shaders over fragment shaders wherever possible. Enabled by
default, although Nvidia users may want to disable it.

`--vulkan-display-display=<n>`

The index of the display, on the selected Vulkan device, to present on when
using the `displayvk` GPU context. Use `--vulkan-display-display=help`
to see the list of available displays. If left unspecified, the first
enumerated display will be used.

`--vulkan-display-mode=<n>`

The index of the display mode, of the selected Vulkan display, to use when
using the `displayvk` GPU context. Use `--vulkan-display-mode=help`
to see the list of available modes. If left unspecified, the first
enumerated mode will be used.

`--vulkan-display-plane=<n>`

The index of the plane, on the selected Vulkan device, to present on when
using the `displayvk` GPU context. Use `--vulkan-display-plane=help`
to see the list of available planes. If left unspecified, the first
enumerated plane will be used.

`--d3d11-exclusive-fs=<yes|no>`

Switches the D3D11 swap chain fullscreen state to 'fullscreen' when
fullscreen video is requested. Also known as "exclusive fullscreen" or
"D3D fullscreen" in other applications. Gives mpv full control of
rendering on the swap chain's screen. Off by default.

`--d3d11-warp=<yes|no|auto>`

Use WARP (Windows Advanced Rasterization Platform) with the D3D11 GPU
backend (default: auto). This is a high performance software renderer. By
default, it is only used when the system has no hardware adapters that
support D3D11. While the extended GPU features will work with WARP, they
can be very slow.

`--d3d11-output-mode=<auto|window|composition>`

Use a specific output mode for creating the D3D11 swapchain. "composition"
will not create a window. If you want to use the D3D11 GPU backend in WinUI
applications, you need to set this to "composition". "window" will create
a window and use the DWM to present the video. "auto" is the same as
"window". After creating the swapchain, you can get the swapchain address
(int64 type value) by getting the `display-swapchain` property.

`--d3d11-feature-level=<12_1|12_0|11_1|11_0|10_1|10_0|9_3|9_2|9_1>`

Select a specific feature level when using the D3D11 GPU backend. By
default, the highest available feature level is used. This option can be
used to select a lower feature level, which is mainly useful for debugging.
Most extended GPU features will not work at 9_x feature levels.

`--d3d11-flip=<yes|no>`

Enable flip-model presentation, which avoids unnecessarily copying the
backbuffer by sharing surfaces with the DWM (default: yes). This may cause
performance issues with older drivers. If flip-model presentation is not
supported (for example, on Windows 7 without the platform update), mpv will
automatically fall back to the older bitblt presentation model.

flip-model needs presentation needs to be disabled for background
