local mp = require 'mp'
local utils = require 'mp.utils'

-- Configuration: API keys from environment variables with fallback
local CACHE_DIR = os.getenv("HOME") .. "/.cache/subdl_ar"
local CACHE_FILE = CACHE_DIR .. "/cache.json"
local SUBS_DIR = CACHE_DIR .. "/subtitles"
local SUBDL_API_KEY = os.getenv("SUBDL_API_KEY") or "***REMOVED***"
local SUBDL_API_BACKUP_KEY = os.getenv("SUBDL_API_KEY_BACKUP") or "***REMOVED***"
local TMDB_API_KEY = os.getenv("TMDB_API_KEY") or "***REMOVED***"
-- FIX 1: Remove trailing spaces from API URLs
local SUBDL_API_URL = "https://api.subdl.com/api/v1/subtitles"
local TMDB_API_URL = "https://api.themoviedb.org/3"
local CURL_TIMEOUT = 10
local MAX_RETRIES = 2
local DEEP_SEARCH = (os.getenv("SUBDL_DEEP_SEARCH") == "1")

-- Magic number constants
local MAX_SEASON = 30
local MAX_EPISODE = 2000
local MIN_MATCH_SCORE = 50
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

local tmdb_cache = {}
local tmdb_season_cache = {}
local subdl_sd_cache = {}  -- Cache sd_id lookups
local media_catalog = {
    loaded = false,
    exact_type = {},
    basename_types = {},
    stem_types = {},
}

local save_runtime_cache
local load_runtime_cache



-- OSD feedback helper


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

local function sleep_sec(s)
    if not s or s <= 0 then return end
    utils.subprocess({ args = {"sleep", tostring(s)}, cancellable = false })
end

local function http_get_json(url, opts)
    local backoff = 1
    local tries = (opts and opts.max_retries) or (MAX_RETRIES + 3)
    for _ = 1, tries do
        -- FIX 2: Log the URL being fetched for debugging
        mp.msg.debug("SubDL: fetching URL: " .. url)
        local res = run({ "curl", "-sL", "-w", "\n%{http_code}", url })
        if res.status ~= 0 or not res.stdout then
            mp.msg.warn("SubDL: curl failed with status " .. tostring(res.status))
            sleep_sec(backoff)
            backoff = math.min(backoff * 2, 10)
        else
            local body, code = res.stdout:match("^([%s%S]*)\n(%d%d%d)%s*$")
            local http_code = tonumber(code or 0)
            if http_code == 429 then
                mp.msg.warn("HTTP 429: backing off before retry")
                sleep_sec(backoff)
                backoff = math.min(backoff * 2, 10)
            elseif http_code >= 200 and http_code < 300 then
                local json = utils.parse_json(body or "")
                if json then return json, http_code end
                return nil, http_code
            else
                mp.msg.warn("SubDL: HTTP error " .. tostring(http_code) .. " for URL: " .. url)
                return nil, http_code
            end
        end
    end
    return nil, 0
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

local function basename(path)
    return path:match("([^/]+)%.[^/]*$")
end

local function url_safe(str)
    if not str then return "" end
    -- RFC 3986 unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
    return (tostring(str):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

-- Shared title cleanup helper
local function clean_title(title)
    if not title then return nil end
    -- Remove prefix numbering like "1.", "1a.", "01 - "
    title = title:gsub("^%s*%d+[a-zA-Z]?%.%s*", ""):gsub("^%s*%d+[a-zA-Z]?%s+%-%s+", "")
    title = title:gsub("[._]", " ")           -- Replace dots/underscores with spaces
    title = title:gsub("%s*%(%d%d%d%d%)%s*", " ")  -- Remove year in parentheses
    title = title:gsub("%s*%-+%s*$", "")      -- Remove trailing dashes
    title = title:gsub("%s+", " ")            -- Collapse multiple spaces
    title = title:match("^%s*(.-)%s*$")       -- Trim whitespace
    return title
end

local STEM_STOPWORDS = {
    ["1080p"]=true, ["720p"]=true, ["480p"]=true, ["2160p"]=true, ["4320p"]=true, ["4k"]=true,
    ["bluray"]=true, ["brrip"]=true, ["bdrip"]=true, ["web"]=true, ["webrip"]=true, ["webdl"]=true,
    ["hdr"]=true, ["dv"]=true, ["sdr"]=true, ["uhd"]=true, ["x264"]=true, ["x265"]=true, ["h264"]=true,
    ["h265"]=true, ["hevc"]=true, ["aac"]=true, ["ac3"]=true, ["dts"]=true, ["flac"]=true, ["truehd"]=true,
    ["atmos"]=true, ["remux"]=true, ["repack"]=true, ["proper"]=true, ["sample"]=true, ["subs"]=true
}

local MEDIA_CATALOG_FILES = {
    { type = "anime", file = "anime.txt" },
    { type = "movie", file = "movies.txt" },
    { type = "tv", file = "tv.txt" },
}

local function normalize_path_key(path)
    if not path then return nil end
    local p = tostring(path):gsub("\\", "/"):gsub("/+", "/"):match("^%s*(.-)%s*$")
    if not p or p == "" then return nil end
    return p:lower()
end

local function normalize_stem_key(name)
    if not name then return "" end
    local stem = tostring(name):gsub("%.[^.]+$", ""):lower()
    stem = stem:gsub("%b()", " "):gsub("%b[]", " "):gsub("%b{}", " ")
    stem = stem:gsub("[^%w]+", " ")

    local parts = {}
    for w in stem:gmatch("%w+") do
        local skip = STEM_STOPWORDS[w]
            or w:match("^%d+$")
            or w:match("^s%d+$")
            or w:match("^e%d+$")
            or w:match("^ep%d+$")
        if not skip and #w > 1 then
            table.insert(parts, w)
        end
    end
    return table.concat(parts, " ")
end

local function bump_type_count(tbl, content_type)
    tbl[content_type] = (tbl[content_type] or 0) + 1
end

local function best_type_from_counts(tbl)
    if not tbl then return nil end
    local order = {"anime", "tv", "movie"}
    local best_type, best_count, tie = nil, 0, false

    for _, t in ipairs(order) do
        local c = tbl[t] or 0
        if c > best_count then
            best_type = t
            best_count = c
            tie = false
        elseif c > 0 and c == best_count then
            tie = true
        end
    end

    if tie then return nil end
    return best_type
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
end

local function classify_content_type(path)
    if not path then return nil, nil end
    load_media_catalog()

    local key = normalize_path_key(path)
    if not key then return nil, nil end

    local exact = media_catalog.exact_type[key]
    if exact then return exact, "catalog-exact" end

    local name = key:match("([^/]+)$")
    if not name then return nil, nil end

    local by_name = best_type_from_counts(media_catalog.basename_types[name])
    if by_name then return by_name, "catalog-basename" end

    local stem_key = normalize_stem_key(name)
    if stem_key ~= "" then
        local by_stem = best_type_from_counts(media_catalog.stem_types[stem_key])
        if by_stem then return by_stem, "catalog-stem" end
    end

    return nil, nil
end

local function normalize_title_candidates(title)
    if not title then return {} end
    local candidates = {}
    local seen = {}

    local function add(t)
        if not t then return end
        t = clean_title(t)
        if t and t ~= "" and not seen[t:lower()] then
            seen[t:lower()] = true
            table.insert(candidates, t)
        end
    end

    add(title)
    add(title:gsub("%b()", " "):gsub("%b[]", " "):gsub("%s+", " "))

    if title:find(" %- ") then
        local parts = {}
        for part in title:gmatch("[^%-]+") do
            local p = part:gsub("^%s+", ""):gsub("%s+$", "")
            if p ~= "" then table.insert(parts, p) end
        end
        if #parts >= 2 then
            add(parts[1])
            add(parts[1] .. " " .. parts[2])
        end
    end

    if title:find(":") then
        add(title:match("^(.-):") or title)
    end

    local words = {}
    for w in title:gmatch("%w+") do table.insert(words, w) end
    if #words > 3 then
        add(table.concat(words, " ", 1, 3))
    end

    return candidates
end

local function merge_candidates(primary, extra)
    local out, seen = {}, {}
    for _, t in ipairs(primary or {}) do
        if t and t ~= "" and not seen[t:lower()] then
            seen[t:lower()] = true
            table.insert(out, t)
        end
    end
    for _, t in ipairs(extra or {}) do
        if t and t ~= "" and not seen[t:lower()] then
            seen[t:lower()] = true
            table.insert(out, t)
        end
    end
    return out
end

local function path_title_candidates(path)
    if not path then return {} end
    local parts = {}
    for part in path:gmatch("([^/]+)") do table.insert(parts, part) end
    if #parts == 0 then return {} end

    local candidates, seen = {}, {}
    local function add(t)
        if not t then return end
        t = clean_title(t)
        if t and t ~= "" and not seen[t:lower()] then
            seen[t:lower()] = true
            table.insert(candidates, t)
        end
    end

    -- Parent and grandparent folder names are often more reliable than filename
    local parent = parts[#parts - 1]
    local grand = parts[#parts - 2]

    local function scrub_folder(name)
        if not name then return nil end
        name = name:gsub("%b()", " "):gsub("%b[]", " ")
        name = name:gsub("[._]", " ")
        name = name:gsub("Season%s*%d+", " "):gsub("S%d%d", " ")
        name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
        return name
    end

    add(scrub_folder(parent))
    add(scrub_folder(grand))
    return candidates
end

local function limit_queries(queries, max)
    if not queries or not max or #queries <= max then return queries end
    local out = {}
    for i = 1, math.min(max, #queries) do out[i] = queries[i] end
    return out
end

local function dedupe_queries(queries)
    local out, seen = {}, {}
    for _, q in ipairs(queries or {}) do
        if q and q ~= "" and not seen[q] then
            seen[q] = true
            table.insert(out, q)
        end
    end
    return out
end

local function extract_series_info(filename)
    -- Strip [Group] tags if present
    local clean_filename = filename:gsub("^%[.-%]%s*", "")
    
    local show_title, season, episode
    
    -- Pattern 1: S##E## (most common)
    show_title, season, episode = clean_filename:match("^(.+)[._ ]S(%d+)E(%d+)")
    
    -- Pattern 2: NxN format (exclude resolutions)
    if not show_title then
        local potential_title, s, e = clean_filename:match("^(.+)[._ ](%d+)x(%d+)")
        if potential_title and s and e then
            local s_num, e_num = tonumber(s), tonumber(e)
            if s_num and e_num and s_num <= MAX_SEASON and 
               not (s_num == 1920 or s_num == 1280 or s_num == 3840 or s_num == 720 or s_num == 480) then
                show_title, season, episode = potential_title, s, e
            end
        end
    end
    
    -- Pattern 3: Season-only format (S## without E##) - season pack
    if not show_title then
        local potential_title, s = clean_filename:match("^(.+)[._ ]S(%d+)[._ )]")
        if potential_title and s then
            local s_num = tonumber(s)
            if s_num and s_num <= MAX_SEASON then
                show_title, season, episode = potential_title, s, nil
            end
        end
    end
    
    -- Pattern 4: Daily show format (Title YYYY MM DD)
    if not show_title then
        local potential_title, y, m, d = clean_filename:match("^(.+)[._ ](%d%d%d%d)[._ ](%d%d)[._ ](%d%d)")
        if potential_title and y and m and d then
            local year, month, day = tonumber(y), tonumber(m), tonumber(d)
            if year and year >= 1990 and year <= 2099 and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                show_title = potential_title
                -- For daily shows, episode is the full date as number (MMDD), season is year
                season, episode = year - 2000, month * 100 + day
            end
        end
    end
    
    if show_title then
        return clean_title(show_title), tonumber(season), episode and tonumber(episode) or nil
    end
    
    return nil, nil, nil
end

local function extract_anime_info(filename)
    -- Must start with [Group] tag OR look very much like an anime file (e.g. Title E01 without S01)
    local has_group = filename:match("^%[.-%]")
    local has_anime_pattern = filename:match(" E%d+") or filename:match(" %- %d+")
    
    if not has_group and not has_anime_pattern then return nil, nil, nil, nil end
    
    -- Remove group tag and normalize
    local s = filename:gsub("^%[.-%]%s*", ""):gsub("_", " ")
    
    -- If no group tag, but we have E01 pattern, treat as "Group-less" anime
    if not has_group then s = filename:gsub("_", " ") end
    local title, season, episode, year
    
    -- Helper to extract year from title and clean it
    local function clean(t)
        -- Remove prefix numbering like "1.", "1a.", "01 - "
        t = t:gsub("^%s*%d+[a-zA-Z]?%.%s*", ""):gsub("^%s*%d+[a-zA-Z]?%s+%-%s+", "")
        local y = t:match("%((%d%d%d%d)%)")
        return t:gsub("%s*%(%d%d%d%d%)%s*", " "):gsub("%s+$", ""):gsub(" S%d+$", ""), y
    end
    
    -- Pattern 1: "Title S2 - 10"
    title, season, episode = s:match("^(.+) S(%d+) %- (%d+)")
    if title then
        title, year = clean(title)
        return title, tonumber(season), tonumber(episode), year
    end
    
    -- Pattern 2: "Title - 10" or "Title S2 - 10v2"
    local t_temp, e_temp, rest = s:match("^(.+) %- (%d+)(.*)")
    if t_temp and e_temp then
        local ep = tonumber(e_temp)
        -- Avoid matching resolutions like 1080p as episode numbers
        local is_res = (ep == 480 or ep == 720 or ep == 1080 or ep == 2160) and rest and rest:lower():match("^p")
        
        if not is_res then
            local ts = t_temp:match(" S(%d+)$")
            title, year = clean(t_temp)
            return title, ts and tonumber(ts), ep, year
        end
    end
    
    -- Pattern 3: "Title 1153 (quality)" - episode before parenthesis
    title, episode = s:match("^(.+) (%d+) %([^)]+%)")
    if title and episode then
        local ep = tonumber(episode)
        if ep > 0 and ep < 2000 then
            title, year = clean(title)
            return title, nil, ep, year
        end
    end
    
    -- Pattern 4: Episode range "Title - 01~12"
    title, episode = s:match("^(.+) %- (%d+)~%d+")
    if title then
        title, year = clean(title)
        return title, nil, tonumber(episode), year
    end

    -- Pattern 5: "Title E01" (No Season)
    title, episode = s:match("^(.+) E(%d+)")
    if title then
        title, year = clean(title)
        return title, nil, tonumber(episode), year
    end

    -- Pattern 6: "Title S01E01" (Standard TV format inside Anime)
    title, season, episode = s:match("^(.+) S(%d+)E(%d+)")
    if title then
        title, year = clean(title)
        return title, tonumber(season), tonumber(episode), year
    end
    
    return nil, nil, nil, nil
end

local function extract_movie_info(filename)
    mp.msg.info("DEBUG: extract_movie_info input:", filename)
    local title, year
    
    -- Try multiple year patterns in order of preference
    local year_patterns = {
        "^(.+) (%d%d%d%d) ",      -- "Title 1989 "
        "^(.+)%.(%d%d%d%d)%.",    -- "Title.1989."
        "^(.+) %((%d%d%d%d)%)",   -- "Title (1989)"
        "^(.+)%.(%d%d%d%d) ",     -- "Title.1989 "
        "^(.+) (%d%d%d%d)%.",     -- "Title 1989."
        "^(.+)%s*%-%s*(%d%d%d%d)",-- "Title - 1989"
        "^(.+)%s*%[(%d%d%d%d)%]", -- "Title [1989]"
    }
    
    for _, pattern in ipairs(year_patterns) do
        title, year = filename:match(pattern)
        if title then 
            mp.msg.info("DEBUG: match pattern found:", title, year)
            break 
        end
    end
    
    -- Fallback: find any 4-digit year
    if not title then
        local raw = filename
        year = raw:match("(%d%d%d%d)")
        
        -- Validate year matches a reasonable range to avoid matching 1080p, 720p, etc.
        if year then
            local y_num = tonumber(year)
            local current_year = tonumber(os.date("%Y"))
            if y_num < 1880 or y_num > current_year + 5 then
                year = nil
            end
        end

        title = year and raw:match("^(.-)%s*" .. year) or raw
        if not title or title == "" then title = raw end
        mp.msg.info("DEBUG: fallback info:", title, year)
    end
    
    if title then
        mp.msg.info("DEBUG: title before cleaning:", title)
        -- Clean: replace dots/underscores, remove brackets, strip release terms
        -- Remove prefix numbering like "1.", "1a.", "01 - "
        title = title:gsub("^%s*%d+[a-zA-Z]?%.%s*", ""):gsub("^%s*%d+[a-zA-Z]?%s+%-%s+", "")
        mp.msg.info("DEBUG: title after prefix strip:", title)
        title = title:gsub("[._]", " "):gsub("%b()", " "):gsub("%b[]", " ")
        mp.msg.info("DEBUG: title after punct clean:", title)
        
        -- Remove common release terms (case-insensitive via pattern)
        local terms = "1080p|720p|480p|2160p|4k|bluray|brrip|bdrip|web%-dl|webdl|webrip|hdrip|dvdrip|"..
                     "x264|x265|h%.264|h%.265|hevc|ac3|aac|dts|flac|truehd|repack|proper|uhd|"..
                     "hdr|dv|sdr|amzn|nf|dsnp|hulu|hbo|max|rarbg|yify|yts|etrg|psa|ntb|"..
                     "deflate|sparks|flame|zq|it|byndr|mora|25r|wadu|dkore"
        title = title:gsub("%s+([%w%-%.]+)%s*", function(w)
            return w:lower():match("^("..terms..")$") and " " or " "..w.." "
        end)
        
        title = title:gsub("[%._]", " "):gsub("%s*%-+%s*$", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    end
    
    return title, year
end

local function resolve_media_info(path, video_name)
    local filename = basename(path or "") or video_name or ""
    local type_hint, hint_source = classify_content_type(path)
    local likely_anime = filename:match("^%[.-%]") and true or false

    local info = {
        filename = filename,
        content_type = "unknown",
        title = nil,
        season = nil,
        episode = nil,
        year = nil,
        is_anime = false,
        type_hint = type_hint,
        hint_source = hint_source,
    }

    local anime_done, anime_title, anime_season, anime_episode, anime_year = false, nil, nil, nil, nil
    local tv_done, tv_title, tv_season, tv_episode = false, nil, nil, nil
    local movie_done, movie_title, movie_year = false, nil, nil

    local function parse_anime()
        if not anime_done then
            anime_title, anime_season, anime_episode, anime_year = extract_anime_info(filename)
            anime_done = true
        end
        return anime_title, anime_season, anime_episode, anime_year
    end

    local function parse_tv()
        if not tv_done then
            tv_title, tv_season, tv_episode = extract_series_info(filename)
            tv_done = true
        end
        return tv_title, tv_season, tv_episode
    end

    local function parse_movie()
        if not movie_done then
            movie_title, movie_year = extract_movie_info(filename)
            movie_done = true
        end
        return movie_title, movie_year
    end

    local function set_anime()
        local t, s, e, y = parse_anime()
        if t and e then
            info.content_type = "anime"
            info.title = t
            info.season = s or 1
            info.episode = e
            info.year = y
            info.is_anime = true
            return true
        end
        return false
    end

    local function set_tv()
        local t, s, e = parse_tv()
        if t and s and e then
            info.content_type = "tv"
            info.title = t
            info.season = s
            info.episode = e
            info.is_anime = false
            return true
        end
        return false
    end

    local function set_movie()
        local t, y = parse_movie()
        if t and t ~= "" then
            info.content_type = "movie"
            info.title = t
            info.year = y
            info.is_anime = false
            return true
        end
        return false
    end

    local order
    if type_hint == "anime" then
        order = {"anime", "tv", "movie"}
    elseif type_hint == "tv" then
        order = {"tv", "anime", "movie"}
    elseif type_hint == "movie" then
        order = {"movie", "tv", "anime"}
    elseif likely_anime then
        order = {"anime", "tv", "movie"}
    else
        order = {"tv", "anime", "movie"}
    end

    for _, kind in ipairs(order) do
        if kind == "anime" and set_anime() then break end
        if kind == "tv" and set_tv() then break end
        if kind == "movie" and set_movie() then break end
    end

    if not info.title or info.title == "" then
        local extra = path_title_candidates(path)
        if #extra > 0 then
            info.title = extra[1]
            if info.content_type == "unknown" then
                info.content_type = type_hint or "movie"
            end
        end
    end

    if info.content_type == "unknown" and type_hint then
        info.content_type = type_hint
        if info.content_type == "anime" and not info.season then info.season = 1 end
    end

    return info
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
        save_runtime_cache()
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
                    save_runtime_cache()
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
    
    -- Check cache first
    if tmdb_season_cache[tmdb_id] then
        mp.msg.info("TMDB: using cached season info for ID", tmdb_id)
        return tmdb_season_cache[tmdb_id]
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
    
    -- Cache the result
    tmdb_season_cache[tmdb_id] = seasons
    return seasons
end

-- Calculate season/episode from absolute episode number using TMDB season data
local function calculate_cour_mappings(absolute_episode, tmdb_id, detected_season)
    local mappings = {}
    local seen = {}

    local function add_mapping(season_num, episode_num)
        season_num = tonumber(season_num)
        episode_num = tonumber(episode_num)
        if not season_num or not episode_num then return end
        if season_num < 1 or episode_num < 1 or episode_num > MAX_EPISODE then return end
        local key = season_num .. "_" .. episode_num
        if not seen[key] then
            seen[key] = true
            table.insert(mappings, {season = season_num, ep = episode_num})
        end
    end

    -- Always include absolute episode as S1.
    add_mapping(1, absolute_episode)

    -- If we have TMDB data, calculate canonical season mapping.
    local seasons = get_tmdb_season_info(tmdb_id)
    if seasons then
        local cumulative = 0
        for s = 1, 10 do
            local ep_count = seasons[s]
            if not ep_count or ep_count == 0 then break end

            if absolute_episode > cumulative and absolute_episode <= cumulative + ep_count then
                local relative_ep = absolute_episode - cumulative
                add_mapping(s, relative_ep)
                mp.msg.info(string.format("TMDB cour mapping: E%d → S%dE%d", absolute_episode, s, relative_ep))
                break
            end
            cumulative = cumulative + ep_count
        end
    end

    -- Add fallback cour guesses because SubDL seasoning often differs from TMDB.
    local boundaries = {12, 13, 23, 24, 25}
    local function add_fallback(s, ep)
        if ep > 0 and ep <= 26 and s >= 2 and s <= 5 then
            add_mapping(s, ep)
        end
    end

    for _, b in ipairs(boundaries) do
        if absolute_episode > b then add_fallback(2, absolute_episode - b) end
    end

    local s2_totals = {24, 25, 36, 37, 47, 48, 49, 50}
    for _, total in ipairs(s2_totals) do
        if absolute_episode > total then add_fallback(3, absolute_episode - total) end
    end

    if absolute_episode > 60 then
        local s3_totals = {60, 71, 72, 73}
        for _, total in ipairs(s3_totals) do
            if absolute_episode > total then add_fallback(4, absolute_episode - total) end
        end
    end

    if detected_season and detected_season > 1 then
        add_mapping(detected_season, absolute_episode)
    end

    mp.msg.info(string.format("Cour mappings: %d candidates for E%d", #mappings, absolute_episode))
    return mappings
end

local function build_valid_mapping_sets(cour_mappings)
    local valid_eps = {}
    local valid_pairs = {}
    local valid_seasons = {}

    for _, m in ipairs(cour_mappings or {}) do
        if m and m.season and m.ep then
            valid_eps[m.ep] = true
            valid_pairs[m.season] = valid_pairs[m.season] or {}
            valid_pairs[m.season][m.ep] = true
            valid_seasons[m.season] = true
        end
    end

    return valid_eps, valid_pairs, valid_seasons
end


local function get_quality_score(rn)
    local s = 2000
    if rn:find("remux") then s = s + 3000
    elseif rn:find("bluray") or rn:find("bd[ri]") then s = s + 2000
    elseif rn:find("web") then s = s + 1000 end
    
    if rn:find("2160p") or rn:find("4k") then s = s + 400
    elseif rn:find("1080p") then s = s + 300
    elseif rn:find("720p") then s = s + 200
    elseif rn:find("480p") then s = s + 100 end
    
    if rn:find("x265") or rn:find("hevc") then s = s + 20
    elseif rn:find("x264") then s = s + 10 end
    
    if rn:find("truehd") or rn:find("dts[hx]?d?") or rn:find("flac") then s = s + 15
    elseif rn:find("aac") or rn:find("ac3") or rn:find("dd[p+]?") then s = s + 5 end
    return s
end

local function add_episode_meta(ep_set, ep)
    ep = tonumber(ep)
    if not ep then return end
    if ep < 1 or ep > MAX_EPISODE then return end
    if ep == 480 or ep == 720 or ep == 1080 or ep == 2160 then return end
    ep_set[ep] = true
end

local function add_pair_meta(pair_set, season_set, se, ep)
    se = tonumber(se)
    ep = tonumber(ep)
    if not se or not ep then return end
    if se < 1 or se > MAX_SEASON or ep < 1 or ep > MAX_EPISODE then return end
    pair_set[se] = pair_set[se] or {}
    pair_set[se][ep] = true
    season_set[se] = true
end

local function normalize_subtitle_metadata(sub)
    if type(sub) ~= "table" then return end
    if sub._meta_parsed then return end
    sub._meta_parsed = true

    local pair_set, season_set, ep_set = {}, {}, {}
    local se = tonumber(sub.season_number)
    local ep = tonumber(sub.episode_number)
    if se and ep then
        add_pair_meta(pair_set, season_set, se, ep)
        add_episode_meta(ep_set, ep)
    elseif ep then
        add_episode_meta(ep_set, ep)
    end

    local rn = (sub.release_name or ""):lower()
    if rn ~= "" then
        for s, e in rn:gmatch("s(%d+)%s*[%._%- ]*e[p]?[%._%- ]*(%d+)") do
            add_pair_meta(pair_set, season_set, s, e)
        end
        for s, e in rn:gmatch("(%d+)[xX](%d+)") do
            add_pair_meta(pair_set, season_set, s, e)
        end
        for s, e in rn:gmatch("season%s*(%d+)[^%d]+e[p]?[%._%- ]*(%d+)") do
            add_pair_meta(pair_set, season_set, s, e)
        end
        for s, e in rn:gmatch("season%s*(%d+)%s*[%._%- ]*(%d+)%f[%D]") do
            add_pair_meta(pair_set, season_set, s, e)
        end
        for s, e in rn:gmatch("s(%d+)%s*[%._%- ]*(%d+)%f[%D]") do
            add_pair_meta(pair_set, season_set, s, e)
        end

        for e in rn:gmatch("episode%s*(%d+)") do add_episode_meta(ep_set, e) end
        for e in rn:gmatch("e[p]?[%._%- ]*(%d+)") do add_episode_meta(ep_set, e) end
        for e in rn:gmatch("%-%s*(%d+)%f[%D]") do add_episode_meta(ep_set, e) end
    end

    sub._norm_pairs = pair_set
    sub._norm_seasons = season_set
    sub._norm_eps = ep_set
end

local function normalize_subtitles_metadata(subs)
    for _, sub in ipairs(subs or {}) do
        normalize_subtitle_metadata(sub)
    end
end

local function fetch_subdl_api(query_string)
    local function do_fetch(query)
        local json = http_get_json(query)
        if json and json.subtitles then
            normalize_subtitles_metadata(json.subtitles)
            return json.subtitles, json.results, json
        end
        return {}, json and json.results or nil, json
    end

    local subs, results, json = do_fetch(query_string)
    -- FIX 3: Correct typo SUBDL_API_BACK_KEY -> SUBDL_API_BACKUP_KEY
    if json and json.status == false and SUBDL_API_BACKUP_KEY and SUBDL_API_BACKUP_KEY ~= SUBDL_API_KEY then
        local err = tostring(json.error or ""):lower()
        local key_related = err:find("api") or err:find("limit") or err:find("request")
        if key_related then
            local backup_query = query_string:gsub("api_key=" .. SUBDL_API_KEY, "api_key=" .. SUBDL_API_BACKUP_KEY, 1)
            if backup_query ~= query_string then
                mp.msg.warn("SubDL: primary API key failed, retrying with backup key")
                local b_subs, b_results, b_json = do_fetch(backup_query)
                if b_json and b_json.subtitles then
                    return b_subs, b_results
                end
            end
        end
    end

    return subs, results
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
    
    -- Query SubDL to find the correct sd_id
    local query = string.format("%s?api_key=%s&tmdb_id=%s&languages=ar",
                               SUBDL_API_URL, SUBDL_API_KEY, tmdb_id)
    local _, results = fetch_subdl_api(query)
    
    if results then
        for _, result in ipairs(results) do
            if result.type == media_type and result.sd_id then
                subdl_sd_cache[cache_key] = result.sd_id
                save_runtime_cache()
                mp.msg.info(string.format("SubDL: resolved %s sd_id=%d for tmdb_id=%s (%s)", 
                           media_type, result.sd_id, tmdb_id, result.name or title))
                return result.sd_id
            end
        end
    end
    
    mp.msg.warn(string.format("SubDL: could not find %s sd_id for tmdb_id=%s", media_type, tmdb_id))
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

local function sanitize_filename(name)
    local ext = name:match("%.([^.]+)$") or ""
    local base = name:gsub("%.[^.]+$", "")
    base = base:gsub("[%[%]%(%)'\"`]", ""):gsub("%s+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", ""):gsub("_%-_", "-"):gsub("%-+", "-")
    return base .. "." .. ext
end

local function matches_title_words(filename, title)
    if not title then return true end
    local name_lower = filename:lower()
    local name_tokens = {}
    for token in name_lower:gmatch("%w+") do
        name_tokens[token] = true
    end
    local stop = {
        ["the"]=true, ["and"]=true, ["or"]=true, ["a"]=true, ["an"]=true,
        ["of"]=true, ["in"]=true, ["on"]=true, ["to"]=true, ["for"]=true,
        ["with"]=true, ["by"]=true, ["from"]=true, ["part"]=true
    }
    local match_count = 0
    local long_match = false
    local significant_count = 0

    for word in title:lower():gmatch("%w+") do
        if #word > 2 and not stop[word] then
            significant_count = significant_count + 1
            if name_tokens[word] then
                match_count = match_count + 1
                if #word >= 5 then long_match = true end
            end
        end
    end

    if significant_count == 0 then return true end

    -- Single-word titles (e.g. "Cure") should only need one match.
    if significant_count == 1 then
        return match_count >= 1
    end

    -- Multi-word titles: require at least two significant matches, or one long word.
    return long_match or match_count >= 2
end

local function fetch_sub_list_tv(show_title, season, episode, tmdb_id)
    local queries = {}
    local candidates = normalize_title_candidates(show_title)
    if tmdb_id then
        local sd_id = get_subdl_sd_id("tv", tmdb_id, show_title)
        if sd_id then table.insert(queries, string.format("type=tv&sd_id=%s&season_number=%d&episode_number=%d", sd_id, season, episode)) end
        table.insert(queries, string.format("tmdb_id=%s&season_number=%d&episode_number=%d", tmdb_id, season, episode))
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
    
    for i, q in ipairs(queries) do queries[i] = string.format("%s?api_key=%s&languages=ar&subs_per_page=50&%s", SUBDL_API_URL, SUBDL_API_KEY, q) end

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
    local function add(q) table.insert(queries, string.format("%s?api_key=%s&languages=ar&subs_per_page=50&%s", SUBDL_API_URL, SUBDL_API_KEY, q)) end
    
    if tmdb_id then add("tmdb_id=" .. tmdb_id) end
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

local function fetch_sub_list_anime(title, season, episode, tmdb_id)
    local cour_mappings = calculate_cour_mappings(episode, tmdb_id, season)
    local valid_eps, valid_pairs, valid_seasons = build_valid_mapping_sets(cour_mappings)

    local queries = {}
    local sd_id = tmdb_id and get_subdl_sd_id("tv", tmdb_id, title)
    local candidates = normalize_title_candidates(title)
    local function add(q) table.insert(queries, string.format("%s?api_key=%s&languages=ar&subs_per_page=50&%s", SUBDL_API_URL, SUBDL_API_KEY, q)) end

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
                add(string.format("tmdb_id=%s&season_number=%d&episode_number=%d", tmdb_id, m.season, m.ep))
            end
        end
        add(string.format("tmdb_id=%s", tmdb_id))
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

        subs_list = fetch_sub_list_anime(media.title, media.season or 1, media.episode, tmdb_id)
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

local function find_matching_episode_file(sub_files, season, episode, valid_episodes, valid_pairs)
    -- If no episode info at all, just return first file
    if not episode then
        return sub_files[1]
    end

    season = season and tonumber(season) or nil
    episode = tonumber(episode)
    
    -- Default valid_episodes to just the target episode
    if not valid_episodes then
        valid_episodes = { [episode] = true }
    end

    local target_season_count = 0
    if valid_pairs then
        for _ in pairs(valid_pairs) do target_season_count = target_season_count + 1 end
    end
    local has_multi_target_seasons = target_season_count > 1

    local best_match = nil
    local best_score = -1

    for _, sub_file in ipairs(sub_files) do
        local filename = sub_file:match("([^/]+)$")
        local filename_lower = filename:lower()

        local score = 0
        local ep_candidates = {}
        local se_candidates = {}

        for full, se_str, ep_str in filename_lower:gmatch("(s(%d+))[^a-zA-Z0-9]?e(%d+)") do
            local se = tonumber(se_str)
            local ep = tonumber(ep_str)
            if se and se > 0 and se <= MAX_SEASON then table.insert(se_candidates, se) end
            if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
        end

        for full, se_str, ep_str in filename_lower:gmatch("(%d+)[xX](%d+)") do
            local se = tonumber(se_str)
            local ep = tonumber(ep_str)
            if se and se > 0 and se <= MAX_SEASON then table.insert(se_candidates, se) end
            if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
        end

        for ep_str in filename_lower:gmatch("[eE][pP][._ %-]*(%d+)") do
            local ep = tonumber(ep_str)
            if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
        end

        for num_str in filename_lower:gmatch("(%d+)") do
            local num = tonumber(num_str)
            if num and num > 0 and num <= MAX_EPISODE then
                if not (filename_lower:find("[a-zA-Z]" .. num_str) or 
                        filename_lower:find(num_str .. "[a-zA-Z]")) then
                    if num ~= 1080 and num ~= 720 and num ~= 480 and num ~= 2160 and num ~= 4 and num ~= 5 and num ~= 6 then
                        table.insert(ep_candidates, num)
                    end
                end
            end
        end

        local ep_set = {}
        for _, e in ipairs(ep_candidates) do ep_set[e] = true end
        ep_candidates = {}
        for e in pairs(ep_set) do table.insert(ep_candidates, e) end

        local se_set = {}
        for _, s in ipairs(se_candidates) do se_set[s] = true end
        se_candidates = {}
        for s in pairs(se_set) do table.insert(se_candidates, s) end

        local has_valid_pair = false
        if valid_pairs then
            for _, s in ipairs(se_candidates) do
                if valid_pairs[s] then
                    for _, e in ipairs(ep_candidates) do
                        if valid_pairs[s][e] then
                            has_valid_pair = true
                            break
                        end
                    end
                end
                if has_valid_pair then break end
            end
        end

        if has_valid_pair then
            score = score + 180
        end

        for _, e in ipairs(ep_candidates) do
            if valid_episodes[e] then
                -- Any valid episode (including cour-mapped ones) is a strong match
                score = score + 100
            elseif e == episode then
                score = score + 100
            elseif math.abs(e - episode) == 1 then
                score = score + 10
            elseif math.abs(e - episode) <= 2 then
                score = score + 1
            end
        end

        for _, s in ipairs(se_candidates) do
            if valid_pairs and valid_pairs[s] then
                score = score + 35
            elseif s == season then
                score = score + 50
            elseif has_multi_target_seasons then
                score = score - 20
            end
        end

        -- STRICT episode matching: require EXACT episode number match
        local has_exact_episode = has_valid_pair
        if has_valid_pair then
            score = score + 120
        else
            for _, e in ipairs(ep_candidates) do
                if valid_episodes[e] or e == episode then
                    local ep_padded = string.format("%02d", e)
                    local ep_str = tostring(e)
                    local exact_patterns = {
                        "e" .. ep_padded .. "[^%d]",
                        "e" .. ep_padded .. "$",
                        "[^%dSsPp]" .. ep_padded .. "[^%d]",
                        "^" .. ep_padded .. "[^%d]",
                        "- " .. ep_padded .. "[^%d]",
                        "- " .. ep_padded .. "$",
                        "ep" .. ep_padded,
                        "episode " .. ep_str .. "[^%d]",
                    }
                    for _, pattern in ipairs(exact_patterns) do
                        if filename_lower:find(pattern) then
                            has_exact_episode = true
                            score = score + 100
                            break
                        end
                    end
                    if has_exact_episode then break end
                end
            end
        end

        -- If no exact episode match found, severely penalize
        if not has_exact_episode and #ep_candidates > 0 then
            score = score - 50
        end

        local is_pack = filename_lower:find("batch") or filename_lower:find("complete") or filename_lower:find("season") or filename_lower:find("pack")
        local has_range = filename_lower:find("%d+%s*[%-%~]%s*%d+")
        if is_pack then
            score = score - (has_exact_episode and 15 or 60)
        end
        if has_range and not has_exact_episode then
            score = score - 30
        end

        -- If cour mapping includes multiple seasons, avoid hard S01 preference.
        local season_from_file = filename_lower:match("s(%d+)")
        if season_from_file then
            local s = tonumber(season_from_file)
            if has_multi_target_seasons and valid_pairs then
                if valid_pairs[s] then
                    score = score + 10
                else
                    score = score - 25
                end
            elseif s == 1 then
                score = score + 20
            elseif s == (season or 1) then
                score = score + 20
            else
                score = score - 20
            end
        end

        if #ep_candidates > 1 then score = score - 10 end
        if #se_candidates > 1 then score = score - 5 end

        mp.msg.debug(string.format("SubDL: file='%s' → eps=%d candidates, seas=%d candidates → score=%d", 
            filename, #ep_candidates, #se_candidates, score))

        if score > best_score then
            best_score = score
            best_match = sub_file
        end
    end

    if best_match and best_score >= MIN_MATCH_SCORE then
        local chosen_name = best_match:match("([^/]+)$")
        mp.msg.info(string.format("SubDL: ✅ Selected for E%02d (score=%d): %s", 
            episode, best_score, chosen_name))
        return best_match
    elseif best_match and best_score > 0 then
        -- Low confidence match - skip this pack and try next subtitle
        mp.msg.warn(string.format("SubDL: ⚠️ No good match for E%02d in this pack (best score=%d), trying next...", episode, best_score))
        return nil
    else
        mp.msg.warn(string.format("SubDL: ⚠️ No match for E%02d in this pack, trying next...", episode))
        return nil
    end
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

local function download_and_load(sub, video_name, season, episode, valid_episodes, valid_pairs)
    -- FIX 6: Remove trailing space from download URL
    local url = "https://dl.subdl.com" .. (sub.url or sub.download_url)
    downloaded_subs[video_name] = downloaded_subs[video_name] or {}
    if downloaded_subs[video_name][url] then 
        mp.osd_message("Subtitle loaded", 2)
        mp.commandv("sub-add", downloaded_subs[video_name][url])
        return downloaded_subs[video_name][url]
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
    local zip = tmp .. "/download.zip"
    if run({"curl", "-sL", "-o", zip, "-H", "User-Agent: mpv", "-H", "Accept: application/zip", url}).status ~= 0 then safe_rm_rf(tmp); return nil end
    -- Try unzip; if it fails, treat as direct subtitle file
    local unzip_res = safe_unzip(zip, tmp)
    if unzip_res.status == 0 then
        os.remove(zip)
    else
        local direct = tmp .. "/" .. sanitize_filename(title) .. ".srt"
        os.rename(zip, direct)
    end

    local sub_file = process_download_content(tmp, title, content_type, season, episode, valid_episodes, valid_pairs, video_name, url)
    safe_rm_rf(tmp)
    if sub_file then mp.commandv("sub-add", sub_file); mp.msg.info("SubDL: loaded subtitle", sub_file) end
    return sub_file
end

local function fetch_bulk_subs(subs_batch, video_name, season, episode, valid_episodes, valid_pairs)
    local path = mp.get_property("path")
    local media = resolve_media_info(path, video_name)
    local content_type = media.content_type
    if content_type ~= "anime" and content_type ~= "tv" and content_type ~= "movie" then
        content_type = media.episode and "tv" or "movie"
    end
    local title = media.title or video_name or "unknown"
    
    local tmp_base = "/tmp/subdl_batch_" .. os.time()
    safe_mkdir(tmp_base)

    mp.msg.info(string.format("SubDL: downloading %d subtitles sequentially...", #subs_batch))

    for i, sub in ipairs(subs_batch) do
        -- FIX 7: Remove trailing space from download URL
        local url = "https://dl.subdl.com" .. (sub.url or sub.download_url)
        local zip = string.format("%s/%d.zip", tmp_base, i)
        local extract_dir = string.format("%s/%d", tmp_base, i)
        safe_mkdir(extract_dir)

        local res = run({ "curl", "-sL", "-o", zip, "-H", "User-Agent: mpv", "-H", "Accept: application/zip", url })
        if res.status == 0 and utils.file_info(zip) then
            local unzip_res = safe_unzip(zip, extract_dir)
            if unzip_res.status == 0 then
                os.remove(zip)
            else
                local direct = extract_dir .. "/" .. sanitize_filename(title) .. ".srt"
                os.rename(zip, direct)
            end

            local loaded = process_download_content(extract_dir, title, content_type, season, episode, valid_episodes, valid_pairs, video_name, url)
            if loaded then
                safe_rm_rf(tmp_base)
                mp.commandv("sub-add", loaded)
                mp.msg.info("SubDL: loaded subtitle", loaded)
                return loaded
            end
        end
    end

    safe_rm_rf(tmp_base)
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
    if not subs_list then mp.osd_message("No Arabic subtitles found", 3); return end

    current_index[video_name] = current_index[video_name] or 0
    local attempts = 0

    while attempts < 5 do
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

        mp.osd_message(string.format("Downloading batch %d-%d/%d...", start_idx, end_idx, #subs_list), 2)
        local loaded = fetch_bulk_subs(batch, video_name, season, episode, valid_episodes, valid_pairs)
        if loaded then
            mp.osd_message("Subtitle loaded", 2)
            return
        end

        attempts = attempts + 1
        mp.osd_message("Batch failed, trying next...", 1)
    end
    mp.osd_message("Failed to load subtitles after several batches", 3)
end

local function has_arabic_sub()
    for _, track in ipairs(mp.get_property_native("track-list") or {}) do
        if track.type == "sub" and (track.lang or ""):match("^ar") then return true end
    end
end

local function toggle_deep_search()
    DEEP_SEARCH = not DEEP_SEARCH
    mp.osd_message("SubDL deep search: " .. (DEEP_SEARCH and "ON" or "OFF"), 2)
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
        mp.osd_message("Searching for Arabic subtitles...", 2)
        fetch_next_sub()
    end
end

-- Convert table with numeric keys to string keys for JSON compatibility
local function stringify_keys(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
        local key = tostring(k)
        result[key] = stringify_keys(v)
    end
    return result
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
        tmdb_seasons = stringify_keys(tmdb_season_cache),
        season_files = stringify_keys(season_files_map),
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

-- Load cache from disk
load_runtime_cache = function()
    local f = io.open(CACHE_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local cache_data = utils.parse_json(content)
        if cache_data then
            tmdb_cache = cache_data.tmdb or cache_data.tmdb_cache or {}
            subdl_sd_cache = cache_data.subdl_sd_cache or {}
            tmdb_season_cache = cache_data.tmdb_seasons or {}
            
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

-- Handle manual search query
local function handle_manual_search(query)
    if not is_enabled() then return end
    if not query or query == "" then
        mp.osd_message("No search query provided", 2)
        return
    end
    
    mp.osd_message("Searching: " .. query, 2)
    
    local api_url = string.format("%s?api_key=%s&query=%s&languages=ar&subs_per_page=50",
                             SUBDL_API_URL, SUBDL_API_KEY, url_safe(query))
    
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

    local loaded = download_and_load(sub, video_name, dl_season, dl_episode, valid_episodes, valid_pairs)
    if loaded then
        mp.osd_message("Loaded: " .. loaded:match("([^/]+)$"), 3)
    else
        mp.osd_message("Failed to load subtitle", 3)
    end
end

-- Load cache on startup
load_runtime_cache()
-- Scan all local subtitles (handles files not in JSON cache)
index_local_files()
-- Load media path catalogs if present (anime.txt, movies.txt, tv.txt)
load_media_catalog()

mp.register_event("file-loaded", enhanced_auto_fetch_if_needed)
mp.register_event("shutdown", save_runtime_cache)  -- Just save cache, don't delete any files
mp.add_key_binding("Ctrl+Shift+V", "subdl_ar_next", fetch_next_sub)
mp.add_key_binding("Ctrl+V", "subdl_ar_toggle_deep", toggle_deep_search)
mp.add_key_binding("Alt+V", "subdl_ar_search", manual_search)
mp.register_script_message("subdl_ar_search", handle_manual_search)

mp.msg.info("SubDL Arabic subtitle loader initialized (Ctrl+Shift+V=next, Ctrl+V=deep, Alt+V=manual search)")
mp.msg.info("Subtitle database: " .. SUBS_DIR)
