# mpv Wiki

Converted from the [mpv-player/mpv wiki](https://github.com/mpv-player/mpv/wiki) into clean, searchable markdown files.

## Home

| File | Description |
|------|-------------|
| [Home](wiki-home.md) | Landing page with links to manual, FAQ, downloads, and user scripts |

## Frequently Asked Questions

| File | Description |
|------|-------------|
| [FAQ: General](wiki-faq-general.md) | GUI, OSC, screensaver, profiles, mpv vs MPlayer, Lua 5.3, DVD/BD, RAR, rotation |
| [FAQ: Video & Hardware](wiki-faq-video.md) | Tearing (all platforms), GPU recommendations, HW decoding, HDR, VOs, RPI |
| [FAQ: Platform](wiki-faq-platform.md) | macOS, Windows, NVIDIA+Wayland, X11 vs Wayland, PulseAudio, OSC, cache, window decorations |
| [FAQ: Streaming & YouTube](wiki-faq-streaming.md) | YouTube playlists, video quality selection, format codes |

## User Scripts

| File | Description |
|------|-------------|
| [User Scripts Intro](wiki-user-scripts-intro.md) | Overview, script locations, external lists, JavaScript scripts |
| [Lua Scripts A-C](wiki-user-scripts-lua-a-c.md) | abs-screenshot, autoload, autocrop, bookmarks, boss-key, chapters, clipboard, crop, cycle |
| [Lua Scripts D-M](wiki-user-scripts-lua-d-m.md) | dbvol, delogo, encode, equalizer, fastforward, file-browser, gallery, history, image-viewer, interSubs, lua-mpris |
| [Lua Scripts mpv-\*](wiki-user-scripts-lua-mpv.md) | mpv-clipper, mpv_sponsorblock, mpv-thumbnail-script, notify, ontop, OSC replacements |
| [Lua Scripts P-Z](wiki-user-scripts-lua-p-z.md) | pause-indicator, playlistmanager, progressbar, reload, subtitle tools, thumbfast, uosc, youtube scripts |
| [User Shaders](wiki-user-scripts-shaders.md) | Anime4K, FSR, CAS, NNEDI3, FSRCNN, deband, antiringing, prescalers |
| [VapourSynth, C Plugins, Other](wiki-user-scripts-vapoursynth-c-other.md) | MVTools, mpris, Discord RPC, web extensions |

## Technical Articles

| File | Description |
|------|-------------|
| [GPU-next vs GPU](wiki-gpu-next-vs-gpu.md) | Differences between vo=gpu and vo=gpu-next video outputs |
| [Display Sync](wiki-display-sync.md) | How `--video-sync=display` works, frame drops, troubleshooting |
| [Interpolation](wiki-interpolation.md) | Motion interpolation with `--interpolation`, tscale options, vo_gpu-next notes |
| [Which VO to Use](wiki-which-vo.md) | Why you should use vo_gpu (not vo_vaapi/vo_vdpau), troubleshooting |
| [Upscaling](wiki-upscaling.md) | Recommended upscaling settings with comparison images |
| [Downscaling (Hermite)](wiki-downscaling-hiermite.md) | Default `--dscale=hermite` change rationale |
| [Shaders Stage Diagram](wiki-shader-stage-diagram.md) | Conceptual diagram of GPU processing stages |

## Configuration & Options

| File | Description |
|------|-------------|
| [Option Replacement List](wiki-option-replacement-list.md) | Comprehensive mapping of removed/changed options to current replacements |
| [Hardware Decoding (Linux)](wiki-hardware-decoding-linux.md) | Intel/AMD VA-API setup instructions |
| [V4L2 DRM-Prime](wiki-v4l2-drmprime.md) | v4l2 drmprime support in mpv, ffmpeg forks for RPI |
| [Zsh Completion](wiki-zsh-completion.md) | Customizing mpv's zsh completion: file extensions, URLs |
| [IR Remotes](wiki-ir-remotes.md) | Using IR remotes via evdev, lirc/irxevent alternative |

## Platform-Specific

| File | Description |
|------|-------------|
| [Compiling macOS](wiki-compiling-macos.md) | Building mpv on macOS with Homebrew, bundling libs |
| [ALSA Surround Sound](wiki-alsa-surround.md) | Surround sound setup with ALSA and AVRs |
| [V4L2 Input](wiki-v4l2-input.md) | Using mpv with V4L2 video devices |
| [Cocoa Constraints](wiki-cocoa-constraints.md) | macOS Cocoa-specific constraints (semi-obsolete) |
| [Fixing Simulcasts](wiki-fixing-simulcasts.md) | HD simulcast aspect ratio fix with `--aspect` |
| [libavformat MKV Checklist](wiki-libavformat-mkv-checklist.md) | Debugging MKV playback issues |

## Applications Using mpv

| File | Description |
|------|-------------|
| [Apps Using mpv](wiki-apps-using-mpv.md) | Frontends (celluloid, IINA, Baka MPlayer), CLI tools (mps-youtube, ytfzf), daemons |

## Development

| File | Description |
|------|-------------|
| [Stuff to Do](wiki-stuff-to-do.md) | Ideas for implementation in mpv |
| [Language Bindings](wiki-language-bindings.md) | Internal (Lua, JS) and external (Python, Ruby, JS) bindings |
| [Scripting Language Bindings](wiki-scripting-language-bindings.md) | External link to bindings page |

## Obsolete Pages

| File | Description |
|------|-------------|
| [Config & CmdLine (obsolete)](wiki-obsolete-config-cmdline.md) | Old brainstorming about sub-option handling |
| [Filter Benchmark (obsolete)](wiki-obsolete-filter-benchmark.md) | Outdated Lua filter performance benchmarks |

## Image Directories

| Directory | Description |
|-----------|-------------|
| `interpolation/` | Comparison images showing interpolation behavior at various refresh rates |
| `upscaling/` | Comparison images of different upscaling methods |

---

*Converted from the mpv wiki. Last updated: 2026-07-09*
