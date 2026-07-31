-- ar_subs.ui.uosc_picker: format subtitle list into uosc menu-open JSON.
--
-- Produces a menu structure compatible with uosc's menu-open message:
--   { title = "...", items = [ { title, value }, ... ] }
--
-- Each item's value is a script-message command that triggers download.

local M = {}

local function format_score(score)
  if score == nil or score == "" then return "N/A" end
  return tostring(score)
end

function M.format_item(sub, index)
  local release = sub.release_name or "Unknown"
  local lang = sub.lang or "ar"
  local score = format_score(sub.score)
  local title = string.format("[%s] %s (%s)", score, release, lang)
  return {
    title = title,
    value = string.format("script-message ar_subs_download_item %d", index),
  }
end

function M.build_menu(subs)
  if not subs or #subs == 0 then
    return { title = "Arabic Subtitles", items = {} }
  end

  -- Sort by score descending so the best match appears first.
  local sorted = {}
  for _, sub in ipairs(subs) do
    sorted[#sorted + 1] = sub
  end
  table.sort(sorted, function(a, b)
    return (a.score or 0) > (b.score or 0)
  end)

  local items = {}
  for i, sub in ipairs(sorted) do
    items[i] = M.format_item(sub, i)
  end

  return {
    title = string.format("Arabic Subtitles (%d)", #subs),
    items = items,
  }
end

return M
