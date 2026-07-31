-- Spec: Immediate slang/rescan activation.
--
-- When a subtitle is downloaded, it should be activated via:
--   1. slang + rescan_external_files — when the file is beside the video
--      (CACHE_TO_MEDIA_DIR=1 or same directory).
--   2. sub-add with "select" — when the file lives in the cache directory.
--
-- This spec stubs mp to capture which activation path is taken.

local H = require "harness"

local activation = require "ar_subs.util.activation"

---------------------------------------------------------------------------
-- is_beside_video: pure directory comparison.
---------------------------------------------------------------------------
do
  H.reset()
  H.ok("same dir → beside",
       activation.is_beside_video("/video/movie.srt", "/video/movie.mkv"))
end

do
  H.reset()
  H.ok("different dir → not beside",
       not activation.is_beside_video("/cache/subs/movie.srt", "/video/movie.mkv"))
end

do
  H.reset()
  H.ok("nil sub_file → not beside",
       not activation.is_beside_video(nil, "/video/movie.mkv"))
end

do
  H.reset()
  H.ok("nil video_path → not beside",
       not activation.is_beside_video("/cache/movie.srt", nil))
end

do
  H.reset()
  H.ok("both nil → not beside",
       not activation.is_beside_video(nil, nil))
end

---------------------------------------------------------------------------
-- activate: beside video → slang + rescan_external_files.
---------------------------------------------------------------------------
do
  H.reset()
  local props = {}
  local calls = {}
  local mock_mp = {
    set_property = function(name, val)
      props[name] = val
      table.insert(calls, { kind = "set_property", name = name, value = val })
    end,
    commandv = function(...)
      table.insert(calls, { kind = "commandv", args = { ... } })
    end,
  }
  activation.activate(mock_mp, "/video/movie.srt", "/video/movie.mkv", false)

  H.eq("slang set to ara", props["slang"], "ara")

  local rescan_found = false
  for _, c in ipairs(calls) do
    if c.kind == "commandv" and c.args[1] == "rescan_external_files" then
      rescan_found = true
      H.eq("rescan reselect", c.args[2], "reselect")
    end
  end
  H.ok("rescan_external_files called", rescan_found)

  local sub_add_found = false
  for _, c in ipairs(calls) do
    if c.kind == "commandv" and c.args[1] == "sub-add" then
      sub_add_found = true
    end
  end
  H.ok("sub-add NOT called when beside", not sub_add_found)
end

---------------------------------------------------------------------------
-- activate: CACHE_TO_MEDIA_DIR=1 → slang + rescan (even if not beside).
---------------------------------------------------------------------------
do
  H.reset()
  local props = {}
  local calls = {}
  local mock_mp = {
    set_property = function(name, val)
      props[name] = val
      table.insert(calls, { kind = "set_property", name = name, value = val })
    end,
    commandv = function(...)
      table.insert(calls, { kind = "commandv", args = { ... } })
    end,
  }
  activation.activate(mock_mp, "/cache/subs/movie.srt", "/video/movie.mkv", true)

  H.eq("slang set to ara (cache_to_media)", props["slang"], "ara")

  local rescan_found = false
  for _, c in ipairs(calls) do
    if c.kind == "commandv" and c.args[1] == "rescan_external_files" then
      rescan_found = true
    end
  end
  H.ok("rescan_external_files called (cache_to_media)", rescan_found)
end

---------------------------------------------------------------------------
-- activate: in cache (not beside, not cache_to_media) → sub-add select.
---------------------------------------------------------------------------
do
  H.reset()
  local calls = {}
  local props = {}
  local mock_mp = {
    set_property = function(name, val)
      props[name] = val
    end,
    commandv = function(...)
      table.insert(calls, { kind = "commandv", args = { ... } })
    end,
  }
  activation.activate(mock_mp, "/cache/subs/movie.srt", "/video/movie.mkv", false)

  local sub_add_found = false
  for _, c in ipairs(calls) do
    if c.kind == "commandv" and c.args[1] == "sub-add" then
      sub_add_found = true
      H.eq("sub-add file arg", c.args[2], "/cache/subs/movie.srt")
      H.eq("sub-add select flag", c.args[3], "select")
      H.eq("sub-add label", c.args[4], "Arabic")
      H.eq("sub-add lang", c.args[5], "ara")
    end
  end
  H.ok("sub-add called for cache path", sub_add_found)

  local rescan_found = false
  for _, c in ipairs(calls) do
    if c.kind == "commandv" and c.args[1] == "rescan_external_files" then
      rescan_found = true
    end
  end
  H.ok("rescan NOT called for cache path", not rescan_found)
  H.ok("slang NOT set for cache path", props["slang"] == nil)
end
