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

-- find_matching_episode_file: "Show - 05.srt" must match episode 5
do
  H.reset()
  local r = match.find_matching_episode_file(
    { "/p/Show - 05.srt", "/p/Show - 12.srt" }, 1, 5, nil, nil)
  H.eq("fmef hyphen-padded episode 05", r, "/p/Show - 05.srt")
end

-- Hash suffix 03b81f3c must not hide a delimited _03_ episode tag.
do
  H.reset()
  local f = "/p/coalgirls_serial_experiments_lain_03_1520x1080_blu-ray_flac_03b81f3c.ass.zst"
  local r = match.find_matching_episode_file({ f }, 1, 3, { [3] = true }, { [1] = { [3] = true } })
  H.eq("fmef coalgirls _03_ vs hash 03b81f", r, f)
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

-- ---------------------------------------------------------------------------
-- Episode identity across numbering schemes (Dandadan: S1 = 12 episodes,
-- absolute 17 = S2E05). Regression: E17 loaded "Crunchyroll_Dandadan-16_S2-04"
-- because a 13-episode cour guess made episode 4 valid and "S2-04" was not
-- read as a pair.
-- ---------------------------------------------------------------------------
local function tags_str(name)
  local t = match.episode_tags(name)
  local o = {}
  for s, es in pairs(t.pairs) do for e in pairs(es) do o[#o + 1] = "P" .. s .. "x" .. e end end
  for s in pairs(t.seasons) do o[#o + 1] = "S" .. s end
  for e in pairs(t.eps) do o[#o + 1] = "E" .. e end
  table.sort(o)
  return table.concat(o, " ")
end
H.eq("tags S2-04 is a pair", tags_str("Crunchyroll_Dandadan-16_S2-04.ass.zst"), "E16 E4 P2x4 S2")
H.eq("tags S2 - 05 with crc/res noise", tags_str("[SubsPlease] Dandadan S2 - 05 (1080p) [ABCDEF12].ass"), "E5 P2x5 S2")
H.eq("tags 2nd Season - 05", tags_str("DAN DA DAN 2nd Season - 05.srt"), "E5 P2x5 S2")
H.eq("tags Season 2 Episode 5", tags_str("Dandadan Season 2 Episode 5.srt"), "E5 P2x5 S2")
H.eq("tags S02E05 ignores DDP5.1 and H.264", tags_str("Dan.Da.Dan.S02E05.1080p.NF.WEB-DL.DDP5.1.H.264.srt"), "E5 P2x5 S2")
H.eq("tags 3x07", tags_str("Show 3x07 720p.srt"), "E7 P3x7 S3")
H.eq("tags bare absolute", tags_str("Dandadan - 17.ass"), "E17")
H.eq("tags season-only pack", tags_str("House.Of.The.Dragon.S02.1080p.Bluray.x264-BROADCAST"), "S2")
H.eq("tags roman numeral season", tags_str("Mob Psycho 100 II - 05 [1080p].ass"), "E100 E5 S2")
H.eq("tags lain _03_ vs hash", tags_str("coalgirls_serial_experiments_lain_03_1520x1080_blu-ray_flac_03b81f3c.ass.zst"), "E3")
H.eq("tags year in parens ignored", tags_str("One.Outs.E24.Jap.DVD.Rip[720p].ENG.subs.(2009).srt"), "E24")

do
  H.reset()
  match._tmdb_season_info = function() return { [1] = 12, [2] = 12 } end
  local function pairs_of(m) local o = {} for _, x in ipairs(m) do o[#o + 1] = x.season .. "x" .. x.ep end table.sort(o) return table.concat(o, " ") end
  H.eq("cour E17 with TMDB: absolute + S2E05 only, no guesses", pairs_of(match.calculate_cour_mappings(17, 1, nil)), "1x17 2x5")
  H.eq("cour E5 with TMDB: season 1 only", pairs_of(match.calculate_cour_mappings(5, 1, nil)), "1x5")
  H.eq("cour S2E05 file: pair + TMDB absolute", pairs_of(match.calculate_cour_mappings(5, 1, 2)), "1x17 2x5")
  H.eq("cour S2 - 17 continuing count: absolute + TMDB pair", pairs_of(match.calculate_cour_mappings(17, 1, 2)), "1x17 2x17 2x5")
  match._tmdb_season_info = nil
  H.eq("cour S2E05 file without TMDB: no season-1 twin", pairs_of(match.calculate_cour_mappings(5, nil, 2)), "2x5")

  local e17 = { [1] = { [17] = true }, [2] = { [5] = true } }
  local ve17 = { [17] = true, [5] = true }
  local pool = {
    "/c/NETFLIX_Dandadan-05.ass.zst",
    "/c/Crunchyroll_Dandadan-16_S2-04.ass.zst",
    "/c/Crunchyroll_Dandadan-05_1080p-BD.ass.zst",
  }
  H.eq("E17: wrong-episode pool yields nothing (not S2-04, not S1 -05)",
    match.find_matching_episode_file(pool, nil, 17, ve17, e17), nil)
  local with_right = { pool[1], pool[2], "/c/Dandadan - 17.ass", "/c/Crunchyroll_Dandadan-17_S2-05.ass.zst" }
  H.eq("E17: explicit S2-05 beats bare absolute 17",
    match.find_matching_episode_file(with_right, nil, 17, ve17, e17), "/c/Crunchyroll_Dandadan-17_S2-05.ass.zst")
  H.eq("E17: bare absolute 17 accepted",
    match.find_matching_episode_file({ pool[1], "/c/Dandadan - 17.ass" }, nil, 17, ve17, e17), "/c/Dandadan - 17.ass")
  H.eq("E17: 2nd Season - 05 accepted",
    match.find_matching_episode_file({ pool[1], "/c/DAN DA DAN 2nd Season - 05.srt" }, nil, 17, ve17, e17), "/c/DAN DA DAN 2nd Season - 05.srt")
  H.eq("E17: roman II - 05 accepted",
    match.find_matching_episode_file({ pool[1], "/c/Dandadan II - 05.ass" }, nil, 17, ve17, e17), "/c/Dandadan II - 05.ass")

  local e5 = { [1] = { [5] = true } }
  H.eq("E5 (S1): bare 05 accepted",
    match.find_matching_episode_file({ "/c/Dandadan S2 - 05.ass", "/c/NETFLIX_Dandadan-05.ass.zst" }, nil, 5, { [5] = true }, e5), "/c/NETFLIX_Dandadan-05.ass.zst")
  H.eq("E5 (S1): only season-2 names -> nothing",
    match.find_matching_episode_file({ "/c/Dandadan S2 - 05.ass", "/c/DAN DA DAN 2nd Season - 05.srt" }, nil, 5, { [5] = true }, e5), nil)
end

do
  H.reset()
  -- Plain TV: single target season, bare episode numbers are unambiguous.
  local files = { "/t/Show.S02E07.srt", "/t/Show.S03E08.srt", "/t/Show - 07.srt", "/t/Show.S03E07.720p.srt" }
  H.eq("TV S3E7: explicit pair wins", match.find_matching_episode_file(files, 3, 7, nil, nil), "/t/Show.S03E07.720p.srt")
  H.eq("TV S3E7: bare 07 accepted when alone", match.find_matching_episode_file({ files[1], files[3] }, 3, 7, nil, nil), "/t/Show - 07.srt")
  H.eq("TV S3E7: S02E07 and S03E08 rejected", match.find_matching_episode_file({ files[1], files[2] }, 3, 7, nil, nil), nil)
end

do
  H.reset()
  local vp = { [1] = { [17] = true }, [2] = { [5] = true } }
  H.eq("verdict: API season 1 + bare 05 row rejected for S2E05",
    match.episode_verdict(match.release_tags({ release_name = "Dandadan - 05", season = 1 }), vp), -1)
  H.eq("verdict: API pair 2/5 accepted",
    match.episode_verdict(match.release_tags({ release_name = "Dandadan", season_number = 2, episode_number = 5 }), vp), 3)
  H.eq("verdict: no episode info is neutral (last-resort fallback)",
    match.episode_verdict(match.release_tags({ release_name = "Dandadan Arabic" }), vp), 0)
  H.eq("verdict: season-2 pack name without episode is neutral",
    match.episode_verdict(match.release_tags({ release_name = "Dandadan Season 2 Complete" }), vp), 0)
end

-- Arc-named titles: the season is unknown (Swordsmith Village is TMDB S3,
-- Crunchyroll S4); episode N of any season qualifies, an explicit season
-- outranks a bare number, an explicit wrong episode is still rejected.
H.eq("tags s4-episode_10 is a pair", tags_str("demon_slayer_s4-episode_10.srt.zst"), "E10 P4x10 S4")
do
  H.reset()
  local function pairs_of(m) local o = {} for _, x in ipairs(m) do o[#o + 1] = x.season .. "x" .. x.ep end table.sort(o) return table.concat(o, " ") end
  H.eq("cour arc title: wildcard only", pairs_of(match.calculate_cour_mappings(10, 85937, 1, true)), "0x10")
  local ve, vp = match.build_valid_mapping_sets(match.calculate_cour_mappings(10, 85937, 1, true))
  local files = { "/k/Demon Slayer - 10.srt", "/k/demon_slayer_s4-episode_10.srt.zst", "/k/Demon Slayer S4 - 09.ass" }
  H.eq("arc: stated season beats bare number", match.find_matching_episode_file(files, 1, 10, ve, vp), "/k/demon_slayer_s4-episode_10.srt.zst")
  H.eq("arc: bare number accepted when alone", match.find_matching_episode_file({ files[1], files[3] }, 1, 10, ve, vp), "/k/Demon Slayer - 10.srt")
  H.eq("arc: explicit wrong episode rejected", match.find_matching_episode_file({ files[3] }, 1, 10, ve, vp), nil)
end

-- Real TMDB shapes. Dan Da Dan (240411): one 24-episode season whose second
-- cour starts at E13 (196-day air-date gap); providers call that cour S2.
do
  H.reset()
  match._tmdb_season_info = function() return { [1] = 24, cours = { [1] = { 13 } }, v = 2 } end
  local function pairs_of(m) local o = {} for _, x in ipairs(m) do o[#o + 1] = x.season .. "x" .. x.ep end table.sort(o) return table.concat(o, " ") end
  H.eq("dandadan E17: absolute + cour label S2E05", pairs_of(match.calculate_cour_mappings(17, 240411, nil)), "1x17 2x5")
  H.eq("dandadan E12: first cour, no label", pairs_of(match.calculate_cour_mappings(12, 240411, nil)), "1x12")
  H.eq("dandadan provider S2E05 file: absolute twin 17", pairs_of(match.calculate_cour_mappings(5, 240411, 2)), "1x17 2x5")
  local ve, vp = match.build_valid_mapping_sets(match.calculate_cour_mappings(17, 240411, nil))
  local pool = { "/c/Crunchyroll_Dandadan-16_S2-04.ass.zst", "/c/NETFLIX_Dandadan-05.ass.zst" }
  H.eq("dandadan E17 real data: wrong pool -> nothing", match.find_matching_episode_file(pool, 1, 17, ve, vp), nil)
  H.eq("dandadan E17 real data: S2 - 05 accepted",
    match.find_matching_episode_file({ pool[1], pool[2], "/c/[SubsPlease] Dandadan S2 - 05 (1080p).ass" }, 1, 17, ve, vp),
    "/c/[SubsPlease] Dandadan S2 - 05 (1080p).ass")
  -- Demon Slayer (85937): Swordsmith Village is a real TMDB season (4), so
  -- no cour label may shadow it.
  match._tmdb_season_info = function() return { [1] = 26, [2] = 7, [3] = 11, [4] = 11, [5] = 8, cours = {}, v = 2 } end
  H.eq("demon slayer abs 54 = S4E10", pairs_of(match.calculate_cour_mappings(54, 85937, nil)), "1x54 4x10")
  match._tmdb_season_info = nil

  -- Without TMDB data the cour guesses are weak: a guessed pair is accepted
  -- unless the name's own absolute count says it is another episode.
  local gve, gvp = match.build_valid_mapping_sets(match.calculate_cour_mappings(17, nil, nil))
  H.eq("no TMDB: guess pair (2,4) is marked guess", gvp[2] and gvp[2][4], "guess")
  H.eq("no TMDB: 16_S2-04 contradicted by its absolute 16", match.find_matching_episode_file({ pool[1] }, 1, 17, gve, gvp), nil)
  H.eq("no TMDB: 17_S2-05 accepted", match.find_matching_episode_file({ pool[1], "/c/Crunchyroll_Dandadan-17_S2-05.ass.zst" }, 1, 17, gve, gvp), "/c/Crunchyroll_Dandadan-17_S2-05.ass.zst")
end
