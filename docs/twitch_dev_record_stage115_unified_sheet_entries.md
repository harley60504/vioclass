# Stage 115 — Unified Sheet Template and Emote Entry Cleanup

## Summary

This stage standardizes the Twitch chat-related sheet UI on the shared responsive sheet template and removes remaining ad-hoc bottom sheet entry points from the active chat/player flow.

## Changed

- Added `showTwitchUnifiedSheet` to `twitch_responsive_sheet.dart`.
- Updated chat appearance sheet to use the unified sheet header/scaffold.
- Updated chat message context sheet to use the unified sheet header/scaffold.
- Added dedicated sheet entry helpers:
  - `showTwitchEmotePickerSheet`
  - `showTwitchChannelPointsSheet`
  - `showTwitchPredictionBetSheet`
- Updated watch pages to open emotes/channel points/prediction bet through the sheet-specific helper functions instead of building responsive sheets inline.
- Kept the removed mention-history flow out of this stage.
- Kept emote recent/favorite/multi-select behavior from Stage 114.

## Active Sheet Model

The active sheets remain separate by feature, but now share the same outer template concept:

- Emote picker: emote content only
- Channel points: channel points content only
- Prediction bet: prediction form content only
- Chat appearance: appearance settings only
- Message context: selected message reply context only

The shared layer handles responsive popup/bottom-sheet behavior, header, close action, refresh action, and sizing.
