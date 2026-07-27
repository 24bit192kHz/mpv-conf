# Display Synchronization

`--video-sync=display` (enabled by default in mpv since v0.14.0) will match video display to the display refresh rate, even if the video fps does not match the display refresh rate. It essentially does framerate conversion by repeating or dropping frames according to the ratio between video fps and display fps.

While `--display-fps-override` allows forcing a specific display FPS, mpv will normally auto-detect it via the windowing system.

## How It Works

The concept avoids the use of vsync as a timing source because that's not how the modern display stack works. Instead, mpv uses the presentation time feedback from the graphics driver (or audio as a proxy) to determine the display's approximate vsync phase and period. Based on this feedback, it can carefully time video presentation to prevent or minimize tearing, stuttering, or other visual artifacts.

## Wait... I'm getting frame drops

Frame drops while display sync is active are expected. While "normal" vsync timing reduces the number of dropped frames, display sync will intentionally cause them if the video fps ratio mismatches the display's refresh rate. Due to the way display sync works, it also might become unstable or inaccurate if playback is not real-time.

Stuttering with display sync can also be caused by unusual display refresh rates (like 59.97 Hz or 120 Hz on some mobile displays), or if the audio device has issues maintaining a stable clock. If you are experiencing problems, put `--video-sync=display-resample` in your config. This causes the audio to be resampled to match the video rate, which also has the side effect of making the audio work as a quasi-vsync source.

If you want to avoid frame drops (like in the classic VSync setup) you can disable display-sync with `--video-sync=audio`.

See `--video-sync` in the manual for additional details.
