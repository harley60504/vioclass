# 聊天室／私訊共用貼圖排列

## 完整內嵌面板共用

- 聊天室與私訊的內嵌面板現在均使用 `TwitchEmotePickerPanel`，不再各自繪製搜尋、分類、關閉按鈕或處理搜尋狀態。
- 呼叫端只提供分類描述、貼圖列表建立器、載入／錯誤狀態及選取／關閉動作。聊天室保留最近、收藏與來源分類；私訊同時提供官方貼圖與 Unicode 分類，不借用聊天室權限。
- 分類統一使用可垂直捲動的左側欄，短高度也不換成橫向列或選單。搜尋和關閉放在同一標頭。原本獨立開啟的聊天室大視窗外殼與分頁仍保留，統一的是聊天室／私訊實際使用的內嵌面板。
- 動圖圖片路徑未變更，仍由既有原生解碼元件處理。
- 訂閱分類回歸修正：內嵌聊天室不再攤平官方子頁；左側列出頻道、全域、每個訂閱頻道與已解鎖，保留各自的貼圖列表與權限。
- 聊天室新增 Emoji 分類；聊天室與私訊共用 `TwitchEmojiPicker`。聊天室 emoji 直接依輸入游標／選取範圍插入純文字，不走貼圖名稱查找或修改 IRC 協議。
- 私訊輸入列只保留一個笑臉入口，開啟合併面板（預設 Twitch，左側可切換 Emoji）；移除重複 GIF 按鈕。
- 新增共用面板搜尋、分類切換、小高度、關閉測試；聊天室／私訊整合測試會確認實際使用同一面板類別。

- 共用 `TwitchEmotePickerFlow` 與 `TwitchEmotePickerTile`，改用延遲建立的緊密 Wrap 列，不使用 GridView／SliverGrid 或大型卡片。貼圖名稱、鎖定狀態、收藏與長按操作保留。
- 聊天室及私訊貼圖使用既有 `TwitchEmoteImage`。私訊訊息內的貼圖也改用此元件；官方動圖交給既有 `TwitchNativeAnimatedEmoteImage`／`NativeAnimatedImageProvider`。未修改原生解碼套件或平台檔案。
- 私訊仍以自己的官方貼圖資料與權限為來源，不混用聊天室的頻道貼圖資料。窄版的搜尋整合在面板標頭，表情與官方貼圖均使用同一排列元件。
- 聊天室底部空白來自 `Flexible(flex: 3, fit: loose)` 分配的高度大於內部 SizedBox 上限。改為按可用空間設定面板高度，訊息區 Expanded 吸收剩餘空間。開啟面板時暫時隱藏可選互動卡片，關閉後恢復。
- 2026-10-05 最新驗證：`twitch_emote_picker_flow_test.dart`、`twitch_watch_chat_keyboard_test.dart`、`twitch_whisper_inbox_test.dart` 共 173 項通過，另涵蓋各訂閱頻道分類保留、聊天室 emoji 插入及私訊單一笑臉入口。
- scoped flutter analyze 本輪僅執行一次：7 個指定來源／測試檔案，No issues found。其後僅修正短高度測試的點擊座標，未再次執行 analyze。
- 真實動圖播放與 Windows／Android 最終外觀仍需實機確認。App 已關閉，尚未熱更新至本輪版本。
