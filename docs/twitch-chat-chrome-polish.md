# 聊天室 header / 操作列收尾

2026-10-09。只處理聊天室上方 header 和下方操作排列，不修改 API、登入儲存或 IRC 發送協議。

## Changed files

- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`：新增 optional trailingActions，原有傳送與貼圖序列化不變。
- `lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_header_bar.dart`：一般 56 → 44px、緊湊 44 → 40px；簡化背景和連線標示；圖示 28px，點擊區域約 40px（緊湊高度扣分隔線為 39px），保留開關及停用狀態。
- `lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_input_section.dart`：忠誠點數 / 貼圖在左，身分入口 / 發送在右。
- `lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_utility_bar.dart`：身分圖示改為 badge_outlined（識別證 / 徽章），tooltip 與功能不變；點數在窄版允許縮短顯示，tooltip 保留完整數字。
- `lib/features/twitch/presentation/widgets/watch/chat/twitch_watch_chat_layout_metrics.dart`：header 高度同步實際元件；以 108px 計入完整 composer，避免可選活動區域擠掉訊息區。
- `docs/twitch_chat_chrome_test.dart`：新增 20 項 widget / layout 測試。
- 本文件。

## 驗證

- `flutter test docs/twitch_chat_chrome_test.dart docs/twitch_chat_event_ui_test.dart --no-pub --reporter expanded`：45 / 45 通過。
- 新測試包含 220 / 280 / 320 / 768px、1 / 1.6 / 2 倍文字、大點數數字、键盤 insets、按鈕左右順序、回呼保留、空訊息不送出、傳送中狀態、無身分回呼停用、header 點擊區、無置頂 / 無預測停用、無 trailingActions 的共用輸入欄相容性。
- 本輪只跑一次 flutter analyze，僅分析五個修改 Dart 元件與新測試：No issues found。
- git diff --check：通過。

測試沒有實際操作 Android 裝置；手機輸入法、橫向鍵盤與不同裝置的底部安全區仍需實機確認。
