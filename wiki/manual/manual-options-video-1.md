## Video

`--vo=<driver>`

Specify the video output backend to be used. See [VIDEO OUTPUT DRIVERS](manual-video-output-drivers-1.md) for
details and descriptions of available drivers.

`--vd=<...>`

Specify a priority list of video decoders to be used, according to their
family and name. See `--ad` for further details. Both of these options
use the same syntax and semantics; the only difference is that they
operate on different codec lists.

Note

See `--vd=help` for a full list of available decoders.

`--vf=<filter1[=parameter1:parameter2:...],filter2,...>`

Specify a list of video filters to apply to the video stream. See
[VIDEO FILTERS](manual-video-filters-1.md) for details and descriptions of the available filters.
The option variants `--vf-add`, `--vf-pre`, and `--vf-clr` exist
to modify a previously specified list, but you should not need these for
typical use.

`--untimed`

Do not sleep when outputting video frames. Useful for benchmarks when used
with `--audio=no`.

`--framedrop=<mode>`

Skip displaying some frames to maintain A/V sync on slow systems, or
playing high framerate video on video outputs that have an upper framerate
limit.

The argument selects the drop methods, and can be one of the following:

<no>

Disable any frame dropping. Not recommended, for testing only.

<vo>

Drop late frames on video output (default). This still decodes and
filters all frames, but doesn't render them on the VO. Drops are
indicated in the terminal status line as `Dropped:` field.

In audio sync. mode, this drops frames that are outdated at the time of
display. If the decoder is too slow, in theory all frames would have to
be dropped (because all frames are too late) - to avoid this, frame
dropping stops  if the effective framerate is below 10 FPS.

In display-sync. modes (see `--video-sync`), this affects only how
A/V drops or repeats frames. If this mode is disabled, A/V desync will
in theory not affect video scheduling anymore (much like the
`display-resample-desync` mode). However, even if disabled, frames
will still be skipped (i.e. dropped) according to the ratio between
video and display frequencies.

This is the recommended mode, and the default.

<decoder>

Old, decoder-based framedrop mode. (This is the same as `--framedrop=yes`
in mpv 0.5.x and before.) This tells the decoder to skip frames (unless
they are needed to decode future frames). May help with slow systems,
but can produce unwatchable choppy output, or even freeze the display
completely.

This uses a heuristic which may not make sense, and in  general cannot
achieve good results, because the decoder's frame dropping cannot be
controlled in a predictable manner. Not recommended.

Even if you want to use this, prefer `decoder+vo` for better results.

The `--vd-lavc-framedrop` option controls what frames to drop.

<decoder+vo>

Enable both modes. Not recommended. Better than just `decoder` mode.

Note

`--vo=vdpau` has its own code for the `vo` framedrop mode. Slight
differences to other VOs are possible.

`--video-latency-hacks=<yes|no>`

Enable some things which tend to reduce video latency by 1 or 2 frames
(default: no). Note that this option might be removed without notice once
the player's timing code does not inherently need to do these things
anymore. Using this option is known to break other options such as
interpolation, so it is not recommended to enable this.

This does:

- Use the demuxer reported FPS for frame dropping. This avoids the
player needing to decode 1 frame in advance, lowering total latency in
effect. This also means that if the demuxer reported FPS is wrong, or
the video filter chain changes FPS (e.g. deinterlacing), then it could
drop too many or not enough frames.

- Disable waiting for the first video frame. Normally the player waits for
the first video frame to be fully rendered before starting playback
properly. Some VOs will lazily initialize stuff when rendering the first
frame, so if this is not done, there is some likeliness that the VO has
to drop some frames if rendering the first frame takes longer than needed.

`--display-fps-override=<fps>`

Set the display FPS used with the `--video-sync=display-*` modes. By
default, a detected value is used. Keep in mind that setting an incorrect
value (even if slightly incorrect) can ruin video playback. On multi-monitor
systems, there is a chance that the detected value is from the wrong
monitor.

Set this option only if you have reason to believe the automatically
determined value is wrong.

`--hwdec=<api1,api2,...|no|auto|auto-copy>`

Specify the hardware video decoding API that should be used if possible.
Whether hardware decoding is actually done depends on the video codec. If
hardware decoding is not possible, mpv will fall back on software decoding.

Hardware decoding is not enabled by default, to keep the out-of-the-box
configuration as reliable as possible. However, when using modern hardware,
hardware video decoding should work correctly, offering reduced CPU usage,
and possibly lower power consumption. On older systems, it may be necessary
to use hardware decoding due to insufficient CPU resources; and even on
modern systems, sufficiently complex content (eg: 4K60 AV1) may require it.

This is a string list option. See [List Options](manual-options-track.md) for details.

Note

Use the `Ctrl+h` shortcut to toggle hardware decoding at runtime. It
toggles this option between `auto` and `no`.

If you decide you want to use hardware decoding by default, the general
recommendation is to try out decoding with the command line option, and
prove to yourself that it works as desired for the content you care
about. After that, you can add it to your config file.

When testing, you should start by using `hwdec=auto` as it will
limit itself to choosing from hwdecs that are actively supported by the
development team. If that doesn't result in working hardware decoding,
you can try `hwdec=auto-unsafe` to have it attempt to load every
possible hwdec, but if `auto` didn't work, you will probably need
to know exactly which hwdec matches your hardware and read up on that
entry below.

If `auto` produced the desired results, we recommend just
sticking with that and only setting a specific hwdec in your config
file if it is really necessary.

If you use the Ubuntu package, keep in mind that their
`/etc/mpv/mpv.conf` contains `hwdec=vaapi`, which is less than
ideal as it may not be the right choice for your system, and it may end
up using an inefficient wrapper library under the covers. We recommend
removing this line or deleting the file altogether.

Note

Even if enabled, hardware decoding is still only white-listed for some
codecs. See `--hwdec-codecs` to enable hardware decoding in more cases.

Which method to choose?

- If you only want to enable hardware decoding at runtime, don't set the
parameter, or put `hwdec=no` into your `mpv.conf` (relevant on
distros which force-enable it by default, such as on Ubuntu). Use the
`Ctrl+h` default binding to enable it at runtime.

- If you're not sure, but want hardware decoding always enabled by
default, put `hwdec=yes` into your `mpv.conf`, and acknowledge that
this may cause problems.

- If you want to test available hardware decoding methods, pass
`--hwdec=auto --hwdec-codecs=all` and look at the terminal output.

- If you're a developer, or want to perform elaborate tests, you may
need any of the other possible option values.

This option accepts a comma delimited list of `api` types, along with certain
special values:
| no: | always use software decoding (default) |
| --- | --- |
| auto: | enable any whitelisted hw decoder (see below) |
| auto-unsafe: | forcibly enable any hw decoder found (see below) |
| yes: | exactly the same as `auto` |
| auto-safe: | exactly the same as `auto` |

