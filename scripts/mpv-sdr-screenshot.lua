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

    local function restore()
        for name, value in pairs(saved) do
            if value ~= nil then pcall(mp.set_property, name, value) end
        end
    end

    local ok = pcall(function()
        mp.command_native({"screenshot-to-file", temp_path, "video"})
    end)
    if not ok then
        restore()
        busy = false
        mp.osd_message("SDR screenshot failed", 2.5)
        return
    end

    local attempts = 0
    local function finish()
        local file = io.open(temp_path, "rb")
        if not file then
            attempts = attempts + 1
            if attempts < 30 then
                mp.add_timeout(0.05, finish)
                return
            end
            restore()
            busy = false
            mp.osd_message("SDR screenshot failed", 2.5)
            return
        end

        file:close()
        os.rename(temp_path, final_path)
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

mp.add_forced_key_binding("s", "mpv-sdr-screenshot", screenshot)
