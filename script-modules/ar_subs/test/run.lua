#!/usr/bin/env lua
-- Zero-dependency test runner for ar_subs modules.
--
-- Discovers spec/test_*.lua under test/spec/, runs each with mp/mp.utils/mp.options
-- stubbed, collects results, prints a summary, and exits non-zero on any failure.
--
-- Usage:  lua script-modules/ar_subs/test/run.lua

local _source = debug.getinfo(1, "S").source:sub(2)
local _test_dir = _source:match("^(.*)/[^/]*$") or "."
local _module_root = _test_dir:match("^(.*)/test$") or _test_dir
local _script_modules = _module_root:match("^(.*)/ar_subs$") or _module_root

-- Build package.path. A dotted require like "stubs.mp" expands to the path
-- "stubs/mp" (dots become separators), so each template substitutes `?` with
-- the full dotted name flattened to a path. The templates below resolve:
--   require "stubs.mp"        -> <test_dir>/stubs/mp.lua
--   require "spec.test_url"   -> <test_dir>/spec/test_url.lua
--   require "ar_subs.util.x" -> <script_modules>/ar_subs/util/x.lua
--   require "ar_subs.config" -> <script_modules>/ar_subs/config.lua
--   require "ar_subs"        -> <script_modules>/ar_subs/init.lua
package.path = table.concat({
  _test_dir .. "/?.lua",
  _script_modules .. "/?.lua",
  _script_modules .. "/?/init.lua",
  package.path,
}, ";")

-- ---------------------------------------------------------------------------
-- harness: shared state + assertion helpers consumed by stubs and specs.
-- ---------------------------------------------------------------------------
local harness = {
  -- captured side effects
  calls = {},          -- { {kind=, cmd=, args=, ...}, ... }
  logs = {},           -- { {level=, msg=}, ... }
  -- configurable return values
  props = {},          -- mp.get_property[name] = value
  props_native = {},   -- mp.get_property_native[name] = value
  file_info_map = {},  -- utils.file_info[path] = info-table (or nil)
  subprocess_result = { status = 0, stdout = "", stderr = "", killed = false },
  json_decode = nil,   -- optional function(s) -> table; default is the bundled mini-parser
  -- accumulated spec results
  _results = { passed = 0, failed = 0, failures = {} },
}

function harness.reset()
  harness.calls = {}
  harness.logs = {}
  harness.props = {}
  harness.props_native = {}
  harness.file_info_map = {}
  harness.subprocess_result = { status = 0, stdout = "", stderr = "", killed = false }
end

local function _fmt(v)
  if type(v) == "string" then return v end
  if type(v) == "table" then
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts + 1] = tostring(k) .. "=" .. _fmt(val)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  return tostring(v)
end

-- Shallow/deep table equality used by same().
local function _same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not _same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- Compare expected against actual; treats nil and "" distinctly.
function harness.eq(name, actual, expected)
  if actual == expected then
    harness._results.passed = harness._results.passed + 1
  else
    harness._results.failed = harness._results.failed + 1
    table.insert(harness._results.failures, string.format(
      "%s\n    expected: %s\n    got:      %s",
      name, _fmt(expected), _fmt(actual)))
  end
end

-- Multi-value equality: eq_n(name, {a, b, c}, {x, y, z}) compares elementwise.
function harness.eq_n(name, actuals, expecteds)
  if #actuals ~= #expecteds then
    harness._results.failed = harness._results.failed + 1
    table.insert(harness._results.failures, string.format(
      "%s\n    arity mismatch: expected %d values, got %d",
      name, #expecteds, #actuals))
    return
  end
  for i = 1, #expecteds do
    if actuals[i] ~= expecteds[i] then
      harness._results.failed = harness._results.failed + 1
      table.insert(harness._results.failures, string.format(
        "%s (value %d)\n    expected: %s\n    got:      %s",
        name, i, _fmt(expecteds[i]), _fmt(actuals[i])))
      return
    end
  end
  harness._results.passed = harness._results.passed + 1
end

-- Deep table equality.
function harness.same(name, actual, expected)
  if _same(actual, expected) then
    harness._results.passed = harness._results.passed + 1
  else
    harness._results.failed = harness._results.failed + 1
    table.insert(harness._results.failures, string.format(
      "%s\n    expected: %s\n    got:      %s",
      name, _fmt(expected), _fmt(actual)))
  end
end

-- Truthy assertion.
function harness.ok(name, cond, msg)
  if cond then
    harness._results.passed = harness._results.passed + 1
  else
    harness._results.failed = harness._results.failed + 1
    table.insert(harness._results.failures, name .. ": " .. (msg or "expected truthy"))
  end
end

-- Preload harness so stubs and specs can `require "harness"`.
package.loaded["harness"] = harness

-- ---------------------------------------------------------------------------
-- Preload mp / mp.utils / mp.options stubs. Done by actually requiring the
-- stub modules (which themselves consult `harness` for capture behaviour).
-- ---------------------------------------------------------------------------
package.loaded["mp"] = require "stubs.mp"
package.loaded["mp.utils"] = require "stubs.utils"
package.loaded["mp.options"] = require "stubs.options"

-- Also expose config root so ar_subs.config (if required during a spec) can
-- see that mp is the stub.
package.loaded["mp"]._test_root = _script_modules

-- ---------------------------------------------------------------------------
-- Spec discovery + runner.
-- ---------------------------------------------------------------------------
local function list_specs(dir)
  local files = {}
  local ok, pipe = pcall(io.popen, 'ls -1 "' .. dir .. '" 2>/dev/null')
  if ok and pipe then
    for line in pipe:lines() do
      if line:match("^test_.*%.lua$") then files[#files + 1] = line end
    end
    pipe:close()
  end
  table.sort(files)
  return files
end

local spec_dir = _test_dir .. "/spec"
local spec_files = list_specs(spec_dir)

if #spec_files == 0 then
  -- Fall back to a hardcoded list if ls is unavailable.
  spec_files = { "test_url.lua", "test_media.lua", "test_match.lua" }
end

local function module_name(file)
  return "spec." .. file:gsub("%.lua$", "")
end

print(string.format("ar_subs test runner: %d spec file(s)", #spec_files))
print(string.rep("-", 60))

local any_failed = false
for _, file in ipairs(spec_files) do
  local mod = module_name(file)
  harness.reset()
  local before_pass = harness._results.passed
  local before_fail = harness._results.failed
  local ok, err = xpcall(function()
    require(mod)
  end, function(e) return debug.traceback(tostring(e), 2) end)
  local d_pass = harness._results.passed - before_pass
  local d_fail = harness._results.failed - before_fail
  local status = ok and (d_fail == 0 and "PASS" or "FAIL") or "ERROR"
  if status ~= "PASS" then any_failed = true end
  print(string.format("  %-22s  %s  (%d passed, %d failed)",
    file, status, d_pass, d_fail))
  if not ok then
    print(string.rep(" ", 24) .. "error: " .. tostring(err):gsub("\n", "\n" .. string.rep(" ", 24)))
  end
end

print(string.rep("-", 60))
print(string.format("TOTAL: %d passed, %d failed",
  harness._results.passed, harness._results.failed))

if #harness._results.failures > 0 then
  print("\nFailures:")
  for i, f in ipairs(harness._results.failures) do
    print(string.format("\n[%d] %s", i, f))
  end
end

os.exit(any_failed and 1 or 0)
