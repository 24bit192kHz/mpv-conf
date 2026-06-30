-- YouTube-style Space: tap = play/pause, hold = speed up
-- Inspired by evafast but with deterministic tap-vs-hold via timer.

local options = {
    hold_threshold = 0.25,   -- seconds before speedup kicks in
    speed_factor   = 2.0,    -- target speed when holding
    speed_ramp     = false,  -- false = instant jump, true = gradual ramp (evafast-style)
}
require 'mp.options'.read_options(options, 'space_hold_speed')

local holding = false
local original_speed = 1.0
local original_pause = false
local timer = nil

local function flash_speed()
    if mp.command_native then
        mp.command("script-binding uosc/flash-speed")
    end
end

local function restore_state()
    mp.set_property_number("speed", original_speed)
    if original_pause then
        mp.set_property_native("pause", true)
    end
    flash_speed()
end

local function on_space(evt)
    if evt.event == "down" then
        if timer then timer:kill() end
        holding = false
        timer = mp.add_timeout(options.hold_threshold, function()
            -- Hold threshold passed -> engage speedup
            holding = true
            original_speed = mp.get_property_number("speed", 1.0)
            original_pause = mp.get_property_native("pause", false)
            if original_pause then
                mp.set_property_native("pause", false)
            end
            mp.set_property_number("speed", options.speed_factor)
            flash_speed()
        end)
    elseif evt.event == "up" or evt.event == "press" then
        if timer then timer:kill(); timer = nil end
        if holding then
            holding = false
            restore_state()
        else
            -- Quick tap: toggle pause (standard Space behavior)
            mp.command("cycle pause")
        end
    end
end

mp.add_key_binding("SPACE", "space-hold", on_space, {complex = true, repeatable = false})
