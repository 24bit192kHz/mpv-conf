## Network

`--user-agent=<string>`

Use `<string>` as user agent for HTTP streaming.

`--cookies=<yes|no>`

Support cookies when making HTTP requests. Disabled by default.

`--cookies-file=<filename>`

Read HTTP cookies from <filename>. The file is assumed to be in Netscape
format.

`--http-header-fields=<field1,field2>`

Set custom HTTP fields when accessing HTTP stream.

This is a string list option. See [List Options](manual-options-track.md) for details.

Example

```
mpv --http-header-fields='Field1: value1','Field2: value2' \
http://localhost:1234
```

Will generate HTTP request:

```
GET / HTTP/1.0
Host: localhost:1234
User-Agent: MPlayer
Icy-MetaData: 1
Field1: value1
Field2: value2
Connection: close
```

`--http-proxy=

`

URL of the HTTP/HTTPS proxy. If this is set, the `http_proxy` environment
is ignored. The `no_proxy` environment variable is still respected. This
option is silently ignored if it does not start with `http://`. Proxies
are not used for https URLs. Setting this option does not try to make the
ytdl script use the proxy.

`--tls-ca-file=<filename>`

Certificate authority database file for use with TLS. (Silently fails with
older FFmpeg versions.)

`--tls-verify`

Verify peer certificates when using TLS (e.g. with `https://...`).
(Silently fails with older FFmpeg versions.)

`--tls-cert-file`

A file containing a certificate to use in the handshake with the
peer.

`--tls-key-file`

A file containing the private key for the certificate.

`--referrer=<string>`

Specify a referrer path or URL for HTTP requests.

`--network-timeout=<seconds>`

Specify the network timeout in seconds (default: 60 seconds). This affects
at least HTTP. The special value 0 uses the FFmpeg defaults. If a
protocol is used which does not support timeouts, this option is silently
ignored.

Warning

This breaks the RTSP protocol, because of inconsistent FFmpeg API
regarding its internal timeout option. Not only does the RTSP timeout
option accept different units (seconds instead of microseconds, causing
mpv to pass it huge values), it will also overflow FFmpeg internal
calculations. The worst is that merely setting the option will put RTSP
into listening mode, which breaks any client uses. At time of this
writing, the fix was not made effective yet. For this reason, this
option is ignored (or should be ignored) on RTSP URLs. You can still
set the timeout option directly with `--demuxer-lavf-o`.

`--rtsp-transport=<lavf|udp|udp_multicast|tcp|http>`

Select RTSP transport method (default: tcp). This selects the underlying
network transport when playing `rtsp://...` URLs. The value `lavf`
leaves the decision to libavformat.

`--hls-bitrate=<no|min|max|<rate>>`

If HLS streams are played, this option controls what streams are selected
by default. The option allows the following parameters:
| no: | Don't do anything special. Typically, this will simply pick the
first audio/video streams it can find. |
| --- | --- |
| min: | Pick the streams with the lowest bitrate. |
| max: | Same, but highest bitrate. (Default.) |

Additionally, if the option is a number, the stream with the highest rate
equal or below the option value is selected.

The bitrate as used is sent by the server, and there's no guarantee it's
actually meaningful.
