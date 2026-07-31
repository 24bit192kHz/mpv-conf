-- Spec: ar_subs.util.media
local H = require "harness"
local media = require "ar_subs.util.media"

-- Reset catalog to empty (default state) before each conceptual section.
media._reset_catalog()

-- clean_title
H.eq("clean_title('1. The Beginning')", media.clean_title("1. The Beginning"), "The Beginning")
H.eq("clean_title('01 - Foo')", media.clean_title("01 - Foo"), "Foo")
H.eq("clean_title dots to spaces", media.clean_title("Foo.Bar"), "Foo Bar")
H.eq("clean_title underscores to spaces", media.clean_title("Foo_Bar"), "Foo Bar")
H.eq("clean_title year in parens removed", media.clean_title("Show.Name.(2023)"), "Show Name")
H.eq("clean_title keeps bare year (no parens)", media.clean_title("foo.bar_2023"), "foo bar 2023")
H.eq("clean_title trailing dash removed", media.clean_title("Foo - "), "Foo")
H.eq("clean_title collapses spaces", media.clean_title("a   b"), "a b")
H.eq("clean_title trims whitespace", media.clean_title("  hello  "), "hello")
H.eq("clean_title(nil) -> nil", media.clean_title(nil), nil)
H.eq("clean_title empty -> empty", media.clean_title(""), "")

-- normalize_path_key
H.eq("path_key lowercases", media.normalize_path_key("/mnt/Foo/Bar.MKV"), "/mnt/foo/bar.mkv")
H.eq("path_key backslash to slash", media.normalize_path_key("C:\\a\\B"), "c:/a/b")
H.eq("path_key collapses slashes", media.normalize_path_key("//dup//slash"), "/dup/slash")
H.eq("path_key nil -> nil", media.normalize_path_key(nil), nil)
H.eq("path_key empty -> nil", media.normalize_path_key(""), nil)
H.eq("path_key trims whitespace", media.normalize_path_key("  /foo  "), "/foo")

-- normalize_stem_key
H.eq("stem removes stopwords", media.normalize_stem_key("Show.Name.S01E01.1080p"), "show name s01e01")
H.eq("stem strips group and tech", media.normalize_stem_key("[Group] Title E01 X265"), "title")
H.eq("stem(nil) -> empty", media.normalize_stem_key(nil), "")
H.eq("stem single char -> empty (filter #w>1)", media.normalize_stem_key("a"), "")
H.eq("stem strips extension", media.normalize_stem_key("file.srt"), "file")
H.eq("stem paren content removed", media.normalize_stem_key("Foo (2020) Bar"), "foo bar")

-- classify_content_type with empty catalog (default) returns nil, nil
H.eq_n("classify empty catalog returns nil,nil", { media.classify_content_type("/mnt/x/foo.mkv") }, { nil, nil })
H.eq("classify nil path", media.classify_content_type(nil), nil)
media._reset_catalog()

-- With injected catalog.
media.set_catalog(
  { ["/mnt/anime/show.mkv"] = "anime" },
  { ["show.mkv"] = { anime = 2 } },
  { ["my show"] = { tv = 3 } }
)
H.eq_n("classify catalog-exact", { media.classify_content_type("/mnt/anime/show.mkv") }, { "anime", "catalog-exact" })
H.eq_n("classify catalog-basename", { media.classify_content_type("/mnt/x/Show.MKV") }, { "anime", "catalog-basename" })
H.eq_n("classify catalog-stem", { media.classify_content_type("/mnt/x/My.Show.mkv") }, { "tv", "catalog-stem" })
H.eq_n("classify no match", { media.classify_content_type("/mnt/x/unrelated.mkv") }, { nil, nil })
media._reset_catalog()

-- normalize_title_candidates
local function list(t) local o = {} for i, v in ipairs(t) do o[i] = tostring(v) end return "{" .. table.concat(o, ", ") .. "}" end
H.same("ntc simple title", media.normalize_title_candidates("Breaking Bad"), { "Breaking Bad" })
H.same("ntc parens stripped (year removed by clean_title, deduped)", media.normalize_title_candidates("Foo (2020) Bar"), { "Foo Bar" })
H.same("ntc dash split", media.normalize_title_candidates("Foo - Bar (2020)"), { "Foo - Bar", "Foo", "Foo Bar" })
H.same("ntc colon split", media.normalize_title_candidates("One Piece: Gold"), { "One Piece: Gold", "One Piece" })
H.same("ntc truncates long", media.normalize_title_candidates("A B C D"), { "A B C D", "A B C" })
H.same("ntc nil -> {}", media.normalize_title_candidates(nil), {})

-- merge_candidates
H.same("merge dedupes", media.merge_candidates({ "a", "b", "a" }, { "b", "c" }), { "a", "b", "c" })
H.same("merge nil primary", media.merge_candidates(nil, { "x" }), { "x" })
H.same("merge nil extra", media.merge_candidates({ "x" }, nil), { "x" })
H.same("merge case-insensitive dedupe", media.merge_candidates({ "Foo", "foo" }, {}), { "Foo" })
H.same("merge empty strings dropped", media.merge_candidates({ "", "x", "" }, {}), { "x" })

-- path_title_candidates adds BOTH parent and grandparent folder names.
H.same("ptc parent + grandparent folders", media.path_title_candidates("/media/Movies/Inception (2010)/file.mkv"), { "Inception", "Movies" })
H.same("ptc season folder scrubbed, grandparent kept", media.path_title_candidates("/media/TV/Season 01/file.mkv"), { "TV" })
H.same("ptc nil -> {}", media.path_title_candidates(nil), {})

-- limit_queries
H.same("limit_queries under max unchanged", media.limit_queries({ "a", "b" }, 5), { "a", "b" })
H.same("limit_queries truncates", media.limit_queries({ "a", "b", "c", "d" }, 2), { "a", "b" })
H.same("limit_queries nil passes through", media.limit_queries(nil, 5), nil)
H.same("limit_queries nil max passes through", media.limit_queries({ "a" }, nil), { "a" })

-- dedupe_queries
H.same("dedupe removes dups", media.dedupe_queries({ "a", "b", "a", "c", "b" }), { "a", "b", "c" })
H.same("dedupe drops empties", media.dedupe_queries({ "", "a", "" }), { "a" })
H.same("dedupe nil -> {}", media.dedupe_queries(nil), {})

-- extract_series_info
H.eq_n("series S01E02", { media.extract_series_info("Breaking.Bad.S01E02.mkv") }, { "Breaking Bad", 1, 2 })
H.eq_n("series lowercase s03e04", { media.extract_series_info("house.of.the.dragon.s03e04.dv.hdr.2160p.web.h265-cakes") }, { "house of the dragon", 3, 4 })
H.eq_n("series 1x05", { media.extract_series_info("My.Show.1x05.WEB-DL") }, { "My Show", 1, 5 })
H.eq_n("series daily YYYY.MM.DD", { media.extract_series_info("Daily.Show.2020.03.15.720p") }, { "Daily Show", 20, 315 })
H.eq_n("series season pack S02", { media.extract_series_info("My.Show.S02.720p") }, { "My Show", 2, nil })
H.eq_n("series no match", { media.extract_series_info("plain.filename") }, { nil, nil, nil })
H.eq_n("series strips [Group]", { media.extract_series_info("[Group] Show.S03E10.mkv") }, { "Show", 3, 10 })

-- extract_anime_info
H.eq_n("anime [Erai] Foo - 01", { media.extract_anime_info("[Erai-raws] Foo - 01 [1080p]") }, { "Foo", nil, 1, nil })
H.eq_n("anime Title S2 - 10 (dots preserved)", { media.extract_anime_info("Anime.Title S2 - 10") }, { "Anime.Title", 2, 10, nil })
H.eq_n("anime Title - 12 (space)", { media.extract_anime_info("Anime Title - 12") }, { "Anime Title", nil, 12, nil })
H.eq_n("anime range Foo - 01~12", { media.extract_anime_info("Foo - 01~12") }, { "Foo", nil, 1, nil })
H.eq_n("anime Foo E05", { media.extract_anime_info("Foo E05") }, { "Foo", nil, 5, nil })
H.eq_n("anime 1080p-as-ep rejected", { media.extract_anime_info("Movie - 1080p") }, { nil, nil, nil, nil })
H.eq_n("anime no group, no E pattern", { media.extract_anime_info("plain.filename") }, { nil, nil, nil, nil })
H.eq_n("anime [Group] Title E01 X265", { media.extract_anime_info("[Group] Title E01 X265") }, { "Title", nil, 1, nil })

-- extract_movie_info
H.eq_n("movie Matrix.1999.1080p.BluRay", { media.extract_movie_info("The.Matrix.1999.1080p.BluRay.mkv") }, { "The Matrix", "1999" })
H.eq_n("movie Inception (2010) - paren left in title (existing behavior)", { media.extract_movie_info("Inception.(2010).1080p") }, { "Inception (", "2010" })
H.eq_n("movie bracket year", { media.extract_movie_info("Film [2020]") }, { "Film", "2020" })
H.eq_n("movie plain title no year", { media.extract_movie_info("Random.Movie.Title") }, { "Random Movie Title", nil })
H.eq_n("movie 1080p rejected as year", { media.extract_movie_info("Movie.1080p.web") }, { "Movie 1080p web", nil })
-- extract_movie_info emits mp.msg.info DEBUG lines; verify side effect captured.
H.ok("extract_movie_info logs DEBUG input", (function()
  local before = #H.logs
  media.extract_movie_info("Foo.2020.mkv")
  return #H.logs > before
end)())

-- resolve_media_info with empty catalog (classify returns nil)
local function resolve_summary(info)
  return info.content_type .. "|title=" .. tostring(info.title) .. "|s=" .. tostring(info.season) .. "|e=" .. tostring(info.episode) .. "|anime=" .. tostring(info.is_anime)
end
H.eq("resolve TV S01E01", resolve_summary(media.resolve_media_info("/mnt/z/Breaking.Bad.S01E01.mkv", nil)), "tv|title=Breaking Bad|s=1|e=1|anime=false")
H.eq("resolve anime [Group]", resolve_summary(media.resolve_media_info("/mnt/z/[Erai-raws] Foo - 01 [1080p].mkv", nil)), "anime|title=Foo|s=1|e=1|anime=true")
H.eq("resolve TV 1x05", resolve_summary(media.resolve_media_info("/mnt/z/My.Show.1x05.WEB-DL.mkv", nil)), "tv|title=My Show|s=1|e=5|anime=false")
H.ok("resolve filename fallback when basename nil", media.resolve_media_info(nil, "Fallback.S01E01.mkv").filename == "Fallback.S01E01.mkv")
