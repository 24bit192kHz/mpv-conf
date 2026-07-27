# Miscellaneous Ideas

Here are some random ideas for implementation in mpv. While there is no guarantee that any of these will actually get done, feel free to implement them yourself and submit a pull request.

You should probably coordinate with upstream first to avoid duplicate work and to get feedback.

- (rewrite the man page. But note: this is not something anybody cares about ATM.)
- Support for fetching pages on Windows (e.g. via code from FFmpeg's HTTP code).
- AppData for the binary (Windows).
- Feature-rich network streaming (live streams, Twitch, YouTube, etc.) can be done via Lua/JavaScript scripts and external programs (youtube-dl + mpv). This is already done and is working.
- PipeWire integration.
- Wayland output.
- Direct3D 11 output (is there interest? There's a partial implementation...)
- VapourSynth output (for headless transcoding).
- A video equalizer that works in an ICC-aware environment (currently, anything that changes the RGB conversion will break the 3DLUT).
- Reproducible build for releases (e.g. via a Docker container).
- Native VA-API encoding.
- Better audio support:
  - gapless
  - A-B repeat
  - bookmarks per file
- Better OS X integration.
- BBC soundbox integration.
- Spotify integration.
- MLT integration.
- A style guide for the mpv Lua scripts.
- A code of conduct for the mpv community.
