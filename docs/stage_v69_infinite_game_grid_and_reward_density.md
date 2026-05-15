# Stage v69：遊戲分類無按鈕連續滾動與忠誠點數卡片填滿

更新時間：2026-05-15 04:36:57

## 本次修正

### 1. 篩選 Sheet 遊戲區高度
- 移除 `_GameWaterfallSelector` 固定 `height: 420`。
- 篩選 sheet 改為：
  - Header
  - 語言篩選
  - 遊戲類型 title
  - 遊戲 grid 吃剩餘高度
- 目的：避免遊戲區下方被固定高度或空白區佔滿。

### 2. 遊戲分類連續載入
- 移除「載入更多」卡片。
- 改成使用內部 ScrollController：
  - 滾到接近底部自動呼叫 `onLoadMore()`。
  - grid 內容不足以填滿高度時，會在 frame 後自動補載。
  - 新資料 append 後仍靠近底部時會繼續補載。
- 保留 v65 的 cursor pagination。

### 3. 忠誠點數 Reward 卡片
- 圖片從 58x58 放大到 74x74。
- 標題字體加大到 13。
- prompt 可顯示 2 行。
- 卡片比例略縮短，讓內容更填滿，不再看起來太空。

## 主要影響檔案
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
