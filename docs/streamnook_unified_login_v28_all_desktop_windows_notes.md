# v28 - All three desktop login steps use `desktop_webview_window`

## Changed files

```text
lib/features/twitch/presentation/pages/twitch_linked_login_page.dart
lib/features/twitch/presentation/pages/twitch_interaction_web_login_page.dart
lib/features/twitch/presentation/pages/twitch_oauth_webview_login_page.dart
lib/features/twitch/presentation/pages/twitch_drops_device_login_page.dart
```

## Main changes

```text
Official Web / GQL login  → desktop_webview_window
Main OAuth login          → desktop_webview_window
Drops / Android login     → desktop_webview_window
```

All three desktop auth windows now share the same WebView user-data folder:

```text
%TEMP%/new_twitch_app_shared_twitch_desktop_webview_v28
```

This means the Twitch cookie/session created in the official Web/GQL step can be reused by the main OAuth and Drops authorization windows.

## Required dependency

```yaml
dependencies:
  desktop_webview_window: ^0.2.3
```

## Required main.dart hook

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

## Version markers

```text
PATCH VERSION: twitch_linked_login_page_all_desktop_windows_v28
PATCH VERSION: twitch_interaction_web_login_page_desktop_window_v28
PATCH VERSION: twitch_oauth_webview_login_page_desktop_window_v28
PATCH VERSION: twitch_drops_device_login_page_desktop_window_only_v28
```
