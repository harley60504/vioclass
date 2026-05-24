# Chat inline tag visibility — 聊天室內 tag 顏色可讀性調整

## 背景

使用者回報主要問題不是留言紀錄 sheet 的 relation chip，而是聊天室訊息內部的 `@username` / reply preview tag 顏色太灰，在深色背景上不明顯。

## 修改檔案

- `lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_reply_preview.dart`
- `lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_segments.dart`
- `docs/chat_inline_tag_visibility.md`

## 修改內容

### 1. Reply preview 內的 tag 高亮

`TwitchChatMessageReplyPreview` 原本整行 reply preview 都使用 `Colors.white38`，導致 `@tag` 與一般灰字混在一起。

本次改為 `Text.rich`，將 preview body 內符合：

```text
@[A-Za-z0-9_]{3,25}
```

的文字套用較亮的紫灰色：

```dart
const Color(0xFFD6CCEA)
```

並加粗到 `FontWeight.w900`。

### 2. 聊天室正文內的 @mention 高亮

`TwitchChatMessageSegmentSpans` 的一般文字處理新增 mention-aware plain text append。

當文字 token 內出現 `@username` 時，會切成一般文字與 mention span：

- 一般文字：白色
- `@username`：紫灰色 `0xFFD6CCEA`，`FontWeight.w800`

此邏輯同時套用在：

- 沒有任何 emote cache 時的純文字路徑
- 有 emote cache 但 token 不是 emote 時
- emote fallback text 路徑

## 預期效果

- 聊天室訊息本體中的 `@username` 更明顯。
- reply preview 上方灰字中的 `@tag` 不再被深色背景吃掉。
- 不影響連結、cheermote、Twitch emote、第三方 emote 的原有渲染。

## Commits

- `716c54c6b62230e6af530fd33453df33cfdff9f7`
- `b73874ff4b4bd04e79fd4221f93e840f117353db`
