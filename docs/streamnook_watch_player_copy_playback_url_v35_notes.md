# v35 Watch Player Copy Playback URL Debug

This patch adds a small debug copy menu to the Watch Player control bar.

## File changed

```text
lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart
```

## Added

- Debug bug icon near the quality selector.
- Copy current selected media playlist URL.
- Copy master playlist URL.
- Copy an `mpv` command with user-agent/referrer/origin headers.
- Copy playback debug JSON.

## Usage

Open a stream, click the bug icon in the bottom player control bar, then copy the current m3u8 URL or mpv command.

Example copied command format:

```bash
mpv --user-agent="Mozilla/5.0 ..." --referrer="https://www.twitch.tv/" --http-header-fields="Origin: https://www.twitch.tv" "<current-m3u8-url>"
```

The current media playlist URL is signed and temporary. Re-copy it after reload or quality changes.
