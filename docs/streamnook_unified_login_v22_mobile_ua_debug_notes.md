# v22 Drops Device Flow Mobile UA Debug

## 判斷

v21 log 顯示：

- device_code 正常產生。
- Twitch activate / authorize 頁正常載入。
- `authorize/data` 回 200。
- `gql.twitch.tv/integrity` 回 200。
- 但按下授權後，沒有觀察到真正完成 device grant approval 的 fetch/xhr/form submit。
- polling 一直 `authorization_pending`。

因此卡點不是 polling，也不是 device_code，而是 Twitch 授權頁在目前 Windows embedded WebView 的 desktop auth runtime 內沒有完成 approve。

## v22 修改

- Drops auth WebView 改用 Frosty 類似的 Android Chrome mobile User-Agent。
- 保留 device flow + in-app WebView，不使用外部瀏覽器。
- 增加 console error/warn 展開，避免只看到 `Error`。
- 增加 `sendBeacon` / form submit debug hook。

## 版本字串

```text
PATCH VERSION: twitch_drops_device_login_page_mobile_ua_debug_v22
```
