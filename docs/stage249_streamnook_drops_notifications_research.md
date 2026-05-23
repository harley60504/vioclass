# Stage 249 — StreamNook / NewNook Drops 與通知功能研究

> Branch: `stage249-research-streamnook-features`
> Date: 2026-05-23
> Scope: 先研究架構與可行性，不直接照搬 StreamNook 原始碼。

---

## 1. 目前專案已存在的基礎

### 1.1 專案身份

`pubspec.yaml` 目前 package name 是 `vio_class`，description 是 `VioClass streaming classroom app.`。也就是雖然 GitHub repo 目前仍叫 `new_twitch_app`，產品/專案代號可以視為 `vioclass`。

### 1.2 已存在的 Twitch auth 分層

目前專案已經不是單一 Twitch token，而是拆成：

```text
主 Twitch OAuth token
官方 Web / GQL token
Drops / Android token
```

`TwitchStreamPage` 已經建立並持有：

```text
TwitchAuthService
TwitchDropsAuthService
TwitchWebGqlAuthService
TwitchAuthApiService
TwitchDiscoveryService
```

這代表 Stage 249 可以直接沿用現有 auth runtime，而不是重新設計登入流程。

### 1.3 Drops / Android token 已有基礎

`TwitchDropsAuthService` 已經具備：

```text
loadStoredSession()
setDropsClientId()
saveSession()
startDeviceFlow()
pollForToken()
getToken()
validateToken()
logout()
```

設計重點：

```text
1. Drops token 與 Web GQL token 分開存。
2. Drops token 使用 Twitch Android / Drops-compatible public Client-ID。
3. token 不主動用 expires_at 判斷過期，而是直到 Twitch 拒絕再清掉。
4. 若舊 patch 把 Web Client-ID 誤存到 Drops slot，會遷移到 Web GQL slot。
```

### 1.4 Drops Device Flow 已存在

`TwitchDropsDeviceAuthApiService` 目前走 empty-scope device flow：

```text
startDeviceAuthorization(scopes: const <String>[])
pollDeviceToken(scopes: const <String>[])
```

註解也明確標示這是 StreamNook / TwitchDropsMiner style flow。

### 1.5 登入 UI 已支援三 token 檢查

`TwitchLinkedLoginPage` 已把完整登入定義為：

```text
webGqlTokenReady && mainLoggedIn && dropsTokenReady
```

若 Drops token 缺失，會導向 `TwitchDropsDeviceLoginPage`。

### 1.6 共用 API client 可直接延伸

`TwitchApiClient` 已有：

```text
getJson()
postJson()
patchJson()
deleteJson()
```

並且統一把非 2xx 回應轉為 `TwitchApiException`。因此 Drops / notification 相關 API service 應優先沿用這層。

### 1.7 常數層已具備必要 endpoint

`TwitchApiConstants` 已經包含：

```text
helixBaseUrl = https://api.twitch.tv/helix
gqlEndpoint = https://gql.twitch.tv/gql
ircWebSocketUrl = wss://irc-ws.chat.twitch.tv:443
hermesWebSocketUrl = wss://hermes.twitch.tv/v1
```

也包含：

```text
twitchWebClientId
twitchAndroidPublicClientId
twitchDefaultDropsClientId
```

這對 Stage 249 很有利，因為 Drops / Channel Points / Prediction / Hermes 都需要清楚區分 token 與 Client-ID。

---

## 2. StreamNook 參考功能拆解

StreamNook 參考文件中，Drops 相關 command 包含：

```text
get_drops_settings
update_drops_settings
get_active_drop_campaigns
get_drops_inventory
get_drop_progress
claim_drop
check_channel_points
claim_channel_points
get_drops_statistics
get_claimed_drops
get_channel_points_history
get_channel_points_balance
get_all_channel_points_balances
start_drops_monitoring
stop_drops_monitoring
update_monitoring_channel
```

Drops auth 相關 command 包含：

```text
start_drops_device_flow
poll_drops_token
drops_logout
is_drops_authenticated
validate_drops_token
open_drop_details
```

通知相關可參考：

```text
send_test_notification
get_resub_notification
use_resub_token
```

Stage 249 建議先不要一次全做，而是分成 research prototype：

```text
A. Drops token / GQL 探針
B. Drops inventory / campaign snapshot
C. Drops monitor loop
D. local notification service
E. UI sheet / debug panel
```

---

## 3. 官方 Twitch API 可行性判斷

### 3.1 Helix Drops Entitlements 不是一般使用者 Drops 頁面

官方 Helix API 有：

```text
GET /helix/entitlements/drops
PATCH /helix/entitlements/drops
```

但它的定位是 game / organization entitlement 管理：

```text
- 查 organization/game/user 的 entitlements
- 更新 entitlement fulfillment status
- Client ID 必須屬於持有遊戲 organization 的成員
```

結論：

```text
一般 viewer 想看 Twitch Drops campaign / inventory / progress / claim，不能只靠這個官方 Helix endpoint。
Stage 249 應該把 Helix Entitlements 視為低優先級或備註，不要當主線。
```

### 3.2 EventSub 對 Channel Points 有官方事件，但權限偏 broadcaster/moderator

官方 EventSub 支援：

```text
channel.channel_points_custom_reward_redemption.add
channel.channel_points_custom_reward_redemption.update
```

但需要：

```text
channel:read:redemptions 或 channel:manage:redemptions
```

結論：

```text
這比較適合實況主或管理者，不適合一般 viewer 端追蹤自己的 Drops / channel points。
Viewer 端仍然需要 GQL / Hermes / polling 補資料。
```

### 3.3 Windows notification 套件限制

`flutter_local_notifications` 有 Windows support，但要注意：

```text
1. Windows 不支援 repeating notifications。
2. 未打包成 MSIX 時，cancel 與 getActiveNotifications 會受限。
3. 一次性 toast notification 仍可作為 Stage 249 prototype。
```

結論：

```text
Stage 249 通知功能建議先做單次通知與 app 內 banner，不要一開始就設計排程通知。
```

---

## 4. Stage 249 建議檔案規劃

### 4.1 API service

```text
lib/features/twitch/api/drops/twitch_drops_gql_api_service_stage249.dart
lib/features/twitch/api/drops/twitch_drops_models_stage249.dart
```

用途：

```text
- 呼叫 gql.twitch.tv/gql
- 使用 Drops / Android token 或 Web GQL token 做 A/B 測試
- 封裝 raw JSON，不讓 Widget 直接解析
```

### 4.2 Monitor / Controller

```text
lib/features/twitch/services/drops/twitch_drops_monitor_service_stage249.dart
```

用途：

```text
- 保存目前 monitoring channel
- 定時 refresh campaign / inventory / progress
- 偵測 claimable drop
- 去重通知
- dispose 時停止 timer
```

### 4.3 Notification service

```text
lib/features/twitch/services/notifications/twitch_local_notification_service_stage249.dart
```

用途：

```text
- Windows / desktop local notification wrapper
- 不把 flutter_local_notifications 直接散落到 UI
- 提供 fallback app banner / SnackBar interface
```

### 4.4 UI / Debug panel

```text
lib/features/twitch/presentation/pages/twitch_drops_lab_page_stage249.dart
lib/features/twitch/presentation/sheets/twitch_drops_monitor_sheet_stage249.dart
```

用途：

```text
- 顯示 Drops token 狀態
- 測試 GQL operation
- 顯示 raw / parsed snapshot
- 手動 claim 測試
- 手動 send test notification
```

---

## 5. 資料流建議

```text
TwitchStreamPage / PlayerPage
        ↓
TwitchDropsMonitorService
        ↓
TwitchDropsGqlApiService
        ↓
TwitchApiClient → gql.twitch.tv/gql
        ↓
TwitchDropsSnapshot / TwitchDropCampaign / TwitchDropProgress
        ↓
UI sheet + notification service
```

通知觸發條件：

```text
1. 有新的可領取 drop
2. 目前 campaign progress 達到 100%
3. monitoring channel 失效或 stream offline
4. token invalid，需要重新登入 Drops / Android token
```

去重 key：

```text
dropId + campaignId + claimState
```

---

## 6. 初步實作順序

### Step 1：建立 Drops Lab，不接正式 UI

```text
- 顯示 Drops token 是否存在 / validate 狀態
- 顯示目前使用的 Drops Client-ID
- 加一個「測試 GQL」按鈕
- 顯示 raw response
```

### Step 2：找 Twitch Web/GQL operation

需要用 DevTools 對 Twitch Drops 頁面觀察：

```text
https://www.twitch.tv/drops/inventory
```

優先找：

```text
Drops inventory query
Drops campaigns query
Drop progress query
Claim drop mutation
```

### Step 3：建立 parsed model

```text
TwitchDropCampaign
TwitchDropReward
TwitchDropProgress
TwitchDropInventoryItem
TwitchDropClaimResult
```

### Step 4：做 monitor loop

```text
- 60~180 秒 refresh 一次
- manual refresh 不受 timer 限制
- App 關閉或頁面 dispose 停止
- 通知要 debounce / dedupe
```

### Step 5：接 notification prototype

```text
- 先做 send test notification
- 再做 claimable drop notification
- Windows 未 MSIX 時先不依賴 cancel / active notification query
```

---

## 7. 風險與限制

```text
1. StreamNook 授權未確認，不直接複製原始碼。
2. Helix Entitlements 不是 viewer Drops inventory 的主解。
3. Drops Web/GQL operation 可能會改，需要保留 raw fallback 與診斷 log。
4. Flutter Windows notification 若未 MSIX，取消通知與查詢 active notification 有限制。
5. 使用 public Android Client-ID 屬於相容性研究，正式版要保留可配置與 fallback。
6. Timer polling 不能重建整個聊天室或播放器頁，必須隔離到 controller / notifier。
```

---

## 8. 目前結論

Stage 249 最合理的第一個真正 patch 不是直接做完整 Drops UI，而是：

```text
新增 Drops Lab / Probe
→ 驗證 Drops token 能否打 Twitch GQL
→ 確認 inventory / campaign / claim mutation
→ 再把結果抽成 service + monitor + notification
```

因為目前專案已經具備 Drops auth、Android public Client-ID、GQL endpoint、Hermes endpoint、共用 API client，所以 Stage 249 的主工作會集中在：

```text
1. 找 operation
2. 封裝 model
3. 做 monitor loop
4. 做 notification wrapper
5. 整合到登入/設定/播放器入口
```
