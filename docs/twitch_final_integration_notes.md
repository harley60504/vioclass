# Twitch Final Integration Notes

## Current State Sources

- Watch page owns route-level state in `TwitchWatchPageState`; feature controllers live under `presentation/watch/controllers`.
- Playback mode is represented by `TwitchWatchPlaybackKind`: `live`, `liveDvr`, `vod`, and `clip`.
- `TwitchPlaybackSessionController` owns the latest reusable playback snapshot and validates the media URI before WatchPage or mini-player reuses it.
- In-app mini-player keeps a `TwitchMiniPlayerEntry` with playback snapshot plus optional `TwitchPlaylistPlayerRuntime`; it moves the active video surface instead of opening a new player when possible.
- Android PiP is controlled by `TwitchAndroidPipController`; WatchPage and mini-player only enable auto PiP when the setting allows it, while app-internal navigation should keep using the mini-player path.
- Live chat and VOD replay chat both render through `TwitchChatMessageFeed`; message tiles share `TwitchChatMessageVisualMetrics` and the same context sheet entry.
- Chat message styling is centered around `twitchChatTextStyle`, `TwitchChatMessageVisualMetrics`, and the split message widgets under `presentation/widgets/chat/message`; visible special-event copy should stay in the localization helpers instead of being duplicated in tiles.
- Watch chat composition is split between the WatchPage chat state methods, chat loaders, and `presentation/widgets/watch/chat`; VOD replay chat is a panel variant and should keep using the same runtime message tile path.
- Drops and Channel Points use separate services but share the Drops connection surface; visible labels should describe user outcomes such as authorization, inventory, rewards, and points without exposing token names.
- Settings should remain the switchboard for user-controlled playback/chat/PiP preferences; feature widgets should read the resolved flags instead of inventing local preference state.
- VOD, Clip, and live DVR all enter playback through explicit playback-kind state and playlist/runtime selection; UI copy can be polished independently, but access token requests, persisted query hashes, and player runtime behavior should not change during cleanup passes.

## Integration Boundaries

- Chat cleanup can safely adjust typography, chips, banners, context-sheet labels, preview copy, and localized special-message formatting.
- Playback cleanup should stay near WatchPage state methods, route guard handoff checks, mini-player entry handling, and player control copy.
- Android PiP cleanup should keep the distinction clear: app-internal navigation uses mini-player, OS backgrounding may enter PiP when the setting allows it.
- Drops cleanup can refine connection page copy, empty states, reward labels, and status presentation, while leaving claim payload construction and client IDs untouched.
- VOD/Clip/DVR cleanup should verify labels against `TwitchWatchPlaybackKind` and runtime flags before changing UI, because these modes share a lot of controls.

## Small-Scope Order

1. Chat polish: keep message tiles, pinned messages, context sheet, link previews, emote picker, and special messages using shared typography and localized copy.
2. Playback polish: keep WatchPage, bottom controls, mini-player, VOD, Clip, and DVR labels driven by the explicit playback kind and current runtime flags.
3. PiP/settings polish: keep Android PiP as a background/system action and mini-player as the in-app return-home action.
4. Drops/channel points polish: remove patch-era markers, keep reward sheets clean, and avoid changing Channel Points payload construction.
5. VOD/Clip/DVR polish: keep replay chat and quality switching states explicit without touching persisted query hashes or low-level player runtime behavior.

## Validation Rule

After each small scope, run `flutter analyze`, clean generated Windows plugin noise if it appears, commit the allowed files, and push `HEAD:main`.
