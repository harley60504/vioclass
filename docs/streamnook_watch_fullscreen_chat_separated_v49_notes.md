# StreamNook Watch v49 — fullscreen restored, chat separated

## Files

- `lib/features/twitch/services/window/twitch_fullscreen_controller.dart`

## Changes

- Keeps fullscreen and chat visibility as separate concepts.
- Restores desktop true fullscreen using the `window_manager` MethodChannel contract.
- Does not import `package:window_manager` in shared code, so Android/iOS builds do not need to parse the desktop plugin import.
- Uses the correct `setFullScreen` argument shape:

```dart
{'isFullScreen': true}
```

instead of passing a raw boolean.

## Platform behavior

- Windows/macOS/Linux:
  - fullscreen button controls OS-level fullscreen through `window_manager` channel if plugin is registered.
  - chat button only shows/hides chat.

- Android/iOS:
  - fullscreen button should remain hidden by `watch_page`.
  - immersive mode is handled through `SystemChrome`.
  - chat button only shows/hides chat.

## Version markers

- `PATCH VERSION: twitch_fullscreen_controller_desktop_method_channel_v49`
