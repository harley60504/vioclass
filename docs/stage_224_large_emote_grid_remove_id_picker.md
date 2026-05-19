# Stage 224 - Large Emote Grid and Remove Duplicate ID Picker

## Summary

Updated the normal emote picker to look closer to the large card grid shown in the reference screenshot, and removed the duplicate Channel Points official emote ID picker path.

## Changes

### Normal Emote Picker

The normal emote picker grid now uses larger visual cards:

- larger card max width
- larger image area
- image + emote name only
- no provider / scope / source text in cards
- favorite remains long press
- favorite star remains as a small corner indicator
- locked and zero-width markers remain as compact corner indicators

Affected grids:

- third-party provider grid
- recent / favorite mixed grid
- Twitch official emote grid

### Channel Points Picker Cleanup

Removed the duplicate `TwitchOfficialEmoteIdPickerSheet` file and removed the old public wrapper from `twitch_emote_picker_sheet.dart`.

Channel Points should use the unified overlay:

```text
ChannelPointEmoteMenuOverlay
```

This avoids maintaining two similar Channel Points emote selection UIs.

## Files Changed

- `lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_third_party_provider_emote_grid.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_mixed_emote_grid.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_official_emote_panel.dart`
- removed `lib/features/twitch/presentation/sheets/emote_picker/twitch_official_emote_id_picker_sheet.dart`

## Build Reminder

```powershell
flutter clean
flutter pub get
flutter run -d windows
```
