# v31 Android compile fix

修正 `twitch_interaction_web_login_page.dart` 在 Android build 時 `_probeAndMaybeSave()` 內誤用不存在的 `url` 變數。

- 移除 probe 期間錯誤的 mobile `loadUrl(WebUri(url))` 區塊
- 保留 Android / iOS App 內 InAppWebView token 探測
- 保留 Desktop desktop_webview_window 流程
