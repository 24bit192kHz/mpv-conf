# Option Replacement List

## Things Removed From mpv

| Old Option | Current Replacement |
|------------|-------------------|
| `--sub-fix-timing` | removed |
| `--ni` | removed |
| `--noni` | removed |
| `--noidle` | `--idle=no` (or `--idle=once`) |
| `--rawaudio` | `--demuxer=rawaudio --rawaudio-...` |
| `--rawvideo` | `--demuxer=rawvideo --rawvideo-...` |
| `--flip` | `--vf=flip` |
| `--pp` | removed (use `--vf=pp`) |
| `--pphelp` | removed |
| `--ssf` | removed |
| `--noaspect` | `--aspect=0` |
| `--nostop-xscreensaver` | `--stop-xscreensaver=no` |
| `--heartbeat-cmd` | removed |
| `--input-keylist` | `--input-keylist` (still works) |
| `--input-cmdlist` | `--input-cmdlist` (still works) |
| `--af-adv` | removed |
| `--afm` | removed |
| `--vfm` | removed |
| `--xineramascreen` | `--screen` (xinerama) |
| `--old-demos` | removed |
| `--dvb` | `--dvbin-...` |
| `--edl` | `--edl=` |
| `--alang` / `--slang` / `--vlang` | `--alang=` / `--slang=` / `--vid=` |
| `--mixer-channel` | removed |
| `--mixer` | removed |
| `--softvol-max` | `--volume-max` |
| `--panscan` | `--video-pan-x/y` + `--video-zoom` |
| `--spugauss` | removed |
| `--sub-bg-alpha` | removed |
| `--sub-bg-color` | `--sub-blur` can replace |
| `--sub-fuzziness` | removed |
| `--osdlevel` | removed |
| `--use-filename-title` | removed (now default) |
| `--term-osd` | removed |
| `--term-osd-esc` | removed |
| `--playing-msg` / `--playing-msg-start` | removed |
| `--identify` | removed (use `--vo=null --ao=null --untimed` or `TOOLS/mpv_identify.sh`) |
| `--report-level` | removed |
| `--msgcolor` | `--msg-color` |
| `--msglevel` | `--msg-level` |
| `--msgmodule` | removed |
| `--playlist-.*` | `--playlist-...` |
| `--tv-...` | removed (use V4L2 directly) |
| `--pvr-...` | removed |
| `--dvd-...` | removed (use libdvdread) |
| `--mc` | `--mc=0` still works |
| `--correct-pts` | removed (deprecated/always on) |
| `--index` | removed |
| `--forceidx` | removed |
| `--delay` / `--audio-delay` / `--audio-delay` | `--audio-delay` |
| `--audiofile` / `--audiofile-cache` | removed |
| `--raw-only` | removed |
| `--vt-init` | removed (VDPAU) |
| `--a52drc` | `--ad-lavc-ac3-drc=level` |
| `--dtshd` / `--dts-hd` | removed |
| `--vsync` / `--no-vsync` | removed (use `--video-sync`) |
| `--sync-to-audio` | removed (use `--video-sync`) |
| `--hq` / `--no-hq` / `--hq-low` | removed |
| `--auto-sync` | removed |
| `--softsleep` | removed |
| `--benchmark` | use `--untimed --no-audio --vo=null` or `--ao=null` |
| `--capture` | removed |
| `--forcedebug` | removed |
| `--edlout` | removed |
| `--shm` / `--hugepage` | removed |
| `--use-filename-title` | removed (now always on) |
| `--mkv-subtitle-preroll` | removed (now always on) |
| `--autosync` | removed |
| `--ad-spdif-dtshd` / `--dtshd` | removed |
| `--ad-lavc-ac3drc` | `--ad-lavc-ac3-drc=level` |
| `--ad-spdif-dtshd` | removed |
| `--stream-capture` / `--capture` | removed |
| `--stream-dump` | removed |
| `--chapter` | `--start=#` (with chapter percent) |
| `--ffactor` | removed |(removed)|
| `--overlay-add` | `--overlay` |
| `--overlay-remove` | `--overlay` |
| `--sub-bg-alpha` | removed |
| `--osd-level` | `--osd-level` |
| `--osd-scale` | `--osd-scale` |
| `--osd-fractions` | removed |
| `--osd-shadow` | removed |
| `--osd-shadow-offset` | removed |
| `--sub-align-x` | `--sub-align-x` |
| `--sub-align-y` | `--sub-align-y` |
| `--sub-justify` | removed |
| `--sub-margin-x` | removed |
| `--sub-margin-y` | removed |
| `--sub-scale` | `--sub-scale` |
| `--sub-scale-by-window` | removed |
| `--sub-scale-with-window` | `--sub-scale-by-window` |
| `--sub-unicode` | removed |
| `--sub-ass-margin` | removed |
| `--sub-ass-scale-with-window` | removed |
| `--ass-charset` | removed |
| `--ass-color` | removed |
| `--ass-top-margin` | removed |
| `--ass-bottom-margin` | removed |
| `--ass-force-style` | removed |
| `--ass-hinting` | removed |
| `--ass-line-spacing` | `--sub-ass-line-spacing` |
| `--ass-use-margins` | hidden (still works) |
| `--ass-style` | removed |
| `--embeddedfonts` | `--sub-ass-force-style=Fonts...` |
| `--sub-bg-alpha` | removed |
| `--sub-bg-color` | removed |
| `--sub-fg-color` | removed |
| `--sub-shadow-color` | removed |

## Options Still Working but Unsupported/Discouraged

| Old Option | Notes |
|------------|-------|
| `--mc=0` | Not a replacement, but ok |
| `--ad-lavc-ac3-drc=level` | Still works |
| `--dvd-angle` | Still works |
| `--bluray-angle` | Still works |
| `--chapter` | Still works somewhat |
| `--sub-bg-alpha` | Hidden |
