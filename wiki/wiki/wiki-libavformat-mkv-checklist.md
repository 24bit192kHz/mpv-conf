# libavformat mkv checklist

Before describing a problem about any mkv file, please:

1. Try it with `ffplay` too.
2. Make sure your ffmpeg is not ancient.

To report a problem:

1. Provide a sample (or a cut of it).
2. Use `ffprobe` on the file and provide its output.

Please check if the file has any errors when you mux/demux or seek. It could be a problem with ffmpeg in general. If `ffplay` has the same problem, then it's likely a ffmpeg problem and should be reported there.

If `ffplay` works fine but mpv does not, then you can open an issue on the mpv tracker.

Please also try to provide a small sample for easier testing.
