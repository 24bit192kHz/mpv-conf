-- Spec: ar_subs.cache (debounce + key normalization)
local H = require "harness"
local cache = require "ar_subs.cache"

-- ---------------------------------------------------------------------------
-- Helper: mock mp module with controllable timer firing
-- ---------------------------------------------------------------------------
local function make_mock_mp()
  local m = { _pending = {} }
  function m.add_timeout(sec, cb)
    local timer = { _cb = cb, _killed = false }
    function timer:kill() self._killed = true end
    table.insert(m._pending, timer)
    return timer
  end
  m.msg = { info = function() end }
  return m
end

-- ---------------------------------------------------------------------------
-- 1. Debounce: 50 mutations within window → exactly 1 write
-- ---------------------------------------------------------------------------
do
  H.reset()
  local write_count = 0
  local mock_mp = make_mock_mp()

  cache.init(function() write_count = write_count + 1 end, mock_mp)

  for _ = 1, 50 do
    cache.schedule_save()
  end

  -- Only 1 timer should be created (debounce coalesces)
  H.eq("debounce: single timer scheduled for 50 mutations",
       #mock_mp._pending, 1)

  -- Fire the timer callback
  mock_mp._pending[1]._cb()

  H.eq("debounce: exactly 1 write after timer fires",
       write_count, 1)
end

-- ---------------------------------------------------------------------------
-- 2. Debounce: timer killed before firing → no write
-- ---------------------------------------------------------------------------
do
  H.reset()
  local write_count = 0
  local mock_mp = make_mock_mp()

  cache.init(function() write_count = write_count + 1 end, mock_mp)

  cache.schedule_save()
  H.eq("debounce: 1 timer before kill", #mock_mp._pending, 1)

  -- Kill the timer before it fires
  mock_mp._pending[1]:kill()

  H.eq("debounce: 0 writes after timer killed", write_count, 0)
end

-- ---------------------------------------------------------------------------
-- 3. force_save: bypasses debounce, writes immediately
-- ---------------------------------------------------------------------------
do
  H.reset()
  local write_count = 0
  local mock_mp = make_mock_mp()

  cache.init(function() write_count = write_count + 1 end, mock_mp)

  -- Schedule but don't fire
  cache.schedule_save()
  cache.schedule_save()  -- no-op, timer exists

  -- Force save kills pending timer and writes
  cache.force_save()
  H.eq("force_save: writes immediately", write_count, 1)
  H.ok("force_save: pending timer killed",
       mock_mp._pending[1]._killed)

  -- schedule_save works again after force_save
  mock_mp._pending = {}
  cache.schedule_save()
  H.eq("force_save: new timer schedulable after force",
       #mock_mp._pending, 1)
end

-- ---------------------------------------------------------------------------
-- 4. force_save: no pending timer → still writes
-- ---------------------------------------------------------------------------
do
  H.reset()
  local write_count = 0
  local mock_mp = make_mock_mp()

  cache.init(function() write_count = write_count + 1 end, mock_mp)

  cache.force_save()
  H.eq("force_save without pending: still writes", write_count, 1)
end

-- ---------------------------------------------------------------------------
-- 5. stringify_keys: numeric keys become strings
-- ---------------------------------------------------------------------------
do
  local input = { [1] = "a", [2] = "b", hello = "c" }
  local result = cache.stringify_keys(input)
  H.eq("stringify numeric key 1", result["1"], "a")
  H.eq("stringify numeric key 2", result["2"], "b")
  H.eq("stringify string key preserved", result["hello"], "c")
  H.ok("stringify: original numeric key gone", result[1] == nil)
end

-- ---------------------------------------------------------------------------
-- 6. stringify_keys: nested tables
-- ---------------------------------------------------------------------------
do
  local input = { [1] = { [10] = "deep", ["x"] = "y" } }
  local result = cache.stringify_keys(input)
  H.eq("stringify nested outer key", type(result["1"]), "table")
  H.eq("stringify nested inner numeric key", result["1"]["10"], "deep")
  H.eq("stringify nested inner string key", result["1"]["x"], "y")
end

-- ---------------------------------------------------------------------------
-- 7. stringify_keys: nil / non-table passthrough
-- ---------------------------------------------------------------------------
do
  H.eq("stringify nil", cache.stringify_keys(nil), nil)
  H.eq("stringify string", cache.stringify_keys("hello"), "hello")
  H.eq("stringify number", cache.stringify_keys(42), 42)
end

-- ---------------------------------------------------------------------------
-- 8. migrate_keys: tmdb_season_cache numeric keys → string
-- ---------------------------------------------------------------------------
do
  local cache_data = {
    tmdb_seasons = { [12345] = { [1] = 12, [2] = 13 } },
  }
  local migrated = cache.migrate_keys(cache_data)

  H.ok("migrate: tmdb_seasons numeric key becomes string",
       migrated.tmdb_seasons["12345"] ~= nil)
  H.ok("migrate: tmdb_seasons original numeric key gone",
       migrated.tmdb_seasons[12345] == nil)
  -- stringify_keys is recursive: nested numeric keys also become strings
  H.same("migrate: nested season data preserved",
         migrated.tmdb_seasons["12345"], { ["1"] = 12, ["2"] = 13 })
end

-- ---------------------------------------------------------------------------
-- 9. migrate_keys: already-string keys survive
-- ---------------------------------------------------------------------------
do
  local cache_data = {
    tmdb_seasons = { ["12345"] = { ["1"] = 12 } },
  }
  local migrated = cache.migrate_keys(cache_data)

  H.same("migrate: string keys unchanged",
         migrated.tmdb_seasons["12345"], { ["1"] = 12 })
end

-- ---------------------------------------------------------------------------
-- 10. migrate_keys: nil / empty input
-- ---------------------------------------------------------------------------
do
  H.same("migrate: nil input", cache.migrate_keys(nil), {})
  H.same("migrate: empty input", cache.migrate_keys({}), {})
end

-- ---------------------------------------------------------------------------
-- 11. migrate_keys: subdl_sd_cache and tmdb_cache pass through
-- ---------------------------------------------------------------------------
do
  local cache_data = {
    tmdb_cache = { ["tv:show"] = { id = 123, type = "tv" } },
    subdl_sd_cache = { ["tv_123"] = "sd_456" },
    tmdb_seasons = { [99999] = { [1] = 10 } },
  }
  local migrated = cache.migrate_keys(cache_data)

  H.same("migrate: tmdb_cache passes through",
         migrated.tmdb_cache["tv:show"], { id = 123, type = "tv" })
  H.same("migrate: subdl_sd_cache passes through",
         migrated.subdl_sd_cache["tv_123"], "sd_456")
  H.ok("migrate: tmdb_seasons numeric migrated",
       migrated.tmdb_seasons["99999"] ~= nil)
end
