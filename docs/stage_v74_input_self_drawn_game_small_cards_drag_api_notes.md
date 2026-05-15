# Stage v74：輸入列自繪對齊、遊戲分類小卡片、官方 API 分頁結論、聊天室拖曳優化

更新時間：2026-05-15 05:38:56

## 本次修正

### 1. 聊天輸入列高度再次修正
- 之前即使輸入框與 Send 按鈕使用同一個高度，`TextField` 與 `FilledButton` 內部高度模型仍不同。
- v74 改成：
  - 自己畫輸入框外殼：`Container + Border + BorderRadius`
  - `TextField` 改用 `InputDecoration.collapsed`
  - Send 按鈕改成 `Material + InkWell + Container`
  - 不再使用 `FilledButton`
- 目的：避免 Material Button / InputDecorator 各自偷加 padding 與 minimum size，讓兩邊高度真正一致。

### 2. 遊戲篩選 sheet 不變矮，格子縮小
- 篩選 sheet 高度提高：
  - `portraitHeightFactor: 0.88`
  - `landscapeHeightFactor: 0.98`
- 遊戲分類卡片縮小：
  - 欄數更多：寬畫面最多 5 欄
  - item 高度改為 138 / 128
  - box art 請求尺寸改為 112x150
  - 圖片置中、字體縮到 11
- 目標是同一個 sheet 內一次看到更多遊戲。

### 3. 遊戲分類 API 研究結論
- Twitch 官方 `Get Top Games` 使用 `/helix/games/top`。
- 官方限制：
  - `first` 最小 1、最大 100、預設 20。
  - 下一頁使用 response `pagination.cursor` 放到 `after`。
  - `pagination` 為空時表示沒有下一頁。
- 所以它不是「無限全部資料庫搜尋」，而是官方排序列表的 cursor 分頁。
- v73/v74 已經是正確方向：每頁 100，直到 cursor 消失或 cursor 沒前進就停止。
- 若還是很快結束，通常代表官方當下沒有再給下一頁，或 cursor 動態列表出現空頁 / 重複資料 / rate limit。

### 4. 聊天室拖曳不跟手修正
- 問題之一是拖曳時每次 update 都排程儲存 preference，造成拖曳時有額外負擔。
- v74 改成：
  - 拖曳中只更新記憶體狀態。
  - 拖曳結束才儲存寬度比例。
- 另一個問題是使用 build 當下的 `effectiveChatWidth` 計算每次 delta，容易跟實際 state 不同步。
- v74 改成用目前 `_chatPanelWidth` 作為基準再套 `delta.dx`，改善拖曳連續性。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/pages/twitch_watch_page.dart`
