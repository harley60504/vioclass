# Stage v55 — Responsive Sheet 統一、登入 WebView 精簡、聊天室輸入列折疊

## 本次目標

這一版主要處理手機橫向與窄螢幕下的 UI 佔用問題，並開始把 Twitch App 裡不同類型的彈窗 / sheet 收斂到同一套 responsive 行為。

## 修改重點

### 1. 共用 Responsive Sheet 強化

- 更新 `twitch_responsive_sheet.dart`。
- 手機直向維持 bottom sheet 行為。
- 手機橫向 / 高度較低時改為置中的 compact dialog。
- 針對窄寬度加入最大寬度保護，避免 sheet 在手機橫向時偏移或超出畫面。
- 加入 keyboard inset padding，降低鍵盤彈出時內容被遮住的機率。

### 2. 貼圖 / 忠誠點數 / 賭盤 / 登出確認逐步統一

- `TwitchThirdPartyEmotePickerSheet` 原本已走 `showTwitchResponsiveSheet`。
- `TwitchChannelPointsSheet` 由播放頁統一使用 `showTwitchResponsiveSheet` 開啟。
- `TwitchPredictionBetSheet` 由播放頁統一使用 `showTwitchResponsiveSheet` 開啟。
- 官方 emote ID 確認視窗改用共用 responsive sheet。
- 登出確認視窗改用共用 responsive sheet。

> 後續若還有新的 sub / follow / login options / reward input 彈窗，原則上都應該走 `showTwitchResponsiveSheet`，避免每個視窗自己處理手機橫向、置中、maxWidth、maxHeight 與 keyboard inset。

### 3. 登入 WebView 手機版工具列精簡

- 手機內嵌 WebView 模式移除上方過寬的 action bar。
- 移除 App 內 WebView 上方「重載 / 複製 URL」那一排，避免小螢幕橫向時佔用太多高度與寬度。
- 桌面版仍保留 OAuth 重新開啟、進階、複製 URL 等操作列。
- 順手修正 `twitch_oauth_webview_login_page.dart` 內重複的 `initialSettings: InAppWebViewSettings(` 行，避免編譯錯誤。

### 4. 聊天室輸入列可折疊

- 更新 `twitch_watch_chat_panel.dart`。
- 新增聊天室輸入列展開 / 折疊狀態。
- 預設以較小的 collapsed prompt 呈現，減少手機鍵盤彈出前後佔用空間。
- 使用者點擊「展開輸入訊息」後才顯示完整 `TextField + Send`。
- 完整輸入列左側新增折疊按鈕，可收回輸入框並關閉鍵盤 focus。
- 更新 `twitch_chat_input_bar.dart`，支援 `onCollapse` 並縮小 padding / button 寬度。

### 5. 手機橫向聊天室寬度縮小

- 更新 `twitch_watch_page.dart`。
- 一般聊天室最小寬度由 `320` 降為 `260`。
- 手機橫向 side chat 改成依螢幕寬度比例計算：大約使用 `34%`，並限制在 `220 ~ 310`。
- 手機橫向影片區 flex 提高，避免聊天室佔掉接近一半畫面。

## 受影響檔案

- `features/twitch/presentation/widgets/responsive/twitch_responsive_sheet.dart`
- `features/twitch/presentation/pages/twitch_oauth_webview_login_page.dart`
- `features/twitch/presentation/pages/twitch_linked_login_page.dart`
- `features/twitch/presentation/pages/twitch_watch_page.dart`
- `features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
- `features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`

## 後續建議

1. 把所有新彈窗都禁止直接使用 `showDialog` / `showModalBottomSheet`，統一使用 `showTwitchResponsiveSheet`。
2. 若手機橫向仍覺得聊天室太寬，可以再把比例從 `0.34` 降到 `0.30 ~ 0.32`。
3. 聊天室輸入列後續可加 SharedPreferences，記住使用者上次是否展開。
4. 若忠誠點數獎勵列表在橫向仍太高，下一步可讓 reward detail 改成第二層 responsive sheet。
