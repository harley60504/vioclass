# Stage v76：遊戲分類改為每頁 50，純滾到底載入

更新時間：2026-05-15 05:52:53

## 本次修正

### 1. 移除背景預抓
- 移除 v75 的 `_prefetchMoreGames()`。
- 不再打開頁面後自動抓到 300 筆。
- 避免一開始造成 API 壓力，也避免載入太多遊戲造成 UI 負擔。

### 2. 每頁改為 50 筆
- 新增 `_gamePageSize = 50`。
- 初始 `_loadGames()` 使用 `fetchTopGames(first: _gamePageSize)`。
- `_loadMoreGames()` 同樣使用 `first: _gamePageSize`。
- 之後所有遊戲分類分頁統一每頁 50。

### 3. 滾到底才載入
- 移除 init / didUpdateWidget 的自動補載。
- `_GameWaterfallSelector` 只在使用者實際滾動到底部附近時呼叫 `onLoadMore()`。
- 判斷方式改用 `position.extentAfter <= 160`，比直接比較 `pixels` / `maxScrollExtent` 更穩定。
- 底部狀態文字改為「滑到底載入更多」。

### 4. 保留 cursor pagination
- 仍然使用 Twitch `pagination.cursor`。
- 有 cursor 才繼續載入。
- cursor 消失或沒有前進時停止，避免無限重複讀取。

## 影響檔案
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
