# Stage 226B - Android Auto PiP on App Leave

## Summary

Added automatic Android Picture-in-Picture entry when the user leaves the app while the Watch player Activity is active.

## Behavior

When Android triggers `onUserLeaveHint()` — for example when the user presses Home or switches apps — `MainActivity` now asks the PiP bridge to enter Picture-in-Picture automatically.

Manual PiP button behavior from Stage 226 is still kept.

## Files Changed

- `android/app/src/main/kotlin/com/example/new_twitch_app/MainActivity.kt`
- `android/app/src/main/kotlin/com/example/new_twitch_app/TwitchPipBridge.kt`

## Notes

This first version is Activity-level auto PiP. It does not yet check from Flutter whether the current route is actually a Twitch Watch page or whether playback is currently active.

If auto PiP is too aggressive on non-player pages, the next stage should add a Flutter-side `setAutoPipEnabled(true/false)` method and only enable it while the media_kit Watch player is visible.

## Build/Test

```powershell
flutter clean
flutter pub get
flutter run -d <android-device-id>
```
