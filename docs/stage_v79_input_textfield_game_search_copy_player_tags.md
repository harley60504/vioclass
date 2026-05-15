# Stage v79：聊天室輸入同一渲染、遊戲分類搜尋、聊天室複製、播放器資訊標籤

更新時間：2026-05-15 06:22:22

## 本次修正

### 1. 聊天室輸入框改回同一套 TextField 渲染
- 移除 v78 的 `EditableText + Stack placeholder` 分離渲染方式。
- 改成：
  - 外層自己畫輸入框外殼。
  - 內層使用 `TextField`。
  - hint 與實際輸入文字都交給同一個 `TextField` / `InputDecoration` 渲染。
- 使用固定公式計算 padding：
  - `verticalPadding = (rowHeight - fontSize * lineHeight) / 2`
- 加入：
  - `isCollapsed: true`
  - `strutStyle`
  - `forceStrutHeight: true`
  - `contentPadding`
- 目的：讓 placeholder 與實際輸入文字使用同一套行高與 padding。

### 2. 遊戲分類搜尋
- 篩選 sheet 的「遊戲類型」區塊新增搜尋欄。
- 搜尋會篩選目前已載入的遊戲分類。
- 不影響 cursor pagination，滑到底仍可繼續載入下一頁。
- 若目前已載入的遊戲沒有符合搜尋，會顯示提示文字。

### 3. 聊天室訊息複製
- `TwitchRuntimeMessageTile` 新增複製功能。
- 一般訊息與特殊訊息都支援：
  - 長按複製
  - 滑鼠右鍵 / secondary tap 複製
- 複製格式：
  - `顯示名稱: 訊息內容`
- 複製成功會顯示 SnackBar。

### 4. Player 上方資訊標籤
- `TwitchWatchPage` 新增 optional metadata：
  - `initialStreamTitle`
  - `initialGameName`
  - `initialViewerCount`
- 從瀏覽頁進入直播時，會把 stream title、game name、viewer count 傳進 watch page。
- Player 上方標籤列新增：
  - 實況人數
  - 遊戲類型
- 遊戲類型標籤可以點擊複製。
- Stream title 目前放在 channel label 的 tooltip 中，避免上方列過度擁擠。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart`
- `lib/features/twitch/presentation/pages/twitch_watch_page.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`
