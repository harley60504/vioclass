# Stage v70：下注可滾動、忠誠點數按鈕數字、Overlay 簡化、輸入列對齊

更新時間：2026-05-15 04:52:33

## 本次修正重點

### 1. 下注 / Prediction 區避免被裁切
- 調整 `TwitchWatchChatPanel` 內互動區最大高度。
- 手機橫向 / 低高度時不再壓到只剩很小高度。
- 保留 `SingleChildScrollView`，當置頂留言 + prediction 同時存在時，互動區可以自己上下滾動。

### 2. 聊天室忠誠點數小按鈕顯示短數字
- 修改聊天室工具列的粉紅忠誠點數入口按鈕。
- 不是 sheet 上方餘額，而是聊天室底部工具列那顆小按鈕。
- 顯示格式：
  - `999`
  - `1k`
  - `9.9k`
  - `1w`
  - `120w`
  - `1b`
- tooltip 仍顯示完整數字。
- compact 模式也會顯示短數字，不再只有 icon。

### 3. 忠誠點數 sheet 內數字維持完整
- 新增 / 調整共用格式：
  - `formatChannelPointFullNumber()`：sheet 內完整加逗號，例如 `9,990`
  - `formatChannelPointCompactNumber()`：聊天室小按鈕短格式，例如 `9.9k`
- reward cost 與 sheet balance 改用完整數字。

### 4. 忠誠點數 reward 卡片置中
- reward 圖片改成真正置中。
- 圖片放大到 82x82。
- 標題與 prompt 置中。
- 點數 chip 保留右上角 overlay。
- 右下角保留箭頭或鎖頭。
- 整體減少上下空白感。

### 5. 解鎖 / 修改貼圖 overlay 移除 title
- 移除 `Choose an Emote to Unlock` / 修改貼圖 title。
- 移除 StreamNook-style subtitle。
- Header 只保留：
  - 返回鍵，如果有上一層
  - 搜尋欄 / 修改效果提示
  - 重新整理
  - 關閉
- 降低 overlay header 高度。

### 6. 聊天室輸入列對齊
- 輸入框與 Send 按鈕高度統一。
- compact 與正常模式的上下 padding 重新整理。
- TextField 垂直 padding 改為 0，由外層高度控制置中。
- Send 按鈕加入 `minimumSize` 與 `shrinkWrap`，避免上下不一致。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_emote_overlay.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_utils.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
