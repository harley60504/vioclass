# v36 Watch Player Proxy Copy Fix

- 修正 `TwitchWatchPlayerArea` constructor 與目前 `twitch_watch_page.dart` 的參數不一致問題。
- Debug 選單只保留兩個項目：
  - 複製 Dart Proxy URL
  - 複製 mpv Proxy 指令
- `TwitchPlaylistPlayerRuntime` 會在載入/切換畫質時啟動 `TwitchDartHlsLowLatencyProxy`，並將播放器實際使用的 URL 設成本機 proxy URL。
- `playerRuntime.proxyUrl` 會對應目前 Dart proxy endpoint，可用來測試外部 mpv 延遲。
