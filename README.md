# mpv config

Personal mpv configuration: HDR profiles, a complete Arabic subtitle system
(`ar_subs` downloader + `autosubsync` auto-timing), the uosc UI, shaders, and
CUDA-backed dynamic crop.

## ar_subs — Arabic subtitles, end to end

Auto-fetches an Arabic subtitle for whatever plays, then aligns it to the
video automatically. Three sources, tried in this order:

1. **Offline Subscene index** (optional) — a Docker API (`subtitle-api/`,
   not in this repo) serving a ~306k-subtitle FTS5 index of the Subscene
   Arabic dump. Zero quota, LAN-fast; checked first.
2. **SubSource.net** — preferred online source (`SUBSOURCE_API_KEY`).
   Per-season show resolution, episode-filtered pack ranking.
3. **SubDL** — last-resort fallback (`SUBDL_API_KEY`), with TMDB/TVDB
   metadata for title/season/episode detection.

Fetched subs are stored compressed at rest (`.ass.zst` / `.srt.zst`,
zstd-19 via in-process LuaJIT FFI — no subprocess) under one cache root
`~/.cache/ar_subs/`, decompressed into an LRU `hot/` dir on load in
sub-milliseconds. Episode matching, season-pack unpacking, and a per-season
search cache (SQLite + zstd) are shared by all three sources.

**Auto-sync** (`scripts/autosubsync/`): as soon as the Arabic track loads it
is aligned to the video — embedded text subtitle first (extracted in one
windowed ffmpeg pass, dialogue-only filtered, sub-to-sub ffsubsync), bounded
audio VAD otherwise (capped window, serialized-speech cache). Computed
offset+scale is cached per episode (replays apply it in ~20 ms), next
episodes' refs are prefetched in the background, and implausible alignments
(cues past end-of-media — wrong release) are rejected instead of loaded.

Keybindings: `n` re-sync, `Ctrl+N` sync menu, `F12` clear episode cache,
`Ctrl+Shift+V` next candidate subtitle.

## Install

### Linux / macOS

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1 | iex
```

Installs to `~/.config/mpv` (Linux/macOS) or `%APPDATA%\mpv` (Windows). The installer
backs up any existing mpv config folder before replacing it.

## API keys

Keys are **intentionally not committed**. Copy `.env.example` to `.env` and fill it:

| Variable | Service |
|---|---|
| `SUBSOURCE_API_KEY` | SubSource — preferred subtitle source |
| `SUBDL_API_KEY` | SubDL — subtitle fallback |
| `TMDB_API_KEY` | TMDB — movie/series metadata |
| `TVDB_API_KEY` | TVDB — optional, for anime episodes |

`script-opts/ar_subs.conf` is also supported for mpv-style overrides
(see `ar_subs.conf.example` for every option, including the offline
index URL and the sync-engine tuning).

## Dynamic crop

Dynamic crop uses the native C++ sidecar in `cuda-crop-cpp/` (ffprobe + ffmpeg
`cropdetect` — no Python). The installer tries to build it automatically; if it
can't, build manually. Requires CMake, a C++17 compiler, `nlohmann_json`, and
ffprobe/ffmpeg at runtime.

Linux / macOS:

```sh
cd ~/.config/mpv/cuda-crop-cpp          # deps e.g.: apt install nlohmann-json3-dev
cmake -B build && cmake --build build
```

Windows (CMake + Visual Studio; `nlohmann_json` via vcpkg):

```powershell
cd "$env:APPDATA\mpv\cuda-crop-cpp"
cmake -B build
cmake --build build --config Release
```
