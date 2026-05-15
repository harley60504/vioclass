# Stage 112 - Emote Favorite Persistence Fix

## 變更重點

- 修正 `TwitchOfficialEmoteCacheService` 缺少 `_favoriteKey()` 導致 Windows build 失敗。
- Twitch 官方貼圖收藏改成可持久保存，重開 App 後仍保留。
- BTTV / 7TV / FFZ 第三方貼圖收藏也同步改成可持久保存。
- 收藏資料使用 `SharedPreferences` 儲存：
  - `twitch_official_favorite_emotes_v1`
  - `twitch_third_party_favorite_emotes_v1`
- 載入頻道貼圖後，收藏中的貼圖會用最新 API 資料刷新顯示資訊。

## 修改檔案

```text
lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart
lib/features/twitch/services/chat/twitch_official_emote_cache_service.dart
lib/features/twitch/services/chat/twitch_third_party_emote_cache_service.dart
```

## 注意

這版保留 Stage 111 的官方貼圖星號 UI，並修正 service / persistence。
