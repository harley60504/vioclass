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

### 測試建議

1. Android 平板冷啟動 App 後第一次進直播。
2. 觀察預設畫質是否不再是 Source / chunked。
3. 確認播放穩定後仍可手動切回 Source。
4. 對比修改前後第一次進播放頁的卡頓時間。
5. 如果仍卡，下一階段再測 media_kit `PlayerConfiguration` / `VideoControllerConfiguration` 與聊天室延後啟動。

---

## Stage 108 — Discovery 首頁直播縮圖解碼降載

Commit: `21c9c8c921caa666e0677c6e10ed0bde2bb1a7f5`

### 背景

PiliPlus 首頁順暢的關鍵之一是列表與圖片層控制得比較細：Sliver builder 只建立可視項目，圖片層會控制實際解碼尺寸與 filter quality。Twitch App 的 Discovery 直播卡片雖然已使用 SliverGrid builder，但直播縮圖固定請求 `520x292`，且 `Image.network` 沒有指定 `cacheWidth/cacheHeight`，頭像也沒有解碼尺寸限制。

這會造成首頁一次解碼多張偏大的直播縮圖，尤其在 Android 平板上，進播放頁前後容易和播放器首幀初始化競爭 CPU/GPU/記憶體頻寬。

### 修改檔案

- `lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart`

### 修改內容

- 將直播縮圖從固定 `520x292` 改為依卡片實際寬度與 device pixel ratio 動態計算。
- 縮圖實際請求寬度限制在 `320 ~ 480` physical px。
- 依 16:9 自動計算縮圖高度。
- `Image.network` 加上：
  - `cacheWidth`
  - `cacheHeight`
  - `filterQuality: FilterQuality.low`
  - `gaplessPlayback: true`
- 頭像圖片加上固定 `64x64` 解碼限制。
- 保留既有 UI 結構、卡片高度、Grid 版面與 RepaintBoundary。

### 預期效果

- 降低首頁直播卡片圖片解碼成本。
- 降低首頁滑動時 jank。
- 降低從首頁點進播放頁時，圖片解碼與 media_kit 首幀初始化同時競爭資源的機率。
- 在平板上應比單純調整預設畫質更接近 PiliPlus 的首頁優化方向。

### 測試建議

1. Android 平板冷啟動後進首頁，快速滑動 Discovery / Following。
2. 觀察縮圖是否仍清楚，是否有明顯糊掉。
3. 從首頁點進直播，觀察第一次播放器卡頓是否減少。
4. 對比修改前後 Android Studio Performance Overlay 或 Flutter DevTools 的 raster / UI frame spikes。

---

## Stage 109 — 建立共用 TwitchCachedImageLayer 並接入直播卡片

Commits:

- `a0396abf0b0905bbfc0e3932f4150ce76f5b1f96`
- `e6f98eb577ecd157adc343778fdca192a19f6137`

### 背景

Stage 108 先在直播卡片內局部降低圖片解碼成本，但優化邏輯仍散在單一 widget 中。PiliPlus 的做法更接近共用 `NetworkImgLayer`，讓 avatar、thumbnail、emote、背景圖、分類封面都使用一致的圖片解碼與 fallback 策略。

Twitch App 沒有 Bilibili 直播那種大量飛行彈幕，因此理論性能壓力更低；若圖片層與播放器生命週期逐步靠近 PiliPlus，Android 平板應能明顯更順。

### 新增檔案

- `lib/features/twitch/presentation/widgets/shared/twitch_cached_image_layer.dart`

### 修改檔案

- `lib/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart`

### 修改內容

- 新增 `TwitchCachedImageLayer`。
- 支援：
  - `cacheWidth`
  - `cacheHeight`
  - `filterQuality`
  - `gaplessPlayback`
  - `borderRadius`
  - circular avatar mode
  - fallback icon / color
- 新增工具方法：
  - `physicalWidthFor(...)`
  - `heightForAspectRatio(...)`
- 將直播卡片 thumbnail 改用 `TwitchCachedImageLayer`。
- 將直播主 avatar 改用 `TwitchCachedImageLayer.avatar(...)`。
- 保留 Stage 108 的 320~480 physical px 縮圖上限策略。

### 預期效果

- 後續圖片優化集中在共用層，不需要散落修改多個 widget。
- 更接近 PiliPlus `NetworkImgLayer` 的維護方式。
- 降低首頁大量圖片解碼造成的 raster thread 壓力。

### 下一階段候選

- Stage 110：把遊戲分類 sheet 的 box art 改用 `TwitchCachedImageLayer`。
- Stage 111：把聊天室 emote / badge / 頻道點數圖片逐步接到共用圖片層。
- Stage 112：做 `TwitchMediaKitPlayerHost`，讓 WatchPage 之間短時間重用同一組 `Player` / `VideoController`，避免每次從首頁進直播都冷啟動 media_kit。
- Stage 113：模仿 PiliPlus route-aware 行為，切到其他頁時暫停聊天室 heavy update，回到播放頁再恢復。
