-- ar_subs.providers.subdl: SubDL v2 API client.
--
-- Extracted from scripts/ar_subs.lua (Task B / Task C). Owns every SubDL-
-- specific request shape so the orchestrator only needs to call:
--
--   provider.configure { ... }            -- wire deps + keys once
--   provider.search(query, opts)          -- GET /api/v2/subtitles?<query>
--   provider.get_sd_id(mt, tmdb, title)   -- resolve sd_id from tmdb_id
--   provider.download(sub)                -- GET /<nId>/download?format=file
--
-- Auth model:
--   v1 glued the api key into every query string. v2 requires the key in an
--   `Authorization: Bearer <key>` header instead. The provider constructs
--   that header on every request and never puts the key in a URL.
--
-- v2 features used:
--   * `unpack=1` on searches: SubDL expands season packs into per-file entries
--     in `unpack_files[]` (each with its own url/season/episode/language).
--   * `format=file` on downloads: GET /api/v2/subtitles/{nId}/download?format=
--     file returns the raw SRT body, eliminating the unzip subprocess from the
--     download path.
--
-- Server-side `season` / `episode` fields are HINTS ONLY. The client-side
-- matcher (util/match.lua) remains authoritative. season:0 is dropped by
-- add_pair_meta (filtered as season < 1).
--
-- Dep injection:
--   http_get_json and http_get_raw are passed via configure() so the test
--   suite can stub the HTTP boundary without going through utils.subprocess.
--   The orchestrator wires real closures over its run()/http_get_json().

local match_util = require "ar_subs.util.match"

-- Monotonic counter for temp-file names. os.time()+math.random collides when
-- two downloads land in the same second (math.random is unseeded, so the
-- first call is deterministic). A per-process counter is unique regardless.
local _tmp_seq = 0
local function tmp_tag()
  _tmp_seq = _tmp_seq + 1
  return string.format("%d_%d", os.time(), _tmp_seq)
end

local M = {}

-- Default configuration. configure() merges caller-supplied keys over these.
M._cfg = {
  api_url      = "https://api.subdl.com/api/v2/subtitles/search",
  download_url = "https://dl.subdl.com",
  api_key      = "",
  backup_key   = "",
  -- Active key used for dl.subdl.com downloads (?api_key=). Selected by
  -- ensure_download_key() based on remaining daily download quota.
  download_key = nil,
}

-- Default HTTP deps. No-op stubs so requiring the module without configure()
-- cannot crash; the orchestrator MUST call configure() before use.
M._http = {
  get_json = function(_url, _opts) return nil, 0 end,
  get_raw  = function(_url, _opts) return nil, 0 end,
  get_json_async = nil,
  get_raw_async = nil,
}

-- Logger: prefer mp.msg when mpv's runtime is available, otherwise no-op so
-- the test harness (which stubs mp) does not blow up if it never wires msg.
local _mp_ok, _mp = pcall(require, "mp")
local function log(level, msg)
  if _mp_ok and _mp and _mp.msg and _mp.msg[level] then
    _mp.msg[level](msg)
  end
end

local function get_utils()
  if M._utils then return M._utils end
  if _mp and _mp.utils then return _mp.utils end
  return nil
end

-- configure({ api_key=, http_get_json=, ... }): merge caller deps.
-- Idempotent: subsequent calls overlay on top of the previous state.
function M.configure(deps)
  if type(deps) ~= "table" then return end
  for k, v in pairs(deps) do
    if k == "http_get_json" then M._http.get_json = v
    elseif k == "http_get_raw" then M._http.get_raw = v
    elseif k == "http_get_json_async" then M._http.get_json_async = v
    elseif k == "http_get_raw_async" then M._http.get_raw_async = v
    elseif k == "utils" then M._utils = v
    elseif k == "mp" then _mp = v; _utils = v and v.utils or nil
    else M._cfg[k] = v end
  end
end

-- Bearer header for the currently-active key. The backup-key retry path
-- swaps M._cfg.api_key temporarily so this same helper produces the right
-- header on the retry.
local function auth_header()
  return "Authorization: Bearer " .. M._cfg.api_key
end

local function auth_headers()
  return { auth_header() }
end

-- fetch: low-level GET returning (subs, results, json). Mirrors the original
-- fetch_subdl_api contract so the orchestrator's strategy fan-out works as-is.
local function fetch(query_string)
  local url = M._cfg.api_url .. "?" .. query_string
  local json, code = M._http.get_json(url, { headers = auth_headers() })
  if json and json.subtitles then
    match_util.normalize_subtitles_metadata(json.subtitles)
    return json.subtitles, json.results, json
  end
  return {}, json and json.results or nil, json
end

-- search(query_string, opts) -> subs, results
-- Adds unpack=1 by default (opts.unpack = false to opt out, e.g. for sd_id
-- lookups where the unpacked fan-out is wasted bytes).
function M.search(query_string, opts)
  opts = opts or {}
  if opts.unpack ~= false then
    query_string = query_string .. "&unpack=1"
  end

  local subs, results, json = fetch(query_string)

  -- Backup-key retry: identical heuristic to the old fetch_subdl_api.
  if json and json.status == false
     and M._cfg.backup_key ~= ""
     and M._cfg.backup_key ~= M._cfg.api_key then
    local err = tostring(json.error or ""):lower()
    if err:find("api") or err:find("limit") or err:find("request") then
      log("warn", "SubDL: primary API key failed, retrying with backup key")
      local orig = M._cfg.api_key
      M._cfg.api_key = M._cfg.backup_key
      local b_subs, b_results, b_json = fetch(query_string)
      M._cfg.api_key = orig
      if b_json and b_json.subtitles then
        return b_subs, b_results
      end
    end
  end

  return subs, results
end

-- get_sd_id(media_type, tmdb_id, title) -> sd_id | nil
-- Resolves the SubDL record matching the requested media_type when a TMDB id
-- could map to both a movie and a TV show.
function M.get_sd_id(media_type, tmdb_id, title)
  if not tmdb_id then return nil end

  local query = string.format("type=%s&tmdb_id=%s&languages=ar", media_type, tmdb_id)
  local _, results = M.search(query, { unpack = false })

  if results then
    for _, result in ipairs(results) do
      if result.type == media_type and result.sd_id then
        log("info", string.format(
          "SubDL: resolved %s sd_id=%s for tmdb_id=%s (%s)",
          media_type, tostring(result.sd_id), tmdb_id,
          result.name or title or ""))
        return result.sd_id
      end
    end
  end

  log("warn", string.format(
    "SubDL: could not find %s sd_id for tmdb_id=%s",
    media_type, tmdb_id))
  return nil
end

-- rewrite_download_api_key(url, api_key): force ?api_key= on a dl.subdl.com URL.
-- Search results embed the key used for search; when that key is out of
-- download quota we must swap to the backup key without re-searching.
function M.rewrite_download_api_key(url, api_key)
  if not url or url == "" or not api_key or api_key == "" then
    return url
  end
  if url:find("api_key=", 1, true) then
    return (url:gsub("api_key=[^&]*", "api_key=" .. api_key))
  end
  local sep = url:find("?", 1, true) and "&" or "?"
  return url .. sep .. "api_key=" .. api_key
end

-- Current key for downloads (session-sticky after ensure_download_key / failover).
function M.get_download_key()
  return M._cfg.download_key or M._cfg.api_key or ""
end

function M.set_download_key(key)
  if key == nil or key == "" then
    M._cfg.download_key = nil
  else
    M._cfg.download_key = key
  end
end

-- api_download_url(sub) -> url string
-- Uses sub.url from the API response (relative path on dl.subdl.com).
-- Falls back to sub_id-based construction if sub.url is unavailable.
-- Always rewrites ?api_key= to the active download key when one is set.
function M.api_download_url(sub)
  if type(sub) ~= "table" then
    return nil
  end
  local url = nil
  -- Prefer the URL from the API response (relative path like /subtitle/...).
  local sub_url = sub.url or sub.download_url
  if sub_url and sub_url ~= "" then
    -- If already absolute, return as-is; otherwise prepend download_url base.
    if sub_url:match("^https?://") then
      url = sub_url
    else
      url = M._cfg.download_url .. sub_url
    end
  else
    -- Fallback: construct from sub_id (legacy path, may not work with v2).
    local sub_id = sub.nId or sub.id or sub.sd_id
    if sub_id then
      url = M._cfg.download_url .. "/subtitle/" .. tostring(sub_id) .. ".zip"
    end
  end
  if not url then return nil end
  local key = M.get_download_key()
  if key ~= "" then
    url = M.rewrite_download_api_key(url, key)
  end
  return url
end

-- Stable identity for a subtitle entry (used to dedupe download candidates).
function M.sub_identity(sub)
  if type(sub) ~= "table" then return nil end
  local raw = sub.url or sub.download_url
  if raw and raw ~= "" then
    -- Strip query string so api_key differences don't create false uniques.
    return (raw:gsub("%?.*$", ""))
  end
  local id = sub.nId or sub.id or sub.sd_id
  if id then return "id:" .. tostring(id) end
  if sub.release_name then return "rn:" .. tostring(sub.release_name) end
  return nil
end

-- Deduplicate a subtitle list by download identity, preserving order.
function M.dedupe_subs(subs)
  if type(subs) ~= "table" then return {} end
  local out, seen = {}, {}
  for _, sub in ipairs(subs) do
    local id = M.sub_identity(sub) or ("row:" .. tostring(#out + 1))
    if not seen[id] then
      seen[id] = true
      out[#out + 1] = sub
    end
  end
  return out
end

-- get_usage_async(on_done[, api_key]): GET /api/v2/me (does not count against search quota).
-- on_done(usage_json_or_nil, http_code)
function M.get_usage_async(on_done, api_key)
  local key = api_key or M._cfg.api_key or ""
  local url = "https://api.subdl.com/api/v2/me"
  local headers = { "Authorization: Bearer " .. key }
  if M._http.get_json_async then
    return M._http.get_json_async(url, {
      headers = headers,
      api_key = key,
      backup_key = "", -- do not rotate; /me is diagnostic only
    }, function(a1, a2, a3)
      local success, json, http_code
      if type(a1) == "boolean" then
        success, json, http_code = a1, a2, a3
      else
        json, http_code = a1, a2
        success = (json ~= nil)
      end
      if on_done then on_done((success and json) or nil, http_code or 0) end
    end)
  end
  -- Sync path: temporarily use the requested key for auth_headers() if needed.
  local json, code
  if M._http.get_json then
    -- Prefer passing headers directly; stubs and real wrappers accept opts.headers.
    json, code = M._http.get_json(url, { headers = headers, api_key = key })
  end
  if on_done then on_done(json, code or 0) end
  return nil
end

-- download_quota(usage_json) -> { used, limit, remaining, reset_at } or nil
function M.download_quota(usage_json)
  if type(usage_json) ~= "table" then return nil end
  local dl = usage_json.usage and usage_json.usage.downloads
  if type(dl) ~= "table" then return nil end
  return {
    used = tonumber(dl.used) or 0,
    limit = tonumber(dl.limit) or 0,
    remaining = tonumber(dl.remaining) or 0,
    reset_at = dl.reset_at,
    period = dl.period,
  }
end

-- ensure_download_key(on_done): pick a key with remaining download quota.
-- Prefers primary, then backup. Sticky for the session via set_download_key.
-- on_done(key_or_nil, quota_or_nil, source)  source = "primary"|"backup"|"cached"|nil
function M.ensure_download_key(on_done)
  local primary = M._cfg.api_key or ""
  local backup = M._cfg.backup_key or ""
  local cached = M._cfg.download_key

  local function finish(key, quota, source)
    if key and key ~= "" then
      M.set_download_key(key)
    end
    if on_done then on_done(key, quota, source) end
  end

  -- If we already pinned a download key this session, re-check it still has quota.
  local function check_key(key, source, on_empty)
    if not key or key == "" then
      if on_empty then on_empty() end
      return
    end
    M.get_usage_async(function(usage)
      local q = M.download_quota(usage)
      if q and q.remaining > 0 then
        finish(key, q, source)
      elseif on_empty then
        on_empty(q)
      else
        finish(nil, q, nil)
      end
    end, key)
  end

  local function try_backup(primary_q)
    if backup ~= "" and backup ~= primary then
      check_key(backup, "backup", function(backup_q)
        -- Both empty: report primary quota (or backup) so caller can message.
        finish(nil, backup_q or primary_q, nil)
      end)
    else
      finish(nil, primary_q, nil)
    end
  end

  if cached and cached ~= "" then
    check_key(cached, "cached", function()
      -- Cached key exhausted: fall through primary → backup.
      check_key(primary, "primary", try_backup)
    end)
    return nil
  end

  check_key(primary, "primary", try_backup)
  return nil
end

-- download_quota(usage_json) -> { used, limit, remaining, reset_at } or nil
function M.download_quota(usage_json)
  local dl = usage_json and usage_json.usage and usage_json.usage.downloads
  if type(dl) ~= "table" then return nil end
  return {
    used = tonumber(dl.used) or 0,
    limit = tonumber(dl.limit) or 0,
    remaining = tonumber(dl.remaining) or 0,
    reset_at = dl.reset_at,
    period = dl.period,
  }
end

-- Format a human-readable quota exhausted message.
function M.quota_exhausted_message(q)
  if not q then return "SubDL download quota exhausted. Try later." end
  local msg = string.format("SubDL download quota exhausted (%d/%d)", q.used, q.limit)
  if q.reset_at and q.reset_at ~= "" then
    local pretty = tostring(q.reset_at):gsub("T", " "):gsub("%.%d+Z$", " UTC"):gsub("Z$", " UTC")
    msg = msg .. ". Resets " .. pretty
  end
  return msg
end

-- Parse SubDL reset_at ISO timestamp to a rough unix time (best-effort).
-- Returns nil if unparseable.
function M.parse_reset_at(reset_at)
  if not reset_at or type(reset_at) ~= "string" then return nil end
  local y, mo, d, h, mi, s = reset_at:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if not y then return nil end
  return os.time({
    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
    hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
    isdst = false,
  })
end

-- Zip-slip guard: reject archives whose members escape the extraction dir
-- (absolute paths or '..' segments). Returns true if the archive is safe.
local function zip_members_safe(path)
  local u = get_utils()
  if not u then return true end
  local res = u.subprocess({ args = { "unzip", "-Z1", path }, cancellable = false })
  if res.status ~= 0 or not res.stdout then return true end
  for member in res.stdout:gmatch("[^\r\n]+") do
    local m = member:gsub("\\", "/")
    if m:match("^/") or m:match("^%a:") then return false end
    for p in m:gmatch("[^/]+") do
      if p == ".." then return false end
    end
  end
  return true
end

-- SubDL occasionally answers HTTP 200 with a non-zip body (a transient error
-- page, or a key it rejects). A real subtitle zip starts with the PK magic;
-- checking it lets us detect that case and retry instead of feeding garbage
-- to unzip ("End-of-central-directory signature not found").
local function is_zip_file(path)
  local f = io.open(path, "rb")
  if not f then return false end
  local magic = f:read(4)
  f:close()
  return magic == "PK\3\4" or magic == "PK\5\6"
end

-- One-line description of a downloaded file for failure diagnostics:
-- http code, size, and the first bytes (so we can tell an HTML/JSON error
-- page from a truncated zip without dumping the body).
local function describe_download(path, code)
  local u = get_utils()
  local info = u and u.file_info(path)
  local head = ""
  local f = io.open(path, "rb")
  if f then
    head = (f:read(32) or ""):gsub("[^\32-\126]", ".")
    f:close()
  end
  return string.format("http=%s size=%s head=%q", tostring(code),
          tostring(info and info.size or -1), head)
end

-- Internal: curl a subtitle URL (zip OR raw subtitle file), return the first
-- subtitle body and its name. Returns body, http_code, url_used, original_filename.
local function download_url_to_srt(url, fallback_name)
  if not url then return nil, 0, nil end

  local tmp_zip = "/tmp/subdl_dl_" .. tmp_tag() .. ".zip"
  local tmp_dir = "/tmp/subdl_dl_" .. tmp_tag()
  local u = get_utils()
  if not u then return nil, 0, url end

  local res = u.subprocess({
    args = {
      "curl", "-sS", "-o", tmp_zip, "-w", "%{http_code}",
      "--connect-timeout", "10", "--max-time", "20",
      url,
    },
    cancellable = false,
  })

  local code = tonumber(res.stdout) or 0
  local zip_info = u.file_info(tmp_zip)
  if code < 200 or code >= 300 or not zip_info or zip_info.size == 0 then
    os.remove(tmp_zip)
    return nil, code, url
  end

  local srt_content = nil
  local original_filename = nil

  if not is_zip_file(tmp_zip) then
    -- SubDL served the subtitle file directly (expanded unpack_files child URL).
    local f = io.open(tmp_zip, "r")
    local body = f and f:read("*a")
    if f then f:close() end
    if body and (body:find("-->", 1, true) or body:find("Dialogue:", 1, true)
            or body:find("[Script", 1, true) or body:find("{\\", 1, true)) then
      srt_content = body
      original_filename = fallback_name
    end
    os.remove(tmp_zip)
    return srt_content, code, url, original_filename
  end

  if not zip_members_safe(tmp_zip) then
    log("warn", "SubDL: rejecting zip with unsafe members (zip-slip)")
    os.remove(tmp_zip)
    return srt_content, 0, url, nil
  end
  u.subprocess({ args = {"mkdir", "-p", tmp_dir}, cancellable = false })
  u.subprocess({ args = {"unzip", "-o", tmp_zip, "-d", tmp_dir}, cancellable = false })

  local find_res = u.subprocess({
    args = {"find", tmp_dir, "-type", "f", "-name", "*.srt", "-o", "-name", "*.ass", "-o", "-name", "*.ssa"},
    cancellable = false,
  })
  if find_res.status == 0 and find_res.stdout and find_res.stdout ~= "" then
    local first_path = find_res.stdout:match("^([^\n]+)")
    if first_path then
      original_filename = first_path:match("([^/]+)$")
      local f = io.open(first_path, "r")
      if f then
        srt_content = f:read("*a")
        f:close()
      end
    end
  end

  os.remove(tmp_zip)
  u.subprocess({ args = {"rm", "-rf", tmp_dir}, cancellable = false })

  return srt_content, code, url, original_filename
end

-- Alternate key for download failover (backup if primary was used, else primary).
local function alternate_download_key(used_key)
  local primary = M._cfg.api_key or ""
  local backup = M._cfg.backup_key or ""
  if backup == "" or backup == primary then return nil end
  if used_key == primary then return backup end
  if used_key == backup then return primary end
  -- used_key unknown / empty: prefer backup if primary was the default
  if used_key == "" or used_key == primary then return backup end
  return backup
end

function M.download(sub)
  if type(sub) ~= "table" then return nil, 0, nil end

  local url = M.api_download_url(sub)
  if not url then return nil, 0, nil end

  local body, code, used_url, original_filename = download_url_to_srt(url, sub.release_name)
  -- Retry once with the alternate key on any failure (429, empty, error page).
  if not body then
    local alt = alternate_download_key(M.get_download_key())
    if alt then
      log("warn", string.format("SubDL: download failed (http %s), retrying with alternate API key", tostring(code)))
      M.set_download_key(alt)
      local retry_url = M.rewrite_download_api_key(url, alt)
      body, code, used_url, original_filename = download_url_to_srt(retry_url, sub.release_name)
    end
  end
  return body, code, used_url, original_filename
end

function M.search_async(query_string, opts, on_done)
  if not M._http.get_json_async then
    local subs, results = M.search(query_string, opts)
    if on_done then on_done(subs, results) end
    return nil
  end
  opts = opts or {}
  if opts.unpack ~= false then
    query_string = query_string .. "&unpack=1"
  end
  local url = M._cfg.api_url .. "?" .. query_string
  return M._http.get_json_async(url, { headers = auth_headers(), api_key = M._cfg.api_key, backup_key = M._cfg.backup_key }, function(success, json, http_code, remaining)
    if not success or not json then
      if on_done then on_done({}, nil) end
      return
    end
    if json.subtitles then
      match_util.normalize_subtitles_metadata(json.subtitles)
    end
    local subs = json.subtitles or {}
    if json.status == false and M._cfg.backup_key ~= "" and M._cfg.backup_key ~= M._cfg.api_key then
      local err_str = json.error and type(json.error) == "string" and json.error or ""
      local err_code = json.error and json.error.code and tostring(json.error.code) or ""
      local combined = (err_str .. " " .. err_code):lower()
      if combined:find("api") or combined:find("limit") or combined:find("request") or combined:find("quota") then
        log("warn", "SubDL: async primary key failed, retrying with backup")
        local orig = M._cfg.api_key
        M._cfg.api_key = M._cfg.backup_key
        local retry_url = M._cfg.api_url .. "?" .. query_string
        return M._http.get_json_async(retry_url, { headers = auth_headers(), api_key = M._cfg.api_key, backup_key = M._cfg.backup_key }, function(s2, j2)
          M._cfg.api_key = orig
          if s2 and j2 and j2.subtitles then
            match_util.normalize_subtitles_metadata(j2.subtitles)
            if on_done then on_done(j2.subtitles, j2.results) end
          else
            if on_done then on_done(subs, json.results) end
          end
        end)
      end
    end
    if on_done then on_done(subs, json.results) end
  end)
end

function M.download_async(sub, on_done)
  if type(sub) ~= "table" then
    if on_done then on_done(nil, 0, nil, nil) end
    return nil
  end

  local base_url = M.api_download_url(sub)
  if not base_url then
    if on_done then on_done(nil, 0, nil, nil) end
    return nil
  end

  -- No async support: fall back to sync download (includes key failover).
  if not (_mp and _mp.command_native_async) then
    local body, code, dl_url, original_filename = M.download(sub)
    if on_done then on_done(body, code, dl_url, original_filename) end
    return nil
  end

  local function do_curl(url, key_used, is_retry, fallback_name)
    local tmp_zip = "/tmp/subdl_dl_" .. os.time() .. "_" .. math.random(10000) .. ".zip"
    local tmp_dir = "/tmp/subdl_dl_" .. os.time() .. "_" .. math.random(10000)
    local curl_args = {
      "curl", "-sS", "-o", tmp_zip, "-w", "%{http_code}",
      "--connect-timeout", "10", "--max-time", "20",
      url,
    }

    return _mp.command_native_async({
      name = "subprocess",
      args = curl_args,
      capture_stdout = true,
      playback_only = false,
    }, function(_ok, res)
      local code = tonumber(res and res.stdout) or 0
      local u = get_utils()
      local zip_info = u and u.file_info(tmp_zip)

      if code == 429 and not is_retry then
        os.remove(tmp_zip)
        local alt = alternate_download_key(key_used)
        if alt then
          log("warn", "SubDL: download 429, retrying with alternate API key")
          M.set_download_key(alt)
          do_curl(M.rewrite_download_api_key(url, alt), alt, true, fallback_name)
          return
        end
        if on_done then on_done(nil, code, url, nil) end
        return
      end

      if code < 200 or code >= 300 or not zip_info or zip_info.size == 0 then
        log("warn", "SubDL: download unusable (" .. describe_download(tmp_zip, code) .. ")")
        os.remove(tmp_zip)
        if on_done then on_done(nil, code, url, nil) end
        return
      end

      local srt_content, orig_name

      if is_zip_file(tmp_zip) then
        -- ZIP archive: unzip and take the first subtitle inside.
        if not zip_members_safe(tmp_zip) then
          log("warn", "SubDL: rejecting zip with unsafe members (zip-slip)")
          os.remove(tmp_zip)
          if on_done then on_done(nil, code, url, nil) end
          return
        end
        u.subprocess({ args = {"mkdir", "-p", tmp_dir}, cancellable = false })
        u.subprocess({ args = {"unzip", "-o", tmp_zip, "-d", tmp_dir}, cancellable = false })
        local find_res = u.subprocess({
          args = {"find", tmp_dir, "-type", "f", "-name", "*.srt", "-o", "-name", "*.ass", "-o", "-name", "*.ssa"},
          cancellable = false,
        })
        if find_res.status == 0 and find_res.stdout and find_res.stdout ~= "" then
          local first_path = find_res.stdout:match("^([^\n]+)")
          if first_path then
            -- Preserve the filename from inside the zip so callers can use it
            -- for episode matching (it typically contains SxxExx).
            orig_name = first_path:match("([^/]+)$")
            local f = io.open(first_path, "r")
            if f then srt_content = f:read("*a"); f:close() end
          end
        end
        u.subprocess({ args = {"rm", "-rf", tmp_dir}, cancellable = false })
      else
        -- Not a zip: SubDL served the subtitle file directly. This is what an
        -- expanded unpack_files child URL (match.expand_unpack_files) returns.
        -- Accept it only if it actually looks like subtitle text (not an
        -- HTML/JSON error page); the filename comes from the search result.
        local f = io.open(tmp_zip, "r")
        local body = f and f:read("*a")
        if f then f:close() end
        if body and (body:find("-->", 1, true) or body:find("Dialogue:", 1, true)
                or body:find("[Script", 1, true) or body:find("{\\", 1, true)) then
          srt_content = body
          orig_name = fallback_name
        end
      end

      os.remove(tmp_zip)

      if not srt_content then
        log("warn", "SubDL: download yielded no subtitle (" .. describe_download(tmp_zip, code) .. ")")
        if on_done then on_done(nil, code, url, nil) end
        return
      end
      -- Pass orig_name (4th arg) so callers write the SxxExx filename
      if on_done then on_done(srt_content, code, url, orig_name) end
    end)
  end

  -- When unpack_files is available (unpack=1 was used), prefer downloading
  -- the individual SRT file directly — no zip extraction needed and the
  -- file's name includes the SxxExx tag which the episode matcher needs.
  -- Retry once with the alternate key on failure, then fall back to the zip.
  local unpack_files = sub.unpack_files
  if type(unpack_files) == "table" and #unpack_files > 0 then
    local uf = unpack_files[1]
    local uf_url = uf and uf.url
    local uf_name = uf and uf.name
    if uf_url and uf_url ~= "" then
      if not uf_url:match("^https?://") then
        uf_url = M._cfg.download_url .. uf_url
      end

      local function try_unpack(key, attempt)
        local url = uf_url
        if key ~= "" then url = M.rewrite_download_api_key(uf_url, key) end
        local tmp_srt = "/tmp/subdl_uf_" .. os.time() .. "_" .. math.random(10000) .. ".srt"
        return _mp.command_native_async({
          name = "subprocess",
          args = { "curl", "-sS", "-o", tmp_srt, "-w", "%{http_code}",
                   "--connect-timeout", "10", "--max-time", "20", url },
          capture_stdout = true,
          playback_only = false,
        }, function(_ok, res)
          local code = tonumber(res and res.stdout) or 0
          local u = get_utils()
          local info = u and u.file_info(tmp_srt)
          local good = code >= 200 and code < 300 and info and info.size > 0
          if not good then
            local desc = describe_download(tmp_srt, code)
            os.remove(tmp_srt)
            if attempt == 0 then
              local alt = alternate_download_key(key)
              if alt then M.set_download_key(alt) end
              log("warn", string.format("SubDL: unpack download failed (%s), retrying%s",
                      desc, alt and " with alternate key" or ""))
              return try_unpack(alt or key, 1)
            end
            log("warn", "SubDL: unpack download failed (" .. desc .. "), falling back to zip")
            return do_curl(base_url, M.get_download_key(), false, uf_name or sub.release_name)
          end
          local srt_content = nil
          local f = io.open(tmp_srt, "r")
          if f then
            srt_content = f:read("*a")
            f:close()
          end
          os.remove(tmp_srt)
          -- Pass the original filename so callers write SxxExx into the name
          if on_done then on_done(srt_content, code, url, uf_name) end
        end)
      end

      log("debug", "SubDL: downloading via unpack_files URL: " .. (uf_name or "?"))
      return try_unpack(M.get_download_key(), 0)
    end
  end

  local key = M.get_download_key()
  return do_curl(base_url, key, false, sub.release_name)
end

return M
