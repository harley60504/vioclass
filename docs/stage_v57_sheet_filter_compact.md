# Stage v57：Sheet 壓縮、橫向滿高、瀏覽篩選二級選單

更新時間：2026-05-15 02:53:38

## 本次修改重點

### 1. 共用 Sheet 高度策略
- `TwitchResponsiveSheet` 手機橫向 compact dialog 改為幾乎吃滿可用上下高度。
- 橫向時降低 inset 與圓角，避免 sheet 因高度太矮造成內容 overflow。
- 新增 `TwitchResponsiveSheetHeader`，統一提供：重新整理、關閉、搜尋、可選標題。

### 2. 貼圖 Sheet
- 移除原本較佔高度的最上方「貼圖 + 數量」header。
- 改為只保留：搜尋、重新整理、關閉。
- 搜尋列直接併入共用 header，減少一整排垂直高度。
- 橫向或小高度時 tab row 變矮。

### 3. 忠誠點數 / 下注 Sheet
- 忠誠點數 header 改矮，只保留重點資訊、重新整理、關閉。
- 忠誠點數 sheet 改為吃滿共用 sheet 提供的高度，不再自行用固定 0.78 高度。
- Prediction 下注 sheet 壓縮上方 header、padding 與間距。

### 4. 至頂留言 / 下注提示區
- 置頂留言與 engagement strip 減少 padding、字體與卡片高度。
- 移除不必要的高佔用，讓聊天室訊息與輸入列優先保留空間。

### 5. 瀏覽頁篩選
- 瀏覽頁語言與遊戲類型改成同一個「篩選」二級選單。
- 二級選單使用共用 responsive sheet。
- 手機窄螢幕不再同時塞語言 dropdown 與遊戲類型選單，避免橫向爆版。

## 輸出結構
- `lib/`：修改後的 Flutter 專案 lib 目錄。
- `docs/`：本次與歷史開發紀錄。
