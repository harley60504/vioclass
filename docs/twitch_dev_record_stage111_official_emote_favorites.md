# Stage 111 - Twitch 官方貼圖收藏

## 修改內容

- 在 `TwitchOfficialEmoteCacheService` 補上官方貼圖收藏狀態。
- `貼圖` 面板的 `收藏` 分頁現在會同時顯示：
  - BTTV / 7TV / FFZ 第三方收藏貼圖
  - Twitch 官方收藏貼圖
- `Twitch` 官方貼圖分頁中的官方貼圖卡片補上星號收藏按鈕。
- 鎖住的官方頻道貼圖仍不能插入訊息，但可以先收藏，之後解鎖或訂閱後比較好找。
- `最近` 分頁改回顯示一般第三方貼圖預覽，不再把收藏拿來假裝最近。

## 修改檔案

```text
lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart
lib/features/twitch/services/chat/twitch_official_emote_cache_service.dart
```

## 備註

目前收藏仍沿用記憶體層級，與既有第三方貼圖收藏邏輯一致；之後若要跨重開 App 保留，需要再把官方與第三方收藏接到 SharedPreferences 或本地 cache。
