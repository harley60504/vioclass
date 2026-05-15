# Stage 113 — 統一 Sheet 模板與保留最近貼圖

## 變更目標

將貼圖、忠誠點數、賭盤下注三種 sheet 的外框逐步統一，避免每個 sheet 自己寫一套 header / close / refresh UI。

## 主要變更

- 新增共用 `TwitchUnifiedSheetScaffold`。
- 新增共用 `TwitchUnifiedSheetHeader`。
- 貼圖 sheet 改用共用 sheet header。
- Twitch 官方貼圖 ID picker 也改用共用 sheet header。
- 忠誠點數 sheet 改用共用 sheet header。
- 賭盤下注 sheet 改用共用 sheet header。
- 保留「最近」貼圖分頁，不移除。
- 保留 Stage 112 的官方 / 第三方貼圖收藏持久化修正。

## 注意

「最近」分頁目前仍保留為入口；後續如果要做真正使用紀錄，可再加入最近使用 emote 的持久化佇列。
