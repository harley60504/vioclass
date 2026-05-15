# Stage v63：修正 LiveMessageDivider compact 未初始化

更新時間：2026-05-15 03:54:11

## 修正內容
- 修正 `twitch_chat_message_list.dart` 中 `_LiveMessageDivider` 被誤加 `final bool compact;`。
- `_LiveMessageDivider` constructor 沒有接收 compact，導致 Windows build 出現 `Final field 'compact' is not initialized`。
- 已移除該多餘欄位；`compact` 只保留在 `TwitchChatMessageList` 與 `TwitchRuntimeMessageTile`。

## 影響檔案
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_message_list.dart`
