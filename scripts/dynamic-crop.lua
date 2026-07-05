local mp = require "mp"
local options = require "mp.options"
local utils = require "mp.utils"

local opts = {
    enabled = true,
    backend = "cuda",
    project = "/home/btw/mhm/cuda-crop-py",
    binary = "/home/btw/mhm/cuda-crop-py/.venv/bin/cuda-crop-py",
    socket = "/tmp/cuda-crop-py.sock",
    daemon_idle_timeout = 10.0,
    legacy_script = "~~/script-modules/dynamic-crop-legacy.lua",
    fallback_failures = 2,
    apply_mode = "panscan",
    panscan_letterbox = 1.0,
    panscan_full = 0.0,
    panscan_target_aspect = 2.333333,
    scan_ahead_seconds = 2.0,
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
    telemetry = true,
    debug = false,
}

options.read_options(opts)

local label = "dynamic_crop_cuda_crop"
local timer = nil
local running = false
local last_crop = nil
local daemon_started = false
local legacy_started = false
local scan_failures = 0
local pending_timer = nil
local pending_crop = nil
local pending_at = nil
local pending_events = {}
local source_width = nil
local source_height = nil
local full_frame_restore_started_at = nil
local source_dimensions
local remove_crop

local function set_panscan(value)
    mp.set_property("panscan", string.format("%.3f", value))
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

local function stop_cuda_timers()
    if timer then
        timer:kill()
        timer = nil
    end
    if pending_timer then
        pending_timer:kill()
        pending_timer = nil
    end
    pending_crop = nil
    pending_at = nil
    pending_events = {}
    full_frame_restore_started_at = nil
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
    local info = utils.file_info(opts.binary)
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
    return mp.command_native({"expand-path", path})
end

remove_crop = function()
    if pending_timer then
        pending_timer:kill()
        pending_timer = nil
    end
    pending_crop = nil
    pending_at = nil
    pending_events = {}
    full_frame_restore_started_at = nil
    mp.set_property("video-crop", "")
    mp.set_property("video-aspect-override", "-2")
    set_panscan(opts.panscan_full)
    last_crop = nil
end

local function reset_crop_state()
    if pending_timer then
        pending_timer:kill()
        pending_timer = nil
    end
    pending_crop = nil
    pending_at = nil
    pending_events = {}
    last_crop = nil
    full_frame_restore_started_at = nil
    mp.set_property("video-crop", "")
    mp.set_property("video-aspect-override", "-2")
    set_panscan(opts.panscan_full)
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

local function json_string(value)
    return string.format("%q", value)
end

local function current_crop_state()
    if last_crop then return last_crop end
    local sw, sh = source_dimensions(nil)
    if not sw or not sh then return nil end
    return string.format("%d:%d:0:0", sw, sh)
end

local function full_frame_crop()
    local sw, sh = source_dimensions(nil)
    if not sw or not sh then return nil end
    return string.format("%d:%d:0:0", sw, sh)
end

local function apply_crop(crop, timing)
    crop = normalize_crop(crop)
    if crop == last_crop then return end
    local panscan = panscan_for_crop(crop)

    if is_full_frame_crop(crop) then
        if last_crop then
            mp.set_property("video-crop", "")
            set_panscan(opts.panscan_full)
            last_crop = nil
            log(string.format("restored panscan=%.3f crop=%s", opts.panscan_full, crop))
            if timing then
                local applied_at = mp.get_property_number("time-pos", timing.apply_at)
                telemetry(string.format(
                    "panscan_restore crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f scheduled_at=%.3f applied_at=%.3f detect_lag=%.3fs apply_lag=%.3fs schedule_delay=%.3fs remux=%.3fs analyze=%.3fs detector=%s",
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
                    timing.detector_version or "unknown"
                ))
            end
        end
        return
    end

    if not panscan then
        log("rejected unsafe crop=" .. crop)
        return
    end

    mp.set_property("video-crop", video_crop_rect(crop))
    set_panscan(panscan)
    last_crop = crop
    log(string.format("applied panscan=%.3f crop=%s", panscan, crop))
    if timing then
        local applied_at = mp.get_property_number("time-pos", timing.apply_at)
        telemetry(string.format(
            "panscan_timing crop=%s panscan=%.3f needed_at=%.3f detected_at=%.3f scheduled_at=%.3f applied_at=%.3f detect_lag=%.3fs apply_lag=%.3fs schedule_delay=%.3fs remux=%.3fs analyze=%.3fs detector=%s",
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
            timing.detector_version or "unknown"
        ))
    end
end

local function schedule_next_pending()
    if pending_timer or #pending_events == 0 then return end

    local event = pending_events[1]
    local now = mp.get_property_number("time-pos", event.timing.detected_at)
    local delay = math.max(0, event.apply_at - now)
    pending_crop = event.crop
    pending_at = event.apply_at
    pending_timer = mp.add_timeout(delay, function()
        pending_timer = nil
        local next_event = table.remove(pending_events, 1)
        if next_event then
            apply_crop(next_event.crop, next_event.timing)
        end
        pending_crop = nil
        pending_at = nil
        schedule_next_pending()
    end)
end

local function pending_event_exists(crop, apply_at)
    local tolerance = frame_duration_seconds()
    for _, event in ipairs(pending_events) do
        if event.crop == crop and math.abs(event.apply_at - apply_at) <= tolerance then
            return true
        end
    end
    return false
end

local function enqueue_pending_crop(crop, apply_at, timing)
    if pending_event_exists(crop, apply_at) then return end

    table.insert(pending_events, {
        crop = crop,
        apply_at = apply_at,
        timing = timing,
    })
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
        opts.binary, "analyze", path,
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
            opts.binary,
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
    local relative_seconds = tonumber(parsed.relative_seconds) or 0
    crop = normalize_crop(crop)
    if crop == last_crop then return end
    if is_full_frame_crop(crop) and not last_crop then return end
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
    if is_full_frame_crop(crop) and last_crop then
        if not full_frame_restore_started_at then
            full_frame_restore_started_at = needed_at
        end
        local restore_age = needed_at - full_frame_restore_started_at
        if restore_age < opts.restore_grace_seconds then
            local now = mp.get_property_number("time-pos", scan_start)
            telemetry(string.format(
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
    if is_full_frame_crop(crop) and last_crop then
        apply_before = opts.restore_before_seconds
    end
    apply_before = apply_before + (opts.presentation_lead_frames * frame_duration_seconds())

    local apply_at = needed_at - apply_before
    local now = mp.get_property_number("time-pos", scan_start)
    local timing = {
        needed_at = needed_at,
        detected_at = now,
        apply_at = apply_at,
        remux_seconds = tonumber(parsed.remux_seconds),
        analyze_seconds = tonumber(parsed.analyze_seconds),
        detector_version = tostring(parsed.detector_version or "unknown"),
    }
    telemetry(string.format(
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

local function run_scan()
    if running or not opts.enabled then return end

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
        playback_only = true,
    }, function(success, result, error)
        running = false

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
                playback_only = true,
            }, function(fallback_success, fallback_result, fallback_error)
                if not fallback_success or fallback_result.status ~= 0 then
                    record_scan_failure(tostring(fallback_error or fallback_result.error_string or fallback_result.status))
                    mp.msg.warn(
                        "cuda crop scan failed: "
                        .. tostring(fallback_error or fallback_result.error_string or fallback_result.status)
                    )
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
            end)
            return
        end

        local json = (result.stdout or ""):match("(%b{})")
        local parsed = json and utils.parse_json(json) or nil
        if parsed and parsed.ok and parsed.events then
            scan_failures = 0
            for _, event in ipairs(parsed.events) do
                if event.crop then
                    queue_crop(normalize_crop(event.crop), scan_start, event)
                end
            end
        elseif parsed and parsed.ok and parsed.crop then
            scan_failures = 0
            queue_crop(normalize_crop(parsed.crop), scan_start, parsed)
        else
            log("no stable crop found")
        end
    end)
end

local function schedule()
    if timer then timer:kill() end
    timer = mp.add_periodic_timer(opts.scan_interval, function()
        run_scan()
    end)
    start_daemon()
    mp.add_timeout(0.25, run_scan)
end

mp.register_event("file-loaded", function()
    source_width = nil
    source_height = nil
    scan_failures = 0
    if opts.backend == "legacy" then
        start_legacy_backend("legacy backend selected")
    elseif opts.apply_mode ~= "panscan" then
        start_legacy_backend("non-panscan apply mode selected: " .. tostring(opts.apply_mode))
    elseif opts.enabled and not cuda_binary_available() then
        start_legacy_backend("missing CUDA analyzer binary: " .. opts.binary)
    elseif opts.enabled then
        reset_crop_state()
        schedule()
    end
end)

mp.register_event("end-file", function()
    if timer then
        timer:kill()
        timer = nil
    end
    remove_crop()
end)

mp.add_key_binding(nil, "cuda-crop-test-toggle", function()
    opts.enabled = not opts.enabled
    if opts.enabled then
        schedule()
        mp.osd_message("cuda-crop-test enabled")
    else
        if timer then
            timer:kill()
            timer = nil
        end
        remove_crop()
        mp.osd_message("cuda-crop-test disabled")
    end
end)
