# StreamNook Unified Login v27 Notes

## 目標

本版把登入流程調成比較接近 Xtra 的概念：

```text
一鍵登入
1. 先建立 Twitch 官方 Web session
2. 在同一個官方 Web session 裡順手擷取 kimne Web GQL token
3. 再跑主 App OAuth token
4. 最後跑 Drops / Android device flow
```

重點是：

```text
流程可以合併，但 token slot 仍然分開。
```

## Token slot

```text
web_gql_token
→ Twitch 官方 Web / kimne client token
→ Channel Points / Web GQL / 官方 web context

main_oauth_token
→ 你的 App OAuth token
→ Helix / IRC / 追隨列表 / 官方 API

drops_android_token
→ Twitch Android client token
→ Drops / StreamNook-style Android APQ route
```

## UI 改動

登入檢查頁從「Web GQL」改成「官方 Twitch Web / GQL」。

```text
✅ 官方 Twitch Web / GQL
✅ 主 OAuth token
✅ Drops / Android token
```

`kimne GQL 測試` 不再是獨立概念，而是官方 Web session 流程的一部分。

## Drops 授權容器分流

```text
Windows / Linux / macOS
→ desktop_webview_window 獨立授權視窗

Android / iOS
→ App 內 InAppWebView 授權頁
```

桌面仍需要 main.dart hook：

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

pubspec.yaml 需要：

```yaml
dependencies:
  desktop_webview_window: ^0.2.3
```

## Patch version strings

```text
PATCH VERSION: twitch_linked_login_page_official_web_gql_merge_v27
PATCH VERSION: twitch_drops_device_login_page_platform_split_v27
```
