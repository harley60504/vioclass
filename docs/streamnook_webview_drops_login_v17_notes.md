# v17：Drops / Android token 改用 WebView 取得

這版修正 v16 的登入流程：

- 不再讓登入頁的 Drops 步驟開 `TwitchDropsDeviceLoginPage`。
- 新增 `TwitchDropsWebViewLoginPage`。
- 一鍵登入仍然依序補三種 token：
  1. 主 Twitch token
  2. Web GQL token
  3. Drops / Android token
- 第 3 步改成 WebView OAuth 方式讀取 token，而不是 device flow。

## Token 分工仍然不變

```text
主 Twitch token
→ Helix / IRC / 聊天室 / 追隨狀態查詢

Web GQL token
→ Channel Points / Web GQL / kimne client-id 功能

Drops / Android token
→ StreamNook-style Follow / Unfollow APQ
```

## Drops WebView 登入行為

`TwitchDropsWebViewLoginPage` 會：

```text
WebView 開 Twitch OAuth authorize
→ client_id 使用 Drops / Android client id
→ redirect 後攔截 access_token
→ validate token
→ validate.client_id 必須等於 Drops / Android client id
→ 存入 TwitchDropsAuthService
```

如果 Twitch 不允許目前的 Android client id 使用預設 redirect URI，登入頁會顯示 OAuth 錯誤。進階面板可以改 Client-ID / Redirect URI 測試。

## 修改檔案

```text
lib/features/twitch/presentation/pages/twitch_drops_webview_login_page.dart
lib/features/twitch/presentation/pages/twitch_linked_login_page.dart
```

## 版本字串

```text
PATCH VERSION: twitch_drops_webview_login_page_v17
PATCH VERSION: twitch_linked_login_page_webview_drops_v17
```
