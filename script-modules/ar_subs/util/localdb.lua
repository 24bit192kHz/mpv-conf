-- ar_subs.util.localdb: read-only access to the offline Subscene Arabic
-- subtitle index (arabic_subs.db, built by build_subscene_db.py).
--
-- mpv's LuaJIT has no sqlite binding, so queries go through the sqlite3 CLI
-- over a read-only immutable URI (NFS-safe, no locking). The DB is an
-- accelerator: if the binary or the file is missing, available() is false and
-- every lookup returns nil -- the caller falls through to the SubDL API.

local M = {}

M._mp = nil
M._db = nil
M._subs_root = nil
M._ok = false

-- Season number -> slug word: dumps name season dirs "first-season" etc.
local ORDINALS = {
  "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth",
  "ninth", "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth",
  "fifteenth", "sixteenth", "seventeenth", "eighteenth", "nineteenth", "twentieth",
}

local function log(level, ...)
  if M._mp and M._mp.msg then M._mp.msg[level](...) end
end

-- init(opts): { mp, db_path, subs_root }
function M.init(opts)
  opts = opts or {}
  M._mp = opts.mp
  M._db = opts.db_path
  M._subs_root = opts.subs_root
  if not M._db or not M._subs_root then return false end
  local f = io.open(M._db, "rb")
  if not f then
    log("info", "localdb: no DB at " .. M._db .. " (offline source disabled)")
    return false
  end
  f:close()
  M._ok = true
  return true
end

function M.available()
  return M._ok == true
end

local function sql_quote(s)
  return "'" .. tostring(s):gsub("'", "''") .. "'"
end

-- slugify("Deadman Wonderland") -> "deadman-wonderland"
local function slugify(title)
  return tostring(title or ""):lower():gsub("[^a-z0-9]+", "-"):gsub("^-+", ""):gsub("-+$", "")
end

-- Candidate show slugs for a title/season: exact, "<base>-<ordinal>-season",
-- "<base>-complete-series". The DB keys coverage by the dump's directory slug.
function M.slug_candidates(title, season)
  local base = slugify(title)
  local out = {}
  local seen = {}
  local function add(s)
    if s ~= "" and not seen[s] then seen[s] = true; table.insert(out, s) end
  end
  add(base)
  if season and ORDINALS[season] then add(base .. "-" .. ORDINALS[season] .. "-season") end
  add(base .. "-complete-series")
  add(base .. "-the-complete-series")
  return out, base
end

-- Run one query, return rows as arrays of fields ('|'-separated -list output).
local function query(sql)
  local uri = "file:" .. M._db .. "?mode=ro&immutable=1"
  local r = M._mp.command_native({
    name = "subprocess",
    args = { "sqlite3", "-noheader", "-list", uri, sql },
    capture_stdout = true,
    playback_only = false,
  })
  if not r or r.status ~= 0 or not r.stdout then return {} end
  local rows = {}
  for line in r.stdout:gmatch("[^\n]+") do
    local fields = {}
    for field in (line .. "|"):gmatch("(.-)|") do table.insert(fields, field) end
    table.insert(rows, fields)
  end
  return rows
end

local function num(x)
  local n = tonumber(x)
  return n
end

-- find_episode_subs(title, season, episode) -> list of candidate tables,
-- best first (conf desc, non-HI first, newest first).
function M.find_episode_subs(title, season, episode)
  if not M._ok or not title or not episode then return nil end
  season = season or 1
  local cands, base = M.slug_candidates(title, season)
  local slug_clause = {}
  for _, s in ipairs(cands) do table.insert(slug_clause, "c.show_slug = " .. sql_quote(s)) end
  -- season-suffixed slugs ("deadman-wonderland-first-season") are covered by
  -- the ordinal candidate; also sweep any "<base>-%season" variant.
  table.insert(slug_clause, "c.show_slug LIKE " .. sql_quote(base .. "-%"))
  local sql = "SELECT c.subtitle_id, s.archive_relpath, s.archive_kind, s.title, c.conf, "
    .. "s.hearing_impaired, s.author FROM episode_coverage c "
    .. "JOIN subtitles s ON s.id = c.subtitle_id "
    .. "WHERE (" .. table.concat(slug_clause, " OR ") .. ") "
    .. "AND c.season = " .. tonumber(season) .. " AND c.episode = " .. tonumber(episode) .. " "
    .. "AND s.listed != 0 "
    .. "ORDER BY c.conf DESC, s.hearing_impaired ASC, s.date_unix DESC LIMIT 25;"
  local out = {}
  for _, f in ipairs(query(sql)) do
    table.insert(out, {
      subtitle_id = f[1], relpath = f[2], archive_kind = f[3], title = f[4],
      conf = num(f[5]) or 0, hi = (f[6] == "1"), author = f[7],
    })
  end
  return out
end

-- find_movie_subs(title) -> candidate tables for movie-ish titles.
function M.find_movie_subs(title)
  if not M._ok or not title then return nil end
  local q = sql_quote("%" .. tostring(title):lower() .. "%")
  local sql = "SELECT id, archive_relpath, archive_kind, title, best_conf, hearing_impaired, author "
    .. "FROM subtitles WHERE lower(title) LIKE " .. q .. " AND listed != 0 "
    .. "ORDER BY best_conf DESC, hearing_impaired ASC, date_unix DESC LIMIT 25;"
  local out = {}
  for _, f in ipairs(query(sql)) do
    table.insert(out, {
      subtitle_id = f[1], relpath = f[2], archive_kind = f[3], title = f[4],
      conf = num(f[5]) or 0, hi = (f[6] == "1"), author = f[7],
    })
  end
  return out
end

-- abs_path(relpath) -> full path under the dump's subtitle tree.
function M.abs_path(relpath)
  return M._subs_root .. "/" .. tostring(relpath)
end

return M
