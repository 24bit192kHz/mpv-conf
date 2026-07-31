-- ar_subs.util.subsource: SubSource.net API client (https://subsource.net).
-- Preferred ONLINE source; SubDL is the last-resort fallback.
--
-- HTTP contract (v1):
--   GET /movies/search?searchType=text&q=<title>
--       -> {success, data: [{movieId, title, type, releaseYear, imdbId,
--                             season, subtitleCount, ...}]}
--   GET /subtitles?movieId=N&season=S&episode=E&language=arabic&limit=N
--       -> {success, data: [{subtitleId, movieId, language,
--                            releaseInfo: [..], files, downloads, ...}],
--           pagination: {total, ...}}
--   GET /subtitles/{subtitleId}/download
--       -> raw zip bytes (content-type: application/zip)
--
-- Auth: X-API-Key header (or api_key query param).
-- Rate limits: 60/min, 1800/h, 7200/day -- headers echo the budget.
--
-- Sync curl subprocesses, same pattern as the offline subtitle_api client.

local utils = require("mp.utils")

local M = {}

local BASE = "https://api.subsource.net/api/v1"

function M.init(opts)
    M._mp = opts.mp
    M._key = (opts.api_key or ""):gsub("%s+", "")
    M._timeout = opts.timeout or 10
    M._disabled = false
end

function M.available()
    return M._mp ~= nil and M._key ~= "" and not M._disabled
end

local function curl_json(url)
    local out = os.tmpname() .. ".json"
    local ret = M._mp.command_native({
        name = "subprocess", playback_only = false,
        capture_stdout = false, capture_stderr = true,
        args = { "curl", "--fail", "--silent", "--show-error",
                 "--max-time", tostring(M._timeout),
                 "-H", "X-API-Key: " .. M._key,
                 "-o", out, url },
    })
    if ret == nil or ret.status ~= 0 then
        os.remove(out)
        return nil, ret and ret.status or -1
    end
    local f = io.open(out, "r")
    if not f then return nil, -2 end
    local raw = f:read("*a"); f:close(); os.remove(out)
    local data = utils.parse_json(raw)
    if type(data) ~= "table" then return nil, -3 end
    if data.success == false or data.error then
        return nil, data.error or "api error"
    end
    return data
end

local function urlenc(s)
    return (tostring(s):gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- Search a title; returns a list of {movieId, title, type, releaseYear,
-- season, subtitleCount} or nil.
function M.search_show(title)
    if not M.available() then return nil end
    local d, err = curl_json(BASE .. "/movies/search?searchType=text&q=" .. urlenc(title))
    if not d then
        if err == 401 or err == 403 then M._disabled = true end
        return nil, err
    end
    return type(d.data) == "table" and d.data or {}
end

-- List Arabic subtitle packs for one episode (or movie). Returns the data
-- array (possibly empty) or nil.
function M.list_subs(movie_id, season, episode)
    if not M.available() then return nil end
    local url = string.format("%s/subtitles?movieId=%d&language=arabic&limit=20",
        BASE, movie_id)
    if season then url = url .. "&season=" .. tostring(season) end
    if episode then url = url .. "&episode=" .. tostring(episode) end
    local d, err = curl_json(url)
    if not d then
        if err == 401 or err == 403 then M._disabled = true end
        return nil, err
    end
    return type(d.data) == "table" and d.data or {}
end

-- Download a subtitle pack to a temp .zip; returns the path or nil.
function M.download(subtitle_id)
    if not M.available() then return nil end
    local out = (os.getenv("TMPDIR") or "/tmp") ..
        "/subsource_" .. tostring(subtitle_id) .. "_" .. tostring(os.time()) .. ".zip"
    local ret = M._mp.command_native({
        name = "subprocess", playback_only = false,
        capture_stdout = false, capture_stderr = true,
        args = { "curl", "--fail", "--silent", "--show-error", "-L",
                 "--max-time", "60",
                 "-H", "X-API-Key: " .. M._key,
                 "-o", out,
                 BASE .. "/subtitles/" .. tostring(subtitle_id) .. "/download" },
    })
    if ret == nil or ret.status ~= 0 then
        os.remove(out)
        return nil
    end
    return out
end

return M
