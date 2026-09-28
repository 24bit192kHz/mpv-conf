# mpv-conf

My mpv config. It fetches and auto-syncs Arabic subtitles, detects anime and
switches to Anime4K, passes HDR straight through to the display, and zooms
letterboxed shots to fill the screen with a CUDA crop detector. The UI is uosc.

Built for Linux + NVIDIA + Wayland (Hyprland). Most of it works elsewhere; the
Linux-specific parts sit in auto-profiles in `profiles.conf`.

## Install

Linux / macOS:

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1 | iex
```

Installs to `~/.config/mpv` (or `%APPDATA%\mpv`). An existing config is backed
up first. A reinstall keeps your `.env` and `script-opts/`.

### Requirements

| Needed for | Tools |
|---|---|
| Everything | a recent mpv with `gpu-next` (tested on 0.41), ffmpeg/ffprobe, curl |
| Arabic subtitles | unzip (7z for `.7z` packs), sqlite3 + zstd for the cache |
| Auto-sync | [ffsubsync](https://github.com/smacke/ffsubsync); optional [alass](https://github.com/kaegi/alass) |
| Auto-sync compare mode (optional) | Python 3, [Argos Translate](https://github.com/argosopentech/argos-translate), [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) |
| Anime chapters | [guessit](https://github.com/guessit-io/guessit) (`uv tool install guessit`) |
| Dynamic crop | NVIDIA GPU, CMake, a C++17 compiler, [nlohmann/json](https://github.com/nlohmann/json) |
| Clipboard screenshots | `wl-copy` (Wayland) or `xclip` (X11) |
| Media keys (Linux, optional) | [mpv-mpris](https://github.com/hoyon/mpv-mpris) (`pacman -S mpv-mpris`) |

The installer tries to build the crop sidecar. To build it yourself:

```sh
cd ~/.config/mpv/cuda-crop-cpp && cmake -B build && cmake --build build
```

### API keys

No keys are committed. Copy `.env.example` to `.env` and fill it in:

| Variable | Used for |
|---|---|
| `SUBSOURCE_API_KEY` | SubSource, the main subtitle source |
| `SUBDL_API_KEY` | SubDL, the fallback source |
| `TMDB_API_KEY` | Title, season and episode metadata; anime detection |
| `TVDB_API_KEY` | Optional, better anime episode numbering |

Values in `script-opts/ar_subs.conf` or `anime_detect.conf` override `.env`.
Both files are gitignored; keep the keys in `.env`.

## What it does

**Arabic subtitles** (`scripts/ar_subs.lua`, `script-modules/ar_subs/`).
When a file loads without an Arabic track, it searches an optional offline
Subscene index, then SubSource, then SubDL. It understands season packs,
absolute vs. per-season anime numbering and split-cour seasons. Subtitles are
stored zstd-compressed under `~/.cache/mpv/ar_subs/`. Files with Arabic audio
are skipped.

**Auto-sync** (`scripts/autosubsync/`). The loaded Arabic subtitle is aligned
with ffsubsync against the file's own text subtitle if it has one, otherwise
against the audio. The result is cached per episode, and the next episode's
reference is prepared in the background.

**Anime** (`scripts/anime_detect.lua`). A TMDB lookup (animation genre plus
Japanese language or audio), or an `/Anime/` folder in the path, turns on the
`[Anime]` profile, which swaps the SDR shader chain for Anime4K. Folder
verdicts are remembered so the next episode starts with the right shaders.
SmartSkip skips openings, endings and previews; autochapters adds OP/ED
chapters from AniSkip when a file has none.

**Picture.** `vo=gpu-next`. SDR gets KrigBilateral + SSimSuperRes +
SSimDownscaler; HDR (PQ/HLG) is passed through to the display untouched.
`Ctrl+h` switches between passthrough and mpv's own tone mapping.

**Dynamic crop** (`scripts/dynamic-crop.lua`, `cuda-crop-cpp/`). A sidecar
scans ahead of playback on the GPU and zooms letterboxed shots to fill the
screen, down to 1-2 second inserts. If CUDA fails twice it falls back to
mpv's own cropdetect for that file.

**Smaller things.** Arabic keyboard layout support for shortcuts (`keylayout`),
subtitle cycling limited to Arabic/English/the original language
(`sub-lang-filter`), seeking in MKVs without cues (`no-index-seek`), SDR
screenshots of HDR video, clipboard screenshots, recent files, and hold Space
for 2x speed.

## Keys

| Key | Action |
|---|---|
| `Ctrl+Shift+V` / `Ctrl+V` / `Alt+V` / `Ctrl+Alt+V` | Next Arabic subtitle / deep search / manual search / picker |
| `n` / `Ctrl+N` / `F12` | Re-sync subtitle / sync menu / clear this episode's sync cache |
| `j` / `J` | Cycle allowed subtitles |
| `Alt+1`..`Alt+7` / `Alt+0` | Anime4K modes / clear shaders |
| `Ctrl+h` | HDR passthrough ⇄ tone mapping |
| `C` | Dynamic crop mode |
| `h` | Recent files |
| `c` / `Alt+s` / `Alt+w` | Copy screenshot (with subs / video / window) |
| `s` | Copy an SDR screenshot (tone-mapped if the video is HDR) |
| Space (hold) | 2x speed while held |
| Right-click or `U` | Menu |

All bindings are in `input.conf`.

## State

Everything the scripts generate lives under `~/.cache/mpv/`. Deleting it
resets them; watching something rebuilds it. The exceptions are
`scripts/autochapters/*.json` (anime database, downloaded on first run),
`chapters/` (SmartSkip) and `scripts/sponsorblock_shared/sponsorblock.txt`.

## Credits

Much of this config is other people's work. Thank you to:

| Component | Author | Source | License | Changes here |
|---|---|---|---|---|
| uosc (UI, incl. its fonts) | tomasklaen | [tomasklaen/uosc](https://github.com/tomasklaen/uosc) | LGPL-2.1 | config only |
| thumbfast | po5 | [po5/thumbfast](https://github.com/po5/thumbfast) | MPL-2.0 | |
| memo | po5 | [po5/memo](https://github.com/po5/memo) | GPL-3.0 | |
| evafast | po5 | [po5/evafast](https://github.com/po5/evafast) | none stated | |
| sponsorblock | po5 | [po5/mpv_sponsorblock](https://github.com/po5/mpv_sponsorblock) | GPL-3.0 | |
| autochapters | po5 | [po5/mpv-auto-chapters](https://github.com/po5/mpv-auto-chapters) | GPL-3.0 | keeps embedded chapters instead of replacing them |
| SmartSkip | Eisa01 | [Eisa01/mpv-scripts](https://github.com/Eisa01/mpv-scripts) | BSD-2-Clause | |
| autosubsync | joaquintorres | [joaquintorres/autosubsync-mpv](https://github.com/joaquintorres/autosubsync-mpv) | MIT | heavily extended: auto-run, reference extraction, caching, Argos compare |
| dynamic-crop (legacy fallback) | Ashyni | [Ashyni/mpv-scripts](https://github.com/Ashyni/mpv-scripts) | MIT | used as the fallback for the CUDA sidecar |
| input-event | natural-harmonia-gropius | [input-event](https://github.com/natural-harmonia-gropius/input-event) | MIT | |
| clipshot | ObserverOfTime | [ObserverOfTime/mpv-scripts](https://github.com/ObserverOfTime/mpv-scripts) | 0BSD | |
| cycle-through-existing | Vinícius B. Matos | [viniciusbm/mpv-cycle-through-existing](https://github.com/viniciusbm/mpv-cycle-through-existing) | Apache-2.0 | |
| auto-save-state | AN3223 | [AN3223/dotfiles](https://github.com/AN3223/dotfiles) | MIT | |
| autodeint | mpv developers | [mpv TOOLS/lua](https://github.com/mpv-player/mpv/tree/master/TOOLS/lua) | mpv's license | |
| Anime4K shaders | bloc97 | [bloc97/Anime4K](https://github.com/bloc97/Anime4K) | MIT (AutoDownscalePre: Unlicense) | |
| KrigBilateral, SSimSuperRes | Shiandow | [igv's gists](https://gist.github.com/igv) | LGPL-3.0 | |
| SSimDownscaler | igv | [igv's gists](https://gist.github.com/igv) | LGPL-3.0 | |
| JetBrains Mono | JetBrains | [JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono) | OFL-1.1 | |
| Clear Sans | Intel | [intel/clear-sans](https://github.com/intel/clear-sans) | Apache-2.0 | |
| Calibri | Microsoft | | proprietary | |

`space-hold-speed` is my own, but inspired by evafast.

Data and services: [TMDB](https://www.themoviedb.org/) (this product uses
the TMDB API but is not endorsed or certified by TMDB), [TheTVDB](https://thetvdb.com/),
[SubSource](https://subsource.net/), [SubDL](https://subdl.com/),
[AniSkip](https://aniskip.com/),
[anime-offline-database](https://github.com/manami-project/anime-offline-database)
by manami-project, and [SponsorBlock](https://sponsor.ajay.app/) by Ajay Ramachandran.
Built on [mpv](https://mpv.io/), [FFmpeg](https://ffmpeg.org/),
[libplacebo](https://code.videolan.org/videolan/libplacebo) and
[ffsubsync](https://github.com/smacke/ffsubsync).

The full upstream license texts are in [`licenses/`](licenses/). Each
third-party file keeps its original license.
