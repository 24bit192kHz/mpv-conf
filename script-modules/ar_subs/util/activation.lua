-- ar_subs.util.activation: determine and apply the correct subtitle
-- activation method based on file location relative to the video.
--
-- Two paths:
--   1. BESIDE video (same dir, or CACHE_TO_MEDIA_DIR=1):
--      set slang="ara" and rescan_external_files so mpv discovers it natively.
--   2. CACHE path (different directory):
--      use sub-add with "select" flag to load it explicitly.

local M = {}
local zstd = require("ar_subs.util.zstd")

function M.is_beside_video(sub_file, video_path)
  if not sub_file or not video_path then return false end
  local sub_dir = sub_file:match("(.+)/[^/]+$") or ""
  local vid_dir = video_path:match("(.+)/[^/]+$") or ""
  return sub_dir ~= "" and sub_dir == vid_dir
end

local function copy_beside(sub_file, video_path)
  local vid_dir = video_path:match("(.+)/[^/]+$")
  if not vid_dir then return nil end
  local src = zstd.ensure(sub_file) or sub_file
  local name = (src:match("([^/]+)$") or "subtitle.srt"):gsub("%.zst$", "")
  local dest = vid_dir .. "/" .. name
  if src == dest then return dest end
  local inf = io.open(src, "rb")
  if not inf then return nil end
  local data = inf:read("*a"); inf:close()
  local outf = io.open(dest, "wb")
  if not outf then return nil end
  outf:write(data); outf:close()
  return dest
end

function M.activate(mp_ref, sub_file, video_path, cache_to_media_dir)
  local beside = M.is_beside_video(sub_file, video_path)
  if cache_to_media_dir and not beside then
    local copied = copy_beside(sub_file, video_path)
    if copied then
      sub_file = copied
      beside = true
    end
  end
  if beside then
    mp_ref.set_property("slang", "ara")
    mp_ref.commandv("rescan_external_files", "reselect")
  else
    local loadable = zstd.ensure(sub_file)
    if not loadable then return end
    -- Cache-path subs are archived (.zst) at rest; ensure() decompresses
    -- into the hot dir (in-process FFI, sub-millisecond). Beside-video
    -- files are always raw, so is_beside_video won't reach this with .zst.
    mp_ref.commandv("sub-add", loadable, "select", "Arabic", "ara")
  end
end

return M
