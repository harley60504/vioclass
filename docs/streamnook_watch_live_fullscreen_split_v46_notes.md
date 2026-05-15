# v46 Watch Page 控制列 / LIVE / 全螢幕整理

## PATCH VERSION

- `watch_page_platform_true_fullscreen_v46`
- `watch_player_area_live_media_direct_modes_v46`
- `twitch_fullscreen_controller_platform_split_v46`

## 改動

1. LIVE 列接回 media_kit 狀態
   - 使用 `player.stream.position`
   - 使用 `player.stream.duration`
   - 使用 `player.stream.buffering`
   - 使用 `player.stream.playing`
   - tooltip 會顯示 media_kit 的播放狀態與 position/duration。

2. 劇場模式與全螢幕移出二級選單
   - 劇場模式是獨立按鈕。
   - 全螢幕是獨立按鈕。
   - More menu 只保留 Debug。

3. Debug 維持二級選單
   - 更多 → Debug → 複製 Dart Proxy URL
   - 更多 → Debug → 複製 mpv Proxy 指令
   - Android / iOS 不顯示 Debug / More menu。

4. 全螢幕邏輯分離
   - `TwitchFullscreenController` 負責平台分流。
   - Desktop: `window_manager.setFullScreen()` 真全螢幕。
   - Android / iOS: `SystemChrome.immersiveSticky`。

## pubspec.yaml

如果專案還沒有 `window_manager`，請加：

```yaml
dependencies:
  window_manager: ^0.5.1
```

然後執行：

```bash
flutter pub get
```
