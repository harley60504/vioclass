# Stage v65：修正遊戲分類載入更多分頁

更新時間：2026-05-15 04:10:48

## 問題原因
- v64 使用 `_gameFetchLimit += 40` 並重新呼叫 `fetchTopGames(first: n)`。
- Twitch Helix list API 的 `first` 有 page size 上限，不能靠 `first: 120/160/240` 取得更多資料。
- 正確方式是使用 response 的 `pagination.cursor`，下一頁用 `after` 查詢。

## 修正內容
### Service / Model
- `TwitchDiscoveryService.fetchTopGames()` 改為回傳 `TwitchGamePageResult`。
- `fetchTopGames()` 新增 `after` 參數。
- 新增 `_parseGamePage()`，解析 top games response 的 `data` 與 `pagination.cursor`。
- 新增 `TwitchGamePageResult` model：
  - `games`
  - `cursor`
  - `hasMore`

### Browse Page
- 移除 v64 的 `_gameFetchLimit` 假分頁。
- 新增 `_gameCursor` 與 `_hasMoreGames`。
- `_loadGames()` 讀第一頁。
- `_loadMoreGames()` 使用 `after: _gameCursor` 讀下一頁並 append。
- 避免重複 game id。
- 遊戲分類 sheet 只有在 `hasMoreGames == true` 時顯示「載入更多」。

## 影響檔案
- `lib/features/twitch/services/discovery/twitch_discovery_service.dart`
- `lib/features/twitch/models/discovery/twitch_live_stream.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
