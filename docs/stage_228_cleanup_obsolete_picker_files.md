# Stage 228 - Cleanup Obsolete Picker Files

## Summary

Removed obsolete duplicated emote picker implementations after the app moved to one unified emote picker sheet.

## Canonical Emote Picker

The only public normal emote picker entry is now:

```text
lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart
```

This file owns:

- Recent
- Favorite
- Twitch official emotes
- 7TV
- BTTV
- FFZ
- search
- long-press favorite
- large unified grid cards
- single `_EmoteEntry` page model

## Removed Files

The old Frosty sheet and the earlier split-panel implementation were removed:

```text
lib/features/twitch/presentation/sheets/twitch_frosty_emote_picker_sheet.dart
lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_models.dart
lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_widgets.dart
lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_panels.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_emote_picker_empty_state.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_favorite_emote_panel.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_mixed_emote_grid.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_official_emote_panel.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_recent_emote_panel.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/twitch_third_party_provider_emote_grid.dart
```

## Why

Keeping both the Frosty sheet and the original split-panel sheet caused confusion about which UI path was active. The unified sheet now contains the desired category logic and grid UI, so the old split files only created maintenance risk.

## Follow-up Check

Run:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run --release -d <android-device-id>
```

If an import error mentions any deleted `emote_picker/` panel file, that caller should be migrated to `showTwitchEmotePickerSheet(...)` from `twitch_emote_picker_sheet.dart`.
