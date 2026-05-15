# Twitch Flutter 開發紀錄 — Stage 91：Watch Player 窄螢幕控制列去彈窗化

## 修改檔案

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

## 修改目標

窄螢幕下原本音量與進度控制會使用 `showModalBottomSheet` 彈出底部面板，但彈窗 UI 在目前播放器 overlay 情境下顯示與操作體驗不穩定。因此本階段將 compact player controls 改成「控制列內直接操作」，不再使用 bottom sheet 彈窗。

## 主要變更

### 1. 移除 compact 進度彈窗

- 移除 `_CompactProgressOverlayButton`
- compact layout 不再點擊 timeline icon 開啟 bottom sheet
- 改為直接在底部控制列顯示 `_LivePlaybackStrip(compact: true)`

### 2. 移除 compact 音量彈窗

- 移除 `_CompactVolumeOverlayButton`
- 移除 `_showVolumeOverlay()`
- 新增 `_CompactInlineVolumeControl`
- 音量 icon 與小型 slider 直接顯示在底部控制列

### 3. 移除所有 `showModalBottomSheet` 使用

- `twitch_watch_player_area.dart` 內目前不再包含 `showModalBottomSheet`
- 避免播放器 overlay 與 bottom sheet 在窄螢幕時互相干擾

## 保留功能

- 播放 / 暫停
- 進度條與 LIVE / BUFFER 狀態
- 靜音切換
- 音量調整
- 畫質選單
- 聊天室顯示 / 隱藏
- 全螢幕切換
- More / Debug 選單

## 注意事項

- 這次移除的是 `showModalBottomSheet` 類型的底部彈窗。
- 畫質與 More 仍保留原本選單行為，因為它們不是這次造成問題的音量 / 進度 bottom sheet。
- 本階段未執行 `dart analyze`，需在本機 Flutter 專案中確認編譯與畫面縮放結果。
