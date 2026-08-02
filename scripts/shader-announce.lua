-- shader-announce: logs the active glsl-shaders chain on every change.
-- OSD stays quiet by default: automatic profile swaps ([Anime],
-- [hdr-passthrough]) only hit the terminal, and manual ALT+1..7 switches
-- already show their own text via the bindings. Set debug=yes to get an
-- OSD announcement for every change, including profile swaps.

local mp = require "mp"
local options = require "mp.options"

local opts = {
    debug = false,
}
options.read_options(opts, "shader_announce")

local last_label = nil

local function chain_label(shaders)
    if not shaders or #shaders == 0 then
        return "Shaders: off (ALT+0)"
    end
    local joined = table.concat(shaders, ":")
    if joined:find("Anime4K", 1, true) then
        local stacked = joined:find("Restore_CNN_VL", 1, true)
            and joined:find("Upscale_CNN_x2_VL", 1, true)
            and select(2, joined:gsub("Restore_CNN", "")) >= 2
        if stacked then
            return "Anime4K: stacked chain (ALT+4..6)"
        elseif joined:find("Restore_CNN_Soft", 1, true) then
            return "Anime4K: Mode B Soft (HQ, grain-safe)"
        elseif joined:find("Upscale_Denoise", 1, true) then
            return "Anime4K: Mode C (HQ)"
        elseif joined:find("Restore_CNN", 1, true) then
            return "Anime4K: Mode A (HQ)"
        else
            return "Anime4K: Pure upscale (grain-safe, anime movies)"
        end
    end
    if joined:find("SSimSuperRes", 1, true) then
        return "Shaders: SDR base (KrigBilateral + SSim)"
    end
    if #shaders == 1 and joined:find("KrigBilateral", 1, true) then
        return "Shaders: HDR (KrigBilateral only)"
    end
    return "Shaders: " .. #shaders .. " custom"
end

local function on_shaders(_, value)
    local shaders = {}
    if type(value) == "table" then
        for _, part in ipairs(value) do
            if part ~= "" then shaders[#shaders + 1] = part end
        end
    elseif type(value) == "string" then
        for part in value:gmatch("[^:]+") do shaders[#shaders + 1] = part end
    end
    local label = chain_label(shaders)
    if label == last_label then return end
    last_label = label
    mp.msg.info(label)
    if opts.debug then
        mp.commandv("show-text", label, 2500)
    end
end

mp.observe_property("glsl-shaders", "native", on_shaders)
