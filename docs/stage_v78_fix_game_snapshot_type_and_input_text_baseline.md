# Stage v78：修正 GameLoadSnapshot 型別錯誤與輸入實際文字垂直偏移

更新時間：2026-05-15 06:10:00

## 本次修正

### 1. 修正 build error
錯誤：
- `Future<void> Function()` 無法傳給 `Future<_GameLoadSnapshot> Function()`

原因：
- `_BrowseHeader.onLoadMoreGames` 需要回傳 `_GameLoadSnapshot`，這是正確的，因為 parent `_loadMoreGames()` 需要把最新遊戲資料回傳給 sheet。
- 但 `_GameWaterfallSelector` 只需要一個「觸發載入」 callback；sheet 內的 `loadMoreInsideSheet()` 已經把 snapshot 寫回 local state，所以 selector 不需要知道 `_GameLoadSnapshot` 型別。
- v77 把 `_GameWaterfallSelector.onLoadMore` 也設成 `Future<_GameLoadSnapshot> Function()`，導致 `loadMoreInsideSheet()` 的 `Future<void>` 型別不相容。

修正：
- `_BrowseHeader.onLoadMoreGames` 保持：
  - `Future<_GameLoadSnapshot> Function()`
- `_GameWaterfallSelector.onLoadMore` 改回：
  - `Future<void> Function()`
- `_GamePaginationStatusTile.onRetry` 也保持：
  - `Future<void> Function()`

### 2. 修正輸入框「顯示文字置中，但實際輸入文字偏高」
原因：
- placeholder 是外層 `Text` 自己畫的，因此已經置中。
- 真正輸入文字是 `EditableText` 內部 `RenderEditable` 畫的，baseline 與 cursor 高度仍然會讓文字看起來偏高。
- 所以兩者即使都包在 `Align.centerLeft`，視覺中心仍可能不同。

修正：
- `EditableText` 外層高度從 `fontSize * 1.18` 改為 `fontSize * 1.42`。
- 對實際輸入文字加上小幅 top compensation：
  - `textTopCompensation = fontSize * 0.11`
- placeholder 仍然保持外層置中。
- 目標是讓實際輸入文字與 placeholder 的視覺高度更接近。

## 影響檔案
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
