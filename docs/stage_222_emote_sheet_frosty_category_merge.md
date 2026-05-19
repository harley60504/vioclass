# Stage 222 - Emote Sheet Frosty Category Merge

## Summary

Merged the Frosty-style emote category logic back into the original VioClass/Twitch emote picker sheet.

## Files Changed

- `lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_models.dart`
- `lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_widgets.dart`

## Changes

### 1. Keep original emote sheet as the single entry

The original sheet remains the only public picker entry:

```text
showTwitchEmotePickerSheet(...)
```

No second Frosty picker sheet is introduced.

### 2. Add Frosty-style category/scope filtering

Added third-party emote scope filter chips for provider tabs:

- 全部
- 頻道
- Shared
- 全域
- ZW

These filters are shown only inside third-party provider tabs:

- BTTV
- 7TV
- FFZ

### 3. Favorite interaction changed to long press

The visible favorite star button was removed from emote cards.

New behavior:

- Tap: insert emote
- Long press: toggle favorite
- Favorited cards still show a small star indicator
- Card border becomes gold when favorited

This reduces accidental favorite toggles and keeps the grid cleaner.

### 4. Search remains inside original sheet

Search still filters by:

- emote name
- emote ID

For third-party provider tabs, search is combined with the selected Frosty-style scope filter.

## Notes

This stage intentionally avoids adding another emote picker sheet. The goal is to merge the better Frosty category logic into the existing original sheet while keeping the current app structure stable.
