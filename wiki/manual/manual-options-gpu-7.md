Selects a specific feature level when using the ANGLE backend with D3D11.
By default, the highest available feature level is used. This option can be
used to select a lower feature level, which is mainly useful for debugging.
Note that OpenGL ES 3.0 is only supported at feature level 10_1 or higher.
Most extended OpenGL features will not work at lower feature levels
(similar to `--gpu-dumb-mode`).

Windows with ANGLE only.

`--angle-d3d11-warp=<yes|no|auto>`

Use WARP (Windows Advanced Rasterization Platform) when using the ANGLE
backend with D3D11 (default: auto). This is a high performance software
renderer. By default, it is used when the Direct3D hardware does not
support Direct3D 11 feature level 9_3. While the extended OpenGL features
will work with WARP, they can be very slow.

Windows with ANGLE only.

`--angle-egl-windowing=<yes|no|auto>`

Use ANGLE's built in EGL windowing functions to create a swap chain
(default: auto). If this is set to `no` and the D3D11 renderer is in use,
ANGLE's built in swap chain will not be used and a custom swap chain that
is optimized for video rendering will be created instead. If set to
`auto`, a custom swap chain will be used for D3D11 and the built in swap
chain will be used for D3D9. This option is mainly for debugging purposes,
in case the custom swap chain has poor performance or does not work.

If set to `yes`, the `--angle-flip` option will have no effect.

Windows with ANGLE only.

`--angle-flip=<yes|no>`

Enable flip-model presentation, which avoids unnecessarily copying the
backbuffer by sharing surfaces with the DWM (default: yes). This may cause
performance issues with older drivers. If flip-model presentation is not
supported (for example, on Windows 7 without the platform update), mpv will
automatically fall back to the older bitblt presentation model.

If set to `no`, the `--angle-swapchain-length` option will have no
effect.

Windows with ANGLE only.

`--angle-renderer=<d3d9|d3d11|auto>`

Forces a specific renderer when using the ANGLE backend (default: auto). In
auto mode this will pick D3D11 for systems that support Direct3D 11 feature
level 9_3 or higher, and D3D9 otherwise. This option is mainly for
debugging purposes. Normally there is no reason to force a specific
renderer, though `--angle-renderer=d3d9` may give slightly better
performance on old hardware. Note that the D3D9 renderer only supports
OpenGL ES 2.0, so most extended OpenGL features will not work if this
renderer is selected (similar to `--gpu-dumb-mode`).

Windows with ANGLE only.

`--macos-force-dedicated-gpu=<yes|no>`

Deactivates the automatic graphics switching and forces the dedicated GPU.
(default: no)

macOS only.

`--cocoa-cb-sw-renderer=<yes|no|auto>`

Use the Apple Software Renderer when using cocoa-cb (default: auto). If set
to `no` the software renderer is never used and instead fails when a the
usual pixel format could not be created, `yes` will always only use the
software renderer, and `auto` only falls back to the software renderer
when the usual pixel format couldn't be created.

macOS and cocoa-cb only.

`--cocoa-cb-10bit-context=<yes|no>`

Creates a 10bit capable pixel format for the context creation (default: yes).
Instead of 8bit integer framebuffer a 16bit half-float framebuffer is
requested.

macOS and cocoa-cb only.

`--cocoa-cb-output-csp=<csp>`

This sets the color space of the layer to activate the macOS color
transformation. Depending on the color space used the system's EDR (HDR)
support will be activated. To get correct results, this needs to be set to
the color primaries/transfer characteristics of the VO target. It is recommended
to use this switch together with `--target-trc` and `--target-prim`.

`<csp>` can be one of the following:
| auto: | Sets the color space to the icc profile of the
screen (default). |
| --- | --- |
| display-p3: | DCI P3 primaries, a D65 white point and the sRGB
transfer function. |
| display-p3-hlg: | DCI P3 primaries, a D65 white point and the Hybrid
Log-Gamma (HLG) transfer function. |
| display-p3-pq: | DCI P3 primaries, a D65 white point and the Perceptual
Quantizer (PQ) transfer function. |
| display-p3-linear: |
|  | DCI P3 primaries, a D65 white point and linear transfer function. |
| dci-p3: | DCI P3 color space. |
| bt.2020: | ITU BT.2020 color space. |
| bt.2020-linear: | ITU BT.2020 color space and linear transfer function. |
| bt.2100-hlg: | ITU BT.2100 and the Hybrid Log-Gamma (HLG) transfer function. |
| bt.2100-pq: | ITU BT.2100 and the Perceptual Quantizer (PQ) transfer function. |
| bt.709: | ITU BT.709 color space. |
| srgb: | sRGB colorimetry and non-linear transfer function. |
| srgb-linear: | Same as sRGB but linear transfer function. |
| rgb-linear: | RGB and linear transfer function. |
| adobe: | Adobe RGB (1998) color space. |

macOS and cocoa-cb only.

`--macos-title-bar-appearance=<appearance>`

Sets the appearance of the title bar (default: auto). Not all combinations
of appearances and `--macos-title-bar-material` materials make sense or
are unique. Appearances that are not supported by you current macOS version
fall back to the default value.
macOS only

`<appearance>` can be one of the following:
| auto: | Detects the system settings and sets the title
bar appearance appropriately. On macOS 10.14 it
also detects run time changes. |
| --- | --- |
| aqua: | The standard macOS Light appearance. |
| darkAqua: | The standard macOS Dark appearance. (macOS 10.14+) |
| vibrantLight: | Light vibrancy appearance with. |
| vibrantDark: | Dark vibrancy appearance with. |
| aquaHighContrast: |
|  | Light Accessibility appearance. (macOS 10.14+) |
| darkAquaHighContrast: |
|  | Dark Accessibility appearance. (macOS 10.14+) |
| vibrantLightHighContrast: |
|  | Light vibrancy Accessibility appearance.
(macOS 10.14+) |
| vibrantDarkHighContrast: |
|  | Dark vibrancy Accessibility appearance.
(macOS 10.14+) |

`--macos-title-bar-material=<material>`

Sets the material of the title bar (default: titlebar). All deprecated
materials should not be used on macOS 10.14+ because their functionality
is not guaranteed. Not all combinations of materials and
`--macos-title-bar-appearance` appearances make sense or are unique.
Materials that are not supported by you current macOS version fall back to
the default value.
macOS only

`<material>` can be one of the following:
| titlebar: | The standard macOS title bar material. |
| --- | --- |
| selection: | The standard macOS selection material. |
| menu: | The standard macOS menu material. (macOS 10.11+) |
| popover: | The standard macOS popover material. (macOS 10.11+) |
| sidebar: | The standard macOS sidebar material. (macOS 10.11+) |
| headerView: | The standard macOS header view material.
(macOS 10.14+) |
| sheet: | The standard macOS sheet material. (macOS 10.14+) |
| windowBackground: |
|  | The standard macOS window background material.
(macOS 10.14+) |
| hudWindow: | The standard macOS hudWindow material. (macOS 10.14+) |
| fullScreen: | The standard macOS full screen material.
(macOS 10.14+) |
| toolTip: | The standard macOS tool tip material. (macOS 10.14+) |
| contentBackground: |
|  | The standard macOS content background material.
(macOS 10.14+) |
| underWindowBackground: |
|  | The standard macOS under window background material.
(macOS 10.14+) |
| underPageBackground: |
|  | The standard macOS under page background material.
(deprecated in macOS 10.14+) |
| dark: | The standard macOS dark material.
(deprecated in macOS 10.14+) |
| light: | The standard macOS light material.
(macOS 10.14+) |
| mediumLight: | The standard macOS mediumLight material.
(macOS 10.11+, deprecated in macOS 10.14+) |
| ultraDark: | The standard macOS ultraDark material.
(macOS 10.11+ deprecated in macOS 10.14+) |

`--macos-title-bar-color=<color>`

Sets the color of the title bar (default: completely transparent). Is
influenced by `--macos-title-bar-appearance` and
`--macos-title-bar-material`.
