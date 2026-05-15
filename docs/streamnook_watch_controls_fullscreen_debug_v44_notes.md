# streamnook_watch_controls_fullscreen_debug_v44

## 修改內容

- `twitch_watch_player_area.dart`
  - 移除主控制列上的獨立 Debug 蟲蟲按鈕，避免功能重複。
  - 移除主控制列上的獨立劇場 / 全螢幕按鈕，統一收進「更多」選單。
  - Debug 改成二級選單：「更多」→「Debug」→「複製 Dart Proxy URL / 複製 mpv Proxy 指令」。
  - Android / iOS 不顯示 Debug 選單，避免手機端出現外部 mpv 測試功能。

- `twitch_watch_page.dart`
  - 桌面平台 Windows / macOS / Linux 改用 `window_manager.setFullScreen()`，是真正的桌面視窗全螢幕。
  - Android / iOS 繼續用 `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`。
  - dispose 時會依平台還原全螢幕狀態。

## 注意

如果專案還沒有 `window_manager`，需要在 `pubspec.yaml` 加入 dependency。
