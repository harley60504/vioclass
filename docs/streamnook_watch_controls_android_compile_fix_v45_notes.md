# PATCH VERSION: streamnook_watch_controls_android_compile_fix_v45

## 修正

- 移除 `twitch_watch_page.dart` 對 `package:window_manager/window_manager.dart` 的直接 import。
- Android / iOS build 不再因為沒有 `window_manager` dependency 而失敗。
- 保留 v44 的控制列整理、Debug 二級選單與 Android/iOS 不顯示 Debug 的行為。
- 全螢幕暫時回到 `SystemChrome.setEnabledSystemUIMode`，避免桌面套件污染手機 build。

## 後續

桌面真全螢幕建議下一版用平台 wrapper 處理，不要在共用 `watch_page.dart` 直接 import 桌面 plugin。
