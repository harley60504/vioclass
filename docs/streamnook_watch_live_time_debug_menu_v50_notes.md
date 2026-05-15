# StreamNook Watch Player v50

PATCH VERSION: watch_player_area_live_time_anchored_debug_v50

## Changes

- Fixed the second-level Debug menu position.
  - It now anchors near the More button instead of using a hard-coded screen-right position.
- Added media_kit playback time display next to the live progress slider.
  - Format: `position / duration`.
- LIVE label is now clickable.
  - Clicking LIVE seeks media_kit to the current duration edge and resumes playback.
- Kept Debug as a second-level menu only.
  - More → Debug → Copy Dart Proxy URL / Copy mpv Proxy command.
- Kept Android / iOS Debug hidden behavior from the previous version.
- Does not change chat/fullscreen separation.

## Files

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`
