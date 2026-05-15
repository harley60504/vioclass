# Stage v64：Sheet 搜尋列、Reward Overflow、遊戲分類載入更多、聊天室最小寬度修正

更新時間：2026-05-15 04:05:33

## 本次修正重點

### 1. 貼圖 Sheet 搜尋列
- 移除上方 header 裡的小搜尋欄。
- 保留下方主要搜尋欄。
- 主要搜尋欄高度縮小，字體改為 13px，並補上 search icon 與較小 padding。
- 避免同一個 sheet 出現兩個搜尋欄造成視覺混亂。

### 2. 忠誠點數 Reward Grid Overflow
- Reward grid item 高度加大。
- Reward tile padding、icon、badge 間距進一步縮小。
- 降低「BOTTOM OVERFLOWED」機率，尤其是手機橫向與較小視窗。

### 3. 瀏覽頁遊戲分類
- 遊戲分類 selector 改成 StatefulWidget。
- 加入內部 ScrollController。
- 滾到底會觸發 `onLoadMoreGames()`。
- 目前以提高 `fetchTopGames(first: n)` 的方式累進載入更多遊戲：
  - 初始 80
  - 每次 +40
  - 上限 240
- 篩選 sheet 內保留「載入更多」按鈕作為手動 fallback。

### 4. 聊天室拖曳寬度
- 聊天室寬度仍保留比例式儲存。
- 新增 `_maxEffectiveMinChatPanelWidth = 280`。
- 桌面寬螢幕下，最小寬度不再被 22% 比例硬限制到過寬。
- 儲存 ratio 時允許低於 `_minChatPanelRatio`，避免桌面縮小後下次開啟又彈回太寬。
- 手機與小螢幕仍會受 `_minChatPanelWidth = 180` 保護，避免聊天室太窄。

## 主要影響檔案
- `lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
- `lib/features/twitch/presentation/pages/twitch_watch_page.dart`
