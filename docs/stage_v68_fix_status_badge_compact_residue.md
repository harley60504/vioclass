# Stage v68：徹底修正 StatusBadge compact 殘留

更新時間：2026-05-15 04:29:08

## 修正內容
- 修正 v67 後 `_StatusBadge` 裡仍殘留 `compact` 變數引用的問題。
- 錯誤位置：
  - `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
  - `_StatusBadge` 內 padding / font style
- `_StatusBadge` 沒有 `compact` 欄位，因此改回固定：
  - `padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4)`
  - `fontSize: 11`
  - `fontWeight: FontWeight.w800`
- `_CostChip` 的 compact 欄位保留，用於右上角點數 chip。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
