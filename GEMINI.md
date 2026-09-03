# GEMINI.md

Instructions for Gemini CLI / Gemini Code Assist.

This tree **is** the live mpv config (`~/.config/mpv`). Follow **CLAUDE.md** in this directory as the canonical project guide (architecture, commands, gotchas, conventions). Keep `GEMINI.md`, `AGENTS.md`, and `CLAUDE.md` in sync when the pipeline or gotchas change.

## Quick commands

```sh
lua script-modules/ar_subs/test/run.lua
luajit -e "assert(loadfile('scripts/ar_subs.lua'))"
mpv --vo=null --ao=null --fs=no --keep-open=no --script-opts=uosc-autoload=no --untimed <file>
graphify query "<question>"
graphify update .
```

## Non-negotiables

- Never commit `.env`, `script-opts/ar_subs.conf`, `script-opts/anime_detect.conf`, or API key values. Never log unmasked `api_key=`.
- Feature work on branches; README installers fetch `master`.
- Parse Lua with **LuaJIT**, not system `luac` 5.4.
- `profile-restore=copy-equal` on every conditional profile. `msg-level` is one line.
- Async `file-loaded` work (TMDB, SubDL, sub-add, crop sidecar) must drop stale callbacks when the path changes.

## Pipeline (see CLAUDE.md for detail)

`file-loaded` → anime_detect (generation-token TMDB) → ar_subs waterfall → autosubsync (src-keyed transform) → `[Anime]` / `[hdr-passthrough]` / `[sdr-native]` → dynamic-crop CUDA (legacy cropdetect + nvdec-copy failover, CUDA retry next file).
