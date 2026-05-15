# StreamNook Watch Player v42

## 目的

這版先處理三個觀察到的問題：

1. 第一次進入 Watch Page 時，避免聊天室/互動資料在播放器初始解碼前搶資源。
2. 控制列音量重新接回 `TwitchWatchPage` 的 `_volume` / `_isMuted` 狀態與 SharedPreferences 儲存。
3. 外部 mpv 測試指令壓掉 ffmpeg H264 PPS 起始警告，避免 debug log 被洗版。

## 改動

- `twitch_watch_page.dart`
  - media_kit 維持預設 buffer。
  - App 內與外部 mpv 仍然使用同一條 raw proxy route：`/stream.ts`。
  - `_loadPlayer()` 在 `player.open()` 後等待播放初始 guard：先等 width 或 playing，最長約 850 ms。
  - 聊天室、追隨狀態、Channel Points、賭盤、置頂留言仍背景載入，但會在播放器初始階段後才啟動。
  - 新增 `_setPlayerVolume()`、`_togglePlayerMute()`，並把 callback 傳給 `TwitchWatchPlayerArea`。

- `twitch_watch_player_area.dart`
  - mpv 複製指令加入：`--msg-level=ffmpeg/video=fatal`。
  - 保留兩個 debug 功能：
    - 複製 Dart Proxy URL
    - 複製 mpv Proxy 指令

## 版本字串

```text
PATCH VERSION: watch_page_player_first_volume_fix_v42
PATCH VERSION: watch_player_area_volume_mpv_clean_log_v42
```
