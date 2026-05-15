# Stage 94 - Watch Player Top Bar Overflow Safe Fix

## 檔案
- `twitch_watch_player_area_stage94.dart`

## 問題
使用者回報上方標題列仍出現 `BOTTOM OVERFLOWED BY 1.00 PIXELS`。
截圖顯示 overflow 出現在上方資訊卡底部，不是底部控制列。

## 原因判斷
目前版本仍為 `watch_player_area_inline_compact_controls_v54`，上方列相關高度仍偏緊：

- `_WatchTopActionBar`：`slotHeight = compact ? 48.0 : 64.0`
- `_WatchStreamHeaderCard`：`height = compact ? 44.0 : 64.0`
- 資訊卡內部有 metadata pills + stream title 兩行內容，64px 高度在 Windows/Flutter text metrics 下可能剛好超出 1px。
- 原本還有雙層 `FittedBox`，垂直尺寸計算容易在邊界情況產生 1px overflow。

## 修改內容
1. 新檔案改名為 `twitch_watch_player_area_stage94.dart`，避免與舊檔混淆。
2. 上方列高度加大：
   - compact：48 → 60
   - normal：64 → 74
3. 上方資訊卡高度加大：
   - compact：44 → 52
   - normal：64 → 72
4. 上方資訊卡 padding 微調：
   - compact vertical：6 → 5
   - normal vertical：8 → 9
5. 移除雙層 `FittedBox`，改為單層 `FittedBox + Align + Center`。
6. 標題文字區 `Column` 加入 `mainAxisSize: MainAxisSize.min`，避免 Flex 高度邊界誤差。
7. 保留 Stage 91 的底部控制列內嵌音量 slider，沒有恢復音量彈窗。

## 預期效果
- 上方資訊卡不再出現 bottom overflow 1px。
- 上方標題列維持較大的視覺尺寸。
- 窄螢幕仍可透過 `FittedBox.scaleDown` 避免橫向 overflow。
