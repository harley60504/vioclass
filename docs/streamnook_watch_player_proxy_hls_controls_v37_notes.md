# v37 Watch Player proxy HLS + controls fix

- Fix black screen / audio-only after v36 by using `proxy.playlistUrl` (`/playlist.m3u8`) as the playback URL instead of raw `proxy.streamUrl` (`/`).
- Raw stream URL can break on Twitch fMP4/CMAF playlists because init segments from `EXT-X-MAP` are not reliably emitted in a concatenated byte stream.
- Move Watch Page overlay controls into `Video.controls` so Windows video surface does not cover the Flutter top/bottom control bars.
- Debug copy now copies Dart Proxy HLS URL and mpv command for that HLS proxy URL.
