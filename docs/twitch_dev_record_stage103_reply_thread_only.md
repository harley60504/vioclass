# Stage 103 — Chat Context Sheet: Official Reply Thread Only

## Files

- `twitch_chat_message_context_sheet_stage103_reply_thread_only.dart`
  - Replace: `lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart`

## Goal

Make the chat message context sheet behave closer to Twitch official reply context:

```text
@tag = displayed as a tag only
reply = actual thread relationship
```

## Behavior

When opening a message X:

1. Show X's parent chain if visible in the current message buffer.
2. Show X itself.
3. Show direct replies to X.
4. Do not show sibling replies.
5. Do not aggregate messages only because they mention the same @user.

Example:

```text
A: 今天吃什麼？
├─ B replies A: 吃拉麵
│  └─ C replies B: 哪一家？
└─ D replies A: 我想吃火鍋
```

- Open A: A, B, D
- Open B: A, B, C
- Open C: A, B, C
- Open D: A, D

## UI

The sheet keeps the cleaner original card style:

- sender name
- time
- relation chips
- compact message body
- Twitch emote rendering
- third-party emote rendering

## Notes

This version no longer depends on `TwitchChatMessageContextBuilder` for grouping. It builds the visible reply context from each message's `metadata.replyInfo` and falls back to parent login/body matching when an explicit parent message id is unavailable.
