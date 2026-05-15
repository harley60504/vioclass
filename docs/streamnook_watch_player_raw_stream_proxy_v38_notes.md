# v38 Watch Player Raw Stream Proxy

- Reverts playback URL from `proxy.playlistUrl` back to `proxy.streamUrl`.
- This matches the old successful app behavior: media_kit/mpv receives a raw local live byte stream instead of a local `.m3u8` playlist.
- The goal is to avoid extra HLS buffering from media_kit/mpv and keep live-edge decisions inside Dart proxy.
- The debug menu now copies only the raw Dart Proxy URL and mpv command using that URL.

Version markers:

```text
PATCH VERSION: twitch_playlist_player_runtime_raw_stream_proxy_v38
PATCH VERSION: watch_player_area_raw_stream_proxy_controls_v38
```
