# Twitch WatchPage Port Refactor — Stage 184–187

這份文件記錄 WatchPage 拆分與 port 化重構的收尾狀態。主開發紀錄仍在 `docs/twitch_development_log.md`，本文件作為 Stage 184–187 的集中說明。

---

## 目標

原本 `TwitchWatchPage` 同時負責：

- 建立 Twitch API / GQL / playback / chat / emote / engagement services
- 播放器載入與畫質切換
- 聊天室 startup / IRC runtime
- 第三方貼圖與 Twitch 官方貼圖載入
- Channel Points / Prediction / Pinned Chat
- Follow / Subscribe relationship 操作
- Player + Chat layout
- Sheet 開啟與互動操作

Stage 184–187 的目標是改成：

```text
WatchPage
→ route lifecycle
→ loading coordinator
→ layout / resize / preferences
→ player/chat/sheets 拼裝

Feature ports / adapters
→ Player
→ Chat
→ Emote
→ Engagement
→ Relationship
```

---

## Stage 184 — Emote picker panels 拆分

### 主要內容

- 將 emote picker 內部 panels 拆到 `panels/` 子資料夾。
- `twitch_emote_picker_panels.dart` 改成 barrel export。
- 官方 Twitch emote panel、最近使用、收藏、第三方 provider grid 等獨立化。

### 代表檔案

```text
lib/features/twitch/presentation/sheets/emote_picker/twitch_emote_picker_panels.dart
lib/features/twitch/presentation/sheets/emote_picker/panels/
```

---

## Stage 185 — Progressive grid 共用化

### 主要內容

- 將漸進式載入 Grid 抽成 common widget。
- Emote picker / Official Emote ID picker 改用同一個 progressive grid。
- 修正 `TwitchProgressiveGridView` import 問題。

### 代表檔案

```text
lib/features/twitch/presentation/widgets/common/twitch_progressive_grid_view.dart
lib/features/twitch/presentation/sheets/emote_picker/twitch_official_emote_id_picker_sheet.dart
```

---

## Stage 186 — Watch feature services / ports 基礎

### 保留的核心檔案

```text
lib/features/twitch/services/watch/twitch_watch_services.dart
lib/features/twitch/services/watch/twitch_watch_feature_services.dart
lib/features/twitch/presentation/watch/twitch_watch_feature_ports.dart
lib/features/twitch/presentation/watch/twitch_watch_scope.dart
lib/features/twitch/presentation/watch/twitch_watch_port_scope.dart
```

### 已刪除的重複 / 未接入檔案

以下檔案曾作為過渡架構，但最後沒有接入正式流程，已刪除避免重複概念：

```text
lib/features/twitch/presentation/watch/twitch_watch_service_builders.dart
lib/features/twitch/presentation/watch/twitch_watch_port_builders.dart
lib/features/twitch/presentation/watch/twitch_watch_composition_root.dart
lib/features/twitch/presentation/watch/twitch_watch_player_shell.dart
lib/features/twitch/services/watch/twitch_watch_engagement_controller.dart
```

### 現在的 service groups

```text
TwitchWatchCoreServices
TwitchWatchAuthServices
TwitchWatchPlayerServices
TwitchWatchChatServices
TwitchWatchEmoteServices
TwitchWatchEngagementServices
TwitchWatchRelationshipServices
```

### 現在的 feature ports

```text
TwitchWatchPlayerPort
TwitchWatchChatPort
TwitchWatchEmotePort
TwitchWatchEngagementPort
TwitchWatchRelationshipPort
```

---

## Stage 187 — WatchPage 接入 port / adapter 並清理

### 主要 commits

```text
bb1ac15d875f7bc6f63cddf3cc7215b7046808b0
Stage 187C: wire WatchPage to port scopes and adapters

adced9dbda9f625da14438514e34e68c65d17d1b
Stage 187D: add watch sheet port launcher

b5bd9e6de78a7c8363e5dbeb7f2e72b2f3b9c112
Stage 187E: remove unused watch service builders

02b054f80d7fa91fff41c8ef94a89c43faf6d8f3
Stage 187E: remove unused watch port builders

7bff4be6865c144a51f9faaf21770ace3945da2b
Stage 187E: remove unused watch composition root

855af81e6e2a1b658868084a3789ad6249268521
Stage 187E: remove unused watch player shell

f745b6856195bc4be868d4237cfe1668a931f79f
Stage 187F: clean WatchPage unused fields and delegate sheets
```

### 新增 / 保留的 adapter

```text
lib/features/twitch/presentation/watch/adapters/twitch_watch_player_area_port_adapter.dart
```

目前包含：

```text
TwitchWatchPlayerAreaPortAdapter
TwitchWatchChatPanelPortAdapter
```

作用：

- Player 區域從 `TwitchWatchPlayerPort` 取得 player runtime / player / video controller / quality state。
- Chat 區域從 `TwitchWatchEmotePort` 取得第三方貼圖 cache 與官方貼圖 loading 狀態。
- WatchPage 不再需要手動把所有 player / emote 依賴一個一個傳給子元件。

### 新增 / 保留的 sheet launcher

```text
lib/features/twitch/presentation/watch/sheets/twitch_watch_sheet_port_launcher.dart
```

作用：

- `openEmotePicker()`
- `openChannelPointsSheet()`
- `loadChannelPointModifiableEmotes()`
- `claimCommunityPoints()`
- `redeemChannelPointReward()`
- `openPredictionBetSheet()`
- `placePredictionBet()`

這些流程已從 WatchPage 移到 launcher，並透過 `TwitchWatchEmotePort` / `TwitchWatchEngagementPort` 操作。

---

## Stage 187F 後的 WatchPage 責任

目前 `TwitchWatchPage` 仍保留：

```text
OAuth/session loading
chat runtime 建立與發送訊息
watch loading pipeline
player volume / mute preference
chat panel width / visibility preference
fullscreen lifecycle
route dispose / session cleanup
player + chat layout
blocking startup overlay
resize handle
```

目前已經移出或委派：

```text
Player playlist load / quality switch
Chat startup snapshot
Emote cache loading / clear
Channel Points load / claim / redeem / emote options
Prediction refresh / bet
Pinned Chat refresh
Follow / unfollow / subscribe URI
Sheets operation details
```

---

## 目前不要再做的事

```text
不要再新增大 controller 代理所有 API
不要再讓 WatchPage 直接 new 各種 Twitch API service
不要再新增未接入的 composition shell / builder wrapper
不要在功能未穩定前把 layout helper 再拆太細
```

---

## 後續建議

### 先驗證

請先跑：

```bash
git pull
flutter analyze
```

再測試：

```text
播放直播
切畫質
聊天室連線與發訊息
Emote Picker
Channel Points Sheet
Prediction Sheet
Follow / Subscribe
聊天室寬度拖曳
手機 / 窄視窗 layout
```

### 若 analyze 沒問題

可以進入 UI 風格重做，優先處理：

```text
Player header / overlay UI
Chat panel top cards
Pinned message / announcement / special message cards
Sheets visual style
Channel Points / Prediction card layout
```

### 若還要讓 WatchPage 更薄

只建議做小清理：

```text
把 _WatchBlockingStartupOverlay 拆成純 UI widget
把 _ChatResizeHandle 拆成純 UI widget
把 player/chat layout 區塊整理成 section builder
```

但這些不是 API 架構問題，可以等 UI 重做時一起處理。
