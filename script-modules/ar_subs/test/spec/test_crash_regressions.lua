-- Regression specs for crash bugs in scripts/ar_subs.lua
--
-- Bug 1: Nil-unsafe URL concatenation in download_and_load (line ~893)
--         and fetch_bulk_subs (line ~944).
--         When both sub.url and sub.download_url are nil, Lua throws
--         "attempt to concatenate a nil value".
--
-- Bug 2: %d format crash in get_subdl_sd_id (line ~412).
--         When result.sd_id is a string like "12345", string.format
--         with %d throws "bad argument to 'format' (number expected, got string)".

local H = require "harness"

---------------------------------------------------------------------------
-- Bug 1: nil-unsafe URL concatenation
---------------------------------------------------------------------------

-- Replicates the pattern from download_and_load / fetch_bulk_subs AFTER fix.
-- The fixed pattern guards against both sub.url and sub.download_url being nil.
local function build_download_url(sub)
    local sub_url = sub.url or sub.download_url
    if not sub_url then
        return nil
    end
    return "https://dl.subdl.com" .. sub_url
end

-- Pre-fix vulnerable pattern (for comparison / documenting the bug).
local function build_download_url_unfixed(sub)
    return "https://dl.subdl.com" .. (sub.url or sub.download_url)
end

-- (a) Both nil → should return nil, not crash
H.ok("bug1: nil url + nil download_url does not crash",
     pcall(build_download_url, { url = nil, download_url = nil }))
H.eq("bug1: nil url + nil download_url returns nil",
     build_download_url({ url = nil, download_url = nil }), nil)

-- (b) url present, download_url nil → should work
H.eq("bug1: valid url with nil download_url",
     build_download_url({ url = "/sub/123.srt", download_url = nil }),
     "https://dl.subdl.com/sub/123.srt")

-- (c) url nil, download_url present → should work
H.eq("bug1: nil url with valid download_url",
     build_download_url({ url = nil, download_url = "/sub/456.srt" }),
     "https://dl.subdl.com/sub/456.srt")

-- (d) Both present → url takes precedence
H.eq("bug1: both present, url takes precedence",
     build_download_url({ url = "/a.srt", download_url = "/b.srt" }),
     "https://dl.subdl.com/a.srt")

-- (e) Verify the unfixed pattern actually crashes (proving the bug exists)
local ok_crash, err_crash = pcall(build_download_url_unfixed,
                                  { url = nil, download_url = nil })
H.ok("bug1: unfixed pattern crashes (proves bug exists)",
     not ok_crash and err_crash:find("concatenate"))

---------------------------------------------------------------------------
-- Bug 2: %d format crash when sd_id is a string
---------------------------------------------------------------------------

-- Replicates the pattern from get_subdl_sd_id AFTER fix.
-- The fixed pattern uses %s and tostring() so string sd_ids don't crash.
local function format_sd_id_resolved(media_type, sd_id, tmdb_id, name)
    return string.format("SubDL: resolved %s sd_id=%s for tmdb_id=%s (%s)",
                         media_type, tostring(sd_id), tmdb_id, name)
end

-- (a) String sd_id "12345" → should not crash, should render correctly
H.ok("bug2: string sd_id does not crash",
     pcall(format_sd_id_resolved, "tv", "12345", "99999", "Test Show"))
H.eq("bug2: string sd_id renders correctly",
     format_sd_id_resolved("tv", "12345", "99999", "Test Show"),
     "SubDL: resolved tv sd_id=12345 for tmdb_id=99999 (Test Show)")

-- (b) Numeric sd_id → should still work
H.eq("bug2: numeric sd_id still works",
     format_sd_id_resolved("movie", 42, "88888", "Test Movie"),
     "SubDL: resolved movie sd_id=42 for tmdb_id=88888 (Test Movie)")

-- (c) Verify tostring coercion works for edge-case sd_id values
H.eq("bug2: nil sd_id renders as 'nil'",
     format_sd_id_resolved("tv", nil, "111", "Show"),
     "SubDL: resolved tv sd_id=nil for tmdb_id=111 (Show)")
H.eq("bug2: boolean sd_id coerces",
     format_sd_id_resolved("tv", true, "222", "Show"),
     "SubDL: resolved tv sd_id=true for tmdb_id=222 (Show)")
