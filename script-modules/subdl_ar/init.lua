-- subdl_ar.init: bootstrap package.path so that scripts/subdl_ar.lua (and any
-- other consumer inside the mpv tree) can `require "subdl_ar.*"` and have it
-- resolve to script-modules/subdl_ar/.
--
-- This file is loaded in two ways:
--   1. By scripts/subdl_ar.lua, which sets up package.path itself before
--      requiring this module (the require resolves via the ?/init.lua pattern
--      that the script adds).
--   2. By any other script that does `require "subdl_ar"` after its own
--      package.path setup; this file's ensure_path() is idempotent.
--
-- Idempotent: safe to call multiple times.

local function ensure_path()
  local ok, mp = pcall(require, "mp")
  if not (ok and mp and mp.command_native) then return end
  local ok2, modules_dir = pcall(mp.command_native, {"expand-path", "~~/script-modules"})
  if not ok2 or type(modules_dir) ~= "string" or modules_dir == "" then return end

  local prefix = modules_dir .. "/"
  local function add(pattern)
    if not package.path:find(pattern, 1, true) then
      package.path = pattern .. ";" .. package.path
    end
  end
  -- ?.lua resolves require "subdl_ar.util.url" -> .../subdl_ar/util/url.lua
  add(prefix .. "?.lua")
  -- ?/init.lua resolves require "subdl_ar" -> .../subdl_ar/init.lua
  add(prefix .. "?/init.lua")
end

ensure_path()

return true
