-- subdl_ar.util.activation: determine and apply the correct subtitle
-- activation method based on file location relative to the video.
--
-- Two paths:
--   1. BESIDE video (same dir, or CACHE_TO_MEDIA_DIR=1):
--      set slang="ara" and rescan_external_files so mpv discovers it natively.
--   2. CACHE path (different directory):
--      use sub-add with "select" flag to load it explicitly.

local M = {}

function M.is_beside_video(sub_file, video_path)
  if not sub_file or not video_path then return false end
  local sub_dir = sub_file:match("(.+)/[^/]+$") or ""
  local vid_dir = video_path:match("(.+)/[^/]+$") or ""
  return sub_dir ~= "" and sub_dir == vid_dir
end

function M.activate(mp_ref, sub_file, video_path, cache_to_media_dir)
  if M.is_beside_video(sub_file, video_path) or cache_to_media_dir then
    mp_ref.set_property("slang", "ara")
    mp_ref.commandv("rescan_external_files", "reselect")
  else
    mp_ref.commandv("sub-add", sub_file, "select", "Arabic", "ara")
  end
end

return M
