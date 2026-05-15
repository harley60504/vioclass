# Stage 93 — 修正 Watch Player 上方標題列 1px bottom overflow

## 問題

上方標題列放大後，在 compact 寬度下仍可能出現：

```text
RenderFlex overflowed by 1 px on the bottom
```

主要原因是 compact 標題卡高度太剛好：第一行 metadata pill 高度約 24px，第二行直播標題文字加上間距後，實際需要的垂直空間略高於原本配置。

## 修改內容

### `twitch_watch_player_area.dart`

- PATCH VERSION 更新為：`watch_player_area_top_bar_no_bottom_overflow_v56`
- 上方 action bar slot 高度調整：
  - tiny：`56 → 58`
  - compact：`60 → 66`
  - normal：`74 → 76`
- `_WatchStreamHeaderCard` 高度調整：
  - compact：`52 → 58`
  - normal：`68 → 70`
- compact 標題卡垂直 padding 微調：
  - `7 → 6`

## 保留項目

- 保留上方列自動縮放 `FittedBox.scaleDown`。
- 保留上方列較大的視覺尺寸。
- 保留底部控制列無音量彈窗設計。
- 未改動 Twitch 播放、畫質、聊天室、下注、忠誠點數等邏輯。

## 預期效果

- compact 上方標題列不再因 1px 高度不足產生 bottom overflow。
- 中小寬度下標題卡仍可顯示實況主、觀看人數、分類、語言與直播標題。
- 極窄寬度下仍走精簡頭像列，避免水平 overflow。
