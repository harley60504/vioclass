# Twitch Channel Points Sheet 架構說明（Stage 174）

本文件記錄 `twitch_channel_points_sheet.dart` 在 Stage 169～173 之後的拆分方式。目標是讓忠誠點數 sheet 不再把 UI、reward grid、redeem payload、emote overlay state 全部塞在同一個檔案。

---

## 1. 主入口

```text
lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart
```

目前主檔負責：

```text
1. showTwitchChannelPointsSheet() sheet 入口
2. TwitchChannelPointsSheet widget wiring
3. sheet scaffold 組裝
4. reward tap flow
5. emote overlay 開啟 / 重新載入 / 關閉 / 完成選擇
6. 呼叫 redeem payload builder
```

主檔不再直接負責：

```text
reward grid UI
claim button UI
empty rewards UI
redeem payload 判斷細節
modified emote selection model
overlay visible emote filter
多欄位 overlay state 管理
```

---

## 2. Body / Grid / Claim UI

```text
lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_sheet_body.dart
```

負責：

```text
TwitchChannelPointsSheetBody
→ 錯誤 banner
→ 可領取忠誠點數按鈕
→ empty rewards state
→ reward grid layout

TwitchChannelPointsClaimButton
→ 領取忠誠點數禮物按鈕

TwitchChannelPointsRewardGrid
→ reward grid 自適應欄數
→ 2 / 3 / 4 欄
→ 呼叫 ChannelPointsRewardTile
```

這個檔案只處理 UI，不處理實際 redeem payload。

---

## 3. Sheet Models / Helper Types

```text
lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_sheet_models.dart
```

負責：

```text
TwitchChannelPointsModifiedEmoteSelection
→ Modify a Single Emote 的結果模型
→ emoteId 是最後要送 API 的 modified emote id
→ modifierId 只保留 UI metadata

TwitchChannelPointEmoteLoader
→ 載入 Channel Points 可選 emote 的 callback typedef

TwitchChannelPointEmoteCompleter
→ overlay 選擇流程使用的 Completer wrapper

filterChannelPointOverlayEmotes()
→ choose / modify overlay emote 過濾
→ modify 模式第一層只顯示有 modifications 的 base emote
→ query 搜尋 id / token
→ 預設最多取 240 個
```

---

## 4. Redeem Payload Builder

```text
lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_redeem_payload_builder.dart
```

負責：

```text
buildTwitchChannelPointRedeemPayload()
```

目前處理流程：

```text
1. requiresChannelPointModifiedEmoteSelection
   → 開 modify emote overlay
   → 回傳 JSON: {emoteId, modifierId}

2. requiresChannelPointOfficialEmoteSelection
   → 開 choose emote overlay
   → 回傳 emote id

3. requiresChannelPointMessageInput
   → 開聊天室訊息輸入 dialog
   → 回傳文字

4. isUserInputRequired
   → 開通用文字輸入 dialog
   → 回傳文字

5. 一般 reward
   → 回傳空字串
```

這個檔案不直接管理 overlay state，而是透過：

```text
TwitchChannelPointEmoteOverlayOpener
```

向主 sheet 要求開啟 overlay。

---

## 5. Emote Overlay State

```text
lib/features/twitch/presentation/sheets/channel_points/twitch_channel_points_emote_overlay_state.dart
```

負責：

```text
TwitchChannelPointsEmoteOverlayState
```

集中管理：

```text
mode
reward
emotes
selectedBaseEmote
loading
error
query
```

提供狀態轉換：

```text
hidden()
opened()
reloading()
loaded()
failed()
withQuery()
selectBaseEmote()
clearBaseEmote()
visibleEmotes()
```

主檔原本分散的欄位：

```text
_emoteOverlayMode
_emoteOverlayReward
_emoteOverlayEmotes
_selectedBaseEmote
_emoteOverlayLoading
_emoteOverlayError
_emoteSearchQuery
```

已整合成：

```text
TwitchChannelPointsEmoteOverlayState _emoteOverlay
```

---

## 6. Overlay UI

```text
lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_emote_overlay.dart
```

負責：

```text
ChannelPointEmoteMenuOverlay
ChannelPointEmoteOverlayMode
TwitchChannelPointEmoteOption 顯示
TwitchChannelPointEmoteModification 顯示
搜尋欄
重新載入 / 關閉 / 返回
choose / modify grid
```

目前 overlay UI 還留在 widgets/channel_points 底下，因為它可視為 Channel Points 專用 overlay widget，不屬於 sheet 主檔。

---

## 7. Existing Shared Widgets / Utils

```text
lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart
```

負責既有 reward tile / error / empty state 類 UI。

```text
lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_utils.dart
```

負責 reward 解析、可用狀態、標題、價格、排序、需求判斷等工具函式。

---

## 8. 目前 Channel Points Sheet 分層

```text
twitch_channel_points_sheet.dart
├─ sheet scaffold
├─ reward tap flow
├─ overlay open/reload/close/complete
└─ calls builder/body/state

channel_points/twitch_channel_points_sheet_body.dart
├─ body layout
├─ claim button
└─ reward grid

channel_points/twitch_channel_points_sheet_models.dart
├─ modified emote selection
├─ emote loader typedef
├─ completer
└─ overlay emote filter

channel_points/twitch_channel_points_redeem_payload_builder.dart
├─ text payload
├─ choose emote payload
├─ modify emote payload
└─ user input payload

channel_points/twitch_channel_points_emote_overlay_state.dart
├─ immutable overlay state
├─ state transition helpers
└─ visibleEmotes()

widgets/channel_points/twitch_channel_points_emote_overlay.dart
└─ overlay visual UI
```

---

## 9. 下一步建議

Channel Points 之後可以繼續拆：

```text
1. 把 overlay open/reload/complete 再包成 controller class
2. 把 reward tile widgets 裡的圖片 / cost / cooldown / disabled reason 再拆小
3. 把 channel points utils 中 reward type detection 分離到 parser/helper
4. 整理領取禮物 claim error 行為，確認 optimistic UI / refresh timing
5. 把 withOpacity deprecated 一次整理成 withValues 或 UI token helper
```

目前不建議再把 `twitch_channel_points_sheet.dart` 拆太碎，因為它還需要保留 widget lifecycle 與 `setState()` 控制 overlay。下一步更適合轉去拆：

```text
lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart
```

或整理 Channel Points widget layer：

```text
lib/features/twitch/presentation/widgets/channel_points/twitch_channel_points_sheet_widgets.dart
```
