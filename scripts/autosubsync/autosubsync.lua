-- Usage:
--  default keybinding: n
--  add the following to your input.conf to change the default keybinding:
--  keyname script_binding autosubsync-menu

local mp = require('mp')
local utils = require('mp.utils')
local mpopt = require('mp.options')
local menu = require('menu')
local sub = require('subtitle')
local h = require('helpers')
local ref_selector
local engine_selector
local track_selector
-- Forward declarations: sync_subtitles (line ~275) references these but
-- their `local function` definitions come later. Without these, the
-- compiler treats the references as global and the call fails at runtime
-- with "attempt to call global 'get_embedded_refs' (a nil value)".
local get_embedded_refs
local pick_best_embedded_ref
local dialogue_only_ass
local count_dialogue_cues
local count_cues
local show_marked_slow
local mark_show_slow
local prefetch_next
local prefetch_pending
local read_ref_manifest

-- Config
-- Options can be changed here or in a separate config file.
-- Config path: ~/.config/mpv/script-opts/autosubsync.conf
local config = {
    -- Change the following lines if the locations of executables differ from the defaults
    -- If set to empty, the path will be guessed.
    ffmpeg_path = "",
    ffsubsync_path = "",
    alass_path = "",

    -- Choose what tool to use. Allowed options: ffsubsync, alass, ask.
    -- If set to ask, the add-on will ask to choose the tool every time.
    audio_subsync_tool = "ask",
    altsub_subsync_tool = "ask",

    -- After retiming, tell mpv to forget the original subtitle track.
    unload_old_sub = true,

    -- Overwrite the original subtitle file
    overwrite_old_sub = false,

    -- Automatically sync a newly loaded external subtitle (no keypress).
    auto_sync_on_load = true,
    -- On-load: when no show transform is cached yet, establish the reliable
    -- one. The audio VAD path is only reached when the file has no embedded
    -- text sub (PGS / image-based) -- for text-subbed remuxes sync_subtitles
    -- feeds ffsubsync the cached embedded sub instead (sub-to-sub, instant).
    -- Guarded by auto_sync_audio + audio_is_cheap so a long lossless 4K track
    -- (a multi-minute decode) doesn't get auto-VAD'd when it does run.
    auto_sync_audio = true,
    -- On-load: skip auto-sync if the best embedded sub has fewer cues than
    -- this (a signs/songs track is too sparse to be a reliable reference).
    auto_sync_min_cues = 100,
    -- Strip signs/songs/OP/ED/title-card cues from the .ass reference before
    -- passing it to ffsubsync. Anime "forced" tracks mix the dialogue
    -- ("Default" style) with dozens of typewriter title-card cues and OP/ED
    -- karaoke flows; ffsubsync turns every Dialogue cue into a speech-activity
    -- blip, so a cluster of 0.25s "P"/"Pre"/"Prese" cues at t=1.85s poisons
    -- the alignment and the matched offset can be off by tens of seconds.
    -- Off = pass the full .ass through (old behaviour).
    dialogue_only_filter = true,
    -- ffsubsync --max-offset-seconds. Default 60 -- far too tight for
    -- release-cut differences (coalgirls BD adds a 2-min recap that an
    -- Arabic SubDL sub doesn't have -> true offset +120s). 600s = 10 min
    -- covers recap/Cold-open shifts but rejects garbage far-match anchors.
    ffsubsync_max_offset = 600,
    -- Seconds to wait after a subtitle is selected before auto-syncing, so
    -- the loader (e.g. ar_subs) finishes adding tracks first.
    auto_sync_delay = 0.7,
    -- Cache the computed offset+framerate per show folder and reuse it for
    -- every episode (applying it is instant). First episode of a show computes
    -- it; the rest reuse it. Press n to recompute for the current show.
    cache_show_transform = true,
    -- Dynamic sync window. Extraction (ffmpeg -t) and the audio VAD fallback
    -- (ffsubsync --max-duration-seconds) read only the first N seconds of
    -- the file, N = the smallest step of a 120/180/300/450/600/900s ladder
    -- holding this many dialogue cues of the ACTIVE subtitle (its cue
    -- density approximates where the speech is). Dense shows land on a small
    -- window -- cold NFS traversal scales with the window, so a dense 24-min
    -- episode extracts in a few seconds instead of ~20. A sub too sparse to
    -- reach the target anywhere on the ladder falls back to the full file
    -- (sparse signal needs all of it). Alignment failures on a windowed ref
    -- auto-retry once against the full extraction.
    sync_window_target_cues = 100,
    -- A sub too sparse for the ladder (or a show whose MKV interleaves subs
    -- late in the file) falls back to BOUNDED AUDIO VAD on a window this
    -- many seconds long instead of traversing the file for a thin subtitle
    -- reference. Audio packets are densely interleaved, so the read stays
    -- proportional to the window even on badly-muxed files.
    sync_window_sparse_cap = 900,
    -- Sub extraction slower than this (seconds) marks the SHOW (directory)
    -- as slow: later episodes of the same show go audio-first immediately
    -- instead of paying the interleaving-lag traversal again.
    slow_show_extraction_seconds = 8,
    -- While an episode plays, extract the embedded refs of the NEXT episode
    -- in the same folder in the background (niced), so its first-play sync
    -- is instant. Costs background I/O during playback; the read is niced
    -- and only runs once per next-episode.
    prefetch_next_episode = true,
}
mpopt.read_options(config, 'autosubsync')

-- Snippet borrowed from stackoverflow to get the operating system
-- originally found at: https://stackoverflow.com/a/30960054
local os_name = (function()
    if os.getenv("HOME") == nil then
        return function()
            return "Windows"
        end
    else
        return function()
            return "*nix"
        end
    end
end)()

local os_temp = (function()
    if os_name() == "Windows" then
        return function()
            return os.getenv('TEMP')
        end
    else
        return function()
            return '/tmp/'
        end
    end
end)()

local function notify(message, level, duration)
    level = level or 'info'
    duration = duration or 1
    mp.msg[level](message)
    mp.osd_message(message, duration)
end

local function subprocess(args)
    return mp.command_native {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = args
    }
end

-- All autosubsync state lives under the ar_subs cache root (one directory
-- for the whole Arabic-subtitle workflow: downloads, retimed files, refs,
-- transforms, slow-show marks).
local CACHE_BASE = (os.getenv("HOME") or "/tmp") .. "/.cache/ar_subs/autosubsync"

-- Per-video cache dir (keyed by path+size+mtime) for extracted references and
-- serialized speech. Defined early because sync_subtitles uses it for the
-- audio-speech cache.
local REF_CACHE_DIR = CACHE_BASE .. "/refs"

local function djb2_hex(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 0x100000000
    end
    return string.format("%08x", h)
end

local function video_ref_dir()
    local path = mp.get_property("path") or ""
    local info = utils.file_info(path)
    local size = info and info.size or 0
    local mtime = info and info.mtime or 0
    return REF_CACHE_DIR .. "/" .. djb2_hex(path .. "|" .. size .. "|" .. mtime)
end

-- Per-episode sync-transform cache. SubDL returns a DIFFERENT Arabic sub
-- release per episode (Lain E01 = coalgirls-720p-sub, E07 = coalgirls-1080p
-- sub from a different SubDL author; Deadman E01 = "s.t.s" E02-04 = "sts
-- horrible"; the offsets of these subs against their episodes are
-- independent -- Lain E01 needed +0.72s while E07 needed +119.62s against
-- the same coalgirls BD). Caching the FIRST episode's offset and reusing
-- it on later episodes silently mistimes them.
--
-- So: key the cache on the video file's identity (path+size+mtime -- same
-- hash as video_ref_dir, so a cache-cleared-file's transform disappears
-- alongside its extracted refs). First play of each episode pays the ~1s
-- extract+ffsubsync cost; subsequent plays of the SAME file are instant
-- (pure offset+scale string math -- no extraction / no ffsubsync).
local TRANSFORM_DIR = CACHE_BASE .. "/transforms"

local function episode_key()
    -- Same identity hashing as video_ref_dir (path|size|mtime) so that
    -- touching/moving/replacing the file invalidates the cache and the
    -- extracted refs together.
    local path = mp.get_property("path") or ""
    local info = utils.file_info(path)
    local size = info and info.size or 0
    local mtime = info and info.mtime or 0
    return djb2_hex(path .. "|" .. size .. "|" .. mtime)
end

local function load_show_transform()
    if not config.cache_show_transform then return nil end
    local f = io.open(TRANSFORM_DIR .. "/" .. episode_key() .. ".json", "r")
    if not f then return nil end
    local raw = f:read("*a"); f:close()
    local t = utils.parse_json(raw)
    if type(t) ~= "table" or type(t.offset) ~= "number" then return nil end
    if type(t.scale) ~= "number" then t.scale = 1.0 end
    -- Tie the cache to the retimed file it produced: if the user wipes the
    -- subdl cache (rm -rf .cache/ar_subs) the retimed is gone too, and the
    -- cached offset+scale would silently reapply a stale transform on the
    -- next play. Reject the entry so the next run recomputes from scratch.
    if type(t.retimed) == "string" and not utils.file_info(t.retimed) then
        mp.msg.info("autosubsync: cached episode transform's retimed is gone (" ..
            t.retimed .. "), invalidating cache")
        return nil
    end
    return t
end

local function save_show_transform(offset, scale, retimed_path)
    if not config.cache_show_transform or type(offset) ~= "number" then return end
    -- A subtitle-derived framerate scale can be wildly wrong on sparse refs
    -- (e.g. 1.186 for Lain's signs sub). Only trust it inside a plausible
    -- framerate band (covers real PAL 25/24 ~= 1.042); otherwise keep the
    -- offset but apply no stretch rather than distort every episode.
    if type(scale) ~= "number" or scale < 0.90 or scale > 1.10 then
        scale = 1.0
    end
    subprocess({ "mkdir", "-p", TRANSFORM_DIR })
    local f = io.open(TRANSFORM_DIR .. "/" .. episode_key() .. ".json", "w")
    if f then
        f:write(utils.format_json({
            offset = offset,
            scale = scale,
            retimed = retimed_path or false,
        }))
        f:close()
    end
end

local function parse_ffsubsync_transform(stdout)
    local clean = (stdout or ""):gsub("\27%[[%d;]*m", ""):gsub("\27%][^\7]*\7", "")
    local offset = tonumber(clean:match("offset seconds:%s*([%-%d%.]+)"))
    local scale = tonumber(clean:match("framerate scale factor:%s*([%-%d%.]+)"))
    return offset, scale
end

local url_decode = function(url)
    local function hex_to_char(x)
        return string.char(tonumber(x, 16))
    end
    if url ~= nil then
        url = url:gsub("^file://", "")
        url = url:gsub("+", " ")
        url = url:gsub("%%(%x%x)", hex_to_char)
        return url
    else
        return
    end
end

local function get_loaded_tracks(track_type)
    local result = {}
    local track_list = mp.get_property_native('track-list')
    for _, track in pairs(track_list) do
        if track.type == track_type then
            track['external-filename'] = track.external and url_decode(track['external-filename'])
            table.insert(result, track)
        end
    end
    return result
end

local function get_active_track(track_type)
    local track_list = mp.get_property_native('track-list')
    for num, track in ipairs(track_list) do
        if track.type == track_type and track.selected == true then
            if track.external and not h.file_exists(track['external-filename']) then
                track['external-filename'] = url_decode(track['external-filename'])
            end
            if not (track_type == 'sub' and track.id == mp.get_property_native('secondary-sid')) then
                return num, track
            end
        end
    end
    return notify(string.format("Error: no track of type '%s' selected", track_type), "error", 3)
end

-- Dynamic sync window: the smallest amount of the file alignment needs.
-- Window candidates in seconds -- stepped, so a dense episode pays for a
-- small read and a sparse one grows toward the full file. Cross-correlation
-- locks on with ~100 dialogue cues; past that, extra reference is wasted
-- traversal (a 300s window on a 1400s episode reads ~21% of the clusters).
local WINDOW_LADDER = { 120, 180, 300, 450, 600, 900 }

-- Start time (seconds) of every cue in an .srt/.ass, scanned line-by-line
-- without a full parse. SRT: the first HH:MM:SS on a "-->" line (the end
-- stamp on the same line is not matched -- match() takes the first hit).
-- ASS: field 2 of each Dialogue line.
local function cue_start_times(path)
    local times = {}
    local f = io.open(path, "r")
    if not f then return times end
    local is_ass = path:lower():sub(-4) == ".ass"
    for line in f:lines() do
        local h, m, s
        if is_ass then
            if line:sub(1, 9) == "Dialogue:" then
                local rest = line:sub(10)
                local c = rest:find(",", 1, true)
                if c then
                    h, m, s = rest:sub(c + 1):match("^(%d+):(%d+):(%d+)")
                end
            end
        else
            h, m, s = line:match("(%d%d):(%d%d):(%d%d)[,%.]")
        end
        if h then times[#times + 1] = h * 3600 + m * 60 + s end
    end
    f:close()
    return times
end

-- Smallest window (seconds) whose [0, D] holds >= target_cues cues of the
-- active sub. Falls back to the full duration when even the whole file
-- can't reach the target (a sparse sub needs every cue it can get), and to
-- a bounded 600s default when there's no external sub timeline to judge by
-- (the old fixed cap). Never below the first ladder step (120s) so the
-- OP/cold-open is inside the window even when dialogue starts late.
local function dynamic_sync_window(target_cues)
    local total = tonumber(mp.get_property("duration")) or 0
    local _, active = get_active_track('sub')
    local path = active and active.external and (url_decode(active['external-filename'] or '') or '') or ''
    local times = (path ~= '' and utils.file_info(path)) and cue_start_times(path) or {}
    if #times == 0 then return ((total > 0 and total < 600) and total or 600), false end
    table.sort(times)
    local cap = tonumber(config.sync_window_sparse_cap) or WINDOW_LADDER[#WINDOW_LADDER]
    for _, D in ipairs(WINDOW_LADDER) do
        if (total > 0 and D >= total) or D > cap then break end
        local n = 0
        for _, t in ipairs(times) do
            if t <= D then n = n + 1 else break end
        end
        if n >= target_cues then
            mp.msg.info(string.format(
                "autosubsync: sync window %ds (%d/%d sub cues in [0,%ds]; episode %.0fs)",
                D, n, #times, D, total))
            return D, false
        end
    end
    -- Sparse: no ladder step reaches the target. A sparse cue train is also
    -- a WEAK alignment reference, so callers use bounded audio VAD (a far
    -- denser speech signal) on this window instead of paying a traversal
    -- for a thin embedded-sub reference.
    local w = (total > 0 and total < cap) and total or cap
    mp.msg.info(string.format(
        "autosubsync: sparse sub (%d cues total, < %d within %ds); bounded %ds audio window",
        #times, target_cues, cap, math.floor(w)))
    return w, true
end

local function remove_extension(filename)
    return filename:gsub('%.%w+$', '')
end

local function get_extension(filename)
    return filename:match("^.+(%.%w+)$")
end

local function startswith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

local function mkfp_retimed(sub_path)
    if config.overwrite_old_sub then
        return sub_path
    end
    local base_stem, ext
    if not startswith(sub_path, os_temp()) then
        base_stem, ext = remove_extension(sub_path), get_extension(sub_path)
    else
        base_stem, ext = remove_extension(mp.get_property("path")), get_extension(sub_path)
    end
    -- don't stack suffixes when re-syncing an already-retimed file
    base_stem = base_stem:gsub('_retimed$', '')
    return table.concat { base_stem, '_retimed', ext }
end

local function engine_is_set()
    local subsync_tool = ref_selector:get_subsync_tool()
    if h.is_empty(subsync_tool) or subsync_tool == "ask" then
        return false
    else
        return true
    end
end

local function extract_to_file(subtitle_track)
    local codec_ext_map = { subrip = "srt", ass = "ass" }
    local ext = codec_ext_map[subtitle_track['codec']]
    if ext == nil then
        return notify(string.format("Error: unsupported codec: %s", subtitle_track['codec']), "error", 3)
    end
    local temp_sub_fp = utils.join_path(os_temp(), 'autosubsync_extracted.' .. ext)
    notify("Extracting internal subtitles...", nil, 3)
    local ret = subprocess {
        config.ffmpeg_path,
        "-hide_banner",
        "-nostdin",
        "-y",
        "-loglevel", "quiet",
        "-an",
        "-vn",
        "-i", mp.get_property("path"),
        "-map", "0:" .. (subtitle_track and subtitle_track['ff-index'] or 's'),
        "-f", ext,
        temp_sub_fp
    }
    if ret == nil or ret.status ~= 0 or not h.file_exists(temp_sub_fp) then
        return notify("Couldn't extract internal subtitle.\nMake sure the video has internal subtitles.", "error", 7)
    end
    return temp_sub_fp
end

local function sync_subtitles(ref_sub_path, force_engine)
    local reference_file_path = ref_sub_path or mp.get_property("path")
    local _, sub_track = get_active_track('sub')
    if sub_track == nil then
        return
    end
    local subtitle_path = sub_track.external and sub_track['external-filename'] or extract_to_file(sub_track)
    local engine_name = force_engine or engine_selector:get_engine_name()
    local engine_path = config[engine_name .. '_path']

    if h.is_path(config.ffmpeg_path) and not h.file_exists(engine_path) then
        return notify(
                string.format("Can't find %s executable.\nPlease specify the correct path in the config.", engine_name),
                "error",
                5
        )
    end

    if not h.file_exists(subtitle_path) then
        return notify(
                table.concat {
                    "Subtitle synchronization failed:\nCouldn't find ",
                    subtitle_path or "external subtitle file."
                },
                "error",
                3
        )
    end

    local retimed_subtitle_path = mkfp_retimed(subtitle_path)

    notify(string.format("Starting %s...", engine_name), nil, 2)

    local ret
    -- Set by the plausibility gate (inside the ffsubsync branch) when the
    -- alignment is rejected; checked after BOTH branches, so it must be
    -- scoped here -- a local inside the branch is invisible outside it and
    -- the `not rejected` check silently reads a nil global.
    local rejected = false
    if engine_name == "ffsubsync" then
        local ref = reference_file_path
        local extra = {}
        -- Set when the reference came from a WINDOWED extraction; if the
        -- alignment fails on it we get one retry against the full file.
        local windowed_embedded = false
        -- Set when the final reference is a subtitle (vs audio VAD): only
        -- subtitle-derived transforms get the plausibility check, since
        -- audio VAD is the ground truth and never needs rescuing.
        local sub_to_sub_ref = false
        local active, window, sparse
        local total
        -- Audio VAD reference for a window: the cached serialized speech
        -- (.npz, instant reuse) if present, else a symlinked video plus the
        -- bounded-decode flags. Returns ref, extra_args.
        local function audio_ref_args(win)
            local dir2 = video_ref_dir()
            local npz = dir2 .. "/video_" .. math.floor(win) .. ".npz"
            if utils.file_info(npz) then return npz, {} end
            local link = dir2 .. "/video.mkv"
            subprocess({ "ln", "-sf", reference_file_path, link })
            -- --reference-stream takes an ffmpeg stream specifier: "0:N" is
            -- the 0-based GLOBAL stream index == mpv's ff-index (the
            -- track-list position is off by one and would reference the
            -- stream AFTER the selected audio).
            local _, atr = get_active_track('audio')
            return link, { "--serialize-speech",
                "--reference-stream", "0:" .. (atr and atr['ff-index'] or 0),
                "--max-duration-seconds", string.format("%d", math.floor(win)) }
        end
        -- (max_time, n_cues, n_cues_past_limit) of the retimed file.
        local function retimed_stats(limit)
            local maxt, n, past = 0, 0, 0
            local f = io.open(retimed_subtitle_path, "r")
            if not f then return nil, 0, 0 end
            for line in f:lines() do
                local h, m, s, frac
                if line:sub(1, 9) == "Dialogue:" then
                    local rest = line:sub(10)
                    local c = rest:find(",", 1, true)
                    if c then
                        local r2 = rest:sub(c + 1)
                        local c2 = r2:find(",", 1, true)
                        if c2 then
                            h, m, s, frac = r2:sub(c2 + 1):match("^(%d+):(%d+):(%d+)%.(%d+)")
                            if frac then frac = frac / 100 end
                        end
                    end
                else
                    h, m, s, frac = line:match("(%d%d):(%d%d):(%d%d)[,%.](%d%d%d)")
                    if frac then frac = frac / 1000 end
                end
                if h then
                    local t = h * 3600 + m * 60 + s + frac
                    n = n + 1
                    if t > maxt then maxt = t end
                    if limit and t > limit then past = past + 1 end
                end
            end
            f:close()
            return maxt, n, past
        end

        -- A correct global transform keeps (nearly) every cue inside the
        -- media: a few ED/credits cues may trail the video end, but a
        -- wrong-release alignment dumps a large fraction past it (measured:
        -- wrong-episode sub -> +425.94s/1.043, exit code 0, ~30% of cues
        -- past EOF -- "successful" garbage). Reject when the tail runs far
        -- past the media AND a substantial fraction of cues is past it.
        local function implausible_alignment()
            local dur = tonumber(mp.get_property("duration")) or 0
            if dur <= 0 then return false end
            local maxt, n, past = retimed_stats(dur + 5)
            if not maxt or n < 10 then return false end
            return maxt > dur + 30 and past / n > 0.15
        end
        if not ref_sub_path then
            -- No explicit reference: prefer the best embedded text sub as
            -- the ffsubsync reference (sub-to-sub) over audio VAD. Falls
            -- back to audio only when no usable text sub exists (PGS /
            -- image-based) -- the .npz is cached per video AND window. The
            -- cue gate uses auto_sync_min_cues so very sparse refs
            -- (signs/songs-only) still get the reliable audio path.
            local dir = video_ref_dir()
            subprocess({ "mkdir", "-p", dir })

            -- Read only as much of the file as alignment needs: the window
            -- is the smallest ladder step holding enough dialogue cues of
            -- the active sub (cold traversal scales with the window).
            window, sparse = dynamic_sync_window(
                    math.max(config.sync_window_target_cues, config.auto_sync_min_cues))
            if not sparse and show_marked_slow() then
                -- A previous episode of this show took > slow_show_extraction_
                -- seconds to extract: its MKV interleaves subtitle packets
                -- late in the file, so even a bounded sub extraction
                -- traverses most of it. Audio packets are densely
                -- interleaved, so bounded audio VAD is the cheaper AND
                -- denser reference for this show.
                mp.msg.info("autosubsync: show extracts slowly (bad MKV interleaving); audio-first")
                sparse = true
            end
            total = tonumber(mp.get_property("duration")) or 0
            active = select(2, get_active_track('sub'))
            local best
            if not sparse then
                local t0 = mp.get_time()
                local refs = get_embedded_refs(active and active.id or nil, window)
                if mp.get_time() - t0 > config.slow_show_extraction_seconds then
                    mark_show_slow()
                end
                best = pick_best_embedded_ref(refs)
            elseif read_ref_manifest(video_ref_dir()) then
                -- Audio-first for this show -- but refs already on disk
                -- (prefetched during the previous episode) cost nothing:
                -- sub-to-sub is still the instant path.
                local refs = get_embedded_refs(active and active.id or nil, window)
                best = pick_best_embedded_ref(refs)
            end
            if best and best.cues >= config.auto_sync_min_cues then
                ref = dialogue_only_ass(best.path)
                sub_to_sub_ref = true
                windowed_embedded = total > 0 and window < total - 1
                notify(string.format("using embedded sub ref: %s (%d cues)", ref, best.cues), "info", 1)
                if ref ~= best.path then
                    notify(string.format("Stripped signs/songs from ref (%d -> %d cues)",
                            count_cues(best.path), count_dialogue_cues(ref)), "info", 3)
                end
            else
                local aref, aextra = audio_ref_args(window)
                ref = aref
                for _, a in ipairs(aextra) do table.insert(extra, a) end
            end
        end
        local function run(ref_path, extra_args)
            local args = { config.ffsubsync_path, ref_path, "-i", subtitle_path, "-o", retimed_subtitle_path }
            -- ffsubsync's default --max-offset-seconds is 60 -- far too tight
            -- for release-cut mismatches (a SubDL Arabic sub vs the coalgirls
            -- BD that opens with a 2-minute recap: true alignment +120s).
            -- 600s covers recap/OP shifts but rejects wrong-language anchors.
            table.insert(args, "--max-offset-seconds"); table.insert(args, tostring(config.ffsubsync_max_offset))
            for _, a in ipairs(extra_args) do table.insert(args, a) end
            return subprocess(args)
        end
        ret = run(ref, extra)
        if windowed_embedded and (ret == nil or ret.status ~= 0) then
            -- The window holds enough cues by construction, so failure here
            -- is unusual; retry once against the full extraction before
            -- giving up (the manifest wipe forces a windowless re-extract).
            notify("Windowed sync failed; retrying with the full file...", "warn", 3)
            os.remove(video_ref_dir() .. "/manifest.json")
            local refs2 = get_embedded_refs(active and active.id or nil, nil)
            local best2 = pick_best_embedded_ref(refs2)
            if best2 and best2.cues >= config.auto_sync_min_cues then
                ret = run(dialogue_only_ass(best2.path), {})
            end
        end
        -- Plausibility gate (see implausible_alignment). Sub-to-sub results
        -- get one rescue via bounded audio VAD; if the audio result is
        -- ALSO implausible the subtitle release itself doesn't match this
        -- file (wrong episode / wrong cut) -- refuse to load it rather
        -- than caching+loading garbage.
        if ret ~= nil and ret.status == 0 and implausible_alignment() then
            if sub_to_sub_ref then
                notify("Sub-to-sub alignment implausible; audio rescue...", "warn", 3)
                local aref, aextra = audio_ref_args(window or 600)
                ret = run(aref, aextra)
                sub_to_sub_ref = false
            end
            if ret ~= nil and ret.status == 0 and implausible_alignment() then
                rejected = true
            end
        end
    else
        ret = subprocess { config.alass_path, reference_file_path, subtitle_path, retimed_subtitle_path }
    end

    if ret == nil then
        return notify("Parsing failed or no args passed.", "fatal", 3)
    end

    if ret.status == 0 and not rejected then
        -- Cache the offset+framerate so the rest of this show's episodes can
        -- reuse it instantly (only ffsubsync reports a clean global transform).
        if engine_name == "ffsubsync" then
            -- ffsubsync logs its result to stderr, not stdout
            local offset, scale = parse_ffsubsync_transform(
                    (ret.stdout or "") .. "\n" .. (ret.stderr or ""))
            if offset then save_show_transform(offset, scale, retimed_subtitle_path) end
        end
        local old_sid = mp.get_property("sid")
        if mp.commandv("sub_add", retimed_subtitle_path) then
            notify("Subtitle synchronized.", nil, 2)
            mp.set_property("sub-delay", 0)
            if config.unload_old_sub then
                mp.commandv("sub_remove", old_sid)
            end
            if config.prefetch_next_episode and not prefetch_pending then
                prefetch_pending = true
                mp.add_timeout(10, prefetch_next)
            end
        else
            notify("Error: couldn't add synchronized subtitle.", "error", 3)
        end
    elseif rejected then
        os.remove(retimed_subtitle_path)
        notify("Alignment implausible (cues run past end of media): this subtitle release doesn't match the file. Not loading it.", "error", 6)
    else
        notify("Subtitle synchronization failed.", "error", 3)
    end
end

local function sync_to_subtitle()
    local selected_track = track_selector:get_selected_track()

    if selected_track and selected_track.external then
        sync_subtitles(selected_track['external-filename'])
    else
        if h.is_path(config.ffmpeg_path) and not h.file_exists(config.ffmpeg_path) then
            return notify("Can't find ffmpeg executable.\nPlease specify the correct path in the config.", "error", 5)
        end
        local temp_sub_fp = extract_to_file(selected_track)
        if temp_sub_fp then
            sync_subtitles(temp_sub_fp)
            os.remove(temp_sub_fp)
        end
    end
end

local function sync_to_manual_offset()
    local _, track = get_active_track('sub')
    local sub_delay = tonumber(mp.get_property("sub-delay"))
    if tonumber(sub_delay) == 0 then
        return notify("There were no manual timings set, nothing to do!", "error", 7)
    end
    local file_path = track.external and track['external-filename'] or extract_to_file(track)
    if file_path == nil then
        return
    end

    local ext = get_extension(file_path)
    local codec_parser_map = { ass = sub.ASS, subrip = sub.SRT }
    local parser = codec_parser_map[track['codec']]
    if parser == nil then
        return notify(string.format("Error: unsupported codec: %s", track['codec']), "error", 3)
    end
    local s = parser:populate(file_path)
    s:shift_timing(sub_delay)
    if track.external == false then
        os.remove(file_path)
        s.filename = mp.get_property("filename/no-ext") .. "_manual_timing" .. ext
    else
        s.filename = remove_extension(s.filename) .. '_manual_timing' .. ext
    end
    s:save()
    mp.commandv("sub_add", s.filename)
    if config.unload_old_sub then
        mp.commandv("sub_remove", track.id)
    end
    mp.set_property("sub-delay", 0)
    return notify(string.format("Manual timings saved, loading '%s'", s.filename), "info", 7)
end

------------------------------------------------------------
-- Automatic sync: prefer an embedded TEXT subtitle as the reference (fast,
-- no audio/video decode, low RAM even on huge remuxes); only fall back to
-- audio when the file has no usable embedded text subtitle.

-- Text subtitle codecs extract_to_file can turn into a reference (bitmap
-- subs like PGS/DVD are image-based and unusable for text alignment).
local TEXT_SUB_CODECS = { subrip = true, ass = true }

-- Count dialogue cues in an .ass/.srt to judge how "full" a subtitle is.
count_cues = function(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        if line:find("^Dialogue:", 1) or line:match("^%d+%s*$") then n = n + 1 end
    end
    f:close()
    return n
end

-- ASS style-name prefix that marks a style as signs/songs/OP/ED/title-card
-- (everything that is NOT spoken dialogue). Anime "forced" tracks mix
-- "Default" (real dialogue) with "Time"/"Time Shadow" (the typewriter
-- title-card effect), "OPL"/"OPR"/"ED English"/"ED Japanese" (OP/ED lyrics)
-- and "Sign"/"Signs". Uses PREFIX match (case-insensitive) on the first
-- non-separator token, so "ED English", "Time Shadow", "OP-Romaji",
-- "Signs", "Titles" all get caught, while "Default", "Alternate",
-- "Main", "Subtitle" pass through.
--
-- "english" prefix catches SGKK/Commie releases that name the OP/ED
-- English-translated karaoke style "ENGLISH" (cues typically use
-- {\blur3\fad(250,250)} / {\fad(...)} effects -- dead-giveaway of song).
-- Acceptable trade-off: a release that genuinely uses a style named
-- "English Dialogue" for spoken dialogue would lose those; rare vs. the
-- OP/ED-leak hazard.
local SIGN_PREFIXES = {
    "op", "ed", "opl", "opr",
    "time", "sign", "title", "banner",
    "ts", "typeset",
    "karaoke", "song",
    "epi", "eyecatch", "neon",
    "splash", "headline", "instruct",
    "picture", "abandoned",
    "nextep", "next", "preview",
    "english", "eng", "romaji",
}

local function is_dialogue_style(name)
    if not name then return true end
    -- lowercase + strip leading separators (space/dash/punct), then take
    -- the first token delimited by space/dash/underscore.
    local lc = name:lower():gsub("^[%s%p]+", "")
    local first = lc:match("([^%s%-_]+)") or ""
    for _, p in ipairs(SIGN_PREFIXES) do
        if first:sub(1, #p) == p then return false end
    end
    return true
end

-- Pull the Style field (4th comma-separated field, "Dialogue: Marked,Start,
-- End,Style,...") out of one .ass Dialogue line. Returns "" / nil if the
-- line is malformed.
local function ass_style_of_line(line)
    -- the prefix "Dialogue:" with its trailing comma is field 0; fields after
    -- it are 1=Marked/Layer, 2=Start, 3=End, 4=Style
    local rest = line:sub(("Dialogue:"):len() + 1)
    local r = rest
    for _ = 1, 3 do
        local c = r:find(",", 1, true)
        if not c then return nil end
        r = r:sub(c + 1)
    end
    local c = r:find(",", 1, true)
    return c and r:sub(1, c - 1) or r
end

-- For .ass: count cues whose style is dialogue-class (strip signs/songs/OP/
-- ED/title-card). For .srt (or unrecognized): count every line. Used by
-- extract_all_refs so we size a sub up by its DIALOGUE density -- Lain's
-- "default forced" track is 286 cues total but only 201 dialogue; the other
-- 85 are the typewriter title-card + OP + ED.
count_dialogue_cues = function(path)
    local lowered = path:lower()
    if lowered:sub(-4) ~= ".ass" then return count_cues(path) end
    local f = io.open(path, "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        if line:sub(1, 9) == "Dialogue:" then
            if is_dialogue_style(ass_style_of_line(line) or "") then n = n + 1 end
        end
    end
    f:close()
    return n
end

-- Write a filtered copy of an .ass keeping only dialogue-style Dialogue lines
-- (the [V4+ Styles]/[Events]/comments headers are preserved). Returns the
-- filtered path, or the original path when there's nothing to filter, the file
-- isn't .ass, all cues would be dropped (no dialogue at all -- treat the file
-- as a pure signs/songs track and let ffsubsync fall back if it can), or the
-- filter is disabled. The output sits next to the source at "<base>.dlg.ass"
-- in the cached ref dir so it sticks between runs (it's only ~30 KB).
dialogue_only_ass = function(path)
    if not config.dialogue_only_filter then return path end
    if path:lower():sub(-4) ~= ".ass" then return path end
    local f = io.open(path, "r")
    if not f then return path end
    local out, kept, dropped = {}, 0, 0
    for line in f:lines() do
        if line:sub(1, 9) == "Dialogue:" then
            if is_dialogue_style(ass_style_of_line(line) or "") then
                table.insert(out, line); kept = kept + 1
            else
                dropped = dropped + 1
            end
        else
            table.insert(out, line)
        end
    end
    f:close()
    if dropped == 0 or kept == 0 then return path end
    local dlg = path:sub(1, #path - 4) .. ".dlg.ass"
    local o = io.open(dlg, "w")
    if not o then return path end
    o:write(table.concat(out, "\n")); o:close()
    return dlg
end

-- Reference cache: extracting an embedded subtitle means ffmpeg traverses the
-- (possibly huge, possibly cold-on-NFS) file once. The embedded subs of a given
-- video never change, so extract them ONCE per video (single ffmpeg pass for
-- all tracks) into a cache dir keyed by path+size+mtime, and reuse forever.
-- Re-syncs and replays then cost milliseconds instead of a full file traversal.
local REF_EXT = { subrip = "srt", ass = "ass" }

-- Returns list, covered_window. window 0/absent = full-file coverage (also
-- how the pre-window manifest format -- a bare array -- is interpreted).
-- Assignment form (NOT `local function`): the forward declaration at the
-- top of the file must receive this definition. `local function` would
-- create a NEW local shadowing it, leaving the forward-declared upvalue
-- nil for sync_subtitles' sparse path ("attempt to call a nil value").
read_ref_manifest = function(dir)
    local mf = io.open(dir .. "/manifest.json", "r")
    if not mf then return nil, nil end
    local raw = mf:read("*a"); mf:close()
    local data = utils.parse_json(raw)
    local list, window
    if type(data) == "table" then
        if type(data.tracks) == "table" then
            list, window = data.tracks, data.window
        elseif #data > 0 then
            list = data
        end
    end
    if type(list) ~= "table" or #list == 0 then return nil, nil end
    for _, r in ipairs(list) do
        if not utils.file_info(dir .. "/" .. r.file) then return nil, nil end
    end
    return list, window
end

-- Extract every embedded text subtitle in ONE ffmpeg pass (one traversal of
-- the input, all outputs written together) and cache them with a manifest.
-- window (seconds, optional): extract only cues inside [0, window]. The -t
-- goes per OUTPUT (not before -i: as an INPUT option it is IGNORED when the
-- only mapped streams are subtitles -- the demux traversed the whole file
-- anyway). Per-output -t makes the CLI stop the demux loop once every
-- output reaches the limit, so ffmpeg reads only the clusters covering
-- [0, window] -- cold NFS traversal scales with the window, not the file
-- size (measured: 19.6s full vs 0.1s for a 300s window on a cold episode).
-- nil = full traversal.
local function extract_all_refs(dir, exclude_id, window)
    local tracks = {}
    for _, t in ipairs(get_loaded_tracks('sub')) do
        if (not t.external) and TEXT_SUB_CODECS[t.codec] and t.id ~= exclude_id then
            table.insert(tracks, t)
        end
    end
    if #tracks == 0 then return {} end
    subprocess({ "mkdir", "-p", dir })
    local args = {
        config.ffmpeg_path, "-hide_banner", "-nostdin", "-y", "-loglevel", "quiet",
        "-analyzeduration", "100000", "-probesize", "5000000",
        "-an", "-vn", "-i", mp.get_property("path"),
    }
    for _, t in ipairs(tracks) do
        local ext = REF_EXT[t.codec] or "ass"
        t._ref_file = t.id .. "." .. ext
        table.insert(args, "-map"); table.insert(args, "0:" .. t['ff-index'])
        table.insert(args, "-f"); table.insert(args, ext)
        if window then
            table.insert(args, "-t"); table.insert(args, string.format("%d", math.floor(window)))
        end
        table.insert(args, dir .. "/" .. t._ref_file)
    end
    local ret = subprocess(args)
    if ret == nil or ret.status ~= 0 then return {} end
    local list = {}
    for _, t in ipairs(tracks) do
        if utils.file_info(dir .. "/" .. t._ref_file) then
            table.insert(list, {
                id = t.id, lang = t.lang, codec = t.codec,
                file = t._ref_file, cues = count_dialogue_cues(dir .. "/" .. t._ref_file),
            })
        end
    end
    local mf = io.open(dir .. "/manifest.json", "w")
    if mf then
        mf:write(utils.format_json({ window = window or 0, tracks = list }))
        mf:close()
    end
    return list
end

-- Cached list of embedded reference subs: {id, lang, codec, file, cues, path}.
-- min_window: reuse the cache only if it covers at least this many seconds;
-- otherwise re-extract with that window (a later sync may need a wider one).
get_embedded_refs = function(exclude_id, min_window)
    local dir = video_ref_dir()
    local list, covered = read_ref_manifest(dir)
    if list and min_window and covered and covered > 0 and covered + 1 < min_window then
        mp.msg.info(string.format(
            "autosubsync: cached refs cover %ds; re-extracting for a %ds window",
            covered, min_window))
        list = nil
    end
    list = list or extract_all_refs(dir, exclude_id, min_window)
    for _, r in ipairs(list) do
        r.path = dir .. "/" .. r.file
    end
    return list
end

------------------------------------------------------------
-- Next-episode prefetch: extract the embedded refs of the next file in the
-- same folder in the background while this episode plays, so its first-play
-- sync hits a warm manifest (instant) instead of paying the cold traversal.

-- Episode number = the highest-scoring digit run in the stem, NOT the last:
-- "Lain E07 Society 1080p ... x264" ends in 264. Scoring: an E/e prefix
-- wins outright; width>=4 (years/resolutions), resolutions (NNNp), codec
-- tails (x264) and decimals (FLAC 2.0) are disqualified. Ties go to the
-- later run. Sibling match requires n+1 at the same zero-padded width,
-- digit-delimited so "02" can't match inside "102".
local function episode_number_in(stem)
    local best, best_score
    local idx, pos = 0, 1
    while true do
        local s, e = stem:find("%d+", pos)
        if not s then break end
        idx = idx + 1
        local digits = stem:sub(s, e)
        local pre = s > 1 and stem:sub(s - 1, s - 1) or ""
        local post = stem:sub(e + 1, e + 1)
        local score = idx
        if pre:match("[Ee]") then
            score = score + 1000                    -- E07 episode marker
        elseif pre:match("[%a]") then
            score = -1                              -- S02 season / x264 / [ABC123] CRC
        else
            if #digits >= 4 then score = -1 end                 -- 1998 / 1080
            if post == "p" and #digits >= 3 then score = -1 end -- 1080p
            if post == "." then score = -1 end                  -- "2.0"
        end
        if score > (best_score or -2) then best, best_score = digits, score end
        pos = e + 1
    end
    return best
end

local function next_episode_path()
    local path = mp.get_property("path") or ""
    local dir, name = path:match("^(.*/)([^/]+)$")
    if not dir then return nil end
    local ext = name:match("(%.[^.]+)$") or ""
    local stem = name:sub(1, #name - #ext)
    local num = episode_number_in(stem)
    if not num then return nil end
    local nxt = string.format("%0" .. #num .. "d", tonumber(num) + 1)
    local files = utils.readdir(dir, "files")
    if not files then return nil end
    for _, f in ipairs(files) do
        if f ~= name and f:sub(-#ext) == ext then
            local fstem = f:sub(1, #f - #ext)
            if fstem:match("%f[%d]" .. nxt .. "%f[%D]") then return dir .. f end
        end
    end
    return nil
end

prefetch_next = function()
    prefetch_pending = false
    if not config.prefetch_next_episode then return end
    local nxt = next_episode_path()
    if not nxt then return end
    local info = utils.file_info(nxt)
    if not info then return end
    local dir = REF_CACHE_DIR .. "/" .. djb2_hex(nxt .. "|" .. info.size .. "|" .. info.mtime)
    if read_ref_manifest(dir) then return end
    local ffprobe = config.ffmpeg_path:gsub("ffmpeg$", "ffprobe")
    if not h.file_exists(ffprobe) then ffprobe = "ffprobe" end
    local pr = subprocess({ ffprobe, "-v", "quiet", "-print_format", "json",
        "-show_entries", "stream=index,codec_type,codec_name:stream_tags=language", nxt })
    if pr == nil or pr.status ~= 0 then return end
    local data = utils.parse_json(pr.stdout or "")
    if type(data) ~= "table" or type(data.streams) ~= "table" then return end
    -- Filenames use the per-type subtitle ordinal (1.ass, 2.srt, ...) --
    -- the same scheme extract_all_refs uses via mpv's track.id, so the
    -- manifest written on completion is honored by the next play.
    local args = { "nice", "-n", "19", config.ffmpeg_path, "-hide_banner", "-nostdin",
        "-y", "-loglevel", "quiet", "-analyzeduration", "100000", "-probesize", "5000000",
        "-an", "-vn", "-i", nxt }
    local picks, seq = {}, 0
    for _, s in ipairs(data.streams) do
        local ext = REF_EXT[s.codec_name]
        if s.codec_type == "subtitle" and ext then
            seq = seq + 1
            local file = seq .. "." .. ext
            table.insert(args, "-map"); table.insert(args, "0:" .. s.index)
            table.insert(args, "-f"); table.insert(args, ext)
            table.insert(args, dir .. "/" .. file)
            table.insert(picks, { file = file, id = seq,
                lang = s.tags and s.tags.language, codec = s.codec_name })
        end
    end
    if seq == 0 then return end
    subprocess({ "mkdir", "-p", dir })
    mp.msg.info("autosubsync: prefetching refs for next episode: " .. nxt)
    mp.command_native_async({
        name = "subprocess", playback_only = false,
        capture_stdout = false, capture_stderr = false, args = args,
    }, function(_, ret)
        if type(ret) ~= "table" or ret.status ~= 0 then return end
        local list = {}
        for _, p in ipairs(picks) do
            if utils.file_info(dir .. "/" .. p.file) then
                table.insert(list, { id = p.id, lang = p.lang, codec = p.codec,
                    file = p.file, cues = count_dialogue_cues(dir .. "/" .. p.file) })
            end
        end
        if #list == 0 then return end
        -- window 0 = full coverage -> satisfies any future min_window.
        local mf = io.open(dir .. "/manifest.json", "w")
        if mf then
            mf:write(utils.format_json({ window = 0, tracks = list }))
            mf:close()
        end
        mp.msg.info("autosubsync: prefetched refs ready: " .. nxt)
    end)
end

-- Slow-show tracking: MKVs muxed with subtitle packets physically late in
-- the file defeat windowing -- even a bounded sub extraction traverses most
-- of the file (measured: 20.5s for a 900s window on a 1436s episode). Audio
-- packets are always densely interleaved, so for a show that extracts
-- slowly, bounded audio VAD is the cheaper AND denser reference. The first
-- episode pays the slow extraction once; its wall time marks the show
-- (directory hash) so every later episode goes audio-first immediately.
local SHOW_SLOW_DIR = CACHE_BASE .. "/slow_shows"

local function show_dir_hash()
    local path = mp.get_property("path") or ""
    local dir = path:match("^(.*/)") or path
    return djb2_hex(dir)
end

show_marked_slow = function()
    return utils.file_info(SHOW_SLOW_DIR .. "/" .. show_dir_hash()) ~= nil
end

mark_show_slow = function()
    subprocess({ "mkdir", "-p", SHOW_SLOW_DIR })
    local f = io.open(SHOW_SLOW_DIR .. "/" .. show_dir_hash(), "w")
    if f then
        f:write("sub extraction slow (bad MKV interleaving); audio-first\n")
        f:close()
    end
    mp.msg.info("autosubsync: marked show as slow-extracting; later episodes go audio-first")
end

-- Pick the best reference out of an embedded-subs manifest. Prefers an
-- English track (the usual full-dialogue sub) over other languages -- picking
-- by raw cue count alone can choose e.g. a Chinese track, which aligns Arabic
-- to the wrong language's timing. Shared between the altsub path and the
-- ffsubsync-on-embedded-sub fallback (so ffsubsync can do sub-to-sub matching
-- instead of full audio VAD on the .mkv -- the difference is ~20s of decode
-- vs sub-second).
pick_best_embedded_ref = function(refs)
    if not refs or #refs == 0 then return nil end
    local best = nil
    for _, r in ipairs(refs) do
        if (r.lang or ""):lower():sub(1, 2) == "en" then
            if not best or r.cues > best.cues then best = r end
        end
    end
    if not best then
        best = refs[1]
        for _, r in ipairs(refs) do
            if r.cues > best.cues then best = r end
        end
    end
    return best
end

-- Fast subtitle<->subtitle sync to the best (most-cues) embedded sub. Returns
-- true on a completed sync. If gate_min_cues is set, a too-sparse reference
-- (signs/songs) is rejected (returns false) so the caller can fall back.
local function sync_to_best_embedded(gate_min_cues, exclude_id)
    local _, active = get_active_track('sub')
    if active == nil then return false end
    local refs = get_embedded_refs(exclude_id or active.id,
            dynamic_sync_window(math.max(config.sync_window_target_cues, config.auto_sync_min_cues)))
    local best = pick_best_embedded_ref(refs)
    if not best then return false end
    if gate_min_cues and best.cues < gate_min_cues then
        notify(string.format("Embedded sub too sparse to auto-sync (%d cues); press n for audio.", best.cues), "info", 4)
        return false
    end
    notify(string.format("Syncing to embedded sub #%s (%s, %d cues)...",
            best.id, best.lang or "?", best.cues), nil, 2)
    -- Sub-to-sub sync via config.altsub_subsync_tool (ffsubsync). NOTE: the
    -- transform sync_subtitles caches on success is keyed per EPISODE (file
    -- path+size+mtime), so a subtitle-derived offset is safe here -- each
    -- episode computes its own against its own embedded ref, and only
    -- replays of the SAME file reuse it. (Under the old per-SHOW key this
    -- was garbage: sparse-ref offsets flip sign between episodes, e.g.
    -- E02=+30.56 vs E03=-33.38. Per-episode keying makes that moot.)
    --
    -- Strip signs/songs/OP/ED/title cues from the .ass before handing it to
    -- the syncer. The unfiltered track mixes dialogue with typewriter title-
    -- card cues and OP/ED karaoke flows whose 0.25s micro-cues cluster at the
    -- start and poison sub-to-sub alignment (Lain's "default forced" track is
    -- 286 cues total / 201 dialogue; the 85 noise cues give ffsubsync a
    -- garbage +25.85s offset that no dialogue-only signal would).
    local ref_path = dialogue_only_ass(best.path)
    if ref_path ~= best.path then
        local total = count_cues(best.path)
        notify(string.format("Stripped signs/songs from ref (%d -> %d cues)",
                total, count_dialogue_cues(ref_path)), "info", 3)
    end
    sync_subtitles(ref_path, config.altsub_subsync_tool ~= "ask" and config.altsub_subsync_tool or "alass")
    return true
end

------------------------------------------------------------
-- Apply a cached show transform (offset + framerate scale) directly to the
-- loaded subtitle's timestamps. Pure string math -- no ffsubsync, no file
-- traversal. This is what makes episodes 2..N of a show sync in milliseconds.

local function ass_time_to_sec(t)
    local h, m, s, cs = t:match("(%d+):(%d+):(%d+)%.(%d+)")
    if not h then return nil end
    return h * 3600 + m * 60 + s + cs / 100
end

local function sec_to_ass_time(x)
    if x < 0 then x = 0 end
    -- ASS time is H:MM:SS.cc (centiseconds). The minutes denominator is
    -- 6000 cs/min, not 60000 -- with 60000 the m field was always 0 once
    -- h and s were extracted, leaking 0..599 into the s field and producing
    -- invalid timestamps like "0:00:62.09" for any sub cue that crossed the
    -- 60s mark after a +offset shift. (SRT below uses 60000 because its
    -- input unit is ms, not cs -- the math is right, just different.)
    local cs = math.floor(x * 100 + 0.5)
    local h = math.floor(cs / 360000); cs = cs % 360000
    local m = math.floor(cs / 6000); cs = cs % 6000
    local s = math.floor(cs / 100); cs = cs % 100
    return string.format("%d:%02d:%02d.%02d", h, m, s, cs)
end

local function sec_to_srt_time(x)
    if x < 0 then x = 0 end
    local ms = math.floor(x * 1000 + 0.5)
    local h = math.floor(ms / 3600000); ms = ms % 3600000
    local m = math.floor(ms / 60000); ms = ms % 60000
    local s = math.floor(ms / 1000); ms = ms % 1000
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

-- ASS: "Dialogue: Marked,Start,End,Style,Name,ML,MR,MV,Effect,Text" -- shift
-- fields 2 and 3 (the first 9 commas delimit fields; text may contain commas).
local function transform_ass(content, offset, scale)
    local out = {}
    -- ([^\n]*)\n over content.."\n" yields each line exactly once (the gmatch
    -- pattern "[^\r\n]*" alone also matches every empty position and doubles).
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        if line:sub(1, 9) == "Dialogue:" then
            local parts, rest, ok = {}, line, true
            for i = 1, 9 do
                local c = rest:find(",", 1, true)
                if not c then ok = false; break end
                parts[i] = rest:sub(1, c - 1)
                rest = rest:sub(c + 1)
            end
            if ok then
                local st = ass_time_to_sec(parts[2])
                local en = ass_time_to_sec(parts[3])
                if st and en then
                    parts[2] = sec_to_ass_time(st * scale + offset)
                    parts[3] = sec_to_ass_time(en * scale + offset)
                    line = table.concat(parts, ",") .. "," .. rest
                end
            end
        end
        table.insert(out, line)
    end
    -- drop the single trailing empty line our added "\n" produces
    if out[#out] == "" then out[#out] = nil end
    return table.concat(out, "\n")
end

local function transform_srt(content, offset, scale)
    return (content:gsub("(%d%d):(%d%d):(%d%d)[,%.](%d%d%d)", function(h, m, s, ms)
        local x = (h * 3600 + m * 60 + s + ms / 1000) * scale + offset
        return sec_to_srt_time(x)
    end))
end

-- Set by apply_cached_transform when it succeeds. A late-firing timer (set
-- before the cache was applied) must NOT then run sync_to_best_embedded and
-- have the syncer compound another offset on top of the cached retimed -- we
-- already wrote and loaded the correct retimed, doing it again is always
-- wrong. Declared before apply_cached_transform so the assignment inside it
-- hits this LOCAL (declaring it after made the assignment a global write and
-- left this guard permanently dead).
local just_applied_cache = false

-- Apply the cached show transform to the active external subtitle. Returns true
-- if a retimed sub was produced and loaded.
local function apply_cached_transform()
    local t = load_show_transform()
    if not t then return false end
    local _, active = get_active_track('sub')
    if not active or not active.external then return false end
    local src = url_decode(active['external-filename'] or '') or ''
    if src == '' or src:find('_retimed', 1, true) or not utils.file_info(src) then return false end
    local f = io.open(src, "r")
    if not f then return false end
    local content = f:read("*a"); f:close()
    local ext = get_extension(src) or ".ass"
    local out_content
    if ext == ".srt" then
        out_content = transform_srt(content, t.offset, t.scale)
    else
        out_content = transform_ass(content, t.offset, t.scale)
    end
    local out_path = remove_extension(src) .. "_retimed" .. ext
    local of = io.open(out_path, "w")
    if not of then return false end
    of:write(out_content); of:close()
    notify(string.format("Applying cached show sync (offset %+.2fs, scale %.4f)...",
            t.offset, t.scale), nil, 2)
    local old_sid = mp.get_property("sid")
    if mp.commandv("sub_add", out_path) then
        mp.set_property("sub-delay", 0)
        if config.unload_old_sub then mp.commandv("sub_remove", old_sid) end
        notify("Subtitle synchronized (cached).", nil, 2)
        just_applied_cache = true
        return true
    end
    return false
end

-- Auto-reference sync: let sync_subtitles pick the cheapest viable reference
-- (embedded sub if dense enough, cached .npz, then bounded audio VAD). Kept
-- as a named wrapper so the on-load path can be read at a glance.
local function sync_via_ffsubsync()
    sync_subtitles(nil, config.audio_subsync_tool ~= "ask" and config.audio_subsync_tool or "ffsubsync")
end

-- `n`: force a fresh sync (recompute the show transform), embedded then audio.
local function auto_sync()
    -- An embedded subtitle is already muxed/timed to this video -- syncing it
    -- is pointless (and would retiming a known-good track to a possibly-worse
    -- reference). Only external (downloaded) subs need syncing.
    local _, active = get_active_track('sub')
    if active and not active.external then
        notify("Active subtitle is embedded (already timed); nothing to sync.", "info", 3)
        return
    end
    if not sync_to_best_embedded(nil) then
        sync_via_ffsubsync()
    end
end

-- True when the active audio is cheap to decode (not a long lossless track).
-- Keeps the automatic audio-seed from triggering a multi-minute decode on a
-- long TrueHD/DTS/FLAC 4K file.
local function audio_is_cheap()
    local dur = tonumber(mp.get_property("duration")) or 0
    for _, t in ipairs(mp.get_property_native("track-list")) do
        if t.type == "audio" and t.selected then
            local c = (t.codec or ""):lower()
            local lossless = c:find("truehd") or c:find("dts") or c:find("flac") or c:find("pcm")
            if lossless and dur > 2400 then return false end
            return true
        end
    end
    return true
end

-- On-load auto sync:
--   1. cached show transform present -> apply it (milliseconds, no file access);
--   2. else -> ffsubsync on the best embedded text sub (sub-to-sub, instant;
--      caches the per-show transform; every later episode of the show hits
--      step 1). Falls through to audio VAD only when the file has no embedded
--      text sub (PGS / image-based).
--   3. else (PGS-only) -> ffsubsync on cached or bounded audio VAD (first run
--      is the slow one, every later run on the same file is instant via .npz;
--      --max-duration-seconds caps the first decode at 10 min).
local synced_paths = {}
local auto_timer = nil
local function auto_sync_on_load()
    if just_applied_cache then
        just_applied_cache = false
        return
    end
    if apply_cached_transform() then
        return
    end
    if config.auto_sync_audio and audio_is_cheap() then
        sync_via_ffsubsync()
        return
    end
    sync_to_best_embedded(config.auto_sync_min_cues)
end

local function on_sid_changed()
    if not config.auto_sync_on_load then return end
    local sid = mp.get_property_native('sid')
    if not sid or sid == 0 then return end
    local track
    for _, t in ipairs(mp.get_property_native('track-list')) do
        if t.type == 'sub' and t.id == sid then track = t; break end
    end
    if not track or not track.external then return end
    local path = url_decode(track['external-filename'] or '') or ''
    if path == '' or path:find('_retimed', 1, true) then return end
    if synced_paths[path] then return end
    synced_paths[path] = true
    if auto_timer then auto_timer:kill() end
    auto_timer = mp.add_timeout(config.auto_sync_delay, auto_sync_on_load)
end

------------------------------------------------------------
-- Menu actions & bindings

ref_selector = menu:new {
    items = { 'Sync to audio', 'Sync to another subtitle', 'Save current timings', 'Cancel' },
    last_choice = 'audio',
    pos_x = 50,
    pos_y = 50,
    text_color = 'fff5da',
    border_color = '2f1728',
    active_color = 'ff6b71',
    inactive_color = 'fff5da',
}

function ref_selector:get_keybindings()
    return {
        { key = 'h', fn = function() self:close() end },
        { key = 'j', fn = function() self:down() end },
        { key = 'k', fn = function() self:up() end },
        { key = 'l', fn = function() self:act() end },
        { key = 'down', fn = function() self:down() end },
        { key = 'up', fn = function() self:up() end },
        { key = 'Enter', fn = function() self:act() end },
        { key = 'ESC', fn = function() self:close() end },
        { key = 'n', fn = function() self:close() end },
        { key = 'WHEEL_DOWN', fn = function() self:down() end },
        { key = 'WHEEL_UP', fn = function() self:up() end },
        { key = 'MBTN_LEFT', fn = function() self:act() end },
        { key = 'MBTN_RIGHT', fn = function() self:close() end },
    }
end

function ref_selector:new(o)
    self.__index = self
    o = o or {}
    return setmetatable(o, self)
end

function ref_selector:get_ref()
    if self.selected == 1 then
        return 'audio'
    elseif self.selected == 2 then
        return 'sub'
    else
        return nil
    end
end

function ref_selector:get_subsync_tool()
    if self.selected == 1 then
        return config.audio_subsync_tool
    elseif self.selected == 2 then
        return config.altsub_subsync_tool
    end
end

function ref_selector:act()
    self:close()

    if self.selected == 3 then
        return sync_to_manual_offset()
    end
    if self.selected == 4 then
        return
    end

    engine_selector:init()
end

function ref_selector:call_subsync()
    if self.selected == 1 then
        sync_subtitles()
    elseif self.selected == 2 then
        sync_to_subtitle()
    elseif self.selected == 3 then
        sync_to_manual_offset()
    end
end

function ref_selector:open()
    self.selected = 1
    for _, val in pairs(self:get_keybindings()) do
        mp.add_forced_key_binding(val.key, val.key, val.fn)
    end
    self:draw()
end

function ref_selector:close()
    for _, val in pairs(self:get_keybindings()) do
        mp.remove_key_binding(val.key)
    end
    self:erase()
end


------------------------------------------------------------
-- Engine selector

engine_selector = ref_selector:new {
    items = { 'ffsubsync', 'alass', 'Cancel' },
    last_choice = 'ffsubsync',
}

function engine_selector:init()
    if not engine_is_set() then
        engine_selector:open()
    else
        track_selector:init()
    end
end

function engine_selector:get_engine_name()
    return engine_is_set() and ref_selector:get_subsync_tool() or self.last_choice
end

function engine_selector:act()
    self:close()

    if self.selected == 1 then
        self.last_choice = 'ffsubsync'
    elseif self.selected == 2 then
        self.last_choice = 'alass'
    elseif self.selected == 3 then
        return
    end

    track_selector:init()
end

------------------------------------------------------------
-- Track selector

track_selector = ref_selector:new { }

local function is_supported_format(track)
    local supported_format = true
    if track.external then
        local ext = get_extension(track['external-filename'])
        if ext ~= '.srt' and ext ~= '.ass' then
            supported_format = false
        end
    end
    return supported_format
end

function track_selector:init()
    self.selected = 0

    if ref_selector:get_ref() == 'audio' then
        return ref_selector:call_subsync()
    end

    self.all_sub_tracks = get_loaded_tracks(ref_selector:get_ref())
    self.secondary_sid = mp.get_property_native('secondary-sid')
    self.tracks = {}
    self.items = {}

    for _, track in ipairs(self.all_sub_tracks) do
        if (not track.selected or track.id == self.secondary_sid) and is_supported_format(track) then
            table.insert(self.tracks, track)
            table.insert(
                    self.items,
                    string.format(
                            "%s #%s - %s%s",
                            (track.external and 'External' or 'Internal'),
                            track['id'],
                            (track.lang or (track.title and track.title:gsub('^.*%.', '') or 'unknown')),
                            (track.selected and ' (active)' or '')
                    )
            )
        end
    end

    if #self.items == 0 then
        notify("No supported subtitle tracks found.", "warn", 5)
        return
    end

    table.insert(self.items, "Cancel")
    self:open()
end

function track_selector:get_selected_track()
    if self.selected < 1 then
        return nil
    end
    return self.tracks[self.selected]
end

function track_selector:act()
    self:close()

    if self.selected == #self.items then
        return
    end

    ref_selector:call_subsync()
end

------------------------------------------------------------
-- Initialize the addon

local function init()
    for _, executable in pairs { 'ffmpeg', 'ffsubsync', 'alass' } do
        local config_key = executable .. '_path'
        config[config_key] = h.is_empty(config[config_key]) and h.find_executable(executable) or config[config_key]
    end
end

------------------------------------------------------------
-- Entry point

init()
-- n = automatic sync (embedded text sub if present, else audio).
-- ctrl+n = the old interactive menu for manual reference/engine selection.
-- F12 = wipe the per-show transform cache for the current show and force
-- a fresh sync on the next play (or now if you press n after).
mp.add_key_binding("n", "autosubsync-auto", auto_sync)
mp.add_key_binding("ctrl+n", "autosubsync-menu", function() ref_selector:open() end)
mp.add_key_binding("F12", "autosubsync-clear-cache", function()
    local path = TRANSFORM_DIR .. "/" .. episode_key() .. ".json"
    os.remove(path)
    notify("Episode transform cache cleared; next sync will recompute.", "info", 3)
end)
mp.register_script_message("autosubsync-clear-cache", function()
    local path = TRANSFORM_DIR .. "/" .. episode_key() .. ".json"
    os.remove(path)
end)

-- Auto-sync a subtitle as soon as it gets selected (e.g. when ar_subs loads
-- the Arabic track). Fires only for external, non-retimed tracks, once each.
mp.observe_property("sid", "native", on_sid_changed)
