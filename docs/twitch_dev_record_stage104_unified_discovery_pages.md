# Stage 104 — Following / Browse 共用探索模板與膠囊搜尋列

## 目標

將 `TwitchFollowingPage` 與 `TwitchBrowsePage` 的直播列表 UI 統一成同一套模板，並依照目前畫面需求調整上方工具列：

- 「追隨中的直播」與「探索直播」使用同一種標題字級與排版。
- 搜尋列改成膠囊狀。
- 搜尋旁只保留一個刷新按鈕。
- 篩選移到搜尋列旁邊，以 icon-only 按鈕呈現。
- 降低平板版卡頓：共用 Grid/Card，減少重複 UI，圖片使用較合理的 cacheWidth/cacheHeight。

---

## 新增檔案

### `twitch_discovery_stream_template_stage104.dart`

建議放置位置：

```text
lib/features/twitch/presentation/widgets/discovery/twitch_discovery_stream_template.dart
```

內容包含共用元件：

- `TwitchDiscoveryStreamGrid`
- `TwitchDiscoverySectionHeader`
- `TwitchDiscoveryStreamCard`
- `TwitchDiscoveryStateView`
- `TwitchDiscoveryPaginationFooter`

## 修改檔案

### `twitch_following_page_stage104_unified_template.dart`

建議覆蓋：

```text
lib/features/twitch/presentation/pages/twitch_following_page.dart
```

變更：

- 使用 `TwitchDiscoveryStreamGrid` 顯示追隨直播。
- 標題統一為 `追隨中的直播 · N`。
- 保留原本資料來源：`/streams/followed`。
- 保留語言篩選 dialog。
- 新增 `refresh()` 相容外部 `GlobalKey` 呼叫。

### `twitch_browse_page_stage104_unified_template.dart`

建議覆蓋：

```text
lib/features/twitch/presentation/pages/twitch_browse_page.dart
```

變更：

- 使用 `TwitchDiscoveryStreamGrid` 顯示探索直播。
- 標題統一為 `探索直播 · N`。
- 保留原本資料來源：`/streams`、`/games/top`。
- 保留遊戲分類與語言篩選 dialog。
- 新增 `refresh()` 相容外部 `GlobalKey` 呼叫。

### `twitch_stream_page_stage104_capsule_toolbar.dart`

建議覆蓋：

```text
lib/features/twitch/presentation/pages/twitch_stream_page.dart
```

變更：

- 搜尋列改為膠囊狀。
- 搜尋提示改為：`搜尋頻道、標題、遊戲...`
- 篩選按鈕移到搜尋列右側。
- Browse 頁顯示：遊戲分類、篩選、刷新。
- Following 頁顯示：篩選、刷新。
- 刷新與篩選都改成 icon-only，不再顯示文字。
- 保留設定齒輪選單。

---

## 平板效能優化內容

### 1. 共用 Grid/Card 模板

原本 Following 與 Browse 各自有一份相似的 Grid / Card / Thumbnail / Avatar UI。Stage 104 改為共用模板，避免後續兩邊分別維護，也減少重複 widget 結構。

### 2. `CustomScrollView + SliverGrid`

共用模板改用 `CustomScrollView` + `SliverGrid` + `SliverToBoxAdapter`，讓 section header、grid、footer 在同一個 scroll tree 裡，避免額外巢狀 layout。

### 3. 圖片 cache 尺寸依欄位數調整

依照 grid 欄位數決定 thumbnail cache size：

```text
1 欄：640px
2 欄：520px
3 欄：440px
4～5 欄：360px
```

避免平板或高欄位 layout 還下載過大的縮圖，降低記憶體與解碼壓力。

### 4. 卡片加上 `RepaintBoundary`

直播卡片包一層 `RepaintBoundary`，減少 scroll 時重繪影響範圍。

---

## 覆蓋順序

```text
1. 建立新資料夾：
   lib/features/twitch/presentation/widgets/discovery/

2. 放入：
   twitch_discovery_stream_template.dart

3. 覆蓋：
   lib/features/twitch/presentation/pages/twitch_following_page.dart
   lib/features/twitch/presentation/pages/twitch_browse_page.dart
   lib/features/twitch/presentation/pages/twitch_stream_page.dart

4. 執行：
   flutter pub get
   flutter analyze
```

---

## 注意事項

我這邊沒有 Flutter SDK，尚未實跑 `flutter analyze`。若出現 import path 或 widget 參數錯誤，下一版可直接修正。
