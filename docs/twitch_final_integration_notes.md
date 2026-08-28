# Twitch Final Integration Notes

## Current State Sources

- Watch page owns route-level state in `TwitchWatchPageState`; feature controllers live under `presentation/watch/controllers`.
- Playback mode is represented by `TwitchWatchPlaybackKind`: `live`, `liveDvr`, `vod`, and `clip`.
- `TwitchPlaybackSessionController` owns the latest reusable playback snapshot and validates the media URI before WatchPage or mini-player reuses it.
- In-app mini-player keeps a `TwitchMiniPlayerEntry` with playback snapshot plus optional `TwitchPlaylistPlayerRuntime`; it moves the active video surface instead of opening a new player when possible.
- Android PiP is controlled by `TwitchAndroidPipController`; WatchPage and mini-player only enable auto PiP when the setting allows it, while app-internal navigation should keep using the mini-player path.
- Live chat and VOD replay chat both render through `TwitchChatMessageFeed`; message tiles share `TwitchChatMessageVisualMetrics` and the same context sheet entry.

## Small-Scope Order

1. Chat polish: keep message tiles, pinned messages, context sheet, link previews, emote picker, and special messages using shared typography and localized copy.
2. Playback polish: keep WatchPage, bottom controls, mini-player, VOD, Clip, and DVR labels driven by the explicit playback kind and current runtime flags.
3. PiP/settings polish: keep Android PiP as a background/system action and mini-player as the in-app return-home action.
4. Drops/channel points polish: remove patch-era markers, keep reward sheets clean, and avoid changing Channel Points payload construction.
5. VOD/Clip/DVR polish: keep replay chat and quality switching states explicit without touching persisted query hashes or low-level player runtime behavior.

## Validation Rule

After each small scope, run `flutter analyze`, clean generated Windows plugin noise if it appears, commit the allowed files, and push `HEAD:main`.
