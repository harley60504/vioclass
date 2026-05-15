# Stage v62：修正 v61 Import 與 compact 參數同步錯誤

更新時間：2026-05-15 03:51:19

## 修正內容
- 修正 `twitch_watch_chat_panel.dart` 中錯誤的 import 字串：
  - 錯誤：`../../settings/twitch_chat_appearance_controller.dart;'`
  - 正確：`../../settings/twitch_chat_appearance_controller.dart`
- 重新整理 `TwitchWatchChatPanel` 的 `_appearanceController` 欄位、初始化與釋放。
- 重新整理 `TwitchChatMessageList` constructor，確保 `compact` 有完整宣告與預設值。
- 重新整理 `TwitchRuntimeMessageTile` constructor，確保 `compact` 有完整宣告與預設值。
- 重新整理 `_ChatMessageVisualMetrics`，讓 compact 模式正式參與聊天室字體、badge、emote 尺寸計算。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart`
