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
  -- Require a Japanese signal (TMDB lang=ja or a ja audio track): genre
  -- 16 is "Animation" and also matches Pixar/Disney/Arcane, which
  -- Anime4K's line-art tuning harms.
  japanese_only = "yes",
  debug = "no",
}
options.read_options(cfg, "anime_detect")

-- Key source order: conf, process env, then the gitignored ~~/.env
-- dotenv (mpv does NOT export .env into the process environment, so
-- os.getenv alone never sees it -- parse it like ar_subs does).
if cfg.tmdb_api_key == "" then
  cfg.tmdb_api_key = os.getenv("TMDB_API_KEY") or ""
end
if cfg.tmdb_api_key == "" then
  local f = io.open(mp.command_native({"expand-path", "~~/.env"}), "r")
  if f then
    for line in f:lines() do
      local val = line:match("^%s*TMDB_API_KEY%s*=%s*(.-)%s*$")
      if val then
        cfg.tmdb_api_key = val:gsub("^['\"]", ""):gsub("['\"]$", "")
        break
      end
    end
    f:close()
  end
end

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

-- Transport failures get one retry (then a visible warning); genuine
-- empty TMDB results ("no match") do not retry.
local retry_done = {}

-- session cache: normalized-title -> bool
local cache = {}
-- inflight: normalized-title -> boolean (prevent re-entrancy)
local inflight = {}

-- Scene-name noise (Lua patterns have no alternation, so: loops, and %f[]
-- frontiers so tokens only match as whole words).
local SCENE_COMPOUNDS = { -- codec/source glued to a release-group suffix
  "x264", "x265", "h264", "h265", "h%.264", "h%.265", "hevc", "av1",
  "bluray", "webdl", "web", "remux", "%d%d%d%d?p",
}
local SCENE_TOKENS = {
  "hdr", "sdr", "uhd", "webdl", "webrip", "web", "bluray", "blu%-ray",
  "bdrip", "bdremux", "remux", "x264", "x265", "h264", "h265", "hevc",
  "avc", "av1", "10bit", "8bit", "flac", "opus", "aac", "eac3", "ac3",
  "dts", "atmos", "truehd", "dual", "audio", "proper", "repack",
  "amzn", "nf", "hulu", "dsnp",
}

local function normalize(s)
  s = s:lower()
  s = s:gsub("^%[[^%]]*%]%s*", "")
  s = s:gsub("%[[^%]]*%]", " ")
  s = s:gsub("%b()", " ")
  -- scene-style codec/source-group compounds (h265-cakes, x264-ntb, 2160p-grp)
  for _, c in ipairs(SCENE_COMPOUNDS) do
    s = s:gsub(c .. "%-[a-z0-9]+", " ")
  end
  -- resolution (Lua patterns have no {n,m}: %d{3,4}p matched literally, so
  -- unbracketed 1080p/2160p used to leak into the TMDB query)
  s = s:gsub("%d%d%d%d?p", " ")
  -- common scene/release tokens
  for _, tok in ipairs(SCENE_TOKENS) do
    s = s:gsub("%f[%w]" .. tok .. "%f[%W]", " ")
  end
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

-- The file's own tracks: any Japanese audio track is the strongest anime
-- signal available -- offline, instant, and settles co-productions TMDB
-- tags en (Cyberpunk: Edgerunners ships ja audio as aid=1).
local function has_japanese_audio()
  for _, t in ipairs(mp.get_property_native("track-list", {})) do
    local lang = t.lang or ""
    if t.type == "audio" and (lang == "ja" or lang == "jpn" or lang:sub(1, 3) == "ja-") then
      return true
    end
  end
  return false
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
  log("query", (url:gsub("api_key=[^&]+", "api_key=***")))
  curl_json(url, function(j)
    inflight[norm] = nil
    if not j or not j.results or #j.results == 0 then
      if not j and not retry_done[norm] then
        -- Transport failure (curl/TMDB hiccup): one retry, made visible.
        retry_done[norm] = true
        mp.msg.warn("anime_detect: TMDB lookup failed, retrying once")
        mp.add_timeout(2, function() probe(raw_title) end)
        return
      end
      if not j then
        mp.msg.warn("anime_detect: TMDB unreachable; anime detection skipped for this file")
      end
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
    local function finalize(is_anime, lang)
      cache[norm] = is_anime
      mp.set_property("user-data/anime_detect/is_anime", is_anime and "1" or "0")
      log("result", norm, is_anime, lang or "?", best.name or best.title or "")
    end

    local genre_match = false
    for _, gid in ipairs(best.genre_ids) do
      if genres[gid] then genre_match = true break end
    end
    if not genre_match then
      finalize(false, best.original_language)
      return
    end
    -- Japanese gate: TMDB lang=ja OR a Japanese audio track in the file.
    -- The audio check catches co-productions TMDB tags en (Edgerunners)
    -- with no extra API call; western animation (Castlevania, Arcane)
    -- has neither and stays excluded. Live-action with ja audio never
    -- reaches here -- it fails the Animation genre gate.
    if cfg.japanese_only == "yes"
      and best.original_language ~= "ja"
      and not has_japanese_audio() then
      finalize(false, best.original_language)
      return
    end
    finalize(true, best.original_language)
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