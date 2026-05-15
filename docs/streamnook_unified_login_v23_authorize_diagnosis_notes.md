# StreamNook Unified Login v23 - Drops Authorize Diagnosis

## 目的

定位 Drops / Android device flow 在 WebView 中按下「授權」後卡住的原因。

## 改動

- `twitch_drops_device_login_page.dart` 版本：`twitch_drops_device_login_page_authorize_diagnosis_v23`
- WebView debug hook 改成 document-start 注入。
- 加入 `window.flutter_inappwebview.callHandler('dropsAuthDebug', ...)`，避免只靠 console message。
- 展開 `console.error`、`window.onerror`、`unhandledrejection` 的 message / stack。
- 捕捉 fetch / XHR / sendBeacon。
- 捕捉 pointerdown / mousedown / mouseup / click / touchstart / Enter/Space keydown。
- 捕捉 form submit。
- 新增「診斷頁面」按鈕，列出目前 URL、readyState、button、form、activeElement。

## 測試方式

1. 清除登入資訊後重新一鍵登入。
2. 到 Drops / Android token 步驟。
3. 按下 Twitch 授權頁面的「授權」。
4. 等 5~10 秒。
5. 按「診斷頁面」。
6. 按「複製 log」貼回來。

## 判讀

- 如果有 click/pointerdown，但沒有 fetch/xhr/beacon/form submit：Twitch 前端 click handler 卡住。
- 如果有 approve/authorize 類 request 但非 2xx：WebView runtime 或 Twitch 端拒絕。
- 如果 approve request 成功但 polling 仍 pending：device_code 與 approve action 沒成功綁定。
