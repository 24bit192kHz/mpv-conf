-- subdl_ar.util.media: pure(ish) filename/title parsing for subtitle matching.
--
-- All functions here are side-effect-free except for debug logging via mp.msg
-- (extract_movie_info) and os.date (extract_movie_info year validation). The
-- media catalog used by classify_content_type is injected via set_catalog so
-- the I/O-bound loader stays in the orchestrator.

local mp = require "mp"
local url_util = require "subdl_ar.util.url"

local M = {}

local MAX_SEASON = 30

local STEM_STOPWORDS = {
  ["1080p"]=true, ["720p"]=true, ["480p"]=true, ["2160p"]=true, ["4320p"]=true, ["4k"]=true,
  ["bluray"]=true, ["brrip"]=true, ["bdrip"]=true, ["web"]=true, ["webrip"]=true, ["webdl"]=true,
  ["hdr"]=true, ["dv"]=true, ["sdr"]=true, ["uhd"]=true, ["x264"]=true, ["x265"]=true, ["h264"]=true,
  ["h265"]=true, ["hevc"]=true, ["aac"]=true, ["ac3"]=true, ["dts"]=true, ["flac"]=true, ["truehd"]=true,
  ["atmos"]=true, ["remux"]=true, ["repack"]=true, ["proper"]=true, ["sample"]=true, ["subs"]=true,
}

-- Catalog state, injected by the orchestrator after load_media_catalog runs.
-- Defaults to empty tables so classify_content_type returns nil when no catalog
-- is loaded (matching the behaviour when the catalog files are absent).
local catalog = {
  exact_type = {},
  basename_types = {},
  stem_types = {},
}

function M.set_catalog(exact, basename_types, stem_types)
  catalog.exact_type = exact or {}
  catalog.basename_types = basename_types or {}
  catalog.stem_types = stem_types or {}
end

function M._reset_catalog()
  catalog.exact_type = {}
  catalog.basename_types = {}
  catalog.stem_types = {}
end

function M.clean_title(title)
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

function M.normalize_path_key(path)
  if not path then return nil end
  local p = tostring(path):gsub("\\", "/"):gsub("/+", "/"):match("^%s*(.-)%s*$")
  if not p or p == "" then return nil end
  return p:lower()
end

function M.normalize_stem_key(name)
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

function M.classify_content_type(path)
  if not path then return nil, nil end

  local key = M.normalize_path_key(path)
  if not key then return nil, nil end

  local exact = catalog.exact_type[key]
  if exact then return exact, "catalog-exact" end

  local name = key:match("([^/]+)$")
  if not name then return nil, nil end

  local by_name = best_type_from_counts(catalog.basename_types[name])
  if by_name then return by_name, "catalog-basename" end

  local stem_key = M.normalize_stem_key(name)
  if stem_key ~= "" then
    local by_stem = best_type_from_counts(catalog.stem_types[stem_key])
    if by_stem then return by_stem, "catalog-stem" end
  end

  return nil, nil
end

function M.normalize_title_candidates(title)
  if not title then return {} end
  local candidates = {}
  local seen = {}

  local function add(t)
    if not t then return end
    t = M.clean_title(t)
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

function M.merge_candidates(primary, extra)
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

function M.path_title_candidates(path)
  if not path then return {} end
  local parts = {}
  for part in path:gmatch("([^/]+)") do table.insert(parts, part) end
  if #parts == 0 then return {} end

  local candidates, seen = {}, {}
  local function add(t)
    if not t then return end
    t = M.clean_title(t)
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

function M.limit_queries(queries, max)
  if not queries or not max or #queries <= max then return queries end
  local out = {}
  for i = 1, math.min(max, #queries) do out[i] = queries[i] end
  return out
end

function M.dedupe_queries(queries)
  local out, seen = {}, {}
  for _, q in ipairs(queries or {}) do
    if q and q ~= "" and not seen[q] then
      seen[q] = true
      table.insert(out, q)
    end
  end
  return out
end

function M.extract_series_info(filename)
  -- Strip [Group] tags if present
  local clean_filename = filename:gsub("^%[.-%]%s*", "")

  local show_title, season, episode

  -- Pattern 1: S##E## (most common)
  show_title, season, episode = clean_filename:match("^(.+)[._ ]%s?[sS](%d+)[eE](%d+)")

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
    local potential_title, s = clean_filename:match("^(.+)[._ ]%s?[sS](%d+)[._ )]")
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
    return M.clean_title(show_title), tonumber(season), episode and tonumber(episode) or nil
  end

  return nil, nil, nil
end

function M.extract_anime_info(filename)
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

function M.extract_movie_info(filename)
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

function M.resolve_media_info(path, video_name)
  local filename = url_util.basename(path or "") or video_name or ""
  local type_hint, hint_source = M.classify_content_type(path)
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
      anime_title, anime_season, anime_episode, anime_year = M.extract_anime_info(filename)
      anime_done = true
    end
    return anime_title, anime_season, anime_episode, anime_year
  end

  local function parse_tv()
    if not tv_done then
      tv_title, tv_season, tv_episode = M.extract_series_info(filename)
      tv_done = true
    end
    return tv_title, tv_season, tv_episode
  end

  local function parse_movie()
    if not movie_done then
      movie_title, movie_year = M.extract_movie_info(filename)
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
    local extra = M.path_title_candidates(path)
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

return M
