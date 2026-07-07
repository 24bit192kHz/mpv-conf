-- subdl_ar.cache — debounced disk writes + cache key normalization.
--
-- Provides:
--   init(save_fn, mp_mod)   – inject real save function and mp module
--   schedule_save()         – coalesce mutations into a single delayed write
--   force_save()            – immediate write (shutdown / teardown)
--   stringify_keys(t)       – recursively convert all table keys to strings
--   migrate_keys(cache_data) – normalize legacy numeric keys in loaded cache

local M = {}

local save_fn        -- function that performs the actual JSON write
local mp_mod         -- mp module (real or mock)
local pending_timer = nil
local PENDING_DELAY = 2.0  -- seconds

function M.init(actual_save_fn, mp_module)
    save_fn = actual_save_fn
    mp_mod = mp_module
    pending_timer = nil
end

--- Schedule a debounced save. Multiple calls within the window coalesce
--- into a single disk write.
function M.schedule_save()
    if pending_timer then return end  -- already scheduled
    pending_timer = mp_mod.add_timeout(PENDING_DELAY, function()
        pending_timer = nil
        if save_fn then save_fn() end
    end)
end

--- Immediately write and cancel any pending debounced save.
function M.force_save()
    if pending_timer then
        pending_timer:kill()
        pending_timer = nil
    end
    if save_fn then save_fn() end
end

--- Recursively convert all table keys to strings.  Returns non-table values
--- unchanged.
function M.stringify_keys(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
        result[tostring(k)] = M.stringify_keys(v)
    end
    return result
end

--- One-time migration: convert any legacy numeric keys in the loaded cache
--- data to strings so lookups by string key always succeed.
function M.migrate_keys(cache_data)
    if type(cache_data) ~= "table" then return {} end
    local migrated = {}
    for k, v in pairs(cache_data) do
        migrated[k] = v
    end
    -- tmdb_seasons may have numeric tmdb_id keys from a pre-migration save
    if type(migrated.tmdb_seasons) == "table" then
        migrated.tmdb_seasons = M.stringify_keys(migrated.tmdb_seasons)
    end
    return migrated
end

return M
