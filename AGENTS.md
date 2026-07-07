# API Reference — subdl_ar.lua

This document is the authoritative reference for every external API consumed by
`subdl_ar.lua` and its module tree. It exists so that any agent modifying this
codebase can reason about auth flows, endpoint shapes, rate limits, and failure
modes without re-discovering them from live requests.

Last verified: 2026-07-07 against live API responses.

---

## 1. SubDL API v2

**Base URL:** `https://api.subdl.com`
**Docs:** https://subdl.com/developers
**Free tier:** 2,000 searches/day + 50 downloads/day (no credit card)
**Pro tier:** 30,000 searches/day + 2,000 downloads/day + AI features

### 1.1 Authentication

Every search request requires an `Authorization: Bearer <key>` header.

Download links on `dl.subdl.com` use the legacy `?api_key=<key>` query parameter
(embedded in the `sub.url` field from search results). The Bearer header is NOT
sent to `dl.subdl.com`.

Rate-limit headers on every response:
- `X-RateLimit-Limit` — total allowed in current window
- `X-RateLimit-Remaining` — remaining in current window
- `X-RateLimit-Reset` — Unix timestamp when the window resets

### 1.2 Endpoints

#### GET /api/v2/subtitles/search — Subtitle Search (PRIMARY)

**CRITICAL: The URL is `/api/v2/subtitles/search`, NOT `/api/v2/subtitles`.**
The bare `/api/v2/subtitles` returns HTTP 404.

Parameters (query string):

| Param        | Required                              | Description                              |
|--------------|---------------------------------------|------------------------------------------|
| sd_id        | One of sd_id/imdb_id/tmdb_id/film_name/file_name | SubDL internal ID            |
| imdb_id      | (same)                                | IMDb ID (e.g. tt1375666)                 |
| tmdb_id      | (same, but REQUIRES type)             | TMDB ID                                  |
| film_name    | (same)                                | Title search string                      |
| file_name    | (same)                                | Release filename                         |
| type         | Required with tmdb_id                 | movie or tv                              |
| languages    | No                                    | Comma-separated codes (e.g. ar,en)       |
| season       | No                                    | Season number (for TV)                   |
| episode      | No                                    | Episode number (for TV)                  |
| full_season  | No                                    | 1 to get a season pack                   |
| unpack       | No                                    | 1 to expand archives into single-file download URLs |
| subs_per_page| No                                    | Max results                              |

Example:
```
GET /api/v2/subtitles/search?film_name=Inception&languages=ar&unpack=1
Authorization: Bearer <key>
```

Response shape:
```json
{
  "status": true,
  "results": [
    {
      "sd_id": 2922,
      "type": "movie",
      "name": "Inception",
      "imdb_id": "tt1375666",
      "tmdb_id": 27205,
      "year": 2010,
      "slug": "inception"
    }
  ],
  "subtitles": [
    {
      "release_name": "Inception.2010.720p.BluRay.x264-GROUP",
      "name": "SUBDL::inception-arabic-3206930.zip",
      "lang": "arabic",
      "author": "dustinismail",
      "url": "/subtitle/3190917-3206930.zip?api_key=KEY",
      "subtitlePage": "/s/info/A2ds6YXG0O",
      "season": 0,
      "episode": null,
      "language": "AR",
      "framerate": 0,
      "fps": null,
      "hi": false,
      "episode_from": null,
      "episode_end": 0,
      "full_season": false,
      "unpack_files": []
    }
  ]
}
```

Key fields on each subtitle object:
- `url` — Relative download path on dl.subdl.com. Prepend `https://dl.subdl.com` to make absolute. Contains embedded `?api_key=`.
- `language` — Two-letter uppercase code (AR, EN).
- `lang` — Human-readable language name (arabic).
- `season` / `episode` — Server-side hints (0 = not applicable). Client matcher is authoritative.
- `unpack_files` — When unpack=1, contains per-file entries.
- `hi` — true if hearing-impaired.

Error response (no results):
```json
{ "status": false, "error": "not_found" }
```

Quota error:
```json
{
  "error": {
    "code": "quota_exceeded",
    "message": "Daily request quota exceeded.",
    "docs_url": "https://subdl.com/developers#errors"
  }
}
```

#### GET /api/v2/movies/search — Movie & TV Title Search

Returns posters and matched IDs. Not currently used by subdl_ar.lua.

Parameters:
| Param | Required | Description                                   |
|-------|----------|-----------------------------------------------|
| q     | Yes      | Search query (min 2 chars). Accepts IMDb ID.  |
| type  | No       | movie or tv                                   |
| limit | No       | 1-30 (default 10)                             |

Note: sd_id here is a string like "sd123456". In /subtitles/search it is a
number like 2922.

#### GET /api/v2/files/search — Filename Search

Not currently used by subdl_ar.lua.

Parameters:
| Param        | Required | Description              |
|--------------|----------|--------------------------|
| filename     | Yes      | Release filename          |
| languages    | No       | Comma-separated codes     |
| subs_per_page| No       | Max 30                    |

#### GET /api/v2/subtitles/{nId}/download — API Download (NOT USED)

Requires a numeric nId. format=zip (default) or format=file.
Our code does NOT use this. The nId from search results often does not resolve.
We use sub.url on dl.subdl.com instead.

#### Download via dl.subdl.com (ACTUAL DOWNLOAD PATH)

Download URLs come from sub.url in search results:

```
/subtitle/3190917-3206930.zip?api_key=KEY
```

Full URL: `https://dl.subdl.com/subtitle/3190917-3206930.zip?api_key=KEY`

The ?api_key= query parameter is required (embedded in sub.url from the API).
Response is a ZIP archive containing .srt file(s). Must be unzipped locally.

Download flow:
1. Search returns sub.url = /subtitle/3190917-3206930.zip?api_key=...
2. Prepend https://dl.subdl.com to get absolute URL
3. curl -o /tmp/sub.zip "https://dl.subdl.com/subtitle/3190917-3206930.zip?api_key=..."
4. unzip /tmp/sub.zip -d /tmp/sub_extract/
5. Read .srt files from the extracted directory

#### GET /api/v2/me — Account & Usage

Check plan status, search/download counters, AI quota.
Does NOT count against search quota.

Response:
```json
{
  "plan": { "is_pro": false, "name": "Free" },
  "usage": {
    "search":    { "used": 12, "limit": 2000, "remaining": 1988, "period": "day" },
    "downloads": { "used": 3,  "limit": 50,   "remaining": 47,   "period": "day" },
    "ai": {
      "translations": { "eligible": false, "free_trial_per_month": 1, "period": "month" }
    }
  }
}
```

### 1.3 Rate Limits and Backup Key Rotation

When the primary key is exhausted (429 or quota_exceeded), the script rotates
to SUBDL_API_KEY_BACKUP. The http module checks:
- HTTP status 429
- JSON body with error.code containing "quota_exceeded", "rate", or "limit"
- JSON body with error string containing the same keywords

On detection, the request is retried once with the backup key.

### 1.4 Gotchas

1. /api/v2/subtitles (without /search) returns 404. Always use /api/v2/subtitles/search.
2. tmdb_id REQUIRES the type param. Omitting type with tmdb_id returns an error.
3. Download URLs are ZIP files. The script must unzip them locally.
4. ?api_key= on download URLs is legacy but required for dl.subdl.com downloads.
5. season:0 and episode:null mean "not applicable" (movies, full-season packs).
6. Server-side season/episode are HINTS ONLY. Client matcher is authoritative.
7. Bearer auth on search, query-param auth on downloads. Different mechanisms.
8. sd_id type differs: string "sd123456" in /movies/search, number 2922 in /subtitles/search.

---

## 2. TMDB API v3

**Base URL:** `https://api.themoviedb.org/3`
**Auth:** API key as query parameter `?api_key=<key>` (NOT Bearer header)
**Rate limit:** 40 requests/10 seconds (free tier)

### 2.1 Endpoints We Use

#### GET /search/movie — Movie Search

```
GET /3/search/movie?api_key=KEY&query=TITLE&year=YEAR
```

Parameters:
| Param   | Required | Description                    |
|---------|----------|--------------------------------|
| api_key | Yes      | TMDB API key                   |
| query   | Yes      | Title string (URL-encoded)     |
| year    | No       | Release year filter            |

Response:
```json
{
  "results": [
    { "id": 27205, "title": "Inception", "release_date": "2010-07-15" }
  ]
}
```

#### GET /search/tv — TV Search

```
GET /3/search/tv?api_key=KEY&query=TITLE
```

Same shape as movie search but returns TV results.

#### GET /search/multi — Multi Search (Fallback)

```
GET /3/search/multi?api_key=KEY&query=TITLE&year=YEAR
```

Returns mixed results with media_type field. Used as fallback when
/search/movie returns no results.

#### GET /tv/{id} — TV Show Details (Season Info)

```
GET /3/tv/TMDB_ID?api_key=KEY
```

Returns season information including episode counts per season.
Used for cour mapping calculations (anime season/episode resolution).

Response (relevant fields):
```json
{
  "seasons": [
    { "season_number": 0, "episode_count": 6 },
    { "season_number": 1, "episode_count": 24 },
    { "season_number": 2, "episode_count": 24 }
  ]
}
```

### 2.2 Gotchas

1. Auth is via ?api_key= query parameter, NOT Bearer header.
2. Search results are paginated (20 per page by default). We only read the first result.
3. /search/multi returns mixed media_type — must filter results by type.
4. URL-encode all query parameters — use url_safe() helper.
5. Season 0 is "Specials" — excluded from cour mapping calculations.

---

## 3. TheTVDB API v4

**Base URL:** `https://api4.thetvdb.com/v4`
**Docs:** https://thetvdb.github.io/v4-api/
**Spec:** https://github.com/thetvdb/v4-api/blob/main/docs/swagger.yml
**Auth:** Two-step: POST /login with API key -> JWT bearer token (valid 1 month)

### 3.1 Authentication Flow

TVDB v4 uses JWT tokens, NOT direct API key auth.

Step 1 — Login:
```
POST https://api4.thetvdb.com/v4/login
Content-Type: application/json

{"apikey": "YOUR_V4_API_KEY"}
```

For user-supported keys with subscriber PIN:
```json
{"apikey": "KEY", "pin": "PIN"}
```

Response:
```json
{
  "status": "success",
  "data": { "token": "eyJhbGciOi..." }
}
```

Step 2 — Use JWT for subsequent requests:
```
Authorization: Bearer eyJhbGciOi...
```

The JWT is valid for 1 month. Our code caches it in memory (M._jwt) and
re-logins on script restart.

### 3.2 Endpoints We Use

#### POST /v4/login — Authentication

See section 3.1 above.

#### GET /v4/search — Series Search

```
GET /v4/search?query=TITLE&type=series
Authorization: Bearer JWT
```

Parameters:
| Param | Required | Description                                |
|-------|----------|--------------------------------------------|
| query | Yes      | Series title                               |
| type  | No       | Restrict to entity type (series, movie, person, company) |

Response:
```json
{
  "data": [
    {
      "id": 81485,
      "name": "Steins;Gate",
      "slug": "steins-gate",
      "type": "series",
      "aliases": ["Steins Gate"],
      "firstAired": "2011-04-05",
      "network": "TV Tokyo",
      "status": "Continuing"
    }
  ]
}
```

We use only the first result's `id` and `name`.

#### GET /v4/series/{id}/episodes/default — Episode List

```
GET /v4/series/SERIES_ID/episodes/default?page=0
Authorization: Bearer JWT
```

Parameters:
| Param | Required | Description           |
|-------|----------|-----------------------|
| page  | No       | Page number (0-based) |

Response:
```json
{
  "data": {
    "episodes": [
      {
        "id": 3564211,
        "seasonNumber": 1,
        "number": 1,
        "absoluteNumber": 1,
        "title": "Prologue",
        "firstAired": "2011-04-05"
      }
    ],
    "links": {
      "previous": null,
      "self": "https://api4.thetvdb.com/v4/series/81485/episodes/default?page=0",
      "next": "https://api4.thetvdb.com/v4/series/81485/episodes/default?page=1",
      "total_items": 48
    }
  }
}
```

Key fields:
- `absoluteNumber` — The absolute episode number across all seasons (used for anime cour resolution)
- `seasonNumber` — Season number
- `number` — Episode number within the season
- `links.next` — If present, more pages available

Our code iterates pages until it finds the episode where absoluteNumber matches
the target absolute episode number, returning the corresponding season/episode pair.

### 3.3 Other Useful Endpoints (Not Currently Used)

| Endpoint                                  | Description                         |
|-------------------------------------------|-------------------------------------|
| GET /v4/series/{id}                       | Series base record                  |
| GET /v4/series/{id}/extended              | Series with actors, artworks, etc.  |
| GET /v4/series/{id}/episodes/{season}/{episode} | Specific episode              |
| GET /v4/movies/{id}                       | Movie base record                   |
| GET /v4/search?query=X&type=movie         | Movie search                        |
| GET /v4/languages                         | List all languages                  |
| GET /v4/updates?since=TIMESTAMP           | Changed records since timestamp     |

### 3.4 Gotchas

1. You CANNOT use the API key directly as a Bearer token. You must POST /login first.
2. Without a subscriber PIN, omit "pin" entirely from the login body (don't send empty string).
3. JWT tokens expire after 1 month. The script caches in memory and re-logins on restart.
4. Episode pages are 0-indexed. Start at page=0.
5. absoluteNumber is across ALL seasons — essential for anime where episodes are numbered sequentially.
6. The "score" field across entities is a popularity hint, not a quality score.

---

## 4. Common Patterns Across All APIs

### 4.1 Auth Mechanism Summary

| API     | Auth Method              | Where Key Comes From        |
|---------|--------------------------|-----------------------------|
| SubDL   | Bearer header (search)   | SUBDL_API_KEY in .env       |
| SubDL   | ?api_key= (downloads)    | Embedded in sub.url from API|
| TMDB    | ?api_key= query param    | TMDB_API_KEY in .env        |
| TVDB    | JWT Bearer (after login) | TVDB_API_KEY in .env        |

### 4.2 Key Loading Priority

Keys are loaded in this order (first non-empty wins):
1. mpv script-opts (subdl_ar.conf)
2. Environment variables (os.getenv)
3. .env file (~/config/mpv/.env)

### 4.3 Error Handling Contract

All APIs return JSON error bodies. The http module checks:
- HTTP status codes (401, 403, 404, 429, 500)
- JSON error codes/messages for quota/rate limiting
- Empty or nil response bodies

### 4.4 .env File Format

```
SUBDL_API_KEY=your-key-here
SUBDL_API_KEY_BACKUP=
TMDB_API_KEY=your-key-here
TVDB_API_KEY=your-key-here
USE_TVDB_COUR=yes
```

Boolean options in script-opts/subdl_ar.conf must use yes/no (not true/false)
because mpv's options.read_options treats true/false as strings.
