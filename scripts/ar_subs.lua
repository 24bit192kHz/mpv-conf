local mp = require 'mp'
local options = require 'mp.options'
local utils = require 'mp.utils'

-- Bootstrap package.path so `require 'ar_subs.*'` resolves into
-- script-modules/ar_subs/. init.lua also runs an idempotent ensure_path()
-- for any other script that wants to consume these modules.
do
    local _modules_dir = mp.command_native({"expand-path", "~~/script-modules"})
    package.path = _modules_dir .. "/?.lua;" .. _modules_dir .. "/?/init.lua;" .. package.path
end
require 'ar_subs.init'

local url_util = require 'ar_subs.util.url'
local media_util = require 'ar_subs.util.media'
local match_util = require 'ar_subs.util.match'
local activation_util = require 'ar_subs.util.activation'
local config_loader = require 'ar_subs.config'
local subdl_provider = require 'ar_subs.providers.subdl'
local tvdb_provider = require 'ar_subs.providers.tvdb'
local cache_mod = require 'ar_subs.cache'
local store_mod = require 'ar_subs.store'
local subtitle_api = require 'ar_subs.util.subtitle_api'
local subsource_mod = require 'ar_subs.util.subsource'
local zstd_mod = require 'ar_subs.util.zstd'
zstd_mod.init(mp)
local http_mod = require 'ar_subs.http'
local uosc_picker = require 'ar_subs.ui.uosc_picker'

local trim = url_util.trim
local strip_quotes = url_util.strip_quotes
local url_safe = url_util.url_safe
local redact_url = url_util.redact_url
local basename = url_util.basename
local sanitize_filename = url_util.sanitize_filename
local clean_title = media_util.clean_title
local normalize_title_candidates = media_util.normalize_title_candidates
local merge_candidates = media_util.merge_candidates
local path_title_candidates = media_util.path_title_candidates
local limit_queries = media_util.limit_queries
local dedupe_queries = media_util.dedupe_queries
local extract_series_info = media_util.extract_series_info
local extract_anime_info = media_util.extract_anime_info
local extract_movie_info = media_util.extract_movie_info
local resolve_media_info = media_util.resolve_media_info
local classify_content_type = media_util.classify_content_type
local normalize_path_key = media_util.normalize_path_key
local normalize_stem_key = media_util.normalize_stem_key
local get_quality_score = match_util.get_quality_score
local add_episode_meta = match_util.add_episode_meta
local add_pair_meta = match_util.add_pair_meta
local normalize_subtitle_metadata = match_util.normalize_subtitle_metadata
local normalize_subtitles_metadata = match_util.normalize_subtitles_metadata
local matches_title_words = match_util.matches_title_words
local calculate_cour_mappings = match_util.calculate_cour_mappings
local build_valid_mapping_sets = match_util.build_valid_mapping_sets
local find_matching_episode_file = match_util.find_matching_episode_file
local expand_unpack_files = match_util.expand_unpack_files

local _cfg = config_loader.load(mp, options)
local dotenv = _cfg.dotenv
local env_config = _cfg.env
local config = _cfg.opts

-- All ar_subs state lives under the shared mpv cache root so a single
-- rm -rf ~/.cache/mpv resets the whole workflow (subs, search db, hot files).
local CACHE_DIR = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") or "/tmp") .. "/.cache") .. "/mpv/ar_subs"
local CACHE_FILE = CACHE_DIR .. "/cache.json"
local SUBS_DIR = CACHE_DIR .. "/subtitles"
local SUBDL_API_KEY = trim(config.subdl_api_key) ~= "" and config.subdl_api_key or env_config.subdl_api_key
local SUBDL_API_BACKUP_KEY = trim(config.subdl_api_backup_key) ~= "" and config.subdl_api_backup_key or env_config.subdl_api_backup_key
local TMDB_API_KEY = trim(config.tmdb_api_key) ~= "" and config.tmdb_api_key or env_config.tmdb_api_key
-- FIX 1: Remove trailing spaces from API URLs
local SUBDL_API_URL = "https://api.subdl.com/api/v2/subtitles/search"
local TMDB_API_URL = "https://api.themoviedb.org/3"
local CURL_TIMEOUT = 10
local MAX_RETRIES = 2
local DEEP_SEARCH = (os.getenv("SUBDL_DEEP_SEARCH") == "1")
local CACHE_TO_MEDIA_DIR = (os.getenv("CACHE_TO_MEDIA_DIR") == "1")
local TVDB_API_KEY = _cfg.tvdb_api_key or ""
local USE_TVDB_COUR = _cfg.use_tvdb_cour or false
local has_uosc = false

-- Magic number constants
local EARLY_STOP_COUNT = 5
local ANIME_EARLY_STOP_COUNT = 10
-- Download one candidate at a time. Free tier is 50 downloads/day; a batch of
-- 5 burned quota on near-duplicate releases even when the first was fine.
local BATCH_SIZE = 1
-- Auto-fetch on file-loaded: only the top candidate (1 download).
-- Manual next (Ctrl+Shift+V): up to this many sequential tries per press.
local AUTO_MAX_DOWNLOAD_ATTEMPTS = 1
local MANUAL_MAX_DOWNLOAD_ATTEMPTS = 3
local GLOBAL_MODE = false
local RESTRICTED_PATH = "/mnt/my-zfs"
local SCRIPT_DIR = mp.get_script_directory() or "."
local rate_limit_until = nil
-- Soft rate-limit retries (temporary 429 with remaining quota).
local RATE_LIMIT_SOFT_WAIT = 30
local RATE_LIMIT_SOFT_MAX_RETRIES = 2
-- When daily download quota is exhausted, block until reset (or this floor).
local RATE_LIMIT_QUOTA_FLOOR = 3600

-- Persistent season-level search cache (SQLite + zstd, see ar_subs.store).
-- One search serves every episode of a season: SubDL's season queries return
-- the whole candidate pool, and the per-episode cour filter runs in memory on
-- the cached rows. search_cache_ttl_days=0 disables the cache.
store_mod.init({ dir = CACHE_DIR, mp = mp })
local SEARCH_CACHE_TTL = (tonumber(config.search_cache_ttl_days) or 30) * 86400

-- Offline Subscene Arabic index served by the subtitle-api Docker container
-- (built by build_subscene_db.py, served by subtitle-api/server.py). mpv asks
-- the API for the one matching subtitle file; a hit costs zero SubDL quota.
-- When the API is unreachable the source disables itself and everything falls
-- through to SubDL.
local function opt_or(key, default)
    local v = config[key]
    if v and trim(v) ~= "" then return v end
    return default
end
subtitle_api.init({
    mp = mp,
    url = opt_or("subtitle_api_url", "http://127.0.0.1:8787"),
    timeout = tonumber(config.subtitle_api_timeout) or 10,
})

-- SubSource.net: preferred ONLINE source (after the zero-quota offline
-- index, before the SubDL fallback). Empty key disables it.
subsource_mod.init({
    mp = mp,
    api_key = trim(config.subsource_api_key) ~= "" and config.subsource_api_key
        or _cfg.env.subsource_api_key or "",
    timeout = 10,
})

-- Skip fetching when the playing video already has a same-stem external
-- subtitle loaded (the per-episode sibling kept in-folder). Set to "no" to
-- always fetch regardless.
local SKIP_IF_SIBLING_SUB = opt_or("skip_if_sibling_sub", "yes") ~= "no"

local function search_cache_get(key)
    if SEARCH_CACHE_TTL <= 0 or not store_mod.available() then return nil end
    local raw = store_mod.get("search", key, SEARCH_CACHE_TTL)
    if not raw then return nil end
    local ok, parsed = pcall(utils.parse_json, raw)
    if not ok or type(parsed) ~= "table" or #parsed == 0 then return nil end
    normalize_subtitles_metadata(parsed)
    return parsed
end

local function search_cache_put(key, subs)
    if SEARCH_CACHE_TTL <= 0 or not subs or #subs == 0 then return end
    if not store_mod.available() then return end
    local clean = {}
    for i, s in ipairs(subs) do
        local c = {}
        for k, v in pairs(s) do
            if type(k) ~= "string" or k:sub(1, 1) ~= "_" then c[k] = v end
        end
        clean[i] = c
    end
    local ok, enc = pcall(utils.format_json, clean)
    if ok and enc then store_mod.put("search", key, enc) end
end

-- Apply a hard download-quota block from /api/v2/me usage.
-- Returns true if quota is exhausted (caller should stop retries).
local function apply_download_quota_block(usage)
    local q = subdl_provider.download_quota(usage)
    if not q or q.remaining > 0 then return false end

    local reset_ts = subdl_provider.parse_reset_at(q.reset_at)
    local now = os.time()
    local until_ts = now + RATE_LIMIT_QUOTA_FLOOR
    if reset_ts and reset_ts > now then
        until_ts = reset_ts
    end
    rate_limit_until = until_ts

    local msg = subdl_provider.quota_exhausted_message(q)
    mp.msg.warn("SubDL: " .. msg)
    mp.osd_message(msg, 8)
    return true
end

-- On HTTP 429 after provider-level key failover already tried:
-- re-resolve a key with remaining quota; hard-stop only if both are empty.
-- on_soft(wait_secs) for temporary limits; on_hard(reason) when giving up.
local function handle_download_429(attempt, on_soft, on_hard)
    -- Clear sticky download key so ensure_download_key re-evaluates both keys.
    subdl_provider.set_download_key(nil)

    subdl_provider.ensure_download_key(function(key, quota, source)
        if key and key ~= "" then
            mp.msg.info(string.format(
                "SubDL: switched download key to %s (%d downloads left)",
                source or "alternate", (quota and quota.remaining) or -1))
            -- Soft retry with the new key (limited attempts).
            if attempt >= RATE_LIMIT_SOFT_MAX_RETRIES then
                rate_limit_until = os.time() + RATE_LIMIT_SOFT_WAIT
                mp.msg.warn("SubDL: still rate limited after key switch; giving up for now")
                mp.osd_message(string.format("SubDL rate limited. Try again in %ds.", RATE_LIMIT_SOFT_WAIT), 5)
                if on_hard then on_hard("soft_exhausted") end
                return
            end
            rate_limit_until = os.time() + 2
            mp.osd_message("Retrying download with backup key...", 3)
            if on_soft then on_soft(2) end
            return
        end

        -- No key with remaining quota.
        if quota then
            apply_download_quota_block({ usage = { downloads = {
                used = quota.used, limit = quota.limit, remaining = 0,
                reset_at = quota.reset_at, period = quota.period,
            }}})
        else
            rate_limit_until = os.time() + RATE_LIMIT_QUOTA_FLOOR
            mp.msg.warn("SubDL: all API keys out of download quota (or /me unreachable)")
            mp.osd_message("SubDL download quota exhausted on all keys.", 8)
        end
        if on_hard then on_hard("quota") end
    end)
end

-- Helper: Check if script should be enabled for this file
local function is_enabled()
    local path = mp.get_property("path")
    if not path then return false end
    
    -- 1. Restrict to specific path unless global mode is enabled
    if not GLOBAL_MODE and not path:find(RESTRICTED_PATH, 1, true) then
        return false
    end
    
    -- 2. Restrict to video files (ignore audio-only like mp3)
    local has_video = false
    local track_list = mp.get_property_native("track-list") or {}
    for _, track in ipairs(track_list) do
        if track.type == "video" and not track.albumart then
            has_video = true
            break
        end
    end
    return has_video
end

-- Global state
local subs_cache = {}
local downloaded_subs = {}
local current_index = {}
local local_candidates = {}   -- video_name -> top-N list from subtitle-api /candidates
local local_idx = {}          -- video_name -> index of the loaded local candidate
local season_files_map = {}
local movie_files_map = {}
local last_subs_list = nil

local tmdb_cache = {}
local tmdb_season_cache = {}
local subdl_sd_cache = {}  -- Cache sd_id lookups
local tvdb_series_cache = {}  -- TVDB title -> series_id cache
local media_catalog = {
    loaded = false,
    exact_type = {},
    basename_types = {},
    stem_types = {},
}

local save_runtime_cache
local load_runtime_cache



-- OSD feedback helper
local function osd_overlay_update(text)
end
local current_osd_overlay = nil
local function osd_show(text)
    if not mp.create_osd_overlay then return end
    if not current_osd_overlay then
        current_osd_overlay = mp.create_osd_overlay("ass-events")
    end
    if current_osd_overlay then
        current_osd_overlay:update({ data = text })
    end
end
local function osd_remove()
    if current_osd_overlay then
        current_osd_overlay:remove()
        current_osd_overlay = nil
    end
end

local current_async_handle = nil

local function abort_inflight()
    if current_async_handle then
        mp.abort_async_command(current_async_handle)
        current_async_handle = nil
    end
end

local function http_get_json_async(url, opts, on_done)
    opts = opts or {}
    local headers = opts.headers or {}
    local api_key = opts.api_key or SUBDL_API_KEY
    local backup_key = opts.backup_key or SUBDL_API_BACKUP_KEY
    current_async_handle = http_mod.request_async(url, {
        api_key = api_key,
        backup_key = backup_key,
        headers = headers,
        timeout = opts.timeout,
    }, function(success, result)
        current_async_handle = nil
        if not success or not result or not result.body then
            if on_done then on_done(false, nil, result and result.http_code or 0, result and result.remaining or nil) end
            return
        end
        local json = utils.parse_json(result.body)
        if json then
            if on_done then on_done(true, json, result.http_code or 0, result.remaining) end
        else
            if on_done then on_done(false, nil, result.http_code or 0, result.remaining) end
        end
    end)
    return current_async_handle
end

local function http_get_raw_async(url, opts, on_done)
    opts = opts or {}
    local headers = opts.headers or {}
    local api_key = opts.api_key or SUBDL_API_KEY
    local backup_key = opts.backup_key or SUBDL_API_BACKUP_KEY
    current_async_handle = http_mod.request_async(url, {
        api_key = api_key,
        backup_key = backup_key,
        headers = headers,
        timeout = opts.timeout,
    }, function(success, result)
        current_async_handle = nil
        if on_done then on_done(result.body, result.http_code or 0) end
    end)
end

-- Run command with timeout and retry logic
local function run(cmd)
    local args = cmd
    if cmd[1] == "curl" then
        args = {"curl", "--connect-timeout", tostring(CURL_TIMEOUT), "--max-time", tostring(CURL_TIMEOUT * 2)}
        for i = 2, #cmd do table.insert(args, cmd[i]) end
    end
    
    for i = 0, MAX_RETRIES do
        local res = utils.subprocess({ args = args, cancellable = false })
        if res.status == 0 then return res end
        if i < MAX_RETRIES then mp.msg.warn(string.format("Command failed, retrying (%d/%d)...", i + 1, MAX_RETRIES)) end
        if i == MAX_RETRIES then return res end
    end
end

local function http_get_json(url, opts)
    opts = opts or {}
    local backoff = 1
    local tries = opts.max_retries or (MAX_RETRIES + 3)
    for _ = 1, tries do
        -- FIX 2: Log the URL being fetched for debugging
        mp.msg.debug("SubDL: fetching URL: " .. redact_url(url))
        local cmd = {"curl", "-sL", "-w", "\n%{http_code}"}
        if opts.headers then
            for _, h in ipairs(opts.headers) do
                table.insert(cmd, "-H")
                table.insert(cmd, h)
            end
        end
        table.insert(cmd, url)
        local res = run(cmd)
        if res.status ~= 0 or not res.stdout then
            mp.msg.warn("SubDL: curl failed with status " .. tostring(res.status))
            backoff = math.min(backoff * 2, 10)
        else
            local body, code = res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
            local http_code = tonumber(code or 0)
            if http_code == 429 then
                mp.msg.warn("HTTP 429: retrying (sync fallback, no blocking sleep)")
                backoff = math.min(backoff * 2, 10)
            elseif http_code >= 200 and http_code < 300 then
                local json = utils.parse_json(body or "")
                if json then return json, http_code end
                return nil, http_code
            else
                mp.msg.warn("SubDL: HTTP error " .. tostring(http_code) .. " for URL: " .. redact_url(url))
                return nil, http_code
            end
        end
    end
    return nil, 0
end

local function http_get_raw(url, opts)
    opts = opts or {}
    local cmd = {"curl", "-sL", "-w", "\n%{http_code}"}
    if opts.headers then
        for _, h in ipairs(opts.headers) do
            table.insert(cmd, "-H")
            table.insert(cmd, h)
        end
    end
    table.insert(cmd, url)
    local res = run(cmd)
    if res.status ~= 0 or not res.stdout then return nil, 0 end
    local body, code = res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
    local http_code = tonumber(code or 0)
    if http_code >= 200 and http_code < 300 then
        return body or "", http_code
    end
    mp.msg.warn("SubDL: HTTP error " .. tostring(http_code) .. " for URL: " .. redact_url(url))
    return nil, http_code
end

subdl_provider.configure {
    api_url = SUBDL_API_URL,
    download_url = "https://dl.subdl.com",
    api_key = SUBDL_API_KEY,
    backup_key = SUBDL_API_BACKUP_KEY,
    http_get_json = http_get_json,
    http_get_raw = http_get_raw,
    http_get_json_async = http_get_json_async,
    http_get_raw_async = http_get_raw_async,
    utils = utils,
}


if TVDB_API_KEY ~= "" then
    tvdb_provider.configure {
        api_key = TVDB_API_KEY,
        post_json_async = function(url, opts, on_done)
            local body = opts and opts.body or ""
            local extra_headers = opts and opts.headers or {}
            local args = {
                "curl", "-sS", "-D", "-",
                "--connect-timeout", tostring(CURL_TIMEOUT),
                "--max-time", tostring(CURL_TIMEOUT * 2),
                "-X", "POST",
                "-H", "Content-Type: application/json",
                "-d", body,
            }
            for _, h in ipairs(extra_headers) do
                if not h:find("Content-Type", 1, true) then
                    table.insert(args, "-H")
                    table.insert(args, h)
                end
            end
            table.insert(args, url)
            local handle = mp.command_native_async({
                name = "subprocess",
                args = args,
                capture_stdout = true,
                playback_only = false,
            }, function(ok, res)
                local resp_body, http_code, _headers = nil, 0, {}
                if res.stdout then
                    local body_raw, code = res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
                    resp_body = body_raw
                    http_code = tonumber(code or 0)
                end
                local json = resp_body and utils.parse_json(resp_body) or nil
                if on_done then on_done(json ~= nil, json, http_code) end
            end)
            return handle
        end,
        get_json_async = function(url, opts, on_done)
            local headers = opts and opts.headers or {}
            local handle = http_mod.request_async(url, {
                api_key = TVDB_API_KEY,
                headers = headers,
                timeout = opts and opts.timeout,
            }, function(success, result)
                if not success or not result.body then
                    if on_done then on_done(false, nil, 0) end
                    return
                end
                local json = utils.parse_json(result.body)
                if on_done then on_done(json ~= nil, json, result.http_code or 0) end
            end)
            return handle
        end,
    }
    mp.msg.info("SubDL: TVDB provider configured")
end

-- Safe subprocess helpers (avoid shell injection from os.execute)
local function safe_mkdir(path)
    return utils.subprocess({ args = {"mkdir", "-p", path}, cancellable = false })
end

local function safe_copy(src, dst)
    return utils.subprocess({ args = {"cp", "-f", src, dst}, cancellable = false })
end

local function safe_rm_rf(path)
    return utils.subprocess({ args = {"rm", "-rf", path}, cancellable = false })
end

local function safe_find_subs(dir)
    local res = utils.subprocess({
        args = {"find", dir, "-type", "f", "(", "-name", "*.srt", "-o", "-name", "*.ass", "-o", "-name", "*.ssa", "-o", "-name", "*.vtt", "-o", "-name", "*.zst", ")"},
        cancellable = false
    })
    if res.status ~= 0 or not res.stdout then return {} end
    local files = {}
    for line in res.stdout:gmatch("[^\n]+") do
        table.insert(files, line)
    end
    return files
end

local function safe_unzip(zip, dest)
    return utils.subprocess({ args = {"unzip", "-o", zip, "-d", dest}, cancellable = false })
end

-- SubDL downloads are ZIPs. The provider returns the original subtitle
-- filename as the fourth callback value because it carries the episode tag
-- (for example, S03E01). Keep that name when staging the body; replacing it
-- with only the show title makes the episode matcher reject an otherwise
-- valid subtitle.
local function downloaded_subtitle_name(title, original_name)
    local name = tostring(original_name or "")
    name = name:match("([^/]+)$") or name
    name = name:gsub("[\r\n]", "")
    if name == "" then name = tostring(title or "subtitle") .. ".srt" end
    if not name:match("%.[%w]+$") then name = name .. ".srt" end
    return sanitize_filename(name)
end

local function subtitle_directory_name(title)
    -- sanitize_filename() preserves a legacy trailing dot for extensionless
    -- names. Directories are extensionless names, so remove that dot here.
    return sanitize_filename(tostring(title or "subtitle")):gsub("%.$", "")
end

local function subtitle_cache_title_key(title)
    return tostring(title or ""):gsub("_", " "):gsub("%.*$", "")
        :gsub("%s+", " "):match("^%s*(.-)%s*$"):lower()
end

local MEDIA_CATALOG_FILES = {
    { type = "anime", file = "anime.txt" },
    { type = "movie", file = "movies.txt" },
    { type = "tv", file = "tv.txt" },
}

local function bump_type_count(tbl, content_type)
    tbl[content_type] = (tbl[content_type] or 0) + 1
end

local function load_media_catalog()
    if media_catalog.loaded then return end

    media_catalog.loaded = true
    local loaded_rows = 0

    for _, spec in ipairs(MEDIA_CATALOG_FILES) do
        local selected_path = nil
        local candidates = {SCRIPT_DIR .. "/" .. spec.file, spec.file}

        for _, candidate in ipairs(candidates) do
            local info = utils.file_info(candidate)
            if info and not info.is_dir then
                selected_path = candidate
                break
            end
        end

        if selected_path then
            local f = io.open(selected_path, "r")
            if f then
                for line in f:lines() do
                    local raw_path = line:match("^%s*(.-)%s*$")
                    if raw_path and raw_path ~= "" then
                        local key = normalize_path_key(raw_path)
                        if key then
                            media_catalog.exact_type[key] = spec.type

                            local name = key:match("([^/]+)$")
                            if name then
                                media_catalog.basename_types[name] = media_catalog.basename_types[name] or {}
                                bump_type_count(media_catalog.basename_types[name], spec.type)

                                local stem_key = normalize_stem_key(name)
                                if stem_key ~= "" then
                                    media_catalog.stem_types[stem_key] = media_catalog.stem_types[stem_key] or {}
                                    bump_type_count(media_catalog.stem_types[stem_key], spec.type)
                                end
                            end
                            loaded_rows = loaded_rows + 1
                        end
                    end
                end
                f:close()
            end
        end
    end

    mp.msg.info(string.format("SubDL: media catalog loaded (%d rows)", loaded_rows))
    media_util.set_catalog(media_catalog.exact_type, media_catalog.basename_types, media_catalog.stem_types)
end

-- Unified TMDB lookup for both TV and movies
local function get_tmdb_id(media_type, title, year)
    if not title or title == "" then return nil end
    
    -- Check cache first
    local cache_key = media_type .. ":" .. title:lower() .. (year or "")
    if tmdb_cache[cache_key] then
        mp.msg.info("TMDB: using cached ID for", title)
        return tmdb_cache[cache_key].id, tmdb_cache[cache_key].type
    end
    
    -- Build query based on media type
    local query
    if media_type == "movie" then
        query = string.format("%s/search/movie?api_key=%s&query=%s%s", 
            TMDB_API_URL, TMDB_API_KEY, url_safe(title), year and ("&year=" .. year) or "")
    else
        query = string.format("%s/search/tv?api_key=%s&query=%s", 
            TMDB_API_URL, TMDB_API_KEY, url_safe(title))
    end

    local json = http_get_json(query)
    if json and json.results and #json.results > 0 then
        local first_result = json.results[1]
        tmdb_cache[cache_key] = { id = first_result.id, type = media_type }
        cache_mod.schedule_save()
        mp.msg.info("TMDB ID found:", first_result.id, "Type:", media_type)
        return first_result.id, media_type
    end
    
    -- Fallback for movies: try multi-search
    if media_type == "movie" then
        local fallback_query = year
            and string.format("%s/search/multi?api_key=%s&query=%s&year=%s",
                              TMDB_API_URL, TMDB_API_KEY, url_safe(title), year)
            or string.format("%s/search/multi?api_key=%s&query=%s",
                             TMDB_API_URL, TMDB_API_KEY, url_safe(title))
        local fallback_json = http_get_json(fallback_query)
        if fallback_json and fallback_json.results then
            for _, result in ipairs(fallback_json.results) do
                if result.media_type == "movie" or result.media_type == "tv" then
                    tmdb_cache[cache_key] = { id = result.id, type = result.media_type }
                    cache_mod.schedule_save()
                    return result.id, result.media_type
                end
            end
        end
    end
    
    mp.msg.info("TMDB: no results found for", title)
    return nil
end

local function get_tmdb_id_candidates(media_type, titles, year)
    if not titles or #titles == 0 then return nil end
    for _, t in ipairs(titles) do
        local id, ttype = get_tmdb_id(media_type, t, year)
        if id then return id, ttype, t end
    end
    return nil
end

-- Get season info from TMDB to calculate cour mappings (with caching)
local function get_tmdb_season_info(tmdb_id)
    if not tmdb_id then return nil end
    
    local key = tostring(tmdb_id)
    if tmdb_season_cache[key] then
        mp.msg.info("TMDB: using cached season info for ID", tmdb_id)
        return tmdb_season_cache[key]
    end
    
    local query = string.format("%s/tv/%s?api_key=%s", 
                                TMDB_API_URL, tmdb_id, TMDB_API_KEY)
    
    local json = http_get_json(query)
    if not json or not json.seasons then
        return nil
    end
    
    -- Build episode count per season (excluding season 0 which is specials)
    local seasons = {}
    for _, season in ipairs(json.seasons) do
        if season.season_number and season.season_number > 0 then
            seasons[season.season_number] = season.episode_count or 0
        end
    end
    
    tmdb_season_cache[tostring(tmdb_id)] = seasons
    return seasons
end

match_util._tmdb_season_info = get_tmdb_season_info

local function fetch_subdl_api(query_string)
    return subdl_provider.search(query_string)
end

-- Lookup SubDL sd_id for TV/movie to handle TMDB ID conflicts
-- (same tmdb_id can map to both a movie and TV show on SubDL)

local function get_subdl_sd_id(media_type, tmdb_id, title)
    if not tmdb_id then return nil end

    -- Check cache first
    local cache_key = media_type .. "_" .. tostring(tmdb_id)
    if subdl_sd_cache[cache_key] then
        return subdl_sd_cache[cache_key]
    end

    local sd_id = subdl_provider.get_sd_id(media_type, tmdb_id, title)
    if sd_id then
        subdl_sd_cache[cache_key] = sd_id
        cache_mod.schedule_save()
    end
    return sd_id
end

local function tvdb_resolve_episode_sync(title, absolute_episode)
    if TVDB_API_KEY == "" or not USE_TVDB_COUR then return nil end

    local cache_key = title:lower() .. ":" .. tostring(absolute_episode)
    if tvdb_series_cache[cache_key] then
        mp.msg.info("TVDB: using cached resolution for " .. title .. " ep " .. absolute_episode)
        return tvdb_series_cache[cache_key]
    end

    mp.msg.info("TVDB: resolving absolute " .. absolute_episode .. " for " .. title)

    local login_body = string.format('{"apikey":"%s"}', TVDB_API_KEY)
    local login_cmd = {
        "curl", "-sS", "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", login_body,
        "--connect-timeout", tostring(CURL_TIMEOUT),
        "--max-time", tostring(CURL_TIMEOUT * 2),
        "-w", "\n%{http_code}",
        "https://api4.thetvdb.com/v4/login",
    }
    local login_res = run(login_cmd)
    if login_res.status ~= 0 or not login_res.stdout then
        mp.msg.warn("TVDB: login request failed")
        return nil
    end
    local login_body_raw, login_code = login_res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
    local login_json = login_body_raw and utils.parse_json(login_body_raw) or nil
    if not login_json or not login_json.data or not login_json.data.token then
        mp.msg.warn("TVDB: login failed (http=" .. tostring(login_code) .. ")")
        return nil
    end
    local jwt = login_json.data.token

    local encoded_query = title:gsub(" ", "+")
    local search_url = string.format("https://api4.thetvdb.com/v4/search?query=%s&type=series", encoded_query)
    local search_cmd = {
        "curl", "-sS",
        "-H", "Authorization: Bearer " .. jwt,
        "--connect-timeout", tostring(CURL_TIMEOUT),
        "--max-time", tostring(CURL_TIMEOUT * 2),
        "-w", "\n%{http_code}",
        search_url,
    }
    local search_res = run(search_cmd)
    if search_res.status ~= 0 or not search_res.stdout then
        mp.msg.warn("TVDB: search request failed")
        return nil
    end
    local search_body_raw, search_code = search_res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
    local search_json = search_body_raw and utils.parse_json(search_body_raw) or nil
    if not search_json or not search_json.data or #search_json.data == 0 then
        mp.msg.warn("TVDB: no series found for '" .. title .. "'")
        return nil
    end
    local series_id = search_json.data[1].id

    local page = 0
    while true do
        local ep_url = string.format("https://api4.thetvdb.com/v4/series/%d/episodes/default?page=%d",
                                     series_id, page)
        local ep_cmd = {
            "curl", "-sS",
            "-H", "Authorization: Bearer " .. jwt,
            "--connect-timeout", tostring(CURL_TIMEOUT),
            "--max-time", tostring(CURL_TIMEOUT * 2),
            "-w", "\n%{http_code}",
            ep_url,
        }
        local ep_res = run(ep_cmd)
        if ep_res.status ~= 0 or not ep_res.stdout then break end
        local ep_body_raw = ep_res.stdout:match("^([%s%S]*)\n%d%d%d%s*$")
        local ep_json = ep_body_raw and utils.parse_json(ep_body_raw) or nil
        if not ep_json or not ep_json.data then break end

        local episodes = ep_json.data.episodes or {}
        for _, ep in ipairs(episodes) do
            if ep.absoluteNumber and tonumber(ep.absoluteNumber) == absolute_episode then
                local result = {
                    season  = tonumber(ep.seasonNumber),
                    episode = tonumber(ep.number),
                }
                tvdb_series_cache[cache_key] = result
                cache_mod.schedule_save()
                mp.msg.info(string.format("TVDB: resolved E%d -> S%dE%d for %s",
                             absolute_episode, result.season, result.episode, title))
                return result
            end
        end

        local links = ep_json.data.links or {}
        if not links.next then break end
        page = page + 1
    end

    mp.msg.warn("TVDB: could not resolve absolute " .. absolute_episode .. " for " .. title)
    return nil
end


-- Unified search execution helper
local function execute_search_strategies(strategies, callbacks)
    local all_subs = {}
    local seen_ids = {}
    local log_type = callbacks.type or "search"
    local queries = strategies 

    for i, query in ipairs(queries) do
        mp.msg.info(string.format("SubDL: executing %s strategy %d/%d", log_type, i, #queries))
        local subs = fetch_subdl_api(query)
        normalize_subtitles_metadata(subs)
        -- Season packs arrive as one entry with unpack_files[]; expand to
        -- per-episode entries so ranking picks, and download fetches, the
        -- exact episode file instead of the pack's first file.
        subs = expand_unpack_files(subs)

        for _, sub in ipairs(subs) do
            local sub_id = sub.id or sub.sd_id or tostring(sub)
            if sub_id and not seen_ids[sub_id] then
                if not callbacks.filter or callbacks.filter(sub) then
                    table.insert(all_subs, sub)
                    seen_ids[sub_id] = true
                    if callbacks.on_accept then callbacks.on_accept(sub) end
                end
            end
        end
        
        mp.msg.info(string.format("SubDL: strategy %d added %d unique results (total: %d)", 
                                 i, #subs, #all_subs))
        
        if callbacks.should_stop and callbacks.should_stop(i, #all_subs) then
            mp.msg.info("SubDL: early stop - found enough " .. (log_type == "anime search" and "anime " or "") .. "subtitles")
            break
        end
    end

    if #all_subs == 0 then
        local msg_suffix = ""
        if log_type == "TV search" then msg_suffix = " for this episode"
        elseif log_type == "anime search" then msg_suffix = " for this anime episode" end
        mp.msg.info(string.format("SubDL: no Arabic subtitles found%s", msg_suffix))
        return nil
    end

    return all_subs
end

local function fetch_sub_list_tv(show_title, season, episode, tmdb_id)
    local queries = {}
    local candidates = normalize_title_candidates(show_title)
    if tmdb_id then
        local sd_id = get_subdl_sd_id("tv", tmdb_id, show_title)
        if sd_id then table.insert(queries, string.format("type=tv&sd_id=%s&season_number=%d&episode_number=%d", sd_id, season, episode)) end
        table.insert(queries, string.format("type=tv&tmdb_id=%s&season_number=%d&episode_number=%d", tmdb_id, season, episode))
    end
    local es = string.format("S%02dE%02d", season, episode)
    -- FIX 4: URL encode the entire query value including spaces
    table.insert(queries, "film_name=" .. url_safe(show_title .. " " .. es))
    table.insert(queries, string.format("film_name=%s&season_number=%d&episode_number=%d", url_safe(show_title), season, episode))
    if DEEP_SEARCH then
        for i = 1, math.min(2, #candidates) do
            local c = candidates[i]
            if c ~= show_title then
                table.insert(queries, "film_name=" .. url_safe(c .. " " .. es))
            end
        end
    end
    if not DEEP_SEARCH then queries = limit_queries(queries, 3) end
    
    for i, q in ipairs(queries) do queries[i] = string.format("languages=ar&subs_per_page=50&%s", q) end

    local function tv_episode_filter(sub)
        local pair_set = sub._norm_pairs or {}
        local season_set = sub._norm_seasons or {}
        local ep_set = sub._norm_eps or {}
        if next(pair_set) then
            if not pair_set[season] then return false end
        elseif next(season_set) then
            if not season_set[season] then return false end
        else
            local api_sn = tonumber(sub.season_number) or tonumber(sub.season)
            if api_sn and api_sn ~= season then return false end
        end
        if next(ep_set) and not ep_set[episode] then return false end
        return true
    end

    -- Same season-pool cache as anime: one search per show/season, per-episode
    -- filtering happens in memory on the cached rows.
    local cache_key = string.format("tv/%s/s%d/deep%d",
        tmdb_id and ("tmdb" .. tostring(tmdb_id)) or ("t:" .. show_title:lower()),
        season or 1, DEEP_SEARCH and 1 or 0)
    local raw_subs = search_cache_get(cache_key)
    if raw_subs then
        mp.msg.info(string.format("SubDL: search cache hit (%d season results), filtering for S%02dE%02d",
            #raw_subs, season or 1, episode))
    else
        raw_subs = execute_search_strategies(queries, { type = "TV search" })
        search_cache_put(cache_key, raw_subs)
    end

    local subs = nil
    if raw_subs then
        subs = {}
        for _, sub in ipairs(raw_subs) do
            if tv_episode_filter(sub) then table.insert(subs, sub) end
        end
        if #subs == 0 then subs = nil end
    end
    
    if subs then
        table.sort(subs, function(a, b)
            local a_pairs = a._norm_pairs or {}
            local b_pairs = b._norm_pairs or {}
            local a_match = a_pairs[season] and a_pairs[season][episode]
            local b_match = b_pairs[season] and b_pairs[season][episode]
            if a_match and not b_match then return true end
            if not a_match and b_match then return false end

            local a_season = a_pairs[season] or (a._norm_seasons or {})[season]
            local b_season = b_pairs[season] or (b._norm_seasons or {})[season]
            if a_season and not b_season then return true end
            if not a_season and b_season then return false end

            local a_pack = a._is_pack
            local b_pack = b._is_pack
            if a_pack and not b_pack then return false end
            if not a_pack and b_pack then return true end

            return get_quality_score((a.release_name or ""):lower()) > get_quality_score((b.release_name or ""):lower())
        end)
    end
    return subs
end

local function fetch_sub_list_movie(title, year, tmdb_id)
    local queries = {}
    local candidates = normalize_title_candidates(title)
    local function add(q) table.insert(queries, string.format("languages=ar&subs_per_page=50&%s", q)) end
    
    if tmdb_id then add("type=movie&tmdb_id=" .. tmdb_id) end
    add("film_name=" .. url_safe(title))
    -- FIX 5: URL encode the year query properly
    if year then add("film_name=" .. url_safe(title .. " " .. year)) end
    if DEEP_SEARCH then
        for i = 1, math.min(3, #candidates) do
            local c = candidates[i]
            if c ~= title then
                add("film_name=" .. url_safe(c))
                if year then add("film_name=" .. url_safe(c .. " " .. year)) end
            end
        end
    end
    if not DEEP_SEARCH then queries = limit_queries(queries, 3) end
    
    local subs = execute_search_strategies(queries, {
        type = "movie search",
        filter = function(s)
            if tmdb_id and s.tmdb_id and tostring(s.tmdb_id) ~= tostring(tmdb_id) then
                return false
            end

            local rn = (s.release_name or ""):lower()
            if rn == "" then
                return not tmdb_id or not s.tmdb_id or tostring(s.tmdb_id) == tostring(tmdb_id)
            end

            if not matches_title_words(rn, title) then
                return false
            end

            if year then
                local rn_year = rn:match("(%d%d%d%d)")
                if rn_year and rn_year ~= tostring(year) then
                    return false
                end
            end

            return true
        end
    })
    
    if subs then
        table.sort(subs, function(a, b) return get_quality_score((a.release_name or ""):lower()) > get_quality_score((b.release_name or ""):lower()) end)
    end
    return subs
end

local function fetch_sub_list_anime(title, season, episode, tmdb_id, opts)
    opts = opts or {}
    local cour_mappings

    if opts.tvdb_result then
        local tr = opts.tvdb_result
        cour_mappings = { { season = tr.season, ep = tr.episode } }
        mp.msg.info(string.format("TVDB: using resolved mapping S%dE%d for E%d", tr.season, tr.episode, episode))
    else
        cour_mappings = calculate_cour_mappings(episode, tmdb_id, season)
    end
    local valid_eps, valid_pairs, valid_seasons = build_valid_mapping_sets(cour_mappings)

    local queries = {}
    local sd_id = tmdb_id and get_subdl_sd_id("tv", tmdb_id, title)
    local candidates = normalize_title_candidates(title)
    local function add(q) table.insert(queries, string.format("languages=ar&subs_per_page=50&%s", q)) end

    local max_mapping_queries = DEEP_SEARCH and math.min(#cour_mappings, 10) or math.min(#cour_mappings, 6)

    if sd_id then
        for i = 1, max_mapping_queries do
            local m = cour_mappings[i]
            if m then
                add(string.format("type=tv&sd_id=%s&season_number=%d&episode_number=%d", sd_id, m.season, m.ep))
            end
        end
        add(string.format("type=tv&sd_id=%s", sd_id))
    elseif tmdb_id then
        for i = 1, max_mapping_queries do
            local m = cour_mappings[i]
            if m then
                add(string.format("type=tv&tmdb_id=%s&season_number=%d&episode_number=%d", tmdb_id, m.season, m.ep))
            end
        end
        add(string.format("type=tv&tmdb_id=%s", tmdb_id))
    end

    for i = 1, max_mapping_queries do
        local m = cour_mappings[i]
        if m then
            add("film_name=" .. url_safe(string.format("%s S%02dE%02d", title, m.season, m.ep)))
        end
    end
    add("film_name=" .. url_safe(string.format("%s E%02d", title, episode)))
    add("film_name=" .. url_safe(title))
    if DEEP_SEARCH then
        for i = 1, math.min(3, #candidates) do
            local c = candidates[i]
            if c ~= title then
                add("film_name=" .. url_safe(c))
            end
        end
    end

    queries = dedupe_queries(queries)
    if not DEEP_SEARCH then queries = limit_queries(queries, 10) end

    local function subtitle_matches_cour(sub)
        local se = tonumber(sub.season_number)
        local ep = tonumber(sub.episode_number)

        if se and ep then
            return valid_pairs[se] and valid_pairs[se][ep] or false
        end

        local pair_map = sub._norm_pairs or {}
        local saw_pair = false
        for se_num, ep_set in pairs(pair_map) do
            saw_pair = true
            if valid_pairs[se_num] then
                for ep_num in pairs(ep_set) do
                    if valid_pairs[se_num][ep_num] then
                        return true
                    end
                end
            end
        end
        if saw_pair then return false end

        if ep then
            return valid_eps[ep] or false
        end

        local ep_set = sub._norm_eps or {}
        local saw_ep = false
        for ep_num in pairs(ep_set) do
            saw_ep = true
            if valid_eps[ep_num] then
                return true
            end
        end
        if saw_ep then return false end

        -- Keep ambiguous no-metadata rows as a last-resort fallback.
        return true
    end

    -- Season-level raw pool is episode-independent (SubDL season queries
    -- return the whole candidate pool); cache it, then apply the per-episode
    -- cour filter in memory. Episodes 2..N of a season cost zero search API.
    local cache_key = string.format("anime/%s/s%d/deep%d",
        tmdb_id and ("tmdb" .. tostring(tmdb_id)) or ("t:" .. title:lower()),
        season or 1, DEEP_SEARCH and 1 or 0)
    local raw_subs = search_cache_get(cache_key)
    if raw_subs then
        mp.msg.info(string.format("SubDL: search cache hit (%d season results), filtering for E%d",
            #raw_subs, episode))
    else
        raw_subs = execute_search_strategies(queries, {
            type = "anime search",
            should_stop = function(i, count)
                return not DEEP_SEARCH and i >= 9 and count >= ANIME_EARLY_STOP_COUNT
            end
        })
        search_cache_put(cache_key, raw_subs)
    end

    local subs = nil
    if raw_subs then
        subs = {}
        for _, sub in ipairs(raw_subs) do
            if subtitle_matches_cour(sub) then table.insert(subs, sub) end
        end
        if #subs == 0 then subs = nil end
    end

    local function get_anime_release_score(sub)
        local rn = (sub.release_name or ""):lower()
        local score = get_quality_score(rn)
        local pair_set = sub._norm_pairs or {}
        local season_set = sub._norm_seasons or {}
        local eps = sub._norm_eps or {}

        local has_pair_match = false
        local has_episode_match = false

        for se, ep_set in pairs(pair_set) do
            for ep in pairs(ep_set) do
                if valid_pairs[se] and valid_pairs[se][ep] then
                    has_pair_match = true
                    break
                end
            end
            if has_pair_match then break end
        end

        if not has_pair_match then
            for ep in pairs(eps) do
                if valid_eps[ep] then
                    has_episode_match = true
                    break
                end
            end
        end

        if has_pair_match then
            score = score + 12000
        elseif has_episode_match then
            score = score + 5000
        else
            score = score - 300
        end

        local has_wrong_season = false
        local has_known_season_wrong_ep = false
        for se, ep_set in pairs(pair_set) do
            if not valid_seasons[se] then
                has_wrong_season = true
            else
                local season_ep_ok = false
                for ep in pairs(ep_set) do
                    if valid_pairs[se] and valid_pairs[se][ep] then
                        season_ep_ok = true
                        break
                    end
                end
                if not season_ep_ok then
                    has_known_season_wrong_ep = true
                end
            end
        end

        if has_wrong_season and not has_pair_match then
            score = score - 900
        end
        if has_known_season_wrong_ep and not has_pair_match then
            score = score - 450
        end

        local is_pack = rn:find("season") or rn:find("batch") or rn:find("complete") or rn:find("pack") or rn:find("~")
        if is_pack then
            if has_pair_match then
                score = score - 150
            else
                score = score - 700
            end
        end

        -- Season tags without episode tags are weak signals; penalize lightly if all seasons are off-target.
        if not has_pair_match and next(pair_set) == nil and next(season_set) ~= nil then
            local any_valid = false
            for se in pairs(season_set) do
                if valid_seasons[se] then
                    any_valid = true
                    break
                end
            end
            if not any_valid then
                score = score - 300
            end
        end

        return score
    end

    if subs then
        table.sort(subs, function(a, b)
            return get_anime_release_score(a) > get_anime_release_score(b)
        end)
    end
    return subs
end

local function fetch_sub_list(video_name)
    if subs_cache[video_name] then
        return subs_cache[video_name]
    end

    local path = mp.get_property("path")
    if not path then return nil end

    local extra_candidates = path_title_candidates(path)
    local media = resolve_media_info(path, video_name)

    if media.type_hint and media.hint_source then
        mp.msg.info(string.format("SubDL: media hint=%s via %s", media.type_hint, media.hint_source))
    end

    local subs_list

    if media.content_type == "anime" and media.title and media.episode then
        mp.msg.info(string.format("Searching for anime: %s S%d Episode %d", media.title, media.season or 1, media.episode))

        local candidates = merge_candidates(normalize_title_candidates(media.title), extra_candidates)
        local tmdb_id, media_type, used_title = get_tmdb_id_candidates("tv", candidates)
        if tmdb_id then
            mp.msg.info("TMDB ID found:", tmdb_id, "Type:", media_type, "Title:", used_title or media.title)
        else
            mp.msg.warn("No TMDB ID found, searching by title only")
        end

        if USE_TVDB_COUR and TVDB_API_KEY ~= "" then
            local tvdb_result = tvdb_resolve_episode_sync(media.title, media.episode)
            subs_list = fetch_sub_list_anime(media.title, media.season or 1, media.episode, tmdb_id, {
                tvdb_result = tvdb_result,
            })
        else
            subs_list = fetch_sub_list_anime(media.title, media.season or 1, media.episode, tmdb_id)
        end
    elseif media.content_type == "tv" and media.title and media.season and media.episode then
        mp.msg.info(string.format("Searching for TV show: %s S%02dE%02d", media.title, media.season, media.episode))

        local candidates = merge_candidates(normalize_title_candidates(media.title), extra_candidates)
        local tmdb_id, media_type, used_title = get_tmdb_id_candidates("tv", candidates)
        if tmdb_id then
            mp.msg.info("TMDB ID found:", tmdb_id, "Type:", media_type, "Title:", used_title or media.title)
        else
            mp.msg.warn("No TMDB ID found, searching by title only")
        end

        subs_list = fetch_sub_list_tv(media.title, media.season, media.episode, tmdb_id)
    else
        local title, year = media.title, media.year
        if not title or title == "" then
            mp.msg.warn("Could not extract info from filename:", media.filename)
            return nil
        end

        mp.msg.info("Searching for movie:", title, "Year:", year or "unknown")

        local candidates = merge_candidates(normalize_title_candidates(title), extra_candidates)
        local tmdb_id, media_type, used_title = get_tmdb_id_candidates("movie", candidates, year)
        if tmdb_id then
            mp.msg.info("TMDB ID found:", tmdb_id, "Type:", media_type, "Title:", used_title or title)
        else
            mp.msg.warn("No TMDB ID found, searching by title only")
        end

        subs_list = fetch_sub_list_movie(title, year, tmdb_id)
    end
    
    if not subs_list or #subs_list == 0 then
        mp.msg.info("No Arabic subtitles found")
        return nil
    end

    -- Drop duplicate download URLs so we never burn quota twice on the same zip.
    local before = #subs_list
    subs_list = subdl_provider.dedupe_subs(subs_list)
    if #subs_list < before then
        mp.msg.info(string.format("SubDL: deduped subtitle list %d → %d", before, #subs_list))
    end

    subs_cache[video_name] = subs_list
    last_subs_list = subs_list

    mp.msg.info(string.format("Found %d Arabic subtitles total", #subs_list))
    mp.msg.info("Top 5 subtitle candidates:")
    for i = 1, math.min(5, #subs_list) do
        local sub = subs_list[i]
        local rn = sub.release_name or "Unknown"
        local score = get_quality_score((rn):lower())
        mp.msg.info(string.format("  %d. [%d] %s", i, score, rn))
    end

    return subs_list
end

local function process_download_content(tmp_dir, title, content_type, season, episode, valid_episodes, valid_pairs, video_name, url)
    local files, perm_files = safe_find_subs(tmp_dir), {}
    
    local show_dir = string.format("%s/%s/%s%s", SUBS_DIR, 
        content_type == "movie" and "Movies" or (content_type == "anime" and "Anime" or (content_type == "tv" and "TV" or "Other")),
        subtitle_directory_name(title), (content_type == "tv" or content_type == "anime") and string.format("/S%02d", season or 1) or "")
    safe_mkdir(show_dir)

    if content_type == "tv" or content_type == "anime" then season_files_map[title] = season_files_map[title] or {} end

    for _, f in ipairs(files) do
        local base = f:match("([^/]+)$")
        if matches_title_words(base, title) then
            local dest = show_dir .. "/" .. sanitize_filename(base)
            if utils.file_info(f) and not utils.file_info(dest)
               and not utils.file_info(dest .. ".zst") then
                if not os.rename(f, dest) then safe_copy(f, dest); os.remove(f) end
                -- subtitles live compressed at rest; mpv loads them via the
                -- hot dir (zstd_mod.ensure at every sub-add site).
                dest = zstd_mod.archive_in_place(dest)
                mp.msg.info("SubDL: saved → " .. dest:gsub(SUBS_DIR .. "/", ""))
            elseif utils.file_info(dest .. ".zst") then
                dest = dest .. ".zst" -- already archived from an earlier run
            end
            table.insert(perm_files, dest)
            
            if content_type == "tv" or content_type == "anime" then
                local s, e = base:lower():match("s(%d+)e(%d+)")
                if s then
                     s, e = tonumber(s), tonumber(e)
                     if content_type ~= "anime" or s == 1 then
                         season_files_map[title][s] = season_files_map[title][s] or {}
                         if not season_files_map[title][s][e] then season_files_map[title][s][e] = dest end
                     end
                else
                     e = base:lower():match("e(%d+)") or base:lower():match("ep(%d+)") or base:lower():match("%-[%s]*(%d+)")
                     if e then
                         season_files_map[title][1] = season_files_map[title][1] or {}
                         if not season_files_map[title][1][tonumber(e)] then season_files_map[title][1][tonumber(e)] = dest end
                     end
                end
            end
        else
            mp.msg.warn(string.format("SubDL: ⚠️ Skipping - '%s' doesn't match '%s'", base, title))
        end
    end
    
    local sub_file = content_type == "movie" and perm_files[1] or find_matching_episode_file(perm_files, season, episode, valid_episodes, valid_pairs)
    if sub_file and utils.file_info(sub_file) then
        if content_type == "movie" then
            -- Cache by filename and by movie title for reliable lookup
            movie_files_map[video_name] = sub_file
            movie_files_map[title] = sub_file
        end
        downloaded_subs[video_name] = downloaded_subs[video_name] or {}
        downloaded_subs[video_name][url] = sub_file
        return sub_file
    end
    return nil
end

local function download_and_load(sub, video_name, season, episode, valid_episodes, valid_pairs, on_done)
    downloaded_subs[video_name] = downloaded_subs[video_name] or {}

    local cache_key = subdl_provider.api_download_url(sub)
                       or (sub and (sub.url or sub.download_url))
    if cache_key and downloaded_subs[video_name][cache_key] then
        mp.osd_message("Subtitle loaded", 2)
        mp.commandv("sub-add", zstd_mod.ensure(downloaded_subs[video_name][cache_key]))
        if on_done then on_done(downloaded_subs[video_name][cache_key]) end
        return downloaded_subs[video_name][cache_key]
    end

    local function handle_download(body, code, dl_url, original_name)
        if code == 429 then
            mp.msg.warn("SubDL: HTTP 429 rate limited in single download")
            handle_download_429(RATE_LIMIT_SOFT_MAX_RETRIES, nil, function()
                if on_done then on_done(nil) end
            end)
            return nil
        end

        if not body or body == "" or not dl_url then
            mp.msg.warn("ar_subs: empty download body for url=" .. tostring(dl_url)
                        .. " http_code=" .. tostring(code))
            if on_done then on_done(nil) end
            return nil
        end

        local path = mp.get_property("path")
        local media = resolve_media_info(path, video_name)
        local content_type = media.content_type
        if content_type ~= "anime" and content_type ~= "tv" and content_type ~= "movie" then
            content_type = media.episode and "tv" or "movie"
        end
        local title = media.title or video_name or "unknown"

        local tmp = "/tmp/subdl_extract_" .. os.time()
        safe_mkdir(tmp)
        local out = tmp .. "/" .. downloaded_subtitle_name(title, original_name)
        local f = io.open(out, "w")
        if not f then safe_rm_rf(tmp); if on_done then on_done(nil) end; return nil end
        f:write(body)
        f:close()

        local sub_file = process_download_content(tmp, title, content_type, season, episode, valid_episodes, valid_pairs, video_name, dl_url)
        safe_rm_rf(tmp)
        if sub_file then
            local video_path = mp.get_property("path")
            activation_util.activate(mp, sub_file, video_path, CACHE_TO_MEDIA_DIR)
            mp.msg.info("SubDL: loaded subtitle", sub_file)
        end
        if on_done then on_done(sub_file) end
        return sub_file
    end

    -- Resolve a key with remaining download quota, then fetch once.
    subdl_provider.ensure_download_key(function(key, quota, source)
        if not key or key == "" then
            if quota then
                apply_download_quota_block({ usage = { downloads = {
                    used = quota.used, limit = quota.limit, remaining = 0,
                    reset_at = quota.reset_at, period = quota.period,
                }}})
            else
                mp.osd_message("SubDL download quota exhausted on all keys.", 6)
            end
            if on_done then on_done(nil) end
            return
        end
        mp.msg.info(string.format(
            "SubDL: using %s key for single download (%s remaining)",
            source or "unknown",
            quota and tostring(quota.remaining) or "?"))
        subdl_provider.download_async(sub, function(body, code, dl_url, original_name)
            handle_download(body, code, dl_url, original_name)
        end)
    end)
    return nil
end

local function fetch_bulk_subs(subs_batch, video_name, season, episode, valid_episodes, valid_pairs, on_done)
    local path = mp.get_property("path")
    local media = resolve_media_info(path, video_name)
    local content_type = media.content_type
    if content_type ~= "anime" and content_type ~= "tv" and content_type ~= "movie" then
        content_type = media.episode and "tv" or "movie"
    end
    local title = media.title or video_name or "unknown"

    local tmp_base = "/tmp/subdl_batch_" .. os.time()
    safe_mkdir(tmp_base)

    mp.msg.info(string.format("SubDL: downloading %d subtitles async...", #subs_batch))

    local function process_item(i)
        if i > #subs_batch then
            safe_rm_rf(tmp_base)
            if on_done then on_done(nil) end
            return
        end

        local sub = subs_batch[i]
        if not sub or type(sub) ~= "table" then
            mp.msg.warn("ar_subs: invalid sub, skipping batch item " .. i)
            mp.add_timeout(0.5, function() process_item(i + 1) end)
            return
        end

        subdl_provider.download_async(sub, function(body, code, dl_url, original_name)
            if code == 429 then
                mp.msg.warn("SubDL: HTTP 429 rate limited, stopping batch")
                safe_rm_rf(tmp_base)
                if on_done then on_done(nil, true) end
                return
            end
            if body and body ~= "" and dl_url then
                local extract_dir = string.format("%s/%d", tmp_base, i)
                safe_mkdir(extract_dir)
                local out = extract_dir .. "/" .. downloaded_subtitle_name(title, original_name)
                local f = io.open(out, "w")
                if f then
                    f:write(body)
                    f:close()

                    local loaded = process_download_content(extract_dir, title, content_type, season, episode, valid_episodes, valid_pairs, video_name, dl_url)
                    if loaded then
                        safe_rm_rf(tmp_base)
                        local video_path = mp.get_property("path")
                        activation_util.activate(mp, loaded, video_path, CACHE_TO_MEDIA_DIR)
                        mp.msg.info("SubDL: loaded subtitle", loaded)
                        if on_done then on_done(loaded) end
                        return
                    end
                end
            else
                mp.msg.warn("ar_subs: empty download body for batch item " .. i
                            .. " http_code=" .. tostring(code))
            end
            mp.add_timeout(0.5, function() process_item(i + 1) end)
        end)
    end

    process_item(1)
    return nil
end

-- opts.auto = true  → frugal auto-fetch (1 download max)
-- opts.auto = false → manual next (up to MANUAL_MAX_DOWNLOAD_ATTEMPTS)
local function fetch_next_sub(opts)
    opts = opts or {}
    local is_auto = opts.auto == true
    local max_attempts = is_auto and AUTO_MAX_DOWNLOAD_ATTEMPTS or MANUAL_MAX_DOWNLOAD_ATTEMPTS

    if not is_enabled() then return end
    if rate_limit_until and os.time() < rate_limit_until then
        local wait = rate_limit_until - os.time()
        mp.osd_message(string.format("Rate limited, try again in %ds", wait), math.min(wait + 1, 8))
        return
    end
    rate_limit_until = nil
    local path = mp.get_property("path")
    if not path then return end
    
    local video_name = basename(path)
    local extra_candidates = path_title_candidates(path)
    local media = resolve_media_info(path, video_name)

    local show_title = media.title
    local season = media.season
    local episode = media.episode
    local is_anime = (media.content_type == "anime")
    local tmdb_id = nil

    if is_anime and show_title and episode then
        local candidates = merge_candidates(normalize_title_candidates(show_title), extra_candidates)
        tmdb_id = get_tmdb_id_candidates("tv", candidates)
    end
    
    local valid_episodes, valid_pairs = nil, nil
    if is_anime and episode then
        local cour_mappings = calculate_cour_mappings(episode, tmdb_id, season)
        valid_episodes, valid_pairs = build_valid_mapping_sets(cour_mappings)
    end
    
    local subs_list = fetch_sub_list(video_name)
    if not subs_list then
        mp.osd_message("No Arabic subtitles found", 3); return
    end

    current_index[video_name] = current_index[video_name] or 0

    local function try_batch(attempt)
        if attempt > max_attempts then
            if is_auto then
                mp.osd_message("No matching Arabic sub yet — press Ctrl+Shift+V to try next", 4)
            else
                mp.osd_message("Failed to load subtitle from candidates", 3)
            end
            return
        end

        if rate_limit_until and os.time() < rate_limit_until then
            local wait = rate_limit_until - os.time()
            -- Quota blocks can span hours; don't schedule multi-hour auto-retries.
            if wait > RATE_LIMIT_SOFT_WAIT + 5 then
                mp.osd_message(string.format("Download quota exhausted, try again in %ds", wait), 6)
                return
            end
            mp.osd_message(string.format("Rate limited, waiting %ds...", wait), wait + 1)
            mp.add_timeout(wait + 1, function() try_batch(attempt) end)
            return
        end
        rate_limit_until = nil

        local start_idx = current_index[video_name] + 1
        if start_idx > #subs_list then
            mp.osd_message("No more subtitles available", 3)
            mp.msg.info(string.format("SubDL: no more subtitles available (tried all %d)", #subs_list))
            current_index[video_name] = #subs_list
            return
        end

        local end_idx = math.min(start_idx + BATCH_SIZE - 1, #subs_list)
        local batch = {}
        for i = start_idx, end_idx do table.insert(batch, subs_list[i]) end

        local function start_download()
            osd_show(string.format("Downloading %d/%d...", start_idx, #subs_list))
            fetch_bulk_subs(batch, video_name, season, episode, valid_episodes, valid_pairs, function(loaded, rate_limited)
                osd_remove()
                if loaded then
                    current_index[video_name] = end_idx
                    mp.osd_message("Subtitle loaded", 2)
                    return
                end
                if rate_limited then
                    handle_download_429(attempt, function(wait)
                        mp.add_timeout(wait + 1, function() try_batch(attempt + 1) end)
                    end, function(_reason)
                        -- Hard stop: do not advance index so a later manual
                        -- retry can re-try this candidate after quota resets.
                    end)
                    return
                end
                -- Candidate downloaded but didn't match episode/title — advance
                -- one slot only (BATCH_SIZE=1) so the next press/attempt is frugal.
                current_index[video_name] = end_idx
                if attempt < max_attempts then
                    mp.osd_message("Candidate missed, trying next...", 1)
                    mp.add_timeout(0.1, function() try_batch(attempt + 1) end)
                else
                    if is_auto then
                        mp.osd_message("No matching Arabic sub yet — press Ctrl+Shift+V to try next", 4)
                    else
                        mp.osd_message("No matching subtitle in this try", 3)
                    end
                end
            end)
        end

        -- Pick a key that still has download quota before spending one.
        subdl_provider.ensure_download_key(function(key, quota, source)
            if not key or key == "" then
                if quota then
                    apply_download_quota_block({ usage = { downloads = {
                        used = quota.used, limit = quota.limit, remaining = 0,
                        reset_at = quota.reset_at, period = quota.period,
                    }}})
                else
                    mp.osd_message("SubDL download quota exhausted on all keys.", 6)
                end
                return
            end
            mp.msg.info(string.format(
                "SubDL: using %s key for download (%s remaining)",
                source or "unknown",
                quota and tostring(quota.remaining) or "?"))
            start_download()
        end)
    end

    try_batch(1)
end

local function has_arabic_sub()
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "sub" and (track.lang or ""):match("^ar") then return true end
    end
end

local function count_arabic_subs()
    local count = 0
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "sub" and (track.lang or ""):match("^ar") then
            count = count + 1
        end
    end
    return count
end

-- True when an external subtitle whose filename stem matches the playing video
-- is already loaded -- the per-episode sibling the user keeps in-folder. Treated
-- as "this episode already has its subtitle" so we don't fetch a duplicate.
local SIBLING_SUB_EXTS = { srt = true, ass = true, ssa = true, sub = true, vtt = true }

local function has_sibling_sub()
    local path = mp.get_property("path")
    if not path then return false end
    local stem = (basename(path):match("(.+)%.%w+$") or ""):lower()
    if stem == "" then return false end
    -- Track-list check (a matching external sub already loaded).
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
        if t.type == "sub" and t.external then
            local fn = t["external-filename"] or ""
            local sub_stem = (basename(fn):match("(.+)%.%w+$") or ""):lower()
            if sub_stem ~= "" and sub_stem == stem then return true end
        end
    end
    -- Filesystem check: a same-stem subtitle file next to the video. This does
    -- not depend on autoload having populated the track list yet, so it fires
    -- reliably on first load.
    local dir = path:match("^(.*)/[^/]*$")
    if dir then
        for _, fn in ipairs(utils.readdir(dir, "files") or {}) do
            local fstem, fext = fn:match("(.+)%.([%w]+)$")
            if fstem and fext and SIBLING_SUB_EXTS[fext:lower()]
                and fstem:lower() == stem then
                return true
            end
        end
    end
    return false
end

local function publish_uosc_button()
    local ar_count = count_arabic_subs()
    local tooltip = "Arabic Subs"
    if DEEP_SEARCH then tooltip = tooltip .. " (Deep: ON)" end
    local data = {
        icon = "subtitles",
        active = DEEP_SEARCH,
        badge = ar_count > 0 and tostring(ar_count) or nil,
        tooltip = tooltip,
        command = "script-binding ar_subs/ar_subs_search",
    }
    mp.commandv("script-message-to", "uosc", "set-button", "ar_subs", utils.format_json(data))
end

local function toggle_deep_search()
    DEEP_SEARCH = not DEEP_SEARCH
    mp.osd_message("SubDL deep search: " .. (DEEP_SEARCH and "ON" or "OFF"), 2)
    publish_uosc_button()
end

local function scan_local_files_for_episode(show_title, season, episode, content_type)
    if not show_title or not episode then return nil end
    local type_dir = content_type == "anime" and "Anime" or (content_type == "tv" and "TV" or nil)
    if not type_dir then return nil end
    
    local search_dir = string.format("%s/%s/%s/S%02d", SUBS_DIR, type_dir, subtitle_directory_name(show_title), season or 1)
    if not utils.file_info(search_dir) then return nil end
    
    local files = safe_find_subs(search_dir)
    if #files == 0 then return nil end

    -- Match with the SAME episode parser the rest of the pipeline uses.
    -- The old substring heuristic scored the bare episode digits anywhere
    -- in the name, so the "08" inside "1080" matched episode 8 and the
    -- first file in find order (a DIFFERENT episode's subtitle) was loaded
    -- and persisted as the E08 entry. There is also no minimum score, so
    -- some wrong file always won.
    local valid_episodes = {[tonumber(episode)] = true}
    local valid_pairs = {[tonumber(season or 1)] = {[tonumber(episode)] = true}}
    local best_match = nil
    for _, file in ipairs(files) do
        local fname = (file:match("([^/]+)$") or ""):lower()
        if not fname:find("_retimed", 1, true)
           and find_matching_episode_file({file}, season or 1, episode,
                   valid_episodes, valid_pairs) then
            best_match = file
            break
        end
    end

    if best_match then
        season_files_map[show_title] = season_files_map[show_title] or {}
        season_files_map[show_title][season or 1] = season_files_map[show_title][season or 1] or {}
        season_files_map[show_title][season or 1][episode] = best_match
    end
    return best_match
end

local function check_existing_season_files(show_title, season, episode)
    if show_title and season and episode then
        local cached_seasons = season_files_map[show_title]
        if not cached_seasons then
            local wanted = subtitle_cache_title_key(show_title)
            for cached_title, seasons in pairs(season_files_map) do
                if subtitle_cache_title_key(cached_title) == wanted then
                    cached_seasons = seasons
                    season_files_map[show_title] = seasons
                    break
                end
            end
        end
        if not cached_seasons or not cached_seasons[season] then return false end

        local target_file = cached_seasons[season][episode]
        if target_file and utils.file_info(target_file) then
            -- Validate persisted/indexed entries before loading them. A stale
            -- cache entry with a generic or unrelated filename must not win
            -- merely because its table key happens to be SxxExx.
            local valid_episodes = {[tonumber(episode)] = true}
            local valid_pairs = {[tonumber(season)] = {[tonumber(episode)] = true}}
            local matched = find_matching_episode_file(
                {target_file}, season, episode, valid_episodes, valid_pairs)
            if not matched then
                mp.msg.warn(string.format(
                    "SubDL: ignoring stale cached subtitle for %s S%02dE%02d: %s",
                    show_title, season, episode, target_file))
                cached_seasons[season][episode] = nil
                return false
            end
            mp.msg.info(string.format("SubDL: Found cached %s S%02dE%02d: %s", show_title, season, episode, target_file))
            mp.commandv("sub-add", zstd_mod.ensure(target_file))
            return true
        end
    end
    return false
end

-- Check if video file already has a cached subtitle (by exact filename)
local function check_existing_subtitle_for_file(video_filename)
    if not video_filename then return false end

    local function try_key(key)
        local target_file = key and movie_files_map[key]
        if target_file and utils.file_info(target_file) then
            mp.msg.info(string.format("SubDL: Found cached subtitle for '%s': %s", key, target_file))
            mp.commandv("sub-add", zstd_mod.ensure(target_file))
            return true
        end
        return false
    end

    if try_key(video_filename) then return true end

    -- Try movie title as a fallback cache key
    local title = extract_movie_info(video_filename)
    if title and try_key(title) then return true end

    return false
end

-- Ask the subtitle-api container for the one matching subtitle file before
-- spending any SubDL quota. The API does the DB lookup + archive extraction
-- and returns the episode-matched .srt/.ass bytes; we persist it into the
-- season dir (so offline replays hit the normal local cache) and return the
-- path. Returns the subtitle path or nil.
-- Load one specific candidate (by subscene_id) via the API, persist it into
-- the season dir, register it for offline replays. Returns the path or nil.
local function load_api_candidate(media, video_name, subscene_id)
    local tmp = subtitle_api.fetch({
        title = media.title,
        season = media.season,
        episode = media.episode,
        content_type = media.content_type,
        filename = video_name,
    }, subscene_id)
    if not tmp then return nil end

    local meta = subtitle_api.last_meta() or {}
    local ctype = media.content_type
    local season = media.season or 1
    local type_dir = ctype == "movie" and "Movies"
        or (ctype == "anime" and "Anime" or (ctype == "tv" and "TV" or "Other"))
    local show_dir = string.format("%s/%s/%s%s", SUBS_DIR, type_dir,
        subtitle_directory_name(media.title),
        (ctype == "tv" or ctype == "anime") and string.format("/S%02d", season) or "")
    safe_mkdir(show_dir)

    local src_name = (meta.filename or ""):match("([^/]+)$")
    if not src_name or src_name == "" then src_name = "subtitle.srt" end
    local dest = show_dir .. "/" .. sanitize_filename(src_name)
    local cp = safe_copy(tmp, dest)
    os.remove(tmp)
    if not (cp and cp.status == 0) then
        mp.msg.warn("subtitle-api: could not persist " .. tostring(dest))
        return nil
    end
    dest = zstd_mod.archive_in_place(dest)

    if ctype == "tv" or ctype == "anime" then
        season_files_map[media.title] = season_files_map[media.title] or {}
        season_files_map[media.title][season] = season_files_map[media.title][season] or {}
        -- overwrite any stale/dangling entry so a fresh API result wins.
        if media.episode then
            season_files_map[media.title][season][media.episode] = dest
        end
    end
    mp.msg.info(string.format("subtitle-api: loaded %s (conf=%s show=%s)",
        dest:gsub(SUBS_DIR .. "/", ""), tostring(meta.conf or "?"), tostring(meta.show or "?")))
    return dest
end

-- Ask the subtitle-api for the top-N candidates, load the best one, and stash
-- the list so Ctrl+Shift+V can step through the rest. Returns the path or nil.
-- SubSource.net online source. SubSource keys TV entries PER SEASON (each
-- season is its own "movie" row), so the movieId is resolved for the exact
-- season and memoized in-memory. The listing endpoint does not reliably
-- filter by episode, so packs naming a different episode are dropped and
-- the rest are tried in downloads order -- the final gate is always the
-- episode match on the files inside the pack (process_download_content).
local subsource_ids = {} -- title(lower) -> { [season] = movieId }

local function subsource_movie_id(title, season, content_type)
    local tkey = (title or ""):lower()
    local want_season = season or 1
    subsource_ids[tkey] = subsource_ids[tkey] or {}
    if subsource_ids[tkey][want_season] then
        return subsource_ids[tkey][want_season]
    end
    local rows = subsource_mod.search_show(title)
    if not rows then return nil end
    local best, best_score = nil, -1
    for _, r in ipairs(rows) do
        if (r.subtitleCount or 0) > 0 then
            local score = 0
            local rt = (r.title or ""):lower()
            if rt == tkey then score = score + 4
            elseif rt:find(tkey, 1, true) or tkey:find(rt, 1, true) then score = score + 2 end
            if content_type == "movie" then
                if r.type == "movie" then score = score + 3 end
            else
                if (r.season or 0) == want_season then score = score + 3 end
            end
            if score > best_score then best, best_score = r, score end
        end
    end
    if best then
        subsource_ids[tkey][want_season] = best.movieId
        return best.movieId
    end
    return nil
end

-- Reject only packs that explicitly name a DIFFERENT episode; packs with no
-- episode info (season packs) pass and get verified by the member match.
local function pack_covers_episode(release, season, episode)
    if not episode then return true end
    local r = (release or ""):lower()
    local s2, e2 = r:match("s(%d+)[%s%.%-_]*e(%d+)")
    if s2 and e2 then return tonumber(e2) == tonumber(episode) end
    local e3 = r:match("[%s%.%-_%.%[]e(%d+)")
    if e3 and #e3 <= 3 then return tonumber(e3) == tonumber(episode) end
    return true
end

local function try_subsource(media, video_name)
    if not subsource_mod.available() or not media or not media.title then return nil end
    local season = media.season or 1
    local episode = media.episode
    local mid = subsource_movie_id(media.title, season, media.content_type)
    if not mid then return nil end
    local packs = subsource_mod.list_subs(mid, season, episode)
    if not packs or #packs == 0 then return nil end
    local ranked = {}
    for _, p in ipairs(packs) do
        if pack_covers_episode((p.releaseInfo or {})[1], season, episode) then
            ranked[#ranked + 1] = p
        end
    end
    table.sort(ranked, function(a, b) return (a.downloads or 0) > (b.downloads or 0) end)
    local valid_episodes = episode and { [tonumber(episode)] = true } or nil
    local valid_pairs = episode and { [season] = { [tonumber(episode)] = true } } or nil
    for _, p in ipairs(ranked) do
        local zip = subsource_mod.download(p.subtitleId)
        if zip then
            local tmp_dir = "/tmp/subsource_unpack_" .. tostring(p.subtitleId)
            safe_rm_rf(tmp_dir); safe_mkdir(tmp_dir)
            local uz = safe_unzip(zip, tmp_dir)
            os.remove(zip)
            if uz and uz.status == 0 then
                local rel = (p.releaseInfo or { "?" })[1]
                mp.msg.info(string.format("SubSource: trying pack %s (downloads=%s)",
                    tostring(rel), tostring(p.downloads)))
                local got = process_download_content(tmp_dir, media.title,
                    media.content_type, season, episode,
                    valid_episodes, valid_pairs, video_name,
                    "subsource://" .. tostring(p.subtitleId))
                safe_rm_rf(tmp_dir)
                if got then
                    mp.msg.info("SubSource: loaded " .. tostring(rel))
                    return got
                end
            else
                safe_rm_rf(tmp_dir)
            end
        end
    end
    return nil
end

local function try_local_db(media, video_name)
    if not subtitle_api.available() or not media or not media.title then return nil end
    local cands = subtitle_api.candidates({
        title = media.title,
        season = media.season,
        episode = media.episode,
        content_type = media.content_type,
        filename = video_name,
    }, 5)
    if not cands or #cands == 0 then
        local_candidates[video_name] = nil
        return nil
    end
    local_candidates[video_name] = cands
    mp.msg.info(string.format("subtitle-api: %d candidate(s) for %s", #cands, media.title))
    -- Load the first candidate that actually serves a file. A candidate can be
    -- unservable (its episode member is corrupt in the dump), so step down the
    -- list; Ctrl+Shift+V continues from whichever one loaded.
    for i = 1, #cands do
        local dest = load_api_candidate(media, video_name, cands[i].subscene_id)
        if dest then
            local_idx[video_name] = i
            return dest
        end
    end
    return nil
end

-- Ctrl+Shift+V: load the next local candidate for this video, if any remain.
local function try_local_next(media, video_name)
    local cands = local_candidates[video_name]
    if not cands then return nil end
    local nxt = (local_idx[video_name] or 0) + 1
    if not cands[nxt] then return nil end
    local dest = load_api_candidate(media, video_name, cands[nxt].subscene_id)
    if dest then
        local_idx[video_name] = nxt
        return dest
    end
    return nil
end

local function enhanced_auto_fetch_if_needed()
    if not is_enabled() then return end
    local path = mp.get_property("path")
    if not path then return end
    
    local video_name = basename(path)
    local media = resolve_media_info(path, video_name)

    -- The episode's own sibling subtitle is already loaded -> nothing to fetch.
    if SKIP_IF_SIBLING_SUB and has_sibling_sub() then
        mp.msg.info("SubDL: matching sibling subtitle already loaded, skipping fetch")
        return
    end

    -- Check cached files based on media content_type
    if media.content_type == "movie" then
        if check_existing_subtitle_for_file(media.filename) then
            mp.osd_message("Loaded cached subtitle", 2)
            return
        end
    elseif media.content_type == "anime" and media.title and media.episode then
        local season = media.season or 1
        if check_existing_season_files(media.title, season, media.episode) then mp.osd_message("Loaded cached subtitle", 2); return end
        local local_file = scan_local_files_for_episode(media.title, season, media.episode, "anime")
        if local_file then mp.commandv("sub-add", zstd_mod.ensure(local_file)); mp.osd_message("Loaded local subtitle", 2); return end
    elseif media.content_type == "tv" and media.title and media.season and media.episode then
        if check_existing_season_files(media.title, media.season, media.episode) then mp.osd_message("Loaded cached subtitle", 2); return end
        local local_file = scan_local_files_for_episode(media.title, media.season, media.episode, "tv")
        if local_file then mp.commandv("sub-add", zstd_mod.ensure(local_file)); mp.osd_message("Loaded local subtitle", 2); return end
    end
    
    -- Offline Subscene index: zero-quota local hit before any API search.
    if not has_arabic_sub() then
        local local_sub = try_local_db(media, video_name)
        if local_sub then
            local vpath = mp.get_property("path")
            activation_util.activate(mp, local_sub, vpath, CACHE_TO_MEDIA_DIR)
            mp.msg.info("SubDL: loaded subtitle from local DB", local_sub)
            mp.osd_message("Loaded local DB subtitle", 2)
            return
        end
    end

    -- SubSource.net: second source (after the offline index, before SubDL).
    if not has_arabic_sub() then
        local ss_sub = try_subsource(media, video_name)
        if ss_sub then
            activation_util.activate(mp, ss_sub, mp.get_property("path"), CACHE_TO_MEDIA_DIR)
            mp.osd_message("Loaded SubSource subtitle", 2)
            return
        end
    end

    if not has_arabic_sub() then
        osd_show("Searching for Arabic subtitles...")
        -- Auto path: top candidate only (1 download). Manual next for more.
        -- SubDL is the LAST resort now (offline index + SubSource run first).
        fetch_next_sub({ auto = true })
    end
end

-- Save cache to disk for persistence
save_runtime_cache = function()
    -- Create cache directory if it doesn't exist
    safe_mkdir(CACHE_DIR)
    
    -- Convert numeric keys to strings for JSON compatibility
    local cache_data = {
        tmdb = tmdb_cache,
        tmdb_cache = tmdb_cache,
        subdl_sd_cache = subdl_sd_cache,
        tmdb_seasons = cache_mod.stringify_keys(tmdb_season_cache),
        tvdb_series = tvdb_series_cache,
        season_files = cache_mod.stringify_keys(season_files_map),
        movie_files = movie_files_map  -- No numeric keys, just title -> file
    }
    local json_str = utils.format_json(cache_data)
    if json_str then
        local f = io.open(CACHE_FILE, "w")
        if f then
            f:write(json_str)
            f:close()
            mp.msg.info("SubDL: saved cache to " .. CACHE_FILE)
        end
    end
end

cache_mod.init(save_runtime_cache, mp)

-- Load cache from disk
load_runtime_cache = function()
    local f = io.open(CACHE_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local cache_data = utils.parse_json(content)
        if cache_data then
            cache_data = cache_mod.migrate_keys(cache_data)
            tmdb_cache = cache_data.tmdb or cache_data.tmdb_cache or {}
            subdl_sd_cache = cache_data.subdl_sd_cache or {}
            tmdb_season_cache = cache_data.tmdb_seasons or {}
            tvdb_series_cache = cache_data.tvdb_series or {}
            
            -- Load season files (TV/anime) - only if files still exist
            if cache_data.season_files then
                for show, seasons in pairs(cache_data.season_files) do
                    for season, eps in pairs(seasons) do
                        for ep, file in pairs(eps) do
                            if utils.file_info(file) then
                                season_files_map[show] = season_files_map[show] or {}
                                season_files_map[show][tonumber(season)] = season_files_map[show][tonumber(season)] or {}
                                season_files_map[show][tonumber(season)][tonumber(ep)] = file
                            end
                        end
                    end
                end
            end
            
            -- Load movie files - only if files still exist
            if cache_data.movie_files then
                for title, file in pairs(cache_data.movie_files) do
                    if utils.file_info(file) then
                        movie_files_map[title] = file
                    end
                end
            end
            
            mp.msg.info("SubDL: loaded cache from disk")
        end
    end
end

-- Scan all local subtitle files and build index (for 1200+ files)
local function index_local_files()
    local start_time = os.time()
    local count = 0
    
    -- Scan each content type directory
    local content_dirs = {
        {path = SUBS_DIR .. "/TV", type = "tv"},
        {path = SUBS_DIR .. "/Anime", type = "anime"},
        {path = SUBS_DIR .. "/Movies", type = "movie"},
    }
    
    for _, dir_info in ipairs(content_dirs) do
        if utils.file_info(dir_info.path) then
            local files = safe_find_subs(dir_info.path)
            for _, file in ipairs(files) do
                -- Extract show/season/episode from path
                -- Pattern: .../TV/Show_Name/S01/subtitle.srt
                local show, season_str, basename = file:match("/([^/]+)/S(%d+)/([^/]+)$")
                if show and season_str then
                    local season = tonumber(season_str)
                    -- names are stored with a .zst suffix when archived; the
                    -- episode parser wants the original subtitle name.
                    basename = basename:gsub("%.zst$", "")
                    local basename_lower = basename:lower()
                    
                    -- Extract episode number
                    local ep = basename_lower:match("s%d+e(%d+)")
                           or basename_lower:match("e(%d+)")
                           or basename_lower:match("ep(%d+)")
                           or basename_lower:match("- (%d+)")
                           or basename_lower:match("episode[%s]*(%d+)")
                    ep = ep and tonumber(ep)
                    
                    if ep then
                        -- Normalize show name back from filesystem format
                        local show_normalized = show:gsub("_", " "):gsub("%.$", "")
                        season_files_map[show_normalized] = season_files_map[show_normalized] or {}
                        season_files_map[show_normalized][season] = season_files_map[show_normalized][season] or {}
                        if not season_files_map[show_normalized][season][ep] then
                            season_files_map[show_normalized][season][ep] = file
                            count = count + 1
                        end
                    end
                elseif dir_info.type == "movie" then
                    -- For movies: .../Movies/Title_Name/subtitle.srt
                    local movie_title = file:match("/Movies/([^/]+)/[^/]+$")
                    if movie_title and not movie_files_map[movie_title] then
                        movie_files_map[movie_title:gsub("_", " ")] = file
                        count = count + 1
                    end
                end
            end
        end
    end
    
    local elapsed = os.time() - start_time
    mp.msg.info(string.format("SubDL: indexed %d local subtitle files in %ds", count, elapsed))
end

-- Manual search with custom query
local function manual_search()
    if not is_enabled() then mp.osd_message("Sub-Search disabled (restricted path/type)", 3); return end
    mp.osd_message("Enter search query in console (press ` to open)", 5)
    
    -- Use input console for manual search
    mp.add_timeout(0.1, function()
        mp.commandv("script-message-to", "console", "type", "script-message ar_subs_search ")
    end)
end

local function show_picker(subs)
    if not has_uosc then return end
    if not subs or #subs == 0 then
        mp.osd_message("No Arabic subtitles to pick", 2)
        return
    end
    local menu = uosc_picker.build_menu(subs)
    mp.commandv("script-message-to", "uosc", "open-menu", "command-menu",
                utils.format_json(menu))
end

local function ar_subs_pick()
    if not is_enabled() then return end
    if rate_limit_until and os.time() < rate_limit_until then
        local wait = rate_limit_until - os.time()
        mp.osd_message(string.format("Rate limited, try again in %ds", wait), wait + 1)
        return
    end
    local path = mp.get_property("path")
    if not path then return end

    local video_name = basename(path)
    local cached = subs_cache[video_name]
    if cached and #cached > 0 then
        show_picker(cached)
        return
    end

    osd_show("Searching for Arabic subtitles...")
    mp.add_timeout(0, function()
        local subs = fetch_sub_list(video_name)
        osd_remove()
        if not subs or #subs == 0 then
            mp.osd_message("No Arabic subtitles found", 3)
            return
        end
        show_picker(subs)
    end)
end

-- Handle manual search query
local function handle_manual_search(query)
    if not is_enabled() then return end
    if rate_limit_until and os.time() < rate_limit_until then
        local wait = rate_limit_until - os.time()
        mp.osd_message(string.format("Rate limited, try again in %ds", wait), wait + 1)
        return
    end
    if not query or query == "" then
        mp.osd_message("No search query provided", 2)
        return
    end
    
    mp.osd_message("Searching: " .. query, 2)
    
    -- film_name, not query: the v2 endpoint 400s on a bare query= search.
    local api_url = string.format("film_name=%s&languages=ar&subs_per_page=50",
                                  url_safe(query))
    
    local subs = fetch_subdl_api(api_url)
    if #subs == 0 then
        mp.osd_message("No subtitles found for: " .. query, 3)
        return
    end
    
    -- Sort by quality
    table.sort(subs, function(a, b)
        local rn_a = (a.release_name or ""):lower()
        local rn_b = (b.release_name or ""):lower()
        return get_quality_score(rn_a) > get_quality_score(rn_b)
    end)
    
    -- Get current video name for download
    local path = mp.get_property("path")
    if not path then return end
    local video_name = basename(path)
    local media = resolve_media_info(path, video_name)
    
    mp.osd_message(string.format("Found %d subtitles, loading best match...", #subs), 2)
    
    -- Download the best one using proper storage
    local sub = subs[1]
    local dl_season = media.season or 1
    local dl_episode = media.episode
    local valid_episodes, valid_pairs = nil, nil

    if media.content_type == "anime" and media.title and dl_episode then
        local extra_candidates = path_title_candidates(path)
        local candidates = merge_candidates(normalize_title_candidates(media.title), extra_candidates)
        local tmdb_id = get_tmdb_id_candidates("tv", candidates)
        local cour_mappings = calculate_cour_mappings(dl_episode, tmdb_id, dl_season)
        valid_episodes, valid_pairs = build_valid_mapping_sets(cour_mappings)
    end

    download_and_load(sub, video_name, dl_season, dl_episode, valid_episodes, valid_pairs, function(loaded)
        if loaded then
            mp.osd_message("Loaded: " .. loaded:match("([^/]+)$"), 3)
        else
            mp.osd_message("Failed to load subtitle", 3)
        end
    end)
end

-- Load cache on startup
load_runtime_cache()
-- Scan all local subtitles (handles files not in JSON cache)
index_local_files()
-- Load media path catalogs if present (anime.txt, movies.txt, tv.txt)
load_media_catalog()

mp.register_event("file-loaded", enhanced_auto_fetch_if_needed)
mp.register_event("end-file", abort_inflight)
mp.register_event("shutdown", function() cache_mod.force_save() end)
mp.add_key_binding("Ctrl+Shift+V", "ar_subs_next", function()
    -- Step through the local top-N candidates first; when exhausted, fall
    -- through to the SubDL "next candidate" path.
    if is_enabled() then
        local path = mp.get_property("path")
        local video_name = path and basename(path) or nil
        local media = path and resolve_media_info(path, video_name) or nil
        if media and video_name and local_candidates[video_name] then
            local nxt = try_local_next(media, video_name)
            if nxt then
                activation_util.activate(mp, nxt, path, CACHE_TO_MEDIA_DIR)
                mp.osd_message(string.format("Local subtitle %d/%d",
                    local_idx[video_name], #local_candidates[video_name]), 2)
                return
            end
        end
    end
    fetch_next_sub({ auto = false })
end)
mp.add_key_binding("Ctrl+V", "ar_subs_toggle_deep", toggle_deep_search)
mp.add_key_binding("Alt+V", "ar_subs_search", manual_search)
mp.add_key_binding("Ctrl+Alt+v", "ar_subs_pick", ar_subs_pick)
mp.register_script_message("ar_subs_search", handle_manual_search)
mp.register_script_message("ar_subs_download_item", function(index)
    index = tonumber(index) -- script-message args arrive as strings
    if not index then
        mp.osd_message("Invalid subtitle index", 2)
        return
    end
    if rate_limit_until and os.time() < rate_limit_until then
        local wait = rate_limit_until - os.time()
        mp.osd_message(string.format("Rate limited, try again in %ds", wait), wait + 1)
        return
    end
    local path = mp.get_property("path")
    if not path then return end
    local video_name = basename(path)
    local subs = subs_cache[video_name] or last_subs_list
    if not subs or not subs[index] then
        mp.osd_message("Invalid subtitle index", 2)
        return
    end
    local sub = subs[index]
    local media = resolve_media_info(path, video_name)
    local dl_season = media.season or 1
    local dl_episode = media.episode
    local valid_episodes, valid_pairs = nil, nil

    if media.content_type == "anime" and media.title and dl_episode then
        local extra_candidates = path_title_candidates(path)
        local candidates = merge_candidates(normalize_title_candidates(media.title), extra_candidates)
        local tmdb_id = get_tmdb_id_candidates("tv", candidates)
        local cour_mappings = calculate_cour_mappings(dl_episode, tmdb_id, dl_season)
        valid_episodes, valid_pairs = build_valid_mapping_sets(cour_mappings)
    end

    download_and_load(sub, video_name, dl_season, dl_episode, valid_episodes, valid_pairs, function(loaded)
        if loaded then
            mp.osd_message("Loaded: " .. (loaded:match("([^/]+)$") or loaded), 3)
        else
            mp.osd_message("Failed to load subtitle", 3)
        end
    end)
end)
mp.register_script_message("uosc-version", function()
    has_uosc = true
    publish_uosc_button()
end)
mp.observe_property("track-list", "native", function()
    publish_uosc_button()
end)

mp.msg.info("SubDL Arabic subtitle loader initialized (Ctrl+Shift+V=next, Ctrl+V=deep, Alt+V=manual, Ctrl+Alt+V=picker)")
mp.msg.info("Subtitle database: " .. SUBS_DIR)
