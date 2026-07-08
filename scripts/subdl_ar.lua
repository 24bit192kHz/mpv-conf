local mp = require 'mp'
local options = require 'mp.options'
local utils = require 'mp.utils'

-- Bootstrap package.path so `require 'subdl_ar.*'` resolves into
-- script-modules/subdl_ar/. init.lua also runs an idempotent ensure_path()
-- for any other script that wants to consume these modules.
do
    local _modules_dir = mp.command_native({"expand-path", "~~/script-modules"})
    package.path = _modules_dir .. "/?.lua;" .. _modules_dir .. "/?/init.lua;" .. package.path
end
require 'subdl_ar.init'

local url_util = require 'subdl_ar.util.url'
local media_util = require 'subdl_ar.util.media'
local match_util = require 'subdl_ar.util.match'
local activation_util = require 'subdl_ar.util.activation'
local config_loader = require 'subdl_ar.config'
local subdl_provider = require 'subdl_ar.providers.subdl'
local tvdb_provider = require 'subdl_ar.providers.tvdb'
local cache_mod = require 'subdl_ar.cache'
local http_mod = require 'subdl_ar.http'
local uosc_picker = require 'subdl_ar.ui.uosc_picker'

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

local _cfg = config_loader.load(mp, options)
local dotenv = _cfg.dotenv
local env_config = _cfg.env
local config = _cfg.opts

local CACHE_DIR = os.getenv("HOME") .. "/.cache/subdl_ar"
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
local BATCH_SIZE = 5
local GLOBAL_MODE = false
local RESTRICTED_PATH = "/mnt/my-zfs"
local SCRIPT_DIR = mp.get_script_directory() or "."

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
        if not success or not result.body then
            if on_done then on_done(nil, 0) end
            return
        end
        local json = utils.parse_json(result.body)
        if json then
            if on_done then on_done(json, result.http_code or 0) end
        else
            if on_done then on_done(nil, 0) end
        end
    end)
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
        args = {"find", dir, "-type", "f", "(", "-name", "*.srt", "-o", "-name", "*.ass", "-o", "-name", "*.ssa", "-o", "-name", "*.vtt", ")"},
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
        
        for _, sub in ipairs(subs) do
            local sub_id = sub.id or sub.sd_id or tostring(sub)
            if sub_id and not seen_ids[sub_id] then
                if not callbacks.filter or callbacks.filter(sub) then
                    table.insert(all_subs, sub)
                    seen_ids[sub_id] = true
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
    table.insert(queries, "query=" .. url_safe(show_title .. " " .. es))
    if DEEP_SEARCH then
        for i = 1, math.min(2, #candidates) do
            local c = candidates[i]
            if c ~= show_title then
                table.insert(queries, "film_name=" .. url_safe(c .. " " .. es))
                table.insert(queries, "query=" .. url_safe(c .. " " .. es))
            end
        end
    end
    if not DEEP_SEARCH then queries = limit_queries(queries, 3) end
    
    for i, q in ipairs(queries) do queries[i] = string.format("languages=ar&subs_per_page=50&%s", q) end

    local subs = execute_search_strategies(queries, {
        type = "TV search",
        filter = function(sub) 
            return (not sub.season_number or sub.season_number == season) and (not sub.episode_number or sub.episode_number == episode) 
        end,
        should_stop = function(i, count) return count >= 5 end
    })
    
    if subs then
        table.sort(subs, function(a, b) return get_quality_score((a.release_name or ""):lower()) > get_quality_score((b.release_name or ""):lower()) end)
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
    add("query=" .. url_safe(title))
    if DEEP_SEARCH then
        for i = 1, math.min(3, #candidates) do
            local c = candidates[i]
            if c ~= title then
                add("film_name=" .. url_safe(c))
                if year then add("film_name=" .. url_safe(c .. " " .. year)) end
                add("query=" .. url_safe(c))
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
    add("query=" .. url_safe(title))
    if DEEP_SEARCH then
        for i = 1, math.min(3, #candidates) do
            local c = candidates[i]
            if c ~= title then
                add("film_name=" .. url_safe(c))
                add("query=" .. url_safe(c))
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

    local subs = execute_search_strategies(queries, {
        type = "anime search",
        filter = subtitle_matches_cour,
        should_stop = function(i, count)
            return not DEEP_SEARCH and i >= 9 and count >= ANIME_EARLY_STOP_COUNT
        end
    })

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
        sanitize_filename(title), (content_type == "tv" or content_type == "anime") and string.format("/S%02d", season or 1) or "")
    safe_mkdir(show_dir)

    if content_type == "tv" or content_type == "anime" then season_files_map[title] = season_files_map[title] or {} end

    for _, f in ipairs(files) do
        local base = f:match("([^/]+)$")
        if matches_title_words(base, title) then
            local dest = show_dir .. "/" .. sanitize_filename(base)
            if utils.file_info(f) and not utils.file_info(dest) then
                if not os.rename(f, dest) then safe_copy(f, dest); os.remove(f) end
                mp.msg.info("SubDL: saved → " .. dest:gsub(SUBS_DIR .. "/", ""))
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
        mp.commandv("sub-add", downloaded_subs[video_name][cache_key])
        if on_done then on_done(downloaded_subs[video_name][cache_key]) end
        return downloaded_subs[video_name][cache_key]
    end

    local function handle_download(body, code, dl_url)
        if not body or body == "" or not dl_url then
            mp.msg.warn("subdl_ar: empty download body for url=" .. tostring(dl_url)
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
        local out = tmp .. "/" .. sanitize_filename(title) .. ".srt"
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

    subdl_provider.download_async(sub, function(body, code, dl_url)
        handle_download(body, code, dl_url)
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
            mp.msg.warn("subdl_ar: invalid sub, skipping batch item " .. i)
            mp.add_timeout(0, function() process_item(i + 1) end)
            return
        end

        subdl_provider.download_async(sub, function(body, code, dl_url)
            if body and body ~= "" and dl_url then
                local extract_dir = string.format("%s/%d", tmp_base, i)
                safe_mkdir(extract_dir)
                local out = extract_dir .. "/" .. sanitize_filename(title) .. ".srt"
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
                mp.msg.warn("subdl_ar: empty download body for batch item " .. i
                            .. " http_code=" .. tostring(code))
            end
            mp.add_timeout(0, function() process_item(i + 1) end)
        end)
    end

    process_item(1)
    return nil
end

local function fetch_next_sub()
    if not is_enabled() then return end
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
        if attempt > 5 then
            mp.osd_message("Failed to load subtitles after several batches", 3)
            return
        end

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
        current_index[video_name] = end_idx

        osd_show(string.format("Downloading batch %d-%d/%d...", start_idx, end_idx, #subs_list))
        fetch_bulk_subs(batch, video_name, season, episode, valid_episodes, valid_pairs, function(loaded)
            osd_remove()
            if loaded then
                mp.osd_message("Subtitle loaded", 2)
                return
            end
            mp.osd_message("Batch failed, trying next...", 1)
            mp.add_timeout(0.1, function() try_batch(attempt + 1) end)
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

local function publish_uosc_button()
    local ar_count = count_arabic_subs()
    local tooltip = "Arabic Subs"
    if DEEP_SEARCH then tooltip = tooltip .. " (Deep: ON)" end
    local data = {
        icon = "subtitles",
        active = DEEP_SEARCH,
        badge = ar_count > 0 and tostring(ar_count) or nil,
        tooltip = tooltip,
        command = "script-binding subdl_ar/subdl_ar_search",
    }
    mp.commandv("script-message-to", "uosc", "set-button", "subdl_ar", utils.format_json(data))
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
    
    local search_dir = string.format("%s/%s/%s/S%02d", SUBS_DIR, type_dir, show_title:gsub("[^%w%s%-]", ""):gsub("%s+", "_"), season or 1)
    if not utils.file_info(search_dir) then return nil end
    
    local files = safe_find_subs(search_dir)
    if #files == 0 then return nil end
    
    local ep_pad, ep_str = string.format("%02d", episode), tostring(episode)
    local best_match, best_score = nil, 0
    
    for _, file in ipairs(files) do
        local fname = file:match("([^/]+)$"):lower()
        local score = 0
        if fname:find("e" .. ep_pad) then score = 10
        elseif fname:find("- " .. ep_str) then score = 5 
        elseif fname:find(ep_pad) then score = 1 end
        
        if score > best_score then best_score, best_match = score, file end
    end
    
    if best_match then
        season_files_map[show_title] = season_files_map[show_title] or {}
        season_files_map[show_title][season or 1] = season_files_map[show_title][season or 1] or {}
        season_files_map[show_title][season or 1][episode] = best_match
    end
    return best_match
end

local function check_existing_season_files(show_title, season, episode)
    if show_title and season and episode and season_files_map[show_title] and season_files_map[show_title][season] then
        local target_file = season_files_map[show_title][season][episode]
        if target_file and utils.file_info(target_file) then
            mp.msg.info(string.format("SubDL: Found cached %s S%02dE%02d: %s", show_title, season, episode, target_file))
            mp.commandv("sub-add", target_file)
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
            mp.commandv("sub-add", target_file)
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

local function enhanced_auto_fetch_if_needed()
    if not is_enabled() then return end
    local path = mp.get_property("path")
    if not path then return end
    
    local video_name = basename(path)
    local media = resolve_media_info(path, video_name)
    
    -- First, check if this exact file already has a cached subtitle
    if check_existing_subtitle_for_file(media.filename) then
        mp.osd_message("Loaded cached subtitle", 2)
        return
    end
    
    if media.content_type == "anime" and media.title and media.episode then
        local season = media.season or 1
        if check_existing_season_files(media.title, season, media.episode) then mp.osd_message("Loaded cached subtitle", 2); return end
        local local_file = scan_local_files_for_episode(media.title, season, media.episode, "anime")
        if local_file then mp.commandv("sub-add", local_file); mp.osd_message("Loaded local subtitle", 2); return end
    elseif media.content_type == "tv" and media.title and media.season and media.episode then
        if check_existing_season_files(media.title, media.season, media.episode) then mp.osd_message("Loaded cached subtitle", 2); return end
        local local_file = scan_local_files_for_episode(media.title, media.season, media.episode, "tv")
        if local_file then mp.commandv("sub-add", local_file); mp.osd_message("Loaded local subtitle", 2); return end
    end
    
    if not has_arabic_sub() then
        osd_show("Searching for Arabic subtitles...")
        fetch_next_sub()
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
                        local show_normalized = show:gsub("_", " ")
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
        mp.commandv("script-message-to", "console", "type", "script-message subdl_ar_search ")
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

local function subdl_ar_pick()
    if not is_enabled() then return end
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
    if not query or query == "" then
        mp.osd_message("No search query provided", 2)
        return
    end
    
    mp.osd_message("Searching: " .. query, 2)
    
    local api_url = string.format("query=%s&languages=ar&subs_per_page=50",
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
mp.add_key_binding("Ctrl+Shift+V", "subdl_ar_next", fetch_next_sub)
mp.add_key_binding("Ctrl+V", "subdl_ar_toggle_deep", toggle_deep_search)
mp.add_key_binding("Alt+V", "subdl_ar_search", manual_search)
mp.add_key_binding("Ctrl+Alt+v", "subdl_ar_pick", subdl_ar_pick)
mp.add_key_binding("ctrl+alt+v", "subdl_ar_pick_lower", subdl_ar_pick)
mp.register_script_message("subdl_ar_search", handle_manual_search)
mp.register_script_message("subdl_ar_download_item", function(index)
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
