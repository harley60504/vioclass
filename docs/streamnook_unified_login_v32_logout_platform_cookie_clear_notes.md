# StreamNook Unified Login v32 - Logout + Platform Cookie Clear

## 變更

- 將「清除登入資訊」改名為「登出」。
- 登出時仍會清除三種 token：
  - 官方 Web / GQL token
  - 主 OAuth token
  - Drops / Android token
- 登出時改為依平台清除 WebView session：
  - Windows / macOS / Linux：清除 `desktop_webview_window` 共用 user data folder。
  - Android / iOS：清除 `flutter_inappwebview` 的 CookieManager cookies，並補清 Twitch 相關網域 cookies。
  - Android / iOS：同時嘗試清除 WebStorage local/session data。

## 版本字串

```text
PATCH VERSION: twitch_linked_login_page_logout_platform_cookie_clear_v32
```
