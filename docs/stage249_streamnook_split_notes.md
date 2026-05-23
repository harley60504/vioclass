# Stage 249F - StreamNook Drops Split Patch

## 目的

把 Twitch 主頁與 Stage249 Drops 測試入口拆開，避免之後每次都需要整份更新 `twitch_stream_page.dart`。

## 拆分後檔案

```text
lib/features/twitch/presentation/pages/twitch_stream_page.dart
lib/features/twitch/presentation/pages/twitch_stream_home_models_stage249.dart
lib/features/twitch/presentation/widgets/home/twitch_stream_home_sidebar_stage249.dart
lib/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar_stage249.dart
lib/features/twitch/presentation/widgets/home/twitch_stream_home_account_menu_stage249.dart
lib/features/twitch/presentation/pages/twitch_streamnook_drops_connection_page_stage249.dart
lib/features/twitch/api/drops/twitch_drops_query_presets_stage249.dart
lib/features/twitch/services/drops/twitch_streamnook_drops_connection_check_stage249.dart
lib/features/twitch/services/drops/twitch_streamnook_drops_connection_service_stage249.dart
```

## 測試流程

```bash
flutter analyze
flutter run -d windows
```

進 App 後：

```text
設定齒輪 → StreamNook Drops 連線測試 → 開始測試
```

目前只測最小連線：

```text
validate Drops token
→ Inventory
→ ViewerDropsDashboard
```

不做自動 claim、不做 monitor、不做 Raw GQL editor。
