# Stage 140 - Watch Player Full Split

## 目標

將原本過大的 `twitch_watch_player_area.dart` 完整拆成多個小檔案，降低後續修改 LIVE、音量、畫質、上方資訊列、Debug menu 時的風險。

## 修改檔案

### 主入口

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

### 新增 part files

- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_controls_overlay.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_top_action_bar.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_stream_header.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_top_buttons.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_watch_bottom_control_bar.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_live_playback_strip.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_volume_control.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_more_actions_button.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_quality_button.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_common_buttons.dart`
- `lib/features/twitch/presentation/widgets/watch/player/twitch_player_error_card.dart`

## 架構說明

這次採用 Dart `part` / `part of` 拆法，原因是原本檔案裡很多 widget 都是 private class，例如 `_WatchBottomControlBar`、`_QualityButton`、`_PlainIconButton`。使用 `part` 可以保留 private class 名稱，不需要一次重新命名大量 class，也能避免影響現有呼叫端。

## LIVE / Seek 狀態

- 保留 Stage 139 的 `TwitchLivePlaybackStrip`。
- LIVE 按鈕與進度條行為集中到：
  `player/twitch_live_playback_strip.dart`
- 之後要修 LIVE 被拉回、seek target、live edge 判定，只改這個小檔案。

## 後續修改建議

- 修 LIVE：只動 `twitch_live_playback_strip.dart`
- 修音量：只動 `twitch_player_volume_control.dart` 或 `twitch_watch_bottom_control_bar.dart`
- 修畫質 menu：只動 `twitch_player_quality_button.dart`
- 修 Debug menu：只動 `twitch_player_more_actions_button.dart`
- 修上方資訊：只動 `twitch_watch_stream_header.dart`

## 測試建議

```powershell
flutter analyze
flutter run
```

測試項目：

1. 播放器能正常顯示。
2. 上方資訊列、Follow、Subscribe、刷新、停止正常。
3. 下方播放、音量、畫質、聊天室、全螢幕、More menu 正常。
4. LIVE 按鈕與進度條仍正常顯示。
5. 沒有 private class 找不到或 import 錯誤。
