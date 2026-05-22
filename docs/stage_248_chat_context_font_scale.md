# Stage 248 — Chat context sheet 字體倍率與 tag 可讀性調整

## 背景

使用者回報聊天室的留言紀錄 / 回覆串 sheet 沒有跟著聊天室字體大小倍率變化，而且 `@tag` 標記顏色偏灰、不夠明顯。

本次修改集中在 chat message context sheet 與 reply thread card UI。

## 修改檔案

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart`
- `lib/features/twitch/presentation/sheets/chat_message_context/twitch_reply_thread_card.dart`
- `docs/stage_248_chat_context_font_scale.md`

## 修改內容

### 1. Context sheet 接收聊天室字體倍率

`showTwitchChatMessageContextSheet` 新增：

```dart
fontScale: chatFontScale
```

由 `TwitchWatchChatPanel` 開啟 sheet 時，把目前 `_appearanceController.fontScale` 傳入，讓留言紀錄 sheet 與聊天室主列表使用同一個字體倍率。

### 2. Reply thread card 文字跟隨倍率

`TwitchReplyThreadMessageCard` 新增 `fontScale` 參數，並套用到：

- 卡片 header 的實況主名稱
- 時間文字
- 「目前 / 上文 / 回覆」chip
- `reply @...` / `tag @...` relation chip
- 內部 `TwitchRuntimeMessageTile`

訊息內容仍保留 compact 風格，但會使用：

```dart
fontScale * 0.96
```

避免 context sheet 比主聊天室過大，同時仍跟隨使用者設定。

### 3. 改善 tag 可讀性

原本 relation chip 用 `label.startsWith('reply')` 推顏色，tag 顏色較不符合目前暗色 UI。

本次改成明確 enum：

```dart
_RelationChipType.reply
_RelationChipType.tag
```

並將 tag 改為較亮的紫灰色：

```dart
const Color(0xFFD6CCEA)
```

讓 `tag @username` 在深色背景上更容易看見，但不會像高亮訊息一樣搶畫面。

## 預期效果

- 使用聊天室外觀設定調大字體後，留言紀錄 / 回覆串 sheet 會同步變大。
- `@tag` relation chip 在暗色 sheet 上更清楚。
- 回覆串訊息內容仍維持 compact，不會因倍率過大導致版面過度擁擠。

## Commit

- `ecd5c5d070b65ae876b0b1873fdf1430c46d4895`
- `763289be7a90f493c9cb39b2cf90ad4843f3c1a8`
- `2abf374f934efd5f70b601e072f07335f8b747a9`
