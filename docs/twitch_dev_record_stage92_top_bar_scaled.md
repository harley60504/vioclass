# Twitch Flutter App 開發紀錄 — Stage 92

## 主題
Watch Player 上方標題列縮放與高度修正。

## 修改檔案
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

## 修改原因
窄螢幕或縮小視窗時，上方標題列容易出現 overflow / 裁切。原本 v54 的上方列雖然有 `FittedBox.scaleDown`，但 compact 高度偏小，標題卡、頭像與動作按鈕在部分寬度下視覺上太擠。

## Stage 92 變更內容

### 1. 上方列改為較大的穩定高度
- tiny layout：`56px`
- compact layout：`60px`
- normal layout：`74px`

目的：讓按鈕、頭像、標題卡有足夠垂直空間，降低裁切與 overflow 風險。

### 2. 保留自動縮放
使用 `FittedBox(fit: BoxFit.scaleDown)` 包住固定設計寬度內容。

設計邏輯：
- 寬度足夠時：使用實際可用寬度，避免 UI 太小。
- 寬度不足時：使用最低設計寬度，再整體 scale down。

### 3. compact 非 tiny 時恢復標題資訊卡
在中等窄版寬度下，左側不再只顯示頭像，而是顯示較大的 compact stream header card。

### 4. tiny 時仍保留最小資訊模式
在非常窄的寬度下，只保留返回、頭像與右側動作按鈕，並用 `Spacer` 分隔，避免擠出右側控制按鈕。

### 5. 放大標題卡元素
- compact 標題卡高度：`52px`
- normal 標題卡高度：`68px`
- compact 頭像：`34px`
- normal 頭像：`38px`
- compact 頻道名稱字體略放大
- stream title 字體略放大

## 保留功能
- Follow / Subscribe / Reload / Stop
- 返回按鈕
- 實況主頭像
- 頻道名稱、觀看數、遊戲分類、語言、標題
- Stage 91 的底部控制列內嵌音量，不恢復音量彈窗

## 注意事項
此環境沒有 Flutter SDK，因此尚未執行 `dart analyze`。如果貼回專案後出現 analyzer 或 layout 錯誤，下一步直接依錯誤訊息修正完整檔案。
