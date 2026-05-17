# Twitch Watch UI 架構與檔案分類說明（Stage 163）

本文件記錄目前 Twitch Watch / Chat / Sheet UI 的拆分方式，目標是讓後續修改 UI 風格時能快速找到對應檔案，避免所有畫面邏輯集中在 `WatchPage` 或單一大型 widget 內。

---

## 1. 整體方向

目前重構方向是：

```text
API / Service / Runtime
→ Controller / Runtime Snapshot
→ Feature Widget
→ Small UI Component
```

避免回到：

```text
WatchPage
→ 載所有資料
→ 管所有狀態
→ 塞給所有 UI
```

`WatchPage` 未來應該只負責：

```text
1. 建立播放器 / 聊天室 / 互動功能需要的 runtime
2. 管理 watch route 生命週期
3. 組合 player、chat、sheet、overlay
4. 不直接寫複雜 UI 細節
```

---

## 2. Watch Chat Panel 結構

主要入口：

```text
lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart
```

目前它負責聊天室區塊的組裝：

```text
TwitchWatchChatPanel
├─ TwitchWatchChatHeaderBar
├─ TwitchWatchChatEngagementArea
├─ TwitchWatchChatMessageArea
├─ TwitchWatchChatInputSection
└─ TwitchWatchChatLayoutMetrics
```

### 檔案分工

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_header_bar.dart
```

負責：

```text
STREAM CHAT 頂部列
Pinned 顯示切換
Prediction 顯示切換
聊天室字體按鈕
刷新 engagement 按鈕
```

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_utility_bar.dart
```

負責：

```text
忠誠點數小按鈕
可領取禮物狀態
Emote picker 快捷按鈕
```

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_input_section.dart
```

負責：

```text
聊天室底部區域
Utility bar + input bar
SafeArea / bottom chrome
```

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_engagement_area.dart
```

負責：

```text
聊天室上方互動區
Pinned message
Prediction banner
Engagement loading / error
```

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_message_area.dart
```

負責：

```text
聊天室訊息列表
runtime messages
appearance controller listenable
message context sheet 開啟
```

```text
lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_layout_metrics.dart
```

負責：

```text
聊天室高度計算
keyboard visible 判斷
compact / ultra compact 判斷
engagement area 最大高度
是否隱藏 optional engagement
```

---

## 3. Chat Engagement Cards

主要入口：

```text
lib/features/twitch/presentation/widgets/chat/twitch_chat_engagement_strip.dart
```

目前它只負責把 pinned / prediction 組合起來：

```text
TwitchChatEngagementStrip
├─ TwitchPinnedMessageBanner
└─ TwitchPredictionBanner
```

### 檔案分工

```text
lib/features/twitch/presentation/widgets/chat/cards/twitch_pinned_message_banner.dart
```

負責：

```text
置頂留言 UI
sender / pinnedBy avatar 顯示
fallback avatar
```

```text
lib/features/twitch/presentation/widgets/chat/cards/twitch_prediction_banner.dart
```

負責：

```text
Prediction 賭盤卡片
倒數 pill
結果 / 取消狀態
雙選項比例條
locksAt fallback 計算
```

---

## 4. Chat Runtime Message 結構

主要入口：

```text
lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart
```

目前它已經變成薄入口，只負責：

```text
1. 解析使用者顏色
2. 格式化顯示名稱
3. 建立 visual metrics
4. 判斷 normal / special message
5. 交給對應 card
```

### message/ 資料夾

```text
lib/features/twitch/presentation/widgets/chat/message/
```

目前拆分如下：

```text
twitch_chat_message_cards.dart
```

負責：

```text
一般訊息卡片外框
特殊訊息卡片外框
特殊訊息左側 accent bar
特殊訊息 header
```

```text
twitch_chat_message_content.dart
```

負責：

```text
訊息內容排列
reply preview
system line
badge row
author row
message segments
bits / reward chip
```

```text
twitch_chat_message_author.dart
```

負責：

```text
使用者名稱
首聊 chip
冒號
action message italic style
```

```text
twitch_chat_message_badges.dart
```

負責：

```text
Twitch badge 圖片顯示
badge tooltip
badge 尺寸
```

```text
twitch_chat_message_segments.dart
```

負責：

```text
純文字 segment
連結 segment
Twitch emote
第三方 emote
cheermote
空白保留切分
emote cacheWidth / cacheHeight 計算
```

```text
twitch_chat_message_chips.dart
```

負責：

```text
首聊 chip
bits chip
reward chip
通用 small chip
```

```text
twitch_chat_message_timestamp.dart
```

負責：

```text
聊天室時間文字
聊天室時間 chip
HH:mm 格式化
```

```text
twitch_chat_message_reply_preview.dart
```

負責：

```text
回覆預覽文字
parent display name
parent body
```

```text
twitch_chat_message_special_style.dart
```

負責：

```text
特殊訊息種類 → 顏色 / icon / border / background
sub / bits / raid / announcement / channel points reward 等樣式
```

```text
twitch_chat_message_user_style.dart
```

負責：

```text
display name 格式化
Twitch 使用者顏色解析
fallback user color palette
```

```text
twitch_chat_message_visual_metrics.dart
```

負責：

```text
聊天室字體大小
badge 大小
Twitch emote 大小
第三方 emote 大小
line height
compact factor
```

---

## 5. 特殊訊息翻譯

特殊訊息 metadata：

```text
lib/features/twitch/models/chat/twitch_chat_message_metadata.dart
```

負責：

```text
判斷 specialKind
提供 specialLabel
判斷 bits / sub / resub / gift / raid / announcement 等分類
```

特殊訊息內文 formatter：

```text
lib/features/twitch/models/chat/twitch_chat_special_message_formatter.dart
```

負責：

```text
讀取 Twitch IRC msg-id
讀取 msg-param-* tags
組合中文特殊訊息內容
```

已涵蓋方向：

```text
sub：訂閱
resub：重新訂閱、累計月份、連續月份
subgift：贈送訂閱、接收者、方案、累計贈送數
submysterygift：大量贈訂、數量、方案、累計贈送數
raid：揪團人數
bits：歡呼 Bits
bitsbadgetier：Bits 徽章
channel points：忠誠點數兌換
```

如果遇到未涵蓋事件，會 fallback Twitch 原始 `system-msg`。

---

## 6. Sheet 分類方向

目前 sheet 入口集中在：

```text
lib/features/twitch/presentation/sheets/
```

其中：

```text
twitch_chat_appearance_sheet.dart
```

負責：

```text
開啟聊天室字體設定 sheet
連接 TwitchChatAppearanceController
```

UI 小元件已移到：

```text
lib/features/twitch/presentation/widgets/chat/appearance/twitch_chat_appearance_sheet_widgets.dart
```

負責：

```text
字體大小 slider
比例顯示
聊天室預覽卡
```

後續 sheet 拆分建議：

```text
twitch_chat_message_context_sheet.dart
→ 拆 reply thread builder
→ 拆 reply thread card
→ 拆 compact message body
→ 復用 chat/message segment renderer

twitch_emote_picker_sheet.dart
→ 拆 category tabs
→ 拆 emote grid
→ 拆 emote tile
→ 拆 loading / empty / search header

twitch_prediction_bet_sheet.dart
→ 拆 outcome card
→ 拆 bet amount input
→ 拆 points summary
→ 拆 submit status

twitch_channel_points_sheet_widgets.dart
→ 拆 reward card
→ 拆 claim banner
→ 拆 reward image / emote overlay
```

---

## 7. 後續拆檔原則

### 7.1 Page 不寫細節 UI

Page / panel 只負責組裝，例如：

```text
WatchPage
WatchChatPanel
WatchPlayerArea
```

不要在 Page 內直接寫：

```text
badge renderer
emote renderer
chip style
card header
loading skeleton
```

### 7.2 Widget 檔案依功能命名

推薦命名：

```text
twitch_<feature>_<area>_<purpose>.dart
```

例如：

```text
twitch_chat_message_badges.dart
twitch_chat_message_segments.dart
twitch_prediction_banner.dart
twitch_watch_chat_layout_metrics.dart
```

### 7.3 UI tokens 優先集中

顏色、字體、圓角、陰影應優先靠：

```text
lib/features/twitch/presentation/theme/twitch_ui_tokens.dart
lib/features/twitch/presentation/design/twitch_typography.dart
lib/features/twitch/presentation/design/twitch_breakpoints.dart
```

不要在每個 widget 重複散落大量 magic number。

### 7.4 Runtime / Formatter 不放 UI

例如：

```text
twitch_chat_special_message_formatter.dart
```

只做文字資料轉換，不 import Flutter，不碰 Widget。

### 7.5 可測功能優先，難重現事件 fallback

像 sub / raid / gift 這種難重現事件：

```text
1. 先依 Twitch IRC tags 做 formatter
2. 無法涵蓋時 fallback 原始 system-msg
3. 後續真的遇到再補規則
```

---

## 8. 目前下一步建議

優先順序：

```text
1. 拆 twitch_chat_message_context_sheet.dart
2. 拆 twitch_emote_picker_sheet.dart
3. 拆 twitch_prediction_bet_sheet.dart
4. 整理 channel points sheet widgets
5. 最後再回頭把 watch_page 內殘留 UI 拆乾淨
```

目前最值得下一個處理的是：

```text
lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart
```

因為它還包含：

```text
reply thread builder
reply card
relation chip
compact message body
segment renderer
copy message logic
```

其中 compact message body 可以復用 `chat/message/twitch_chat_message_segments.dart`，避免兩套 emote render 邏輯重複。
