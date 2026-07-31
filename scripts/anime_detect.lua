-- anime_detect.lua: TMDB-based anime detection for mpv auto-profiles.
-- On file load, extracts title from filename (or uses force-media-title),
-- queries TMDB /search/multi -> /tv/{id} or /movie/{id} for genres, and
-- sets user-data/anime_detect/is_anime = "1" | "0". Profile-cond reads it
-- to auto-apply Anime4K shaders. Caches results in a Lua table for the
-- session; persistent cache written to ~~/script-opts is omitted on
-- purpose to keep the script dependency-free.
--
-- Config (script-opts/anime_detect.conf):
--   tmdb_api_key=...          (required)
--   genre_ids=16               (comma list of TMDB genre ids to treat as anime)
--   min_score=0.0              (skip fuzzy matches below vote_average)
--   skip_protocols=http,https,rtmp,rtsp  (don't probe streams)
--   debug=no

local mp = require 'mp'
local utils = require 'mp.utils'
local options = require 'mp.options'

local cfg = {
  tmdb_api_key = "",
  genre_ids = "16",
  min_score = 0.0,
  skip_protocols = "http,https,rtmp,rtsp",
  debug = "no",
}
options.read_options(cfg, "anime_detect")

-- genres table { [16] = true, ... }
local genres = {}
cfg.genre_ids:gsub("([^,]+)", function(s) s = tonumber(s:match("%S+")); if s then genres[s] = true end end)

local skip = {}
cfg.skip_protocols:gsub("([^,]+)", function(s) skip[s:match("%S+")] = true end)

local dbg = cfg.debug == "yes"
local function log(...)
  if not dbg then return end
  local args = {...}
  for i, v in ipairs(args) do
    if type(v) == "boolean" then args[i] = v and "true" or "false"
    elseif type(v) == "nil" then args[i] = "<nil>"
    elseif type(v) ~= "string" and type(v) ~= "number" then args[i] = tostring(v) end
  end
  mp.msg.info("[anime_detect] " .. table.concat(args, " "))
end

-- session cache: normalized-title -> bool
local cache = {}
-- inflight: normalized-title -> boolean (prevent re-entrancy)
local inflight = {}

local function normalize(s)
  s = s:lower()
  s = s:gsub("^%[[^%]]*%]%s*", "")
  s = s:gsub("%[[^%]]*%]", " ")
  s = s:gsub("%b()", " ")
  s = s:gsub("%d{3,4}p", " ")
  -- strip episode markers: S01E12, S01xE12, E12, etc.
  s = s:gsub("[%s%-_]*s?%d?%d[xXeE]%d+[%s%-_]*", " ")
  -- strip version suffix like "v2" on episodes: "S01E03v2" tail or standalone "v2"
  s = s:gsub("[%s%-_]*v%d+%s*", " ")
  -- standalone trailing episode number: " 01" or " - 01"
  s = s:gsub("[%s%-_]+%d+%s*$", " ")
  -- stray trailing dash
  s = s:gsub("%s*%-%s*$", " ")
  s = s:gsub("[%._]+", " ")
  s = s:gsub("%s+", " ")
  return s:match("^%s*(.-)%s*$") or ""
end

local function basename(p)
  return (p:gsub("\\", "/"):match("^.+/([^/]+)%..*$") or p:gsub("\\", "/"):match("^.+/([^/]+)$") or p)
end

local function title_from_path(path)
  local f = basename(path)
  f = f:gsub("%[[^%]]*%]", "")        -- strip [tags]
  f = f:gsub("%b()", "")              -- strip (tags)
  f = f:gsub("[%._]+", " ")
  f = f:gsub("%s+", " ")
  return (f:match("^%s*(.-)%s*$") or f)
end

local function curl_json(url, cb)
  local args = {"curl", "-fsSL", "-A", "mpv-anime_detect", "--max-time", "8", url}
  mp.command_native_async({
    name = "subprocess",
    args = args,
    capture_stdout = true,
    capture_stderr = false,
  }, function(success, result)
    if not success or not result or result.status ~= 0 then
      log("curl fail", url, tostring(result and result.status))
      return cb(nil)
    end
    local out = result.stdout
    local parsed = utils.parse_json(out)
    if not parsed then
      log("bad json", out:sub(1,200))
      return cb(nil)
    end
    cb(parsed)
  end)
end

local function probe(raw_title)
  local norm = normalize(raw_title)
  if norm == "" then norm = normalize(title_from_path(mp.get_property("path", ""))) end
  if norm == "" then return end

  if cache[norm] ~= nil then
    mp.set_property("user-data/anime_detect/is_anime", cache[norm] and "1" or "0")
    log("cache hit", norm, cache[norm])
    return
  end
  if inflight[norm] then return end
  inflight[norm] = true

  local q = norm:gsub("%s+", "+")
  local url = string.format("https://api.themoviedb.org/3/search/multi?api_key=%s&query=%s",
    cfg.tmdb_api_key, q)
  log("query", url)
  curl_json(url, function(j)
    inflight[norm] = nil
    if not j or not j.results or #j.results == 0 then
      cache[norm] = false
      mp.set_property("user-data/anime_detect/is_anime", "0")
      return
    end
    -- pick first tv/movie match with vote >= min_score (search returns genre_ids inline).
    local best, best_score
    for _, r in ipairs(j.results) do
      if (r.media_type == "tv" or r.media_type == "movie")
        and r.genre_ids and type(r.genre_ids) == "table"
        and (r.vote_average or 0) >= cfg.min_score
      then
        if not best or (r.media_type == "tv" and best.media_type == "movie") then
          best = r
        end
      end
    end
    if not best then
      cache[norm] = false
      mp.set_property("user-data/anime_detect/is_anime", "0")
      return
    end
    local is_anime = false
    for _, gid in ipairs(best.genre_ids) do
      if genres[gid] then is_anime = true break end
    end
    cache[norm] = is_anime
    mp.set_property("user-data/anime_detect/is_anime", is_anime and "1" or "0")
    log("result", norm, is_anime, best.name or best.title or "")
  end)
end

-- Use property observer instead of on_load hook: `path` only changes when the
-- current playback file actually switches, never when autoload or other
-- scripts populate playlist entries. This naturally avoids the race of
-- concurrent probes for unrelated playlist items and matches profile-cond
-- re-evaluation timing.
local VIDEO_EXTS = {
  mkv=true, mp4=true, avi=true, mov=true, webm=true, wmv=true,
  flv=true, m4v=true, mpg=true, mpeg=true, ts=true, m2ts=true,
  vob=true, ogv=true, ["3gp"]=true, ["3g2"]=true,
  mp3=false, flac=false, ape=false, wav=false, m4a=false, opus=false, ogg=false,
}
local function is_video(path)
  local ext = path:match("%.([%w]+)$"); ext = ext and ext:lower()
  return ext and VIDEO_EXTS[ext] == true
end

local function on_loaded()
  local path = mp.get_property("path", "") or ""
  log("file-loaded path=", path)
  mp.set_property("user-data/anime_detect/is_anime", "0")
  mp.set_property("user-data/anime_detect/title", "")
  if cfg.tmdb_api_key == "" then log("no tmdb key"); return end
  if path == "" then return end
  local proto = mp.get_property("protocol", "") or ""
  if skip[proto] then log("skip proto", proto); return end
  if not is_video(path) then log("skip non-video", path); return end

  local ftitle = mp.get_property("force-media-title", nil)
  local title = (ftitle and ftitle ~= "") and ftitle or title_from_path(path)
  if title == "" then return end
  mp.set_property("user-data/anime_detect/title", title)
  probe(title)
end

mp.register_event("file-loaded", on_loaded)
mp.register_event("end-file", function()
  mp.set_property("user-data/anime_detect/is_anime", "0")
  mp.set_property("user-data/anime_detect/title", "")
end)

log("loaded")