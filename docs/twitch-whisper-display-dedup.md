# 私訊顯示去重與授權入口

- 登入驗證完成（`sessionReady`）後，寬版及窄版上方不再顯示重新授權入口。未通過驗證仍可授權；錯誤重試流程不變。
- 本機送出使用 `local-` ID；Helix 不回傳 Twitch 訊息 ID，因此同步歷史取得正式 ID 時，原本可能出現兩列。
- `displayMessages` 僅隱藏已提交的本機列：參與者與文字相同、時間相差不超過 30 秒，且本機與官方歷史兩側均能唯一配對。這是保守的顯示推定，不是官方送達證明。
- 無法唯一配對、多次相同文字、失敗／未確認／送出中訊息不合併。不同正式 ID 的收件訊息也不以文字或時間合併。
- 原始訊息、草稿、未讀狀態與存檔格式完全保留。顯示推定不刪除或改写紀錄；OAuth/token、GQL hash 皆未變更。
- `twitch_whisper_display_test.dart` 與 `twitch_whisper_inbox_test.dart` 共 164 項通過。
- 本輪 scoped `flutter analyze` 有既有兩項 info：`twitch_whisper_sheet.dart:141`、`:153` 缺少 if 區塊括號，無 error/warning。依專案規則未再執行或修正無關提示。
- 實機仍需確認重複是否為本機送出＋歷史；若為收到的訊息，需核對兩列實際 ID，不能宣稱所有重複原因已解決。
