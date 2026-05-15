# Stage 105 — 修正 lib.zip 實際專案路徑與 Discovery 共用模板

## 目標

修正 Stage 104 直接套用時產生的 import / include 路徑錯誤，並依照目前 `lib.zip` 的實際架構重新整理 Following Page 與 Browse Page。

## 主要修正

- 移除錯誤路徑：
  - `../../data/models/twitch_stream_model.dart`
  - `../../auth/state/twitch_auth_instance.dart`
  - `../twitch_theme.dart`
- 改用目前專案實際存在的模型與服務：
  - `features/twitch/models/discovery/twitch_live_stream.dart`
  - `features/twitch/models/discovery/twitch_stream_header_metadata.dart`
  - `features/twitch/services/discovery/twitch_discovery_service.dart`
  - `features/twitch/services/auth/twitch_auth_service.dart`
  - `features/twitch/services/auth/twitch_drops_auth_service.dart`
  - `features/twitch/services/auth/twitch_web_gql_auth_service.dart`
- Following / Browse 共用：
  - `TwitchDiscoveryStreamGrid`
  - `TwitchDiscoverySectionHeader`
  - `TwitchDiscoveryFooter`
  - `TwitchDiscoveryEmptyState`
- 保留使用者要求：
  - 「追隨中的直播」與「探索直播」同一套字體大小。
  - 搜尋列膠囊狀。
  - 搜尋旁邊放刷新 icon。
  - Browse 搜尋旁邊放遊戲分類 icon 與語言篩選 icon。
  - Following 搜尋旁邊放語言篩選 icon。
  - 按鈕只顯示 icon，不顯示文字。
- 平板效能優化：
  - Discovery grid 使用 `SliverGridDelegateWithMaxCrossAxisExtent`。
  - 單張卡片包 `RepaintBoundary`。
  - 滾動載入更多保留閾值，避免每次 scroll 都 setState。
  - 共用現有 `TwitchStreamCard` 與 `twitchStreamCardGridMainAxisExtent()`。

## 覆蓋檔案

```text
lib/features/twitch/presentation/pages/twitch_stream_page.dart
lib/features/twitch/presentation/pages/twitch_following_page.dart
lib/features/twitch/presentation/pages/twitch_browse_page.dart
lib/features/twitch/presentation/widgets/discovery/twitch_discovery_stream_template.dart
```

## 注意

本環境沒有 Flutter / Dart SDK，因此未執行 `flutter analyze`。已用腳本檢查這四個檔案的相對 import 目標都存在於使用者上傳的 `lib.zip` 專案結構中。
