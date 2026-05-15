# Stage 117：Unified Sheet Size Presets

## 目標
將 Twitch Flutter App 的各種 sheet 從「每份自行填 maxWidth / heightFactor」改成統一尺寸 preset。

## 新增
在 `twitch_responsive_sheet.dart` 新增：

- `TwitchUnifiedSheetSize.compact`
- `TwitchUnifiedSheetSize.medium`
- `TwitchUnifiedSheetSize.large`
- `TwitchUnifiedSheetSize.wide`

每個 preset 統一管理：

- `maxWidth`
- `portraitHeightFactor`
- `landscapeHeightFactor`

## 尺寸規格

| Preset | maxWidth | portraitHeightFactor | landscapeHeightFactor | 用途 |
|---|---:|---:|---:|---|
| compact | 560 | 0.68 | 0.90 | 外觀設定、小型確認面板 |
| medium | 680 | 0.74 | 0.94 | 訊息上下文、下注 |
| large | 760 | 0.78 | 0.96 | 貼圖、忠誠點數 |
| wide | 840 | 0.80 | 0.98 | Debug / log 類面板 |

## 已套用

- `twitch_chat_appearance_sheet.dart` → compact
- `twitch_chat_message_context_sheet.dart` → medium
- `twitch_prediction_bet_sheet.dart` → medium
- `twitch_channel_points_sheet.dart` → large
- `twitch_emote_picker_sheet.dart` → large / compact confirmation
- `twitch_prediction_probe_sheet.dart` → wide

## 保留

- Stage 115 共用 sheet 入口
- Stage 116 nullable refresh 修正
- 貼圖最近 / 收藏 / 連發
- Prediction Probe debug 測試功能

## 設計原則

不是所有 sheet 強制同寬同高，而是統一使用少數固定尺寸規格。這樣可以避免 UI 不一致，同時保留不同內容需要的空間。
