# StreamNook Watch Player v51

PATCH VERSION: watch_player_area_responsive_live_reconnect_v51

## Changes

- Fixed compact/mobile overflow in the player top action bar.
- Fixed compact/mobile overflow in the bottom control bar by switching to a two-row layout when width is narrow.
- LIVE now reconnects to the current Dart raw proxy URL (`/stream.ts`) instead of only seeking to media_kit duration.
  - Raw proxy streams are not reliably seekable, so reopening the same proxy route is closer to opening the same URL in external mpv.
- Kept chat and fullscreen separated.
- Kept Debug under More > Debug and hidden on Android/iOS.
- Re-anchored More / Debug menus to the actual More button to prevent submenu drifting toward the chat area.
