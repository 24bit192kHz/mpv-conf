-- stubs/utils.lua
-- Captures utils.subprocess into harness.calls and returns configurable results.
-- parse_json / format_json use a tiny pure-Lua JSON encoder/decoder (no deps).

local harness = require "harness"

local utils = {}

function utils.subprocess(spec)
  table.insert(harness.calls, { kind = "subprocess", spec = spec })
  local r = harness.subprocess_result or { status = 0, stdout = "", stderr = "" }
  -- Return a shallow copy so specs can mutate without affecting later calls.
  return {
    status = r.status,
    stdout = r.stdout,
    stderr = r.stderr,
    killed = r.killed,
    error_string = r.error_string,
  }
end

-- Minimal JSON decoder. Handles objects, arrays, strings (with escapes),
-- numbers, true/false/null. No comments, no trailing commas. Sufficient for
-- subtitle metadata parsing in tests.
local function skip_ws(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      i = i + 1
    else
      break
    end
  end
  return i
end

local function decode_value(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == "{" then
    local obj = {}
    i = i + 1
    i = skip_ws(s, i)
    if s:sub(i, i) == "}" then return obj, i + 1 end
    while i <= #s do
      i = skip_ws(s, i)
      if s:sub(i, i) ~= '"' then return nil, i end
      local key, j = decode_value(s, i)
      if key == nil then return nil, j end
      i = skip_ws(s, j)
      if s:sub(i, i) ~= ":" then return nil, i end
      i = i + 1
      local val
      val, i = decode_value(s, i)
      if val == nil and s:sub(i, i) ~= "" then end
      obj[key] = val
      i = skip_ws(s, i)
      local sep = s:sub(i, i)
      if sep == "," then i = i + 1
      elseif sep == "}" then return obj, i + 1
      else return nil, i end
    end
    return nil, i
  elseif c == "[" then
    local arr = {}
    i = i + 1
    i = skip_ws(s, i)
    if s:sub(i, i) == "]" then return arr, i + 1 end
    while i <= #s do
      local val
      val, i = decode_value(s, i)
      arr[#arr + 1] = val
      i = skip_ws(s, i)
      local sep = s:sub(i, i)
      if sep == "," then i = i + 1
      elseif sep == "]" then return arr, i + 1
      else return nil, i end
    end
    return nil, i
  elseif c == '"' then
    i = i + 1
    local out, chars = {}, {}
    while i <= #s do
      local ch = s:sub(i, i)
      if ch == '"' then
        return table.concat(chars), i + 1
      elseif ch == "\\" then
        local nxt = s:sub(i + 1, i + 1)
        if nxt == "n" then chars[#chars + 1] = "\n"
        elseif nxt == "t" then chars[#chars + 1] = "\t"
        elseif nxt == "r" then chars[#chars + 1] = "\r"
        elseif nxt == '"' then chars[#chars + 1] = '"'
        elseif nxt == "\\" then chars[#chars + 1] = "\\"
        elseif nxt == "/" then chars[#chars + 1] = "/"
        elseif nxt == "u" then
          local hex = s:sub(i + 2, i + 5)
          local code = tonumber(hex, 16)
          if code then chars[#chars + 1] = string.char(code) end
          i = i + 4
        else chars[#chars + 1] = nxt end
        i = i + 2
      else
        chars[#chars + 1] = ch
        i = i + 1
      end
    end
    return nil, i
  elseif c == "t" then
    if s:sub(i, i + 3) == "true" then return true, i + 4 end
    return nil, i
  elseif c == "f" then
    if s:sub(i, i + 4) == "false" then return false, i + 5 end
    return nil, i
  elseif c == "n" then
    if s:sub(i, i + 3) == "null" then return nil, i + 4 end
    return nil, i
  elseif c == "-" or c:match("%d") then
    local j = i
    if c == "-" then j = j + 1 end
    while j <= #s and s:sub(j, j):match("[%d%.eE%+%-]") do j = j + 1 end
    local num = s:sub(i, j - 1)
    return tonumber(num), j
  end
  return nil, i
end

function utils.parse_json(s)
  if type(s) ~= "string" or s == "" then return nil end
  if harness.json_decode then return harness.json_decode(s) end
  local val, i = decode_value(s, 1)
  return val
end

-- Minimal JSON encoder. Emits tables as objects when they have string keys,
-- arrays when they have sequential integer keys.
local function encode_value(v, out)
  local t = type(v)
  if t == "nil" then
    out[#out + 1] = "null"
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    out[#out + 1] = tostring(v)
  elseif t == "string" then
    local esc = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    out[#out + 1] = '"' .. esc .. '"'
  elseif t == "table" then
    -- Decide array vs object.
    local n = 0
    local is_array = true
    for k in pairs(v) do
      n = n + 1
      if type(k) ~= "number" then is_array = false end
    end
    if n == 0 then
      out[#out + 1] = "{}"
    elseif is_array then
      out[#out + 1] = "["
      for i = 1, n do
        if i > 1 then out[#out + 1] = "," end
        encode_value(v[i], out)
      end
      out[#out + 1] = "]"
    else
      out[#out + 1] = "{"
      local first = true
      for k, val in pairs(v) do
        if not first then out[#out + 1] = "," end
        first = false
        out[#out + 1] = '"' .. tostring(k) .. '":'
        encode_value(val, out)
      end
      out[#out + 1] = "}"
    end
  else
    out[#out + 1] = '"' .. tostring(v) .. '"'
  end
end

function utils.format_json(v)
  local out = {}
  encode_value(v, out)
  return table.concat(out)
end

function utils.file_info(path)
  local entry = harness.file_info_map[path]
  if entry == nil then return nil end
  -- Return a copy so specs can mutate without affecting later calls.
  local copy = {}
  for k, val in pairs(entry) do copy[k] = val end
  return copy
end

function utils.join_path(a, b)
  if a == nil or a == "" then return b or "" end
  if b == nil or b == "" then return a end
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

function utils.getcwd()
  return os.getenv("PWD") or "."
end

return utils
