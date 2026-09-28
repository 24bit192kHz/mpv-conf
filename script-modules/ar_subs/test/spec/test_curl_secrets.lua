-- Spec: ar_subs.util.curl_secrets
local H = require "harness"
local cs = require "ar_subs.util.curl_secrets"

local function joined(t) return table.concat(t, " ") end

-- SubSource: X-API-Key header + URL leave argv
local args, stdin = cs.protect({ "curl", "--fail", "--silent", "-H", "X-API-Key: sk_SECRET",
  "-H", "Accept: application/json", "https://api.subsource.net/api/v1/movies/search?q=x" })
H.eq("header+url: argv keeps plain flags", joined(args), "curl --fail --silent --config -")
H.eq("header+url: stdin carries both headers and url", stdin,
  'header = "X-API-Key: sk_SECRET"\nheader = "Accept: application/json"\n'
  .. 'url = "https://api.subsource.net/api/v1/movies/search?q=x"\n')
H.ok("header+url: key absent from argv", not joined(args):find("SECRET", 1, true))

-- SubDL download: ?api_key= in URL, -o / -w stay
args, stdin = cs.protect({ "curl", "-sS", "-o", "/tmp/x.zip", "-w", "%{http_code}",
  "https://dl.subdl.com/subtitle/1.zip?api_key=K" })
H.eq("url key: -o and -w kept in order", joined(args), "curl -sS -o /tmp/x.zip -w %{http_code} --config -")
H.eq("url key: stdin url", stdin, 'url = "https://dl.subdl.com/subtitle/1.zip?api_key=K"\n')

-- TVDB login: JSON body with quotes is escaped
args, stdin = cs.protect({ "curl", "-sS", "-X", "POST", "-H", "Content-Type: application/json",
  "-d", '{"apikey":"T"}', "-w", "\n%{http_code}", "https://api4.thetvdb.com/v4/login" })
H.eq("post body: -X POST and -w kept", joined(args), "curl -sS -X POST -w \n%{http_code} --config -")
H.eq("post body: quotes escaped in data", stdin,
  'header = "Content-Type: application/json"\ndata = "{\\"apikey\\":\\"T\\"}"\n'
  .. 'url = "https://api4.thetvdb.com/v4/login"\n')

-- backslashes and control chars survive quoting
local _, s2 = cs.protect({ "curl", "-H", 'A: b\\c"d\te', "https://x" })
H.eq("quote escapes backslash, quote, tab", s2, 'header = "A: b\\\\c\\"d\\te"\nurl = "https://x"\n')

-- untouched cases
local plain = { "curl", "--version" }
local a3, s3 = cs.protect(plain)
H.eq("nothing secret: same table back", a3, plain)
H.eq("nothing secret: no stdin", s3, nil)
local notcurl = { "ffmpeg", "-i", "https://x" }
H.eq("non-curl argv untouched", (cs.protect(notcurl)), notcurl)

-- protect_command
local cmd = { name = "subprocess", args = { "curl", "-H", "X-API-Key: K", "https://x" },
  capture_stdout = true, playback_only = false }
local c2 = cs.protect_command(cmd)
H.eq("protect_command: copies options", c2.capture_stdout, true)
H.eq("protect_command: playback_only kept", c2.playback_only, false)
H.eq("protect_command: argv rewritten", joined(c2.args), "curl --config -")
H.eq("protect_command: original table not mutated", joined(cmd.args), "curl -H X-API-Key: K https://x")
local withstdin = { name = "subprocess", args = { "curl", "https://x" }, stdin_data = "q" }
H.eq("protect_command: existing stdin_data left alone", cs.protect_command(withstdin), withstdin)
local other = { name = "run", args = { "curl", "https://x" } }
H.eq("protect_command: non-subprocess left alone", cs.protect_command(other), other)
