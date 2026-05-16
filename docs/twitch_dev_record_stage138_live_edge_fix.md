# Stage 138 - LIVE Button Seek Target 修正

## 修改檔案

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

## 修改內容

1. 修正 LIVE 按鈕按下後沒有反應的問題。
2. 原本 LIVE 按鈕使用 `player.seek(duration)`，HLS live stream 在 seek 到正好最後一格時可能會被 media_kit / mpv 忽略。
3. 新增 `_liveEdgeSeekTarget()`，將 live-edge 目標改成 `duration - 350ms`。
4. 新增 `_seekToLiveEdge()`：
   - UI 先顯示拖曳到最右邊。
   - seek 到 live-edge 目標。
   - 呼叫 `player.play()`，避免暫停狀態下跳轉後不播放。
5. 進度條拖到最右邊時，也改用相同的 live-edge 目標。

## 測試建議

1. 播放 Twitch 直播。
2. 把進度條往左拖離直播最新位置。
3. 確認 LIVE 按鈕變成未亮狀態。
4. 點擊 LIVE 按鈕，確認會跳回接近直播最新位置。
5. 將進度條拖到最右邊放開，確認也會回到 live edge。
