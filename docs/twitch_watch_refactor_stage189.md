# Twitch Watch Refactor Stage 189A–189B — Glass UI 第一版與加強版

## 目標

Stage 189 的目標是先把 Twitch App 往半透明 Twitch dark UI 方向推進，但不再大幅改動架構。

本階段只處理 UI 外觀，不改：

- Watch services / ports / scopes
- Player loading pipeline
- Chat runtime
- Channel Points / Prediction / Emote 的資料流
- Sheet launcher 與 API 行為

---

# Stage 189A — Watch Player Glass UI

## 新增

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

## 修改

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

---

# Stage 189B — Discovery Cards 明顯化

## 背景

使用者截圖顯示目前畫面主要是 Following / Discovery 首頁，不是 WatchPage。Stage 189A 主要改 Watch player overlay，所以在這個頁面上效果不會很明顯。

因此 Stage 189B 先加強首頁直播卡片的視覺感，讓目前截圖中的卡片更明顯有半透明 / purple accent / glass dark UI 風格。

## 修改

### Discovery stream card

檔案：

- `lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart`

變更：

- patch version 更新為 `twitch_stream_card_stage189b_obvious_glass_cards`
- 卡片背景改為深紫黑漸層
- 加強紫色邊框與紫色 glow
- 卡片頂部加入細紫色 highlight line
- LIVE badge 加強亮度、白色邊框與紅色 glow
- Viewer badge 加深半透明黑底與陰影
- Game badge 加強紫色底、紫色邊框與 glow
- Avatar 加入紫色柔光
- Title 加入輕微文字陰影，提升暗背景可讀性

## 設計方向

這版不是只做很低調的透明感，而是刻意讓首頁卡片更容易看出變化：

- 卡片邊框更紫
- 卡片陰影更強
- 卡片背景不再是單純灰黑，而是紫黑漸層
- LIVE / viewer / game pill 的層級更明顯

## 測試建議

本地拉下來後先跑：

```bash
git pull
flutter analyze
```

如果 analyze 沒問題，再看：

- Following / Browse 首頁卡片是否變得更有 glass dark UI 感
- WatchPage player overlay 是否正常顯示
- card grid 是否沒有 overflow
- 窄螢幕下直播卡片是否仍不截斷 streamer footer
