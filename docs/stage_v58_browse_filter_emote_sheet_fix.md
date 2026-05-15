# Stage v58：瀏覽篩選整理與貼圖 Sheet 風格修正

更新時間：2026-05-15 03:13:14

## 本次修正

### 1. 瀏覽頁
- 修正 `_BrowseHeader` 呼叫漏傳 required 參數造成的 analyze error。
- 移除原本瀏覽頁下方的舊 `_GameStrip` 顯示區，避免畫面同時出現兩套遊戲選單。
- 語言與遊戲分類集中到右上「篩選」二級選單。
- 二級選單內的遊戲改成可往下捲動的 grid / 瀑布流式排列，減少橫向寬度壓力。

### 2. 忠誠點數內部選擇貼圖 Overlay
- 對應 Channel Points 裡的 Choose / Modify Emote overlay。
- 移除上方 title / subtitle。
- Header 只保留搜尋、重新整理、關閉；有返回需求時保留返回鍵。
- Overlay 往下偏移，不再直接覆蓋忠誠點數 sheet 的主 title，視覺上比較像內層選單。

### 3. 一般聊天室貼圖 Sheet
- 一般貼圖 sheet 改回接近忠誠點數 title 的 header 風格。
- Header 統一為：標題、搜尋、重新整理、關閉。
- 貼圖 sheet 與忠誠點數 sheet 的主要字級往 13px / 12px 收斂，降低視覺不一致。

## 輸出結構
- `lib/`
- `docs/`
