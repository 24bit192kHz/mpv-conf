-- YouTube-style Space: tap = play/pause, hold = speed up
-- Inspired by evafast but with deterministic tap-vs-hold via timer.

local options = {
    hold_threshold = 0.25,   -- seconds before speedup kicks in
    speed_factor   = 2.0,    -- target speed when holding
    speed_ramp     = false,  -- false = instant jump, true = gradual ramp (evafast-style)
    ramp_step      = 0.2,    -- speed increment per ramp tick when speed_ramp=yes
    ramp_interval  = 0.05,   -- seconds between ramp ticks
}
require 'mp.options'.read_options(options, 'space_hold_speed')

local holding = false
local original_speed = 1.0
local original_pause = false
local timer = nil
local ramp_timer = nil

local function flash_speed()
    if mp.command_native then
        mp.command("script-binding uosc/flash-speed")
    end
end

local function stop_ramp()
    if ramp_timer then ramp_timer:kill(); ramp_timer = nil end
end

local function restore_state()
    stop_ramp()
    mp.set_property_number("speed", original_speed)
    if original_pause then
        mp.set_property_native("pause", true)
    end
    flash_speed()
end

local function engage_speedup()
    holding = true
    original_speed = mp.get_property_number("speed", 1.0)
    original_pause = mp.get_property_native("pause", false)
    if original_pause then
        mp.set_property_native("pause", false)
    end
    if options.speed_ramp then
        local step = tonumber(options.ramp_step) or 0.2
        local interval = tonumber(options.ramp_interval) or 0.05
        if step <= 0 then step = 0.2 end
        if interval <= 0 then interval = 0.05 end
        if original_speed >= options.speed_factor then
            mp.set_property_number("speed", options.speed_factor)
        else
            mp.set_property_number("speed", original_speed)
            ramp_timer = mp.add_periodic_timer(interval, function()
                local cur = mp.get_property_number("speed", 1.0)
                local nxt = cur + step
                if nxt >= options.speed_factor then
                    mp.set_property_number("speed", options.speed_factor)
                    stop_ramp()
                else
                    mp.set_property_number("speed", nxt)
                end
                flash_speed()
            end)
        end
    else
        mp.set_property_number("speed", options.speed_factor)
    end
    flash_speed()
end

local function on_space(evt)
    if evt.event == "down" then
        if timer then timer:kill() end
        stop_ramp()
        holding = false
        timer = mp.add_timeout(options.hold_threshold, engage_speedup)
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
