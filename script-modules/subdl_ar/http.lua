-- subdl_ar.http: async HTTP layer with rate-limit header capture and
-- automatic backup-key rotation on quota exhaustion.
--
-- Provides:
--   request_async(url, opts, on_done)      – raw async GET
--   request_async_json(url, opts, on_done) – async GET with JSON parse
--
-- opts keys:
--   api_key     – Authorization: Bearer <key>  (required)
--   backup_key  – fallback key on 429/quota_exceeded  (optional)
--   headers     – extra curl headers  (optional table)
--   osd_label   – if set, show OSD overlay during request  (optional)
--   timeout     – curl --max-time override  (optional, default 20)
--
-- Version guard: if mp.command_native_async is nil (old mpv), falls back
-- to synchronous utils.subprocess with a one-time warning.

local mp = require "mp"
local utils = require "mp.utils"

local M = {}

local CURL_TIMEOUT = 10

-- One-time warning for old mpv without async support.
local _warned_sync_fallback = false

-- ---------------------------------------------------------------------------
-- Internal: build curl args for a URL with Bearer auth + header capture.
-- ---------------------------------------------------------------------------
local function build_curl_args(url, api_key, extra_headers, timeout)
  local args = {
    "curl", "-sS", "-D", "-",
    "--connect-timeout", tostring(CURL_TIMEOUT),
    "--max-time", tostring(timeout or CURL_TIMEOUT * 2),
    "-H", "Authorization: Bearer " .. api_key,
  }
  if extra_headers then
    for _, h in ipairs(extra_headers) do
      table.insert(args, "-H")
      table.insert(args, h)
    end
  end
  table.insert(args, url)
  return args
end

-- ---------------------------------------------------------------------------
-- Internal: parse curl -D - output.
-- Returns (body, http_code, headers_table).
-- The output format is: <headers>\n\n<body>\n<http_code>
-- ---------------------------------------------------------------------------
local function parse_curl_output(stdout)
  if not stdout or stdout == "" then
    return nil, 0, {}
  end

  -- Split into lines (filter out empty trailing match from gmatch)
  local lines = {}
  for line in stdout:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end
  if #lines == 0 then return nil, 0, {} end

  local headers = {}
  local header_end = 1
  local http_code = 0

  -- Look for a blank line that separates HTTP headers from body (curl -D -).
  -- If the first line looks like "HTTP/1.1 200 OK" we're in header mode.
  local first_line = lines[1] or ""
  local has_headers = first_line:match("^HTTP/%S+") ~= nil

  if has_headers then
    for i, line in ipairs(lines) do
      if line:match("^%s*$") or line == "\r" then
        header_end = i + 1
        break
      end
      local key, value = line:match("^([^:]+):%s*(.-)%s*$")
      if key then
        headers[key:lower()] = value
      end
      local code = line:match("^HTTP/%S+ (%d+)")
      if code then http_code = tonumber(code) end
    end
  end

  local body_parts = {}
  for i = header_end, #lines do
    body_parts[#body_parts + 1] = lines[i]
  end
  local body = table.concat(body_parts, "\n")
  body = body:gsub("%s+$", "")

  -- Fallback: extract trailing HTTP code (e.g. from curl -w "\n%{http_code}")
  if http_code == 0 and body ~= "" then
    local extracted_code = body:match("\n(%d%d%d)%s*$")
    if extracted_code then
      http_code = tonumber(extracted_code)
      body = body:gsub("\n%d%d%d%s*$", "")
    end
  end

  return body, http_code, headers
end

-- ---------------------------------------------------------------------------
-- Internal: parse JSON body + extract http_code from "-w \n%{http_code}".
-- Returns (json_table_or_nil, http_code).
-- ---------------------------------------------------------------------------
local function parse_json_response(stdout)
  if not stdout or stdout == "" then return nil, 0 end
  local body, code = stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
  if not body then return nil, 0 end
  local json = utils.parse_json(body)
  return json, tonumber(code or 0)
end

-- ---------------------------------------------------------------------------
-- Internal: check if response indicates rate limit / quota exhaustion.
-- ---------------------------------------------------------------------------
local function is_rate_limited(json, http_code, headers)
  if http_code == 429 then return true end
  if json and json.status == false then
    local err_code = json.error and json.error.code and tostring(json.error.code):lower() or ""
    local err_msg = json.error and type(json.error) == "string" and json.error:lower() or ""
    if err_code:find("quota_exceeded") or err_code:find("rate") or err_code:find("limit")
       or err_msg:find("quota_exceeded") or err_msg:find("rate") or err_msg:find("limit") then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Internal: check if response is a successful JSON response.
-- ---------------------------------------------------------------------------
local function is_success(http_code)
  return http_code >= 200 and http_code < 300
end

-- ---------------------------------------------------------------------------
-- request_async(url, opts, on_done)
--   on_done(success, result)
--   result = { status, stdout, stderr, headers, remaining, reset }
-- ---------------------------------------------------------------------------
function M.request_async(url, opts, on_done)
  opts = opts or {}
  local api_key = opts.api_key or ""
  local backup_key = opts.backup_key or ""
  local extra_headers = opts.headers
  local osd_label = opts.osd_label
  local timeout = opts.timeout

  -- OSD overlay
  local overlay
  if osd_label and mp.create_osd_overlay then
    overlay = mp.create_osd_overlay("ass-events")
    if overlay then
      overlay:update({ data = osd_label })
    end
  end

  -- Version guard: fall back to sync if command_native_async is nil
  if mp.command_native_async == nil then
    if not _warned_sync_fallback then
      mp.msg.warn("subdl_ar: mp.command_native_async unavailable, using sync fallback")
      _warned_sync_fallback = true
    end

    -- Sync fallback
    local args = build_curl_args(url, api_key, extra_headers, timeout)
    local res = utils.subprocess({ args = args, cancellable = false })
    local body, http_code, headers = parse_curl_output(res.stdout)
    local remaining = headers["x-ratelimit-remaining"]
    local reset = headers["x-ratelimit-reset"]

    if overlay then overlay:remove() end

    local json = body and utils.parse_json(body) or nil
    if is_rate_limited(json, http_code, headers) and backup_key ~= "" and backup_key ~= api_key then
      mp.msg.info("subdl_ar: rate limited, retrying with backup key")
      local retry_args = build_curl_args(url, backup_key, extra_headers, timeout)
      local retry_res = utils.subprocess({ args = retry_args, cancellable = false })
      body, http_code, headers = parse_curl_output(retry_res.stdout)
      remaining = headers["x-ratelimit-remaining"]
      reset = headers["x-ratelimit-reset"]
    end

    local success = res.status == 0 and body ~= nil
    if on_done then
      on_done(success, {
        status = res.status,
        stdout = res.stdout or "",
        stderr = res.stderr or "",
        headers = headers,
        remaining = remaining,
        reset = reset,
        body = body,
        http_code = http_code,
      })
    end
    return nil
  end

  -- Async path
  local args = build_curl_args(url, api_key, extra_headers, timeout)
  local handle

  local function do_request(curl_args, key_used, is_retry)
    handle = mp.command_native_async({
      name = "subprocess",
      args = curl_args,
      capture_stdout = true,
      playback_only = false,
    }, function(res)
      local body, http_code, headers = parse_curl_output(res.stdout)
      local remaining = headers["x-ratelimit-remaining"]
      local reset = headers["x-ratelimit-reset"]

      local json = body and utils.parse_json(body) or nil

      -- Check for rate limit → rotate and retry once
      if not is_retry and is_rate_limited(json, http_code, headers)
         and backup_key ~= "" and backup_key ~= key_used then
        mp.msg.info("subdl_ar: rate limited, retrying with backup key")
        local retry_args = build_curl_args(url, backup_key, extra_headers, timeout)
        if overlay then overlay:update({ data = "Retrying with backup key..." }) end
        do_request(retry_args, backup_key, true)
        return
      end

      if overlay then overlay:remove() end

      local success = res.status == 0 and body ~= nil
      if on_done then
        on_done(success, {
          status = res.status,
          stdout = res.stdout or "",
          stderr = res.stderr or "",
          headers = headers,
          remaining = remaining,
          reset = reset,
          body = body,
          http_code = http_code,
        })
      end
    end)
  end

  do_request(args, api_key, false)
  return handle
end

-- ---------------------------------------------------------------------------
-- request_async_json(url, opts, on_done)
--   on_done(success, json, http_code, remaining)
-- Convenience wrapper that parses the JSON body automatically.
-- ---------------------------------------------------------------------------
function M.request_async_json(url, opts, on_done)
  return M.request_async(url, opts, function(success, result)
    if not success or not result.body then
      if on_done then on_done(false, nil, 0, nil) end
      return
    end
    local json = utils.parse_json(result.body)
    if not json then
      if on_done then on_done(false, nil, result.http_code or 0, result.remaining) end
      return
    end
    if on_done then on_done(true, json, result.http_code or 0, result.remaining) end
  end)
end

return M
