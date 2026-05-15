# PATCH VERSION: watch_player_mpv_cache_default_v40

## 變更

- `twitch_watch_page.dart`
  - media_kit `PlayerConfiguration.bufferSize` 回到預設值。
  - 避免 v39 的 128 KB buffer 太小造成卡頓。

- `twitch_playlist_player_runtime.dart`
  - 保留 App 播放使用 Dart proxy raw stream：`proxy.streamUrl`。
  - 新增 `proxyMpvUrl`，給外部 mpv 測試使用 `proxy.streamTsUrl`，URL 會是 `/stream.ts`。
  - `/stream.ts` 可以讓 mpv 較明確用 MPEG-TS demux，減少直接打 `/` 時的探測問題。

- `twitch_watch_player_area.dart`
  - Debug 選單仍只保留：
    - 複製 Dart Proxy URL
    - 複製 mpv Proxy 指令
  - 複製給 mpv 的 URL 優先使用 `proxyMpvUrl`。
  - mpv 指令回到預設 cache，不再塞低 cache 參數。

## 注意

mpv log 如果仍短暫出現 `non-existing PPS`，通常是 raw live stream 起點剛好在非 IDR / 非完整參數集附近；只要後面能正常出畫面，這是可接受現象。若長時間黑畫面，才需要調整 proxy 起播段選擇。
