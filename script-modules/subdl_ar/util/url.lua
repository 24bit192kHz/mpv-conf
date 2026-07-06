-- subdl_ar.util.url: pure string utilities for URLs, paths, and filenames.
-- No mp.* calls, no I/O, no global mutation.

local M = {}

function M.trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

function M.strip_quotes(value)
  value = M.trim(value)
  local first = value:sub(1, 1)
  local last = value:sub(-1)
  if (first == '"' and last == '"') or (first == "'" and last == "'") then
    return value:sub(2, -2)
  end
  return value
end

function M.url_safe(str)
  if not str then return "" end
  -- RFC 3986 unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
  return (tostring(str):gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

function M.redact_url(url)
  return tostring(url or ""):gsub("([?&]api_key=)[^&]*", "%1<redacted>")
end

function M.basename(path)
  return path:match("([^/]+)%.[^/]*$")
end

function M.sanitize_filename(name)
  local ext = name:match("%.([^.]+)$") or ""
  local base = name:gsub("%.[^.]+$", "")
  base = base:gsub("[%[%]%(%)'\"`]", "")
    :gsub("%s+", "_")
    :gsub("_+", "_")
    :gsub("^_", "")
    :gsub("_$", "")
    :gsub("_%-_", "-")
    :gsub("%-+", "-")
  return base .. "." .. ext
end

return M
