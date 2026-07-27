# mpv Manual Reference

Split from the [official mpv manual](https://mpv.io/manual/master/) into searchable markdown files.
All files are under 200 lines. Multi-part files use numbered suffixes (e.g. `-1`, `-2`).

## Getting Started

| File | Topic |
|------|-------|
| [manual-synopsis.md](manual-synopsis.md) | Command-line usage synopsis |
| [manual-description.md](manual-description.md) | What mpv is |
| [manual-interactive-control-1.md](manual-interactive-control-1.md) | Keyboard, mouse, context menu controls |
| [manual-usage-1.md](manual-usage-1.md) | Legacy syntax, escaping, paths, per-file options |
| [manual-configuration-files-1.md](manual-configuration-files-1.md) | Config file location, syntax, profiles, auto profiles |

## Usage & Behavior

| File | Topic |
|------|-------|
| [manual-using-mpv-from-other-programs-or-scripts.md](manual-using-mpv-from-other-programs-or-scripts.md) | Controlling mpv externally |
| [manual-taking-screenshots.md](manual-taking-screenshots.md) | Screenshot commands |
| [manual-terminal-status-line.md](manual-terminal-status-line.md) | Terminal status line display |
| [manual-low-latency-playback.md](manual-low-latency-playback.md) | Low-latency / live stream playback |
| [manual-resuming-playback.md](manual-resuming-playback.md) | Resume where you left off |
| [manual-protocols.md](manual-protocols-1.md) | Supported protocols (file, http, ytdl, etc.) |
| [manual-pseudo-gui-mode.md](manual-pseudo-gui-mode.md) | Pseudo-GUI mode on Windows |
| [manual-positioning.md](manual-positioning.md) | Window positioning |

## Options Reference

Options are split by subsystem. Large sections have numbered parts.

### Track Selection & Playback
| File | Topic |
|------|-------|
| [manual-options-track.md](manual-options-track.md) | `--aid`, `--vid`, `--sid`, `--alang`, etc. |
| [manual-options-playback-1.md](manual-options-playback-1.md) | Seek, speed, playlist, chapters, editions |
| [manual-options-program-1.md](manual-options-program-1.md) | `--fullscreen`, `--keep-open`, `--save-position`, etc. |
| [manual-options-watch-later.md](manual-options-watch-later.md) | Watch later / resume state |

### Video
| File | Topic |
|------|-------|
| [manual-options-video-1.md](manual-options-video-1.md) | `--vo`, `--vd`, profiles, hwdec, etc. |
| [manual-options-gpu-1.md](manual-options-gpu-1.md) | GPU renderer options (`--vo=gpu`) |
| [manual-options-video-sync.md](manual-options-video-sync.md) | `--video-sync`, interpolation, display timing |
| [manual-options-software-scaler.md](manual-options-software-scaler.md) | `--sw-scaler` options |

### Audio
| File | Topic |
|------|-------|
| [manual-options-audio-1.md](manual-options-audio-1.md) | `--ao`, `--ac`, volume, channels, etc. |
| [manual-options-audio-resampler.md](manual-options-audio-resampler.md) | Audio resampler options |
| [manual-options-equalizer.md](manual-options-equalizer.md) | Audio equalizer options |

### Subtitles
| File | Topic |
|------|-------|
| [manual-options-subtitles-1.md](manual-options-subtitles-1.md) | `--sub-auto`, sub styling, ASS, etc. |

### Window & Display
| File | Topic |
|------|-------|
| [manual-options-window-1.md](manual-options-window-1.md) | `--geometry`, `--ontop`, `--fullscreen`, window state |
| [manual-options-osd-1.md](manual-options-osd-1.md) | OSD display, font, timing options |
| [manual-options-screenshot-1.md](manual-options-screenshot-1.md) | Screenshot format, directory, template |

### Demuxer, Cache & Network
| File | Topic |
|------|-------|
| [manual-options-demuxer-1.md](manual-options-demuxer-1.md) | Demuxer, stream, edl options |
| [manual-options-cache-1.md](manual-options-cache-1.md) | `--cache`, `--demuxer-max-bytes`, cache schemes |
| [manual-options-network.md](manual-options-network.md) | `--user-agent`, `--http-header-fields`, etc. |
| [manual-options-disc.md](manual-options-disc.md) | DVD/Blu-ray device options |
| [manual-options-dvb.md](manual-options-dvb.md) | DVB (digital TV) options |

### Input & Terminal
| File | Topic |
|------|-------|
| [manual-options-input-1.md](manual-options-input-1.md) | `--input-conf`, `--input-*, keyboard/mouse options |
| [manual-options-terminal.md](manual-options-terminal.md) | `--term-osd-bar`, terminal output options |

### Misc
| File | Topic |
|------|-------|
| [manual-options-misc-1.md](manual-options-misc-1.md) | `--msg-level`, `--dump-stats`, profiling, Wayland |

## Output Drivers

| File | Topic |
|------|-------|
| [manual-audio-output-drivers-1.md](manual-audio-output-drivers-1.md) | ALSA, PulseAudio, PipeWire, WASAPI, etc. |
| [manual-video-output-drivers-1.md](manual-video-output-drivers-1.md) | GPU, X11, Wayland, etc. |

## Filters

| File | Topic |
|------|-------|
| [manual-audio-filters-1.md](manual-audio-filters-1.md) | `--af`, audio filters (equalizer, volume, etc.) |
| [manual-video-filters-1.md](manual-video-filters-1.md) | `--vf`, video filters (crop, scale, deinterlace, etc.) |
| [manual-encoding.md](manual-encoding.md) | `--o` / `--of` encoding mode |

## Command Interface

| File | Topic |
|------|-------|
| [manual-input-conf.md](manual-input-conf.md) | `input.conf` file format and syntax |
| [manual-key-names.md](manual-key-names.md) | Key name reference |
| [manual-input-commands-1.md](manual-input-commands-1.md) | Command syntax, key binding commands |
| [manual-list-of-commands-1.md](manual-list-of-commands-1.md) | All input commands (playback, OSD, track, playlist, etc.) |
| [manual-hooks.md](manual-hooks.md) | Command hooks |
| [manual-properties.md](manual-properties.md) | Properties overview |
| [manual-property-list-1.md](manual-property-list-1.md) | All properties reference |

## Built-in Scripts & UI

| File | Topic |
|------|-------|
| [manual-on-screen-controller-1.md](manual-on-screen-controller-1.md) | OSC (On-Screen Controller) |
| [manual-stats-1.md](manual-stats-1.md) | Stats overlay (shift+i) |
| [manual-console-1.md](manual-console-1.md) | Console (`) for commands |
| [manual-commands.md](manual-commands.md) | Built-in script commands |
| [manual-select.md](manual-select.md) | Selection UI script |
| [manual-context-menu-script.md](manual-context-menu-script.md) | Context menu script |

## Scripting

| File | Topic |
|------|-------|
| [manual-lua-scripting-1.md](manual-lua-scripting-1.md) | Lua scripting API |
| [manual-javascript-1.md](manual-javascript-1.md) | JavaScript scripting API |
| [manual-json-ipc-1.md](manual-json-ipc-1.md) | JSON IPC protocol |

## Reference

| File | Topic |
|------|-------|
| [manual-changelog.md](manual-changelog.md) | Version changelog |
| [manual-embedding-into-other-programs-libmpv.md](manual-embedding-into-other-programs-libmpv.md) | libmpv embedding |
| [manual-c-plugins.md](manual-c-plugins.md) | C plugin system |
| [manual-environment-variables.md](manual-environment-variables.md) | Environment variables |
| [manual-exit-codes.md](manual-exit-codes.md) | Exit codes |
| [manual-optical-drives.md](manual-optical-drives.md) | Optical drive access |
| [manual-files.md](manual-files.md) | File paths and config locations |
| [manual-files-on-windows.md](manual-files-on-windows.md) | Windows-specific paths |
| [manual-files-on-macos.md](manual-files-on-macos.md) | macOS-specific paths |
