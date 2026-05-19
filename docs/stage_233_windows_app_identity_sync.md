# Stage 233 - Windows App Identity Sync

## Summary

Windows app identity was checked against Android and the current shared VioClass branding.

## Confirmed Current State

- Android app label is `VioClass`.
- Android launcher icon points to `@drawable/vio_class_icon`.
- Windows resource metadata already uses `VioClass` for:
  - `CompanyName`
  - `FileDescription`
  - `InternalName`
  - `OriginalFilename`
  - `ProductName`
- Windows native window title in `windows/runner/main.cpp` already uses `VioClass`.
- Flutter `MaterialApp.title` already uses `VioClass`.

## Added

- Added `tool/generate_windows_vio_class_icon.py`.
- The script generates `windows/runner/resources/app_icon.ico` from the shared source asset:

```text
assets/app/vio_class_icon.svg
```

This keeps Windows using the same visual icon design as Android instead of maintaining two separate hand-edited icon sources.

## How to Apply Locally

From repo root:

```powershell
python -m pip install cairosvg pillow
python tool/generate_windows_vio_class_icon.py
flutter clean
flutter pub get
flutter build windows
```

## Why This Was Done This Way

GitHub text-file updates are safe through the current tool path, but directly replacing the binary `.ico` in the repository needs binary tree update support. The script is committed so the Windows `.ico` can be regenerated deterministically from the same VioClass SVG asset used by the app.

## Expected Output

```text
windows/runner/resources/app_icon.ico
```

After rebuilding, Windows should show the same VioClass app name and matching dark-purple VioClass icon style as Android.
