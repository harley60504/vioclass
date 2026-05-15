# Stage v75：輸入文字置中重寫與 Top Games 預抓修正

更新時間：2026-05-15 05:49:37

## 本次修正

### 1. 輸入框文字仍未置中的原因
v74 雖然改成自己畫外框，但裡面仍使用 `TextField` + `InputDecoration.collapsed`。  
`TextField` 本身仍然有 baseline / RenderEditable 置中行為差異，所以畫面上 placeholder 仍可能偏上。

### 2. v75 輸入框改法
- `_SelfDrawnInputField` 改成 StatefulWidget。
- 內部改用 `EditableText`，不再用 `TextField`。
- 外層自己畫：
  - 背景
  - 圓角
  - border
  - horizontal padding
- placeholder 用 `Stack + Align.centerLeft + Text` 自己畫。
- 真正輸入區用：
  - `Align.centerLeft`
  - `SizedBox(height: fontSize * 1.18)`
  - `EditableText`
- 目的：避免 `TextField` / `InputDecorator` 的 hidden padding 和 baseline 行為。

### 3. 遊戲分類只有 80 / 100 的原因
v74 還有兩個問題：
- 初始 `_loadGames()` 雖然理應可以分頁，但實際初始仍曾使用 `first: 80`。
- 更重要的是，預抓如果在 `_loadingGames == true` 時呼叫，會被 `_prefetchMoreGames()` 第一行擋掉，導致沒有真的抓第二頁。

### 4. v75 遊戲分類改法
- 初始 `fetchTopGames(first: 100)`。
- `_loadGames()` 完成並把 `_loadingGames = false` 後，才呼叫 `_prefetchMoreGames()`。
- `_prefetchMoreGames()` 預設：
  - 至少嘗試抓到 `300` 筆
  - 最多預抓 `4` 頁
  - 每頁 `100`
- 後續仍保留滾到底繼續使用 cursor 分頁。

## 影響檔案
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
