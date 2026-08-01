# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

The maintainer's **live mpv config**: the working tree IS `~/.config/mpv`, read by mpv on every launch. Edits take effect immediately — there is no build/install step for the config itself. Public repo (`24bit192kHz/mpv-conf`); the install one-liners in README fetch `master`, so feature work happens on branches and is fast-forward merged to master when done.

## Commands

```sh
# Test config changes headlessly (no screen hijack) — full script stack runs:
mpv --vo=null --ao=null --fs=no <file>
# Add --script-opts=anime_detect-debug=yes for TMDB probe tracing

# ar_subs test suite (zero-dep runner, stubbed mp API):
lua script-modules/ar_subs/test/run.lua        # all specs
lua script-modules/ar_subs/test/spec/test_match.lua   # single spec

# cuda-crop-cpp (dynamic-crop sidecar binary, expected at cuda-crop-cpp/build/cuda-crop-cpp):
cd cuda-crop-cpp && cmake -B build && cmake --build build   # needs nlohmann_json

# Factory reset of all script state:
rm -rf ~/.cache/mpv        # ar_subs/ autosubsync/ memo/ + mpv's own shader cache
```

`graphify-out/` contains a knowledge graph of this repo — run `graphify query "<question>"` before large-scale code exploration.

## Architecture

Playback-load pipeline (all scripts fire off `file-loaded`):

1. **anime_detect.lua** — TMDB `/search/multi` probe (genre 16 + `original_language=ja` **or** a Japanese audio track in `track-list`). Sets `user-data/anime_detect/is_anime`, which the `[Anime]` conditional profile in `profiles.conf` watches. Reads its TMDB key from `script-opts/anime_detect.conf` → env → `~~/.env` dotenv (parsed itself — mpv does not export `.env`).
2. **ar_subs** (`scripts/ar_subs.lua` + `script-modules/ar_subs/`) — Arabic subtitle fetch waterfall: offline Subscene index (`subtitle_api_url`) → SubSource → SubDL (dual-key quota failover). Stores `.ass.zst`/`.srt.zst` at rest in `~/.cache/mpv/ar_subs/subtitles/` (SQLite + zstd via `store.lua`); `util/zstd.lua` provides FFI compress/decompress and the hot-dir pattern. Skips fetching when an Arabic track already exists.
3. **autosubsync** (`scripts/autosubsync/`) — aligns the loaded Arabic sub via ffsubsync (embedded text-sub ref first, audio VAD fallback). Refs extracted once per video into `~/.cache/mpv/autosubsync/refs/<hash>/` (**zstd at rest**; readers resolve logical names via `plain_ref()` into `refs/hot/`), per-episode transform cache in `transforms/`, next-episode prefetch in background.
4. **Shaders** — always-on trio in `mpv.conf` (`KrigBilateral:SSimSuperRes:SSimDownscaler`; SSimDownscaler is `//!WHEN`-gated, free unless source > display). `[Anime]` profile REPLACES the list with Anime4K v4.x Mode A + KrigBilateral, height-gated `<1600` and HDR-excluded. `ALT+1..7` swap chains manually.
5. **dynamic-crop** (`scripts/dynamic-crop.lua`) — CUDA sidecar backend; on 2 consecutive scan failures it `dofile`s `script-modules/dynamic-crop-legacy.lua` (cropdetect-based) in the same script context.
6. **uosc** (vendored, `scripts/uosc/`) — the UI; `osc=no` in mpv.conf is load-bearing. SmartSkip (`scripts/SmartSkip.lua`) auto-skips OP/ED/Preview chapters; memo = recent-files menu (`h`); sponsorblock = YouTube only.

## Repo-specific gotchas

- **Conditional profiles must declare `profile-restore=copy-equal`** or their options leak across files (session-order dependent). In `mpv.conf`, everything after a `[profile]` header belongs to that profile — global options live **above** the header blocks at the end of the file.
- **`msg-level` is a list option: one line only.** Repeated `msg-level=` lines clobber each other (last wins).
- **`mp.options` identifier sharing**: a script loaded via `dofile` (the crop legacy fallback) inherits the parent's script name, so `read_options` without an explicit identifier reads the parent's `script-opts` prefix. The legacy backend uses `dynamic_crop_legacy-*` for this reason.
- **Key precedence in ar_subs**: non-empty conf value > env var > `~~/.env` dotenv (`script-modules/ar_subs/config.lua`). `.env` is the canonical secret store; confs carrying keys (`ar_subs.conf`, `anime_detect.conf`) are gitignored — never write key values into tracked files, and never log them (`anime_detect` masks `api_key=` in debug output).
- **Lua pattern limits**: no `{n,m}` quantifiers, no `|` alternation. `normalize()` in anime_detect uses `%d%d%d%d?p` and per-token gsub loops with `%f[]` frontiers for that reason.
- **zstd convention**: compress at rest (`.zst`), never store raw long-term; resolve-on-read through a hot dir. `script-modules/ar_subs/util/zstd.lua` is shared — autosubsync requires it via a `package.path` bootstrap (mpv only auto-adds `script-modules` for `require`, which is how `require "ar_subs.util.zstd"` resolves).
- **Autosubsync cache integrity**: transform-cache entries are tied to the retimed file path (`retimed` field) — if the ar_subs store is wiped, the entry self-invalidates. Keep both caches under `~/.cache/mpv/` so a single wipe stays consistent.

## Conventions

- Commits: lowercase conventional (`feat:`, `fix:`, `chore:`, scoped like `fix(autosubsync):`), prose body explaining WHY.
- Script state goes under `~/.cache/mpv/<script>/` with per-script subdirs; config-level options in `script-opts/`, with a committed `.example` for any new conf.
- Vendored scripts (uosc, thumbfast, memo, SmartSkip) stay close to upstream; custom logic lives in ar_subs/autosubsync/anime_detect.
