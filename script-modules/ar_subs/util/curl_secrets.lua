-- ar_subs.util.curl_secrets: keep API keys out of mpv's subprocess log.
--
-- mpv logs every subprocess argv at -v ("Starting subprocess: [curl, ...]"),
-- which --log-file always captures. Keys ride in headers (SubSource
-- X-API-Key, Bearer tokens), URLs (SubDL ?api_key=) and POST bodies (TVDB
-- login). protect() moves those arguments into a curl config fed on stdin
-- (--config -); mpv never logs stdin_data. Everything else (-w, -o, -D, -X,
-- timeouts) stays on the command line unchanged.

local M = {}

-- argv flag -> curl config keyword, for flags whose value can carry a secret
local SECRET_FLAGS = {
  ["-H"] = "header", ["--header"] = "header",
  ["-d"] = "data", ["--data"] = "data",
  ["--data-raw"] = "data-raw", ["--data-binary"] = "data-binary",
  ["-u"] = "user", ["--user"] = "user",
}

-- curl config strings: double-quoted, backslash escapes for \ " and controls
local function quote(s)
  s = tostring(s):gsub('[\\"]', "\\%0"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
  return '"' .. s .. '"'
end

-- protect(args) -> new_args, stdin_data
-- Returns the input unchanged (and nil) when it is not a curl argv or
-- carries nothing worth hiding.
function M.protect(args)
  if type(args) ~= "table" or args[1] ~= "curl" then return args, nil end
  local out, cfg = { args[1] }, {}
  local i = 2
  while i <= #args do
    local a = args[i]
    local kw = SECRET_FLAGS[a]
    if kw and args[i + 1] ~= nil then
      cfg[#cfg + 1] = kw .. " = " .. quote(args[i + 1])
      i = i + 2
    elseif type(a) == "string" and a:match("^https?://") then
      cfg[#cfg + 1] = "url = " .. quote(a)
      i = i + 1
    else
      out[#out + 1] = a
      i = i + 1
    end
  end
  if #cfg == 0 then return args, nil end
  out[#out + 1] = "--config"
  out[#out + 1] = "-"
  return out, table.concat(cfg, "\n") .. "\n"
end

-- protect_command(t): in-place rewrite of a subprocess command table, for
-- wrapping mp.command_native / mp.command_native_async. Leaves tables that
-- already feed stdin alone (curl would read the config from the wrong data).
function M.protect_command(t)
  if type(t) ~= "table" or t.name ~= "subprocess" or t.stdin_data ~= nil then return t end
  local args, stdin = M.protect(t.args)
  if not stdin then return t end
  local copy = {}
  for k, v in pairs(t) do copy[k] = v end
  copy.args, copy.stdin_data = args, stdin
  return copy
end

return M
