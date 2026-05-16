# Stage 139 - Split Live Playback Strip

## 修改檔案

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_live_playback_strip.dart`

## 修改內容

1. 將直播進度條、時間顯示與 LIVE 按鈕拆成獨立檔案 `twitch_live_playback_strip.dart`。
2. `twitch_watch_player_area.dart` 改為匯入 `TwitchLivePlaybackStrip`，後續修改 LIVE / seek 行為不用再覆蓋整份大型播放器檔。
3. 修正 LIVE 按鈕跳到最右邊後又被視覺上拉回的問題：
   - 新增 `_livePinned` 狀態。
   - 只要播放器仍接近 live edge，UI 會固定顯示在最右側。
   - 使用者主動往左拖曳時才解除 live pinned。
4. LIVE 按鈕與進度條拖到右端都使用 `duration - 350ms` 作為 seek 目標，避免直接 seek 到 HLS 最尾端被播放器忽略。
5. LIVE 按鈕按下後會呼叫 `player.play()`，避免暫停狀態下跳轉後不播放。

## 測試建議

1. 播放 Twitch 直播。
2. 將進度條往左拖離直播最新位置，確認 LIVE 按鈕不亮。
3. 點擊 LIVE 按鈕，確認進度條會回到右側且不再馬上被拉回。
4. 將進度條拖到最右邊放開，確認也會固定在 live edge。
5. 往左拖曳後確認會解除 live pinned，進度條可以停在回放位置。
