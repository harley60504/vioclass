# VioClass

VioClass is a Flutter Twitch client focused on watching streams, DVR/VOD playback, chat, clips, channel pages, drops, and a compact in-app mini player.

The project is experimental and optimized around a desktop/mobile viewing workflow where live streams, active DVR archives, regular VODs, clips, and chat can stay in one app instead of constantly jumping back to the browser.

## Features

- Live stream playback with quality selection.
- Active DVR support for streams that expose a growing archive, so the timeline can be dragged backward while the stream is still live.
- VOD and clip playback inside the app.
- Live chat, VOD replay chat, pinned messages, predictions, hype train, emotes, and channel points.
- Channel About, VOD, and Clips views with Twitch channel metadata and panel images.
- Drops and channel points pages with campaigns, inventory, stats, and claim/status information.
- In-app mini player and Android Picture-in-Picture support.
- Twitch OAuth / token setup through the app settings flow.

## Current Focus

The app is currently being refined around a shared playback session model:

- WatchPage and mini player should render the same playback state instead of rebuilding separate players.
- Live, DVR, VOD, and clip playback should preserve the correct timeline and chat mode when moving between pages.
- The UI is being kept close to Twitch/StreamNook-style viewing flows while staying native Flutter.

## Platforms

- Windows
- Android

Release builds are published from this repository when available.

## Development

Install Flutter, then run:

```bash
flutter pub get
flutter run -d windows
```

Useful checks:

```bash
flutter analyze
flutter build windows --release
flutter build apk --release
```
