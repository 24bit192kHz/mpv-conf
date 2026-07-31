-- Spec: ar_subs.http (async HTTP layer with rate-limit rotation)
--
-- Tests:
--   1. request_async uses mp.command_native_async (not utils.subprocess)
--   2. Response headers parsed: X-RateLimit-Remaining and X-RateLimit-Reset
--   3. HTTP 429 triggers backup key rotation + retry once
--   4. JSON quota_exceeded error triggers backup key rotation
--   5. Version guard: falls back to sync when command_native_async is nil
--   6. OSD overlay created/removed around request lifecycle
--   7. In-flight handle tracked and abortable

local H = require "harness"

-- ---------------------------------------------------------------------------
-- Save and restore state cleanly.
-- ---------------------------------------------------------------------------
local _orig_mp = package.loaded["mp"]
local _orig_mp_utils = package.loaded["mp.utils"]
local _orig_mp_options = package.loaded["mp.options"]
local _orig_http = package.loaded["ar_subs.http"]

-- Build a fresh mp stub using stubs.mp as base, with async support.
local stubs_mp = require "stubs.mp"
package.loaded["ar_subs.http"] = nil

local async_calls = {}
local pending_callbacks = {}
local last_async_handle = 1000

local function flush_callbacks()
  while #pending_callbacks > 0 do
    local entry = table.remove(pending_callbacks, 1)
    -- mpv's command_native_async invokes cb(success, result, error)
    entry.cb(true, entry.result)
  end
end

-- Override command_native_async on the stubs.mp table for async capture.
local _orig_cna = stubs_mp.command_native_async
local _orig_aac = stubs_mp.abort_async_command
local _orig_create_osd = stubs_mp.create_osd_overlay
local _orig_async_result = stubs_mp._async_result

stubs_mp.command_native_async = function(cmd, cb)
  last_async_handle = last_async_handle + 1
  local handle = last_async_handle
  table.insert(async_calls, { cmd = cmd, handle = handle })
  if cb then
    local result = stubs_mp._async_result or { status = 0, stdout = "", stderr = "" }
    table.insert(pending_callbacks, { cb = cb, result = result })
  end
  return handle
end

stubs_mp.abort_async_command = function(handle)
  table.insert(async_calls, { kind = "abort", handle = handle })
end

stubs_mp._async_result = { status = 0, stdout = "", stderr = "" }

local _last_overlay = nil
stubs_mp.create_osd_overlay = function(overlay_type)
  local overlay = { _data = nil, _removed = false }
  function overlay:update(data) overlay._data = data end
  function overlay:remove() overlay._removed = true end
  _last_overlay = overlay
  return overlay
end

package.loaded["mp"] = stubs_mp
package.loaded["mp.utils"] = require "stubs.utils"
package.loaded["mp.options"] = require "stubs.options"

local http = require "ar_subs.http"

-- =========================================================================
-- Test 1: uses command_native_async (not utils.subprocess)
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  stubs_mp._async_result = {
    status = 0,
    stdout = '{"status":true,"subtitles":[]}\n200',
    stderr = "",
  }

  local done = false
  http.request_async("https://api.subdl.com/api/v2/subtitles?test=1", {
    api_key = "TESTKEY",
  }, function(success, result)
    done = true
  end)
  flush_callbacks()
  H.ok("request_async invoked callback", done)
  H.ok("request_async used command_native_async",
       #async_calls > 0 and async_calls[1].cmd ~= nil)
  local used_subprocess = false
  for _, c in ipairs(H.calls) do
    if c.kind == "subprocess" then used_subprocess = true end
  end
  H.ok("request_async did NOT use utils.subprocess", not used_subprocess)
end

-- =========================================================================
-- Test 2: Response headers parsed
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  stubs_mp._async_result = {
    status = 0,
    stdout = 'HTTP/1.1 200 OK\r\nX-RateLimit-Remaining: 42\r\nX-RateLimit-Reset: 1700000060\r\n\r\n{"status":true}',
    stderr = "",
  }

  local captured_result
  http.request_async("https://api.test.com", {
    api_key = "KEY",
  }, function(success, result)
    captured_result = result
  end)
  flush_callbacks()

  H.ok("result has headers table", type(captured_result.headers) == "table")
  H.eq("remaining parsed from headers", captured_result.remaining, "42")
  H.eq("reset parsed from headers", captured_result.reset, "1700000060")
end

-- =========================================================================
-- Test 3: HTTP 429 triggers backup key rotation + retry
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  local call_count = 0

  local orig_cna = stubs_mp.command_native_async
  stubs_mp.command_native_async = function(cmd, cb)
    last_async_handle = last_async_handle + 1
    local handle = last_async_handle
    call_count = call_count + 1
    table.insert(async_calls, { cmd = cmd, handle = handle })
    if cb then
      local result
      if call_count == 1 then
        result = {
          status = 0,
          stdout = '{"error":"rate limited"}\n429',
          stderr = "",
          headers = { ["x-ratelimit-remaining"] = "0" },
        }
      else
        result = {
          status = 0,
          stdout = '{"status":true,"subtitles":[{"id":1}]}\n200',
          stderr = "",
          headers = { ["x-ratelimit-remaining"] = "99" },
        }
      end
      cb(true, result)
    end
    return handle
  end

  local final_result
  http.request_async("https://api.test.com/search", {
    api_key = "PRIMARY_KEY",
    backup_key = "BACKUP_KEY",
  }, function(success, result)
    final_result = result
  end)

  stubs_mp.command_native_async = orig_cna

  H.ok("429 triggered retry", call_count == 2)
  if #async_calls >= 2 then
    local second_cmd = async_calls[2].cmd
    local found_backup = false
    for _, arg in ipairs(second_cmd.args or {}) do
      if type(arg) == "string" and arg:find("BACKUP_KEY") then
        found_backup = true
      end
    end
    H.ok("429 retry uses backup key", found_backup)
  else
    H.ok("429 retry uses backup key", false)
  end
end

-- =========================================================================
-- Test 4: JSON quota_exceeded triggers backup key rotation
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  local call_count = 0

  local orig_cna = stubs_mp.command_native_async
  stubs_mp.command_native_async = function(cmd, cb)
    last_async_handle = last_async_handle + 1
    local handle = last_async_handle
    call_count = call_count + 1
    table.insert(async_calls, { cmd = cmd, handle = handle })
    if cb then
      local result
      if call_count == 1 then
        result = {
          status = 0,
          stdout = '{"status":false,"error":{"code":"quota_exceeded"}}\n200',
          stderr = "",
          headers = {},
        }
      else
        result = {
          status = 0,
          stdout = '{"status":true,"subtitles":[{"id":2}]}\n200',
          stderr = "",
          headers = {},
        }
      end
      cb(true, result)
    end
    return handle
  end

  local final_result
  http.request_async("https://api.test.com/search", {
    api_key = "PRIMARY_KEY",
    backup_key = "BACKUP_KEY",
  }, function(success, result)
    final_result = result
  end)

  stubs_mp.command_native_async = orig_cna

  H.ok("quota_exceeded triggered retry", call_count == 2)
  if #async_calls >= 2 then
    local second_cmd = async_calls[2].cmd
    local found_backup = false
    for _, arg in ipairs(second_cmd.args or {}) do
      if type(arg) == "string" and arg:find("BACKUP_KEY") then
        found_backup = true
      end
    end
    H.ok("quota_exceeded retry uses backup key", found_backup)
  else
    H.ok("quota_exceeded retry uses backup key", false)
  end
end

-- =========================================================================
-- Test 5: Version guard: falls back to sync when command_native_async is nil
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  local orig_fn = stubs_mp.command_native_async
  stubs_mp.command_native_async = nil

  package.loaded["ar_subs.http"] = nil
  local http_old = require "ar_subs.http"

  local utils_stub = package.loaded["mp.utils"]
  local orig_subprocess = utils_stub.subprocess
  utils_stub.subprocess = function(spec)
    table.insert(H.calls, { kind = "subprocess", spec = spec })
    return { status = 0, stdout = '{"status":true}\n200', stderr = "" }
  end

  local done = false
  http_old.request_async("https://api.test.com", {
    api_key = "KEY",
  }, function(success, result)
    done = true
  end)

  H.ok("version guard: fallback invoked callback", done)
  H.ok("version guard: used utils.subprocess as fallback",
       (function()
         for _, c in ipairs(H.calls) do
           if c.kind == "subprocess" then return true end
         end
         return false
       end)())

  stubs_mp.command_native_async = orig_fn
  utils_stub.subprocess = orig_subprocess
  package.loaded["ar_subs.http"] = nil
  http = require "ar_subs.http"
end

-- =========================================================================
-- Test 6: OSD overlay created during request
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  _last_overlay = nil
  stubs_mp._async_result = {
    status = 0,
    stdout = '{"status":true}\n200',
    stderr = "",
  }

  http.request_async("https://api.test.com", {
    api_key = "KEY",
    osd_label = "Searching...",
  }, function(success, result) end)
  flush_callbacks()

  H.ok("OSD overlay created", _last_overlay ~= nil)
  H.ok("OSD overlay updated with text", _last_overlay and _last_overlay._data ~= nil)
  H.ok("OSD overlay removed after completion", _last_overlay and _last_overlay._removed)
end

-- =========================================================================
-- Test 7: In-flight handle tracked
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  local fake_handle = 9999

  local orig_cna = stubs_mp.command_native_async
  stubs_mp.command_native_async = function(cmd, cb)
    last_async_handle = last_async_handle + 1
    table.insert(async_calls, { cmd = cmd })
    if cb then cb(true, { status = 0, stdout = '""\n200', stderr = "" }) end
    return fake_handle
  end

  local tracked_handle = http.request_async("https://api.test.com", {
    api_key = "KEY",
  }, function(success, result) end)

  stubs_mp.command_native_async = orig_cna
  H.eq("request_async returns handle", tracked_handle, fake_handle)
end

-- =========================================================================
-- Test 8: Abort: calling abort_async_command on tracked handle
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  local fake_handle = 7777

  local orig_cna = stubs_mp.command_native_async
  stubs_mp.command_native_async = function(cmd, cb)
    last_async_handle = last_async_handle + 1
    table.insert(async_calls, { cmd = cmd })
    return fake_handle
  end

  local tracked_handle = http.request_async("https://api.test.com", {
    api_key = "KEY",
  }, function() end)

  stubs_mp.abort_async_command(tracked_handle)
  stubs_mp.command_native_async = orig_cna

  local aborted = false
  for _, c in ipairs(async_calls) do
    if c.kind == "abort" and c.handle == fake_handle then
      aborted = true
    end
  end
  H.ok("abort_async_command called on tracked handle", aborted)
end

-- =========================================================================
-- Test 9: request_async_json convenience wrapper
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  stubs_mp._async_result = {
    status = 0,
    stdout = 'HTTP/1.1 200 OK\r\nX-RateLimit-Remaining: 50\r\n\r\n{"subtitles":[{"id":1,"lang":"ar"}],"results":2}',
    stderr = "",
  }

  local json_result
  http.request_async_json("https://api.test.com/search?q=test", {
    api_key = "KEY",
  }, function(success, json, http_code, remaining)
    json_result = { success = success, json = json, code = http_code, remaining = remaining }
  end)
  flush_callbacks()

  H.ok("request_async_json parsed JSON body", type(json_result) == "table" and type(json_result.json) == "table")
  if json_result and json_result.json then
    H.eq("request_async_json returned subtitles", #json_result.json.subtitles, 1)
    H.eq("request_async_json http_code", json_result.code, 200)
    H.eq("request_async_json remaining from headers", json_result.remaining, "50")
  end
end

-- =========================================================================
-- Test 10: Error path: curl failure returns success=false
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  stubs_mp._async_result = {
    status = 1,
    stdout = "",
    stderr = "curl: (6) Could not resolve host",
  }

  local error_result
  http.request_async("https://api.test.com", {
    api_key = "KEY",
  }, function(success, result)
    error_result = { success = success, result = result }
  end)
  flush_callbacks()

  H.ok("curl failure reports success=false", error_result and error_result.success == false)
  H.ok("error result has stderr", error_result and error_result.result.stderr:find("Could not resolve host"))
end

-- =========================================================================
-- Test 11: Header deduplication (no duplicate Authorization headers)
-- =========================================================================
do
  H.reset()
  async_calls = {}
  pending_callbacks = {}
  stubs_mp._async_result = {
    status = 0,
    stdout = '{"status":true}\n200',
    stderr = "",
  }

  http.request_async("https://api.subdl.com/api/v2/me", {
    api_key = "KEY123",
    headers = { "Authorization: Bearer KEY123" },
  }, function(success, result) end)
  flush_callbacks()

  H.ok("request_async executed", #async_calls > 0)
  if #async_calls > 0 then
    local args = async_calls[1].cmd.args
    local auth_count = 0
    for i, a in ipairs(args) do
      if a:lower():find("authorization:") then auth_count = auth_count + 1 end
    end
    H.eq("Authorization header not duplicated", auth_count, 1)
  end
end

-- ---------------------------------------------------------------------------
-- Restore original package.loaded so other spec files aren't affected.
-- ---------------------------------------------------------------------------
package.loaded["mp"] = _orig_mp
package.loaded["mp.utils"] = _orig_mp_utils
package.loaded["mp.options"] = _orig_mp_options
package.loaded["ar_subs.http"] = _orig_http

stubs_mp.command_native_async = _orig_cna
stubs_mp.abort_async_command = _orig_aac
stubs_mp.create_osd_overlay = _orig_create_osd
stubs_mp._async_result = _orig_async_result
