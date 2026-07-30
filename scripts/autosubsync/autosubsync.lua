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
    -- Seconds to wait after a subtitle is selected before auto-syncing, so
    -- the loader (e.g. subdl_ar) finishes adding tracks first.
    auto_sync_delay = 0.7,
    -- Cache the computed offset+framerate per show folder and reuse it for
    -- every episode (applying it is instant). First episode of a show computes
    -- it; the rest reuse it. Press n to recompute for the current show.
    cache_show_transform = true,
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

-- Per-video cache dir (keyed by path+size+mtime) for extracted references and
-- serialized speech. Defined early because sync_subtitles uses it for the
-- audio-speech cache.
local REF_CACHE_DIR = (os.getenv("HOME") or "/tmp") .. "/.cache/autosubsync/refs"

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

-- Show-level sync-transform cache. For a series (same source/release) the
-- offset + framerate scale between the downloaded sub and the video is the
-- same for every episode, so we compute it ONCE (first episode) and reuse it
-- for the rest -- applying it is pure timestamp math (milliseconds), with no
-- file traversal or ffsubsync run. Keyed by the containing folder.
local TRANSFORM_DIR = (os.getenv("HOME") or "/tmp") .. "/.cache/autosubsync/transforms"

local function show_key()
    local path = mp.get_property("path") or ""
    local dir = path:match("^(.*)/[^/]*$") or path
    return djb2_hex(dir)
end

local function load_show_transform()
    if not config.cache_show_transform then return nil end
    local f = io.open(TRANSFORM_DIR .. "/" .. show_key() .. ".json", "r")
    if not f then return nil end
    local raw = f:read("*a"); f:close()
    local t = utils.parse_json(raw)
    if type(t) ~= "table" or type(t.offset) ~= "number" then return nil end
    if type(t.scale) ~= "number" then t.scale = 1.0 end
    -- Tie the cache to the retimed file it produced: if the user wipes the
    -- subdl cache (rm -rf .cache/subdl_ar) the retimed is gone too, and the
    -- cached offset+scale would silently reapply a stale transform on the
    -- next play. Reject the entry so the next run recomputes from scratch.
    if type(t.retimed) == "string" and not utils.file_info(t.retimed) then
        mp.msg.info("autosubsync: cached show transform's retimed is gone (" ..
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
    local f = io.open(TRANSFORM_DIR .. "/" .. show_key() .. ".json", "w")
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
    if engine_name == "ffsubsync" then
        local ref = reference_file_path
        local extra = {}
        if not ref_sub_path then
            -- No explicit reference: prefer the best embedded text sub as
            -- the ffsubsync reference (sub-to-sub, instant) over audio VAD
            -- (21s on lossless 4K). Falls back to audio VAD only when no
            -- usable text sub exists (PGS / image-based) -- cached as .npz
            -- per video, so only the first sync is slow. The cue gate uses
            -- auto_sync_min_cues so very sparse refs (signs/songs-only,
            -- < 100 cues) still get the reliable audio path.
            local dir = video_ref_dir()
            subprocess({ "mkdir", "-p", dir })

            local _, active = get_active_track('sub')
            local refs = get_embedded_refs(active and active.id or nil)
            local best = pick_best_embedded_ref(refs)
            if best and best.cues >= config.auto_sync_min_cues then
                ref = dialogue_only_ass(best.path)
                notify(string.format("using embedded sub ref: %s (%d cues)", ref, best.cues), "info", 1)
                if ref ~= best.path then
                    notify(string.format("Stripped signs/songs from ref (%d -> %d cues)",
                            count_cues(best.path), count_dialogue_cues(ref)), "info", 3)
                end
            else
                local npz = dir .. "/video.npz"
                if utils.file_info(npz) then
                    ref = npz
                else
                    local link = dir .. "/video.mkv"
                    subprocess({ "ln", "-sf", reference_file_path, link })
                    ref = link
                    table.insert(extra, "--serialize-speech")
                    table.insert(extra, "--reference-stream")
                    table.insert(extra, "0:" .. get_active_track('audio'))
                    table.insert(extra, "--max-duration-seconds")
                    table.insert(extra, "600")
                end
            end
        end
        local args = { config.ffsubsync_path, ref, "-i", subtitle_path, "-o", retimed_subtitle_path }
        for _, a in ipairs(extra) do table.insert(args, a) end
        ret = subprocess(args)
    else
        ret = subprocess { config.alass_path, reference_file_path, subtitle_path, retimed_subtitle_path }
    end

    if ret == nil then
        return notify("Parsing failed or no args passed.", "fatal", 3)
    end

    if ret.status == 0 then
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
        else
            notify("Error: couldn't add synchronized subtitle.", "error", 3)
        end
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
local function count_cues(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        if line:find("^Dialogue:", 1) or line:match("^%d+%s*$") then n = n + 1 end
    end
    f:close()
    return n
end

-- ASS style-name first-word that marks a style as signs/songs/OP/ED/title-card
-- (everything that is NOT spoken dialogue). Anime forced tracks mix
-- "Default" (real dialogue) with "Time"/"Time Shadow" (the typewriter
-- title-card effect), "OPL"/"OPR"/"ED English"/"ED Japanese" (OP/ED lyrics)
-- and "Sign". First-token match (case-insensitive) so that "ED English",
-- "Time Shadow", "OP-Romaji" all get caught, while "Default", "Alternate",
-- "Main", "Subtitle" pass through.
local SIGN_FIRSTWORDS = {
    op = true, ed = true, opl = true, opr = true,
    time = true, sign = true, title = true, banner = true,
    ts = true, typeset = true, typesetting = true,
    karaoke = true, song = true,
    epi = true, eyecatch = true, neon = true,
    splash = true, headline = true, instruct = true,
    picture = true, abandoned = true,
    nextep = true, next = true, preview = true,
}

local function is_dialogue_style(name)
    if not name then return true end
    local lc = name:lower():gsub("^[%s%p]+", "")
    local first = lc:match("([^%s%-_]+)")
    if first and SIGN_FIRSTWORDS[first] then return false end
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
local function count_dialogue_cues(path)
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
local function dialogue_only_ass(path)
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

local function read_ref_manifest(dir)
    local mf = io.open(dir .. "/manifest.json", "r")
    if not mf then return nil end
    local raw = mf:read("*a"); mf:close()
    local list = utils.parse_json(raw)
    if type(list) ~= "table" or #list == 0 then return nil end
    for _, r in ipairs(list) do
        if not utils.file_info(dir .. "/" .. r.file) then return nil end
    end
    return list
end

-- Extract every embedded text subtitle in ONE ffmpeg pass (one traversal of
-- the input, all outputs written together) and cache them with a manifest.
local function extract_all_refs(dir, exclude_id)
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
    if mf then mf:write(utils.format_json(list)); mf:close() end
    return list
end

-- Cached list of embedded reference subs: {id, lang, codec, file, cues, path}.
get_embedded_refs = function(exclude_id)
    local dir = video_ref_dir()
    local list = read_ref_manifest(dir) or extract_all_refs(dir, exclude_id)
    for _, r in ipairs(list) do
        r.path = dir .. "/" .. r.file
    end
    return list
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
    local refs = get_embedded_refs(exclude_id or active.id)
    local best = pick_best_embedded_ref(refs)
    if not best then return false end
    if gate_min_cues and best.cues < gate_min_cues then
        notify(string.format("Embedded sub too sparse to auto-sync (%d cues); press n for audio.", best.cues), "info", 4)
        return false
    end
    notify(string.format("Syncing to embedded sub #%s (%s, %d cues)...",
            best.id, best.lang or "?", best.cues), nil, 2)
    -- alass: fast per-episode subtitle sync. NOTE: we deliberately do NOT cache
    -- a show transform from subtitle refs -- on sparse refs (e.g. Lain's forced
    -- sub) the detected offset flips sign per episode (E02=+30.56, E03=-33.38),
    -- so caching it would propagate garbage. The reliable per-show transform
    -- comes from the audio path (ffsubsync), which sync_subtitles caches.
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
-- Set by apply_cached_transform when it succeeds. A late-firing timer (set
-- before the cache was applied) must NOT then run sync_to_best_embedded and
-- have alass compound another offset on top of the cached retimed -- we
-- already wrote and loaded the correct retimed, doing it again is always
-- wrong.
local just_applied_cache = false
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
    local path = TRANSFORM_DIR .. "/" .. show_key() .. ".json"
    os.remove(path)
    notify("Show transform cache cleared; next sync will recompute.", "info", 3)
end)
mp.register_script_message("autosubsync-clear-cache", function()
    local path = TRANSFORM_DIR .. "/" .. show_key() .. ".json"
    os.remove(path)
end)

-- Auto-sync a subtitle as soon as it gets selected (e.g. when subdl_ar loads
-- the Arabic track). Fires only for external, non-retimed tracks, once each.
mp.observe_property("sid", "native", on_sid_changed)
