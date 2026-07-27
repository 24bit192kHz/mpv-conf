## Video Sync

`--mc=<seconds/frame>`

Maximum A-V sync correction per frame (in seconds)

`--autosync=<factor>`

Gradually adjusts the A/V sync based on audio delay measurements.
Specifying `--autosync=0`, the default, will cause frame timing to be
based entirely on audio delay measurements. Specifying `--autosync=1`
will do the same, but will subtly change the A/V correction algorithm. An
uneven video framerate in a video which plays fine with `--audio=no` can
often be helped by setting this to an integer value greater than 1. The
higher the value, the closer the timing will be to `--audio=no`. Try
`--autosync=30` to smooth out problems with sound drivers which do not
implement a perfect audio delay measurement. With this value, if large A/V
sync offsets occur, they will only take about 1 or 2 seconds to settle
out. This delay in reaction time to sudden A/V offsets should be the only
side effect of turning this option on, for all sound drivers.

`--video-timing-offset=<seconds>`

Control how long before video display target time the frame should be
rendered (default: 0.050). If a video frame should be displayed at a
certain time, the VO will start rendering the frame earlier, and then will
perform a blocking wait until the display time, and only then "swap" the
frame to display. The rendering cannot start before the previous frame is
displayed, so this value is implicitly limited by the video framerate. With
normal video frame rates, the default value will ensure that rendering is
always immediately started after the previous frame was displayed. On the
other hand, setting a too high value can reduce responsiveness with low
FPS value.

This option is interesting for client API users using the render API
because you can stop it from limiting your FPS
(see `mpv_render_context_render()` documentation).

This applies only to audio timing modes (e.g. `--video-sync=audio`). In
other modes (`--video-sync=display-...`), video timing relies on vsync
blocking, and this option is not used.

`--video-sync=<audio|...>`

How the player synchronizes audio and video.

If you use this option, you usually want to set it to `display-resample`
to enable a timing mode that tries to not skip or repeat frames when for
example playing 24fps video on a 24Hz screen.

The modes starting with `display-` try to output video frames completely
synchronously to the display, using the detected display vertical refresh
rate as a hint how fast frames will be displayed on average. These modes
change video speed slightly to match the display. See `--video-sync-...`
options for fine tuning. The robustness of this mode is further reduced by
making a some idealized assumptions, which may not always apply in reality.
Behavior can depend on the VO and the system's video and audio drivers.
Media files must use constant framerate. Section-wise VFR might work as well
with some container formats (but not e.g. mkv).

Under some circumstances, the player automatically reverts to `audio` mode
for some time or permanently. This can happen on very low framerate video,
or if the framerate cannot be detected.

Also in display-sync modes it can happen that interruptions to video
playback (such as toggling fullscreen mode, or simply resizing the window)
will skip the video frames that should have been displayed, while `audio`
mode will display them after the renderer has resumed (typically resulting
in a short A/V desync and the video "catching up").

Before mpv 0.30.0, there was a fallback to `audio` mode on severe A/V
desync. This was changed for the sake of not sporadically stopping. Now,
`display-desync` does what it promises and may desync with audio by an
arbitrary amount, until it is manually fixed with a seek.

These modes also require a vsync blocked presentation mode. For OpenGL, this
translates to `--opengl-swapinterval=1`. For Vulkan, it translates to
`--vulkan-swap-mode=fifo` (or `fifo-relaxed`).

The modes with `desync` in their names do not attempt to keep audio/video
in sync. They will slowly (or quickly) desync, until e.g. the next seek
happens. These modes are meant for testing, not serious use.
| audio: | Time video frames to audio. This is the most robust
mode, because the player doesn't have to assume anything
about how the display behaves. The disadvantage is that
it can lead to occasional frame drops or repeats. If
audio is disabled, this uses the system clock. This is
the default mode. |
| --- | --- |
| display-resample: |
|  | Resample audio to match the video. This mode will also
try to adjust audio speed to compensate for other drift.
(This means it will play the audio at a different speed
every once in a while to reduce the A/V difference.) |
| display-resample-vdrop: |
|  | Resample audio to match the video. Drop video
frames to compensate for drift. |
| display-resample-desync: |
|  | Like the previous mode, but no A/V compensation. |
| display-tempo: | Same as `display-resample`, but apply audio speed
changes to audio filters instead of resampling to avoid
the change in pitch. Beware that some audio filters
don't do well with a speed close to 1. It is recommend
to use a conditional profile to automatically switch to
`display-resample` when speed gets too close to 1 for
your filter setup. Use (speed * video_speed_correction)
to get the actual playback speed in the condition.
See [Conditional auto profiles](manual-configuration-files-1.md) for details. |
| display-vdrop: | Drop or repeat video frames to compensate desyncing
video. (Although it should have the same effects as
`audio`, the implementation is very different.) |
| display-adrop: | Drop or repeat audio data to compensate desyncing
video. This mode will cause severe audio artifacts if
the real monitor refresh rate is too different from
the reported or forced rate. Since mpv 0.33.0, this
acts on entire audio frames, instead of single samples. |
| display-desync: | Sync video to display, and let audio play on its own. |
| desync: | Sync video according to system clock, and let audio play
on its own. |

`--video-sync-max-factor=<value>`

Maximum multiple for which to try to fit the video's FPS to the display's
FPS (default: 5).

For example, if this is set to 1, the video FPS is forced to an integer
multiple of the display FPS, as long as the speed change does not exceed
the value set by `--video-sync-max-video-change`.

See `--interpolation-threshold` for how this option affects
interpolation.

`--video-sync-max-video-change=<value>`

Maximum speed difference in percent that is applied to video with
`--video-sync=display-...` (default: 1). Display sync mode will be
disabled if the monitor and video refresh way do not match within the
given range. It tries multiples as well: playing 30 fps video on a 60 Hz
screen will duplicate every second frame. Playing 24 fps video on a 60 Hz
screen will play video in a 2-3-2-3-... pattern.

The default settings are not loose enough to speed up 23.976 fps video to
25 fps. We consider the pitch change too extreme to allow this behavior
by default. Set this option to a value of `5` to enable it.

Note that `--video-sync=display-tempo` avoids this pitch change.

Also note that in the `--video-sync=display-resample` or
`--video-sync=display-tempo` mode, audio speed will additionally be
changed by a small amount if necessary for A/V sync. See
`--video-sync-max-audio-change`.

`--video-sync-max-audio-change=<value>`

Maximum *additional* speed difference in percent that is applied to audio
with `--video-sync=display-...` (default: 0.125). Normally, the player
plays the audio at the speed of the video. But if the difference between
audio and video position is too high, e.g. due to drift or other timing
errors, it will attempt to speed up or slow down audio by this additional
factor. Too low values could lead to video frame dropping or repeating if
the A/V desync cannot be compensated, too high values could lead to chaotic
frame dropping due to the audio "overshooting" and skipping multiple video
frames before the sync logic can react.
