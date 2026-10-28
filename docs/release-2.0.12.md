# VioClass 2.0.12

## 繁體中文

- 聊天室偵測到斷線後立即重連，失敗時依序等待 2、4、8 秒，之後最多每 15 秒重試；恢復連線後重設等待間隔。
- 修正初始化期間斷線仍顯示已連線，以及未處理 Twitch 主動要求重連的問題。
- 補齊聊天室發送連線的斷線偵測；重連保留原有訊息，並避免重複建立連線。
- 切到背景或離開聊天室會取消待重試，返回前景時可立即恢復。

## English

- Chat now reconnects immediately after a detected disconnect. Failed attempts retry after 2, 4, 8, then 15 seconds, with the delay reset after recovery.
- Fixed disconnected sessions being marked connected during initialization and handled Twitch server reconnect requests.
- Added disconnect detection for the optional chat write connection, retaining chat history and preventing overlapping reconnect attempts.
- Pending retries are cancelled when backgrounding or leaving chat; returning to the foreground can recover immediately.
