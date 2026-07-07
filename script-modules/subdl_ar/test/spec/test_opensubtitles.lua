-- Spec: subdl_ar.providers.opensubtitles (hash-based fallback)
--
-- Tests:
--   1. configure() accepts api_key, app_name, http_get_json, http_get_raw
--   2. search_by_hash: builds correct URL with hash + size + languages=ar
--   3. search_by_hash: skips files < 128KB
--   4. search_by_hash: extracts file_id from data[].attributes.files[]
--   5. download_file: two-step flow — POST /download, then GET link
--   6. download_file: returns raw SRT body
--   7. search_by_hash: returns empty when no results
--   8. search_by_hash: returns empty when API returns error

local H = require "harness"

package.loaded["subdl_ar.providers.opensubtitles"] = nil
local provider = require "subdl_ar.providers.opensubtitles"

---------------------------------------------------------------------------
-- Helper: capture HTTP calls
---------------------------------------------------------------------------
local captured = {}

local function setup_provider(overrides)
  captured = {}
  provider.configure {
    api_key = "TEST_OPENSUBS_KEY",
    app_name = "TestApp v1.0",
    http_get_json_async = function(url, opts, on_done)
      captured[#captured + 1] = { kind = "json_async", url = url, opts = opts }
      local canned = overrides and overrides.json_response or { data = {} }
      if on_done then on_done(true, canned, 200) end
      return 999
    end,
    http_get_raw_async = function(url, opts, on_done)
      captured[#captured + 1] = { kind = "raw_async", url = url, opts = opts }
      local body = overrides and overrides.raw_body or "1\n00:00:01,000 --> 00:00:02,000\nhello\n"
      if on_done then on_done(true, { body = body, http_code = 200 }) end
      return 888
    end,
  }
end

---------------------------------------------------------------------------
-- (1) configure accepts keys
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  H.eq("api_key stored", provider._cfg.api_key, "TEST_OPENSUBS_KEY")
  H.eq("app_name stored", provider._cfg.app_name, "TestApp v1.0")
end

---------------------------------------------------------------------------
-- (2) search_by_hash: builds correct URL with hash + size + languages=ar
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  captured = {}
  provider.search_by_hash("8e245d9679d31e12", 12909756, function(results)
    -- Check URL was built correctly
    local json_call = captured[1]
    H.ok("search issued an http call", json_call ~= nil)
    H.ok("URL contains moviehash=8e245d9679d31e12",
         json_call.url:find("moviehash=8e245d9679d31e12", 1, true) ~= nil)
    H.ok("URL contains moviebytesize=12909756",
         json_call.url:find("moviebytesize=12909756", 1, true) ~= nil)
    H.ok("URL contains languages=ar",
         json_call.url:find("languages=ar", 1, true) ~= nil)
    H.ok("URL hits api.opensubtitles.com",
         json_call.url:find("api.opensubtitles.com", 1, true) ~= nil)
    H.ok("URL contains /api/v1/subtitles",
         json_call.url:find("/api/v1/subtitles", 1, true) ~= nil)
  end)
end

---------------------------------------------------------------------------
-- (3) search_by_hash: sends Api-Key and User-Agent headers
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  captured = {}
  provider.search_by_hash("8e245d9679d31e12", 12909756, function(results)
    local json_call = captured[1]
    local headers = json_call.opts and json_call.opts.headers or {}
    local has_api_key = false
    local has_user_agent = false
    for _, h in ipairs(headers) do
      if h:find("Api-Key: TEST_OPENSUBS_KEY", 1, true) then has_api_key = true end
      if h:find("User-Agent: TestApp v1.0", 1, true) then has_user_agent = true end
    end
    H.ok("sends Api-Key header", has_api_key)
    H.ok("sends User-Agent header", has_user_agent)
  end)
end

---------------------------------------------------------------------------
-- (4) search_by_hash: extracts file_id from nested response
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    json_response = {
      data = {
        {
          id = 111111,
          attributes = {
            files = {
              { file_id = 222222 },
              { file_id = 333333 },
            },
          },
        },
      },
    },
  }
  captured = {}
  provider.search_by_hash("aabbccdd11223344", 50000000, function(results)
    H.ok("results is a table", type(results) == "table")
    H.ok("results has entries", #results > 0)
    if #results > 0 then
      H.eq("first result file_id", results[1].file_id, 222222)
    end
    if #results > 1 then
      H.eq("second result file_id", results[2].file_id, 333333)
    end
  end)
end

---------------------------------------------------------------------------
-- (5) download_file: two-step flow
---------------------------------------------------------------------------
do
  H.reset()
  local download_calls = {}
  provider.configure {
    api_key = "DL_KEY",
    app_name = "TestApp",
    http_get_json_async = function(url, opts, on_done)
      download_calls[#download_calls + 1] = { kind = "json", url = url }
      -- Step 1: /download returns a link
      if on_done then
        on_done(true, { link = "https://dl.opensubtitles.org/srt/abc123" }, 200)
      end
      return 101
    end,
    http_get_raw_async = function(url, opts, on_done)
      download_calls[#download_calls + 1] = { kind = "raw", url = url }
      -- Step 2: fetch the actual SRT
      if on_done then
        on_done(true, { body = "1\n00:00:01,000 --> 00:00:02,000\nSub text\n", http_code = 200 })
      end
      return 102
    end,
  }
  captured = {}
  download_calls = {}
  provider.download_file(222222, function(body, code)
    H.eq("download_file returns SRT body",
         body, "1\n00:00:01,000 --> 00:00:02,000\nSub text\n")
    H.eq("download_file returns http code 200", code, 200)
    -- Verify two-step: first json call (POST /download), then raw call (GET link)
    local json_step = nil
    local raw_step = nil
    for _, c in ipairs(download_calls) do
      if c.kind == "json" and c.url:find("/download", 1, true) then json_step = c end
      if c.kind == "raw" then raw_step = c end
    end
    H.ok("download_file made /download JSON call", json_step ~= nil)
    H.ok("download_file fetched link via raw call", raw_step ~= nil)
    H.ok("download link URL is correct",
         raw_step.url == "https://dl.opensubtitles.org/srt/abc123")
  end)
end

---------------------------------------------------------------------------
-- (5b) download_file: sends Api-Key in download step
---------------------------------------------------------------------------
do
  H.reset()
  local dl_headers = {}
  provider.configure {
    api_key = "DL_KEY2",
    app_name = "TestApp",
    http_get_json_async = function(url, opts, on_done)
      dl_headers = opts and opts.headers or {}
      if on_done then on_done(true, { link = "https://dl.example.com/srt" }, 200) end
      return 1
    end,
    http_get_raw_async = function(url, opts, on_done)
      if on_done then on_done(true, { body = "SRT", http_code = 200 }) end
      return 2
    end,
  }
  provider.download_file(99999, function() end)
  local has_key = false
  for _, h in ipairs(dl_headers) do
    if h:find("Api-Key: DL_KEY2", 1, true) then has_key = true end
  end
  H.ok("download step sends Api-Key header", has_key)
end

---------------------------------------------------------------------------
-- (6) search_by_hash: empty when API returns no data
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    json_response = { data = {} },
  }
  provider.search_by_hash("0000000000000000", 1000000, function(results)
    H.eq("empty data returns empty results", #results, 0)
  end)
end

---------------------------------------------------------------------------
-- (7) search_by_hash: empty when API returns nil data
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    json_response = {},
  }
  provider.search_by_hash("0000000000000000", 1000000, function(results)
    H.eq("nil data returns empty results", #results, 0)
  end)
end

---------------------------------------------------------------------------
-- (8) download_file: nil file_id returns nil gracefully
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider()
  provider.download_file(nil, function(body, code)
    H.eq("nil file_id body", body, nil)
    H.eq("nil file_id code", code, nil)
  end)
end

---------------------------------------------------------------------------
-- (9) search_by_hash: empty when http call fails
---------------------------------------------------------------------------
do
  H.reset()
  provider.configure {
    api_key = "KEY",
    app_name = "App",
    http_get_json_async = function(url, opts, on_done)
      if on_done then on_done(false, nil, 0) end
      return nil
    end,
    http_get_raw_async = function(url, opts, on_done)
      if on_done then on_done(false, { body = nil, http_code = 0 }) end
      return nil
    end,
  }
  provider.search_by_hash("aabbccdd11223344", 50000000, function(results)
    H.eq("failed http returns empty", #results, 0)
  end)
end

---------------------------------------------------------------------------
-- (10) Multiple subtitle entries with multiple files each: flattens correctly
---------------------------------------------------------------------------
do
  H.reset()
  setup_provider {
    json_response = {
      data = {
        {
          id = 1,
          attributes = {
            files = {
              { file_id = 101 },
              { file_id = 102 },
            },
          },
        },
        {
          id = 2,
          attributes = {
            files = {
              { file_id = 201 },
            },
          },
        },
      },
    },
  }
  provider.search_by_hash("aabbccdd11223344", 50000000, function(results)
    H.eq("flattened 3 file_ids from 2 entries", #results, 3)
    if #results == 3 then
      H.eq("first file_id", results[1].file_id, 101)
      H.eq("second file_id", results[2].file_id, 102)
      H.eq("third file_id", results[3].file_id, 201)
    end
  end)
end
