# StreamNook Unified Login v18

## PATCH VERSION

- `twitch_linked_login_page_unified_web_first_v18`
- `twitch_drops_device_login_page_webview_device_flow_v18`
- `twitch_stream_page_unified_login_gate_v18`

## 登入順序

v18 將一鍵登入順序改為：

```text
1. Web GQL token
2. 主 Twitch token
3. Drops / Android token
```

原因：先透過 Twitch WebView 建立 Twitch 官方網站登入 cookie，後續主 OAuth 與 Drops device flow 授權頁較容易沿用登入狀態。

## Drops / Android token

Drops 不再使用一般 WebView OAuth redirect，因為 Android client id 會遇到 `redirect_mismatch`。

v18 改為：

```text
start Drops device flow
→ App 內 WebView 開 verification_uri
→ 使用者在 WebView 輸入 user_code / 完成授權
→ App 背景 polling token endpoint
→ validate token client_id == Android / Drops client id
```

這是 device flow，不依賴 localhost redirect URI。

## 清除登入資訊

登入頁保留「清除登入資訊」按鈕，會清除：

```text
主 Twitch token
Web GQL token
Drops / Android token
WebView cookies/cache
舊版 interaction / gql verified 狀態
```

## Token 分流

```text
Web GQL token      → Channel Points / Web GQL / kimne Client-ID
主 Twitch token    → Helix / IRC / 追隨狀態查詢
Drops Android token → StreamNook-style Follow / Unfollow APQ
```
