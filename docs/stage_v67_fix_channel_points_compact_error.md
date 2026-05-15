# Stage v67：修正 Channel Points compact 變數誤用

更新時間：2026-05-15 04:24:54

## 修正內容
- 修正 v66 中 `twitch_channel_points_sheet_widgets.dart` 的兩個 build error。
- 問題原因是 `_StatusChip` / 其他非 `_CostChip` widget 被誤套用 `compact ? 10 : 12`，但該 widget 沒有 `compact` 變數。
- 保留 `_CostChip` 的 compact 字體邏輯，讓右上角點數 chip 仍可縮小。
- 額外移除 `twitch_watch_page.dart` 中 v64 遺留的兩個未使用 local variable：
  - `ratioLimitedMax`
  - `maxByViewport`

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/pages/twitch_watch_page.dart`
