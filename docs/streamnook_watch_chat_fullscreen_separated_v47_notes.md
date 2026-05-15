# StreamNook Watch Controls v47

## 變更重點

- 全螢幕與聊天室顯示改成兩條獨立邏輯。
- 不再使用「劇院模式」命名。
- 控制列按鈕改為「聊天室」圖示：
  - 聊天室顯示：`Icons.chat_bubble`
  - 聊天室隱藏：`Icons.chat_bubble_outline`
- `fullscreenMode` 只負責全螢幕，不再強制隱藏聊天室。
- `chatVisible` 只負責聊天室欄位顯示，不影響全螢幕狀態。
- Android / iOS 進入 Watch Page 時預設進入 immersive fullscreen，並且不顯示全螢幕按鈕。
- Desktop 保留全螢幕按鈕。
- Debug 維持二級選單，且 Android / iOS 不顯示 Debug。

## 桌面全螢幕

`twitch_fullscreen_controller.dart` 不直接 import `package:window_manager/window_manager.dart`，避免 Android/iOS build 被 desktop plugin 污染。

如果專案有安裝並註冊 `window_manager`，Desktop 會嘗試透過 `MethodChannel('window_manager')` 呼叫 `setFullScreen`。
如果沒有安裝，會 fallback 到 Flutter SystemChrome，這不一定能做到真正 OS-level desktop fullscreen。

## 覆蓋檔案

- `lib/features/twitch/presentation/pages/twitch_watch_page.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`
- `lib/features/twitch/services/window/twitch_fullscreen_controller.dart`
