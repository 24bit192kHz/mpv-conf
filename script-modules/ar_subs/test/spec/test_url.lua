-- Spec: ar_subs.util.url
local H = require "harness"
local url = require "ar_subs.util.url"

-- trim
H.eq("trim('  hello  ')", url.trim("  hello  "), "hello")
H.eq("trim('hello')", url.trim("hello"), "hello")
H.eq("trim(nil) returns empty string", url.trim(nil), "")
H.eq("trim(0) tostring", url.trim(0), "0")
H.eq("trim(123) tostring", url.trim(123), "123")
H.eq("trim preserves internal spaces", url.trim("  a b  c  "), "a b  c")
H.eq("trim tabs+newlines", url.trim("\t\n hello \r\n"), "hello")

-- strip_quotes
H.eq("strip_quotes double", url.strip_quotes('"hello"'), "hello")
H.eq("strip_quotes single", url.strip_quotes("'hello'"), "hello")
H.eq("strip_quotes mismatched leading only", url.strip_quotes('"hello'), '"hello')
H.eq("strip_quotes mismatched trailing only", url.strip_quotes('hello"'), 'hello"')
H.eq("strip_quotes no quotes", url.strip_quotes("hello"), "hello")
H.eq("strip_quotes with surrounding whitespace", url.strip_quotes('  "hello"  '), "hello")
H.eq("strip_quotes empty", url.strip_quotes('""'), "")
H.eq("strip_quotes single char inside", url.strip_quotes("'a'"), "a")

-- url_safe (RFC 3986 unreserved preserved)
H.eq("url_safe('hello')", url.url_safe("hello"), "hello")
H.eq("url_safe('a-b_c.d~e')", url.url_safe("a-b_c.d~e"), "a-b_c.d~e")
H.eq("url_safe('a b') space -> %20", url.url_safe("a b"), "a%20b")
H.eq("url_safe('a/b') slash -> %2F", url.url_safe("a/b"), "a%2Fb")
H.eq("url_safe('a&b=1')", url.url_safe("a&b=1"), "a%26b%3D1")
H.eq("url_safe('中文') multibyte utf8", url.url_safe("中"), string.format("%%%02X%%%02X%%%02X", 0xE4, 0xB8, 0xAD))
H.eq("url_safe(nil) -> empty", url.url_safe(nil), "")
H.eq("url_safe(123) tostring", url.url_safe(123), "123")
H.eq("url_safe('@') reserved", url.url_safe("@"), "%40")
H.eq("url_safe empty string", url.url_safe(""), "")

-- redact_url (preserves count return but first value is the string)
H.eq("redact single api_key", url.redact_url("https://x.com/api?api_key=secret&foo=bar"), "https://x.com/api?api_key=<redacted>&foo=bar")
H.eq("redact leading api_key with ?", url.redact_url("?api_key=SECRET"), "?api_key=<redacted>")
H.eq("redact ampersand api_key", url.redact_url("foo=1&api_key=K"), "foo=1&api_key=<redacted>")
H.eq("redact no api_key unchanged", url.redact_url("https://x.com/foo"), "https://x.com/foo")
H.eq("redact nil -> empty", url.redact_url(nil), "")
H.eq("redact number -> tostring", url.redact_url(12345), "12345")

-- basename
H.eq("basename('/p/file.mkv')", url.basename("/p/file.mkv"), "file")
H.eq("basename('file.mkv')", url.basename("file.mkv"), "file")
H.eq("basename dotted name returns stem before last ext", url.basename("/p/Breaking.Bad.S01E01.mkv"), "Breaking.Bad.S01E01")
H.eq("basename('/p/Foo.2020.1080p.mkv')", url.basename("/p/Foo.2020.1080p.mkv"), "Foo.2020.1080p")
H.eq("basename('noext') -> nil", url.basename("noext"), nil)
H.eq("basename('/.hidden') -> nil", url.basename("/.hidden"), nil)

-- sanitize_filename
H.eq("sanitize 'foo bar (2023).srt'", url.sanitize_filename("foo bar (2023).srt"), "foo_bar_2023.srt")
H.eq("sanitize 'Show [1080p].ass'", url.sanitize_filename("Show [1080p].ass"), "Show_1080p.ass")
H.eq("sanitize collapses underscores", url.sanitize_filename("a   b.srt"), "a_b.srt")
H.eq("sanitize collapses dashes", url.sanitize_filename("a---b.srt"), "a-b.srt")
H.eq("sanitize strips leading/trailing underscore", url.sanitize_filename("_foo_.srt"), "foo.srt")
H.eq("sanitize removes quotes", url.sanitize_filename("foo'bar\"baz.srt"), "foobarbaz.srt")
H.eq("sanitize no ext -> dot prefix", url.sanitize_filename("plainname"), "plainname.")
