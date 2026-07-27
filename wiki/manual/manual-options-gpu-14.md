options). Could be removed any time.

`--opengl-early-flush=<yes|no|auto>`

Call `glFlush()` after rendering a frame and before attempting to display
it (default: auto). Can fix stuttering in some cases, in other cases
probably causes it. The `auto` mode will call `glFlush()` only if
the renderer is going to wait for a while after rendering, instead of
flipping GL front and backbuffers immediately (i.e. it doesn't call it
in display-sync mode).

On macOS this is always deactivated because it only causes performance
problems and other regressions.

`--gpu-dumb-mode=<yes|no|auto>`

This mode is extremely restricted, and will disable most extended
features. That includes high quality scalers and custom shaders!

It is intended for hardware that does not support FBOs (including GLES,
which supports it insufficiently), or to get some more performance out of
bad or old hardware.

This mode is forced automatically if needed, and this option is mostly
useful for debugging. The default of `auto` will enable it automatically
if nothing uses features which require FBOs.

This option might be silently removed in the future.

`--gpu-shader-cache`

Store and load compiled GLSL shaders in the cache directory (Default:
`yes`). Normally, shader compilation is very fast, so this is not usually
needed. It mostly matters for anything involving GLSL to SPIR-V conversion,
that is: D3D11, ANGLE or Vulkan, as well as on some other proprietary
drivers. Enabling this can improve startup performance on these platforms.

On <cite>--vo=gpu-next</cite>, files that have not been accessed in the last 24 hours
may be cleared if the cache limit (128 MiB) is exceeded.

On `--vo=gpu`, this is not cleaned automatically, so old, unused cache
files may stick around indefinitely.

`--gpu-shader-cache-dir`

The directory where gpu shader cache is stored. Cache is stored in the system's
cache directory (usually `~/.cache/mpv`) if this is unset.

`--libplacebo-opts=<key>=<value>[,<key>=<value>[,...]]`

Passes extra raw option to the libplacebo rendering backend (used by
`--vo=gpu-next`). May override the effects of any other options set using
the normal options system. Requires libplacebo v6.309 or higher. Included
for debugging purposes only. For more information, see:

[https://libplacebo.org/options/](https://libplacebo.org/options/)
