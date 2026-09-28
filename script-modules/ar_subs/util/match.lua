-- ar_subs.util.match: subtitle quality scoring, metadata normalization, and
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

-- ---------------------------------------------------------------------------
-- Episode identity. One parser for subtitle file names and release names,
-- one decision for "is this the episode we want", shared by the search
-- filter, the release ranking and the per-file pick inside packs.
--
-- Numbering differs per release: absolute ("Dandadan - 17"), per-season
-- ("S02E05", "S2 - 05", "2nd Season - 05", "Season 2 Episode 5"), or both
-- ("Dandadan-17_S2-05"). valid_pairs holds every identity of the target
-- episode as {[season] = {[episode] = true}}: the TMDB pair, and season 1
-- for the absolute number. The two rules that keep the wrong episode out:
--   * an explicit season/episode pair that is not valid rejects the name,
--     whatever bare numbers it also carries ("Dandadan-16_S2-04" is not
--     episode 17, although "04" was a cour-guess candidate);
--   * a bare number counts as a per-season episode only with that season
--     named ("Dandadan - 05" from a season-1 pack is not S2E05); without a
--     season it can only be the absolute (season-1) number, unless the
--     target has a single season anyway (plain TV).
-- ---------------------------------------------------------------------------

local NAME_EXTS = { srt = true, ass = true, ssa = true, vtt = true, sub = true,
  zst = true, zip = true, rar = true, ["7z"] = true, txt = true, idx = true,
  mkv = true, mp4 = true }

local function tag_pair(t, se, ep)
  se, ep = tonumber(se), tonumber(ep)
  if not se or not ep or se < 1 or se > MAX_SEASON or ep < 1 or ep > MAX_EPISODE then return end
  t.pairs[se] = t.pairs[se] or {}
  t.pairs[se][ep] = true
end

local function tag_season(t, se)
  se = tonumber(se)
  if se and se >= 1 and se <= MAX_SEASON then t.seasons[se] = true end
end

local function tag_ep(t, ep)
  ep = tonumber(ep)
  if ep and ep >= 1 and ep <= MAX_EPISODE then t.eps[ep] = true end
end

-- episode_tags(name) -> { pairs = {[s]={[e]=true}}, seasons = {[s]=true}, eps = {[e]=true} }
function M.episode_tags(name)
  local t = { pairs = {}, seasons = {}, eps = {} }
  local s = (tostring(name or ""):match("([^/\\]+)$") or ""):lower()
  while true do
    local base, ext = s:match("^(.*)%.([%w]+)$")
    if base and NAME_EXTS[ext] then s = base else break end
  end
  -- Digit-carrying noise first, while dots still separate it.
  s = s:gsub("%d%d%d%d?[pi]%f[%W]", " ")        -- 1080p 2160p 1080i
  s = s:gsub("%d%d%d%d?x%d%d%d%d?", " ")        -- 1920x1080
  s = s:gsub("[xh]%.?26[45]", " ")               -- x264 h.265
  s = s:gsub("%d+[%-%.]?bits?", " ")             -- 10bit 10-bit
  s = s:gsub("%a+%d%.%d%f[%D]", " ")             -- ddp5.1 aac2.0
  s = s:gsub("%f[%d]%d%.%d%f[%D]", " ")          -- 5.1 7.1 2.0
  s = s:gsub("%[%x%x%x%x%x%x%x%x%]", " ")        -- [A1B2C3D4] crc
  s = s:gsub("%(%d%d%d%d%)", " ")                -- (2019)
  s = s:gsub("(%d)v%d%f[%W]", "%1")              -- 05v2 -> 05
  s = s:gsub("[%._]", " ")

  local function take_pair(se, ep) tag_pair(t, se, ep); tag_season(t, se); tag_ep(t, ep); return " " end
  s = s:gsub("%f[%w]s(%d%d?)%s*%-?%s*episode%s*(%d%d?%d?%d?)%f[%D]", take_pair) -- s4-episode_10
  s = s:gsub("%f[%w]s(%d%d?)%s*%-?%s*e[p]?%s*(%d%d?%d?%d?)%f[%D]", take_pair)   -- s02e05 s2 ep05
  s = s:gsub("%f[%w](%d%d?)x(%d%d%d?)%f[%D]", take_pair)                          -- 3x07
  s = s:gsub("%f[%w]s(%d%d?)%s*%-%s*(%d%d?%d?%d?)%f[%D]", take_pair)             -- s2-04 s2 - 05
  s = s:gsub("season%s*(%d%d?)%s*%-?%s*e?p?i?s?o?d?e?%s*(%d%d?%d?%d?)%f[%D]", take_pair)
  s = s:gsub("%f[%w](%d)[snrt][tdh]%s*season%s*%-?%s*(%d%d?%d?%d?)%f[%D]", take_pair) -- 2nd season - 05

  s = s:gsub("%f[%w]s(%d%d?)%f[%W]", function(se) tag_season(t, se); return " " end)
  s = s:gsub("season%s*(%d%d?)", function(se) tag_season(t, se); return " " end)
  s = s:gsub("%f[%w](%d)[snrt][tdh]%s*season", function(se) tag_season(t, se); return " " end)
  -- roman sequel numerals as season ("Mob Psycho 100 II - 05", "Overlord III")
  for _, r in ipairs({ { "iv", 4 }, { "iii", 3 }, { "ii", 2 } }) do
    s = s:gsub("%f[%w]" .. r[1] .. "%f[%W]", function() tag_season(t, r[2]); return " " end)
  end

  s = s:gsub("%f[%w]e[p]?%s*(%d%d?%d?%d?)%f[%D]", function(ep) tag_ep(t, ep); return " " end)
  s = s:gsub("episode%s*(%d%d?%d?%d?)%f[%D]", function(ep) tag_ep(t, ep); return " " end)
  for ep in s:gmatch("%f[%w](%d%d?%d?%d?)%f[%W]") do tag_ep(t, ep) end
  return t
end

-- episode_verdict(tags, valid_pairs) -> 3 explicit pair match, 2 bare number
-- in a consistent season context, 1 arc-mode bare match, 0 no episode
-- information, -1 names a different episode (or is ambiguous between
-- seasons). valid_pairs[0] is the arc-mode wildcard: the title names an arc
-- ("Katanakaji no Sato-hen - 10") so the season is unknown and episode N of
-- any season qualifies -- an explicit pair outranks a bare number there.
function M.episode_verdict(tags, valid_pairs)
  valid_pairs = valid_pairs or {}
  local any = valid_pairs[0]
  local saw_pair, wild_pair, guess_pair = false, false, false
  for se, eps in pairs(tags.pairs or {}) do
    for ep in pairs(eps) do
      saw_pair = true
      local v = valid_pairs[se] and valid_pairs[se][ep]
      if v == true then return 3 end
      if v == "guess" then
        -- A guessed pair whose name also carries a different absolute count
        -- ("Dandadan-16_S2-04" vs episode 17) is that other episode.
        local contradicted = false
        for n in pairs(tags.eps or {}) do
          if n > ep and valid_pairs[1] and not valid_pairs[1][n] then contradicted = true end
        end
        if not contradicted then guess_pair = true end
      end
      if any and any[ep] then wild_pair = true end
    end
  end
  if wild_pair or guess_pair then return 2 end
  if saw_pair then return -1 end
  if any then
    for ep in pairs(tags.eps or {}) do
      if any[ep] then return 1 end
    end
  end

  local n_seasons, only_season = 0, nil
  for se in pairs(valid_pairs) do
    if se > 0 then n_seasons = n_seasons + 1; only_season = se end
  end
  local hints = tags.seasons or {}
  local has_hint = next(hints) ~= nil
  local saw_ep = false
  for ep in pairs(tags.eps or {}) do
    saw_ep = true
    if has_hint then
      for se in pairs(hints) do
        if valid_pairs[se] and valid_pairs[se][ep] then return 2 end
      end
      -- "Show S2 - 17": a number past any single cour under a later-season
      -- label is the continuing absolute count.
      if ep > 13 and valid_pairs[1] and valid_pairs[1][ep] then return 2 end
    elseif (valid_pairs[1] and valid_pairs[1][ep])
        or (n_seasons == 1 and valid_pairs[only_season][ep]) then
      return 2
    end
  end
  if saw_ep then return -1 end
  return 0
end

-- Tags from a search-result row: API season/episode fields plus its name.
function M.release_tags(sub)
  M.normalize_subtitle_metadata(sub)
  return { pairs = sub._norm_pairs or {}, seasons = sub._norm_seasons or {}, eps = sub._norm_eps or {} }
end

function M.normalize_subtitle_metadata(sub)
  if type(sub) ~= "table" then return end
  if sub._meta_parsed then return end
  sub._meta_parsed = true

  local pair_set, season_set, ep_set = {}, {}, {}

  -- v1 ships season_number/episode_number; v2 ships season/episode. Both are
  -- HINTS only — release_name parsing below is authoritative. season:0 is
  -- dropped by add_pair_meta (se < 1 filter).
  local se = tonumber(sub.season_number) or tonumber(sub.season)
  local ep = tonumber(sub.episode_number) or tonumber(sub.episode)
  if se and ep then
    M.add_pair_meta(pair_set, season_set, se, ep)
    M.add_episode_meta(ep_set, ep)
  elseif se then
    season_set[se] = true
  elseif ep then
    M.add_episode_meta(ep_set, ep)
  end

  -- v2 episode_end: range hint (E5..E12). Expand so the matcher can pick
  -- this sub for any episode within [ep, episode_end].
  local ep_end = tonumber(sub.episode_end)
  if ep and ep_end and ep_end > ep then
    for e = ep + 1, math.min(ep_end, MAX_EPISODE) do
      M.add_episode_meta(ep_set, e)
      if se then M.add_pair_meta(pair_set, season_set, se, e) end
    end
  end

  if sub.full_season then
    sub._is_pack = true
  end

  local rn = sub.release_name or ""
  if rn ~= "" then
    local t = M.episode_tags(rn)
    for s, eps in pairs(t.pairs) do
      for e in pairs(eps) do M.add_pair_meta(pair_set, season_set, s, e) end
    end
    for s in pairs(t.seasons) do season_set[s] = true end
    for e in pairs(t.eps) do M.add_episode_meta(ep_set, e) end
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

function M.calculate_cour_mappings(absolute_episode, tmdb_id, detected_season, season_unknown)
  local mappings = {}
  local seen = {}

  local function add_mapping(season_num, episode_num)
    season_num = tonumber(season_num)
    episode_num = tonumber(episode_num)
    if not season_num or not episode_num then return end
    if season_num < 0 or episode_num < 1 or episode_num > MAX_EPISODE then return end
    local key = season_num .. "_" .. episode_num
    if not seen[key] then
      seen[key] = true
      table.insert(mappings, {season = season_num, ep = episode_num})
    end
  end

  local episode = tonumber(absolute_episode)
  if not episode then return mappings end
  detected_season = tonumber(detected_season)
  local seasons = tmdb_id and M._tmdb_season_info and M._tmdb_season_info(tmdb_id)

  -- TMDB's episode counts turn an absolute number into (season, episode),
  -- and (season, episode) back into the absolute number.
  local function tmdb_pair_for(abs)
    if not seasons then return nil end
    local cumulative = 0
    for s = 1, 10 do
      local ep_count = seasons[s]
      if not ep_count or ep_count == 0 then return nil end
      if abs > cumulative and abs <= cumulative + ep_count then
        return s, abs - cumulative
      end
      cumulative = cumulative + ep_count
    end
    return nil
  end
  local cours = seasons and seasons.cours or {}
  local function tmdb_abs_for(season_num, ep)
    if not seasons then return nil end
    local cumulative, s = 0, 1
    while s < season_num and seasons[s] and seasons[s] > 0 do
      cumulative = cumulative + seasons[s]
      s = s + 1
    end
    if s == season_num and seasons[s] then
      return ep <= seasons[s] and cumulative + ep or nil
    end
    -- A provider season past TMDB's last one is a later cour of it: Dan Da
    -- Dan's "S2E05" is cour 2 of TMDB's single season = episode 17.
    local last = s - 1
    local starts = last >= 1 and cours[last]
    local k = season_num - last
    if starts and starts[k] then
      return cumulative - seasons[last] + starts[k] - 1 + ep
    end
    return nil
  end
  -- Cour-as-season label of a TMDB pair: episode 17 of a 24-episode season
  -- whose second cour starts at 13 is the provider's S2E05. Only when TMDB
  -- has no real next season that the label would collide with.
  local function cour_label_for(s, e)
    local starts = cours[s]
    if not starts or seasons[s + 1] then return nil end
    local k = 0
    for i, b in ipairs(starts) do if e >= b then k = i end end
    if k == 0 then return nil end
    return s + k, e - starts[k] + 1
  end

  if detected_season and detected_season > 1 then
    -- The file names its season ("Show S2 - 05", "S02E05"): the number is
    -- per-season. Its absolute twin is only known through TMDB; guessing
    -- (1, 5) would accept season-1 "Show - 05" subtitles for S2E05.
    add_mapping(detected_season, episode)
    local abs = tmdb_abs_for(detected_season, episode)
    if abs then
      add_mapping(1, abs)
    elseif episode > 13 then
      -- past any single cour: a continuing absolute count under a season label
      add_mapping(1, episode)
      local s, e = tmdb_pair_for(episode)
      if s then add_mapping(s, e) end
    end
    mp.msg.info(string.format("Cour mappings: %d candidates for S%dE%d", #mappings, detected_season, episode))
    return mappings
  end

  -- Arc-named title ("Kimetsu no Yaiba Katanakaji no Sato-hen - 10") that is
  -- not the TMDB show name: the number counts within an arc whose season
  -- providers label differently (Swordsmith Village is S3 on TMDB, S4 on
  -- Crunchyroll). Neither the absolute reading (S1E10) nor a TMDB mapping
  -- holds; accept episode N of any season (season 0 = wildcard).
  if season_unknown then
    add_mapping(0, episode)
    mp.msg.info(string.format("Cour mappings: season unknown (arc title), any season E%d", episode))
    return mappings
  end

  -- No season in the name: absolute numbering (identical to S1 per-season
  -- numbering for the first season).
  add_mapping(1, episode)
  local s, e = tmdb_pair_for(episode)
  if s then
    add_mapping(s, e)
    local cs, ce = cour_label_for(s, e)
    if cs then add_mapping(cs, ce) end
    mp.msg.info(string.format("TMDB cour mapping: E%d → S%dE%d%s", episode, s, e,
      cs and string.format(" (cour label S%dE%d)", cs, ce) or ""))
    -- TMDB placed it: the cour-length guesses below would only add wrong
    -- episodes (Dandadan E17 = S2E05; the 13-episode guess made S2E04 valid
    -- and loaded episode 16's subtitle).
    mp.msg.info(string.format("Cour mappings: %d candidates for E%d", #mappings, episode))
    return mappings
  end

  -- No TMDB data: cour guesses, because provider seasoning often differs.
  local boundaries = {12, 13, 23, 24, 25}
  local function add_fallback(season_num, ep)
    if ep > 0 and ep <= 26 and season_num >= 2 and season_num <= 5 then
      local before = #mappings
      add_mapping(season_num, ep)
      if #mappings > before then mappings[#mappings].guess = true end
    end
  end

  for _, b in ipairs(boundaries) do
    if episode > b then add_fallback(2, episode - b) end
  end

  local s2_totals = {24, 25, 36, 37, 47, 48, 49, 50}
  for _, total in ipairs(s2_totals) do
    if episode > total then add_fallback(3, episode - total) end
  end

  if episode > 60 then
    local s3_totals = {60, 71, 72, 73}
    for _, total in ipairs(s3_totals) do
      if episode > total then add_fallback(4, episode - total) end
    end
  end

  mp.msg.info(string.format("Cour mappings: %d candidates for E%d", #mappings, episode))
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
      -- "guess": a cour-length guess made without TMDB data (weaker than a
      -- mapping, see episode_verdict); never downgrade a real mapping.
      if valid_pairs[m.season][m.ep] ~= true then
        valid_pairs[m.season][m.ep] = m.guess and "guess" or true
      end
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

  -- Target identities for episode_verdict: callers without cour data get
  -- the plain (season, episode) plus any extra valid episode numbers.
  local verdict_pairs = valid_pairs
  if not verdict_pairs then
    local s = season or 1
    verdict_pairs = { [s] = { [episode] = true } }
    for e in pairs(valid_episodes) do verdict_pairs[s][e] = true end
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
    -- Normalize away revision tags ("01v2" -> "01") so the episode number
    -- survives; parsing runs on this copy, display keeps the original name.
    local filename_lower = filename:lower():gsub("(%d)v%d+", "%1")
    -- Gate first: a name that is not this episode (or is ambiguous between
    -- seasons) never competes, whatever its score below would have been.
    local verdict = M.episode_verdict(M.episode_tags(filename), verdict_pairs)
    if verdict < 1 then
      mp.msg.debug(string.format("ar_subs: file='%s' rejected (episode verdict %d)", filename, verdict))
      goto next_file
    end

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

    -- Bare episode tag without season prefix or "p" ("Deadman Wonderland E01",
    -- " - e01"). Require a non-letter (or string start) before the "e" so word
    -- internals like "size1080" never contribute. Lua patterns have no
    -- alternation, so string-start and mid-string are matched separately.
    for ep_str in filename_lower:gmatch("^e(%d+)") do
      local ep = tonumber(ep_str)
      if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
    end
    for ep_str in filename_lower:gmatch("[^a-z]e(%d+)") do
      local ep = tonumber(ep_str)
      if ep and ep > 0 and ep <= MAX_EPISODE then table.insert(ep_candidates, ep) end
    end

    for pos, num_str in filename_lower:gmatch("()(%d+)") do
      local num = tonumber(num_str)
      if num and num > 0 and num <= MAX_EPISODE then
        -- Glued to a letter *at this run* (x264, 03b81f hash). Unanchored
        -- find("[a-z]"..num) also hits a later hash and used to drop a real
        -- `_03_` tag in coalgirls_..._lain_03_1520x1080_..._03b81f3c.
        local before = pos > 1 and filename_lower:sub(pos - 1, pos - 1) or ""
        local after = filename_lower:sub(pos + #num_str, pos + #num_str)
        local glued = before:match("%a") or after:match("%a")
        if not glued then
          if num ~= 1080 and num ~= 720 and num ~= 480 and num ~= 2160 then
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

    -- An explicit pair outranks a bare number; the legacy score only breaks
    -- ties (quality, pack penalties). Verdict-gated names are the episode,
    -- so they no longer need MIN_MATCH_SCORE.
    score = math.max(score, MIN_MATCH_SCORE) + verdict * 1000

    mp.msg.debug(string.format("ar_subs: file='%s' → eps=%d candidates, seas=%d candidates → score=%d",
        filename, #ep_candidates, #se_candidates, score))

    if score > best_score then
      best_score = score
      best_match = sub_file
    end
    ::next_file::
  end

  if best_match and best_score >= MIN_MATCH_SCORE then
    local chosen_name = best_match:match("([^/]+)$")
    mp.msg.info(string.format("ar_subs: selected for E%02d (score=%d): %s",
        episode, best_score, chosen_name))
    return best_match
  elseif best_match and best_score > 0 then
    mp.msg.debug(string.format(
        "ar_subs: no good filename match for E%02d (best score=%d)", episode, best_score))
    return nil
  else
    mp.msg.debug(string.format("ar_subs: no filename match for E%02d", episode))
    return nil
  end
end

-- expand_unpack_files(subs) -> subs
-- Search with unpack=1 returns season packs as one entry carrying unpack_files[]
-- (per-file url/season/episode/language). Downloading such a pack blindly takes
-- unpack_files[1], which is rarely the target episode. Expand each pack into
-- one synthetic child entry per unpack file so the normal filter/rank/download
-- pipeline selects the exact episode file. The parent entry is dropped when at
-- least one child carries a usable download url; otherwise it is kept as a
-- zip-fallback.
function M.expand_unpack_files(subs)
  local out = {}
  for _, sub in ipairs(subs or {}) do
    local ufs = sub.unpack_files
    if type(ufs) ~= "table" or #ufs == 0 then
      table.insert(out, sub)
    else
      local parent_id = sub.id or sub.sd_id or "?"
      local usable = 0
      for idx, uf in ipairs(ufs) do
        if type(uf) == "table" and uf.url and uf.url ~= "" then
          usable = usable + 1
          local name = uf.name or sub.release_name or ""
          name = name:match("([^/]+)$") or name
          local child = {
            url = uf.url,
            download_url = uf.url,
            release_name = name ~= "" and name or sub.release_name,
            season_number = uf.season or uf.season_number or sub.season_number,
            episode_number = uf.episode or uf.episode_number or sub.episode_number,
            episode_end = uf.episode_end,
            language = uf.language or sub.language,
            full_season = false,
            id = tostring(parent_id) .. "#" .. idx,
            _parent_id = parent_id,
            _is_pack = false,
          }
          M.normalize_subtitle_metadata(child)
          table.insert(out, child)
        end
      end
      if usable == 0 then
        -- No direct per-file URLs: keep the parent so the zip path can run.
        table.insert(out, sub)
      end
    end
  end
  return out
end

return M
