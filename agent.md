# agent.md - mpv config operational knowledge base

For AI assistants maintaining this specific mpv config (Hyprland + Nvidia + HDR + Arabic subtitles).

## §0: JUMP TABLE

| Symptom / task | Section |
|---|---|
| HDR not activating, wrong colors | §3 HDR Pipeline |
| Dynamic crop does nothing, wrong crop | §5.1 dynamic-crop.lua |
| Arabic subs not downloading | §5.2 subdl_ar.lua |
| Playback stutters, dropped frames | §1 Platform & Render Chain |
| Script not responding to keybinds | §4 Script Ecosystem |
| Interpolation not working | §2 Profile Interaction Matrix (sdr-native vs hdr-passthrough) |
| Audio too quiet or missing channels | §2 Downmix profiles, input.conf F1/loudnorm |
| Weird colors after seeking | §2 Profile Interaction Matrix |
| Webrtorrent entries in memo history | §2 Webtorrent-Entries profile |
| Deband not applying | §2 Anime profile, Deband-Medium/Strong profiles |
| Subtitle timing off | §5.2 subdl_ar.lua failure modes |
| `.env` keys not loading | §4 Key loading priority |
| Want to add new key binding | §8 Key Bindings by Function |

---

## §1: PLATFORM & RENDER CHAIN

This config targets Nvidia GPU + Hyprland (Wayland compositor). The render chain choices are not defaults - each is forced by this specific stack.

**Render chain:**
```
vo=gpu-next → gpu-api=vulkan → gpu-context=waylandvk → hwdec=nvdec
```

- **vo=gpu-next** (NOT vo=gpu). gpu-next includes the complete HDR pipeline (tone mapping, gamut mapping, color management). vo=gpu is missing HDR features and produces washed-out output on HDR content.
- **gpu-api=vulkan** (NOT opengl). Nvidia's OpenGL driver on Wayland has compositor synchronization bugs that cause visible tearing and stutter. Vulkan on Wayland (through waylandvk) avoids these issues entirely. Also required for zero-copy Nvdec interop on this stack.
- **gpu-context=waylandvk**. Required for Vulkan under Wayland. The only working Nvidia+Wayland Vulkan context. x11vk would not work (not running X11), winvk is Windows-only.
- **hwdec=nvdec**. Nvidia's hardware decoder. NOT vaapi (Intel/AMD), NOT d3d11 (Windows), NOT videotoolbox (macOS). Nvdec + Vulkan on Nvidia provides zero-copy decode-to-display (GPU memory stays on-GPU).

**Verification commands:**
- `mp.commandv("show_text", "${vo}")` - should show "gpu-next"
- `mp.commandv("show_text", "${gpu-context}")` - should show "waylandvk"
- `mp.commandv("show_text", "${hwdec}")` - should show "nvdec"
- Check for dropped frames: `mp.commandv("show_text", "${estimated-display-fps} vs ${container-fps} dropped: ${frame-drop-count}")`
- Enable the console (press `/`) and inspect `print(vo)` output.

---

## §2: PROFILE INTERACTION MATRIX

This config has 6 conditional profiles plus 2 manual ones. Understanding how they combine is essential because they override each other in non-obvious ways.

### 2.1 Profile Inventory

| # | Profile | File & Lines | Condition | Restore |
|---|---|---|---|---|
| 1 | hdr-passthrough | mpv.conf:64-81 | `gamma == "pq" or gamma == "hlg"` | copy-equal |
| 2 | sdr-native | mpv.conf:84-94 | `primaries != "bt.2020"` | copy-equal |
| 3 | Anime | profiles.conf:31-41 | path contains `/Anime/` or `/anime/` | copy-equal |
| 4 | Downmix-5.1 | profiles.conf:17-21 | channel-count 5-6 | copy-equal |
| 5 | Downmix-7.1 | profiles.conf:23-27 | channel-count >= 7 | copy-equal |
| 6 | Webtorrent-Entries | profiles.conf:45-48 | path contains "webtorrent" | copy-equal |
| - | Deband-Medium | profiles.conf:3-7 | manual apply only | none |
| - | Deband-Strong | profiles.conf:9-13 | manual apply only | none |

### 2.2 profile-restore=copy-equal

Options set by a profile are applied when its condition becomes true; options not set keep their current value. When the condition becomes false, options restore to their pre-profile value. **Later profiles override earlier profiles** on the same option.

### 2.3 Mutual Exclusivity: hdr-passthrough vs sdr-native

HDR content (pq/hlg gamma) → hdr-passthrough fires (interpolation=no, video-sync=audio). SDR content (primaries != bt.2020) → sdr-native fires (interpolation=yes, tscale=oversample). If both conditions match, hdr-passthrough wins (appears first in mpv.conf).

### 2.4 Stacking Rules

Profiles evaluate top-to-bottom within each file, then across profile-cond in script-opts. Most combinations are safe because they touch disjoint option sets: Anime sets only deband+sub-scale, Downmix sets only audio+volume, Webtorrent sets only memo-enabled. Conflicts only arise when two profiles set the same option. The mutually exclusive pair (hdr-passthrough/sdr-native) and the downmix profiles (5.1 vs 7.1, same option set) avoid conflict via disjoint conditions.

### 2.5 Non-obvious Interactions

- **Interpolation toggling** (`g` key): Toggles `interpolation` globally. When hdr-passthrough is active, interpolation starts at `no` and gets toggled to `yes` by the key. When sdr-native is active, it starts at `yes` and gets toggled to `no`. The `g` toggle just flips the current value.
- **Anime enabling deband**: Base config has deband=no (deband off by default to save GPU). The Anime profile enables it with mild settings (2 iterations, threshold=35). For non-anime content, manually apply Deband-Medium or Deband-Strong profiles via input.conf (ALT+d cycles deband on/off).
- **Webtorrent-Entries hides from memo**: The profile sets `memo-enabled=no` for files whose path contains "webtorrent". This prevents webtorrent stream entries from cluttering the history list.
- **Downmix volume-max=200**: 5.1 and 7.1 content is downmixed to stereo with a gain of 1.6x. volume-max=200 is needed so the master volume slider can reach the boosted levels. Without it, downmixed audio might sound quiet even at volume=100.

---

## §3: HDR PIPELINE

### 3.1 Base Settings

Applied unconditionally (before profile evaluation):
```
target-colorspace-hint=yes
target-colorspace-hint-mode=source-dynamic
tone-mapping=auto
gamut-mapping-mode=perceptual
```

`target-colorspace-hint=yes` tells mpv to signal the display's color space. `source-dynamic` mode adjusts the signal per-frame based on source metadata. `tone-mapping=auto` is the fallback - the hdr-passthrough profile overrides it.

### 3.2 hdr-passthrough Parameters (Active on HDR Sources)

```
target-prim=bt.2020           # Display primaries: BT.2020 wide gamut
target-trc=pq                 # Perceptual Quantizer (ST.2084) transfer
target-gamut=dci-p3           # Display gamut: DCI-P3 (OLED typical)
target-peak=750               # Peak luminance in cd/m² (OLED specific)
target-contrast=inf           # Infinite contrast (OLED)
tone-mapping=st2094-40        # SMPTE ST.2094-40 (Samsung/OLED tone mapping)
gamut-mapping-mode=perceptual # Perceptual gamut compression
hdr-reference-white=275       # Middle gray at 275 cd/m²
hdr-peak-percentile=99.995    # Ignore top 0.005% of luminance pixels (noise rejection)
hdr-contrast-recovery=0.30    # Recover highlight detail, can cause pumping above 0.30
hdr-compute-peak=no           # Disable frame-by-frame peak computation (Nvidia perf workaround)
video-output-levels=full      # Full range output (not limited/TV range)
video-sync=audio              # Match audio clock (safe for HDR)
interpolation=no              # Disabled in HDR to avoid frame pacing issues
```

### 3.3 Rationale for Specific Values

See §7 for quick reasons on each value. Key callouts: st2094-40 beats bt.2390 on OLED (more highlight detail retained). hdr-compute-peak=no avoids Nvidia stutter. hdr-contrast-recovery caps at 0.30 to prevent brightness pumping. hdr-peak-percentile=99.995 clips noise pixels without losing specular highlights.

### 3.4 Verification

```lua
-- In mpv console (/):
print(mp.get_property("video-params/gamma"))         -- should be "pq" or "hlg" for HDR
print(mp.get_property("target-peak"))                 -- should be "750"
print(mp.get_property("tone-mapping"))                -- should be "st2094-40"
print(mp.get_property("interpolation"))               -- should be "no" in HDR
print(mp.get_property("video-sync"))                  -- should be "audio" in HDR
```

Also check that the OSD shows the correct active profile: cycle through OSD info (default `i` key or uosc info panel).

---

## §4: SCRIPT ECOSYSTEM MAP

Communication flow between scripts:

```
inputevent.lua  (enables @click/@press/@release annotation in input.conf)
  └→ evafast.lua     (hybrid seek/speed on MBTN_LEFT hold)
  └→ dynamic-crop.lua (C key)
      └→ cuda-crop-cpp (C++17 socket daemon via nlohmann_json)
          └→ ffprobe (cropdetect filter, fallback)
      └→ script-modules/dynamic-crop-legacy.lua (2nd fallback)

uosc/  (OSC replacement, menu system)
  ├→ dynamic-crop.lua  (uosc menu items for cycle-mode/continuous/one-shot/disabled)
  ├→ subdl_ar.lua      (uosc picker for subtitle download)
  ├→ thumbfast.lua     (thumbnail preview on timeline)
  └→ memo.lua          (history menu integration)

subdl_ar.lua
  ├→ SubDL API v2 (Bearer auth search, query-param download)
  ├→ TMDB API v3  (metadata fallback, anime cour resolution)
  └→ TVDB API v4  (disabled: use_tvdb_cour=no)

sponsorblock.lua  → sponsorblock API (YouTube segments)
autosubsync.lua   → ffmpeg (subtitle timing correction)
jellyfin.lua       → local Jellyfin server (media playback)
```

### Key loading priority
1. `script-opts/subdl_ar.conf` (mpv option overrides)
2. `os.getenv(...)` (environment variables)
3. `~/.config/mpv/.env` (file-based fallback)

For full API reference (endpoints, auth, rate limits), see **AGENTS.md**.

### inputevent.lua guardrail
`inputevent.lua` (461 lines) is critical for the MBTN_LEFT annotation chain but should NOT be modified unless you fully understand its annotation dispatch. It parses `#@click`, `#@press`, `#@release` suffixes on input.conf lines and routes them to mpv's multi-key binding system. Breaking it breaks the mouse hold-to-speedup feature.

---

## §5: CUSTOM SCRIPTS - DEEP COVERAGE

### 5.1 dynamic-crop.lua (1205 lines, scripts/dynamic-crop.lua)

**Purpose**: Detects and removes letterbox bars in video content automatically. Cycles through continuous cropping, one-shot crop, and disabled modes.

**Architecture**: Three-tier fallback chain:
1. **cuda-crop-cpp daemon** (primary): C++17 socket daemon at `~~/cuda-crop-cpp/` (CMake project). Listens on `/tmp/cuda-crop-cpp.sock`. Runs ffprobe with `cropdetect` filter. Returns detected crop rectangles via JSON over Unix socket. Requires `nlohmann_json` at build time.
2. **ffprobe direct** (fallback): If socket daemon is unavailable, invokes ffprobe directly as a subprocess.
3. **dynamic-crop-legacy.lua** (2nd fallback): Pure Lua implementation at `~~/script-modules/dynamic-crop-legacy.lua`. Used when both cuda and ffprobe fail.

**Three modes** (cycled by `C` key):
- **continuous**: Re-evaluates crop every `scan_interval` seconds. Adapts to scene changes.
- **one-shot**: Crops once at playback start. Best for consistent letterbox throughout.
- **disabled**: No automatic cropping.

**Two apply modes** (configurable, default=transform):
- **transform** (default): Uses `vf=crop` filter. Re-encodes video frames (GPU cost). Preserves original aspect ratio signaling.
- **panscan**: Zooms to fill letterboxed area. No re-encode overhead. Works with `panscan_letterbox` and `panscan_full` ratios.

**Key options** (from mpv.conf script-opts): symmetry_tolerance=96 (pixel symmetry), min_votes=2 (cropdetect agreement), sample_step=1, min_letterbox_aspect=1.8, max_letterbox_aspect=2.60, apply_mode=transform (vf crop), backend=cuda, daemon_idle_timeout=10.0s, fallback_failures=2, telemetry=yes, startup_pause=yes (pauses during initial detection).

**Troubleshooting checklist**:
1. Check the C++ binary exists: `ls ~/.config/mpv/cuda-crop-cpp/build/cuda-crop-cpp`
2. Check the daemon socket: `ls /tmp/cuda-crop-cpp.sock`
3. Check mpv log level: `msg-level=dynamic_crop=info` in mpv.conf
4. Check ffprobe is in PATH: `which ffprobe`
5. Test socket manually: `echo '{"path":"/path/to/video.mkv"}' | nc -U /tmp/cuda-crop-cpp.sock`
6. Verify legacy fallback exists: `ls ~/.config/mpv/script-modules/dynamic-crop-legacy.lua`

### 5.2 subdl_ar.lua (1741 lines, scripts/subdl_ar.lua)

**Purpose**: Automatic Arabic subtitle downloader. Searches SubDL API, resolves metadata via TMDB (and optionally TVDB), presents results through uosc picker.

**Module tree** (script-modules/subdl_ar/): init.lua (path bootstrap), config.lua (config loading), http.lua (HTTP+rate-limit+backup key rotation), cache.lua, providers/subdl.lua (SubDL), providers/tvdb.lua (DISABLED), util/{match,media,url,activation}.lua, ui/uosc_picker.lua (uosc menu integration).

**Auth split**: Search on api.subdl.com uses `Authorization: Bearer <key>`. Downloads on dl.subdl.com use `?api_key=<key>` query param (embedded in URL from search results).

**Key loading priority**: script-opts/subdl_ar.conf → os.getenv() → ~/.config/mpv/.env

**TVDB**: Disabled (`use_tvdb_cour=no`). The TVDB provider script exists at `script-modules/subdl_ar/providers/tvdb.lua` but is never called. The TVDB API key in `.env` is unused. To enable, set `use_tvdb_cour=yes` in script-opts or .env.

**Quota limits** (free tier): 2000 searches/day + 50 downloads/day. Backup key rotation occurs on HTTP 429 or `quota_exceeded` JSON error. For quota checks against live API: `curl -H "Authorization: Bearer $KEY" https://api.subdl.com/api/v2/me`

**Failure modes**:
- `quota_exceeded` - all keys exhausted. Wait for daily reset or upgrade to Pro.
- HTTP 404 on `/api/v2/subtitles` - forgot `/search` in URL path.
- Language code `"ar"` not `"ara"`. SubDL uses two-letter uppercase codes (AR, EN).
- `.env` not loaded - keys placed in wrong file or file has wrong permissions.
- TVDB errors - not relevant, TVDB is disabled.

**Full API reference**: AGENTS.md (477 lines covering SubDL v2, TMDB v3, TVDB v4 endpoints, auth flows, rate limits, gotchas).

### 5.3 Other custom scripts

- **ar_shortcuts.lua** (46 lines): Arabic keyboard layout remapping. Maps Arabic Unicode characters to their Latin key equivalents via a lookup table. Both plain and ctrl/alt+key variants. Used by bilingual users who keep keyboard in Arabic mode. Not performance critical - simple keypress remapping.

---

## §6: SCRIPT DETAIL PRIORITY TABLE

| Script | Lines | Type | Coverage depth | Why |
|---|---|---|---|---|
| dynamic-crop.lua | 1205 | Custom | **Deep** | C++ sidecar, 3-tier fallback, complex mode system, many config opts |
| subdl_ar.lua | 1741 | Custom | **Deep** | 3-API pipeline, auth split, module tree, quota management |
| uosc/ | ~1202 | Third-party | One-liner | UI replacement, standard integration points only |
| thumbfast.lua | 940 | Third-party | One-liner | Thumbnails for uosc timeline, standard config |
| evafast.lua | 313 | Third-party | One-liner | Hybrid seek/speed, configured via input.conf annotations |
| sponsorblock.lua | 569 | Third-party | One-liner | YouTube segment skipping, own API |
| autoload.lua | 334 | Third-party | One-liner | Standard playlist autoload |
| autosubsync/ | ~509 | Third-party | One-liner | ffmpeg subtitle sync, called manually |
| autodeint.lua | 156 | Custom | One-liner | Simple deinterlace keybind, not complex |
| memo.lua | 1161 | Third-party | One-liner | File history, standard config |
| jellyfin.lua | 309 | Custom | One-liner | Jellyfin client integration |
| inputevent.lua | 461 | Third-party | One-liner (guardrail only) | Annotation dispatch, do not modify |
| user-input.lua | 757 | Third-party | One-liner | Text input helper |
| space-hold-speed.lua | 57 | Custom | One-liner | Minimal speed control |
| auto-save-state.lua | 68 | Custom | One-liner | Per-file state persistence |
| no-index-seek.lua | 278 | Custom | One-liner | Blocks index-seeking on certain files |
| ar_shortcuts.lua | 46 | Custom | One-liner | Arabic key remap table |

---

## §7: NON-OBVIOUS CONFIG VALUES

Each value with the reason it's set this way (not just what it does).

| Value | Reason |
|---|---|
| `gpu-context=waylandvk` | Only working Vulkan context on Nvidia+Wayland (Hyprland). No alternative. |
| `gpu-api=vulkan` | Nvidia OpenGL on Wayland has compositor sync bugs (tearing, stutter). |
| `hwdec=nvdec` | Nvidia-only hardware decoder. NOT vaapi (Intel/AMD) or d3d11 (Windows). |
| `target-peak=750` | OLED-specific peak brightness. 750 cd/m² is typical for OLED sustained output. |
| `tone-mapping=st2094-40` | SMPTE ST.2094-40 produces better highlight rolloff on OLED than bt.2390. |
| `hdr-compute-peak=no` | Frame-by-frame peak computation causes periodic stutter on Nvidia. |
| `hdr-contrast-recovery=0.30` | Above 0.30 causes visible brightness pumping. 0.30 is max safe value. |
| `demuxer-max-bytes=2G` | Needed for large MKV files (4K remuxes can be 60+ GB). Prevents re-buffering. |
| `sub-ass-override=force` | Forces positioning override on ASS subtitles. Required for Arabic ASS subs that have wrong position metadata. |
| `blend-subtitles=yes` | Blends subtitles with video (composite) instead of overlaying. Prevents subtitle flicker with HDR. |
| `hr-seek=no` | Disables "high resolution" seeking (keyframe-accurate instead of sample-accurate). Avoids seeking delays on large files. Sample-accurate seeking causes decoder reinit and decoder delay. |
| `demuxer-mkv-probe-video-duration=no` | Disables slow MKV duration probing at file open. Some MKVs trigger a full scan of the file to determine duration, causing multi-second delays. |
| `sub-codepage=cp1256` | Windows-1256 is the standard Arabic ANSI codepage. Required for Arabic subtitle files that lack UTF-8 BOM. |
| `sub-font='Calibri'` | Calibri has good Arabic glyph coverage with proper shaping. Not all fonts handle Arabic ligatures correctly. |
| `save-position-on-quit=yes` with `watch-later-options-remove=pause`, `vf`, `video-crop` | Remember playback position but do NOT restore paused state, video filters, or crop state. Avoids resuming into a blank screen or stuck crop. |
| `osd-font=calibri` | Same Arabic glyph requirement as subtitle font. |
| `audio-channels=auto-safe` | `auto-safe` avoids common speaker mapping issues with surround content on stereo systems. Standard auto can misdetect. |
| `pipewire-buffer=1024` | PipeWire audio buffer in microseconds. Lower values reduce latency but risk crackling. 1024 is a safe middle ground. |
| `volume-max=100` | Default. Overridden to 200 by downmix profiles when 5.1/7.1 content is detected. |

---

## §8: KEY BINDINGS BY FUNCTION

Not a full input.conf dump. These are the non-obvious or non-standard bindings.

| Key | Function | Notes |
|---|---|---|
| MBTN_LEFT click | pause (cycle pause) | Via `#@click` annotation processed by inputevent.lua |
| MBTN_LEFT press | evafast/speedup | Hold to speed up playback. `#@press` annotation. |
| MBTN_LEFT release | evafast/slowdown | Restores normal speed. `#@release` annotation. |
| C | dynamic_crop cycle mode | Cycles continuous/one-shot/disabled. Defined via script-opts, not input.conf. |
| g | cycle interpolation | Toggles interpolation on/off. Starts "yes" in sdr-native, "no" in hdr-passthrough. |
| F1 | toggle loudnorm af | Applies/removes EBU R128 loudnorm filter (I=-14, TP=-3, LRA=4). For dialogue normalization. |
| Ctrl+2 | cycle tone-mapping | Cycles between "bt.2446a" and "off". For manual override when auto detection is wrong. |
| M | cycle mono mix | Toggles stereo-to-mono downmix filter. For single-speaker listening. |
| . / , | frame step / frame back | Frame-accurate navigation (YouTube-style with .). > / < are shifted fallbacks. |
| RIGHT / LEFT | seek 5 / -5 | Plain seeking (NOT evafast hybrid). Overrides any speed-based seek behavior. |
| PGUP / PGDN | playlist prev / next | Quick playlist navigation. |
| Tab | uosc/flash-ui | Shows uosc UI elements temporarily. |
| h | memo-history | Opens file history menu via uosc. |
| ALT+d | cycle deband | Toggles deband on/off. Useful when Anime profile didn't fire. |
| Ctrl+d | autodeint/autodeint | Auto-deinterlace detection and application. |
| ALT+b | autosub/download_subs | Manual subtitle download trigger (subdl_ar). |
| / | console/enable | Opens mpv console for debugging. |
| b | uosc/open-file | Open file dialog. |
| y / Y | load subtitles / select subtitle | Separate key for loading new and selecting existing. |
| v | cycle sub-visibility | Toggle subtitles on/off. |

---

## §9: TROUBLESHOOTING INDEX

### HDR not activating
1. Check gamma: `print(mp.get_property("video-params/gamma"))` - should be "pq" or "hlg"
2. Check target-peak: `print(mp.get_property("target-peak"))` - should be "750" if profile active
3. Check profile is active: `print(mp.get_property("profile"))` or cycle OSD info
4. Verify display supports HDR: `print(mp.get_property("target-colorspace-hint"))` should be "yes"
5. If colors look washed out, the sdr-native profile might be firing instead - check primaries

### Dynamic crop not working
1. `which ffprobe` - is ffprobe installed? (required by both daemon and fallback)
2. `ls ~/.config/mpv/cuda-crop-cpp/build/cuda-crop-cpp` - does the binary exist?
3. Check mpv log level: `msg-level=dynamic_crop=info` is already set, look for crop messages
4. Check the socket: `ls /tmp/cuda-crop-cpp.sock`
5. Check the daemon is running: `ps aux | grep cuda-crop`
6. Set log to verbose: temporarily change to `msg-level=dynamic_crop=v`
7. Test with a known letterboxed video at a specific time position

### Arabic subs not downloading
1. Check API keys: `cat ~/.config/mpv/.env` (redact in output) - SUBDL_API_KEY must be set
2. Check quota: `curl -H "Authorization: Bearer $KEY" https://api.subdl.com/api/v2/me`
3. Check language code: SubDL uses "AR" (uppercase two-letter), not "ara" or "Arabic"
4. Check whether the file name is parseable - subdl_ar needs a recognizable title
5. Check network: does the machine have internet access?
6. Check script-opts: `cat ~/.config/mpv/script-opts/subdl_ar.conf` for overrides
7. Full API details in AGENTS.md

### Playback stutters / dropped frames
1. `print(mp.get_property("frame-drop-count"))` - are frames being dropped?
2. Check which profile is active - interpolation enabled in HDR causes issues
3. Check `gpu-api` - should be "vulkan" for Nvidia+Wayland
4. Check `gpu-context` - should be "waylandvk"
5. Check `hwdec` - should be "nvdec"
6. Check `hdr-compute-peak` - should be "no" on Nvidia
7. Check for vsync issues: `print(mp.get_property("vsync-ratio"))`

### No audio or wrong channels
1. Check channel count: `print(mp.get_property("audio-params/channel-count"))`
2. If >= 5, downmix profiles should fire - verify with `print(mp.get_property("af"))`
3. Check audio device: `print(mp.get_property("audio-device"))` - should be pipewire
4. Check volume: `print(mp.get_property("volume"))` - max is 100 unless downmix active
5. Check PipeWire status: `pw-cli info | grep -i mpv`

### Interpolation artifacts
1. Check which profile is active - hdr-passthrough sets interpolation=no
2. If in HDR mode, interpolation is intentionally off (video-sync=audio mode)
3. Toggle with `g` key to see if artifacts are interpolation-related
4. sdr-native uses tscale=oversample (best quality but high GPU cost)

### Subtitles wrong timing or position
1. `sub-fix-timing=yes` - mpv will attempt to fix common timing issues
2. Check which sub track is active: `print(mp.get_property("track-list/sid/0/codec"))`
3. For ASS overrides: `sub-ass-override=force` - can break some ASS position calculations
4. Run autosubsync manually: `script-binding autosubsync/autosubsync-current`
5. For encoding issues: `sub-codepage=cp1256` only covers Arabic ANSI - UTF-8 files should work without it

### Config changes not applying
1. Check syntax: `mpv --no-config --script-opts= --load-scripts=no /tmp/test.mkv --no-config-file` doesn't help, instead use `mpv --config-dir=~/.config/mpv --no-config-file` to test isolated
2. Watch for Lua errors in terminal output
3. Check option spelling - mpv silently ignores unknown options
4. `profile-restore=copy-equal` may reset options you didn't expect

---
