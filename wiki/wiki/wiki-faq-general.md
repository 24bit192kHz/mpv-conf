# FAQ: General

## Does mpv have an official GUI?

No. But there is the OSC (on-screen-controller), which lets you control playback with the mouse. Requires mpv to be compiled with Lua support.

There are some [3rd party GUI frontends](wiki-apps-using-mpv).

## I can't see the OSC/OSD/GUI!

The OSC requires Lua support. Install Lua 5.1, 5.2, or LuaJIT with development headers, and rebuild mpv. mpv does not and is unlikely to ever support Lua 5.3 or newer. If you didn't build mpv yourself, ask the packager to enable Lua.

Also, note that the OSC is invisible by default but appears once you move the mouse over the mpv window.

## I can't see the window when mpv plays audio files.

Use `--force-window`.

## If I click mpv, nothing happens.

mpv is a command line program and doesn't provide an actual GUI. You need to start it with a media file. On Windows, you can create a file association with the `Open with...` context menu. Also, if you start `mpv.exe` from `explorer.exe`, it will enter pseudo-gui mode. For Linux, a `mpv.desktop` file is provided.

You can also start mpv with `mpv --player-operation-mode=pseudo-gui`. Play files by dropping them on the window.

## What's the difference between high-quality, gpu-hq etc.?

The GPU shader-based rendering VO was renamed and updated a few times:

- `--vo=gpu` is essentially the default
- `--profile=high-quality` selects advanced scaling presets (replaces `gpu-hq`)
- `--profile=fast` selects "dumb" rendering for limited hardware
- GPU supports multiple backends: d3d11, opengl, vulkan (used in order). Use `--gpu-api=vulkan` to force vulkan.

## How can I find out the names and commands associated with each key?

Run mpv in input test mode: `mpv --input-test --force-window --idle`

## Help mpv doesn't disable the screensaver during playback

Some screensavers (like xscreensaver) do not use standard APIs. If you need to run xscreensaver-command or xdg-screensaver, write a Lua script to do so. See [disabling screensaver in the manual](https://mpv.io/manual/master/#disabling-screensaver).

## How does youtube-dl work? Does it download the stream to disk?

The mpv youtube-dl wrapper script calls `youtube-dl --dump-single-json` on URLs that begin with http(s). This returns a direct media link from which mpv streams directly. Nothing is downloaded to disk. Once playback starts, youtube-dl has exited and is not active anymore.

## How is mpv related to MPlayer?

The relation is mostly historic. They should be considered two separate projects. mpv is based on MPlayer's code through the mplayer2 fork (2008), then forked again in 2012. mpv and MPlayer are different software, incompatible with each other. There is no overlap in developers. [Summary of changes](https://github.com/mpv-player/mpv/blob/master/DOCS/mplayer-changes.rst)

## Why does mpv not support Lua 5.3 or newer?

There are hundreds of mpv user scripts targeting Lua 5.1/5.2/jit. Lua 5.3 is a different language with integer types and other incompatibilities. Switching would break most user scripts and drop LuaJIT support. Supporting both languages would require significant effort and may be impossible with distro-provided libs.

## What is the rar file format and why is it stupid?

RAR is a proprietary archive format. Multimedia-wise, distributing video in multi-volume RAR archives is an unnecessary relic. mpv handles these via libarchive, but multi-volume support is not great. Please don't report bugs — pester libarchive instead.

## Why is there no DVD/Bluray menu support?

DVD/Bluray menu code was removed due to maintenance issues. It never worked well and prevented improving other areas. The developers consider menu support "cursed." Playing ripped files gives a better experience anyway. Developers are welcome to contribute, but must keep the code isolated from the playback core.

## How do I create a Conditional auto profile that applies to all videos (or all audio)?

```ini
# Applies to all videos
[video]
profile-cond=p["current-tracks/video/albumart"] == false

# Applies to all audio
[audio]
profile-cond=not vid and not vo_configured or p["current-tracks/video/albumart"]
```

## How do I rotate videos?

Cycle `video-rotate` values in 90° steps in `input.conf`:

```
r cycle-values video-rotate 270 180 90 0
t cycle-values video-rotate 90 180 270 0
```

## How do I apply a profile only once with Auto Profiles?

```ini
[some_profile]
profile-cond = not p["user-data/some-profile-applied"]
input-commands = no-osd set user-data/some-profile-applied 1
```
