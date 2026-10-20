# 聊天室事件與預測 UI 對照

日期：2026-10-09。範圍只限 Twitch 聊天室事件、發燒列車、預測下注與相關更新。
沒有更動登入 / OAuth 儲存、IRC 發送、點數請求 payload、播放器或原有 persisted query hash。

## 參考來源

- [StreamNook ChatMessage](https://github.com/StreamNook/StreamNook/blob/main/src/components/ChatMessage.tsx)：事件使用漸層、圖示與人名層級，而不是每筆完整粗框。
- [發燒列車](https://github.com/StreamNook/StreamNook/blob/main/src/components/HypeTrainBanner.tsx)：緊湊進度、倒數、金色旗標、升級慶祝。
- [列車更新](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/hype_train_watch.rs)：閒置 / 活躍 / 接近升級分別 15 / 3 / 1 秒。
- [預測介面](https://github.com/StreamNook/StreamNook/blob/main/src/components/PredictionOverlay.tsx)：選擇選項後確認下注、顏色表示兩邊、即時比例與結算狀態。
- [贈訂關聯](https://github.com/StreamNook/StreamNook/blob/main/src/utils/giftBombCollapse.ts)：批次摘要與子贈訂以 origin ID 關聯。

這次是沿用 VioClass 的 Flutter 元件與既有資料流重新實作，不是直接搬入 TSX 元件。

## 本次完成

| 項目 | 改善與邊界 |
| --- | --- |
| 訂閱、續訂、大量贈訂、升級 | 低飽和漸層、淡邊框、正常內文字重，突出贈送者名稱；保留原有本地化事件內容和貼圖 |
| 個別贈訂 | 精簡圖示與內文，不再每筆都有大橘框、標題、亮色側線；不丟棄任何收件人訊息 |
| Bits、raid、兌換、徽章、互動 | 共用一致事件卡層級，保留不同圖示與語意色 |
| 公告 | 按原有 msg-param-color 顯示藍 / 綠 / 橘 / 紫，不一律藍色 |
| 系統 / moderation notice | 精簡樣式，保留完整提示，不混成一般付費事件 |
| 列車 | 單行等級 / 百分比 / 倒數、漸層填色；Tooltip 保留精確進度 |
| 金色列車 | 正式旗標判斷，金色填色與圖示；普通列車不再全部橘金色 |
| 升級 | 同一列車 ID 的等級增加才慶祝；一次性粒子與升級文字，重刷不重播；系統減少動態效果時停用 |
| 列車更新 | 可見觀看工作限定的單一 timer；15 / 3 / 1 秒、失敗退避 15 秒、無重疊輪詢；reset / dispose 取消 |
| 暫時列車 API 錯誤 | 保留最後結果，倒數仍按 expiresAt 走，不因錯誤突然清空 |
| 預測入口 | 收斂漸層、細比例條；兩邊名称與比例分開，0% 的文字不擠進細進度條 |
| 手機下注 sheet | 不重複堆疊狀態 / 人數 / 點數 chips；選邊、快捷點數、單一確認，短高度可整頁捲動 |
| 鍵盤 | sheet 容器已避開鍵盤，移除內部重複的 viewInsets padding |
| 即時更新 | 既有 Hermes + GQL 後備保持；比例平滑更新、不顯示工程用同步 chip；確認後只顯示細進度線 |
| 過期與結算 | 本地倒數到期立即停止下注，不等待下一次 API；終止狀態不得被 ACTIVE 舊回應覆蓋 |
| 下注錯誤 | 真正拋回失敗給 sheet，不再把失敗當已下注；重點擊只送一次；已收即時確認不再重加點數 |
| 網路失敗 | 一次暫時失敗不打擾；連續兩次失敗才顯示精簡保留結果提示與重試入口；成功自動清除 |

## 新增 API 清單

只新增唯讀的 `BulkAllActiveHypeTrainStatusesQuery`：

- variables：`{"channelIDs":["目前頻道 ID"]}`
- persisted hash：`88e62c2cbd13b7bdce93cc8934727003a5cadd821938538f74848199fbfe84a0`
- response：`data.allActiveHypeTrainStatuses[].{id,channel.id,isGoldenKappaTrain}`
- 來源：[StreamNook hype_train.rs](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/commands/hype_train.rs)。
- 沿用現有 GQL transport，沒有新增 token 或 Cookie 讀取、儲存。
- 只在已有活躍 execution、已知頻道 ID 時取用。狀態缺失 / 失敗不影響現有進度。
- 頻道與列車 ID 必須相符；旗標必須是真正 bool。
- 每台列車取得旗標後使用最多 64 筆記憶體快取，不寫磁碟、不污染登入儲存。
- 原本 `GetHypeTrainExecution` hash 完全不變。

## 驗證

本輪只執行一次 `flutter analyze --no-pub lib/features/twitch docs/twitch_chat_event_ui_test.dart`：
0 errors、2 warnings、5 infos。沒有依分析結果反覆修改 / 重跑。

- 原有 warning：whisper history API:133、whisper threads API:224，try block 的 Future return 未 await。
- 原有 info：OAuth WebView:380、whisper integrity service:193，if braces。
- 本輪 info：prediction sheet:434、engagement controller:151，if braces；列車 banner:2，dart:ui import 可省略。

### Changed files

- `lib/features/twitch/api/engagement/twitch_hype_train_api_service.dart`
- `lib/features/twitch/models/engagement/twitch_hype_train.dart`
- `lib/features/twitch/services/engagement/twitch_hype_train_controller.dart`
- `lib/features/twitch/presentation/localization/vioclass_localizations.dart`
- `lib/features/twitch/presentation/watch/controllers/twitch_watch_engagement_controller.dart`
- `lib/features/twitch/presentation/watch/sheets/twitch_watch_sheet_port_launcher.dart`
- `lib/features/twitch/presentation/widgets/watch/hype_train/twitch_hype_train_banner.dart`
- `lib/features/twitch/presentation/widgets/chat/cards/twitch_prediction_banner.dart`
- `lib/features/twitch/presentation/widgets/chat/message/twitch_chat_message_cards.dart`
- `lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`
- `lib/features/twitch/presentation/sheets/prediction_bet/twitch_prediction_bet_helpers.dart`
- `lib/features/twitch/presentation/sheets/prediction_bet/twitch_prediction_bet_sheet_widgets.dart`
- `docs/twitch_chat_event_ui_test.dart`
- `docs/twitch-chat-event-ui-review.md`

`flutter test docs/twitch_chat_event_ui_test.dart --no-pub --reporter expanded`

25 項通過：旗標解析 / round-trip / 新查詢與 cache / 可選查詢失敗保留進度 / 關盤禁止下注 /
暫時錯誤與輪詢退避 / timer 不重複 / dispose / 切台後舊回應無效 / 升級不重播 /
九類事件窄版 280px 與 1.45 倍文字 / 零比例 / 短版 320px 高度 /
選邊不直接送出 / 確認下注 / 失敗回復 / 重複點擊 / 即時回報不重算 /
慢回應不覆蓋結算 / 連續失敗的精簡回復提示。

測試為離線 fixture 與 widget 行為測試，不代表已完成真實 Twitch 所有事件與 Android 實機驗證。

## 尚未宣稱完成的 StreamNook 差異

- 沒有將大量贈訂子訊息合併成可展開的收件人清單。本次改為精簡逐筆顯示，保留所有資訊。
  要完全合併，需以 origin ID 建立顯示分組，並一起驗證 paused feed、鍵盤選取與聊天歷史索引；不能只按人名或時間猜測而隱藏訊息。
- 沒有複製 StreamNook 的事件樣式自訂設定、事件文案模板、多聊天室混合列車。
- 欠真實活動中的金色列車、升級、結束、平台退款 / 贏輸回報與 Android 鍵盤實機驗證。
  目前 UI 表達官方結算與勝出，但不猜測尚未回報的實際派彩金額。
