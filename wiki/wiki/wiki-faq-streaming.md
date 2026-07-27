# FAQ: Streaming & YouTube

## (How) can I play YouTube playlists?

Pass the playlist URL to mpv. Use the actual playlist link (`https://www.youtube.com/playlist?list=...`), NOT a video in the playlist (`?v=...&list=...&index=...`).

## How can I change video quality on YouTube?

List available formats with `yt-dlp`:

```bash
yt-dlp -F https://www.youtube.com/watch?v=VIDEO_ID
```

Then play with a specific format:

```bash
mpv --ytdl-format 22 https://www.youtube.com/watch?v=VIDEO_ID
```

Mix video+audio formats:

```bash
mpv --ytdl-format 137+251 https://www.youtube.com/watch?v=VIDEO_ID
```

Use bestvideo up to 1440p with audio fallback:

```
ytdl-format=bestvideo[height<=?1440]+bestaudio/best
```
