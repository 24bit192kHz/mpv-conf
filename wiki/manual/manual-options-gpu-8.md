See `--sub-color` for color syntax.

`--macos-fs-animation-duration=<default|0-1000>`

Sets the fullscreen resize animation duration in ms (default: default).
The default value is slightly less than the system's animation duration
(500ms) to prevent some problems when the end of an async animation happens
at the same time as the end of the system wide fullscreen animation. Setting
anything higher than 500ms will only prematurely cancel the resize animation
after the system wide animation ended. The upper limit is still set at
1000ms since it's possible that Apple or the user changes the system
defaults. Anything higher than 1000ms though seems too long and shouldn't be
set anyway.
(macOS)

`--macos-app-activation-policy=<regular|accessory|prohibited>`

Changes the App activation policy. With accessory the mpv icon in the Dock
can be hidden. (default: regular)

macOS only.

`--macos-geometry-calculation=<visible|whole>`

This changes the rectangle which is used to calculate the screen position
and size of the window (default: visible). `visible` takes the the menu
bar and Dock into account and the window is only positioned/sized within the
visible screen frame rectangle, `whole` takes the whole screen frame
rectangle and ignores the menu bar and Dock. Other previous restrictions
still apply, like the window can't be placed on top of the menu bar etc.

macOS only.

`--macos-render-timer=<timer>`

Sets the mode (default: callback) for syncing the rendering of frames to the display's
vertical refresh rate.
macOS and Vulkan (macvk) only.

`<timer>` can be one of the following:
| callback: | Syncs to the CVDisplayLink callback |
| --- | --- |
| precise: | Syncs to the time of the next vertical display refresh reported by the
CVDisplayLink callback provided information |
| system: | No manual syncing, depend on the layer mechanic and the next drawable |
| feedback: | Same as precise but uses the presentation feedback core mechanism |

`--macos-menu-shortcuts=<yes|no>`

Enables the default menu bar shortcuts (default: yes). The menu bar shortcuts always take
precedence over any other shortcuts, they are not propagated to the mpv core and they can't be
used in config files like `input.conf` or script bindings.

`--macos-bundle-path=path1,path2,...`

App Bundles operate in their own shell environment that is different from the one in the
terminal. The default PATH variable for all Bundles is `/usr/bin:/bin:/usr/sbin:/sbin`.
Because of that mpv can not find binaries installed by package manager that might be used in
scripts for example. This option prepends all given paths to the default Bundle PATH.

Default value in following order:
| /usr/local/bin: | homebrew (Intel) install path |
| --- | --- |
| /usr/local/sbin: |
|  | homebrew (Intel) install path |
| /opt/local/bin: | MacPorts install path |
| /opt/local/sbin: |
|  | MacPorts install path |
| /opt/homebrew/bin: |
|  | homebrew (ARM) install path |
| /opt/homebrew/sbin: |
|  | homebrew (ARM) install path |

`--android-surface-size=<WxH>`

Set dimensions of the rendering surface used by the Android gpu context.
Needs to be set by the embedding application if the dimensions change during
runtime (i.e. if the device is rotated), via the surfaceChanged callback.

Android with `--gpu-context=android` only.

`--d3d11-composition-size=<WxH>`

Set size of the output for d3d11 composition mode.
When use composition mode, there is no window, must set the output size by
the embedding application.

Windows with `--gpu-context=d3d11` and  `--d3d11-output-mode=composition` only.

`--gpu-sw`

Continue even if a software renderer is detected. This only works with
OpenGL/Vulkan backends. For d3d11, see `--d3d11-warp`.

`--gpu-context=<context1,context2,...[,]>`

Specify a priority list of the GPU contexts to be used.
The value `auto` (the default) selects the GPU context with the default autoprobe
order. You can also pass `help` to get a complete list of compiled in backends
(sorted by the default autoprobe order).

Note that the default GPU context is subject to change, and must not be relied upon.
If a certain GPU context needs to be used, it must be explicitly specified.

auto

auto-select (default). Note that this context must be used alone and
does not participate in the priority list.

win

Win32/WGL

winvk

VK_KHR_win32_surface

angle

Direct3D11 through the OpenGL ES translation layer ANGLE. This supports
almost everything the `win` backend does (if the ANGLE build is new
enough).

dxinterop (experimental)

Win32, using WGL for rendering and Direct3D 9Ex for presentation. Works
on Nvidia and AMD. Newer Intel chips with the latest drivers may also
work.

d3d11

Win32, with native Direct3D 11 rendering.

x11

X11/GLX (deprecated/legacy, EGL is preferred these days)

x11vk

VK_KHR_xlib_surface

wayland

Wayland/EGL

waylandvk

VK_KHR_wayland_surface

drm

DRM/EGL

displayvk

VK_KHR_display. This backend is roughly the Vulkan equivalent of
DRM/EGL, allowing for direct rendering via Vulkan without a display
manager.

x11egl

X11/EGL

android

Android/EGL. Requires `--wid` be set to an `android.view.Surface`.

macvk

Vulkan on macOS with a metal surface through a translation layer (experimental)

This is an object settings list option. See [List Options](manual-options-track.md) for details.

`--gpu-api=<type1,type2,...[,]>`

Specify a priority list of accepted graphics APIs.

auto

Use any available API (default). Note that the default GPU API used for this
value is subject to change, and must not be relied upon. If a certain GPU API
needs to be used, it must be explicitly specified.

opengl

Allow only OpenGL (requires OpenGL 2.1+ or GLES 2.0+)

vulkan

Allow only Vulkan (requires a valid/working `--spirv-compiler`)

d3d11

Allow only `--gpu-context=d3d11`

