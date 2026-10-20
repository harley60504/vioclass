# 通知行為對照（2026-10-09）

這份檢查針對「什麼事件值得通知、啟動如何處理、保留多久」，不是外觀改版。對照 StreamNook main 的實際程式，不只看設定頁文字。**尚未完整對齊所有通知來源**。

## 來源與啟動規則

| 項目 | StreamNook 實作 | VioClass 本輪結果 |
|---|---|---|
| 追隨頻道開台 | 首次直播快照只建立基準；之後離線變直播通知。同頻道 5 分鐘內去重 | 已對齊：每分鐘檢查完整分頁，按頻道而非 stream ID 判斷；網路失敗不把頻道視為離線。重開、重新啟用監看或換帳號重新建立基準，不通知已在播的全部頻道 |
| 收藏但未追隨的頻道開台 | 獨立監看與開關 | 尚未新增收藏頻道通知來源 |
| 私訊 | 收到新的對方訊息才通知，不通知自己送出的訊息 | 保留既有收件事件來源；恢復通知歷史不重新推送。沒有重新載入整個私訊 API 或修改其儲存 |
| 點數 | 取得點數事件合併，最後一筆後安靜 3 秒再發摘要 | 已加入正數增量合併、頻道分組；初始餘額不通知；領取成功後的餘額增量扣除已通知的領取額，避免雙份。只出現可領取寶箱但尚未取得點數不通知 |
| 已領取 Drops | 領取成功後通知 | 現有手動領取結果接入共用通知服務；Windows 留通知紀錄，Android 用系統通知。沒有新增自動領取流程，也沒修改領取 payload／成功判斷 |
| 收藏遊戲的新 Drops | 只通知收藏遊戲的新活動，首次讀取靜默 | 使用者決定不加入新 Drops 活動通知；不新增收藏遊戲 UI，也不通知所有遊戲活動 |
| App 新版 | 啟動後 5 秒檢查，之後每 30 分鐘；同版本跨重開只宣布一次 | 已加入：未設定的新安裝預設自動檢查，保留已保存的開關選擇。關閉自動檢查不排定檢查；手動檢查只更新版本狀態、不額外推送。更新入口仍在既有外框／手機設定，通知不在啟動時強制打開更新 sheet |
| 可取得的新徽章／開放取得 | 獨立徽章活動 feed；首次一批靜默建立基準，資料說明變更不當新通知 | 尚未有對應活動 feed；聊天室顯示某人徽章不等於新徽章活動通知 |
| 自己收到贈訂 | 輪詢 Twitch 官方通知 feed，不是看到聊天室的任意贈訂就通知；初次安裝只建立已見 ID | 已接入唯讀帳號通知 feed；每 5 分鐘讀取，首次成功靜默建立基準，按帳號／通知 ID 跨重開去重 |
| 自己獲得徽章／Drop 獎勵 | 同一 Twitch 通知 feed，按類型分類；第一次啟用靜默建立基準 | 已接入自己取得徽章；不新增 Drop reward feed 通知，保留既有手動領取結果。不是「新徽章活動」通知 |
| 操作結果／失敗 | 一般操作回饋可留紀錄；錯誤與警告不能因關閉例行通知而完全吞掉 | 保留現有操作回饋；未新增全部分類的偏好開關 |

對照來源：[開台基準](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/live_notification_service.rs)、[開台去重](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/live_announce.rs)、[通知種類與新 Drops 啟動說明](https://github.com/StreamNook/StreamNook/blob/main/src/components/settings/NotificationsSettings.tsx)、[點數摘要](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/channel_points_summary.rs)、[更新監看](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/update_watch.rs)、[自己收到贈訂與獎勵](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/onsite_notifications.rs)、[徽章通知去重狀態](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/badge_polling_service.rs)。

## 提示壽命不等於歷史保留

- StreamNook：開台 toast／外框短預覽 8 秒，其他類型 5 秒。開台 toast 懸停可暂停剩餘時間。通知中心跨重開保存，最多 20 筆；讀取時過濾超過 7 天的紀錄。[AppStore](https://github.com/StreamNook/StreamNook/blob/main/src/stores/AppStore.ts)、[ToastManager](https://github.com/StreamNook/StreamNook/blob/main/src/components/ToastManager.tsx)、[DynamicIsland](https://github.com/StreamNook/StreamNook/blob/main/src/components/DynamicIsland.tsx)。
- VioClass 已改成預設開台 8 秒、其他 5 秒；可由個別錯誤呼叫明確指定較長時間。歷史最多 20 筆／7 天，跨重開恢復已讀狀態；恢復只加入歷史，不再次跳 toast 或手機系統通知。
- **仍有差異**：VioClass 一次只顯示最新一則 toast，不是 StreamNook 的多則堆疊；目前仍按經過時間到期，未加入開台 toast 的滑鼠懸停暫停。本輪不改 UI 排列；保留使用者先前要求的到期隱藏行為。
- Android 提示是否停留在通知抽屜由系統／使用者操作決定，不把 App toast 的 5／8 秒規則強套成系統通知刪除時間。

## 新的儲存與啟動行為

- `vioclass_notification_history_v1`：SharedPreferences，通知標題、一般文字、時間、類型、頭像 URL、直播 metadata、私訊導航 ID、已讀狀態。沒有 token、Cookie、Integrity、私訊聊天內文。
- 序列化寫入依序執行，避免較舊快照覆蓋較新快照。清除／登出發生在讀取途中，不可把舊紀錄復活；未知／損壞的單筆紀錄跳過。恢復直播／更新通知時重新綁定動作，不保存 Flutter callback。
- 登出清除 App 通知紀錄及尚未發送的點數摘要。取得新的私訊帳號後移除其他帳號的私訊通知；暫時驗證失敗不拿空帳號清除既有紀錄。
- `vioclass_announced_update_versions_v1`：已宣布的 release tag；與登入憑證完全分開。手動更新檢查不記成自動宣布。
- 開台基準與 5 分鐘去重是本次執行的記憶體狀態。重開後先取得最新快照，不重新宣布當時已在直播的人；不是跨重開重新播放上次通知。

## 截圖錯誤

「No Overlay widget」來自通知卡片的關閉 IconButton tooltip。通知外框位在 Navigator 的 Overlay 上方，原本 widget 測試在 route 裡，未涵蓋實際層級。已改為不依賴 Overlay 的關閉按鈕可及性標籤，並加入 `MaterialApp.builder` 的相同層級回歸測試。沒有趁此再改通知外觀。

## 下一輪需要的來源

1. 帳號通知 API 已加入，細節見下面；需要真實收到贈訂／徽章事件驗證，不以 mock 測試宣稱實機通知完成。
2. 新 Drops 活動通知：使用者明確取消，不再新增。
3. 可取得徽章活動：需活動可用時間與可靠來源；現有聊天室 badge set API 不足以證明「新徽章活動出現」。不要把別人的徽章資料當作自己取得獎勵。
4. 依上述來源補對應分類開關，然後實機驗證啟動、重新登入、網路重連、快速開關台與手機背景收件。

## 本輪修改清單

通知服務：`twitch_app_notification_service.dart`、`twitch_system_notification_service.dart`，新增 `twitch_notification_history_store.dart`、`twitch_live_notification_policy.dart`。

接線：`twitch_stream_page.dart`、`twitch_stream_page_parts/01_color.dart`、`02_twitch_stream_page_state_playback_ops.dart`、`vioclass_update_controller.dart`、`twitch_watch_engagement_controller.dart`、`twitch_drops_connection_page.dart`、`twitch_drops_connection_page_parts/01_k_purple.dart`。

截圖修正：`twitch_notification_card.dart`、`twitch_app_notification_overlay.dart`。

測試／文件：`docs/twitch_notification_policy_test.dart`、`docs/twitch_notification_expiry_test.dart`、`docs/twitch_notification_style_test.dart`、本文件。

## 本輪驗證與停止點

以下為上一輪結果；錯誤已於後續輪次修正，最新結果見文末。

- 三份通知測試共 38 個通過：包括提示到期、不同字體／宽度、首次開台基準、5 分鐘去重、跨重開歷史、換帳號、清除與載入競態、3 秒點數摘要、版本宣布去重，以及 Navigator 上方沒有 Overlay 祖先的通知卡片。
- 本輪只執行一次 scoped `flutter analyze`（16 個 Dart 檔案）：**1 error、4 warnings、5 infos**。依專案規則停止修正循環，沒有再次執行 analyze；新版未編譯／啟動。
- Error：`twitch_watch_engagement_controller.dart:270`，點數 claim 的動態回應導致 `earned` 為 `num`，`Map<int,int>.update` 的加總 closure 需要 `int`。下一輪先把通知層的點數正規化成整數，不修改 Channel Points payload。
- Warnings：`docs/twitch_notification_policy_test.dart:242/289/320` 使用測試用 SharedPreferences mock（檔案位於 docs，被 analyzer 視為非 test 目錄）；`twitch_stream_page_parts/01_color.dart:431` 的 monitor 空值檢查已被 Dart promotion 判定多餘。
- Infos：`twitch_stream_page.dart:3` 重複匯出型別的 import；`01_color.dart:423/433`、`twitch_watch_engagement_controller.dart:152`、`twitch_live_notification_policy.dart:23` 的 if 大括號提示。
- 通知 widget／policy 測試通過不代表整個 App 已可編譯；特別是上面的 watch controller 接線未被這三份隔離測試涵蓋。下一輪修正後還需完整 Windows 編譯與實機測試。

## 後續輪次：贈訂與取得徽章（2026-10-09）

- 新增 `TwitchAccountNotificationApi`：POST `https://gql.twitch.tv/gql`，raw query `VioAccountNotifications($first:Int!)`，`currentUser { id notifications(first:$first, language:"en", displayType:VIEWER) { edges { node { id type category body createdAt thumbnailURL } } } }`，first=25。沒有新增或改動 persisted query hash。
- Headers 使用既有 `Client-ID: kimne78kx3ncx6brgo4mv6wki5h1ko` 與 `Authorization: OAuth <existing token>`。先讀既有 web GQL token，必要時嘗試既有主登入 token；每個候選驗證 userId，回應 currentUser.id 再核對。沒有新增 WebView、Cookie 讀取、Integrity 更新或 token 儲存邏輯。
- 篩選 `category == gift_subscriptions`、`type` 含 `earned_badge`；排除 promotions、lifecycle、Drop reward、watch streak 與其他事件。通知正文移除 Twitch 的粗體 markdown，沿用現有共用卡片與頭像，Windows App 內／Android 系統通知。不新增 action URL 或 Android 點擊導航。
- 每 5 分鐘檢查；首次成功基準靜默。`vioclass_account_notification_seen_v1_<userId>` 在 SharedPreferences 保存最多 200 個已見 ID，不保存 token、Cookie 或通知正文。該基準不因登出被清除，避免同帳號重登入重播；損壞基準靜默重建。GQL errors、缺資料、錯帳號不是空清單，不覆蓋基準。
- 先成功保存 ID 再發通知；寫入序列化。停止／換帳號的 generation guard 丟棄舊請求結果。通知歷史附 accountOwnerId，換帳號移除其他帳號的贈訂／徽章歷史，恢復历史不再次彈出。
- 新通知監看依附主頁登入生命週期，不代表 Android 被系統終止後仍會執行；本輪沒有擴充背景常駐服務。
- 已修正點數通知層的 num → int 錯誤，不修改 Channel Points payload；修正上一輪相關 analyzer 提示。
- 四份通知測試共 47 個通過（含新增解析／基準／失敗保留／跨重開／換帳號／歷史隔離測試）；仍需實機收到新事件驗證。沒有測試時主動贈訂或產生其他付費操作。
- 本輪唯一一次 scoped `flutter analyze`（19 個 Dart 檔案）：No issues found。

本輪實際修改檔案：

1. `lib/features/twitch/api/notifications/twitch_account_notification_api.dart`（新增）
2. `lib/features/twitch/services/notifications/twitch_account_notification_monitor.dart`（新增）
3. `lib/features/twitch/services/notifications/twitch_app_notification_service.dart`
4. `lib/features/twitch/services/notifications/twitch_system_notification_service.dart`
5. `lib/features/twitch/services/notifications/twitch_live_notification_policy.dart`
6. `lib/features/twitch/presentation/pages/twitch_stream_page.dart`
7. `lib/features/twitch/presentation/pages/twitch_stream_page_parts/01_color.dart`
8. `lib/features/twitch/presentation/watch/controllers/twitch_watch_engagement_controller.dart`
9. `docs/twitch_account_notification_test.dart`（新增）
10. `docs/twitch_notification_policy_test.dart`
11. `docs/twitch-notification-behavior.md`
