# Stage v77：修正遊戲分類 Sheet 沒有接上載入後更新

更新時間：2026-05-15 06:01:46

## 問題原因
- `_loadMoreGames()` 本身有呼叫 API，也有 append 到 parent `_games`。
- 但篩選 sheet 是 `showTwitchResponsiveSheet()` 開出去的獨立 route。
- Sheet 裡的 `_GameWaterfallSelector(games: games, ...)` 吃的是打開 sheet 當下 `_BrowseHeader` 的 `games` 快照。
- Parent `setState()` 更新 `_games` 後，已經開著的 sheet 不一定會重建，也就是 UI 看起來像「滾到底沒有更新」。

## 修正內容
- 新增 `_GameLoadSnapshot`，讓 `_loadMoreGames()` 回傳最新：
  - games
  - loading
  - loadingMore
  - hasMore
  - error
- `_loadMoreGames()` 從 `Future<void>` 改成 `Future<_GameLoadSnapshot>`。
- `_openFilterSheet()` 內使用 `StatefulBuilder` 維護 sheet 自己的 local state：
  - `sheetGames`
  - `sheetLoading`
  - `sheetLoadingMore`
  - `sheetHasMore`
  - `sheetError`
- `_GameWaterfallSelector` 滾到底時呼叫 local `loadMoreInsideSheet()`。
- `loadMoreInsideSheet()` 等 parent `_loadMoreGames()` 完成後，把回傳 snapshot 寫回 sheet local state。
- 這樣 sheet 開著時也會即時看到新增的遊戲。

## 分頁設定
- 遊戲分類維持每頁 50。
- `TwitchDiscoveryService.fetchTopGames()` 預設值也改成 50。

## 影響檔案
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/services/discovery/twitch_discovery_service.dart`
