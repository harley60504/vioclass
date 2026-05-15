# Stage 123 - Android Cutout SafeArea Alignment

## 目標
修正 Android 手機橫向模式下，挖孔 / 瀏海造成部分 UI 水平偏移的問題。

## 問題
原本有些區塊會吃到 SafeArea 左右 padding，有些區塊不會。尤其聊天室底部輸入列單獨包 SafeArea，導致 header / 訊息列表 / input bar 的水平基準不同；共用 sheet 在 Android 橫向裝置上也可能因 route-level SafeArea 被挖孔側推偏。

## 修改
- `twitch_watch_chat_panel.dart`
  - 聊天室底部 input / utility 區改為只處理 bottom SafeArea，不套用 left/right SafeArea。
- `twitch_responsive_sheet.dart`
  - 共用 sheet 的 dialog / bottom sheet 停用 route-level 橫向 SafeArea 位移。
  - bottom sheet 仍保留 bottom SafeArea，避免被手勢導覽列或鍵盤擋住。

## 影響
- Android 橫向手機挖孔不會再讓聊天室輸入列或 sheet 整體往單側偏移。
- 桌面與一般手機直向邏輯不變。
