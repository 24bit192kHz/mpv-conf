-- Spec: ar_subs.providers.tvdb (anime cour resolution)
--
-- Tests:
--   1. configure() stores api_key and base_url
--   2. login: POST /v4/login with apikey, stores JWT
--   3. login: failure sets no JWT
--   4. search_series: GET /v4/search with query, returns first series id
--   5. search_series: empty results returns nil
--   6. resolve_absolute: iterates pages, matches absoluteNumber
--   7. resolve_absolute: no match returns nil
--   8. resolve_absolute: multi-page pagination
--   9. login + search + resolve full flow
--  10. series caching: second search for same title skips HTTP
--  11. JWT caching: second call skips login
--  12. configure with no deps doesn't crash

local H = require "harness"

package.loaded["ar_subs.providers.tvdb"] = nil
local provider = require "ar_subs.providers.tvdb"

---------------------------------------------------------------------------
-- Helper: capture HTTP calls
---------------------------------------------------------------------------
local captured = {}
local call_count = 0

local function default_login_response()
  return { status = "success", data = { token = "jwt-token-abc123" } }
end

local function default_search_response()
  return {
    status = "success",
    data = {
      { id = 12345, name = "Attack on Titan", slug = "attack-on-titan" },
    },
  }
end

local function default_episodes_page(page)
  page = page or 0
  local episodes = {}
  -- Generate episodes 1-25 across 2 pages
  local start_ep = page * 25 + 1
  local end_ep = math.min(start_ep + 24, 75)
  for i = start_ep, end_ep do
    local season, ep_in_season
    if i <= 25 then
      season, ep_in_season = 1, i
    elseif i <= 50 then
      season, ep_in_season = 2, i - 25
    else
      season, ep_in_season = 3, i - 50
    end
    table.insert(episodes, {
      absoluteNumber = i,
      seasonNumber = season,
      number = ep_in_season,
      aired = "2013-04-07",
    })
  end
  return {
    status = "success",
    data = {
      episodes = episodes,
      links = { next = (end_ep < 75) and ("https://api4.thetvdb.com/v4/series/12345/episodes/default?page=" .. (page + 1)) or nil },
    },
  }
end

local function setup_provider(overrides)
  captured = {}
  call_count = 0
  provider.configure {
    api_key = "TEST_TVDB_KEY",
    base_url = "https://api4.thetvdb.com/v4",
    post_json_async = function(url, opts, on_done)
      call_count = call_count + 1
      captured[#captured + 1] = { kind = "post_json", url = url, opts = opts }
      local resp = overrides and overrides.post_response or default_login_response()
      local code = overrides and overrides.post_code or 200
      if on_done then on_done(true, resp, code) end
      return call_count
    end,
    get_json_async = function(url, opts, on_done)
      call_count = call_count + 1
      captured[#captured + 1] = { kind = "get_json", url = url, opts = opts }
      local resp
      local code = 200
      if overrides and overrides.get_handler then
        resp, code = overrides.get_handler(url, opts)
      elseif overrides and overrides.get_response then
        resp = overrides.get_response
        code = overrides.get_code or 200
      else
        resp = default_episodes_page(0)
      end
      if on_done then on_done(true, resp, code) end
      return call_count
    end,
  }
end

---------------------------------------------------------------------------
-- (1) configure stores api_key and base_url
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  H.eq("api_key stored", provider._cfg.api_key, "TEST_TVDB_KEY")
  H.eq("base_url stored", provider._cfg.base_url, "https://api4.thetvdb.com/v4")
end

---------------------------------------------------------------------------
-- (2) login: POST /v4/login with apikey, stores JWT
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  provider.login(function(success, token)
    H.ok("login succeeds", success)
    H.eq("login returns token", token, "jwt-token-abc123")
    H.eq("JWT stored in provider", provider._jwt, "jwt-token-abc123")
  end)
  -- Verify POST was called
  H.ok("login made a POST call", #captured >= 1)
  if #captured >= 1 then
    H.eq("login POST URL", captured[1].url, "https://api4.thetvdb.com/v4/login")
  end
end

---------------------------------------------------------------------------
-- (3) login: failure sets no JWT
---------------------------------------------------------------------------
do
  H.reset()
  provider._jwt = nil
  setup_provider {
    post_response = { status = "error", message = "Unauthorized" },
    post_code = 401,
  }
  provider.login(function(success, token)
    H.ok("login fails on bad key", not success)
    H.eq("no JWT on failure", provider._jwt, nil)
  end)
end

---------------------------------------------------------------------------
-- (4) search_series: GET /v4/search with query, returns first series id
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_response = default_search_response(),
  }
  -- Pre-set JWT so login is skipped
  provider._jwt = "existing-jwt"
  provider.search_series("Attack on Titan", function(series_id, series_name)
    H.eq("series_id returned", series_id, 12345)
    H.eq("series_name returned", series_name, "Attack on Titan")
  end)
  -- Verify GET was called with search query
  local found = false
  for _, c in ipairs(captured) do
    if c.kind == "get_json" and c.url:find("/search?", 1, true) then
      found = true
      H.ok("search URL contains query", c.url:find("query=Attack+on+Titan", 1, true) ~= nil
                                        or c.url:find("query=Attack%20on%20Titan", 1, true) ~= nil
                                        or c.url:find("query=", 1, true) ~= nil)
      H.ok("search URL type=series", c.url:find("type=series", 1, true) ~= nil)
      break
    end
  end
  H.ok("search made GET call", found)
end

---------------------------------------------------------------------------
-- (5) search_series: empty results returns nil
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_response = { status = "success", data = {} },
  }
  provider._jwt = "existing-jwt"
  provider.search_series("Nonexistent Show", function(series_id, series_name)
    H.eq("empty results returns nil id", series_id, nil)
  end)
end

---------------------------------------------------------------------------
-- (6) resolve_absolute: matches absoluteNumber in episodes
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_handler = function(url)
      if url:find("/episodes/", 1, true) then
        return default_episodes_page(0), 200
      end
      return default_search_response(), 200
    end,
  }
  provider._jwt = "existing-jwt"
  provider.resolve_absolute(12345, 7, function(result)
    H.ok("resolve returns result", result ~= nil)
    if result then
      H.eq("absolute ep 7 -> season 1", result.season, 1)
      H.eq("absolute ep 7 -> episode 7", result.episode, 7)
    end
  end)
end

---------------------------------------------------------------------------
-- (7) resolve_absolute: no match returns nil
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_handler = function(url)
      if url:find("/episodes/", 1, true) then
        return {
          status = "success",
          data = {
            episodes = {
              { absoluteNumber = 1, seasonNumber = 1, number = 1 },
            },
            links = {},
          },
        }, 200
      end
      return default_search_response(), 200
    end,
  }
  provider._jwt = "existing-jwt"
  provider.resolve_absolute(12345, 999, function(result)
    H.eq("no match returns nil", result, nil)
  end)
end

---------------------------------------------------------------------------
-- (8) resolve_absolute: multi-page pagination
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_handler = function(url)
      if url:find("/episodes/", 1, true) then
        local page = 0
        local page_match = url:match("page=(%d+)")
        if page_match then page = tonumber(page_match) end
        return default_episodes_page(page), 200
      end
      return default_search_response(), 200
    end,
  }
  provider._jwt = "existing-jwt"
  -- Ep 30 is in season 2 (page 1 of the TVDB response)
  provider.resolve_absolute(12345, 30, function(result)
    H.ok("pagination finds ep 30", result ~= nil)
    if result then
      H.eq("absolute ep 30 -> season 2", result.season, 2)
      H.eq("absolute ep 30 -> episode 5", result.episode, 5)
    end
  end)
end

---------------------------------------------------------------------------
-- (9) login + search + resolve full flow
---------------------------------------------------------------------------
do
  H.reset()
  provider._jwt = nil
  setup_provider {
    post_response = default_login_response(),
    get_handler = function(url)
      if url:find("/search?", 1, true) then
        return default_search_response(), 200
      elseif url:find("/episodes/", 1, true) then
        local page = 0
        local page_match = url:match("page=(%d+)")
        if page_match then page = tonumber(page_match) end
        return default_episodes_page(page), 200
      end
      return {}, 200
    end,
  }

  -- Full flow: login -> search -> resolve
  provider.login(function(login_ok)
    H.ok("step 1: login succeeds", login_ok)
    provider.search_series("Attack on Titan", function(series_id)
      H.eq("step 2: series found", series_id, 12345)
      provider.resolve_absolute(series_id, 12, function(result)
        H.ok("step 3: resolution succeeds", result ~= nil)
        if result then
          H.eq("full flow: ep 12 -> S1E12", result.season, 1)
          H.eq("full flow: ep 12 -> E12", result.episode, 12)
        end
      end)
    end)
  end)
end

---------------------------------------------------------------------------
-- (10) series caching: second search for same title skips HTTP
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_response = default_search_response(),
  }
  provider._jwt = "cached-jwt"
  provider._series_cache = {} -- reset
  captured = {}

  provider.search_series("Attack on Titan", function(id1)
    H.eq("first search finds series", id1, 12345)
    local first_count = call_count

    -- Second search for same title should use cache
    provider.search_series("Attack on Titan", function(id2)
      H.eq("cached search returns same id", id2, 12345)
      H.eq("no additional HTTP calls for cached search", call_count, first_count)
    end)
  end)
end

---------------------------------------------------------------------------
-- (11) JWT caching: second login skips HTTP
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  provider._jwt = "already-authed-jwt"
  captured = {}
  call_count = 0

  -- login() should skip if JWT is already set
  provider.login(function(success, token)
    H.ok("cached JWT login succeeds", success)
    H.eq("cached JWT returns existing token", token, "already-authed-jwt")
    H.eq("no HTTP calls for cached login", call_count, 0)
  end)
end

---------------------------------------------------------------------------
-- (12) configure with no deps doesn't crash
---------------------------------------------------------------------------
do
  H.reset()
  provider.configure(nil)
  provider.configure({})
  H.ok("configure with nil doesn't crash", true)
  H.ok("configure with empty table doesn't crash", true)
end

---------------------------------------------------------------------------
-- (13) resolve_absolute: first page match doesn't fetch page 2
---------------------------------------------------------------------------
do
  H.reset()
  local page_fetches = 0
  setup_provider {
    get_handler = function(url)
      if url:find("/episodes/", 1, true) then
        page_fetches = page_fetches + 1
        return default_episodes_page(0), 200
      end
      return default_search_response(), 200
    end,
  }
  provider._jwt = "jwt"
  -- Ep 5 is on page 0, should not fetch page 1
  provider.resolve_absolute(12345, 5, function(result)
    H.ok("finds ep 5 on first page", result ~= nil)
    H.eq("only fetched one page", page_fetches, 1)
  end)
end

---------------------------------------------------------------------------
-- (14) search_series: sends JWT in Authorization header
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    get_response = default_search_response(),
  }
  provider._jwt = "my-jwt-token"
  captured = {}
  provider.search_series("Test", function() end)
  local search_call = captured[1]
  H.ok("search call exists", search_call ~= nil)
  if search_call and search_call.opts and search_call.opts.headers then
    local found_jwt = false
    for _, h in ipairs(search_call.opts.headers) do
      if h:find("Bearer my-jwt-token", 1, true) then found_jwt = true end
    end
    H.ok("search sends JWT in Authorization header", found_jwt)
  end
end

---------------------------------------------------------------------------
-- (15) login: POST body contains apikey
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  provider._jwt = nil
  captured = {}
  provider.login(function() end)
  local post_call = captured[1]
  H.ok("login POST call exists", post_call ~= nil)
  if post_call and post_call.opts then
    H.ok("login POST has body with apikey",
         post_call.opts.body and post_call.opts.body:find("TEST_TVDB_KEY", 1, true) ~= nil)
  end
end
