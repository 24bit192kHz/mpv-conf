## Tips and tricks

### Picture

#### Hardware video acceleration

See [Hardware video acceleration](https://wiki.archlinux.org/title/Hardware_video_acceleration).

Hardware accelerated video decoding is available via the `--hwdec=API` option. For a list of all supported APIs and other required options, see `man mpv` (hwdec section).

To make it permanent (for example when playing videos from a desktop environment), add it to the configuration file:

```
hwdec=auto
```

To allow CPU processing with video filters, choose a `*-copy` API.

Use the keyboard shortcut `Ctrl+h` while a video is running to toggle hardware decoding.

To troubleshoot hardware acceleration, adjusting the logging levels (see `man mpv` msg-level) may be necessary. For instance, `--msg-level=vd=v,vo=v,vo/gpu/vaapi-egl=trace` enables the following:

- _Verbose_ messages from the video decoder (`vd`) and video output (`vo`) modules.
- Even more detailed _trace_ messages for the module responsible for video decoding. Here, after running mpv once without any log levels adjusted, the module of interest was empirically determined to be `vo/gpu/vaapi-egl`.

#### Quickly cycle between aspect ratios

You can cycle between aspect ratios using `Shift+a`.

#### Ignoring aspect ratio

You can ignore the aspect ratio using `--keepaspect=no`. To make the option permanent, add the line `keepaspect=no` to the configuration file.

#### Draw to the root window

Run _mpv_ with `--wid=0`. _mpv_ will draw to the window with a window ID of 0.

#### Always show the application window

To show the application window even for audio files when launching mpv from the command line, use the `--force-window` option. To make the option permanent, add the line `force-window=yes` to the configuration file.

#### Disable video output

To disable video output when launching from command line, use the `--vid=no` option, or its alias, `--no-video`.

#### Terminal video

- `--vo=tct` -- "Color Unicode art video output driver that works on a text console."
- `--vo=caca` -- "Color ASCII art video output driver that works on a text console." `libcaca` support has been disabled on Arch due to vulnerabilities (see FS#70962) and has not been added back in as its upstream is inactive: install `mpv-full`.
- `--vo=kitty` -- "Using Kitty protocol for video output that works on all terminals that support this protocol."
