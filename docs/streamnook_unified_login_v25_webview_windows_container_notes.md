# v25 Drops Device Flow：直接換授權容器

這版把 `TwitchDropsDeviceLoginPage` 的授權頁容器從 `flutter_inappwebview` 改成 `webview_windows`，也就是 Windows native WebView2 容器。

## 需要新增 dependency

請在 `pubspec.yaml` 加入：

```yaml
dependencies:
  webview_windows: ^0.4.0
```

然後執行：

```bash
flutter pub get
```

## 覆蓋檔案

```text
lib/features/twitch/presentation/pages/twitch_drops_device_login_page.dart
```

## 重點

- Drops device flow 邏輯不改。
- token polling 邏輯不改。
- 授權頁容器改成 `webview_windows`。
- 加上 URL / loading state / web message / JS diagnostic log。
- 保留「重載容器」「重建容器」「診斷頁面」「立即檢查」。

## 版本字串

```text
PATCH VERSION: twitch_drops_device_login_page_webview_windows_container_v25
```
