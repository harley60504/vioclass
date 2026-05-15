# StreamNook / Flutter Twitch App - v54 Responsive Mobile Layout Notes

## 更新目標

本次更新集中處理手機與窄螢幕的 RWD 架構問題，目標是讓播放頁、首頁側邊欄、登入頁與多種彈窗在手機直向、手機橫向與桌面寬螢幕下都能維持可用性。

## 主要修改

### 1. 播放頁 layout 改為螢幕比例判斷

- 新增 `TwitchResponsiveLayout` 共用判斷工具。
- 不再只用寬度判斷聊天室位置。
- 手機直向或窄比例時：影片在上、聊天室在下。
- 手機橫向、平板與桌面：影片在左、聊天室在右。
- 手機橫向的右側聊天室使用較小寬度，避免影片被過度壓縮。

### 2. 聊天室開關狀態加入記憶

- 新增 `twitch_watch_v2_chat_visible` SharedPreferences key。
- 使用者切換聊天室顯示 / 隱藏後會保存。
- 下次進入播放頁時會延續上次聊天室開關狀態。
- 預設開或關不重要，實際以使用者最後一次操作為主。

### 3. Following / Browse 首頁側邊欄手機優化

- 新增 compact sidebar 模式。
- 窄螢幕下 sidebar 從完整文字欄縮為 icon rail。
- 保留追隨、瀏覽、登入設定、重新整理等操作入口。
- 避免手機只剩一條很怪的內容區。

### 4. 登入頁 overflow 優化

- 登入頁主卡片改為可捲動。
- 高度不足時隱藏大 icon，減少垂直空間浪費。
- 主要操作只保留「一鍵完成 Twitch 登入」與「進入 App」。
- 次要操作收進「更多登入選項」，包含重新檢查、只補 Web/GQL、只補主 OAuth、只補 Drops / Android、登出。

### 5. Sheet / Dialog 共用 responsive template

新增 `TwitchResponsiveSheet` 作為共用彈窗模板，套用於：

- 貼圖選擇 sheet
- 官方 Twitch emote ID 選擇 sheet
- 忠誠點數 sheet
- 賭盤下注 sheet
- 忠誠點數文字輸入 dialog
- 訂閱 WebView dialog

行為設計：

- 手機直向：使用置底 bottom sheet。
- 手機橫向且高度不足：使用置中 compact dialog。
- 桌面 / 平板：限制最大寬度，避免彈窗跑到邊界或不置中。

## 新增檔案

- `features/twitch/presentation/widgets/responsive/twitch_responsive_layout.dart`
- `features/twitch/presentation/widgets/responsive/twitch_responsive_sheet.dart`

## 修改檔案

- `features/twitch/presentation/pages/twitch_watch_page.dart`
- `features/twitch/presentation/pages/twitch_stream_page.dart`
- `features/twitch/presentation/pages/twitch_linked_login_page.dart`
- `features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
- `features/twitch/presentation/dialogs/twitch_subscribe_webview_dialog_v1.dart`
- `features/twitch/presentation/dialogs/twitch_channel_points_text_input_dialog.dart`

## 後續觀察重點

1. 手機橫向時右側聊天室是否仍過寬。
2. 聊天室開關記憶是否符合預期。
3. 訂閱 WebView dialog 在手機橫向下高度是否足夠。
4. 忠誠點數、貼圖、下注 sheet 是否都能正確置中。
5. compact sidebar 的 icon 是否足夠直覺，需要的話可再改成 hamburger drawer。
