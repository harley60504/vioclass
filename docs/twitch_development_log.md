# Twitch Flutter App 開發紀錄

## Stage 107 — Android / iOS 首播安全畫質策略

Commit: `c36d4ab455a508da5b74ee09ecd84bf5ec22ab22`

### 背景

Android 平板第一次進入播放頁時容易出現明顯卡頓。根據 PiliPlus 的架構觀察，問題不應直接歸因於 proxy；PiliPlus 本身也使用 media_kit，但透過播放器重用、圖片快取、Sliver list/grid、彈幕 canvas 化與狀態更新節流來維持流暢。

目前 GitHub 版 `TwitchWatchPage` 已經在 `initState` 建立一次 `Player` 與 `VideoController`，播放與切畫質時主要呼叫 `_player.open(...)`，因此這次沒有大改播放頁生命週期。

### 修改檔案

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

### 修改內容

- 保留 Dart HLS low-latency proxy，不移除 proxy 路線。
- 新增 mobile startup safe quality 選擇策略。
- Android / iOS 首播時不再優先選 `Source` / `chunked`。
- Android / iOS 首播優先選擇：
  - video variant
  - 非 audio-only
  - 優先 clean / no-ad source
  - 優先 720p 以內
  - fps 最高不超過 60fps
- Windows / macOS / Linux 維持原本偏高畫質策略。

### 備註

後續重新判斷後，首播畫質不是主要根因。Stage 107 可保留作為降低首幀壓力的保守策略，但主要優化方向應轉向：

- 播放器與 proxy 的生命週期。
- 首頁圖片請求尺寸、解碼尺寸與快取策略。
- 避免圖片解碼與播放器首幀初始化同時造成尖峰負載。

---

## Stage 108 — Discovery 首頁直播縮圖解碼降載

Commit: `21c9c8c921caa666e0677c6e10ed0bde2bb1a7f5`

### 背景

PiliPlus 首頁順暢的關鍵之一是列表與圖片層控制得比較細：Sliver builder 只建立可視項目，圖片層會控制實際解碼尺寸與 filter quality。Twitch App 的 Discovery 直播卡片雖然已使用 SliverGrid builder，但直播縮圖固定請求 `520x292`，且 `Image.network` 沒有指定 `cacheWidth/cacheHeight`，頭像也沒有解碼尺寸限制。

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

### 背景

Stage 108 先在直播卡片內局部降低圖片解碼成本，但優化邏輯仍散在單一 widget 中。PiliPlus 的做法更接近共用 `NetworkImgLayer`，讓 avatar、thumbnail、emote、背景圖、分類封面都使用一致的圖片解碼與 fallback 策略。

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

### 背景

PiliPlus 直播聊天室貼圖不是直接散落使用 `Image.network`，而是透過共用圖片層控制快取、解碼尺寸、filter quality 與 fallback。Twitch App 目前聊天室訊息列表已具備「使用者不在最新位置時不強制刷新」的設計，接下來的主要差距在圖片層。

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

### 背景

Stage 109/110 已經把多數高頻圖片導向 `TwitchCachedImageLayer`，但底層仍是 Flutter 內建 `Image.network`。PiliPlus 的 `NetworkImgLayer` 使用 `CachedNetworkImage`，能提供更穩定的記憶體與磁碟快取行為。

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

### 背景

使用者確認忠誠點數 icon 沒有壞掉，要求把重點改回 WatchPage 載入方式與 player 不要一直重建，並把保存畫質設定恢復。根據目前 GitHub 版，`TwitchWatchPage` 內部已經是頁面內單一 `_player.open(...)`，但每次進入 WatchPage 仍會建立新的 `Player` / `VideoController`。這一階段先完成兩個低風險前置工作：畫質記憶恢復與 shared player host 建立。

### 新增檔案

- `lib/features/twitch/services/playback/twitch_media_kit_player_host.dart`

### 修改檔案

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

### 修改內容

- 新增 `TwitchMediaKitPlayerHost`：
  - 提供 `acquire()` 取得共用 `Player` / `VideoController`。
  - 使用 ref-count。
  - 最後一個頁面離開後不立即 dispose，而是保留 24 秒 warm grace period。
  - 下一次 WatchPage 若在 grace period 內進入，可重用同一組 player，避免 media_kit / libmpv / texture 冷啟動。
- 恢復畫質記憶：
  - 新增 `twitch_watch_v2_preferred_quality`。
  - 新增頻道專屬 key `twitch_watch_v2_preferred_quality_<channel>`。
  - 兼容舊 key `twitch_fvp_proxy_preferred_quality` 與 `twitch_fvp_proxy_preferred_quality_<channel>`。
- `loadLivePlaylist(...)` 現在會：
  - 優先使用外部傳入 `preferredVariantName`。
  - 若沒有傳入，讀取保存的畫質偏好。
  - 如果有保存畫質，就不套用 mobile safe 720p 預設，直接尊重使用者選擇。
  - 如果沒有保存畫質，Android/iOS 才使用 safe startup quality。
- `startProxyForVariant(...)` 現在會保存手動切換後的畫質。

### 尚未完成

- `TwitchWatchPage` 尚未正式接入 `TwitchMediaKitPlayerHost`。目前新增 host 是可編譯的基礎設施，但主檔仍需要下一個 commit 改：
  - import `twitch_media_kit_player_host.dart`
  - 將 `late final Player _player;` / `late final VideoController _videoController;` 改成由 `TwitchMediaKitPlayerSession` 提供。
  - dispose 時改成 `session.release()`，不要直接 `_player.dispose()`。

### 測試建議

1. 先跑 `flutter pub get` 與編譯，確認 shared host 與 runtime compile pass。
2. 手動切畫質後離開直播再進入同一頻道，確認會記得畫質。
3. Android/iOS 沒有保存畫質時，仍會使用安全首播畫質。
4. 有保存 Source / 1080p 畫質時，下次會尊重保存值。
