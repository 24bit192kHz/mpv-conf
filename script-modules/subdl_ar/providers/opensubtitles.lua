-- subdl_ar.providers.opensubtitles: OpenSubtitles REST API hash-based fallback.
--
-- Activated only when SubDL returns empty results. Uses OSHash to query
-- the OpenSubtitles API for Arabic subtitles matched by file hash.
--
-- Two-phase download:
--   1. POST /api/v1/download { file_id } → get a download link
--   2. GET <link> → raw SRT body
--
-- Dep injection via configure() for testability.

local M = {}

M._cfg = {
  api_base = "https://api.opensubtitles.com/api/v1",
  api_key  = "",
  app_name = "",
}

M._http = {
  get_json_async = nil,
  get_raw_async  = nil,
}

local function log(level, msg)
  local ok, mp = pcall(require, "mp")
  if ok and mp and mp.msg and mp.msg[level] then
    mp.msg[level](msg)
  end
end

function M.configure(deps)
  if type(deps) ~= "table" then return end
  for k, v in pairs(deps) do
    if k == "http_get_json_async" then M._http.get_json_async = v
    elseif k == "http_get_raw_async" then M._http.get_raw_async = v
    else M._cfg[k] = v end
  end
end

local function search_headers()
  return {
    "Api-Key: " .. M._cfg.api_key,
    "User-Agent: " .. M._cfg.app_name,
  }
end

local function download_headers()
  return {
    "Api-Key: " .. M._cfg.api_key,
    "User-Agent: " .. M._cfg.app_name,
    "Content-Type: application/json",
  }
end

local function extract_file_ids(json)
  local results = {}
  if not json or not json.data then return results end
  for _, entry in ipairs(json.data) do
    local attrs = entry.attributes
    if attrs and attrs.files then
      for _, file in ipairs(attrs.files) do
        if file.file_id then
          results[#results + 1] = { file_id = file.file_id }
        end
      end
    end
  end
  return results
end

function M.search_by_hash(hash, file_size, on_done)
  if not M._http.get_json_async then
    if on_done then on_done({}) end
    return nil
  end
  local url = string.format("%s/subtitles?moviehash=%s&moviebytesize=%d&languages=ar",
                            M._cfg.api_base, hash, file_size)
  return M._http.get_json_async(url, { headers = search_headers() }, function(success, json, http_code)
    if not success or not json then
      log("warn", "OpenSubtitles: search request failed")
      if on_done then on_done({}) end
      return
    end
    local results = extract_file_ids(json)
    log("info", string.format("OpenSubtitles: found %d file(s) for hash %s", #results, hash))
    if on_done then on_done(results) end
  end)
end

function M.download_file(file_id, on_done)
  if not file_id then
    if on_done then on_done(nil, nil) end
    return nil
  end
  if not M._http.get_json_async or not M._http.get_raw_async then
    if on_done then on_done(nil, nil) end
    return nil
  end

  local dl_url = M._cfg.api_base .. "/download"
  local body_str = string.format('{"file_id":%d}', file_id)

  return M._http.get_json_async(dl_url, {
    headers = download_headers(),
    post_body = body_str,
  }, function(success, json, http_code)
    if not success or not json or not json.link then
      log("warn", string.format("OpenSubtitles: download link request failed for file_id=%d", file_id))
      if on_done then on_done(nil, nil) end
      return
    end
    local link = json.link
    log("info", "OpenSubtitles: fetching SRT from " .. link:sub(1, 60) .. "...")

    return M._http.get_raw_async(link, { headers = {} }, function(ok2, result)
      if not ok2 or not result or not result.body then
        log("warn", "OpenSubtitles: failed to fetch SRT body")
        if on_done then on_done(nil, nil) end
        return
      end
      if on_done then on_done(result.body, result.http_code) end
    end)
  end)
end

return M
