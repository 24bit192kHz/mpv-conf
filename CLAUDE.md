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
lua script-modules/ar_subs/test/run.lua        # all specs (449)
lua script-modules/ar_subs/test/spec/test_match.lua   # single spec

# sub-lang-filter regression test (standalone; its header's usage path is stale):
lua script-modules/sub_lang_filter/test/test_sub_lang_filter.lua

# Argos timing-ref vs ffsubsync ("testing2" is the feature label, not a branch):
python script-modules/autosubsync/timing_ref.py selftest
python script-modules/autosubsync/timing_ref.py compare --video FILE --ar-sub FILE

# Parse-check custom Lua the way mpv does (LuaJIT, not system luac 5.4):
luajit -e "assert(loadfile('scripts/ar_subs.lua'))"

# cuda-crop-cpp (dynamic-crop sidecar binary, expected at cuda-crop-cpp/build/cuda-crop-cpp):
cd cuda-crop-cpp && cmake -B build && cmake --build build   # needs nlohmann_json

# Factory reset of all script state:
rm -rf ~/.cache/mpv        # ar_subs/ autosubsync/ anime_detect/ memo/ no-index-seek/ + shader cache
```

**Rendering/visual checks without touching the user's screen** (subtitle placement, crop, shaders): a private Xvfb display renders gpu-next on the NVIDIA GPU, and `screenshot-to-file <png> window` returns exactly what the monitor would show (main monitor is 3440x1440). Traps, each one hit in practice:
- `env -u WAYLAND_DISPLAY DISPLAY=:99 ... --gpu-context=x11vk` — with `WAYLAND_DISPLAY` set, `[linux-wayland-vulkan]` opens a real window on Hyprland.
- `[linux-pipewire]` re-applies `ao=pipewire` over `--ao=null`: point `XDG_RUNTIME_DIR` at an empty dir (also stops `mpris.so` joining the media controls) and add `--mute`.
- `mpris.so` blocks mpv startup forever without a reachable D-Bus: load scripts with `--load-scripts=no --script=...` for everything else.
- Give each run its own `--input-ipc-server` (short path: the 108-byte socket limit) — never `/tmp/mpvsocket` (hyprshaderd) — plus `--no-resume-playback --save-position-on-quit=no --watch-later-dir=<tmp>` and `memo-history_path=<tmp>`.
- `--display-fps-override=144`, or Xvfb's missing refresh rate floods `-v` logs (GBs in minutes).
- ananicy-cpp renices anything named `mpv` to -4: run a symlink with another name under `chrt -i 0` to stay out of the user's way. Xvfb frame drops/A-V desync are artifacts; use `vo-passes` for GPU cost.
- `-v` logs hold unredacted secrets only if a script bypasses the curl wrappers below — grep them before sharing, delete after.

`graphify-out/` contains a knowledge graph of this repo — run `graphify query "<question>"` before large-scale code exploration. After code/doc edits: `graphify update .`

`wiki/` (gitignored, local only) mirrors the mpv manual, the mpv GitHub wiki and the Arch wiki page as markdown. Grep `wiki/manual/` to check an option, property or command instead of going from memory.

## Architecture

Playback-load pipeline (scripts fire off `file-loaded`):

1. **anime_detect.lua** — TMDB `/search/multi` probe (genre 16 + `original_language=ja` **or** a Japanese audio track in `track-list`). Sets `user-data/anime_detect/is_anime`, which `[Anime]` in `profiles.conf` watches (a `/[Aa]nime/` path component also triggers `[Anime]` without TMDB). Session cache is applied **before** clearing the flag (avoids Anime4K flash). Async callbacks carry a generation token so a late TMDB result cannot write onto the next file. Keys: conf → env → `~~/.env` (mpv does not export `.env`). Debug logs mask `api_key=`; the URL reaches curl via `--config -` on stdin so mpv's `-v` subprocess log never sees it. TMDB query chain: filename title (or a `group_aliases` hit: `[One Pace]` → One Piece) → `series_cut()` (`S01E02`, `E07`, fansub `Show - 17`) → show folder name (skips `Season N`/`Specials`). Verified verdicts are also counted per folder in `~/.cache/mpv/anime_detect/dirs.json`; a folder whose verdicts all agree sets the flag on `file-loaded`, before the first frame (TMDB still runs and wins). Before this, half the anime library missed Anime4K and the rest switched shaders mid-playback.
2. **ar_subs** (`scripts/ar_subs.lua` + `script-modules/ar_subs/`) — Arabic subtitle fetch waterfall: offline Subscene index (`subtitle_api_url`) → SubSource → SubDL (dual-key quota failover). Stores `.ass.zst`/`.srt.zst` at rest in `~/.cache/mpv/ar_subs/subtitles/` (SQLite + zstd via `store.lua`); `util/zstd.lua` hot-dir names include a **parent-dir hash** so two shows' `Arabic.ass.zst` never collide. Skips fetch only when an **Arabic** sibling/track already exists (an English `video.srt` must not block). Downloads capture the path at start; `sub-add` is dropped if the file changed. Placeholder SubDL/api stubs are deleted, not cached. Zip-slip: `unzip -Z1` failure **refuses** the archive (fail closed). All-Arabic audio skips the automatic waterfall (`skip_if_arabic_audio`). **Episode identity** (`util/match.lua`): one parser `episode_tags()` for subtitle file and release names (S02E05, 3x07, S2-04, "S2 - 05", "2nd Season - 05", s4-episode_10, roman II/III) and one decision `episode_verdict()` shared by the search filter, release ranking and per-file pick — an explicit pair that is not valid rejects the name; a bare number is per-season only with its season named, else only the absolute count. `calculate_cour_mappings`: TMDB authoritative (guesses only without TMDB, weak, rejected when the name's own absolute count disagrees); long TMDB seasons carry cour starts from air-date gaps (Dan Da Dan: one 24-ep season, cour 2 at E13 = provider S2) and a cour label only when TMDB has no real next season; a title that is not the TMDB show name (`anime_season_unknown`, arc titles like "Katanakaji no Sato-hen") uses the season-0 wildcard. TMDB season info round-trips cache.json with string keys — always read through `numeric_season_info`. Season sources: name, `Season NN` folder, `S01E06-Title` titled by its folder; TV-looking names take the anime path on Japanese audio / anime_detect. `scripts/ar_subs.lua` wraps `mp.command_native(_async)` so every curl argv goes through `util/curl_secrets.lua` (headers, `-d` bodies and URLs move to a `--config -` stdin config) — new curl call sites are covered automatically; don't pass `stdin_data` to curl yourself or the wrapper steps aside.
3. **autosubsync** (`scripts/autosubsync/`) — aligns the loaded Arabic sub. Default path is ffsubsync (embedded text-sub ref first, audio VAD fallback). `timing_ref_mode` (`off`/`on`/`compare`; `compare` in both the script default and `script-opts/autosubsync.conf`) also runs `script-modules/autosubsync/timing_ref.py`: default embedded sub → Argos EN→AR (timestamps kept) → DTW-match onto the best-score downloaded sub; no text sub → sherpa-onnx VAD+ASR. Compare writes `*_retimed_argos.*` vs `*_retimed_ffsubsync.*` plus JSON. Refs: `~/.cache/mpv/autosubsync/refs/<hash>/`. Transform JSON is per-video **and** keyed to `src`. `synced_paths` / auto-timer cleared on `end-file`. Embedded-ref extraction is a **synchronous** subprocess (a minute on a cue-less 4K MKV) during which the script never sees `end-file`; the on-load chain re-checks the live `path` after each step, so a stale result never lands on the next episode. Extraction is **cue-bounded** (`bounded_extract_argv`: ffmpeg → awk cuts the pipe at 120 dialogue lines, 900s cap for sparse tracks) and starts on `file-loaded` in the background (`prefetch_current_episode`, waiters instead of a second demux); next-episode prefetch probes title+default so it never picks "Signs & Songs"; a cached manifest that is too thin is re-extracted once.
4. **Shaders / color** — `vo=gpu-next` (required for `target-colorspace-hint` / Hyprland HDR). Always-on SDR chain in `mpv.conf` (`KrigBilateral:SSimSuperRes:SSimDownscaler`). `[hdr-passthrough]` (pq/hlg) empties shaders and sets PQ hint. `[sdr-native]` is **transfer-gated** (not pq/hlg) so Rec.2020 SDR matches and Rec.709-primaries HDR does not. `[Anime]` REPLACES the chain with Anime4K v4.x Mode A + KrigBilateral, height-gated `<1600` and HDR-excluded. `ALT+1..7` swap chains; `blend-subtitles=video` is load-bearing for gpu-next seek-subs (screenshots temporarily turn it off).
5. **dynamic-crop** (`scripts/dynamic-crop.lua`) — CUDA sidecar; pin `mpv_socket=/tmp/mpvsocket` in `script-opts/dynamic_crop.conf` so hyprshaderd keeps that path. Two scan failures `dofile` `script-modules/dynamic-crop-legacy.lua` and switch `hwdec` to `nvdec-copy` for cropdetect. **Next `file-loaded` retries CUDA** and restores nvdec. Sidecar EOF callback must use a forward-declared `playback_ended`. Startup pause has a 2s watchdog. Scan callbacks carry a per-file generation (`file_gen`): `eof-reached` stays false on quit/next-file, and an in-flight scan used to fall into the direct fallback, get killed (-2) and count as a CUDA failure. `min_crop_width_ratio` (0.70) rejects centred logos/title cards on black, which otherwise pass every letterbox check. `min_crop_seconds` (3) keeps short letterbox shots that cut into 16:9 uncropped (anime cinematic inserts pumped 40 zooms/episode); restores are never delayed. The controller scans on demand (`min_lookahead_seconds`, seek/file-change rescans; `scan_interval` is only the longest wait) — back-to-back scans re-decoded 92% of each window. `startup_hold` is off in the conf (it froze every start 1-2s). **Subtitles during a crop:** gpu-next hands libass the crop as its frame and the uncropped picture as negative margins, so native ASS dialogue is laid out on the uncropped picture (+35% on 1920x800, top/bottom lines cut off) unless `sub-ass-force-margins=yes` (global in `mpv.conf`) fits it to the visible crop; SRT does that natively. Panscan mode must not touch `sub-pos`/`sub-scale`/margin flags. Four such workarounds (b0c341f, ff859c6, d316f82, ed1a088) were reverted; `blend-subtitles=no` does not help either (ASS still 1.37x). Verify with offscreen `screenshot-to-file ... window` under Xvfb, not by eye.
6. **autochapters** (vendored po5/mpv-auto-chapters) — local fix in `file_load()`: upstream's `search_only_when_chapters_missing` counted the kept list (always empty), so aniskip's 2-entry OP list replaced full embedded chapters; SmartSkip then skipped cold opens and lost ED/Preview.
7. **uosc** (vendored, `scripts/uosc/`) — the UI; `osc=no` in mpv.conf is load-bearing. SmartSkip (`scripts/SmartSkip.lua`) auto-skips OP/ED/Preview with **no** countdown/OSD. memo = recent-files (`h`); sponsorblock = YouTube only. `keylayout.lua` remaps Arabic letters; extra modifiers (`ctrl+shift` / `ctrl+alt`) are **only on `v`** so `Ctrl+Shift+V` works without stealing every ctrl+shift+letter.

## Repo-specific gotchas

- **Conditional profiles must declare `profile-restore=copy-equal`** or their options leak across files (session-order dependent). In `mpv.conf`, everything after a `[profile]` header belongs to that profile — global options live **above** the header blocks at the end of the file.
- **Audio downmix** (`profiles.conf`): +4 dB dialogue lift then `alimiter` at -0.26 dBFS (`level=disabled`) — without it loud scenes clip.
- **HDR**: DP-2 EDID = 604-nit peak / 277-nit frame-average / ~P3. `[hdr-passthrough]` stays passthrough; `Ctrl+h` A/Bs mpv tone-mapping to 604 nits. Tone quality can't be judged headless.
- **watch-later saves `panscan`/`sub-pos`/`sub-scale`/margin flags by default.** Anything a script changes at runtime is resumed on the next launch unless listed in `watch-later-options-remove` (crop-owned options are).
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
