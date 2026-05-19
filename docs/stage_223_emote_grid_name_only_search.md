# Stage 223 - Emote Grid Name-only Search UI

## Summary

Updated both the Channel Points emote overlay and the normal emote picker grid to use a cleaner grid UI:

- Show emote image.
- Show emote name.
- Do not show internal emote IDs in the visible card UI.
- Keep search available.

## Files Changed

- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_emote_overlay.dart`
- `lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_sheet_models.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/twitch_official_emote_id_picker_sheet.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_widgets.dart`

## Channel Points Emote Overlay

### Before

Channel Points emote cards displayed:

- image
- emote token/name
- emote ID

### After

Channel Points emote cards now display:

- image
- emote token/name only

The selected value still returns the required internal emote ID for redemption, but users do not see the ID in the overlay.

Search now focuses on emote token/name instead of exposing ID-oriented search text.

## Modifier Picker

The modify-emote picker was changed from a list style into a grid style so it visually matches the choose-emote picker.

Modifier cards now display:

- modifier preview image
- modifier name/token

## Official Emote ID Picker

The Channel Points official emote ID picker still returns the required emote ID internally, but its visible grid now shows:

- image
- emote name

The confirmation dialog and visible `ID:` line were removed to make the flow closer to the normal emote sheet.

## Normal Emote Sheet

The regular emote picker grid cards were simplified to match the same visual direction:

- third-party cards show image + emote name
- official cards show image + emote name
- provider/scope labels are removed from cards
- locked and favorite indicators remain as small corner icons
- zero-width emotes keep a compact `ZW` marker

## Build Reminder

```powershell
flutter clean
flutter pub get
flutter run -d windows
```

For Android APK:

```powershell
flutter build apk --release
```
