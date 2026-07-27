# LOW LATENCY PLAYBACK

mpv is optimized for normal video playback, meaning it actually tries to buffer
as much data as it seems to make sense. This will increase latency. Reducing
latency is possible only by specifically disabling features which increase
latency.

The builtin `low-latency` profile tries to apply some of the options which can
reduce latency. You can use  `--profile=low-latency` to apply all of them. You
can list the contents with `--show-profile=low-latency` (some of the options
are quite obscure, and may change every mpv release).

Be aware that some of the options can reduce playback quality.

Most latency is actually caused by inconvenient timing behavior. You can disable
this with `--untimed`, but it will likely break, unless the stream has no
audio, and the input feeds data to the player at a constant rate.

Another common problem is with MJPEG streams. These do not signal the correct
framerate. Using `--untimed` or `--correct-pts=no --container-fps-override=60`
might help.

For livestreams, data can build up due to pausing the stream, due to slightly
lower playback rate, or "buffering" pauses. If the demuxer cache is enabled,
these can be skipped manually. The experimental `drop-buffers` command can
be used to discard any buffered data, though it's very disruptive.

In some cases, manually tuning TCP buffer sizes and such can help to reduce
latency.

Additional options that can be tried:

- `--opengl-glfinish=yes`, can reduce buffering in the graphics driver

- `--opengl-swapinterval=0`, same

- `--vo=xv`, same

- without audio `--framedrop=no --speed=1.01` may help for live sources
(results can be mixed)
