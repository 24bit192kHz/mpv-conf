local mp = require "mp"
local utils = require "mp.utils"
local options = require "mp.options"

local opts = {
    -- HDR->SDR curve for the capture. bt.2446a is the dim-but-faithful
    -- reference trim; mobius/bt.2390 render punchier frames.
    tone_mapping = "bt.2446a",
}
options.read_options(opts, "mpv-sdr-screenshot")
local render_options = {
    -- NOTE: only these take effect for "video" screenshots. target-prim,
    -- target-trc, target-peak, target-gamut and target-colorspace-hint are
    -- ignored there (vo_gpu_next renders "video" to a hardcoded sRGB
    -- target); they used to be set+restored here to no effect.
    "tone-mapping",
    "gamut-mapping-mode",
    "screenshot-tag-colorspace",
    "screenshot-high-bit-depth",
    "blend-subtitles",
}

local busy = false
local sequence = 0
local clipboard_command
-- Generation token + file identity: bumped on every new shot and on
-- file-loaded/end-file so a pending finish()/restore() from file A can
-- never reapply A's tone-mapping/gamut/blend onto file B's
-- conditional-profile values (e.g. sdr-native clip vs hdr-passthrough
-- st2094-40) when s is followed by playlist-next inside the
-- 0.1s + 30x0.05s finish window.
local shot_gen = 0
local active_temp = nil

local function safe_name(value)
    value = (value or "mpv-screenshot"):gsub("[^%w%._%-]+", "_")
    return value:gsub("^%.*", "")
end

local function timecode(seconds)
    seconds = math.max(0, seconds or 0)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local whole = math.floor(seconds % 60)
    local millis = math.floor((seconds - math.floor(seconds)) * 1000 + 0.5)
    return string.format("%02d.%02d.%02d.%03d", hours, minutes, whole, millis)
end

local function screenshot()
    if busy then
        return
    end
    busy = true
    sequence = sequence + 1
    -- Capture generation + file identity before touching properties so a
    -- pending finish()/restore() can prove it still owns the current file.
    shot_gen = shot_gen + 1
    local gen = shot_gen
    local src_path = mp.get_property("path", "")

    local saved = {}
    for _, name in ipairs(render_options) do
        saved[name] = mp.get_property(name)
    end

    -- Render this frame into an SDR/sRGB target before writing the PNG.
    -- ("video" screenshots always map to sRGB; these two do the HDR->SDR
    -- work. Peak comes from the screenshot path's single-frame detection.)
    mp.set_property("tone-mapping", opts.tone_mapping)
    mp.set_property("gamut-mapping-mode", "perceptual")
    mp.set_property("screenshot-tag-colorspace", "no")
    mp.set_property("screenshot-high-bit-depth", "no")
    -- blend-subtitles=video burns ASS into the video plane; disable for a
    -- clean SDR frame (gpu-next still needs the global video mode for seek-subs).
    mp.set_property("blend-subtitles", "no")

    local directory = mp.command_native({"expand-path", "~/Pictures/mpv"})
    utils.subprocess({args = {"mkdir", "-p", directory}, cancellable = false})

    local stem = safe_name(mp.get_property("filename/no-ext"))
    local stamp = timecode(mp.get_property_number("time-pos", 0))
    local final_path = string.format("%s/%s [%s]-%03d.png", directory, stem, stamp, sequence)
    local temp_path = final_path .. ".tmp.png"
    active_temp = temp_path

    local function is_current()
        return gen == shot_gen and mp.get_property("path", "") == src_path
    end

    local function restore()
        -- Stale shot (file-loaded/end-file bumped shot_gen, or playlist
        -- moved to a new path): never reapply file A's saved
        -- tone-mapping/gamut/blend onto file B's conditional-profile
        -- values (sdr-native clip vs hdr-passthrough st2094-40).
        if not is_current() then
            return false
        end
        for name, value in pairs(saved) do
            if value ~= nil then pcall(mp.set_property, name, value) end
        end
        return true
    end

    local ok = pcall(function()
        mp.command_native({"screenshot-to-file", temp_path, "video"})
    end)
    if not ok then
        if active_temp == temp_path then
            active_temp = nil
        end
        -- Guarded: no-op when stale so we never clobber the new file.
        restore()
        -- Only clear busy when we still own it; a newer shot (higher gen)
        -- started after us keeps its own busy=true.
        if gen == shot_gen then
            busy = false
        end
        -- Only OSD when still on the source file; otherwise the message
        -- would pop over the next playlist entry.
        if is_current() then
            mp.osd_message("SDR screenshot failed", 2.5)
        end
        return
    end

    local attempts = 0
    local function finish()
        -- Cancel path: s then playlist-next inside the 0.1s + 30x0.05s
        -- window. Drop the stale temp, leave the new file's properties
        -- and busy flag alone (a newer shot owns them now, or the
        -- file-loaded/end-file handler already cleared busy).
        if gen ~= shot_gen or mp.get_property("path", "") ~= src_path then
            pcall(os.remove, temp_path)
            return
        end
        local file = io.open(temp_path, "rb")
        if not file then
            attempts = attempts + 1
            if attempts < 30 then
                mp.add_timeout(0.05, finish)
                return
            end
            if active_temp == temp_path then
                active_temp = nil
            end
            restore()
            busy = false
            mp.osd_message("SDR screenshot failed", 2.5)
            return
        end

        file:close()
        os.rename(temp_path, final_path)
        if active_temp == temp_path then
            active_temp = nil
        end
        restore()

        clipboard_command = mp.command_native_async({
            name = "subprocess",
            args = {"sh", "-c", "wl-copy --type image/png < \"$1\"", "mpv-sdr-screenshot", final_path},
        }, function()
            clipboard_command = nil
        end)
        busy = false
        mp.osd_message("SDR screenshot copied", 2.5)
    end

    mp.add_timeout(0.1, finish)
end

local function cancel_pending()
    -- A new file (or no file) invalidates every pending finish()/restore():
    -- bump the generation so stale closures drop out, best-effort remove
    -- the stale temp, and free busy so the new file can screenshot at once.
    -- Stale finish() closures return early and never touch busy/properties,
    -- so clearing here cannot race a newer shot (which starts after us).
    shot_gen = shot_gen + 1
    if active_temp then
        pcall(os.remove, active_temp)
        active_temp = nil
    end
    busy = false
end

mp.register_event("file-loaded", cancel_pending)
mp.register_event("end-file", cancel_pending)

mp.add_forced_key_binding("s", "mpv-sdr-screenshot", screenshot)
