-- stubs/options.lua
-- Captures options.read_options calls. By default it is a no-op: the table is
-- left as-is so specs can pre-populate it. The captured options are recorded in
-- harness.calls for assertions.

local harness = require "harness"

local options = {}

-- `merge` lets a spec pre-seed values via harness.options_overrides[name] = {...}.
function options.read_options(opts, name)
  table.insert(harness.calls, { kind = "read_options", name = name, opts = opts })
  local overrides = harness.options_overrides and harness.options_overrides[name]
  if overrides then
    for k, v in pairs(overrides) do opts[k] = v end
  end
  return true
end

return options
