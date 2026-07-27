Skip <sec> seconds after every frame.

Note

Without `--hr-seek`, skipping will snap to keyframes.

`--stop-playback-on-init-failure=<yes|no>`

Stop playback if either audio or video fails to initialize (default: no).
With `no`, playback will continue in video-only or audio-only mode if one
of them fails. This doesn't affect playback of audio-only or video-only
files.

`--play-direction=<forward|+|backward|->`

Control the playback direction (default: forward). Setting `backward`
will attempt to play the file in reverse direction, with decreasing
playback time. If this is set on playback starts, playback will start from
the end of the file. If this is changed at during playback, a hr-seek will
be issued to change the direction.

`+` and `-` are aliases for `forward` and `backward`.

The rest of this option description pertains to the `backward` mode.

Note

Backward playback is extremely fragile. It may not always work, is much
slower than forward playback, and breaks certain other features. How
well it works depends mainly on the file being played. Generally, it
will show good results (or results at all) only if the stars align.

mpv, as well as most media formats, were designed for forward playback
only. Backward playback is bolted on top of mpv, and tries to make a medium
effort to make backward playback work. Depending on your use-case, another
tool may work much better.

Backward playback is not exactly a 1st class feature. Implementation
tradeoffs were made, that are bad for backward playback, but in turn do not
cause disadvantages for normal playback. Various possible optimizations are
not implemented in order to keep the complexity down. Normally, a media
player is highly pipelined (future data is prepared in separate threads, so
it is available in realtime when the next stage needs it), but backward
playback will essentially stall the pipeline at various random points.

For example, for intra-only codecs are trivially backward playable, and
tools built around them may make efficient use of them (consider video
editors or camera viewers). mpv won't be efficient in this case, because it
uses its generic backward playback algorithm, that on top of it is not very
optimized.

If you just want to quickly go backward through the video and just show
"keyframes", just use forward playback, and hold down the left cursor key
(which on CLI with default config sends many small relative seek commands).

The implementation consists of mostly 3 parts:

- Backward demuxing. This relies on the demuxer cache, so the demuxer cache
should (or must, didn't test it) be enabled, and its size will affect
performance. If the cache is too small or too large, quadratic runtime
behavior may result.

- Backward decoding. The decoder library used (libavcodec) does not support
this. It is emulated by feeding bits of data in forward, putting the
result in a queue, returning the queue data to the VO in reverse, and
then starting over at an earlier position. This can require buffering an
extreme amount of decoded data, and also completely breaks pipelining.

- Backward output. This is relatively simple, because the decoder returns
the frames in the needed order. However, this may cause various problems
because filters see audio and video going backward.

Known problems:

- It's fragile. If anything doesn't work, random behavior may occur.
In simple cases, the player will just play nonsense and artifacts.
In other cases, it may get stuck or heat the CPU. (Exceeding memory usage
significantly beyond the user-set limits would be a bug, though.)

- Performance and resource usage isn't good. In part this is inherent to
backward playback of normal media formats, and in parts due to
implementation choices and tradeoffs.

- This is extremely reliant on good demuxer behavior. Although backward
demuxing requires no special demuxer support, it is required that the
demuxer performs seeks reliably, fulfills some specific requirements
about packet metadata, and has deterministic behavior.

- Starting playback exactly from the end may or may not work, depending on
seeking behavior and file duration detection.

- Some container formats, audio, and video codecs are not supported due to
their behavior. There is no list, and the player usually does not detect
them. Certain live streams (including TV captures) may exhibit problems
in particular, as well as some lossy audio codecs. h264 intra-refresh is
known not to work due to problems with libavcodec. WAV and some other raw
audio formats tend to have problems - there are hacks for dealing with
them, which may or may not work.

- Backward demuxing of subtitles is not supported. Subtitle display still
works for some external text subtitle formats. (These are fully read into
memory, and only backward display is needed.) Text subtitles that are
cached in the subtitle renderer also have a chance to be displayed
correctly.

- Some features dealing with playback of broken or hard to deal with files
will not work fully (such as timestamp correction).

- If demuxer low level seeks (i.e. seeking the actual demuxer instead of
just within the demuxer cache) are performed by backward playback, the
created seek ranges may not join, because not enough overlap is achieved.

- Trying to use this with hardware video decoding will probably exhaust all
your GPU memory and then crash a thing or two. Or it will fail because
`--hwdec-extra-frames` will certainly be set too low.

- Stream recording is broken. `--stream-record` may keep working if you
backward play within a cached region only.

- Relative seeks may behave weird. Small seeks backward (towards smaller
time, i.e. `seek -1`) may not really seek properly, and audio will
remain muted for a while. Using hr-seek is recommended, which should have
none of these problems.

- Some things are just weird. For example, while seek commands manipulate
playback time in the expected way (provided they work correctly), the
framestep commands are transposed. Backstepping will perform very
expensive work to step forward by 1 frame.

Tuning:

- Remove all `--vf`/`--af` filters you have set. Disable hardware
decoding. Disable functions like SPDIF passthrough.

- Increasing `--video-reversal-buffer` might help if reversal queue
overflow is reported, which may happen in high bitrate video, or video
with large GOP. Hardware decoding mostly ignores this, and you need to
increase `--hwdec-extra-frames` instead (until you get playback without
logged errors).

- The demuxer cache is essential for backward demuxing. Make sure to set
`--cache=yes`. The cache size might matter. If it's too small, a queue
overflow will be logged, and backward playback cannot continue, or it
performs too many low level seeks. If it's too large, implementation
tradeoffs may cause general performance issues. Use
`--demuxer-max-bytes` to potentially increase the amount of packets the
demuxer layer can queue for reverse demuxing (basically it's the
`--video-reversal-buffer` equivalent for the demuxer layer).

- Setting `--vd-queue-enable=yes` can help a lot to make playback smooth
(once it works).

- `--demuxer-backward-playback-step` also factors into how many seeks may
be performed, and whether backward demuxing could break due to queue
overflow. If it's set too high, the backstep operation needs to search
through more packets all the time, even if the cache is large enough.

- Setting `--demuxer-cache-wait` may be useful to cache the entire file
into the demuxer cache. Set `--demuxer-max-bytes` to a large size to
make sure it can read the entire cache; `--demuxer-max-back-bytes`
should also be set to a large size to prevent that tries to trim the
cache.

- If audio artifacts are audible, even though the AO does not underrun,
increasing `--audio-backward-overlap` might help in some cases.

`--video-reversal-buffer=<bytesize>`, `--audio-reversal-buffer=<bytesize>`

For backward decoding. Backward decoding decodes forward in steps, and then
reverses the decoder output. These options control the approximate maximum
amount of bytes that can be buffered. The main use of this is to avoid
unbounded resource usage; during normal backward playback, it's not supposed
to hit the limit, and if it does, it will drop frames and complain about it.

Use this option if you get reversal queue overflow errors during backward
playback. Increase the size until the warning disappears. Usually, the video
buffer will overflow first, especially if it's high resolution video.

This does not work correctly if video hardware decoding is used. The video
frame size will not include the referenced GPU and driver memory. Some
hardware decoders may also be limited by `--hwdec-extra-frames`.

How large the queue size needs to be depends entirely on the way the media
was encoded. Audio typically requires a very small buffer, while video can
require excessively large buffers.

(Technically, this allows the last frame to exceed the limit. Also, this
does not account for other buffered frames, such as inside the decoder or
the video output.)

This does not affect demuxer cache behavior at all.

See `--list-options` for defaults and value range. `<bytesize>` options
accept suffixes such as `KiB` and `MiB`.

