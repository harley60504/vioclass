# v26 Drops device flow：改用 desktop_webview_window 獨立授權視窗

## 目的
v25 使用 `webview_windows` 嵌入式容器時，使用者端出現：

```text
PlatformException(unsupported_platform, The platform is not supported, null, null)
```

v26 不再用 `webview_windows`，改成 `desktop_webview_window` 開獨立 native desktop WebView 視窗，接近 StreamNook 的獨立 auth window 方式。

## 需要新增 dependency

```yaml
dependencies:
  desktop_webview_window: ^0.2.3
```

然後執行：

```bash
flutter pub get
```

## 需要修改 main.dart
`desktop_webview_window` 需要在 `main()` 前面處理它自己的 titlebar 子程序。請把 main 改成類似：

```dart
import 'package:desktop_webview_window/desktop_webview_window.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (runWebViewTitleBarWidget(args)) return;
  runApp(const MyApp());
}
```

如果你的 `main()` 原本沒有 `args`，要改成 `main(List<String> args)`。

## 覆蓋檔案

```text
lib/features/twitch/presentation/pages/twitch_drops_device_login_page.dart
```

## 版本字串

```text
PATCH VERSION: twitch_drops_device_login_page_desktop_webview_window_v26
```
