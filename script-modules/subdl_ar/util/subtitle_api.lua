-- subtitle_api: mpv-side client for the Dockerized Arabic subtitle service
-- (server.py resolves a video to ONE Arabic subtitle file and returns its
-- bytes over HTTP, replacing the old direct NFS+sqlite access).
--
-- fetch() shells out to curl via mp.command_native subprocess (args array,
-- no shell), writes the subtitle bytes to a unique /tmp file ready for
-- sub-add, and returns that path. X-Sub-* response headers are parsed into
-- last_meta() for OSD/logging. Offline-tolerant: the service being down,
-- timing out, or answering 404 just makes fetch() return nil so the caller
-- falls through to SubDL. Never raises.

local M = {}

local _uok, utils = pcall(require, "mp.utils")
if not _uok then utils = nil end

M._mp = nil
M._url = nil
M._timeout = 10
M._ok = false
M._last_meta = {}

local function log(level, ...)
  if M._mp and M._mp.msg then M._mp.msg[level](...) end
end

-- Percent-encode for query strings. RFC 3986 unreserved: ALPHA/DIGIT/-/./_/~
-- (spaces become %20, same convention as subdl_ar.util.url.url_safe).
function M.url_encode(str)
  if not str then return "" end
  return (tostring(str):gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

-- init(opts): { mp, url, timeout }
-- Lazy on purpose: no /health probe here. available() only means "configured
-- enough to try", and a dead service surfaces later as fetch() -> nil.
function M.init(opts)
  opts = opts or {}
  M._mp = opts.mp
  M._url = tostring(opts.url or "http://127.0.0.1:8787"):gsub("/+$", "")
  M._timeout = tonumber(opts.timeout) or 10
  M._ok = M._mp ~= nil and M._mp.command_native ~= nil and M._url ~= ""
  if M._ok then math.randomseed(os.time()) end
  return M._ok
end

function M.available()
  return M._ok == true
end

-- The last X-Sub-* response headers (filename/conf/source/show), or {}.
function M.last_meta()
  return M._last_meta
end

local TYPES = { anime = true, tv = true, movie = true }

-- int(5) -> "5", int("7") -> "7", int("x") -> nil
local function int(v)
  local n = tonumber(v)
  if not n then return nil end
  return tostring(math.floor(n))
end

-- build_query(media) -> "filename=...&title=...&season=...&episode=...&type=..."
-- filename leads; empty fields are omitted so the server can derive them.
local function build_query(media)
  local params = {}
  local function add(k, v)
    if v ~= nil and tostring(v) ~= "" then
      table.insert(params, k .. "=" .. M.url_encode(v))
    end
  end
  -- Callers should pass a basename, but strip any path defensively.
  local filename = media.filename
  if filename then filename = tostring(filename):match("([^/\\]+)$") end
  add("filename", filename)
  add("title", media.title)
  add("season", int(media.season))
  add("episode", int(media.episode))
  if TYPES[media.content_type] then add("type", media.content_type) end
  if media.hi == 1 or media.hi == true then add("hi", "1") end
  return table.concat(params, "&")
end

-- parse_headers(path) -> meta, http_status. Takes the LAST status line (curl
-- -D keeps earlier blocks around after 100-continue) and lowercases X-Sub-*
-- names: "X-Sub-Filename: x.srt" -> meta.filename = "x.srt".
local function parse_headers(path)
  local meta, status = {}, 0
  local f = io.open(path, "r")
  if not f then return meta, status end
  for line in f:lines() do
    local code = line:match("^HTTP/[%d%.]+%s+(%d+)")
    if code then status = tonumber(code) or 0 end
    local k, v = line:lower():match("^(x%-sub%-[%w-]+):%s*(.-)%s*$")
    if k then meta[k:sub(7)] = v end
  end
  f:close()
  return meta, status
end

local function remove_quiet(path)
  if path then os.remove(path) end
end

-- Subtitle extensions worth renaming the temp file to, so sub-add picks the
-- right demuxer. Anything else keeps the default .srt.
local SUB_EXTS = { srt = true, ass = true, ssa = true, sub = true, smi = true, txt = true }

local function do_fetch(media, pick)
  local query = build_query(media)
  if query == "" then
    log("info", "subtitle_api: no filename/title to resolve")
    return nil
  end
  local stamp = string.format("%d_%06d", os.time(), math.random(0, 999999))
  local body_path = "/tmp/subtitle_api_" .. stamp .. ".srt"
  local hdr_path = "/tmp/subtitle_api_" .. stamp .. ".headers"
  local r = M._mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stderr = true,
    args = {
      "curl", "--fail", "--silent", "--show-error",
      "--max-time", tostring(M._timeout),
      "-D", hdr_path,
      "-o", body_path,
      M._url .. "/subtitle?" .. query .. (pick and ("&pick=" .. M.url_encode(pick)) or ""),
    },
  })
  local meta, http_status = parse_headers(hdr_path)
  M._last_meta = meta
  if not r or r.status ~= 0 then
    -- 404, 000 (no connection), timeout, ...: not an error worth surfacing;
    -- the caller falls back to SubDL.
    local err = r and (r.stderr or r.error_string or "") or "subprocess failed"
    err = tostring(err):match("^%s*(.-)%s*$")
    log("info", string.format("subtitle_api: no subtitle (http %d)%s", http_status,
        err ~= "" and (": " .. err) or ""))
    remove_quiet(hdr_path)
    remove_quiet(body_path)
    return nil
  end
  local bf = io.open(body_path, "rb")
  if not bf then
    log("warn", "subtitle_api: curl exited 0 but no body file")
    remove_quiet(hdr_path)
    return nil
  end
  local size = bf:seek("end")
  bf:close()
  if not size or size == 0 then
    log("info", "subtitle_api: empty subtitle body, treating as no match")
    remove_quiet(hdr_path)
    remove_quiet(body_path)
    return nil
  end
  log("info", string.format("subtitle_api: got %s (conf=%s, show=%s)",
      meta.filename or body_path, meta.conf or "?", meta.show or "?"))
  -- Give the temp file the chosen internal file's extension for sub-add.
  local ext = (meta.filename or ""):match("%.([%w]+)$")
  if ext and SUB_EXTS[ext:lower()] then
    local final = body_path:gsub("%.srt$", "." .. ext:lower())
    if os.rename(body_path, final) then body_path = final end
  end
  remove_quiet(hdr_path)
  return body_path
end

-- fetch(media) -> path to a downloaded .srt/.ass ready for sub-add, or nil.
-- media = { title=, season=, episode=, content_type=anime|tv|movie,
--           filename=<video basename>, hi= }
function M.fetch(media, pick)
  M._last_meta = {}
  if not M._ok then return nil end
  local ok, path = pcall(do_fetch, media or {}, pick)
  if not ok then
    log("warn", "subtitle_api: fetch failed: " .. tostring(path))
    return nil
  end
  return path
end


-- candidates(media, limit) -> list of {rank, subscene_id, show_slug, title,
-- conf, hi, filename, author, date} (best first), or nil. Used by the client
-- to offer the top-N releases so "next" can step through them.
function M.candidates(media, limit)
  if not M._ok or not utils or not utils.parse_json then return nil end
  local query = build_query(media or {})
  if query == "" then return nil end
  query = query .. "&limit=" .. tostring(math.floor(tonumber(limit) or 5))
  local stamp = string.format("%d_%06d", os.time(), math.random(0, 999999))
  local body_path = "/tmp/subtitle_api_cand_" .. stamp .. ".json"
  local r = M._mp.command_native({
    name = "subprocess",
    playback_only = false,
    capture_stderr = true,
    args = {
      "curl", "--fail", "--silent", "--show-error",
      "--max-time", tostring(M._timeout),
      "-o", body_path,
      M._url .. "/candidates?" .. query,
    },
  })
  if not r or r.status ~= 0 then
    remove_quiet(body_path)
    return nil
  end
  local f = io.open(body_path, "rb")
  if not f then return nil end
  local raw = f:read("*a")
  f:close()
  remove_quiet(body_path)
  if not raw or raw == "" then return nil end
  local list = utils.parse_json(raw)
  if type(list) ~= "table" or #list == 0 then return nil end
  return list
end

return M