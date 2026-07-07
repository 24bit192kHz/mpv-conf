# cuda-crop-cpp

Native dynamic crop sidecar for mpv.

It keeps the `cuda-crop-py` command contract:

- `analyze SOURCE --start ...`
- `daemon --socket-path ...`
- `controller --mpv-socket ...`

The analyzer uses ffprobe plus ffmpeg `cropdetect` directly. No Python process is used by mpv.
