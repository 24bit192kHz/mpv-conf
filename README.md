# mpv config

Personal mpv configuration: HDR profiles, an Arabic auto-subtitle downloader (`subdl_ar`),
the uosc UI, shaders, and CUDA-backed dynamic crop.

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
| `SUBDL_API_KEY` | SubDL — required for subtitles |
| `TMDB_API_KEY` | TMDB — movie/series metadata |
| `TVDB_API_KEY` | TVDB — optional, for anime episodes |

`script-opts/subdl_ar.conf` is also supported for mpv-style overrides.

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
