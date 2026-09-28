-- anime_detect.lua: TMDB-based anime detection for mpv auto-profiles.
-- On file load, extracts title from filename (or uses force-media-title),
-- queries TMDB /search/multi -> /tv/{id} or /movie/{id} for genres, and
-- sets user-data/anime_detect/is_anime = "1" | "0". Profile-cond reads it
-- to auto-apply Anime4K shaders. Caches results in a Lua table for the
-- session, and remembers each show folder's verdict in
-- ~~cache/anime_detect/dirs.json so the next launch sets the flag before
-- the first frame instead of switching shaders mid-playback.
--
-- Config (script-opts/anime_detect.conf):
--   tmdb_api_key=...          (required)
--   genre_ids=16               (comma list of TMDB genre ids to treat as anime)
--   min_score=0.0              (skip fuzzy matches below vote_average)
--   skip_protocols=http,https,rtmp,rtsp  (don't probe streams)
--   group_aliases=One Pace=One Piece      ([group] tag -> series to query)
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
  -- Leading [release group] tags that name a series the filename never
  -- does: "Tag=Series" pairs, comma separated. One Pace files are
  -- "[One Pace][1079] Egghead 13", which TMDB cannot place.
  group_aliases = "One Pace=One Piece",
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

local group_aliases = {}
cfg.group_aliases:gsub("([^,]+)", function(pair)
  local tag, series = pair:match("^%s*(.-)%s*=%s*(.-)%s*$")
  if tag and tag ~= "" and series and series ~= "" then group_aliases[tag:lower()] = series end
end)

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

-- session cache: normalized-title -> bool (only verified TMDB verdicts;
-- transport failures are never cached so a later file can recover)
local cache = {}

-- Persistent folder verdicts: parent-dir -> { a = #anime, n = #not, t = epoch }.
-- Episode titles normalize per episode ("... zenpen 01"), and mpv is
-- usually launched once per file, so the session cache rarely hits; the
-- folder is the stable key. Only a provisional hint, and only for folders
-- whose verdicts all agree (a loose-files folder mixing anime and live
-- action gets none): the TMDB probe still runs and has the final word.
local DIRS_PATH = mp.command_native({"expand-path", "~~cache/anime_detect/dirs.json"})
local DIRS_MAX = 2000
local dirs = {}
local current_dir = nil

local function load_dirs()
  local f = io.open(DIRS_PATH, "r")
  if not f then return end
  local parsed = utils.parse_json(f:read("*a") or "")
  f:close()
  if type(parsed) == "table" then dirs = parsed end
end

local function ensure_dir(dir)
  if utils.file_info(dir) then return true end
  local args = package.config:sub(1, 1) == "\\"
    and {"cmd", "/c", "mkdir", dir} or {"mkdir", "-p", dir}
  mp.command_native({name = "subprocess", args = args, playback_only = false,
    capture_stdout = true, capture_stderr = true})
  return utils.file_info(dir) ~= nil
end

local function dir_hint(dir)
  local e = dir and dirs[dir]
  if type(e) ~= "table" then return nil end
  local a, n = tonumber(e.a) or 0, tonumber(e.n) or 0
  if a > 0 and n == 0 then return true end
  if n > 0 and a == 0 then return false end
  return nil
end

local function remember_dir(verdict)
  if not current_dir then return end
  local e = type(dirs[current_dir]) == "table" and dirs[current_dir] or { a = 0, n = 0 }
  -- Counts only need to answer "consistent or mixed": stop writing once a
  -- side is established, so replays of a known folder cost no disk I/O.
  local side = verdict and "a" or "n"
  if (tonumber(e[side]) or 0) >= 1 and dirs[current_dir] then return end
  e[side] = (tonumber(e[side]) or 0) + 1
  e.t = os.time()
  dirs[current_dir] = e
  local n, oldest, oldest_t = 0, nil, math.huge
  for k, entry in pairs(dirs) do
    n = n + 1
    if (entry.t or 0) < oldest_t then oldest, oldest_t = k, entry.t or 0 end
  end
  if n > DIRS_MAX and oldest then dirs[oldest] = nil end
  if not ensure_dir((utils.split_path(DIRS_PATH))) then return end
  local tmp = DIRS_PATH .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(utils.format_json(dirs) or "{}")
  f:close()
  os.remove(DIRS_PATH)
  os.rename(tmp, DIRS_PATH)
end

load_dirs()
-- inflight: normalized-title -> boolean (prevent re-entrancy)
local inflight = {}
-- waiters: normalized-title -> { raw_title=..., gen=..., ja_audio=... }
-- A second probe() for a norm that already has a request in flight stores
-- the latest waiter here instead of dropping it; the stale first callback
-- re-probes the waiter so file2 does not stick at is_anime=0.
local waiters = {}
-- Bumped on every file-loaded/end-file so late TMDB callbacks cannot write
-- is_anime (or read the new file's audio tracks) onto a different video.
local probe_gen = 0

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
  -- distributor/source tags (CR=Crunchyroll) and sub/dub markers
  "cr", "dl", "multi", "msubs", "dub", "sub",
}

local function normalize(s)
  s = s:lower()
  s = s:gsub("^%[[^%]]*%]%s*", "")
  s = s:gsub("%[[^%]]*%]", " ")
  s = s:gsub("%b()", " ")
  for _, c in ipairs(SCENE_COMPOUNDS) do
    s = s:gsub(c .. "%-[a-z0-9]+", " ")
  end
  -- Per-token scene noise (amzn/eac3/nf/cr/...): whole-word only via %f[]
  -- frontiers so "web" never matches inside "webdl". Lua patterns have no
  -- alternation or {n,m}, hence the per-token loop.
  for _, t in ipairs(SCENE_TOKENS) do
    s = s:gsub("%f[%w]" .. t .. "%f[%W]", " ")
  end
  -- resolution (Lua patterns have no {n,m}: %d{3,4}p matched literally, so
  -- unbracketed 1080p/2160p used to leak into the TMDB query)
  s = s:gsub("%d%d%d%d?p", " ")
  -- bare codec numbers ("H.264" -> "h 264"): whole-word 3-digit runs
  s = s:gsub("%f[%w]%d%d%d%f[%W]", " ")
  -- strip episode markers: S01E12, S01xE12, E12, etc.
  s = s:gsub("[%s%-_]*s?%d?%d[xXeE]%d+[%s%-_]*", " ")
  -- strip version suffix like "v2" on episodes: "S01E03v2" tail or standalone "v2"
  s = s:gsub("[%s%-_]*v%d+%s*", " ")
  -- NOTE: no standalone-trailing-number strip here on purpose. A
  -- "[%s%-_]+%d+%s*$" strip collides sequels ("Attack on Titan 2" shares
  -- a cache key with "Attack on Titan"), which is worse than leaving an
  -- episode number in the TMDB query. Episode markers are already cut
  -- above (S01E12 / xE / trailing S01); series_cut() handles the rest.
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

-- Leading [group] tag mapped through group_aliases, else nil.
local function aliased_title(path)
  local tag = basename(path):match("^%[([^%]]+)%]")
  return tag and group_aliases[tag:lower()] or nil
end

-- Show folder of a file: parent dir, or grandparent when the parent is a
-- season/extras subfolder. Used when the filename finds nothing on TMDB
-- ("Made in Abyss Movie - 02 - Hourou Suru Tasogare" -> "Made in Abyss").
local function folder_title(path)
  local dir = (utils.split_path(path or "")):gsub("[/\\]+$", "")
  for _ = 1, 2 do
    local name = dir:match("([^/\\]+)$")
    if not name then return nil end
    local low = name:lower()
    if not (low:match("^season") or low:match("^s%d+$") or low:match("^specials?$")
        or low:match("^extras?$") or low:match("^%d+[a-z]?%.")) then
      local t = title_from_path("/" .. name .. ".x")
      return t ~= "" and t or nil
    end
    dir = dir:match("^(.*)[/\\][^/\\]+$") or ""
  end
  return nil
end

local function curl_json(url, cb)
  -- The URL carries api_key=, and mpv logs every subprocess argv at -v
  -- (so --log-file captures it). Hand the URL to curl as a config on stdin.
  local args = {"curl", "-fsSL", "-A", "mpv-anime_detect", "--max-time", "8", "--config", "-"}
  mp.command_native_async({
    name = "subprocess",
    stdin_data = 'url = "' .. url:gsub('[\\"]', '\\%0') .. '"\n',
    -- A 2KB JSON probe must survive EOF/teardown: the default
    -- playback_only=true gets killed on fast/headless exits and the
    -- generation guard already drops stale callbacks.
    playback_only = false,
    args = args,
    capture_stdout = true,
    capture_stderr = false,
  }, function(success, result)
    if not success or not result or result.status ~= 0 then
      log("curl fail", (url:gsub("api_key=[^&]+", "api_key=***")), tostring(result and result.status))
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

-- Series name left of an episode marker: scene names bury the series
-- ("Solo.Leveling.S02E02.I.Suppose...", "Lain E07 Society ..."); the
-- episode title + release junk right of the marker makes TMDB return
-- zero results. Returns nil when there is no marker to cut at.
local function series_cut(s)
  local left = s:match("^(.-)[%s%.%-_]+[sS]%d%d?%d?[xXeE]%d+")
    or s:match("^(.-)[%s%.%-_]+%d+[xX]%d+")
    or s:match("^(.-)[%s%.%-_]+[eE]%d+")
    or s:match("^(.-)[%s%.%-_]+[sS]%d%d?%d?%s*$")
    -- fansub convention: "Dandadan - 17", "Made in Abyss Movie - 02 - Title"
    or s:match("^(.-)%s+%-%s+%d%d?%d?%d?v?%d?%f[%D]")
  if left then
    left = left:match("^%s*(.-)%s*$")
    if left and #left >= 3 then return left end
  end
  return nil
end

local function probe(raw_title, gen, ja_audio)
  local norm = normalize(raw_title)
  if norm == "" then norm = normalize(title_from_path(mp.get_property("path", ""))) end
  if norm == "" then return end

  if cache[norm] ~= nil then
    mp.set_property("user-data/anime_detect/is_anime", cache[norm] and "1" or "0")
    log("cache hit", norm, cache[norm])
    return
  end
  if inflight[norm] then
    -- Same-norm race: a second file normalizing identically while the
    -- first request is in flight must not be dropped -- the first
    -- callback goes stale (gen guard) without caching, which would
    -- leave this file stuck at is_anime=0. Remember the latest waiter;
    -- the stale callback re-probes it below.
    waiters[norm] = { raw_title = raw_title, gen = gen, ja_audio = ja_audio }
    log("waiter queued", norm)
    return
  end
  inflight[norm] = true

  local q = (norm:gsub("([^%w%-_%.~ ])", function(c)
    return string.format("%%%02X", c:byte())
  end):gsub(" ", "+"))
  local url = string.format("https://api.themoviedb.org/3/search/multi?api_key=%s&query=%s",
    cfg.tmdb_api_key, q)
  log("query", (url:gsub("api_key=[^&]+", "api_key=***")))
  curl_json(url, function(j)
    inflight[norm] = nil
    if gen ~= probe_gen then
      log("stale probe dropped", norm)
      -- Same-norm race recovery: a waiter queued while this request was
      -- in flight still needs its own probe for its own file.
      local w = waiters[norm]
      if w then
        waiters[norm] = nil
        -- Only the current file's waiter still matters; an end-file bump
        -- since queueing means the waiter is obsolete -- drop it instead
        -- of spending a TMDB request on a dead file.
        if w.gen == probe_gen then
          log("stale probe; re-probing waiter", norm)
          probe(w.raw_title, w.gen, w.ja_audio)
        else
          log("stale probe; waiter obsolete", norm)
        end
      end
      return
    end
    -- A stale waiter that has since moved on (end-file bumped probe_gen)
    -- must not fire: drop it now that this request owns the current gen.
    waiters[norm] = nil
    if not j or not j.results or #j.results == 0 then
      if not j and not retry_done[norm] then
        -- Transport failure (curl/TMDB hiccup): one retry, made visible.
        retry_done[norm] = true
        mp.msg.warn("anime_detect: TMDB lookup failed, retrying once")
        mp.add_timeout(2, function()
          if gen == probe_gen then probe(raw_title, gen, ja_audio) end
        end)
        return
      end
      if j and j.results and #j.results == 0 then
        -- Genuine empty result with a cuttable series name: the episode
        -- title + release junk right of the marker sank the query.
        -- Retry once on the series cut (own cache key, own inflight).
        local cut = series_cut(raw_title)
        if cut then
          local cnorm = normalize(cut)
          if cnorm ~= "" and cnorm ~= norm
            and cache[cnorm] == nil and not inflight[cnorm] then
            log("no match; retrying series cut", cnorm)
            probe(cut, gen, ja_audio)
            return
          end
        end
        local folder = folder_title(mp.get_property("path", ""))
        local fnorm = folder and normalize(folder) or ""
        if fnorm ~= "" and fnorm ~= norm and cache[fnorm] == nil and not inflight[fnorm] then
          log("no match; retrying show folder", fnorm)
          probe(folder, gen, ja_audio)
          return
        end
      end
      if not j then
        -- Transport failure after retry: never cache. Caching false here
        -- would poison the session (cache-hit paths return cached false
        -- forever, even after TMDB recovers). Leave is_anime=0 for this
        -- file only; the next probe retries fresh.
        retry_done[norm] = nil
        mp.msg.warn("anime_detect: TMDB unreachable; anime detection skipped for this file")
        mp.set_property("user-data/anime_detect/is_anime", "0")
        return
      end
      cache[norm] = false
      remember_dir(false)
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
      remember_dir(false)
      mp.set_property("user-data/anime_detect/is_anime", "0")
      return
    end
    local function has_genre(r)
      for _, gid in ipairs(r.genre_ids or {}) do
        if genres[gid] then return true end
      end
      return false
    end
    -- The first hit can be a namesake ("Egghead Republic" for an "Egghead"
    -- arc-only query): prefer a genre-matching candidate anywhere in the
    -- list, ideally Japanese, before settling on the first tv/movie.
    if not has_genre(best) then
      for _, r in ipairs(j.results) do
        if (r.media_type == "tv" or r.media_type == "movie")
          and type(r.genre_ids) == "table"
          and (r.vote_average or 0) >= cfg.min_score
          and has_genre(r)
          and (r.original_language == "ja" or ja_audio) then
          best = r
          break
        end
      end
    end
    local function finalize(is_anime, lang)
      cache[norm] = is_anime
      remember_dir(is_anime)
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
      and not ja_audio then
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
  probe_gen = probe_gen + 1
  local gen = probe_gen
  mp.set_property("user-data/anime_detect/title", "")
  if cfg.tmdb_api_key == "" then
    mp.set_property("user-data/anime_detect/is_anime", "0")
    log("no tmdb key"); return
  end
  if path == "" then
    mp.set_property("user-data/anime_detect/is_anime", "0")
    return
  end
  local proto = mp.get_property("protocol", "") or ""
  if skip[proto] then
    mp.set_property("user-data/anime_detect/is_anime", "0")
    log("skip proto", proto); return
  end
  if not is_video(path) then
    mp.set_property("user-data/anime_detect/is_anime", "0")
    log("skip non-video", path); return
  end

  local ftitle = mp.get_property("force-media-title", nil)
  local title = (ftitle and ftitle ~= "") and ftitle or aliased_title(path) or title_from_path(path)
  if title == "" then
    mp.set_property("user-data/anime_detect/is_anime", "0")
    return
  end
  mp.set_property("user-data/anime_detect/title", title)
  -- Apply a known verdict before clearing, so [Anime] does not flash
  -- off/on: session cache for the same title, else the folder's last
  -- verdict (set here, on file-loaded, the shaders are in place before
  -- the VO renders its first frame).
  local norm = normalize(title)
  current_dir = (utils.split_path(path))
  local known = cache[norm]
  if known == nil then known = dir_hint(current_dir) end
  mp.set_property("user-data/anime_detect/is_anime", known and "1" or "0")
  probe(title, gen, has_japanese_audio())
end

mp.register_event("file-loaded", on_loaded)
mp.register_event("end-file", function()
  probe_gen = probe_gen + 1
  current_dir = nil
  mp.set_property("user-data/anime_detect/is_anime", "0")
  mp.set_property("user-data/anime_detect/title", "")
end)

log("loaded")