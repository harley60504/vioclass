# Stage 114 — Recent Emotes + Keep Emote Sheet Open

## 目標

補完貼圖面板的「最近」分頁，並讓使用者可以連續點多個貼圖，不再每點一次就自動關閉 sheet。

## 修改內容

### 1. 貼圖可以連發

- `TwitchThirdPartyEmotePickerSheet` 新增 `onEmoteSelected` callback。
- 有 callback 時：點貼圖只把文字插入聊天室輸入框，不關閉 sheet。
- 沒 callback 時：保留舊行為，用 `Navigator.pop()` 回傳貼圖名稱。
- `twitch_watch_page.dart` 與 `twitch_windows_player_page.dart` 已改為使用 callback 插入貼圖，因此可以連點多個貼圖。

### 2. 最近貼圖持久化

- `TwitchThirdPartyEmoteCacheService` 新增最近貼圖紀錄。
- `TwitchOfficialEmoteCacheService` 新增最近官方貼圖紀錄。
- 最近紀錄使用 `SharedPreferences` 保留，重開 App 後仍存在。
- 最近紀錄最多保留 80 個。

### 3. 最近分頁正式接資料

- 「最近」分頁不再用目前貼圖列表前 48 個假資料。
- 會顯示實際點過的 Twitch 官方 / BTTV / 7TV / FFZ 貼圖。
- 點最近貼圖時也會再次更新最近排序。

## 保留內容

- Prediction Probe debug sheet 保留，之後做 Hermes realtime prediction 時仍可拿來測試事件與 log。
- 收藏分頁保留。
- Twitch 官方貼圖收藏持久化保留。
- 第三方貼圖收藏持久化保留。

## 下一階段建議

Stage 115 可以開始做 Prediction Hermes realtime update：

```text
GQL 作初始 snapshot / fallback
Hermes 作 prediction created / updated / locked / ended 即時更新
Prediction Probe debug sheet 用來驗證事件解析
```
