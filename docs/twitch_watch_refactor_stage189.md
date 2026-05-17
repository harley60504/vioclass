# Twitch Watch Refactor Stage 189A — Glass UI 第一版

## 目標

Stage 189A 的目標是先把 Watch Page 往半透明 Twitch dark UI 方向推進，但不再大幅改動架構。

本階段只處理 UI 外觀，不改：

- Watch services / ports / scopes
- Player loading pipeline
- Chat runtime
- Channel Points / Prediction / Emote 的資料流
- Sheet launcher 與 API 行為

## 本階段新增

### `lib/features/twitch/presentation/widgets/shared/twitch_glass.dart`

新增共用 glass widget：

- `TwitchGlassSurface`
- `TwitchGlassPanelShadow.soft`
- `TwitchGlassPanelShadow.compact`

用途：

- 統一半透明背景
- 統一白色低透明邊框
- 統一 blur / shadow 設定
- 避免每個 player / chat widget 自己重複寫 glass decoration

## 本階段修改

### Player area

檔案：

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

變更：

- patch version 更新為 `watch_player_area_stage189a_glass_ui`
- 引入 shared glass widget
- 保留原本 media_kit `Video.controls` 的架構
- 不改 player runtime / quality switch / playback 行為

### Player stream header

檔案：

- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_stream_header.dart`

變更：

- Stream header card 改成 `TwitchGlassSurface`
- Compact avatar tile 改成 glass tile
- 保留 avatar、viewer count、game name、language、title 顯示邏輯
- 保留 game / language 點擊複製行為

### Player top buttons

檔案：

- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_top_buttons.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_common_buttons.dart`

變更：

- Back / reload / stop icon buttons 改成 glass button
- Follow button 改成 glass button
- Subscribe button 改成紫色 glass accent button
- 保留原本 compact / tiny 高度設計，避免重新引入 overflow 問題

### Player bottom control bar

檔案：

- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_bottom_control_bar.dart`

變更：

- Bottom control bar 改成 glass surface
- Playback sheet 也改成 glass surface
- 保留原本 compact layout / very narrow layout / playback sheet fallback
- 不改播放、靜音、音量、畫質、聊天室、全螢幕、更多選單行為

### Chat panel shell

檔案：

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`

變更：

- Chat panel 外殼改成半透明 dark shell
- 新增左側淡邊框與陰影
- 不對整個 chat list 套 `BackdropFilter`，避免聊天訊息高頻更新時增加 GPU 壓力
- 不改 header / engagement / message area / input section 的資料與互動流程

## 設計方向

這版採用暗色磨砂玻璃感：

- 主色仍是 Twitch dark：`#0E0E10` / black translucent
- 紫色只做 active / accent
- 邊框使用低透明白色
- 陰影偏柔，不做過強 neon
- Blur 只放在 player chrome、小面板與按鈕，不包整個影片或整個聊天室 list

## 下一步建議

Stage 189B 可以繼續做：

1. `TwitchWatchResponsiveBody` 背景與 player/chat 間距細修。
2. Chat header / input section 改成更一致的 glass dark UI。
3. Channel Points / Prediction / Emote sheets 統一成同一套 glass popup style。
4. Following / Browse card UI 之後再獨立整理，不要跟 Watch UI 同一階段混在一起。

## 測試建議

本地拉下來後先跑：

```bash
git pull
flutter analyze
```

如果 Flutter SDK 對透明 / blur 沒問題，再實際開 WatchPage 看：

- top overlay 是否仍不 overflow
- bottom control bar 在窄寬度是否仍可縮放
- 聊天室訊息滾動是否沒有明顯掉幀
- full screen / chat toggle / quality menu 是否正常
