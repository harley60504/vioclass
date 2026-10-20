# 通知呈現調整

參考 [StreamNook ToastManager](https://github.com/StreamNook/StreamNook/blob/main/src/components/ToastManager.tsx) 的緊湊半透明卡片與開台資訊分層；不是新增全部 StreamNook 通知事件。

## 本次範圍

- Windows：即時通知與通知列表共用玻璃感卡片，最大寬度 380，弱化邊框，不再使用整條高彩度側線。窄寬度或放大字體時，底部動作可換行。
- 開台：顯示實況主頭像、名稱、遊戲與直播標題。單一頻道可按卡片或「觀看直播」進入播放頁；多頻道通知保留合併策略，最多三個重疊頭像。
- 忠誠點數、私訊與一般提示共用表面樣式，以語意圖示區別；私訊維持原本的對話開啟行為。
- Android：維持系統通知；開台通知加入頭像 largeIcon 與可展開的完整文字。頭像下載超過三秒或失敗，仍發送文字通知。Android 的開台點擊導航不在本次範圍。
- 保留通知到期自動隱藏與歷史記錄、初次監看不大量通知、通知列表點外側關閉的既有行為。

## 資料與邊界

開台監看原本收到的直播資料未必有頭像；本次僅對新開台的頻道沿用既有 Helix users 批次查詢補入頭像。查詢失敗仍顯示通知與預設圖示。沒有新增 GQL、修改 persisted query hash、登入憑證儲存或點數 payload。

尚未新增 StreamNook 的 Drops、徽章、贈訂等其他通知來源或新的通知偏好設定；本次先統一已存在的通知。

## 修改檔案

- `lib/features/twitch/services/notifications/twitch_app_notification_service.dart`
- `lib/features/twitch/services/notifications/twitch_system_notification_service.dart`
- `lib/features/twitch/services/discovery/twitch_discovery_service.dart`
- `lib/features/twitch/presentation/pages/twitch_stream_page_parts/01_color.dart`
- `lib/features/twitch/presentation/widgets/notifications/twitch_app_notification_overlay.dart`
- `lib/features/twitch/presentation/widgets/notifications/twitch_notification_card.dart`
- `docs/twitch_notification_style_test.dart`
- `docs/twitch-notification-style.md`

## 驗證

`flutter test docs/twitch_notification_style_test.dart docs/twitch_notification_expiry_test.dart --no-pub`：19 個測試通過。涵蓋 220／280／380 寬度、一般與兩倍字體、分類外觀、動作和關閉互不干擾、多頭像、開台資料傳遞，以及到期後隱藏但保留歷史。

本輪只執行一次針對七個 Dart 檔案的 `flutter analyze`：0 errors、0 warnings、3 infos（通知服務第 67／69／71 行的 `curly_braces_in_flow_control_structures`）。依專案規則保留到下一輪處理，沒有反覆修正再分析。

仍需實機確認真實頭像下載、Windows 開台通知進入播放，以及 Android 系統通知的頭像呈現；widget 測試不代表 Android 裝置驗證完成。
