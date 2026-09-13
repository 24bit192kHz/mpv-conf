# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. Cursor / Codex: `AGENTS.md`. Gemini CLI: `GEMINI.md`. Those files stay thin pointers; this file is canonical.

## What this repo is

The maintainer's **live mpv config**: the working tree IS `~/.config/mpv`, read by mpv on every launch. Edits take effect immediately — there is no build/install step for the config itself. Public repo (`24bit192kHz/mpv-conf`); the install one-liners in README fetch `master`, so feature work happens on branches and is fast-forward merged to master when done.

## Commands

```sh
# Test config changes headlessly (no screen hijack) — full script stack runs.
# keep-open=always in mpv.conf, and uosc forces keep-open=yes at runtime, so
# --keep-open=no alone still sits at EOF: --script-opts=uosc-autoload=no lets
# it exit. Add --untimed to decode without realtime wait.
mpv --vo=null --ao=null --fs=no --keep-open=no --script-opts=uosc-autoload=no --untimed <file>
# Add --script-opts=anime_detect-debug=yes for TMDB probe tracing

# ar_subs test suite (zero-dep runner, stubbed mp API):
lua script-modules/ar_subs/test/run.lua        # all specs (380+)
lua script-modules/ar_subs/test/spec/test_match.lua   # single spec

# Argos timing-ref vs ffsubsync (testing2):
python script-modules/autosubsync/timing_ref.py selftest
python script-modules/autosubsync/timing_ref.py compare --video FILE --ar-sub FILE

# Parse-check custom Lua the way mpv does (LuaJIT, not system luac 5.4):

# Parse-check custom Lua the way mpv does (LuaJIT, not system luac 5.4):
luajit -e "assert(loadfile('scripts/ar_subs.lua'))"

# cuda-crop-cpp (dynamic-crop sidecar binary, expected at cuda-crop-cpp/build/cuda-crop-cpp):
cd cuda-crop-cpp && cmake -B build && cmake --build build   # needs nlohmann_json

# Factory reset of all script state:
rm -rf ~/.cache/mpv        # ar_subs/ autosubsync/ memo/ + mpv's own shader cache
```

`graphify-out/` contains a knowledge graph of this repo — run `graphify query "<question>"` before large-scale code exploration. After code/doc edits: `graphify update .`

## Architecture

Playback-load pipeline (scripts fire off `file-loaded`):

1. **anime_detect.lua** — TMDB `/search/multi` probe (genre 16 + `original_language=ja` **or** a Japanese audio track in `track-list`). Sets `user-data/anime_detect/is_anime`, which `[Anime]` in `profiles.conf` watches. Session cache is applied **before** clearing the flag (avoids Anime4K flash). Async callbacks carry a generation token so a late TMDB result cannot write onto the next file. Keys: conf → env → `~~/.env` (mpv does not export `.env`). Debug logs mask `api_key=`.
2. **ar_subs** (`scripts/ar_subs.lua` + `script-modules/ar_subs/`) — Arabic subtitle fetch waterfall: offline Subscene index (`subtitle_api_url`) → SubSource → SubDL (dual-key quota failover). Stores `.ass.zst`/`.srt.zst` at rest in `~/.cache/mpv/ar_subs/subtitles/` (SQLite + zstd via `store.lua`); `util/zstd.lua` hot-dir names include a **parent-dir hash** so two shows' `Arabic.ass.zst` never collide. Skips fetch only when an **Arabic** sibling/track already exists (an English `video.srt` must not block). Downloads capture the path at start; `sub-add` is dropped if the file changed. Placeholder SubDL/api stubs are deleted, not cached. Zip-slip: `unzip -Z1` failure **refuses** the archive (fail closed).
3. **autosubsync** (`scripts/autosubsync/`) — aligns the loaded Arabic sub. Default path is ffsubsync (embedded text-sub ref first, audio VAD fallback). On `testing2`, `timing_ref_mode=compare` also runs `script-modules/autosubsync/timing_ref.py`: default embedded sub → Argos EN→AR (timestamps kept) → DTW-match onto the best-score downloaded sub; no text sub → sherpa-onnx VAD+ASR. Compare writes `*_retimed_argos.*` vs `*_retimed_ffsubsync.*` plus JSON. Refs: `~/.cache/mpv/autosubsync/refs/<hash>/`. Transform JSON is per-video **and** keyed to `src`. `synced_paths` / auto-timer cleared on `end-file`.
4. **Shaders / color** — `vo=gpu-next` (required for `target-colorspace-hint` / Hyprland HDR). Always-on SDR chain in `mpv.conf` (`KrigBilateral:SSimSuperRes:SSimDownscaler`). `[hdr-passthrough]` (pq/hlg) empties shaders and sets PQ hint. `[sdr-native]` is **transfer-gated** (not pq/hlg) so Rec.2020 SDR matches and Rec.709-primaries HDR does not. `[Anime]` REPLACES the chain with Anime4K v4.x Mode A + KrigBilateral, height-gated `<1600` and HDR-excluded. `ALT+1..7` swap chains; `blend-subtitles=no` keeps subs on the window layer so dynamic-crop leaves them fixed (gpu-next seek-subs effect unverified on current mpv; screenshots force `no` per-shot).
5. **dynamic-crop** (`scripts/dynamic-crop.lua`) — CUDA sidecar; pin `mpv_socket=/tmp/mpvsocket` in `script-opts/dynamic_crop.conf` so hyprshaderd keeps that path. Two scan failures `dofile` `script-modules/dynamic-crop-legacy.lua` and switch `hwdec` to `nvdec-copy` for cropdetect. **Next `file-loaded` retries CUDA** and restores nvdec. Sidecar EOF callback must use a forward-declared `playback_ended`. Startup pause has a 2s watchdog.
6. **uosc** (vendored, `scripts/uosc/`) — the UI; `osc=no` in mpv.conf is load-bearing. SmartSkip (`scripts/SmartSkip.lua`) auto-skips OP/ED/Preview with **no** countdown/OSD. memo = recent-files (`h`); sponsorblock = YouTube only. `keylayout.lua` remaps Arabic letters; extra modifiers (`ctrl+shift` / `ctrl+alt`) are **only on `v`** so `Ctrl+Shift+V` works without stealing every ctrl+shift+letter.

## Repo-specific gotchas

- **Conditional profiles must declare `profile-restore=copy-equal`** or their options leak across files (session-order dependent). In `mpv.conf`, everything after a `[profile]` header belongs to that profile — global options live **above** the header blocks at the end of the file.
- **`msg-level` is a list option: one line only.** Repeated `msg-level=` lines clobber each other (last wins).
- **`mp.options` identifier sharing**: a script loaded via `dofile` (the crop legacy fallback) inherits the parent's script name, so `read_options` without an explicit identifier reads the parent's `script-opts` prefix. The legacy backend uses `dynamic_crop_legacy-*` for this reason.
- **Key precedence in ar_subs**: non-empty conf value > env var > `~~/.env` dotenv (`script-modules/ar_subs/config.lua`). `.env` is the canonical secret store; confs carrying keys (`ar_subs.conf`, `anime_detect.conf`) are gitignored — never write key values into tracked files, and never log them (`anime_detect` masks `api_key=` on success **and** curl-fail).
- **Lua pattern limits**: no `{n,m}` quantifiers, no `|` alternation. `normalize()` in anime_detect uses `%d%d%d%d?p` and per-token gsub loops with `%f[]` frontiers for that reason.
- **zstd convention**: compress at rest (`.zst`), never store raw long-term; resolve-on-read through a hot dir. Hot names are `hash(parent-dir)_basename`. `script-modules/ar_subs/util/zstd.lua` is shared — autosubsync requires it via a `package.path` bootstrap (mpv only auto-adds `script-modules` for `require`).
- **Autosubsync cache integrity**: transform entries store `retimed` **and** `src`. Wipe `~/.cache/mpv/` to invalidate both ar_subs and transforms together.
- **Parse Lua with LuaJIT**, not `luac` 5.4 (`for` loop assigns look like const errors under 5.4).
- **In-flight HTTP**: `ar_subs` tracks every async handle (search + download); `end-file` aborts the set, not only the last search.

## Conventions

- Commits: lowercase conventional (`feat:`, `fix:`, `chore:`, scoped like `fix(autosubsync):`), prose body explaining WHY.
- Script state goes under `~/.cache/mpv/<script>/` with per-script subdirs; config-level options in `script-opts/`, with a committed `.example` for any new conf.
- Vendored scripts (uosc, thumbfast, memo, SmartSkip) stay close to upstream; custom logic lives in ar_subs/autosubsync/anime_detect.
