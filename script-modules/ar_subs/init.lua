-- ar_subs.init: bootstrap package.path so that scripts/ar_subs.lua (and any
-- other consumer inside the mpv tree) can `require "ar_subs.*"` and have it
-- resolve to script-modules/ar_subs/.
--
-- This file is loaded in two ways:
--   1. By scripts/ar_subs.lua, which sets up package.path itself before
--      requiring this module (the require resolves via the ?/init.lua pattern
--      that the script adds).
--   2. By any other script that does `require "ar_subs"` after its own
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
  -- ?.lua resolves require "ar_subs.util.url" -> .../ar_subs/util/url.lua
  add(prefix .. "?.lua")
  -- ?/init.lua resolves require "ar_subs" -> .../ar_subs/init.lua
  add(prefix .. "?/init.lua")
end

ensure_path()

return true
