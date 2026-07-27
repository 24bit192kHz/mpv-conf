# mpv Documentation Wiki

Searchable local mirror of the three official mpv documentation sources.

## Sources

| Directory | Source | Files | Lines | Description |
|-----------|--------|-------|-------|-------------|
| [wiki/](wiki/README.md) | [mpv-player/mpv wiki](https://github.com/mpv-player/mpv/wiki) | 37 md | 1,653 | FAQ, user scripts, technical articles, platform guides, shaders |
| [arch/](arch/README.md) | [Arch Linux Wiki — mpv](https://wiki.archlinux.org/title/Mpv) | 12 md | 683 | Installation, configuration, profiles, tips, troubleshooting |
| [manual/](manual/README.md) | [mpv.io manual](https://mpv.io/manual/master/) | 162 md | 23,299 | Full options reference, commands, properties, scripting, IPC, filters |

**Total: 211 markdown files, 25,635 lines**

## Searching

### Quick grep (terminal)

```sh
# Search all sources for a keyword
grep -ri "your-term" /home/btw/.config/mpv/wiki/

# Search a specific source
grep -ri "gpu-next" /home/btw/.config/mpv/wiki/wiki/
grep -ri "hwdec" /home/btw/.config/mpv/wiki/arch/
grep -ri "cache" /home/btw/.config/mpv/wiki/manual/
```

### In mpv itself

```sh
# Manual options are organized to mirror the manpage structure
ls /home/btw/.config/mpv/wiki/manual/manual-options-*
```

## Structure Conventions

- **wiki/** — Flat naming (`wiki-faq-general.md`, `wiki-interpolation.md`) with image assets in subdirs
- **arch/** — Prefixed naming (`arch-configuration.md`, `arch-tips-video.md`)
- **manual/** — Topic-prefixed with numbered parts for large sections (`manual-options-gpu-1.md`, `manual-options-gpu-2.md`). Continuations carry the same prefix with `-2`, `-3` suffixes.

## Last Updated

2026-07-09 — Freshly mirrored from all three sources.
