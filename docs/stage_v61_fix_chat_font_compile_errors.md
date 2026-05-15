# Stage v61：修正聊天室字體設定 Compile Error

更新時間：2026-05-15 03:48:56

## 修正內容
- 修正 v60 呼叫 `compact` 但 `TwitchChatMessageList` 未完整同步的問題。
- 修正 `TwitchRuntimeMessageTile` 的 `compact` 參數與 visual metrics 同步。
- 修正 `TwitchWatchChatPanel` 缺少 `_appearanceController` 欄位、初始化與釋放。
- 修正聊天室字體設定 sheet 的 import / 呼叫缺失。
- 聊天室訊息列表改用 `Listenable.merge([currentRuntime, _appearanceController])`，讓字體 slider 調整後可以即時刷新。

## 影響檔案
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart`
