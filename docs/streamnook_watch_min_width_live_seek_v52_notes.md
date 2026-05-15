# StreamNook Watch Player v52

## Files

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

## Changes

- Added a minimum control-bar content width to avoid repeated Flutter overflow warnings on very narrow widths.
- When the available width is smaller than the minimum, the bottom control bar becomes horizontally scrollable instead of squeezing controls until they overflow.
- Moved the LIVE state into the time label area.
- The time label area is now the clickable live-edge control.
- The label shows red `LIVE` only when media_kit is close enough to the seekable tail.
- When not close to the tail, the same position shows `position / duration` instead of `LIVE`.
- Clicking the time/LIVE area now seeks media_kit to the seekable range tail instead of reopening the raw proxy URL.

## Version

`PATCH VERSION: watch_player_area_min_width_live_time_seek_v52`
