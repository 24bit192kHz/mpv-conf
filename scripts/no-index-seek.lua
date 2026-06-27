-- no-index-seek.lua
-- Workaround for MKV files with missing SeekHead/Cues (common in BDREMUXes)
-- MPV cannot seek these files without scanning from the start.
-- This script replaces seeks with high-speed playback, which forces the same
-- linear read but does it through MPV's cache -- much faster over NFS.
-- It also builds a sidecar timestamp index so backward seeks improve over time.

local mp    = require 'mp'
local msg   = require 'mp.msg'

--------------------------------------------------------------------
-- Config (override via script-opts=no_index_seek-speed=50 etc.)
--------------------------------------------------------------------
local o = {
    speed       = 100,      -- fast-forward multiplier
    index_dir   = "/tmp",   -- sidecar index storage
    record_every = 20,      -- record a timestamp every N seconds of playback
}

(require 'mp.options').read_options(o, 'no_index_seek')

--------------------------------------------------------------------
-- State
--------------------------------------------------------------------
local state = {
    no_cues      = false,
    fast_seeking = false,
    seek_target  = nil,
    orig_speed   = 1.0,
    orig_pause   = false,
    index        = {},   -- sorted list of known good timestamps
    path         = nil,
    last_recorded = -999,
}

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function format_time(t)
    t = math.floor(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s)
    else          return string.format("%d:%02d", m, s) end
end

local function index_path()
    if not state.path then return nil end
    -- sanitise path into a safe filename
    local safe = state.path:gsub("[/\\:*?\"<>| ]", "_")
    return o.index_dir .. "/mpv_noidx_" .. safe .. ".idx"
end

local function save_index()
    local p = index_path(); if not p then return end
    local f = io.open(p, "w"); if not f then return end
    for _, t in ipairs(state.index) do f:write(string.format("%.3f\n", t)) end
    f:close()
end

local function load_index()
    local p = index_path(); if not p then return end
    local f = io.open(p, "r"); if not f then return end
    state.index = {}
    for line in f:lines() do
        local t = tonumber(line)
        if t then table.insert(state.index, t) end
    end
    f:close()
    table.sort(state.index)
    if #state.index > 0 then
        msg.info(string.format("[no-index-seek] Loaded %d cached index points", #state.index))
    end
end

-- Insert timestamp into sorted index (dedup within 5 s)
local function record(pos)
    if pos - state.last_recorded < o.record_every then return end
    state.last_recorded = pos
    for i, t in ipairs(state.index) do
        if math.abs(t - pos) < 5 then return end   -- already have it
        if t > pos then table.insert(state.index, i, pos); return end
    end
    table.insert(state.index, pos)
end

-- Find the largest known timestamp that is <= target AND inside cache
local function best_jump_point(target)
    local ranges = mp.get_property_native("demuxer-cache-state")
    local cached = {}
    if ranges and ranges["seekable-ranges"] then
        cached = ranges["seekable-ranges"]
    end

    local function in_cache(t)
        for _, r in ipairs(cached) do
            if t >= r["start"] and t <= r["end"] then return true end
        end
        return false
    end

    -- Walk the index backward from target
    for i = #state.index, 1, -1 do
        local t = state.index[i]
        if t <= target and in_cache(t) then return t end
    end
    return nil  -- nothing useful in cache
end

--------------------------------------------------------------------
-- Fast-seek logic
--------------------------------------------------------------------
local function stop_fast_seek()
    if not state.fast_seeking then return end
    state.fast_seeking = false
    state.seek_target  = nil
    mp.set_property_number("speed", state.orig_speed)
    if state.orig_pause then mp.set_property("pause", "yes") end
    mp.osd_message("", 0)
    save_index()
    msg.info("[no-index-seek] Seek complete")
end

local function fast_seek_to(target)
    state.fast_seeking = true
    state.seek_target  = target
    state.orig_speed   = mp.get_property_number("speed") or 1.0
    state.orig_pause   = (mp.get_property("pause") == "yes")
    mp.set_property("pause", "no")
    mp.set_property_number("speed", o.speed)
end

local function do_seek(target)
    if not state.no_cues then
        mp.commandv("seek", tostring(target), "absolute")
        return
    end

    -- Cancel any in-progress fast seek
    if state.fast_seeking then stop_fast_seek() end

    local current = mp.get_property_number("time-pos") or 0
    target = math.max(0, target)

    if target > current then
        -- ── Forward: just speed up from here ─────────────────────
        msg.info(string.format("[no-index-seek] Forward seek → %s (fast-forward)", format_time(target)))
        mp.osd_message(string.format("⏩  Seeking to %s …", format_time(target)), 9999)
        fast_seek_to(target)
    else
        -- ── Backward: jump to best cached point first ─────────────
        local jump = best_jump_point(target)
        if jump then
            msg.info(string.format("[no-index-seek] Backward seek → %s (cache jump from %.0fs)", format_time(target), jump))
            mp.commandv("seek", tostring(jump), "absolute")
        else
            msg.info(string.format("[no-index-seek] Backward seek → %s (from start)", format_time(target)))
            mp.commandv("seek", "0", "absolute")
        end
        mp.osd_message(string.format("⏪  Seeking to %s …", format_time(target)), 9999)
        fast_seek_to(target)
    end
end

--------------------------------------------------------------------
-- Monitor playback position
--------------------------------------------------------------------
mp.observe_property("time-pos", "number", function(_, pos)
    if not pos then return end

    -- Record index point during normal playback
    if not state.fast_seeking then
        record(pos)
        return
    end

    -- During fast seek: check if we've arrived
    if state.seek_target and pos >= state.seek_target - 0.8 then
        stop_fast_seek()
        return
    end

    -- Update OSD progress every ~0.5 s (the observer fires on every frame change)
    if state.seek_target then
        local remaining = state.seek_target - pos
        mp.osd_message(string.format("⏩  %s  →  %s   (%.0f s left)",
            format_time(pos), format_time(state.seek_target), remaining), 0.6)
    end
end)

--------------------------------------------------------------------
-- Detect missing cues from mpv log
--------------------------------------------------------------------
mp.enable_messages("warn")
mp.register_event("log-message", function(e)
    if not e.text then return end
    if e.text:find("0x1c53bb6b") or e.text:find("0x1254c367") then
        if not state.no_cues then
            state.no_cues = true
            mp.osd_message("⚠  No seek index in file — fast-seek mode active", 4)
            msg.warn("[no-index-seek] MKV missing SeekHead/Cues — seek workaround enabled")
        end
    end
end)

--------------------------------------------------------------------
-- File open / close hooks
--------------------------------------------------------------------
mp.register_event("file-loaded", function()
    state.path         = mp.get_property("path")
    state.index        = {}
    state.last_recorded = -999
    state.no_cues      = false
    state.fast_seeking = false
    load_index()
end)

mp.register_event("end-file", function()
    if state.fast_seeking then stop_fast_seek() end
    save_index()
end)

--------------------------------------------------------------------
-- Key bindings — override default seek keys when no_cues is active
-- These shadow the built-in bindings only for this script.
-- uosc timeline clicks will still use MPV's own seek; for those,
-- the fast-forward kicks in via the time-pos observer above
-- once MPV's own seek stalls.
--------------------------------------------------------------------
local function make_abs_seek(seconds)
    return function()
        if not state.no_cues then
            mp.commandv("seek", tostring(seconds), "absolute")
            return
        end
        do_seek(seconds)
    end
end

local function make_rel_seek(delta)
    return function()
        if not state.no_cues then
            mp.commandv("seek", tostring(delta), "relative")
            return
        end
        local pos = mp.get_property_number("time-pos") or 0
        do_seek(pos + delta)
    end
end

-- Override the standard seek keys
mp.add_key_binding("RIGHT",       "seek-fwd-5",    make_rel_seek(5),    {repeatable=true})
mp.add_key_binding("LEFT",        "seek-back-5",   make_rel_seek(-5),   {repeatable=true})
mp.add_key_binding("UP",          "seek-fwd-60",   make_rel_seek(60),   {repeatable=true})
mp.add_key_binding("DOWN",        "seek-back-60",  make_rel_seek(-60),  {repeatable=true})
mp.add_key_binding("Shift+RIGHT", "seek-fwd-1",    make_rel_seek(1),    {repeatable=true})
mp.add_key_binding("Shift+LEFT",  "seek-back-1",   make_rel_seek(-1),   {repeatable=true})
mp.add_key_binding("Shift+UP",    "seek-fwd-600",  make_rel_seek(600),  {repeatable=true})
mp.add_key_binding("Shift+DOWN",  "seek-back-600", make_rel_seek(-600), {repeatable=true})

-- Cancel fast seek with Escape or Space
mp.add_key_binding("ESC",   "cancel-fast-seek", function()
    if state.fast_seeking then
        stop_fast_seek()
        mp.set_property("pause", "yes")
        mp.osd_message("⏹  Seek cancelled", 2)
    end
end)

-- Expose a script-message so uosc / other scripts can trigger a smart seek:
-- e.g.  script-message no-index-seek-to 3661.5
mp.register_script_message("no-index-seek-to", function(t)
    local target = tonumber(t)
    if target then do_seek(target) end
end)

msg.info("[no-index-seek] Loaded — watching for cue-less MKV files")
