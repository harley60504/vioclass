# Stage 137 - Player LIVE Button 與 Seek 拖曳優化

## 修改檔案

- `lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart`

## 修改內容

1. 將 `_LivePlaybackStrip` 從 `StatelessWidget` 改為 `StatefulWidget`。
2. 進度條拖曳時只更新 UI，不再連續呼叫 `player.seek()`。
3. 使用者放開進度條後才執行一次 `player.seek()`，降低 HLS seek 卡頓。
4. 移除原本時間文字自動變成 `LIVE` 的邏輯。
5. 時間區固定顯示 `目前時間 / 總長度`。
6. 在進度條與時間文字中間新增 `LIVE` 按鈕。
7. `LIVE` 按鈕狀態：
   - 在直播最新位置時亮紅色。
   - 不在最新位置時不亮，但仍可點擊。
   - 點擊後會 `seek(duration)`，跳到目前可用的最後時間。

## 測試建議

1. 播放 Twitch 直播。
2. 拖曳進度條，確認拖曳中不再明顯卡頓。
3. 放開進度條後確認只 seek 一次。
4. 往回拖離 live edge 後，確認 `LIVE` 按鈕不亮。
5. 點擊 `LIVE` 按鈕後，確認會跳回直播最新位置。
6. 確認時間文字不再變成 `LIVE`，而是固定顯示時間。
