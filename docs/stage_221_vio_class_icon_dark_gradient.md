# Stage 221 - VioClass Dark Gradient App Icon

## Summary

Updated the VioClass app icon direction to match the app's dark purple streaming UI theme.

## Changes

- Reworked `assets/app/vio_class_icon.svg`.
- Reworked `android/app/src/main/res/drawable/vio_class_icon.xml`.
- Changed the icon background from light white/pale purple to a purple-black night gradient direction.
- Enlarged the school/play icon mark so it remains readable at launcher icon size.
- Kept the VioClass concept:
  - school building outline
  - large central play triangle
  - clock
  - flag
  - streaming signal arcs

## Design Notes

- Background direction: stronger purple at top-left, darker black at bottom-right.
- Main mark: white school outline for contrast against the dark background.
- Play triangle and signal arcs: purple accent to stay consistent with the app theme.
- Layout: the building mark now occupies more of the icon canvas than the previous version.

## Build Reminder

After pulling the change locally, rebuild the APK:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

Output APK:

```text
build\app\outputs\flutter-apk\app-release.apk
```
