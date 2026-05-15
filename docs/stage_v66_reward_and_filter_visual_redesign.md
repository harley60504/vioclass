# Stage v66：忠誠點數卡片與篩選選單視覺重整

更新時間：2026-05-15 04:22:27

## 本次修正重點

### 1. 忠誠點數獎勵卡片
- 改成接近官方/StreamNook 風格的 grid card：
  - 圖案放上方並放大。
  - 標題放在圖案下方。
  - 兌換點數改成右上角 overlay chip。
  - 可兌換時右下角保留箭頭。
  - 不可兌換時右下角顯示鎖頭。
- 移除「內建 / 自訂 / 需輸入 / 需貼圖 / 需選效果」這類 log/功能標籤。
- 只在不可兌換時保留狀態提示，例如點數不足，避免正常卡片被過多標籤擠壓。

### 2. 忠誠點數 Grid 尺寸
- Reward grid 的 childAspectRatio 改成更高的卡片比例。
- 避免圖片變大後再次出現 bottom overflow。

### 3. 篩選選單語言區
- 語言篩選改成可收合。
- 預設只顯示前幾個常用語言。
- 點「更多」才展開完整熱門語言列表。
- 節省篩選 sheet 上半部高度，讓遊戲分類更容易看到。

### 4. 遊戲分類卡片
- 遊戲分類改成官方風格：
  - 大圖在上。
  - 遊戲名稱在下。
  - 選取狀態顯示紫色外框與勾勾。
- 「全部直播」也改成第一張卡片，跟其他遊戲分類統一。
- 遊戲分類仍保留 v65 的 cursor pagination 載入更多。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
