-- stubs/mp.lua
-- Captures mp.* side effects into the shared `harness` table for assertions.
-- Returned table is preloaded into package.loaded["mp"] by run.lua.

local harness = require "harness"

local mp = {}

mp._script_name = "ar_subs"

function mp.get_script_name() return mp._script_name end

function mp.get_script_directory()
  return harness._script_dir or "/tmp/ar_subs_test_script_dir"
end

function mp.command_native(cmd)
  table.insert(harness.calls, { kind = "command_native", cmd = cmd })
  if type(cmd) == "table" and cmd[1] == "expand-path" then
    local path = cmd[2] or ""
    -- Resolve ~~/ to the test's script-modules root so config.read_dotenv works.
    if harness._test_root and path:find("~~", 1, true) then
      path = path:gsub("~~", harness._test_root .. "/..")
    end
    return path
  end
  return nil
end

function mp.command_native_async(cmd, cb)
  table.insert(harness.calls, { kind = "command_native_async", cmd = cmd })
  if cb then cb(harness.subprocess_result) end
  return nil
end

function mp.commandv(...)
  local args = { ... }
  table.insert(harness.calls, { kind = "commandv", args = args })
  return nil
end

function mp.osd_message(msg, duration)
  table.insert(harness.calls, { kind = "osd_message", msg = msg, duration = duration })
end

local function log(level)
  return function(...)
    local parts = { ... }
    local n = #parts
    local msg
    if n == 0 then
      msg = ""
    elseif n == 1 then
      msg = tostring(parts[1])
    else
      -- mpv's msg.* joins args with a space, matching Lua print semantics.
      local out = {}
      for i = 1, n do out[i] = tostring(parts[i]) end
      msg = table.concat(out, " ")
    end
    table.insert(harness.logs, { level = level, msg = msg })
  end
end

mp.msg = {
  fatal = log("fatal"),
  error = log("error"),
  warn  = log("warn"),
  info  = log("info"),
  verbose = log("verbose"),
  debug = log("debug"),
  trace = log("trace"),
}

function mp.get_property(name)
  return harness.props[name]
end

function mp.get_property_native(name)
  return harness.props_native[name] or harness.props[name]
end

function mp.set_property(name, value)
  harness.props[name] = value
  table.insert(harness.calls, { kind = "set_property", name = name, value = value })
end

function mp.set_property_bool(name, value)
  harness.props[name] = value and true or false
  table.insert(harness.calls, { kind = "set_property_bool", name = name, value = value })
end

function mp.observe_property(name, t, cb)
  table.insert(harness.calls, { kind = "observe_property", name = name, type = t })
end

function mp.register_event(name, cb)
  table.insert(harness.calls, { kind = "register_event", name = name })
end

function mp.register_script_message(name, cb)
  table.insert(harness.calls, { kind = "register_script_message", name = name })
end

function mp.add_key_binding(key, name, cb, def)
  table.insert(harness.calls, { kind = "add_key_binding", key = key, name = name })
end

function mp.add_timeout(sec, cb)
  table.insert(harness.calls, { kind = "add_timeout", sec = sec })
  return {}
end

function mp.add_periodic_timer(sec, cb)
  table.insert(harness.calls, { kind = "add_periodic_timer", sec = sec })
  return {}
end

function mp.get_time() return harness._now or 0 end

function mp.create_osd_overlay()
  return { update = function() end }
end

return mp
