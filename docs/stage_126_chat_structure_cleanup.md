# Stage 126 — Chat services 路徑與聊天室特殊訊息 localization 整理

## 背景

本次整理針對 Twitch chat 架構中兩個位置不一致的問題：

1. `lib/features/twitch/chat/services/` 底下只剩 `twitch_prediction_probe_service.dart`，與目前主架構 `lib/features/twitch/services/chat/` 不一致。
2. 聊天室特殊訊息翻譯邏輯分散在 `services/chat` 與 `models/chat`，但這類文字轉換更適合集中在 localization 層。

## Commits

- `47ccff74d9c45a44eb40248d6f38432cb1fe1312`
- `3b76cf6d90ac5b20fae60c313b07f596b4cfed02`
- `e5652a35158e278dd44bb1608835ccb5651f6835`
- `016bf163d76e30b093416be921c9b2efdc05a796`
- `b51e3c904df6032508ca29b0f1af93b86d197971`
- `457691ea54ae06d0eb2c73e71f84c2a98b537f10`
- `ea2a65a78553e96202f11d4f39a4921e2bc3ad68`

## 新增檔案

- `lib/features/twitch/services/chat/twitch_prediction_probe_service.dart`
- `lib/features/twitch/localization/twitch_chat_event_localizer.dart`
- `lib/features/twitch/localization/twitch_chat_special_message_formatter.dart`
- `docs/stage_126_chat_structure_cleanup.md`

## 修改檔案

- `lib/features/twitch/presentation/sheets/twitch_prediction_probe_sheet.dart`
- `lib/features/twitch/services/chat/twitch_chat_event_localizer.dart`
- `lib/features/twitch/models/chat/twitch_chat_special_message_formatter.dart`

## 刪除檔案

- `lib/features/twitch/chat/services/twitch_prediction_probe_service.dart`

## 修改內容

### 1. 修正 `chat/services` 錯位殘留

- 將 `twitch_prediction_probe_service.dart` 從：

```text
lib/features/twitch/chat/services/twitch_prediction_probe_service.dart
```

搬到：

```text
lib/features/twitch/services/chat/twitch_prediction_probe_service.dart
```

- 更新 `twitch_prediction_probe_sheet.dart` 的 import：

```dart
import '../../services/chat/twitch_prediction_probe_service.dart';
```

- 刪除舊的 `lib/features/twitch/chat/services/twitch_prediction_probe_service.dart`。

### 2. 建立 Twitch localization 層

新增：

```text
lib/features/twitch/localization/twitch_chat_event_localizer.dart
lib/features/twitch/localization/twitch_chat_special_message_formatter.dart
```

用途：

- 集中放聊天室特殊訊息中文化。
- 避免 model / service 層直接塞大量 UI-facing 文字。
- 讓未來若要支援多語系，可以更容易把 chat notice / USERNOTICE / reward 類文字統一整理。

### 3. 保留相容 export

為了避免大量 import 一次炸掉，舊路徑先保留 re-export：

```dart
export '../../localization/twitch_chat_event_localizer.dart';
```

```dart
export '../../localization/twitch_chat_special_message_formatter.dart';
```

因此目前既有 import 還能編譯，但新的實作位置已經集中到 localization。

## 整理後建議架構

```text
lib/features/twitch/
├─ api/
│  └─ chat/
├─ localization/
│  ├─ twitch_chat_event_localizer.dart
│  └─ twitch_chat_special_message_formatter.dart
├─ models/
│  └─ chat/
├─ parsers/
│  └─ chat/
├─ services/
│  └─ chat/
└─ presentation/
   ├─ sheets/
   └─ widgets/
      └─ chat/
```

## 後續候選

- 把舊 import 逐步改成直接 import `lib/features/twitch/localization/...`。
- 將 `presentation/localization/twitch_reward_localizer.dart` 也移到 `lib/features/twitch/localization/`，讓 reward 與 chat special message 的 localization 位置一致。
- 等所有 import 都改完後，可以移除 compatibility export 檔案。
