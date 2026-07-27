# FAQ: Platform

## Why don't I have any window decorations?

You're likely using GNOME Wayland or a Wayland compositor without xdg-decoration protocol support. Mutter has no plans to deviate from client-side decorations. mpv draws pseudo-client side decorations via the OSC by default.

## NVIDIA and Wayland

Since NVIDIA 495.29.05 beta, GBM and VK_KHR_wayland_surface are supported. Sway works correctly, but GNOME and KDE have hardcoded EGLStreams detection that was dropped in Mutter 42.0+ and KWin 5.23.2+. If things don't work, try `--opengl-es=yes`.

## Should I use X11 or Wayland?

mpv supports both. Provided you have working drivers/hardware (not NVIDIA) and aren't using broken compositors, both backends perform equally well. mpv only supports upstream wayland-protocols, not desktop-specific libraries.

## I want the old PulseAudio volume control back on Linux

Since mpv 0.18.1, volume control is forced to softvol. This means:
- Volume changes affect only the current mpv instance
- Volume is not saved across instances
- Volume is not limited to 100%

To get the old PulseAudio behavior, edit your `input.conf`:

```
9   add ao-volume -2
0   add ao-volume 2
```

Replace `volume` with `ao-volume` for other bindings too.

## I want the old OSC back

In mpv 0.21.0 the default OSC changed to bottom bar. Create `script-opts/osc.conf`:

```
layout=box seekbarstyle=slider deadzonesize=0 minmousemove=3
```

For pre-0.22.0 scale behavior with bottombar/topbar:

```
scalewindowed=0.666 scalefullscreen=0.666
```

## On Windows, why does mpv.exe not attach to the console and what does mpv.com do?

Windows has two subsystems: GUI and CLI. mpv.exe uses the GUI subsystem (no console). mpv.com uses the CLI subsystem and redirects I/O for mpv.exe. Since .com files are checked first by %PATHEXT%, typing `mpv` on the command prompt runs mpv.com.

## How do I automatically play the next file in the folder?

Either pass all files: `mpv *.*`, or use the [autoload script](https://github.com/mpv-player/mpv/blob/master/TOOLS/lua/autoload.lua).

## How can I make mpv the default application for opening movie files on macOS?

1. Install via Homebrew: `brew install mpv`
2. Use duti for file associations:

```bash
brew install duti
duti -s io.mpv avi all
duti -s io.mpv mkv all
duti -s io.mpv mp4 all
```

For macOS Big Sur+, also try [openwith](https://github.com/jdek/openwith).

## Why were some cache options removed or changed (stream cache)?

Since mpv 0.30.0, the stream cache (ringbuffer between demuxer and network) was removed. Caching is now done between demuxer and decoder:

```
--cache-secs=...
--demuxer-readahead-secs=...
--demuxer-max-bytes=...(KiB/MiB)
--demuxer-max-back-bytes=...(KiB/MiB)
--cache-on-disk   # replaces --cache-file
```

The old stream cache wasted memory, reduced performance, and caused bugs.

## X11/Intel with modesetting driver (no compositor)

Run a compositor during playback. [Compton](https://github.com/chjj/compton) with GLX backend:

```bash
compton --backend=glx
```

Then start mpv. See [this archived post](https://web.archive.org/web/20180916133157/https://whirm.eu/posts/fix-for-xorgs-modesetting-driver-tearing/) for details.
