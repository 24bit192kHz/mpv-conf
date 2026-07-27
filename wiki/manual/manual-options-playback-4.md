`--video-backward-overlap=<auto|number>`, `--audio-backward-overlap=<auto|number>`

Number of overlapping keyframe ranges to use for backward decoding (default:
auto) ("keyframe" to be understood as in the mpv/ffmpeg specific meaning).
Backward decoding works by forward decoding in small steps. Some codecs
cannot restart decoding from any packet (even if it's marked as seek point),
which becomes noticeable with backward decoding (in theory this is a problem
with seeking too, but `--hr-seek-demuxer-offset` can fix it for seeking).
In particular, MDCT based audio codecs are affected.

The solution is to feed a previous packet to the decoder each time, and then
discard the output. This option controls how many packets to feed. The
`auto` choice is currently hardcoded to 0 for video, and uses 1 for lossy
audio, 0 for lossless audio. For some specific lossy audio codecs, this is
set to 2.

`--video-backward-overlap` can potentially handle intra-refresh video,
depending on the exact conditions. You may have to use the
`--vd-lavc-show-all` option as well.

`--video-backward-batch=<number>`, `--audio-backward-batch=<number>`

Number of keyframe ranges to decode at once when backward decoding (default:
1 for video, 10 for audio). Another pointless tuning parameter nobody should
use. This should affect performance only. In theory, setting a number higher
than 1 for audio will reduce overhead due to less frequent backstep
operations and less redundant decoding work due to fewer decoded overlap
frames (see `--audio-backward-overlap`). On the other hand, it requires
a larger reversal buffer, and could make playback less smooth due to
breaking pipelining (e.g. by decoding a lot, and then doing nothing for a
while).

It probably never makes sense to set `--video-backward-batch`. But in
theory, it could help with intra-only video codecs by reducing backstep
operations.

`--demuxer-backward-playback-step=<seconds>`

Number of seconds the demuxer should seek back to get new packets during
backward playback (default: 60). This is useful for tuning backward
playback, see `--play-direction` for details.

Setting this to a very low value or 0 may make the player think seeking is
broken, or may make it perform multiple seeks.

Setting this to a high value may lead to quadratic runtime behavior.
