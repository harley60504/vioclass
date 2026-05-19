# Stage 226 - Android media_kit Picture-in-Picture

## Summary

Added Android Picture-in-Picture support for the media_kit Watch player.

## Architecture

PiP is split by responsibility:

- Android native bridge
  - `android/app/src/main/kotlin/com/example/new_twitch_app/TwitchPipBridge.kt`
  - owns Android Activity PiP calls
  - checks device support
  - notifies Flutter when PiP mode changes

- Android Activity wiring
  - `android/app/src/main/kotlin/com/example/new_twitch_app/MainActivity.kt`
  - attaches the MethodChannel bridge
  - forwards `onPictureInPictureModeChanged`

- Flutter platform controller
  - `lib/features/twitch/platform/android_pip/twitch_android_pip_controller.dart`
  - exposes `enterPictureInPicture()`
  - exposes `isInPictureInPictureMode`
  - notifies Watch UI through `ChangeNotifier`

- Watch player UI
  - `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`
  - listens to the PiP controller
  - hides non-video chrome while PiP is active

- Player controls
  - `lib/features/twitch/presentation/widgets/watch/player/twitch_player_pip_button.dart`
  - Android-only PiP button
  - calls the Flutter controller

- Manifest
  - `android/app/src/main/AndroidManifest.xml`
  - enables `android:supportsPictureInPicture="true"`
  - enables `android:resizeableActivity="true"`

## Behavior

- PiP button appears only on Android when the device supports PiP.
- Entering PiP keeps only the media_kit video surface visible.
- Chat, controls, stream metadata, sheets, and other overlays are hidden while PiP is active.
- Returning from PiP restores the normal Watch player UI.

## Build/Test

```powershell
flutter clean
flutter pub get
flutter run -d <android-device-id>
```

APK:

```powershell
flutter build apk --release
```
