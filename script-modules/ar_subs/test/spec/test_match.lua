-- Spec: ar_subs.util.match
local H = require "harness"
local match = require "ar_subs.util.match"

-- Reset TMDB injection between cases.
match._tmdb_season_info = nil

-- get_quality_score
H.eq("q plain", match.get_quality_score("plain.release"), 2000)
H.eq("q remux.2160p.web.x265", match.get_quality_score("movie.remux.2160p.uhd.web-dl.x265"), 5420)
H.eq("q bluray.1080p.x264.aac", match.get_quality_score("movie.bluray.1080p.x264.aac"), 4315)
H.eq("q web.720p.x264.aac", match.get_quality_score("show.web.720p.x264.aac"), 3215)
H.eq("q web.1080p.x264 only", match.get_quality_score("a.web.1080p.x264.b"), 3310)
H.eq("q web-dl alone", match.get_quality_score("a.web-dl.b"), 3000)
H.eq("q 4k counts as 2160p", match.get_quality_score("a.4k.web.b"), 3400)
H.eq("q hevc codec", match.get_quality_score("a.hevc.b"), 2020)
H.eq("q truehd", match.get_quality_score("a.truehd.b"), 2015)
H.eq("q ac3 falls into aac/ac3 branch", match.get_quality_score("a.ac3.b"), 2005)
H.eq("q dts-hd via dts pattern", match.get_quality_score("a.dtshd.b"), 2015)

-- add_episode_meta: range/resolution filtering
do
  local s = {}
  match.add_episode_meta(s, 5)
  match.add_episode_meta(s, 1080)   -- resolution filtered
  match.add_episode_meta(s, 480)    -- resolution filtered
  match.add_episode_meta(s, 0)      -- below 1
  match.add_episode_meta(s, 3000)   -- above MAX_EPISODE
  match.add_episode_meta(s, "12")   -- string coerced
  H.same("add_episode_meta filters", s, { [5] = true, [12] = true })
end

-- add_pair_meta: range filtering + idempotency
do
  local ps, ss = {}, {}
  match.add_pair_meta(ps, ss, 2, 10)
  match.add_pair_meta(ps, ss, 0, 5)   -- season < 1 filtered
  match.add_pair_meta(ps, ss, 2, 10)  -- dup ignored in season_set
  match.add_pair_meta(ps, ss, 1, 3000)-- ep > MAX_EPISODE filtered
  H.same("add_pair_meta pairs[2]", ps[2], { [10] = true })
  H.same("add_pair_meta seasons", ss, { [2] = true })
end

-- normalize_subtitle_metadata: release_name parsing
do
  H.reset()
  local sub = { release_name = "Show.S01E05.WEB-DL.x264" }
  match.normalize_subtitle_metadata(sub)
  H.ok("norm marks _meta_parsed", sub._meta_parsed == true)
  H.same("norm pairs[1] has 5", sub._norm_pairs[1], { [5] = true })
  H.same("norm seasons has 1", sub._norm_seasons, { [1] = true })
  H.same("norm eps has 5", sub._norm_eps, { [5] = true })
end

-- normalize_subtitle_metadata: explicit season/episode fields
do
  H.reset()
  local sub = { season_number = 2, episode_number = 7, release_name = "" }
  match.normalize_subtitle_metadata(sub)
  H.same("norm explicit pair", sub._norm_pairs[2], { [7] = true })
  H.same("norm explicit eps", sub._norm_eps, { [7] = true })
end

-- normalize_subtitle_metadata: episode-only fields
do
  H.reset()
  local sub = { episode_number = 3 }
  match.normalize_subtitle_metadata(sub)
  H.same("norm ep-only eps", sub._norm_eps, { [3] = true })
  H.ok("norm ep-only has no pairs", next(sub._norm_pairs) == nil)
end

-- normalize_subtitle_metadata: idempotent (second call is no-op)
do
  H.reset()
  local sub = { release_name = "X.S01E01" }
  match.normalize_subtitle_metadata(sub)
  local first_pairs = sub._norm_pairs
  sub.release_name = "Y.S02E02"
  match.normalize_subtitle_metadata(sub)  -- should skip because _meta_parsed
  H.same("norm idempotent preserves first parse", sub._norm_pairs, first_pairs)
end

-- normalize_subtitle_metadata: non-table input ignored
H.ok("norm non-table ignored", pcall(function()
  match.normalize_subtitle_metadata("not a table")
end))

-- normalize_subtitles_metadata: iterates list
do
  H.reset()
  local subs = {
    { release_name = "A.S01E01" },
    { release_name = "B.S02E03" },
  }
  match.normalize_subtitles_metadata(subs)
  H.same("norm list sub1 pairs", subs[1]._norm_pairs[1], { [1] = true })
  H.same("norm list sub2 pairs", subs[2]._norm_pairs[2], { [3] = true })
end

-- matches_title_words
H.eq("mtw nil title -> true", match.matches_title_words("anything", nil), true)
H.eq("mtw single sig word match", match.matches_title_words("avatar.2020", "Avatar"), true)
H.eq("mtw single sig word no match", match.matches_title_words("xxx", "Cure"), false)
H.eq("mtw multi-word all match", match.matches_title_words("foo bar baz", "Foo Bar Baz"), true)
H.eq("mtw multi-word none match", match.matches_title_words("foo", "Foo Bar Baz"), false)
H.eq("mtw multi-word one long match suffices", match.matches_title_words("avatar.foo", "Avatar Returns"), true)
H.eq("mtw stopword ignored (the/and/of)", match.matches_title_words("lord rings", "Lord of the Rings"), true)
H.eq("mtw short words (<=2) ignored", match.matches_title_words("it go", "It Go"), true)  -- significant_count=0 -> true
H.eq("mtw 'part' is stopword", match.matches_title_words("foo", "Foo Part"), true)  -- only 'foo' sig, single match

-- calculate_cour_mappings: no TMDB data, fallbacks only
do
  H.reset()
  local m12 = match.calculate_cour_mappings(12, nil, nil)
  H.eq("cour E12 count", #m12, 1)
  H.eq("cour E12[0].season", m12[1].season, 1)
  H.eq("cour E12[0].ep", m12[1].ep, 12)
end

do
  H.reset()
  local m25 = match.calculate_cour_mappings(25, nil, nil)
  H.eq("cour E25 count (fallbacks fire)", #m25, 6)
  -- First entry is always S1E{abs}
  H.eq("cour E25[1] S1E25", m25[1].season .. "/" .. m25[1].ep, "1/25")
  -- Verify a known fallback: 25 > 13 -> S2E12
  local found_s2e12 = false
  for _, mm in ipairs(m25) do
    if mm.season == 2 and mm.ep == 12 then found_s2e12 = true end
  end
  H.ok("cour E25 includes S2E12 fallback", found_s2e12)
end

do
  H.reset()
  -- detected_season > 1 adds S{detected}E{abs}
  local m100 = match.calculate_cour_mappings(100, nil, 2)
  H.eq("cour E100 with detected=2 count", #m100, 2)
  H.ok("cour E100 has S2E100", (function()
    for _, mm in ipairs(m100) do if mm.season == 2 and mm.ep == 100 then return true end end
    return false
  end)())
end

-- calculate_cour_mappings: TMDB injection fires once
do
  H.reset()
  local calls = 0
  match._tmdb_season_info = function(tmdb_id)
    calls = calls + 1
    H.eq("cour tmdb_id passed", tmdb_id, 555)
    -- Season 1: 12 eps -> E13 lands in S2
    return { [1] = 12, [2] = 12 }
  end
  local m13 = match.calculate_cour_mappings(13, 555, nil)
  H.eq("cour TMDB lookup called once", calls, 1)
  H.ok("cour TMDB added S2E1", (function()
    for _, mm in ipairs(m13) do if mm.season == 2 and mm.ep == 1 then return true end end
    return false
  end)())
  match._tmdb_season_info = nil
end

-- build_valid_mapping_sets
do
  local mappings = { {season=1, ep=25}, {season=2, ep=1}, {season=2, ep=2} }
  local ve, vp, vs = match.build_valid_mapping_sets(mappings)
  H.same("build valid_eps", ve, { [1] = true, [2] = true, [25] = true })
  H.same("build valid_pairs[1]", vp[1], { [25] = true })
  H.same("build valid_pairs[2]", vp[2], { [1] = true, [2] = true })
  H.same("build valid_seasons", vs, { [1] = true, [2] = true })
end

H.same("build empty input", ({ match.build_valid_mapping_sets(nil) })[1], {})
-- Entries with missing season/ep fields are skipped; ipairs requires no nil gaps.
H.same("build malformed entries skipped", ({ match.build_valid_mapping_sets({ {season=1, ep=1}, {ep=2}, {season=3} }) })[3], { [1] = true })

-- find_matching_episode_file: nil episode returns first
do
  H.reset()
  local r = match.find_matching_episode_file({ "/a/x.srt", "/b/y.srt" }, nil, nil)
  H.eq("fnef nil episode -> first", r, "/a/x.srt")
end

-- find_matching_episode_file: exact episode beats adjacent episode
do
  H.reset()
  local files = {
    "/p/Show.S01E01.WEB.srt",
    "/p/Show.S01E02.WEB.srt",
  }
  local r = match.find_matching_episode_file(files, 1, 1, nil, nil)
  H.eq("fmef picks exact episode", r, "/p/Show.S01E01.WEB.srt")
end

-- find_matching_episode_file: low score returns nil (below MIN_MATCH_SCORE=50)
do
  H.reset()
  local files = {
    "/p/Random.E99.srt",  -- wrong episode, weak signals
  }
  local r = match.find_matching_episode_file(files, 1, 1, nil, nil)
  H.eq("fmef no match returns nil", r, nil)
end

-- find_matching_episode_file: empty list returns nil
do
  H.reset()
  local r = match.find_matching_episode_file({}, 1, 1, nil, nil)
  H.eq("fmef empty list nil", r, nil)
end

-- find_matching_episode_file: valid_episodes drives selection
do
  H.reset()
  local files = {
    "/p/Show.S01E05.WEB.srt",
    "/p/Show.S01E12.WEB.srt",
  }
  -- Tell the matcher E12 is a valid cour-mapped candidate.
  local valid_eps = { [12] = true }
  local r = match.find_matching_episode_file(files, 1, 12, valid_eps, nil)
  H.eq("fmef respects valid_episodes override", r, "/p/Show.S01E12.WEB.srt")
end

-- find_matching_episode_file: pack is penalized
do
  H.reset()
  local files = {
    "/p/Show.Complete.Season.Pack.srt",  -- pack with no clear episode
    "/p/Show.S01E05.WEB.srt",
  }
  local r = match.find_matching_episode_file(files, 1, 5, nil, nil)
  H.eq("fmef exact beats pack", r, "/p/Show.S01E05.WEB.srt")
end

-- Regression: wrong season pack (S02) should not produce S03 pairs
do
  H.reset()
  local sub = { release_name = "House.Of.The.Dragon.S02.1080p.Bluray.x264-BROADCAST" }
  match.normalize_subtitle_metadata(sub)
  H.ok("wrong-season S02 has _norm_seasons[2]", sub._norm_seasons[2] == true)
  H.ok("wrong-season S02 has no _norm_pairs[3]", sub._norm_pairs[3] == nil)
end

-- Regression: exact episode S03E01 produces correct pair
do
  H.reset()
  local sub = { release_name = "House.of.the.Dragon.S03E01.2160p.HMAX.WEB-DL.DDP5.1.Atmos.DV.HDR.H.265-FLUX" }
  match.normalize_subtitle_metadata(sub)
  H.ok("exact S03E01 has _norm_pairs[3][1]", sub._norm_pairs[3] and sub._norm_pairs[3][1] == true)
  H.ok("exact S03E01 has _norm_seasons[3]", sub._norm_seasons[3] == true)
  H.ok("exact S03E01 has _norm_eps[1]", sub._norm_eps[1] == true)
end

-- Regression: requested-season pack (S03) - release name regex cannot extract
-- season-only from "S03.2160p" because the s/e pattern matches 2160 as episode
-- (>MAX_EPISODE, filtered). Season comes from API fields, not release name.
do
  H.reset()
  local sub = { release_name = "House.of.the.Dragon.S03.2160p.HMAX.WEB-DL", season = 3 }
  match.normalize_subtitle_metadata(sub)
  H.ok("season-pack S03 with API field has _norm_seasons[3]", sub._norm_seasons[3] == true)
  H.ok("season-pack S03 has no pairs", next(sub._norm_pairs) == nil)
end

-- Regression: wrong episode S03E07 should not match S03E01
do
  H.reset()
  local sub = { release_name = "House.of.the.Dragon.S03E07.1080p.HMAX.WEB-DL" }
  match.normalize_subtitle_metadata(sub)
  H.ok("wrong-ep S03E07 has _norm_pairs[3][7]", sub._norm_pairs[3] and sub._norm_pairs[3][7] == true)
  H.ok("wrong-ep S03E07 has no _norm_pairs[3][1]", not (sub._norm_pairs[3] and sub._norm_pairs[3][1]))
end
