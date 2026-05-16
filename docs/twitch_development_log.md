# Twitch Flutter App 開發紀錄

## Stage 107 — Android / iOS 首播安全畫質策略

Commit: `c36d4ab455a508da5b74ee09ecd84bf5ec22ab22`

### 背景

Android 平板第一次進入播放頁時容易出現明顯卡頓。根據 PiliPlus 的架構觀察，問題不應直接歸因於 proxy；PiliPlus 本身也使用 media_kit，但透過播放器重用、圖片快取、Sliver list/grid、彈幕 canvas 化與狀態更新節流來維持流暢。

目前 GitHub 版 `TwitchWatchPage` 已經在 `initState` 建立一次 `Player` 與 `VideoController`，播放與切畫質時主要呼叫 `_player.open(...)`，因此這次沒有大改播放頁生命週期。

### 修改檔案

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

### 修改內容

- 保留 Dart HLS low-latency proxy，不移除 proxy 路線。
- 新增 mobile startup safe quality 選擇策略。
- Android / iOS 首播時不再優先選 `Source` / `chunked`。
- Android / iOS 首播優先選擇：
  - video variant
  - 非 audio-only
  - 優先 clean / no-ad source
  - 優先 720p 以內
  - fps 最高不超過 60fps
- Windows / macOS / Linux 維持原本偏高畫質策略。

### 預期效果

- 降低 Android 平板第一次播放時的 decoder / texture / GPU 首幀壓力。
- 避免一進直播就用 Source 造成瞬間高負載。
- proxy 行為保持不變，方便比較這次卡頓是否主要來自首播畫質與播放器 warm-up。

### 測試建議

1. Android 平板冷啟動 App 後第一次進直播。
2. 觀察預設畫質是否不再是 Source / chunked。
3. 確認播放穩定後仍可手動切回 Source。
4. 對比修改前後第一次進播放頁的卡頓時間。
5. 如果仍卡，下一階段再測 media_kit `PlayerConfiguration` / `VideoControllerConfiguration` 與聊天室延後啟動。

### 下一階段候選

- Stage 108：Android media_kit PlayerConfiguration / VideoControllerConfiguration 對齊 PiliPlus 類似配置。
- Stage 109：首幀後延遲啟動聊天室、emote、prediction、channel points。
- Stage 110：導入統一 image cache layer，取代首頁 / 直播卡片中的直接 `Image.network`。
