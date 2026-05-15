# Stage v71：忠誠點數 overflow 修正、聊天輸入列外框、Prediction 簡化、自動隱藏重開

更新時間：2026-05-15 05:09:53

## 本次修正重點

### 1. 忠誠點數按鈕短數字不再四捨五入
- 修正 `formatChannelPointCompactNumber()`。
- 由原本可能把 `9,990` 顯示成 `10k`，改為截斷顯示：
  - `9,990 -> 9.9k`
  - `23,000 -> 2.3w`
  - `120,000 -> 12w`
- 只影響聊天室工具列那顆粉紅忠誠點數按鈕的短數字。
- sheet 內部仍顯示完整數字，例如 `9,990`、`15,000`。

### 2. 聊天室輸入框與 Send 按鈕高度統一、加清楚外框
- 直接把輸入列高度抽成共用常數：
  - `_kTwitchChatInputControlHeight = 40`
  - `_kTwitchChatInputCompactControlHeight = 34`
- 輸入框改成明確 outline border。
- TextField 加入 `textAlignVertical: TextAlignVertical.center`。
- Send 按鈕使用相同 `controlHeight`，字與 icon 置中。
- 輸入框與按鈕上下高度完全由同一個常數控制。

### 3. 忠誠點數 Reward 卡片 overflow 修正
- 進一步調整 reward card 內容密度：
  - 圖片略縮到 78x78
  - 上下 padding 再縮小
  - status badge 再壓縮
- Grid `childAspectRatio` 再調小，使卡片更高：
  - 窄畫面：`0.74`
  - 一般畫面：`0.86`
- 目的：避免出現 `BOTTOM OVERFLOWED BY ... PIXELS`。

### 4. Prediction 簡化顯示
- 下注 outcome 卡片只保留：
  - 點數
  - 人數
  - 倍率
- 移除 outcome 區過多次要資訊，整體更乾淨。
- 保留標題與簡單 winner 標示，方便辨識。

### 5. Prediction 自動隱藏後，手動再打開也能再次觸發
- 新增 `_schedulePredictionAutoHide()`。
- 當 prediction 是已結束狀態時：
  - 初次顯示會自動隱藏
  - 使用者手動重新打開後，也會再次啟動自動隱藏計時
- 若使用者手動關閉，則會取消目前 timer。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_utils.dart`
- `lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_engagement_strip.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
