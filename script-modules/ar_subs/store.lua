-- ar_subs.store: persistent key/value cache on SQLite (sqlite3 CLI) with
-- zstd-compressed payloads.
--
-- Why CLI subprocesses: mpv's LuaJIT ships no sqlite binding, but the sqlite3
-- and zstd CLIs are present on the target host. fileio extension (readfile/
-- writefile) gives binary-safe blob I/O through temp files, so payloads never
-- touch shell quoting.
--
-- Layout: one table kv(ns, k, v BLOB, updated) WITHOUT ROWID. Callers organize
-- data by namespace + structured keys, e.g.:
--   ns="search"  k="anime/deadman wonderland/s1/deep0"
--   ns="show"    k="tv:42503"
-- Every failure degrades to nil/false — the cache is an accelerator, never a
-- dependency. If sqlite3 or zstd is missing, available() is false and all
-- ops no-op.

local M = {}

M._db = nil
M._dir = nil
M._mp = nil
M._seq = 0
M._ok = false

local function log(level, ...)
  if M._mp and M._mp.msg then M._mp.msg[level](...) end
end

local function have_bin(name)
  local path = os.getenv("PATH") or "/usr/bin:/bin"
  for dir in path:gmatch("[^:]+") do
    local f = io.open(dir .. "/" .. name, "r")
    if f then f:close() return true end
  end
  return false
end

local function sh_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Keys/namespaces go inside SQL literals; keep them to a safe charset so
-- quote-doubling is the only escaping needed.
local function sql_safe(s)
  return (tostring(s):gsub("[^%w%._:%- ]", "_"):gsub("'", "''"))
end

local function tmp_path(tag)
  M._seq = M._seq + 1
  return string.format("%s/.s_%d_%d_%s", M._dir, os.time(), M._seq, tag)
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function write_file(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function exit_ok(...)
  -- Lua 5.1/LuaJIT: os.execute returns the numeric status (0 = success).
  -- Lua 5.2+: returns (ok, how, code). Accept both.
  local a, _b, c = ...
  if type(a) == "boolean" then return a and (c == 0 or c == nil) end
  return a == 0
end

local function run(cmd)
  return exit_ok(os.execute(cmd .. " >/dev/null 2>&1"))
end

-- Like run() but keeps the command's own redirections (no stdout suppression).
local function run_raw(cmd)
  return exit_ok(os.execute(cmd .. " 2>/dev/null"))
end

-- init(opts): opts = { dir = <cache dir>, mp = <mp module or nil> }
-- Creates the db + schema on first use. Idempotent.
function M.init(opts)
  opts = opts or {}
  if M._ok then return true end
  M._mp = opts.mp
  M._dir = opts.dir
  if not M._dir then return false end

  if not have_bin("sqlite3") or not have_bin("zstd") then
    log("warn", "store: sqlite3/zstd CLI missing, persistent cache disabled")
    return false
  end

  os.execute("mkdir -p " .. sh_quote(M._dir))
  M._db = M._dir .. "/cache.db"

  local schema = "CREATE TABLE IF NOT EXISTS kv("
    .. "ns TEXT NOT NULL, k TEXT NOT NULL, v BLOB, updated INTEGER, "
    .. "PRIMARY KEY(ns, k)) WITHOUT ROWID;"
  if not run("sqlite3 -batch " .. sh_quote(M._db) .. " " .. sh_quote(schema)) then
    log("warn", "store: schema init failed, persistent cache disabled")
    M._db = nil
    return false
  end

  M._ok = true
  return true
end

function M.available()
  return M._ok == true
end

-- put(ns, key, data): compress data (string) with zstd, upsert row.
function M.put(ns, key, data)
  if not M._ok or type(data) ~= "string" then return false end
  local raw = tmp_path("raw")
  local zst = tmp_path("zst")
  if not write_file(raw, data) then return false end

  local ok = run("zstd -q -f -o " .. sh_quote(zst) .. " " .. sh_quote(raw))
  if ok then
    local sql = string.format(
      "INSERT INTO kv(ns,k,v,updated) VALUES('%s','%s',readfile('%s'),%d) "
      .. "ON CONFLICT(ns,k) DO UPDATE SET v=excluded.v, updated=excluded.updated;",
      sql_safe(ns), sql_safe(key), zst, os.time())
    ok = run("sqlite3 -batch " .. sh_quote(M._db) .. " " .. sh_quote(sql))
  end

  os.remove(raw)
  os.remove(zst)
  if not ok then log("warn", "store: put failed ns=" .. tostring(ns) .. " k=" .. tostring(key)) end
  return ok
end

-- get(ns, key [, max_age]): decompressed string or nil. max_age in seconds;
-- rows older than max_age are treated as missing (but not deleted).
function M.get(ns, key, max_age)
  if not M._ok then return nil end
  local zst = tmp_path("zst")
  local meta = tmp_path("meta")

  local sql = string.format(
    "SELECT writefile('%s', v), updated FROM kv WHERE ns='%s' AND k='%s';",
    zst, sql_safe(ns), sql_safe(key))
  local ok = run_raw("sqlite3 -batch -list " .. sh_quote(M._db) .. " " .. sh_quote(sql)
    .. " > " .. sh_quote(meta))

  local data = nil
  if ok then
    local line = read_file(meta)
    local updated = line and line:match("|(%d+)")
    updated = tonumber(updated)
    if updated and (not max_age or (os.time() - updated) <= max_age) then
      local raw = tmp_path("out")
      if run("zstd -q -d -f -o " .. sh_quote(raw) .. " " .. sh_quote(zst)) then
        data = read_file(raw)
      end
      os.remove(raw)
    end
  end

  os.remove(zst)
  os.remove(meta)
  return data
end

function M.del(ns, key)
  if not M._ok then return false end
  local sql = string.format("DELETE FROM kv WHERE ns='%s' AND k='%s';",
    sql_safe(ns), sql_safe(key))
  return run("sqlite3 -batch " .. sh_quote(M._db) .. " " .. sh_quote(sql))
end

-- Vacuum old rows across one namespace (housekeeping, best-effort).
function M.purge_older(ns, max_age)
  if not M._ok or not max_age then return false end
  local sql = string.format("DELETE FROM kv WHERE ns='%s' AND updated < %d;",
    sql_safe(ns), os.time() - max_age)
  return run("sqlite3 -batch " .. sh_quote(M._db) .. " " .. sh_quote(sql))
end

return M
