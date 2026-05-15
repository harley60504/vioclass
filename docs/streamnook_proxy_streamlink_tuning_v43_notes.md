# StreamNook Twitch HLS Proxy v43 - Streamlink-style tuning

## Scope

This patch only touches the new playback proxy path:

`lib/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart`

It keeps the current raw proxy route design:

- Internal media_kit playback: `http://127.0.0.1:<port>/stream.ts`
- External mpv test command: same `/stream.ts` route
- No HLS playlist playback path is reintroduced for the main player

## Changes

### 1. Segment-aware replay soft buffer

The live byte bus now avoids trimming replay bytes inside the current media segment.

Before v43, the replay buffer was capped at 448 KB. For 1080p60 Twitch streams, this can cut the current TS/fMP4 segment in the middle, so a new client may start from partial H264 data and print errors such as:

- `non-existing PPS 0 referenced`
- `no frame!`

v43 keeps the current segment intact and only uses an emergency hard cap for pathological segments.

### 2. Init map byte cache

`EXT-X-MAP` / init map data is cached by URL. If the same init map is needed again, the proxy reuses cached bytes instead of refetching.

This follows Streamlink's idea of caching initialization sections/maps for HLS/fMP4 streams.

### 3. Adaptive playlist reload backoff

Playlist polling is still low-latency, but if the playlist has not changed, v43 backs off gradually instead of hammering the playlist endpoint at the minimum delay.

- Future/prefetch playlists use a lower cap.
- Normal-only playlists use a slightly larger cap.
- Once the playlist changes again, the reload cadence becomes fast again.

### 4. Writer live-edge catch-up

If the writer falls too far behind the latest playable sequence, it skips stale candidates at a segment boundary and resumes near the current live edge.

This is intended to reduce first-entry or reconnect lag without forcing tiny media_kit/mpv cache settings.

## Notes

This patch does not change player cache settings. media_kit should remain at its default buffer setting after v40/v42.

