-- ar_subs.providers.tvdb: TVDB v4 API client for anime cour resolution.
--
-- Resolves absolute episode numbers to (season, episode) pairs using
-- TheTVDB's episode data. This is a higher-confidence source than
-- calculate_cour_mappings() when available.
--
-- Flow:
--   1. login()         – POST /v4/login with apikey, cache JWT in memory
--   2. search_series()  – GET /v4/search?query=...&type=series
--   3. resolve_absolute() – GET /v4/series/{id}/episodes/default?page=0
--                          iterate pages to match absoluteNumber == N
--
-- Dep injection via configure() for testability.

local M = {}

M._cfg = {
  api_key  = "",
  base_url = "https://api4.thetvdb.com/v4",
}

M._http = {
  post_json_async = nil,
  get_json_async  = nil,
}

-- In-memory state
M._jwt = nil              -- current JWT token
M._series_cache = {}      -- title_lower -> { id, name }

local function log(level, msg)
  local ok, mp = pcall(require, "mp")
  if ok and mp and mp.msg and mp.msg[level] then
    mp.msg[level](msg)
  end
end

function M.configure(deps)
  if type(deps) ~= "table" then return end
  for k, v in pairs(deps) do
    if k == "post_json_async" then M._http.post_json_async = v
    elseif k == "get_json_async" then M._http.get_json_async = v
    else M._cfg[k] = v end
  end
end

local function auth_headers()
  if not M._jwt then return {} end
  return { "Authorization: Bearer " .. M._jwt }
end

-- login(on_done): POST /v4/login, store JWT.
-- on_done(success, token)
function M.login(on_done)
  -- Skip if JWT already cached
  if M._jwt then
    if on_done then on_done(true, M._jwt) end
    return
  end

  if not M._http.post_json_async then
    log("warn", "TVDB: no post_json_async configured")
    if on_done then on_done(false, nil) end
    return
  end

  local url = M._cfg.base_url .. "/login"
  local body = string.format('{"apikey":"%s"}', M._cfg.api_key)

  return M._http.post_json_async(url, {
    body = body,
    headers = { "Content-Type: application/json" },
  }, function(success, json, http_code)
    if not success or not json or not json.data or not json.data.token then
      log("warn", "TVDB: login failed (http=" .. tostring(http_code) .. ")")
      if on_done then on_done(false, nil) end
      return
    end
    M._jwt = json.data.token
    log("info", "TVDB: login succeeded")
    if on_done then on_done(true, M._jwt) end
  end)
end

-- search_series(query, on_done): GET /v4/search, return first series id.
-- on_done(series_id, series_name)
function M.search_series(query, on_done)
  if not M._http.get_json_async then
    log("warn", "TVDB: no get_json_async configured")
    if on_done then on_done(nil, nil) end
    return
  end

  local cache_key = query:lower()
  if M._series_cache[cache_key] then
    local cached = M._series_cache[cache_key]
    log("info", "TVDB: using cached series id " .. tostring(cached.id) .. " for " .. query)
    if on_done then on_done(cached.id, cached.name) end
    return
  end

  local encoded_query = query:gsub(" ", "+")
  local url = string.format("%s/search?query=%s&type=series", M._cfg.base_url, encoded_query)

  return M._http.get_json_async(url, { headers = auth_headers() }, function(success, json, http_code)
    if not success or not json or not json.data or #json.data == 0 then
      log("warn", "TVDB: no series found for '" .. query .. "'")
      if on_done then on_done(nil, nil) end
      return
    end
    local first = json.data[1]
    M._series_cache[cache_key] = { id = first.id, name = first.name }
    log("info", string.format("TVDB: found series '%s' (id=%d)", first.name, first.id))
    if on_done then on_done(first.id, first.name) end
  end)
end

-- resolve_absolute(series_id, absolute_number, on_done):
--   Iterate episode pages to find the episode with absoluteNumber == N.
--   on_done({ season = S, episode = E }) or on_done(nil)
function M.resolve_absolute(series_id, absolute_number, on_done)
  if not M._http.get_json_async then
    log("warn", "TVDB: no get_json_async configured")
    if on_done then on_done(nil) end
    return
  end

  local function fetch_page(page)
    local url = string.format("%s/series/%d/episodes/default?page=%d",
                              M._cfg.base_url, series_id, page)
    return M._http.get_json_async(url, { headers = auth_headers() }, function(success, json, http_code)
      if not success or not json or not json.data then
        log("warn", "TVDB: episodes fetch failed (page=" .. page .. ")")
        if on_done then on_done(nil) end
        return
      end

      local episodes = json.data.episodes or {}
      for _, ep in ipairs(episodes) do
        if ep.absoluteNumber and tonumber(ep.absoluteNumber) == absolute_number then
          local result = {
            season  = tonumber(ep.seasonNumber),
            episode = tonumber(ep.number),
          }
          log("info", string.format("TVDB: resolved absolute %d -> S%dE%d",
               absolute_number, result.season, result.episode))
          if on_done then on_done(result) end
          return
        end
      end

      -- Check for next page
      local links = json.data.links or {}
      if links.next then
        fetch_page(page + 1)
      else
        log("warn", string.format("TVDB: absolute %d not found for series %d", absolute_number, series_id))
        if on_done then on_done(nil) end
      end
    end)
  end

  return fetch_page(0)
end

return M
