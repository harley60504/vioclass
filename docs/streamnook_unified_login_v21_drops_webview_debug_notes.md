# StreamNook Unified Login v21 - Drops WebView Debug

This patch keeps the Drops / Android device flow, but adds detailed logging around the authorization page getting stuck after pressing **授權**.

## Why this exists

- Frosty is also Flutter, but it uses `webview_flutter` with a dedicated `WebViewController`, mobile-style User-Agent, navigation delegate, and injected JavaScript for Twitch auth page layout.
- StreamNook starts Drops device flow, opens a separate auth WebView window, and keeps polling in the backend.
- The current Flutter Windows route uses `flutter_inappwebview`; pressing **授權** appears to submit, but polling remains pending. v21 is intended to identify whether Twitch's approve request is never sent, blocked, or sent but fails.

## Added diagnostics

- Device flow start / user code / interval / expires logs.
- Poll attempts and result status logs.
- WebView load start / load stop / history / progress logs.
- Console capture for `[drops-auth-debug]`.
- JS hooks injected into Twitch auth page:
  - wraps `fetch`
  - wraps `XMLHttpRequest`
  - logs authorize button click state
  - logs delayed after-click URL and readyState
  - logs visible buttons
- Debug panel at the bottom with copy / clear buttons.

## What to capture

After pressing **授權**, copy the debug log. The useful cases are:

- `click 授權` exists but no `fetch:start` / `xhr:start` follows: the page click handler is not firing the approve request.
- `fetch:start` or `xhr:start` appears, followed by error or non-2xx status: the request is being rejected or blocked.
- polling stays `authorization_pending` after a successful approve request: device approval is not reaching Twitch's device flow endpoint.
