# v34 Playback Ad-Aware Source Selector

This patch keeps the current new_twitch_app playback folder layout:

```text
lib/features/twitch/api/playback/
lib/features/twitch/models/playback/
lib/features/twitch/services/playback/
```

## What changed

- Added an ad-aware playback source selector inspired by the `twitch-hls-player-no-ads.crx` approach.
- The runtime now probes multiple Twitch playback contexts:
  - `web / site`
  - `android / autoplay`
  - `ios / site`
- It parses all returned master playlists, matches variants by quality, and prefers clean Android/iOS candidate URLs when the same quality exists.
- It marks fallback web variants as `hasAds = true` when no clean candidate exists.
- Default quality selection now prefers:
  1. non-ad source variants
  2. video variants over audio-only
  3. source/chunked quality
  4. highest height / fps / bandwidth

## Files changed

```text
lib/features/twitch/api/playback/twitch_playback_api_service.dart
lib/features/twitch/api/playback/twitch_playback_service.dart
lib/features/twitch/models/playback/twitch_m3u8_variant.dart
lib/features/twitch/models/playback/twitch_playback.dart
lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart
lib/features/twitch/services/playback/twitch_player_runtime.dart
```

## Notes

This patch does not remove or rewrite HLS media segments. It selects the cleanest candidate source before playback, which mirrors the important part of the CRX strategy:

```text
fetch normal/web playlist
fetch Android/autoplay playlist
match by quality
replace URL with clean candidate when available
```

If all clean candidates fail, playback still falls back to the normal web source.
