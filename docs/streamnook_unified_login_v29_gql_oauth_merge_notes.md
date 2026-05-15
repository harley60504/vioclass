# v29 unified login notes

## 目標

- 移除登入頁、OAuth 頁、Drops 頁的 debug log 面板與複製 log 按鈕。
- 一鍵登入時不再先跳一次 Web/GQL 視窗，再跳一次主 OAuth 視窗。
- 主 OAuth 視窗取得 main token 後，會在同一個 desktop_webview_window 切回 `https://www.twitch.tv/`，順手讀官方 Web / kimne GQL token。

## 一鍵登入流程

```text
1. 主 OAuth + 官方 Web/GQL
   - 開一個 desktop_webview_window
   - 完成主 OAuth token
   - 同一視窗切到 twitch.tv
   - 讀 auth-token 並驗證 kimne GQL

2. Drops / Android
   - 開 Drops device flow 授權視窗
   - 背景 polling token
```

## 仍然保留的單獨補救

```text
只補官方 Web/GQL
只補主 OAuth
只補 Drops / Android
清除登入資訊
```

## 注意

`main.dart` 仍需保留：

```dart
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

  if (runWebViewTitleBarWidget(args)) {
    return;
  }

  runApp(const NewTwitchApp());
}
```

`pubspec.yaml` 仍需包含：

```yaml
dependencies:
  desktop_webview_window: ^0.2.3
```
