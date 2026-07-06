local mp = require "mp"
local options = require "mp.options"
local utils = require "mp.utils"

local opts = {
    enabled = true,
    backend = "cuda",
    project = "~~/cuda-crop-cpp",
    binary = "~~/cuda-crop-cpp/build/cuda-crop-cpp",
    socket = "/tmp/cuda-crop-cpp.sock",
    scan_driver = "sidecar",
    mpv_socket = "",
    daemon_idle_timeout = 10.0,
    legacy_script = "~~/script-modules/dynamic-crop-legacy.lua",
    fallback_failures = 2,
    apply_mode = "transform",
    panscan_letterbox = 1.0,
    panscan_full = 0.0,
    panscan_target_aspect = 2.333333,
    scan_ahead_seconds = 0.0,
    scan_seconds = 3,
    read_ahead_seconds = 3,
    apply_before_seconds = 0.0,
    restore_before_seconds = 0.0,
    presentation_lead_frames = 0.0,
    symmetry_tolerance = 96,
    min_letterbox_aspect = 2.0,
    max_letterbox_aspect = 2.60,
    min_letterbox_crop_ratio = 0.08,
    restore_grace_seconds = 0.0,
    restore_head_guard_seconds = 0.30,
    restore_min_lead_seconds = 0.50,
    restore_tail_guard_seconds = 0.20,
    transient_revert_seconds = 0.24,
    scan_interval = 1,
    detect_limit = 2,
    detect_round = 2,
    min_votes = 2,
    sample_step = 1,
    mode = 4,
    read_ahead_mode = 2,
    ratio_timer = 2,
    read_ahead_sync = 1,
    limit_timer = 1.0,
    crop_method = 1,
    cycle_key = "C",
    telemetry = true,
    debug = false,
}

options.read_options(opts)

local script_version = "dynamic-crop-lua-transform-v8"
local label = "dynamic_crop_cuda_crop"
local timer = nil
local running = false
local last_crop = nil
local daemon_started = false
local sidecar_started = false
local sidecar_command = nil
local sidecar_socket = nil
local ipc_server_assigned = false
local legacy_started = false
local scan_failures = 0
local pending_timer = nil
local pending_crop = nil
local pending_at = nil
local pending_events = {}
local source_width = nil
local source_height = nil
local full_frame_restore_started_at = nil
local last_applied_needed_at = nil
local startup_pause_active = false
local startup_pause_was_paused = false
local initial_scan_completed = false
local runtime_mode = opts.enabled and "continuous" or "disabled"
local one_shot_locked = false
local restore_after_seek = false
local source_dimensions
local schedule_next_pending
local stop_runtime_scans
local remove_crop
local stop_sidecar

local function expand_path(path)
    return mp.command_native({"expand-path", path})
end

local function script_ipc_socket()
    if opts.mpv_socket and opts.mpv_socket ~= "" then
        return opts.mpv_socket
    end
    local pid = mp.get_property_number("pid", math.floor(mp.get_time() * 1000000))
    return string.format("/tmp/mpv-dynamic-crop-%d.sock", pid)
end

local function start_sidecar()
    if sidecar_started then return end
    sidecar_started = true
    sidecar_socket = script_ipc_socket()
    if not ipc_server_assigned then
        os.remove(sidecar_socket)
        mp.set_property("input-ipc-server", sidecar_socket)
        ipc_server_assigned = true
    end
    local binary = expand_path(opts.binary)
    sidecar_command = mp.command_native_async({
        name = "subprocess",
        args = {
            binary,
            "controller",
            "--mpv-socket", sidecar_socket,
            "--interval", tostring(opts.scan_interval),
            "--scan-ahead", tostring(opts.scan_ahead_seconds),
            "--duration", tostring(opts.read_ahead_seconds),
            "--threshold", tostring(opts.detect_limit),
            "--round-to", tostring(opts.detect_round),
            "--sample-step", tostring(opts.sample_step),
            "--min-votes", tostring(opts.min_votes),
        },
        playback_only = true,
    }, function()
        sidecar_started = false
        sidecar_command = nil
    end)
end

stop_sidecar = function()
    if sidecar_command then
        mp.abort_async_command(sidecar_command)
    end
    sidecar_started = false
    sidecar_command = nil
end

local function set_panscan(value)
    mp.set_property("panscan", string.format("%.3f", value))
end

local function reset_transform()
    mp.set_property_number("video-zoom", 0)
    mp.set_property_number("video-pan-x", 0)
    mp.set_property_number("video-pan-y", 0)
end

local function reset_render_state()
    mp.set_property("video-crop", "")
    mp.set_property("video-aspect-override", "-2")
    set_panscan(opts.panscan_full)
    reset_transform()
end

local function clamp(value, minimum, maximum)
    return math.min(math.max(value, minimum), maximum)
end

local function log(message)
    if opts.debug then mp.msg.info(message) end
end

local function telemetry(message)
    if opts.telemetry then mp.msg.info(message) end
end

local function frame_duration_seconds()
    local fps = mp.get_property_number("container-fps", 0)
    if fps <= 0 then
        fps = 24000 / 1001
    end
    return 1 / fps
end

local function playback_ended()
    return mp.get_property_native("eof-reached") == true
end

local function clear_pending_events()
    if pending_timer then
        pending_timer:kill()
        pending_timer = nil
    end
    pending_crop = nil
    pending_at = nil
    pending_events = {}
    full_frame_restore_started_at = nil
end

local function scans_allowed()
    return opts.enabled
        and runtime_mode ~= "disabled"
        and not (runtime_mode == "one_shot" and one_shot_locked)
        and not legacy_started
end

local function stop_cuda_timers()
    stop_sidecar()
    if timer then
        timer:kill()
        timer = nil
    end
    clear_pending_events()
    running = false
    last_applied_needed_at = nil
    restore_after_seek = false
    startup_pause_active = false
    initial_scan_completed = false
    one_shot_locked = false
end

local function hold_startup_until_first_scan()
    if startup_pause_active or initial_scan_completed then return end
    startup_pause_was_paused = mp.get_property_native("pause") == true
    startup_pause_active = true
    if not startup_pause_was_paused then
        mp.set_property_bool("pause", true)
    end
end

local function release_startup_pause()
    initial_scan_completed = true
    if startup_pause_active and not startup_pause_was_paused then
        mp.set_property_bool("pause", false)
    end
    startup_pause_active = false
end

stop_runtime_scans = function()
    stop_sidecar()
    if timer then
        timer:kill()
        timer = nil
    end
    clear_pending_events()
    running = false
    release_startup_pause()
end

local function start_legacy_backend(reason)
    if legacy_started then return end
    legacy_started = true
    opts.enabled = false
    running = false
    stop_cuda_timers()
    remove_crop()

    local legacy = mp.command_native({"expand-path", opts.legacy_script})
    local info = utils.file_info(legacy)
    if not info then
        mp.msg.error("dynamic_crop: legacy fallback missing: " .. tostring(legacy))
        return
    end

    mp.msg.warn("dynamic_crop: CUDA backend unavailable, starting legacy fallback: " .. reason)
    local ok, err = pcall(dofile, legacy)
    if not ok then
        mp.msg.error("dynamic_crop: failed to start legacy fallback: " .. tostring(err))
    end
end

local function cuda_binary_available()
    local info = utils.file_info(expand_path(opts.binary))
    return info and not info.is_dir
end

local function record_scan_failure(reason)
    scan_failures = scan_failures + 1
    mp.msg.warn(string.format(
        "dynamic_crop: CUDA scan failure %d/%d: %s",
        scan_failures,
        opts.fallback_failures,
        reason
    ))
    if scan_failures >= opts.fallback_failures then
        start_legacy_backend(reason)
    end
end

local function selected_path()
    local path = mp.get_property("path")
    if not path or path:match("^%a[%w+.-]*://") then return nil end
    return expand_path(path)
end

remove_crop = function()
    clear_pending_events()
    last_applied_needed_at = nil
    restore_after_seek = false
    startup_pause_active = false
    initial_scan_completed = false
    one_shot_locked = false
    reset_render_state()
    last_crop = nil
end

local function reset_crop_state()
    clear_pending_events()
    last_crop = nil
    full_frame_restore_started_at = nil
    last_applied_needed_at = nil
    restore_after_seek = false
    startup_pause_active = false
    initial_scan_completed = false
    one_shot_locked = false
    reset_render_state()
end

local function crop_parts(crop)
    local w, h, x, y = crop:match("^(%d+):(%d+):(%d+):(%d+)$")
    if not w then return nil end
    return tonumber(w), tonumber(h), tonumber(x), tonumber(y)
end

local function video_crop_rect(crop)
    local w, h, x, y = crop_parts(crop)
    if not w then return "" end
    return string.format("%dx%d+%d+%d", w, h, x, y)
end

local function round_nearest(value, unit)
    return math.floor((value + unit / 2) / unit) * unit
end

local function normalize_crop(crop)
    local w, h, x, y = crop_parts(crop)
    if not w then return crop end
    return string.format("%d:%d:%d:%d", w, round_nearest(h, 4), x, y)
end

local function same_crop_state(left, right)
    if left == right then return true end
    if not left or not right then return false end
    local lw, lh, lx, ly = crop_parts(normalize_crop(left))
    local rw, rh, rx, ry = crop_parts(normalize_crop(right))
    if not lw or not rw then return false end
    return math.abs(lw - rw) <= 8
        and math.abs(lh - rh) <= 8
        and math.abs(lx - rx) <= 4
        and math.abs(ly - ry) <= 4
end

local function is_full_frame_crop(crop)
    crop = normalize_crop(crop)
    local w, h, x, y = crop_parts(crop)
    local sw, sh = source_dimensions(crop)
    if not w or not sw or not sh then return false end
    return x == 0 and y == 0 and w == sw and h == sh
end

source_dimensions = function(crop)
    local params = mp.get_property_native("video-params")
    local has_video_params = params and params.w and params.h
    if has_video_params then
        source_width = math.max(source_width or 0, params.w)
        source_height = math.max(source_height or 0, params.h)
    end

    local w, h, x, y = crop and crop_parts(crop) or nil
    if w and h and x and y and not has_video_params then
        source_width = math.max(source_width or 0, w + (2 * x))
        source_height = math.max(source_height or 0, h + (2 * y))
    end

    return source_width, source_height
end

local function safe_active_crop(crop)
    local w, h, x, y = crop_parts(crop)
    local sw, sh = source_dimensions(crop)
    if not w or not sw or not sh then return false end
    if x < 0 or y < 0 or w > sw or h > sh then return false end
    if w == sw and h == sh then return false end

    local right = sw - w - x
    local bottom = sh - h - y
    local aspect = w / h
    local removed_ratio = 1 - ((w * h) / (sw * sh))
    return right >= 0
        and bottom >= 0
        and math.abs(x - right) <= opts.symmetry_tolerance
        and math.abs(y - bottom) <= opts.symmetry_tolerance
        and aspect >= opts.min_letterbox_aspect
        and aspect <= opts.max_letterbox_aspect
        and removed_ratio >= opts.min_letterbox_crop_ratio
end

local function target_aspect(sw, sh)
    if opts.panscan_target_aspect and opts.panscan_target_aspect > 0 then
        return opts.panscan_target_aspect
    end

    local _osd_width, _osd_height, aspect = mp.get_osd_size()
    local source_aspect = sw / sh
    if aspect and aspect > source_aspect then
        return aspect
    end
    return source_aspect
end

local function panscan_for_crop(crop)
    if is_full_frame_crop(crop) then
        return opts.panscan_full
    end
    if safe_active_crop(crop) then
        local w, h = crop_parts(crop)
        local sw, sh = source_dimensions(crop)
        if not w or not h or not sw or not sh then return opts.panscan_letterbox end

        local source_aspect = sw / sh
        local crop_aspect = w / h
        local target = target_aspect(sw, sh)
        if crop_aspect <= source_aspect or target <= source_aspect then
            return opts.panscan_full
        end

        local amount = (crop_aspect - source_aspect) / (target - source_aspect)
        return clamp(amount, opts.panscan_full, opts.panscan_letterbox)
    end
    return nil
end

local function transform_for_crop(crop, panscan)
    local w, h, x, y = crop_parts(crop)
    local sw, sh = source_dimensions(crop)
    if not w or not h or not sw or not sh then return nil end
    if w <= 0 or h <= 0 or sw <= 0 or sh <= 0 then return nil end

    local full_zoom = math.log(math.max(sw / w, sh / h)) / math.log(2)
    local zoom = full_zoom * panscan
    local center_x = x + (w / 2)
    local center_y = y + (h / 2)
    local pan_x = -((center_x - (sw / 2)) / sw) * panscan
    local pan_y = -((center_y - (sh / 2)) / sh) * panscan
    return zoom, pan_x, pan_y
end

local function apply_render_crop(crop, panscan)
    if opts.apply_mode == "transform" then
        local zoom, pan_x, pan_y = transform_for_crop(crop, panscan)
        if not zoom then return nil end
        set_panscan(opts.panscan_full)
        mp.set_property_number("video-zoom", zoom)
        mp.set_property_number("video-pan-x", pan_x)
        mp.set_property_number("video-pan-y", pan_y)
        return zoom, pan_x, pan_y
    end

    reset_transform()
    mp.set_property("video-crop", video_crop_rect(crop))
    set_panscan(panscan)
    return nil, nil, nil
end

local function restore_render_crop()
    if opts.apply_mode == "transform" then
        set_panscan(opts.panscan_full)
        reset_transform()
        return
    end

    mp.set_property("video-crop", "")
    set_panscan(opts.panscan_full)
    reset_transform()
end

local function json_string(value)
    return string.format("%q", value)
end

local function current_crop_state()
    if last_crop then return last_crop end
    if pending_events[1] and pending_events[1].crop then return pending_events[1].crop end
    local sw, sh = source_dimensions(nil)
    if not sw or not sh then return nil end
    return string.format("%d:%d:0:0", sw, sh)
end

local function full_frame_crop()
    local sw, sh = source_dimensions(nil)
    if not sw or not sh then return nil end
    return string.format("%d:%d:0:0", sw, sh)
end

local function remember_applied_timeline(timing)
    if not timing or not timing.needed_at then return end
    last_applied_needed_at = math.max(last_applied_needed_at or -math.huge, timing.needed_at)
end

local function stale_timeline_event(needed_at)
    if not last_applied_needed_at then return false end
    return needed_at <= last_applied_needed_at + (frame_duration_seconds() / 2)
end

local function apply_crop(crop, timing)
    crop = normalize_crop(crop)
    if crop == last_crop then return end
    local panscan = panscan_for_crop(crop)

    if is_full_frame_crop(crop) then
        if last_crop then
            restore_render_crop()
            last_crop = nil
            restore_after_seek = false
            remember_applied_timeline(timing)
            log(string.format("restored mode=%s panscan=%.3f crop=%s", opts.apply_mode, opts.panscan_full, crop))
            if timing then
                local applied_at = mp.get_property_number("time-pos", timing.apply_at)
                telemetry(string.format(
                    "panscan_restore crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f scheduled_at=%.3f applied_at=%.3f detect_lag=%.3fs apply_lag=%.3fs schedule_delay=%.3fs remux=%.3fs analyze=%.3fs detector=%s apply_mode=%s",
                    crop,
                    opts.panscan_full,
                    timing.needed_at,
                    timing.detected_at,
                    timing.apply_at,
                    applied_at,
                    timing.detected_at - timing.needed_at,
                    applied_at - timing.needed_at,
                    timing.apply_at - timing.detected_at,
                    timing.remux_seconds or -1,
                    timing.analyze_seconds or -1,
                    timing.detector_version or "unknown",
                    opts.apply_mode
                ))
            end
        end
        return
    end

    if not panscan then
        log("rejected unsafe crop=" .. crop)
        return
    end

    local zoom, pan_x, pan_y = apply_render_crop(crop, panscan)
    if opts.apply_mode == "transform" and not zoom then
        log("rejected transform crop=" .. crop)
        return
    end
    last_crop = crop
    restore_after_seek = false
    remember_applied_timeline(timing)
    if opts.apply_mode == "transform" then
        log(string.format("applied transform zoom=%.6f pan_x=%.6f pan_y=%.6f panscan=%.3f crop=%s", zoom, pan_x, pan_y, panscan, crop))
    else
        log(string.format("applied panscan=%.3f crop=%s", panscan, crop))
    end
    if timing then
        local applied_at = mp.get_property_number("time-pos", timing.apply_at)
        telemetry(string.format(
            "panscan_timing crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f scheduled_at=%.3f applied_at=%.3f detect_lag=%.3fs apply_lag=%.3fs schedule_delay=%.3fs remux=%.3fs analyze=%.3fs detector=%s apply_mode=%s zoom=%.6f pan_x=%.6f pan_y=%.6f",
            crop,
            panscan,
            timing.needed_at,
            timing.detected_at,
            timing.apply_at,
            applied_at,
            timing.detected_at - timing.needed_at,
            applied_at - timing.needed_at,
            timing.apply_at - timing.detected_at,
            timing.remux_seconds or -1,
            timing.analyze_seconds or -1,
            timing.detector_version or "unknown",
            opts.apply_mode,
            zoom or -1,
            pan_x or 0,
            pan_y or 0
        ))
    end
    if runtime_mode == "one_shot" and not one_shot_locked then
        one_shot_locked = true
        stop_runtime_scans()
        telemetry("mode=one-shot locked crop=" .. crop .. " version=" .. script_version)
        mp.osd_message("Dynamic crop: one-shot locked")
    end
end

local function drain_pending_events(now)
    if not scans_allowed() then return end
    local changed = false
    while pending_events[1] and pending_events[1].apply_at <= now do
        local event = table.remove(pending_events, 1)
        changed = true
        if not stale_timeline_event(event.timing.needed_at) and not same_crop_state(event.crop, last_crop) then
            apply_crop(event.crop, event.timing)
            if not scans_allowed() then break end
        end
    end
    if changed then
        pending_crop = nil
        pending_at = nil
        if pending_timer then
            pending_timer:kill()
            pending_timer = nil
        end
        schedule_next_pending()
    end
end

schedule_next_pending = function()
    if not scans_allowed() then
        clear_pending_events()
        return
    end
    if pending_timer or #pending_events == 0 then return end

    local event = pending_events[1]
    local now = mp.get_property_number("time-pos", event.timing.detected_at)
    local delay = math.max(0, event.apply_at - now)
    pending_crop = event.crop
    pending_at = event.apply_at
    pending_timer = mp.add_timeout(delay, function()
        pending_timer = nil
        drain_pending_events(mp.get_property_number("time-pos", 0))
        if #pending_events == 0 then
            pending_crop = nil
            pending_at = nil
        end
        schedule_next_pending()
    end)
end

local function upsert_pending_event(crop, apply_at, timing)
    local tolerance = frame_duration_seconds()
    for index, event in ipairs(pending_events) do
        if math.abs(event.apply_at - apply_at) <= tolerance then
            if (timing.detected_at or 0) > (event.timing.detected_at or 0) then
                pending_events[index] = {
                    crop = crop,
                    apply_at = apply_at,
                    timing = timing,
                }
            end
            return
        end
    end

    table.insert(pending_events, {
        crop = crop,
        apply_at = apply_at,
        timing = timing,
    })
end

local function enqueue_pending_crop(crop, apply_at, timing)
    upsert_pending_event(crop, apply_at, timing)
    table.sort(pending_events, function(left, right)
        return left.apply_at < right.apply_at
    end)

    if pending_timer and pending_events[1] and pending_events[1].apply_at < (pending_at or math.huge) then
        pending_timer:kill()
        pending_timer = nil
        pending_crop = nil
        pending_at = nil
    end

    schedule_next_pending()
end

local function build_args(path, start)
    return {
        expand_path(opts.binary), "analyze", path,
        "--start", string.format("%.3f", start),
        "--duration", tostring(opts.scan_seconds),
        "--threshold", tostring(opts.detect_limit),
        "--round-to", tostring(opts.detect_round),
        "--sample-step", tostring(opts.sample_step),
        "--min-votes", tostring(opts.min_votes),
        "--timing",
    }
end

local function build_request(path, start)
    local current_crop = current_crop_state()
    local current_crop_json = current_crop and json_string(current_crop) or "null"
    return string.format(
        '{"source":%s,"start":%.3f,"duration":%s,"threshold":%s,"round_to":%s,"sample_step":%s,"min_votes":%s,"current_crop":%s,"timeline":true}\n',
        json_string(path),
        start,
        tostring(opts.read_ahead_seconds),
        tostring(opts.detect_limit),
        tostring(opts.detect_round),
        tostring(opts.sample_step),
        tostring(opts.min_votes),
        current_crop_json
    )
end

local function start_daemon()
    if daemon_started then return end
    daemon_started = true
    mp.command_native({
        name = "subprocess",
        args = {
            expand_path(opts.binary),
            "daemon",
            "--socket-path",
            opts.socket,
            "--idle-timeout",
            tostring(opts.daemon_idle_timeout),
        },
        detach = true,
        playback_only = false,
    })
end

local function socket_ready()
    return utils.file_info(opts.socket) ~= nil
end

local function queue_crop(crop, scan_start, parsed)
    if not scans_allowed() then return end
    local relative_seconds = tonumber(parsed.relative_seconds) or 0
    crop = normalize_crop(crop)
    if is_full_frame_crop(crop) and not last_crop and #pending_events == 0 then return end
    if not is_full_frame_crop(crop) and not safe_active_crop(crop) then
        if not last_crop and #pending_events == 0 then
            log("rejected unsafe crop=" .. crop)
            return
        end
        local full_crop = full_frame_crop()
        if not full_crop then
            log("rejected unsafe crop without source dimensions=" .. crop)
            return
        end
        log("unsafe crop restores full frame crop=" .. crop)
        crop = normalize_crop(full_crop)
    end
    local needed_at = scan_start + relative_seconds
    if stale_timeline_event(needed_at) then return end
    local now = mp.get_property_number("time-pos", scan_start)
    local is_full_frame = is_full_frame_crop(crop)
    local immediate_seek_restore = is_full_frame and restore_after_seek and last_crop
    if not is_full_frame and restore_after_seek then
        restore_after_seek = false
    end
    if same_crop_state(crop, last_crop) then
        restore_after_seek = false
        return
    end
    if is_full_frame and last_crop and not immediate_seek_restore and (needed_at - now) < opts.restore_min_lead_seconds then
        log(string.format(
            "restore_ignored reason=short_lead crop=%s needed_at=%.3f detected_at=%.3f lead=%.3f min_lead=%.3f version=%s",
            crop,
            needed_at,
            now,
            needed_at - now,
            opts.restore_min_lead_seconds,
            script_version
        ))
        return
    end
    if is_full_frame and not immediate_seek_restore and now >= needed_at then
        log(string.format(
            "restore_ignored reason=late_full crop=%s needed_at=%.3f detected_at=%.3f relative=%.3f head_guard=%.3f tail_guard=%.3f version=%s",
            crop,
            needed_at,
            now,
            relative_seconds,
            opts.restore_head_guard_seconds,
            opts.restore_tail_guard_seconds,
            script_version
        ))
        return
    end
    if is_full_frame and not immediate_seek_restore and relative_seconds <= opts.restore_head_guard_seconds then
        log(string.format(
            "restore_ignored reason=head_guard crop=%s needed_at=%.3f detected_at=%.3f relative=%.3f head_guard=%.3f tail_guard=%.3f version=%s",
            crop,
            needed_at,
            now,
            relative_seconds,
            opts.restore_head_guard_seconds,
            opts.restore_tail_guard_seconds,
            script_version
        ))
        return
    end
    if is_full_frame and not immediate_seek_restore and relative_seconds >= (opts.read_ahead_seconds - opts.restore_tail_guard_seconds) then
        log(string.format(
            "restore_ignored reason=tail_guard crop=%s needed_at=%.3f detected_at=%.3f relative=%.3f head_guard=%.3f tail_guard=%.3f version=%s",
            crop,
            needed_at,
            now,
            relative_seconds,
            opts.restore_head_guard_seconds,
            opts.restore_tail_guard_seconds,
            script_version
        ))
        return
    end
    if opts.restore_grace_seconds > 0 and is_full_frame and last_crop and not immediate_seek_restore then
        if not full_frame_restore_started_at then
            full_frame_restore_started_at = needed_at
        end
        local restore_age = needed_at - full_frame_restore_started_at
        if restore_age < opts.restore_grace_seconds then
            local now = mp.get_property_number("time-pos", scan_start)
            log(string.format(
                "panscan_restore_deferred crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f restore_age=%.3fs restore_grace=%.3fs",
                crop,
                opts.panscan_full,
                needed_at,
                now,
                restore_age,
                opts.restore_grace_seconds
            ))
            return
        end
    else
        full_frame_restore_started_at = nil
    end

    local apply_before = opts.apply_before_seconds
    if is_full_frame and last_crop then
        apply_before = opts.restore_before_seconds
    end
    apply_before = apply_before + (opts.presentation_lead_frames * frame_duration_seconds())

    local apply_at = needed_at - apply_before
    local timing = {
        needed_at = needed_at,
        detected_at = now,
        apply_at = apply_at,
        remux_seconds = tonumber(parsed.remux_seconds),
        analyze_seconds = tonumber(parsed.analyze_seconds),
        detector_version = tostring(parsed.detector_version or "unknown"),
    }
    log(string.format(
        "panscan_needed crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f scheduled_at=%.3f detect_lag=%.3fs schedule_delay=%.3fs remux=%.3fs analyze=%.3fs detector=%s",
        crop,
        panscan_for_crop(crop) or -1,
        timing.needed_at,
        timing.detected_at,
        timing.apply_at,
        timing.detected_at - timing.needed_at,
        timing.apply_at - timing.detected_at,
        timing.remux_seconds or -1,
        timing.analyze_seconds or -1,
        timing.detector_version
    ))
    enqueue_pending_crop(crop, apply_at, timing)
end

local function queue_timeline_events(events, scan_start)
    if not scans_allowed() then return end
    local now = mp.get_property_number("time-pos", scan_start)
    local newest_past_index = nil
    local newest_past_needed_at = -math.huge
    local prepared = {}

    for _, event in ipairs(events) do
        if event.crop then
            local relative_seconds = tonumber(event.relative_seconds) or 0
            local needed_at = scan_start + relative_seconds
            table.insert(prepared, {event = event, needed_at = needed_at})
            if needed_at <= now and needed_at > newest_past_needed_at then
                newest_past_needed_at = needed_at
                newest_past_index = #prepared
            end
        end
    end

    local filtered = {}
    local index = 1
    local previous_crop = current_crop_state()
    while index <= #prepared do
        local current = prepared[index]
        local following = prepared[index + 1]
        if following
            and previous_crop
            and same_crop_state(normalize_crop(following.event.crop), previous_crop)
            and (following.needed_at - current.needed_at) <= opts.transient_revert_seconds
        then
            index = index + 2
        else
            table.insert(filtered, current)
            previous_crop = normalize_crop(current.event.crop)
            index = index + 1
        end
    end
    prepared = filtered
    newest_past_index = nil
    newest_past_needed_at = -math.huge
    for index, prepared_event in ipairs(prepared) do
        if prepared_event.needed_at <= now and prepared_event.needed_at > newest_past_needed_at then
            newest_past_needed_at = prepared_event.needed_at
            newest_past_index = index
        end
    end

    for index, prepared_event in ipairs(prepared) do
        if prepared_event.needed_at > now or index == newest_past_index then
            queue_crop(normalize_crop(prepared_event.event.crop), scan_start, prepared_event.event)
        end
    end
end

local function run_scan()
    if running or not scans_allowed() then return end
    if playback_ended() then return end

    local path = selected_path()
    local playback_pos = mp.get_property_number("time-pos", 0)
    if not path or not playback_pos then return end
    local scan_start = playback_pos + opts.scan_ahead_seconds

    running = true
    start_daemon()
    log(string.format("scan playback=%.3f start=%.3f", playback_pos, scan_start))

    if not socket_ready() then
        running = false
        mp.add_timeout(0.25, run_scan)
        return
    end

    mp.command_native_async({
        name = "subprocess",
        args = {"ncat", "-U", opts.socket},
        stdin_data = build_request(path, scan_start),
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
    }, function(success, result, error)
        running = false
        if not scans_allowed() then
            release_startup_pause()
            return
        end
        if playback_ended() then return end

        if not success or result.status ~= 0 then
            daemon_started = false
            if opts.debug then
                mp.msg.warn(
                    "cuda crop socket failed: status="
                    .. tostring(result and result.status)
                    .. " stderr="
                    .. tostring(result and result.stderr)
                    .. " error="
                    .. tostring(error)
                )
            end
            local args = build_args(path, scan_start)
            mp.command_native_async({
                name = "subprocess",
                args = args,
                capture_stdout = true,
                capture_stderr = true,
                playback_only = false,
            }, function(fallback_success, fallback_result, fallback_error)
                if not scans_allowed() then
                    release_startup_pause()
                    return
                end
                if not fallback_success or fallback_result.status ~= 0 then
                    record_scan_failure(tostring(fallback_error or fallback_result.error_string or fallback_result.status))
                    mp.msg.warn(
                        "cuda crop scan failed: "
                        .. tostring(fallback_error or fallback_result.error_string or fallback_result.status)
                    )
                    release_startup_pause()
                    return
                end
                scan_failures = 0

                local fallback_json = (fallback_result.stdout or ""):match("(%b{})")
                local fallback_parsed = fallback_json and utils.parse_json(fallback_json) or nil
                if fallback_parsed and fallback_parsed.crop then
                    apply_crop(normalize_crop(fallback_parsed.crop))
                else
                    log("no stable crop found")
                end
                release_startup_pause()
            end)
            return
        end

        local json = (result.stdout or ""):match("(%b{})")
        local parsed = json and utils.parse_json(json) or nil
        if parsed and parsed.ok and parsed.events then
            scan_failures = 0
            queue_timeline_events(parsed.events, scan_start)
            release_startup_pause()
        elseif parsed and parsed.ok and parsed.crop then
            scan_failures = 0
            queue_crop(normalize_crop(parsed.crop), scan_start, parsed)
            release_startup_pause()
        else
            log("no stable crop found")
            release_startup_pause()
        end
    end)
end

local function schedule()
    if not scans_allowed() then return end
    if timer then timer:kill() end
    timer = mp.add_periodic_timer(opts.scan_interval, function()
        run_scan()
    end)
    start_daemon()
    mp.add_timeout(0.25, run_scan)
end

mp.observe_property("time-pos", "number", function(_name, value)
    if value and scans_allowed() then
        drain_pending_events(value)
    end
end)

local function mode_message()
    if runtime_mode == "one_shot" then
        return one_shot_locked and "Dynamic crop: one-shot locked" or "Dynamic crop: one-shot waiting"
    elseif runtime_mode == "disabled" then
        return "Dynamic crop: disabled"
    end
    return "Dynamic crop: continuous"
end

local function mode_button_icon()
    if runtime_mode == "disabled" then return "crop_free" end
    if runtime_mode == "one_shot" then return "crop_square" end
    return "crop_16_9"
end

local function mode_button_active()
    return runtime_mode ~= "disabled"
end

local function publish_uosc_button()
    local data = {
        icon = mode_button_icon(),
        active = mode_button_active(),
        tooltip = mode_message(),
        command = "script-binding dynamic_crop/cycle-mode",
    }
    mp.commandv("script-message-to", "uosc", "set-button", "dynamic_crop", utils.format_json(data))
end

local function set_runtime_mode(mode)
    if mode == "disabled" then
        runtime_mode = "disabled"
        opts.enabled = false
        stop_runtime_scans()
        remove_crop()
    elseif mode == "one_shot" then
        runtime_mode = "one_shot"
        opts.enabled = true
        if last_crop then
            one_shot_locked = true
            stop_runtime_scans()
        else
            one_shot_locked = false
            if not timer then schedule() end
        end
    else
        runtime_mode = "continuous"
        opts.enabled = true
        one_shot_locked = false
        reset_crop_state()
        schedule()
    end

    local message = mode_message()
    telemetry("mode=" .. runtime_mode .. " locked=" .. tostring(one_shot_locked) .. " version=" .. script_version)
    mp.osd_message(message)
    publish_uosc_button()
end

local function cycle_runtime_mode()
    if runtime_mode == "continuous" then
        set_runtime_mode("one_shot")
    elseif runtime_mode == "one_shot" then
        set_runtime_mode("disabled")
    else
        set_runtime_mode("continuous")
    end
end

local function scan_result_is_current(scan_start)
    local now = mp.get_property_number("time-pos", scan_start)
    local tolerance = math.max(opts.read_ahead_seconds + opts.scan_interval + 1.0, 5.0)
    return math.abs(now - scan_start) <= tolerance, now, tolerance
end

local function reset_timeline_after_seek()
    if not scans_allowed() then return end
    clear_pending_events()
    last_applied_needed_at = nil
    restore_after_seek = last_crop ~= nil
    log(string.format(
        "seek_reset crop=%s restore_after_seek=%s version=%s",
        tostring(last_crop),
        tostring(restore_after_seek),
        script_version
    ))
end

mp.register_event("seek", reset_timeline_after_seek)

mp.register_script_message("timeline-events", function(payload, scan_start_text)
    local scan_start = tonumber(scan_start_text)
    local parsed = payload and utils.parse_json(payload) or nil
    if scan_start then
        local current, now, tolerance = scan_result_is_current(scan_start)
        if not current then
            log(string.format(
                "stale_scan_ignored scan_start=%.3f now=%.3f tolerance=%.3f version=%s",
                scan_start,
                now,
                tolerance,
                script_version
            ))
            release_startup_pause()
            return
        end
    end
    if parsed and parsed.ok and parsed.events and scan_start then
        scan_failures = 0
        queue_timeline_events(parsed.events, scan_start)
    elseif opts.debug then
        log("sidecar found no stable crop")
    end
    release_startup_pause()
end)

mp.register_event("file-loaded", function()
    source_width = nil
    source_height = nil
    scan_failures = 0
    publish_uosc_button()
    telemetry(string.format(
        "loaded version=%s mode=%s apply_mode=%s key=%s head_guard=%.3f min_lead=%.3f tail_guard=%.3f transient_revert=%.3f scan_interval=%.3f",
        script_version,
        runtime_mode,
        opts.apply_mode,
        opts.cycle_key,
        opts.restore_head_guard_seconds,
        opts.restore_min_lead_seconds,
        opts.restore_tail_guard_seconds,
        opts.transient_revert_seconds,
        opts.scan_interval
    ))
    if opts.backend == "legacy" then
        start_legacy_backend("legacy backend selected")
    elseif opts.apply_mode ~= "panscan" and opts.apply_mode ~= "transform" then
        start_legacy_backend("unsupported apply mode selected: " .. tostring(opts.apply_mode))
    elseif opts.enabled and runtime_mode ~= "disabled" and not cuda_binary_available() then
        start_legacy_backend("missing CUDA analyzer binary: " .. opts.binary)
    elseif opts.enabled and runtime_mode ~= "disabled" then
        reset_crop_state()
        if runtime_mode == "one_shot" then one_shot_locked = false end
        hold_startup_until_first_scan()
        if opts.scan_driver == "sidecar" then
            start_sidecar()
        else
            schedule()
        end
    end
end)

mp.register_event("end-file", function()
    stop_sidecar()
    if timer then
        timer:kill()
        timer = nil
    end
    remove_crop()
end)

mp.add_key_binding(opts.cycle_key ~= "" and opts.cycle_key or nil, "cycle-mode", cycle_runtime_mode)
mp.register_script_message("cycle-mode", cycle_runtime_mode)
mp.register_script_message("set-mode", function(mode)
    if mode == "continuous" or mode == "one_shot" or mode == "disabled" then
        set_runtime_mode(mode)
    end
end)
mp.register_script_message("uosc-version", function()
    publish_uosc_button()
end)
