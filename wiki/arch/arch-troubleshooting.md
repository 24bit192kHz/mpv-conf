## Troubleshooting

### General debugging

If you are having trouble with _mpv_'s playback (or if it is flat out failing to run) then the first three things you should do are:

1. Run _mpv_ from the command line (the -v flag increases verbosity). If you are lucky there will be an error message there telling you what is wrong.
   `$ mpv -v video.mkv`
2. Have _mpv_ output a log file. The log file might be difficult to sift through but if something is broken you might see it there.
   `$ mpv -v --log-file=./log video.mkv`
3. Run _mpv_ without a configuration. If this runs well then the problem is somewhere in your configuration (perhaps your hardware cannot keep up with your settings).
   `$ mpv --no-config video.mkv`

If _mpv_ runs but it just does not run well then a fourth thing that might be worth taking a look at is the live statistics (with `i`) to see exactly how it is performing.

### Fix jerky playback and tearing

_mpv_ defaults to using the OpenGL video output device setting on hardware that supports it. In cases such as trying to play video back on a 4K display using an Intel HD4XXX series card or similar, you will find video playback unreliable, jerky to the point of stopping entirely at times and with major tearing when using any OpenGL output setting. If you experience any of these issues, using the XV ([Xorg](https://wiki.archlinux.org/title/Xorg) only) video output device may help:

```
vo=xv
```

**Note:** This is the most compatible VO on X, but may be low-quality, and has issues with OSD and subtitle display.

It is possible to increase playback performance even more (especially on lower hardware), but this decreases the video quality dramatically in most cases.

The following [options](arch-configuration.md) may be considered to increase the video playback performance:

```
vd-lavc-fast
vd-lavc-skiploopfilter=skipvalue
vd-lavc-skipframe=skipvalue
vd-lavc-framedrop=skipvalue
vd-lavc-threads=threads
```

### Problems with window compositors

As described in `man mpv` (Window section), mpv by default disables any active window [compositor](https://wiki.archlinux.org/title/Xorg#Composite) while in fullscreen mode. This is done to prevent potential performance issues during playback.

For window compositors such as KWin or Mutter, it can be advantageous to disable window compositing even while in windowed mode. This can be achieved by using the `x11-bypass-compositor=yes` option.

There are two disadvantages to disabling compositing:

- Re-enabling compositing may introduce stutter for a period of time, particularly if using KWin compositing.
- Any effects provided by compositing will be temporarily unavailable (until mpv re-enables it), which in [Plasma](https://wiki.archlinux.org/title/Plasma) prevents the default app switcher from working.

To sidestep these issues, you can try keeping your compositor enabled with `x11-bypass-compositor=no`.

### No volume bar, cannot change volume

Spin the mouse wheel over the volume icon.

### GNOME Blank screen (Wayland)

_mpv_ may not suspend GNOME's Power Saving Settings if using Wayland resulting in screen saver turning off the monitor during video playback. A workaround is to add `gnome-session-inhibit` to the beginning of the `Exec=` line in `mpv.desktop`.

In order to inhibit the screensaver only during playback, use `mpv_inhibit_gnome`. Alternatively, a [mpv lua script](https://gist.github.com/crazygolem/a7d3a2d3c0cee5d072c0cbbbdee69286) based on `gnome-session-inhibit` may be used.

**Tip:** The `io.mpv.Mpv` flatpak app already includes the [mpv_inhibit_gnome](https://github.com/Guldoman/mpv_inhibit_gnome) plugin.

### Cursor theme not respected under GNOME Wayland

See [GNOME/Troubleshooting#Cursor size or theme issues on Wayland](https://wiki.archlinux.org/title/GNOME/Troubleshooting#Cursor_size_or_theme_issues_on_Wayland).

### Error message about missing CUDA libraries on AMD GPUs

While using VAAPI hardware acceleration on AMD GPUs on versions [v0.34.1](https://github.com/mpv-player/mpv/releases/tag/v0.34.1) and older, you may see a persistent error message saying `Cannot load libcuda.so.1`. This can be suppressed by setting `gpu-hwdec-interop=vaapi`.

Related bug reports: [GitHub issue #9691](https://github.com/mpv-player/mpv/issues/9691), [GitHub issue #8765](https://github.com/mpv-player/mpv/issues/8765).

This issue has been fixed upstream in [pull request #9842](https://github.com/mpv-player/mpv/pull/9842).

### Unable to play audio if PipeWire is masked

If _mpv_ crashes or fails to play audio on systems where [PipeWire](https://wiki.archlinux.org/title/PipeWire) is [masked](https://wiki.archlinux.org/title/Mask), reporting no outputs or broken pipe, set the `--ao` option to match your environment. Set it in `mpv.conf` for persistent configuration.

### mpv will not start playing a DVD from file

If _mpv_ will not play a DVD from file in plain VIDEO_TS/VOB structure, there could be a problem with the restore playback position function. Try either cleaning `.config/mpv/watch_later` folder, or start _mpv_ with the `no-resume-playback` option and/or set the `save-position-on-quit=no` option.

### Fix stuttering after resuming playback from pause

If video is stuttering with [PulseAudio](https://wiki.archlinux.org/title/PulseAudio), try the `pulse-latency-hacks` option discussed in `man mpv`:

```
pulse-latency-hacks=yes
```

### Screen sharing cannot capture audio from mpv

For example, when you share _mpv_ into Discord with Discord's "Share a window" functionality and specify that audio should be shared as well, yet Discord fails to capture _mpv_'s audio.

This has been observed when the system uses [PipeWire](https://wiki.archlinux.org/title/PipeWire). Then, by default, _mpv_ uses its `pipewire` audio output driver, which may cause this issue.

The solution is to switch _mpv_ to its `pulse` audio output driver. This should be uncritical as PipeWire also implements [PulseAudio](https://wiki.archlinux.org/title/PulseAudio)'s audio API.

When running _mpv_ from the command line this can be done by supplying the `--ao=pulse` option.

To permanently make _mpv_ use its PulseAudio audio output driver you can put an `ao=pulse` text line into an _mpv_ configuration file.

### Lack of emojis in the media title

If some emojis are not displayed in the media title, install a font that contains monochromatic emojis, such as [Noto Emoji](https://fonts.google.com/noto/specimen/Noto+Emoji/glyphs) (`ttf-noto-emoji-monochrome`) -- Google open-source emoji font, black and white. See the upstream issue [#9073](https://github.com/mpv-player/mpv/issues/9073). Colored emojis are not yet supported by `libass`.
