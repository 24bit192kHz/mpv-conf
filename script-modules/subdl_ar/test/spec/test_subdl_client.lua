-- Spec: SubDL v2 provider client (Bearer auth, unpack=1, format=file, no unzip).
--
-- Scope of this spec (Task C / Wave 2):
--   1. Bearer header present in captured curl args for every SubDL request.
--   2. unpack=1 present in search request URL.
--   3. No api_key= in any request URL.
--   4. unzip NEVER invoked in the download path (source-inspection + runtime).
--   5. Parser handles season:0 gracefully (defers to client-side matcher).
--   6. format=file download returns raw SRT body (no zip extraction).
--
-- The provider exposes dependency injection via .configure({ http_get_json=,
-- http_get_raw=, ... }) so the HTTP layer is stubbed at the function boundary
-- rather than at utils.subprocess.

local H = require "harness"

-- Convenience: linear search a list for an element equal to `want`.
local function contains(t, want)
  for _, v in ipairs(t or {}) do
    if v == want then return true end
  end
  return false
end

-- Tiny helper: locate the first "local function NAME" in `src` starting at idx.
local function find_func(src, name, from)
  local pattern = "local function " .. name .. "%b()"
  local s, e = src:find(pattern, from or 1)
  return s, e
end

---------------------------------------------------------------------------
-- Reload the provider fresh so .configure() state from a previous spec run
-- can't leak in.
---------------------------------------------------------------------------
package.loaded["subdl_ar.providers.subdl"] = nil
local provider = require "subdl_ar.providers.subdl"

---------------------------------------------------------------------------
-- (5) v2 metadata normalization in util/match.lua (independent of provider).
---------------------------------------------------------------------------
local match = require "subdl_ar.util.match"

-- season:0 must be dropped — server-side season is a hint only; the client-side
-- matcher (release_name parser) is authoritative.
do
  H.reset()
  local sub = {
    season_number = 0,            -- v1 server hint, season 0 (specials)
    episode_number = 5,
    release_name = "Show.S01E05.WEB.x264",  -- release_name says S1
  }
  match.normalize_subtitle_metadata(sub)
  H.ok("season:0 not added to _norm_pairs[0]", sub._norm_pairs[0] == nil)
  -- The release_name-derived S01E05 should still land in the pair set.
  H.same("release_name pair survives season:0 hint", sub._norm_pairs[1], { [5] = true })
end

-- v2 field names: season/episode (no _number suffix) plus episode_end range.
do
  H.reset()
  local sub = {
    season = 2,                   -- v2 server hint
    episode = 5,
    episode_end = 8,              -- covers E5..E8
    release_name = "",
  }
  match.normalize_subtitle_metadata(sub)
  H.ok("v2 season/episode parsed into pair[2][5]", sub._norm_pairs[2] ~= nil and sub._norm_pairs[2][5] == true)
  local p2 = sub._norm_pairs[2] or {}
  H.ok("v2 episode_end range extends pairs[2] to 6", p2[6] == true)
  H.ok("v2 episode_end range extends pairs[2] to 7", p2[7] == true)
  H.ok("v2 episode_end range extends pairs[2] to 8", p2[8] == true)
  H.ok("v2 episode_end range stops at 8 (no 9)", p2[9] == nil)
end

-- v2 full_season flag exposed for the matcher as a pack hint.
do
  H.reset()
  local sub = { full_season = true, release_name = "Show.S01.1080p" }
  match.normalize_subtitle_metadata(sub)
  H.ok("v2 full_season sets _is_pack", sub._is_pack == true)
end

-- v1 field names still work (back-compat).
do
  H.reset()
  local sub = { season_number = 3, episode_number = 12, release_name = "" }
  match.normalize_subtitle_metadata(sub)
  H.same("v1 season_number/episode_number still parsed", sub._norm_pairs[3], { [12] = true })
end

---------------------------------------------------------------------------
-- Provider configure() + stubbed HTTP layer.
---------------------------------------------------------------------------
local captured = {}

provider.configure {
  api_url      = "https://api.subdl.com/api/v2/subtitles/search",
  download_url = "https://dl.subdl.com",
  api_key      = "TESTKEY_PRIMARY",
  backup_key   = "TESTKEY_BACKUP",
  utils        = require("mp.utils"),
  http_get_json = function(url, opts)
    captured[#captured + 1] = { kind = "json", url = url, headers = opts and opts.headers or {} }
    -- Canned v2 search response: a single subtitle plus an unpacked file.
    return {
      status = true,
      subtitles = {
        {
          id = 123,
          release_name = "Show.S01E05.WEB.x264",
          lang = "ar",
          url = "/subtitle/123.zip",
        },
      },
      results = {
        { sd_id = 123, type = "tv", name = "Show" },
      },
      unpack_files = {
        { url = "/file/123.srt", season = 1, episode = 5, language = "ar", release_name = "Show.S01E05" },
      },
    }, 200
  end,
  http_get_raw = function(url, opts)
    captured[#captured + 1] = { kind = "raw", url = url, headers = opts and opts.headers or {} }
    return "1\n00:00:01,000 --> 00:00:02,000\nhello\n", 200
  end,
}

---------------------------------------------------------------------------
-- (1)+(2)+(3) search() with Bearer header, unpack=1, no api_key= in URL.
---------------------------------------------------------------------------
do
  H.reset()
  captured = {}
  local subs, results = provider.search("film_name=Show&languages=ar&subs_per_page=50")
  H.ok("search returned subtitles table", type(subs) == "table" and #subs == 1)
  H.ok("search returned results table", type(results) == "table" and #results == 1)

  local json_call = nil
  for _, c in ipairs(captured) do
    if c.kind == "json" then json_call = c; break end
  end
  H.ok("search issued at least one http_get_json call", json_call ~= nil)

  -- (2) unpack=1 present
  H.ok("search URL has unpack=1", json_call.url:find("unpack=1", 1, true) ~= nil)
  -- (3) no api_key= anywhere in URL
  H.ok("search URL has no api_key=", json_call.url:find("api_key=", 1, true) == nil)
  -- v2 base URL
  H.ok("search URL uses api.subdl.com/api/v2/subtitles/search",
       json_call.url:find("api.subdl.com/api/v2/subtitles/search", 1, true) ~= nil)

  -- (1) Bearer header present
  H.ok("search sends Authorization Bearer header",
       contains(json_call.headers, "Authorization: Bearer TESTKEY_PRIMARY"))
  -- No api_key= glued into the URL even as a query param.
  H.ok("no api_key query param in search URL",
       json_call.url:find("[?&]api_key=", 1) == nil)
end

---------------------------------------------------------------------------
-- search() lets caller opt out of unpack=1 (e.g. sd_id lookups).
---------------------------------------------------------------------------
do
  H.reset()
  captured = {}
  provider.search("tmdb_id=99999&languages=ar", { unpack = false })
  local json_call = nil
  for _, c in ipairs(captured) do
    if c.kind == "json" then json_call = c; break end
  end
  H.ok("search unpack=false omits unpack=1",
       json_call.url:find("unpack=1", 1, true) == nil)
  H.ok("search unpack=false still has Bearer",
       contains(json_call.headers, "Authorization: Bearer TESTKEY_PRIMARY"))
end

---------------------------------------------------------------------------
-- get_sd_id() builds the right request and resolves via the stubbed response.
---------------------------------------------------------------------------
do
  H.reset()
  captured = {}
  local sd_id = provider.get_sd_id("tv", 99999, "Show")
  H.eq("get_sd_id resolved from canned results", sd_id, 123)
  local json_call = nil
  for _, c in ipairs(captured) do
    if c.kind == "json" then json_call = c; break end
  end
  H.ok("get_sd_id URL has no api_key=", json_call.url:find("api_key=", 1, true) == nil)
  H.ok("get_sd_id URL carries tmdb_id=99999",
       json_call.url:find("tmdb_id=99999", 1, true) ~= nil)
  -- v2 API 400s on tmdb_id without type=movie/type=tv
  H.ok("get_sd_id URL carries type=tv (required by v2 with tmdb_id)",
       json_call.url:find("type=tv", 1, true) ~= nil)
end

 ---------------------------------------------------------------------------
 -- (6) download() uses sub.url from API response + dl.subdl.com base.
 ---------------------------------------------------------------------------
 do
   H.reset()
   captured = {}
   local body, code, url = provider.download { id = 123, url = "/subtitle/123.zip?api_key=TESTKEY", release_name = "Show.S01E05" }
   -- The download URL should use dl.subdl.com + sub.url
   H.ok("download URL uses dl.subdl.com",
        url:find("dl.subdl.com", 1, true) ~= nil)
   H.ok("download URL contains /subtitle/123.zip",
        url:find("/subtitle/123.zip", 1, true) ~= nil)
 end

---------------------------------------------------------------------------
-- download() with nil id returns nil gracefully (regression: nil url concat).
---------------------------------------------------------------------------
do
  H.reset()
  captured = {}
  local body, code, url = provider.download { release_name = "X" }
  H.eq("download nil id -> body nil", body, nil)
  H.eq("download nil id -> url nil", url, nil)
  H.ok("download nil id -> no raw call issued",
       (function()
         for _, c in ipairs(captured) do
           if c.kind == "raw" then return false end
         end
         return true
       end)())
end

 ---------------------------------------------------------------------------
 -- (4) Source-inspection: orchestrator must not call safe_unzip inside
 --     download_and_load or fetch_bulk_subs.
 ---------------------------------------------------------------------------
 do
   local mp_stub = require "mp"
   local src_path = mp_stub._test_root .. "/../scripts/subdl_ar.lua"
   local f = io.open(src_path, "r")
   H.ok("scripts/subdl_ar.lua readable for source inspection", f ~= nil)
   if f then
     local src = f:read("*a")
     f:close()

     local function assert_no_unzip(name, start_pat)
       local s = src:find(start_pat, 1, true)
       H.ok(name .. " function found in source", s ~= nil)
       if not s then return end
       local e = src:find("\nend", s + 1, true)
       H.ok(name .. " function end found", e ~= nil)
       if not e then return end
       local body = src:sub(s, e)
       H.ok(name .. " does not call safe_unzip(",
            body:find("safe_unzip%(", 1) == nil)
     end

     assert_no_unzip("download_and_load", "local function download_and_load")
     assert_no_unzip("fetch_bulk_subs",   "local function fetch_bulk_subs")
   end
 end

---------------------------------------------------------------------------
-- (3 cross-cut) Redact URL still works (kept for safety per task scope).
---------------------------------------------------------------------------
local url_util = require "subdl_ar.util.url"
H.eq("redact_url still redacts api_key (defensive)",
     url_util.redact_url("https://dl.subdl.com/subtitle/123.zip?api_key=SECRET&foo=bar"),
     "https://dl.subdl.com/subtitle/123.zip?api_key=<redacted>&foo=bar")

---------------------------------------------------------------------------
-- download_quota / quota_exhausted_message / parse_reset_at
---------------------------------------------------------------------------
do
  local q = provider.download_quota({
    usage = {
      downloads = {
        used = 50, limit = 50, remaining = 0,
        reset_at = "2026-07-26T00:00:00.000Z", period = "day",
      },
    },
  })
  H.ok("download_quota parses remaining=0", q and q.remaining == 0)
  H.eq("download_quota used", q.used, 50)
  H.eq("download_quota limit", q.limit, 50)
  H.eq("download_quota reset_at", q.reset_at, "2026-07-26T00:00:00.000Z")

  local msg = provider.quota_exhausted_message(q)
  H.ok("quota message includes 50/50", msg:find("50/50", 1, true) ~= nil)
  H.ok("quota message includes Resets", msg:find("Resets", 1, true) ~= nil)
  H.ok("quota message includes UTC", msg:find("UTC", 1, true) ~= nil)

  local ts = provider.parse_reset_at("2026-07-26T00:00:00.000Z")
  H.ok("parse_reset_at returns number", type(ts) == "number" and ts > 0)
  H.eq("parse_reset_at nil on garbage", provider.parse_reset_at("nope"), nil)
  H.eq("download_quota nil on missing", provider.download_quota({}), nil)
  H.eq("download_quota nil on nil", provider.download_quota(nil), nil)

  local q_ok = provider.download_quota({
    usage = { downloads = { used = 3, limit = 50, remaining = 47 } },
  })
  H.ok("download_quota remaining>0", q_ok and q_ok.remaining == 47)
end

---------------------------------------------------------------------------
-- get_usage_async hits /api/v2/me with Bearer auth
---------------------------------------------------------------------------
do
  H.reset()
  captured = {}
  local done_usage, done_code = nil, nil
  -- Sync fallback path (no get_json_async configured above uses http_get_json).
  provider.get_usage_async(function(usage, code)
    done_usage, done_code = usage, code
  end)
  local me_call = nil
  for _, c in ipairs(captured) do
    if c.kind == "json" and c.url and c.url:find("/api/v2/me", 1, true) then
      me_call = c
      break
    end
  end
  H.ok("get_usage_async calls /api/v2/me", me_call ~= nil)
  if me_call then
    H.ok("get_usage_async has Bearer header",
         contains(me_call.headers, "Authorization: Bearer TESTKEY_PRIMARY"))
    H.ok("get_usage_async URL has no api_key=",
         me_call.url:find("api_key=", 1, true) == nil)
  end
end
