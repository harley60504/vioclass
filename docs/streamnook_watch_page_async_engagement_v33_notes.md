# Watch Page v33 - Async engagement loading

## 目標

降低進入直播頁時被互動資料拖慢的體感延遲。

## 主要改動

- 播放器 `_loadPlayer()` 仍維持在主流程等待，確保影片先開。
- 聊天室 `_connectChat()` 改成背景執行，不再阻塞 `_loadWatch()` 完成。
- `_connectChat()` 連線成功後，第三方 emote 與 engagement refresh 都改為背景載入。
- `_refreshEngagement()` 裡的三個 snapshot 請求改成平行：
  - Channel Points
  - Prediction
  - Pinned Chat
- Relationship status 仍保持背景查詢。

## API 分工不變

- Pinned chat：GQL snapshot
- Prediction 讀取：Web GQL snapshot
- Channel points：Web GQL
- Follow status：relationship private GQL
- Player：Playback GQL + m3u8 + media_kit

## 注意

這版沒有改 API endpoint，也沒有新增 Hermes。只是把原本序列等待的資料改成背景 / 平行載入。
