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

### 背景

PiliPlus 使用 fork/新 API 風格的 media_kit 配置，其中 `PlayerConfiguration.options` 可設定 mpv options，例如 `video-sync`、`volume-max`、`ao`、`autosync`。目前本專案使用官方 `media_kit: ^1.2.6` 與 `media_kit_video: ^2.0.1`，官方 `PlayerConfiguration` 沒有 `options` 欄位，不能直接照抄，否則會編譯失敗。

官方 `media_kit_video` 支援 `VideoController(player, configuration: VideoControllerConfiguration(...))`，因此這一階段先對齊可安全使用的部分。

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
- realtime prediction 更新進來時：
  - 如果 incoming snapshot 明確帶 viewer choice，採用 incoming 並同步本地狀態。
  - 如果 incoming snapshot 沒有 viewer choice，但本地已有下注狀態，將本地 viewer outcome / points merge 回 incoming。
  - 全域總點數、比例、狀態仍會跟著 realtime 更新。
- submit 時先 optimistic 記錄本地 outcome / points，避免送出後下一個 snapshot 把 UI 重置。
- submit 失敗時回滾本地 points；若回到 0 則清除本地 outcome。

---

## Stage 117 — 賭盤倒數與 GQL fallback snapshot 同步

Commits:

- `4e33a55373c0ac2d606fbb997144814dad624ae6`
- `dd3875435ec5f2e1f6e2fc254ce58de62fe24ff2`

### 背景

賭盤 sheet 需要顯示鎖盤/結算時間；另外使用者下注後，即使 Hermes realtime snapshot 沒有立即帶 viewer prediction，本地 UI 也應能透過 GQL fallback 修正「我下了哪邊 / 下了多少」。WatchPage 下注後原本就會 `_refreshEngagement()`，因此可以讓 GQL snapshot 自動發布到同一個 realtime bus，而不是額外大改 WatchPage。

### 修改檔案

- `lib/features/twitch/presentation/sheets/twitch_prediction_bet_sheet.dart`
- `lib/features/twitch/api/engagement/twitch_prediction_api_service.dart`

### 修改內容

- `TwitchPredictionBetSheet` 新增倒數顯示：
  - ACTIVE / OPEN：顯示 `鎖盤剩 mm:ss`。
  - LOCKED / RESOLVE_PENDING：顯示 `結算剩 mm:ss` 或 `等待結算`。
  - 結束後：顯示結算時間。
- sheet 內部每秒刷新倒數，不影響其他頁面。
- 新增 GQL fallback hook：
  - sheet 下注後可觸發 fallback refresh。
  - fallback 失敗時保留 optimistic / local 狀態。
- `TwitchPredictionApiService.fetchPredictionContext(...)` 在成功解析 GQL snapshot 後，會呼叫 `TwitchPredictionHermesRealtimeBus.publishPrediction(snapshot)`。
- 因為 WatchPage 的 `_refreshEngagement()` 本來就會呼叫 `fetchPredictionContext(...)`，下注後 GQL snapshot 會自動回灌到下注 sheet。

### 預期效果

- 賭盤 sheet 可看到鎖盤或結算倒數。
- 下注後先 optimistic 顯示本地下注意圖。
- 後續 GQL fallback snapshot 會修正 viewer outcome / viewerPoints。
- Hermes 與 GQL 都可更新同一個 sheet，不會彼此覆蓋掉本地下注狀態。
