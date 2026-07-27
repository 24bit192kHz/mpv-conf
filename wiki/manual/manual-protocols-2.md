> reads until reaching 2 GiB or end of file.
>
> mpv slice://1g-+2g@cap.ts
>
> This starts reading from cap.ts after seeking 1 GiB, then
> reads until reaching 3 GiB or end of file.
>
> mpv slice://100m@appending://cap.ts
>
> This starts reading from cap.ts after seeking 100MiB, then
> reads until end of file.
> ```

`null://`

> Simulate an empty file. If opened for writing, it will discard all data.
> The `null` demuxer will specifically pass autoprobing if this protocol
> is used (while it's not automatically invoked for empty files).

`memory://data`

> Use the `data` part as source data.

`hex://data`

> Like `memory://`, but the string is interpreted as hexdump.
