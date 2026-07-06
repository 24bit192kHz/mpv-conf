-- subdl_ar.util.match: subtitle quality scoring, metadata normalization, and
-- episode-file selection. Pure functions plus mp.msg.* debug logging preserved
-- verbatim from the original monolith.

local mp = require "mp"

local M = {}

local MAX_SEASON = 30
local MAX_EPISODE = 2000
local MIN_MATCH_SCORE = 50

function M.get_quality_score(rn)
  local s = 2000
  if rn:find("remux") then s = s + 3000
  elseif rn:find("bluray") or rn:find("bd[ri]") then s = s + 2000
  elseif rn:find("web") then s = s + 1000 end

  if rn:find("2160p") or rn:find("4k") then s = s + 400
  elseif rn:find("1080p") then s = s + 300
  elseif rn:find("720p") then s = s + 200
  elseif rn:find("480p") then s = s + 100 end

  if rn:find("x265") or rn:find("hevc") then s = s + 20
  elseif rn:find("x264") then s = s + 10 end

  if rn:find("truehd") or rn:find("dts[hx]?d?") or rn:find("flac") then s = s + 15
  elseif rn:find("aac") or rn:find("ac3") or rn:find("dd[p+]?") then s = s + 5 end
  return s
end

function M.add_episode_meta(ep_set, ep)
  ep = tonumber(ep)
  if not ep then return end
  if ep < 1 or ep > MAX_EPISODE then return end
  if ep == 480 or ep == 720 or ep == 1080 or ep == 2160 then return end
  ep_set[ep] = true
end

function M.add_pair_meta(pair_set, season_set, se, ep)
  se = tonumber(se)
  ep = tonumber(ep)
  if not se or not ep then return end
  if se < 1 or se > MAX_SEASON or ep < 1 or ep > MAX_EPISODE then return end
  pair_set[se] = pair_set[se] or {}
  pair_set[se][ep] = true
  season_set[se] = true
end

function M.normalize_subtitle_metadata(sub)
  if type(sub) ~= "table" then return end
  if sub._meta_parsed then return end
  sub._meta_parsed = true

  local pair_set, season_set, ep_set = {}, {}, {}
  local se = tonumber(sub.season_number)
  local ep = tonumber(sub.episode_number)
  if se and ep then
    M.add_pair_meta(pair_set, season_set, se, ep)
    M.add_episode_meta(ep_set, ep)
  elseif ep then
    M.add_episode_meta(ep_set, ep)
  end

  local rn = (sub.release_name or ""):lower()
  if rn ~= "" then
    for s, e in rn:gmatch("s(%d+)%s*[%._%- ]*e[p]?[%._%- ]*(%d+)") do
      M.add_pair_meta(pair_set, season_set, s, e)
    end
    for s, e in rn:gmatch("(%d+)[xX](%d+)") do
      M.add_pair_meta(pair_set, season_set, s, e)
    end
    for s, e in rn:gmatch("season%s*(%d+)[^%d]+e[p]?[%._%- ]*(%d+)") do
      M.add_pair_meta(pair_set, season_set, s, e)
    end
    for s, e in rn:gmatch("season%s*(%d+)%s*[%._%- ]*(%d+)%f[%D]") do
      M.add_pair_meta(pair_set, season_set, s, e)
    end
    for s, e in rn:gmatch("s(%d+)%s*[%._%- ]*(%d+)%f[%D]") do
      M.add_pair_meta(pair_set, season_set, s, e)
    end

    for e in rn:gmatch("episode%s*(%d+)") do M.add_episode_meta(ep_set, e) end
    for e in rn:gmatch("e[p]?[%._%- ]*(%d+)") do M.add_episode_meta(ep_set, e) end
    for e in rn:gmatch("%-%s*(%d+)%f[%D]") do M.add_episode_meta(ep_set, e) end
  end

  sub._norm_pairs = pair_set
  sub._norm_seasons = season_set
  sub._norm_eps = ep_set
end

function M.normalize_subtitles_metadata(subs)
  for _, sub in ipairs(subs or {}) do
    M.normalize_subtitle_metadata(sub)
  end
end

function M.matches_title_words(filename, title)
  if not title then return true end
  local name_lower = filename:lower()
  local name_tokens = {}
  for token in name_lower:gmatch("%w+") do
    name_tokens[token] = true
  end
  local stop = {
    ["the"]=true, ["and"]=true, ["or"]=true, ["a"]=true, ["an"]=true,
    ["of"]=true, ["in"]=true, ["on"]=true, ["to"]=true, ["for"]=true,
    ["with"]=true, ["by"]=true, ["from"]=true, ["part"]=true
  }
  local match_count = 0
  local long_match = false
  local significant_count = 0

  for word in title:lower():gmatch("%w+") do
    if #word > 2 and not stop[word] then
      significant_count = significant_count + 1
      if name_tokens[word] then
        match_count = match_count + 1
        if #word >= 5 then long_match = true end
      end
    end
  end

  if significant_count == 0 then return true end

  -- Single-word titles (e.g. "Cure") should only need one match.
  if significant_count == 1 then
    return match_count >= 1
  end

  -- Multi-word titles: require at least two significant matches, or one long word.
  return long_match or match_count >= 2
end

-- get_tmdb_season_info is injected by the orchestrator so calculate_cour_mappings
-- can use cached TMDB data without this module owning network I/O. When unset,
-- calculate_cour_mappings skips the TMDB-driven mapping (matching the behaviour
-- when no TMDB id is available).
M._tmdb_season_info = nil

function M.calculate_cour_mappings(absolute_episode, tmdb_id, detected_season)
  local mappings = {}
  local seen = {}

  local function add_mapping(season_num, episode_num)
    season_num = tonumber(season_num)
    episode_num = tonumber(episode_num)
    if not season_num or not episode_num then return end
    if season_num < 1 or episode_num < 1 or episode_num > MAX_EPISODE then return end
    local key = season_num .. "_" .. episode_num
    if not seen[key] then
      seen[key] = true
      table.insert(mappings, {season = season_num, ep = episode_num})
    end
  end

  -- Always include absolute episode as S1.
  add_mapping(1, absolute_episode)

  -- If we have TMDB data, calculate canonical season mapping.
  local seasons = tmdb_id and M._tmdb_season_info and M._tmdb_season_info(tmdb_id)
  if seasons then
    local cumulative = 0
    for s = 1, 10 do
      local ep_count = seasons[s]
      if not ep_count or ep_count == 0 then break end

      if absolute_episode > cumulative and absolute_episode <= cumulative + ep_count then
        local relative_ep = absolute_episode - cumulative
        add_mapping(s, relative_ep)
        mp.msg.info(string.format("TMDB cour mapping: E%d → S%dE%d", absolute_episode, s, relative_ep))
        break
      end
      cumulative = cumulative + ep_count
    end
  end

  -- Add fallback cour guesses because SubDL seasoning often differs from TMDB.
  local boundaries = {12, 13, 23, 24, 25}
  local function add_fallback(s, ep)
    if ep > 0 and ep <= 26 and s >= 2 and s <= 5 then
      add_mapping(s, ep)
    end
  end

  for _, b in ipairs(boundaries) do
    if absolute_episode > b then add_fallback(2, absolute_episode - b) end
  end

  local s2_totals = {24, 25, 36, 37, 47, 48, 49, 50}
  for _, total in ipairs(s2_totals) do
    if absolute_episode > total then add_fallback(3, absolute_episode - total) end
  end

  if absolute_episode > 60 then
    local s3_totals = {60, 71, 72, 73}
    for _, total in ipairs(s3_totals) do
      if absolute_episode > total then add_fallback(4, absolute_episode - total) end
    end
  end

  if detected_season and detected_season > 1 then
    add_mapping(detected_season, absolute_episode)
  end

  mp.msg.info(string.format("Cour mappings: %d candidates for E%d", #mappings, absolute_episode))
  return mappings
end

function M.build_valid_mapping_sets(cour_mappings)
  local valid_eps = {}
  local valid_pairs = {}
  local valid_seasons = {}

  for _, m in ipairs(cour_mappings or {}) do
    if m and m.season and m.ep then
      valid_eps[m.ep] = true
      valid_pairs[m.season] = valid_pairs[m.season] or {}
      valid_pairs[m.season][m.ep] = true
      valid_seasons[m.season] = true
    end
  end

  return valid_eps, valid_pairs, valid_seasons
end

function M.find_matching_episode_file(sub_files, season, episode, valid_episodes, valid_pairs)
  -- If no episode info at all, just return first file
  if not episode then
    return sub_files[1]
  end

  season = season and tonumber(season) or nil
  episode = tonumber(episode)

  -- Default valid_episodes to just the target episode
  if not valid_episodes then
    valid_episodes = { [episode] = true }
  end

  local target_season_count = 0
  if valid_pairs then
    for _ in pairs(valid_pairs) do target_season_count = target_season_count + 1 end
  end
  local has_multi_target_seasons = target_season_count > 1

  local best_match = nil
  local best_score = -1

  for _, sub_file in ipairs(sub_files) do
    local filename = sub_file:match("([^/]+)$")
    local filename_lower = filename:lower()

    local score = 0
    local ep_candidates = {}
    local se_candidates = {}

    for full, se_str, ep_str in filename_lower:gmatch("(s(%d+))[^a-zA-Z0-9]?e(%d+)") do
      local se = tonumber(se_str)
      local ep = tonumber(ep_str)
      if se and se > 0 and se <= MAX_SEASON then table.insert(se_candidates, se) end
      if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
    end

    for full, se_str, ep_str in filename_lower:gmatch("(%d+)[xX](%d+)") do
      local se = tonumber(se_str)
      local ep = tonumber(ep_str)
      if se and se > 0 and se <= MAX_SEASON then table.insert(se_candidates, se) end
      if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
    end

    for ep_str in filename_lower:gmatch("[eE][pP][._ %-]*(%d+)") do
      local ep = tonumber(ep_str)
      if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
    end

    for num_str in filename_lower:gmatch("(%d+)") do
      local num = tonumber(num_str)
      if num and num > 0 and num <= MAX_EPISODE then
        if not (filename_lower:find("[a-zA-Z]" .. num_str) or
                filename_lower:find(num_str .. "[a-zA-Z]")) then
          if num ~= 1080 and num ~= 720 and num ~= 480 and num ~= 2160 and num ~= 4 and num ~= 5 and num ~= 6 then
            table.insert(ep_candidates, num)
          end
        end
      end
    end

    local ep_set = {}
    for _, e in ipairs(ep_candidates) do ep_set[e] = true end
    ep_candidates = {}
    for e in pairs(ep_set) do table.insert(ep_candidates, e) end

    local se_set = {}
    for _, s in ipairs(se_candidates) do se_set[s] = true end
    se_candidates = {}
    for s in pairs(se_set) do table.insert(se_candidates, s) end

    local has_valid_pair = false
    if valid_pairs then
      for _, s in ipairs(se_candidates) do
        if valid_pairs[s] then
          for _, e in ipairs(ep_candidates) do
            if valid_pairs[s][e] then
              has_valid_pair = true
              break
            end
          end
        end
        if has_valid_pair then break end
      end
    end

    if has_valid_pair then
      score = score + 180
    end

    for _, e in ipairs(ep_candidates) do
      if valid_episodes[e] then
        -- Any valid episode (including cour-mapped ones) is a strong match
        score = score + 100
      elseif e == episode then
        score = score + 100
      elseif math.abs(e - episode) == 1 then
        score = score + 10
      elseif math.abs(e - episode) <= 2 then
        score = score + 1
      end
    end

    for _, s in ipairs(se_candidates) do
      if valid_pairs and valid_pairs[s] then
        score = score + 35
      elseif s == season then
        score = score + 50
      elseif has_multi_target_seasons then
        score = score - 20
      end
    end

    -- STRICT episode matching: require EXACT episode number match
    local has_exact_episode = has_valid_pair
    if has_valid_pair then
      score = score + 120
    else
      for _, e in ipairs(ep_candidates) do
        if valid_episodes[e] or e == episode then
          local ep_padded = string.format("%02d", e)
          local ep_str = tostring(e)
          local exact_patterns = {
            "e" .. ep_padded .. "[^%d]",
            "e" .. ep_padded .. "$",
            "[^%dSsPp]" .. ep_padded .. "[^%d]",
            "^" .. ep_padded .. "[^%d]",
            "- " .. ep_padded .. "[^%d]",
            "- " .. ep_padded .. "$",
            "ep" .. ep_padded,
            "episode " .. ep_str .. "[^%d]",
          }
          for _, pattern in ipairs(exact_patterns) do
            if filename_lower:find(pattern) then
              has_exact_episode = true
              score = score + 100
              break
            end
          end
          if has_exact_episode then break end
        end
      end
    end

    -- If no exact episode match found, severely penalize
    if not has_exact_episode and #ep_candidates > 0 then
      score = score - 50
    end

    local is_pack = filename_lower:find("batch") or filename_lower:find("complete") or filename_lower:find("season") or filename_lower:find("pack")
    local has_range = filename_lower:find("%d+%s*[%-%~]%s*%d+")
    if is_pack then
      score = score - (has_exact_episode and 15 or 60)
    end
    if has_range and not has_exact_episode then
      score = score - 30
    end

    -- If cour mapping includes multiple seasons, avoid hard S01 preference.
    local season_from_file = filename_lower:match("s(%d+)")
    if season_from_file then
      local s = tonumber(season_from_file)
      if has_multi_target_seasons and valid_pairs then
        if valid_pairs[s] then
          score = score + 10
        else
          score = score - 25
        end
      elseif s == 1 then
        score = score + 20
      elseif s == (season or 1) then
        score = score + 20
      else
        score = score - 20
      end
    end

    if #ep_candidates > 1 then score = score - 10 end
    if #se_candidates > 1 then score = score - 5 end

    mp.msg.debug(string.format("SubDL: file='%s' → eps=%d candidates, seas=%d candidates → score=%d", 
        filename, #ep_candidates, #se_candidates, score))

    if score > best_score then
      best_score = score
      best_match = sub_file
    end
  end

  if best_match and best_score >= MIN_MATCH_SCORE then
    local chosen_name = best_match:match("([^/]+)$")
    mp.msg.info(string.format("SubDL: ✅ Selected for E%02d (score=%d): %s", 
        episode, best_score, chosen_name))
    return best_match
  elseif best_match and best_score > 0 then
    -- Low confidence match - skip this pack and try next subtitle
    mp.msg.warn(string.format("SubDL: ⚠️ No good match for E%02d in this pack (best score=%d), trying next...", episode, best_score))
    return nil
  else
    mp.msg.warn(string.format("SubDL: ⚠️ No match for E%02d in this pack, trying next...", episode))
    return nil
  end
end

return M
