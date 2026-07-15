local mp = require "mp"
local utils = require "mp.utils"

local render_options = {
    "target-prim",
    "target-trc",
    "target-gamut",
    "target-peak",
    "tone-mapping",
    "gamut-mapping-mode",
    "target-colorspace-hint",
    "target-colorspace-hint-mode",
    "screenshot-tag-colorspace",
    "screenshot-high-bit-depth",
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
    mp.set_property("target-prim", "bt.709")
    mp.set_property("target-trc", "bt.1886")
    mp.set_property("target-gamut", "bt.709")
    mp.set_property("target-peak", "100")
    mp.set_property("tone-mapping", "bt.2446a")
    mp.set_property("gamut-mapping-mode", "perceptual")
    mp.set_property("target-colorspace-hint", "yes")
    mp.set_property("target-colorspace-hint-mode", "target")
    mp.set_property("screenshot-tag-colorspace", "no")
    mp.set_property("screenshot-high-bit-depth", "no")

    local directory = mp.command_native({"expand-path", "~/Pictures/mpv"})
    utils.subprocess({args = {"mkdir", "-p", directory}, cancellable = false})

    local stem = safe_name(mp.get_property("filename/no-ext"))
    local stamp = timecode(mp.get_property_number("time-pos", 0))
    local final_path = string.format("%s/%s [%s]-%03d.png", directory, stem, stamp, sequence)
    local temp_path = final_path .. ".tmp.png"

    mp.command_native({"screenshot-to-file", temp_path, "video"})

    local attempts = 0
    local function finish()
        local file = io.open(temp_path, "rb")
        if not file then
            attempts = attempts + 1
            if attempts < 30 then
                mp.add_timeout(0.05, finish)
                return
            end
            for name, value in pairs(saved) do
                if value ~= nil then mp.set_property(name, value) end
            end
            busy = false
            mp.osd_message("SDR screenshot failed", 2500)
            return
        end

        file:close()
        os.rename(temp_path, final_path)

        for name, value in pairs(saved) do
            if value ~= nil then mp.set_property(name, value) end
        end

        clipboard_command = mp.command_native_async({
            name = "subprocess",
            args = {"sh", "-c", "wl-copy --type image/png < \"$1\"", "mpv-sdr-screenshot", final_path},
        }, function()
            clipboard_command = nil
        end)
        busy = false
        mp.osd_message("SDR screenshot copied", 2500)
    end

    mp.add_timeout(0.1, finish)
end

mp.add_forced_key_binding("s", "mpv-sdr-screenshot", screenshot)
