# Twitch Flutter App 開發紀錄 — Stage 95

## 目標
修正 Watch Player 上方標題列仍出現 `BOTTOM OVERFLOWED BY 1.00 PIXELS` 的問題，並依照需求將上方資訊卡與按鈕高度統一放大。

## 修改檔案
- `twitch_watch_player_area_stage95_equal_top_controls.dart`

## 主要變更
1. 上方列不再只調整外層 slot，而是讓資訊卡、返回鍵、追隨、訂閱、重新整理、關閉按鈕全部使用一致高度。
2. `_WatchTopActionBar` 新增：
   - compact slot：`62.0`
   - normal slot：`78.0`
   - compact control：`52.0`
   - normal control：`72.0`
3. `_WatchStreamHeaderCard` 新增 `height` 參數，由上層傳入 `controlHeight`。
4. `_RoundIconButton`、`_FollowButton`、`_SubscribeButton` 新增可選 `height` 參數。
5. `_WatchCompactAvatarTile` 新增 `height` 參數，頭像格與其他按鈕等高。
6. 移除上方列雙層 `FittedBox`，改成單層 `FittedBox + Center`，避免縮放四捨五入導致 1px overflow。
7. 保留 Stage 91 的底部控制列內嵌音量設計，不恢復音量彈窗。

## 注意事項
此檔案刻意使用新檔名，避免和舊版 `twitch_watch_player_area.dart` 混淆。實際放回專案時，請將內容覆蓋到：

```text
lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart
```

或確認無誤後再改名替換原檔。
