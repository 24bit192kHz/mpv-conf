# FAQ: Video & Hardware

## Tearing

Tearing is generally not something a video player can fix. It depends on hardware, drivers, video output (VO), and the desktop environment/compositor.

### macOS
Never seen it tear.

### Windows
Windows uses the d3d11 backend by default. Try options like `--d3d11-exclusive-fs`, `--d3d11-adapter=...`, `--angle-renderer=...`, or forcing other backends with `--gpu-context=...`.

Use `--d3d11-adapter=help` to see available GPUs. Windows often defaults to IntelHD when using an i-GPU. You can switch with e.g. `--d3d11-adapter="Radeon (TM) RX 470 Graphics"`.

### X11/Nvidia
Nvidia generally should not tear. Try:
- Enabling `ForceFullCompositionPipeline`
- Try with and without a compositor
- Disable Composite extension in xorg.conf
- Set performance mode to maximum performance
- Try `--vo=vdpau`
- For KDE: create `/etc/profile.d/kwin.sh` with `__GL_SYNC_TO_VBLANK=1` and `__GL_YIELD=USLEEP`

### X11/Nvidia with PRIME
If your Xorg ABI < 23, kernel < 4.5, or Nvidia driver is outdated, you WILL get tearing due to missing PRIME buffer synchronization. This cannot be fixed — switch to Intel GPU instead.

### X11/Intel
Intel tears out of the box. Enabling a compositor usually fixes it. Other options:
- Enable SNA and TearFree (may cause stability issues; try `i915.semaphores=1`)
- Try UXA on older hardware
- Try `--x11-bypass-compositor=no`
- Try `--vo=xv --xv-adaptor=N`
- Try `--vo=vaapi` (lower quality)
- With modesetting driver without compositor: run `compton --backend=glx`

### X11/AMD
- Avoid AMDGPU-PRO/fglrx (completely broken)
- With amdgpu: enable TearFree via `xrandr --set TearFree on` or xorg.conf
- For vulkan fullscreen tearing: add `Option "EnablePageFlip" "off"` to Device section

## I am using NVIDIA G-Sync on Windows and running mpv in fullscreen mode reduces the frame rate of other displays

Use `--opengl-backend=win` for exclusive fullscreen. This prevents the compositor from running at mpv's frame rate.

## Recommended GPU hardware

Since mpv renders video with shaders for quality, GPU hardware and driver quality are critical.

### amdgpu (open source)
Work pretty well. Discrete GPUs handle advanced settings. Newer Vega+ models cause more problems.

### amdgpu-pro (closed source)
Unknown. Open-source likely works better. You can switch to amdgpu.

### Intel
Hardware is weak, drivers chaotic. Works well up to medium settings with the right driver versions. Frequent bugs.

### Nvidia
Hardware is good but closed-source drivers are problematic: no presentation feedback in GL, system stability issues, weird quirks.

### Mobile
All mobile GPUs are bad for mpv's use case.

### ARM/Linux
All trash. Some RPI/Rockchip support exists.

## Hardware decoding doesn't work?

- Use `--hwdec=auto` or `--hwdec=auto-safe` or `--hwdec=auto-copy-safe`
- Make sure hwdec backends are compiled in
- Some codecs need `--hwdec-codecs=...`
- 10-bit h264 often can't be hardware decoded

Hardware decoding is not enabled by default because it's an additional source of errors. Only use it if your CPU is too slow.

## I'm using vo=vaapi or vo=vdpau, but there are problems

**DO NOT USE THESE VOs.** They are broken and old. These VOs are NOT required for hardware decoding. Use the default `--vo=gpu` with `--hwdec=auto` instead.

## Video on RPI doesn't work, or is too slow

Build mpv with an ffmpeg fork implementing the v4l2-request API. See [V4L2 drmprime support](wiki-v4l2-drmprime).

## HDR doesn't work on my monitor?

Use these settings to correct wrong color gamut, luminance, and HDR effects:

```ini
# For HD-TV 8-bit
--vf=format=colormatrix=bt.709:colorlevels=limited:primaries=bt.709:light=709-1886:gamma=srgb
# For UHD-TV
--vf=format=colormatrix=bt.2020-ncl:colorlevels=limited:primaries=bt.2020:light=709-1886:gamma=bt.1886
--target-trc=pq
--target-prim=auto
--dither-depth=auto
```

Also try tone mapping options: `--tone-mapping=bt.2390` (default), or `hable`, `reinhard`, `mobius`, etc.

## Player freezing when switching to fullscreen?

Try `--angle-flip=no` or `--d3d11-flip=no` for D3D11 backend.
