# Stage 116 — Responsive Sheet nullable refresh fix

## 目的
修正 Stage 115 統一 Sheet 模板後，`flutter analyze` 在 `twitch_responsive_sheet.dart` 出現的 nullable callback 無法無條件呼叫錯誤。

## 修改檔案
- `lib/features/twitch/presentation/widgets/responsive/twitch_responsive_sheet.dart`

## 主要修正
- 在 `showTwitchUnifiedSheet` 內先將 nullable `onRefresh` 存成 local final `refreshHandler`，再包成同步 callback。
- 在 `TwitchUnifiedSheetScaffold.build()` 內同樣使用 local final `refreshHandler`，避免 Dart flow analysis 在 closure 內無法保證 nullable callback 非 null。
- `Future<void> Function()?` 的 refresh callback 改用 `unawaited(refreshHandler())` 包裝，符合 header 的 `VoidCallback?` 介面。

## 結果
- 修掉 `unchecked_use_of_nullable_value` build/analyze error。
- 其他 `withOpacity`、unused、style 類型項目仍屬 warning/info，不會阻擋 build。
