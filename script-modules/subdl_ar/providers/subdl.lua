-- subdl_ar.providers.subdl: SubDL v2 API client.
--
-- Extracted from scripts/subdl_ar.lua (Task B / Task C). Owns every SubDL-
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

local match_util = require "subdl_ar.util.match"

local M = {}

-- Default configuration. configure() merges caller-supplied keys over these.
M._cfg = {
  api_url      = "https://api.subdl.com/api/v2/subtitles",
  download_url = "https://dl.subdl.com",
  api_key      = "",
  backup_key   = "",
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

-- configure({ api_key=, http_get_json=, ... }): merge caller deps.
-- Idempotent: subsequent calls overlay on top of the previous state.
function M.configure(deps)
  if type(deps) ~= "table" then return end
  for k, v in pairs(deps) do
    if k == "http_get_json" then M._http.get_json = v
    elseif k == "http_get_raw" then M._http.get_raw = v
    elseif k == "http_get_json_async" then M._http.get_json_async = v
    elseif k == "http_get_raw_async" then M._http.get_raw_async = v
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

  local query = string.format("tmdb_id=%s&languages=ar", tmdb_id)
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

-- api_download_url(sub_id) -> url string
-- v2 format=file endpoint. Response body is raw SRT (no zip).
function M.api_download_url(sub_id)
  return string.format("%s/%s/download?format=file",
                       M._cfg.api_url, sub_id)
end

-- download(sub) -> body, http_code, url
-- Fetches the raw SRT body via format=file. Caller writes body to disk.
-- Returns (nil, 0, nil) if sub lacks an id (regression guard for the
-- nil-concatenation crash fixed in Task A).
function M.download(sub)
  if type(sub) ~= "table" then return nil, 0, nil end

  local sub_id = sub.nId or sub.id or sub.sd_id
  if not sub_id then return nil, 0, nil end

  local url = M.api_download_url(sub_id)
  local headers = auth_headers()
  table.insert(headers, "Accept: text/plain, application/octet-stream")

  local body, code = M._http.get_raw(url, { headers = headers })
  return body, code, url
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
  if not M._http.get_raw_async then
    local body, code, url = M.download(sub)
    if on_done then on_done(body, code, url) end
    return nil
  end
  if type(sub) ~= "table" then
    if on_done then on_done(nil, 0, nil) end
    return nil
  end
  local sub_id = sub.nId or sub.id or sub.sd_id
  if not sub_id then
    if on_done then on_done(nil, 0, nil) end
    return nil
  end
  local url = M.api_download_url(sub_id)
  local headers = auth_headers()
  table.insert(headers, "Accept: text/plain, application/octet-stream")
  return M._http.get_raw_async(url, {
    headers = headers,
    api_key = M._cfg.api_key,
    backup_key = M._cfg.backup_key,
    osd_label = "Downloading...",
  }, function(success, result)
    if on_done then
      on_done(result.body or result.stdout, result.http_code or 0, url)
    end
  end)
end

return M
