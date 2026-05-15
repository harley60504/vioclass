# StreamNook Unified Login v30 - Android platform split fix

## 目標

修正 v29 在 Android / iOS 登入流程仍吃到 desktop_webview_window 的問題。

## 行為

- Windows / macOS / Linux
  - 官方 Web / GQL repair page：desktop_webview_window
  - 主 OAuth + Web/GQL merge：desktop_webview_window
  - Drops / Android device flow：desktop_webview_window

- Android / iOS
  - 官方 Web / GQL repair page：App 內 InAppWebView
  - 主 OAuth + Web/GQL merge：App 內 InAppWebView
  - Drops / Android device flow：App 內 InAppWebView

## 保留

- 一鍵登入仍是：主 OAuth 容器順手擷取 Web/GQL token，最後 Drops / Android token。
- token slot 仍分成 web_gql_token / main_oauth_token / drops_android_token。
- desktop 仍共用同一個 desktop_webview_window userDataFolder。

## 注意

main.dart 仍需保留 desktop_webview_window hook，因為桌面版仍會用獨立 WebView 視窗。

```dart
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  if (runWebViewTitleBarWidget(args)) return;
  runApp(const NewTwitchApp());
}
```
