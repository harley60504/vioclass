# Stage 125 - Chat engagement auto-hide correction

## Goal
Correct Stage 124 behavior based on the intended target: hide the official pinned chat banner and prediction notification when the chat panel becomes too short, without hiding the bottom channel-points / emote utility row.

## Changes
- `TwitchWatchChatPanel`
  - Keeps the bottom channel-points/emote utility bar visible.
  - Auto-hides official pinned chat when:
    - the chat panel height is too short, or
    - the keyboard is open.
  - Auto-hides prediction notification when:
    - the chat panel height is too short, or
    - the keyboard is open, or
    - the prediction is locked / closed, or
    - the prediction is resolved / canceled / refunded / ended.
  - Removes the delayed 5-second resolved-prediction hide behavior; ended/locked prediction banners are now hidden immediately.
  - Header pin / prediction buttons are disabled while their banners are auto-hidden by compact height.

## Notes
- This does not remove the channel-points utility button near the chat input.
- Prediction detail sheet remains available from other entry points if connected later; this only controls the chat notification banner.
