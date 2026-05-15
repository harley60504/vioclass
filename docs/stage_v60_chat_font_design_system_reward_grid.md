# Stage v60：聊天室字體設定、Design System 分類、Reward/Grid 本地化

更新時間：2026-05-15 03:41:38

## 本次新增架構分類
新增可維護分類檔案：
- `presentation/design/twitch_breakpoints.dart`
- `presentation/design/twitch_typography.dart`
- `presentation/design/twitch_spacing.dart`
- `presentation/settings/twitch_chat_appearance_controller.dart`
- `presentation/sheets/twitch_chat_appearance_sheet.dart`
- `presentation/localization/twitch_reward_localizer.dart`

## 聊天室字體調整
- 聊天室 header 新增「字體大小」按鈕。
- 可用 slider 拖曳調整聊天室字體。
- 設定會透過 SharedPreferences 保存。
- 新增預覽區：使用者名稱、訊息、emoji/emote 大小會一起變化。
- 手機橫向 / 低高度時套用 compact factor，讓同樣 scale 下更省高度。

## 聊天訊息縮放
- `TwitchChatMessageList` 新增 `compact` 參數。
- `TwitchRuntimeMessageTile` 新增 `compact` 參數。
- username、message、badge、emote、系統訊息會跟著 fontScale 變化。

## 忠誠點數
- 忠誠點數 rewards 改為 grid/table 顯示。
- reward title 加入基礎中文翻譯：
  - Choose an Emote to Unlock → 選擇解鎖貼圖
  - Modify a Single Emote → 修改單一貼圖
  - Unlock a Random Sub Emote → 解鎖隨機訂閱貼圖
  - Highlight My Message → 醒目顯示訊息
- reward tile 字體與 icon 壓小，提高資訊密度。

## 瀏覽頁
- 語言增加為熱門 10 種左右。
- Top games 載入數量從 20 增加到 80。
- 遊戲分類 grid 更接近貼圖表格風格。

## 後續建議
- 將 `TwitchRewardLocalizer` 與使用者提供的 `twitch_event_localizer.dart` 整合成完整 localization module。
- 若要做到真正 infinite scroll，需要 discovery service 支援 top games cursor / pagination。
