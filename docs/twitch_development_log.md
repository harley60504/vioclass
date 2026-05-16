# Twitch Flutter App 開發紀錄

## Stage 107 — Android / iOS 首播安全畫質策略

Commit: `c36d4ab455a508da5b74ee09ecd84bf5ec22ab22`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

### 修改內容

- 保留 Dart HLS low-latency proxy，不移除 proxy 路線。
- 新增 mobile startup safe quality 選擇策略。
- Android / iOS 首播時不再優先選 `Source` / `chunked`。
- Android / iOS 首播優先選擇 video variant、非 audio-only、clean / no-ad source、720p 以內、最高 60fps。
- Windows / macOS / Linux 維持原本偏高畫質策略。

---

## Stage 108 — Discovery 首頁直播縮圖解碼降載

Commit: `21c9c8c921caa666e0677c6e10ed0bde2bb1a7f5`

### 修改檔案

- `lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart`

### 修改內容

- 將直播縮圖從固定 `520x292` 改為依卡片實際寬度與 device pixel ratio 動態計算。
- 縮圖實際請求寬度限制在 `320 ~ 480` physical px。
- `Image.network` 加上 `cacheWidth`、`cacheHeight`、`filterQuality: FilterQuality.low`、`gaplessPlayback: true`。
- 頭像圖片加上固定 `64x64` 解碼限制。

---

## Stage 109 — 建立共用 TwitchCachedImageLayer 並接入直播卡片

Commits:

- `a0396abf0b0905bbfc0e3932f4150ce76f5b1f96`
- `e6f98eb577ecd157adc343778fdca192a19f6137`

### 新增檔案

- `lib/features/twitch/presentation/widgets/shared/twitch_cached_image_layer.dart`

### 修改檔案

- `lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart`

### 修改內容

- 新增 `TwitchCachedImageLayer`。
- 支援 `cacheWidth`、`cacheHeight`、`filterQuality`、`gaplessPlayback`、`borderRadius`、circular avatar mode、fallback icon / color。
- 將直播卡片 thumbnail 與 avatar 改用 `TwitchCachedImageLayer`。

---

## Stage 110 — 聊天室貼圖、badge 與忠誠點數 icon 接入共用圖片層

Commits:

- `2799b79818b7045f3bc3bdae49164b1282043227`
- `df5e1494196f6912a47a5913b8e248a4acb15397`

### 修改檔案

- `lib/features/twitch/presentation/widgets/chat/twitch_runtime_message_tile.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`

### 修改內容

- Twitch badge、Twitch 官方 emote、第三方 emote 改用 `TwitchCachedImageLayer`。
- 聊天室底部忠誠點數 icon 改用 `TwitchCachedImageLayer.avatar(...)`。
- emote cache size 依顯示尺寸與 device pixel ratio 動態計算，並限制在 32~96 px。

---

## Stage 111 — TwitchCachedImageLayer 底層改用 CachedNetworkImage

Commits:

- `a6b448c646e1f6311673ffba059a2630d641b162`
- `3615d97685b389d0a61f83fef42071398e2d8997`

### 修改檔案

- `pubspec.yaml`
- `lib/features/twitch/presentation/widgets/shared/twitch_cached_image_layer.dart`

### 修改內容

- 新增 `cached_network_image` dependency。
- `TwitchCachedImageLayer` 底層從 `Image.network` 改為 `CachedNetworkImage`。
- `cacheWidth/cacheHeight` 對應到 `memCacheWidth/memCacheHeight`。

---

## Stage 112 — 恢復畫質記憶，新增 shared media_kit player host 基礎

Commits:

- `95ad722c2cfb0f02211f0dbe6cc4a40bd91cf26d`
- `924424aa60f9ffbcba9ca255692f85f899146a8b`
- `b1328139d5ca984a68f76209a20b8957efd5340b`

### 新增檔案

- `lib/features/twitch/services/playback/twitch_media_kit_player_host.dart`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

### 修改內容

- 新增 `TwitchMediaKitPlayerHost` 基礎。
- 恢復畫質記憶：
  - `twitch_watch_v2_preferred_quality`
  - `twitch_watch_v2_preferred_quality_<channel>`
  - 兼容舊 key `twitch_fvp_proxy_preferred_quality` 與 `twitch_fvp_proxy_preferred_quality_<channel>`。
- `loadLivePlaylist(...)` 會讀取保存畫質。
- 有保存畫質時不套用 mobile safe 720p，直接尊重使用者選擇。
- `startProxyForVariant(...)` 會保存手動切換後的畫質。

---

## Stage 113 — WatchPage 正式接入 shared media_kit player host

Commits:

- `901a4153498e383f4d6929a6ebae0184f38f9af5`
- `e3ccea1fe1bf37463b11384640a3fca72b6e06f6`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_media_kit_player_host.dart`
- `lib/features/twitch/presentation/pages/twitch_windows_player_page.dart`

### 修改內容

- `TwitchMediaKitPlayerHost` 最後一個 owner release 時會先 `pause()`，避免離開頁面後仍有聲音。
- `TwitchWatchPage` 改為：
  - import `twitch_media_kit_player_host.dart`
  - `initState()` 中透過 `TwitchMediaKitPlayerHost.acquire()` 取得 session。
  - `_player` / `_videoController` 改由 session getter 提供。
  - `dispose()` 不再直接 `_player.dispose()`，改成 `_player.stop()` 後 `_playerSession.release()`。
- 短時間返回播放頁或切台時，可重用同一個 media_kit player 物件，降低 cold-start 成本。

---

## Stage 114 — Shared player 改為 PiliPlus-like 長駐模式

Commit: `46797d17b666426d5a00bd7c70e2284e9efc24ec`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_media_kit_player_host.dart`

### 修改內容

- 移除自動 dispose timer。
- `release()` 後不再排程 dispose。
- 最後一個 WatchPage release 時只做 safety pause。
- shared `Player` / `VideoController` 長駐於 App process 中。
- 只有呼叫 `TwitchMediaKitPlayerHost.disposeNow()` 才會真正 dispose。
- live bufferSize 統一調整為 `16 * 1024 * 1024`，對齊 PiliPlus live default 非 expanded buffer 設定。

---

## Stage 115 — 對齊可用的 PiliPlus media_kit 初始化參數

Commit: `bab80c4b5755ca7849364de548e28acdaa2ae4eb`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_media_kit_player_host.dart`

### 修改內容

- `PlayerConfiguration` 新增：
  - `logLevel: kDebugMode ? MPVLogLevel.warn : MPVLogLevel.error`
  - 保留 live `bufferSize: 16 * 1024 * 1024`
- `VideoController` 改為帶入 `VideoControllerConfiguration`：
  - `enableHardwareAcceleration: true`
  - `androidAttachSurfaceAfterVideoParameters: false`
  - `hwdec: 'auto-safe'`
- 新增 `flutter/foundation.dart` import 以使用 `kDebugMode`。

---

## Stage 116 — 保留賭盤下注本地狀態，避免 realtime 更新覆蓋

Commit: `8deabae81dacba1bc46f2b42573624b985eb2b8f`

### 修改檔案

- `lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`

### 修改內容

- 新增本地 viewer bet 狀態：
  - `_localViewerOutcomeId`
  - `_localViewerPoints`
- sheet 初始化時會記住既有 viewer prediction。
- realtime prediction 更新進來時，若 incoming snapshot 沒有 viewer choice，但本地已有下注狀態，會將本地 viewer outcome / points merge 回 incoming。
- submit 時先 optimistic 記錄本地 outcome / points；submit 失敗時回滾。

---

## Stage 117 — 賭盤倒數與 GQL fallback snapshot 同步

Commits:

- `4e33a55373c0ac2d606fbb997144814dad624ae6`
- `dd3875435ec5f2e1f6e2fc254ce58de62fe24ff2`

### 修改檔案

- `lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`
- `lib/features/twitch/api/engagement/twitch_prediction_api_service.dart`

### 修改內容

- `TwitchPredictionBetSheet` 新增倒數顯示。
- sheet 內部每秒刷新倒數，不影響其他頁面。
- `TwitchPredictionApiService.fetchPredictionContext(...)` 在成功解析 GQL snapshot 後，會呼叫 `TwitchPredictionHermesRealtimeBus.publishPrediction(snapshot)`。
- 因為 WatchPage 的 `_refreshEngagement()` 本來就會呼叫 `fetchPredictionContext(...)`，下注後 GQL snapshot 會自動回灌到下注 sheet。

---

## Stage 118 — 賭盤 sheet 開啟即 GQL fallback，並以 StreamNook 方式推算倒數

Commits:

- `7609e937ba9732b9ffdf839f3ca74f4021a72379`
- `d739dd4f55be78eea743e10b80902f9ba1c3c184`

### 背景

StreamNook 參考流程是「進聊天室先查 active prediction snapshot，再監聽 prediction-created / updated / locked / ended」，而 prediction event payload 概念包含 `prediction_window_seconds` 與 `created_at`。因此倒數不應只依賴 `locksAt`；若 Twitch GQL / Hermes 沒直接提供 `locksAt`，可以用 `createdAt + prediction_window_seconds` 推算鎖盤時間。

### 修改檔案

- `lib/features/twitch/api/engagement/twitch_prediction_api_service.dart`
- `lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`

### 修改內容

- `TwitchPredictionApiService` 新增 static fallback loader：
  - 每次 `fetchPredictionContext(channelLogin)` 成功前會註冊最後一次可用 loader。
  - 新增 `refreshLastPredictionContext()` 供 sheet 開啟時呼叫。
- `TwitchPredictionBetSheet.initState()` 現在會立即呼叫 GQL fallback，不再等下注後才 refresh。
- 倒數時間改用 `_effectiveLocksAt(...)`：
  - 優先使用 `prediction.locksAt`。
  - 若沒有 `locksAt`，讀 `createdAt / created_at / startedAt / started_at`。
  - 再讀 `predictionWindowSeconds / prediction_window_seconds / durationSeconds / windowSeconds` 等欄位。
  - 成功時以 `createdAt + windowSeconds` 推算鎖盤時間。
- 倒數 timer 也改成檢查 `_effectiveLocksAt(...)`，避免 active 但沒有 `locksAt` 時不刷新。

### 預期效果

- 每次打開賭盤 sheet 都會主動用 GQL snapshot 校正 viewerPoints / viewerOutcome。
- 若 Twitch 只提供 `created_at + prediction_window_seconds`，仍能顯示 `鎖盤剩 mm:ss`。
- Hermes realtime、GQL snapshot、local optimistic state 會透過同一個 bus 合併，不互相覆蓋。

---

## Stage 119 — StreamNook-style Prediction Hermes event stream

Commits:

- `ded3adbe60570b83b1fbe6723fa95cadb61216bd`
- `d9e4ace16fb15a9afcb599d34d7bf5252d811673`

### 背景

StreamNook 的 prediction 流程不是高頻 GQL polling，而是：

1. 先用 GQL 取得 active prediction snapshot。
2. 再用 Hermes / event listener 接收 prediction-created、updated、locked、ended 等事件。
3. 下注後用 GQL fallback 校正 viewer outcome / viewer points。

本專案原本已有 `TwitchPredictionHermesRuntimeService`，也已實作 `predictions-channel-v1.<channelId>` topic，但 WatchPage 主流程沒有正式啟動這條 event stream，因此賭盤更新仍主要仰賴 GQL fallback。

### 修改檔案

- `lib/features/twitch/services/engagement/twitch_prediction_hermes_runtime_service.dart`
- `lib/features/twitch/api/engagement/twitch_prediction_api_service.dart`

### 修改內容

- 新增 `TwitchPredictionHermesGlobalRuntime`：
  - 內部持有 app-level `TwitchPredictionHermesRuntimeService`。
  - `ensureConnected(channelId, viewerUserId, previousPrediction)` 會連線 Hermes。
  - 重複同一 channel / viewer 且已連線時不重連。
  - 透過 `TwitchPredictionHermesRealtimeBus` 發布最新 prediction。
- `TwitchPredictionApiService.fetchPredictionContext(...)` 在 GQL snapshot 成功後：
  - 先 publish snapshot 到 realtime bus。
  - 從 raw prediction / raw GQL response 遞迴解析 channelId。
  - 若取得 channelId，呼叫 `TwitchPredictionHermesGlobalRuntime.ensureConnected(...)`。
- Hermes topic 仍沿用既有：
  - `predictions-channel-v1.<channelId>`
  - `community-points-user-v1.<viewerId>`，目前 viewer id 尚未由此 path 傳入，後續可補。

### 預期效果

- 只要 WatchPage 原本的 `_refreshEngagement()` 成功取得 active prediction，Hermes prediction event stream 就會自動啟動。
- 賭盤 sheet 可透過 `TwitchPredictionHermesRealtimeBus` 收到 event-updated / prediction-made 類更新。
- 不需要高頻 GQL polling 就能更接近官方 / StreamNook 的即時更新模型。

### 後續候選

- Stage 120：將 viewerUserId 傳入 `ensureConnected(...)`，讓 `prediction-made` 更準確判斷自己的下注。
- Stage 121：讓聊天室 banner 也直接訂閱 realtime bus，而不只依靠 WatchPage `_prediction` prop。
- Stage 122：加入 Hermes status debug UI / log，方便確認 topic subscribe 是否成功。
