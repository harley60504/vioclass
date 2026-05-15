# StreamNook Follow / Relationship v13 Notes

## 目的

v13 針對 Flutter 版 Follow / Unfollow 仍出現 `failed integrity check` 的情況，修正 token / client id 來源判斷。

## 背景結論

使用者提供的 StreamNook `twitch_service.rs` 顯示：

- `follow_channel` 使用 `DropsAuthService::get_token()`。
- `follow_channel` 的 `Client-Id` 使用 `TWITCH_ANDROID_CLIENT_ID`。
- `Authorization` 使用 `OAuth <drops token>`。
- `FollowButton_FollowUser` APQ hash：
  `800e7346bdf7e5278a3c1d3f21b2b56e2639928f86815677a7126b093b2fdd08`
- `unfollow_channel` 使用同一組 Drops token / Android Client-ID。
- `FollowButton_UnfollowUser` APQ hash：
  `f7dae976ebf41c755ae2d758546bfd176b4eeb856656098bb40e0a672ca0d880`
- `check_following_status` 則是另一條路：主 OAuth token + Helix `/channels/followed`。

## v13 變更

`TwitchPrivateGqlRelationshipApiServiceV1` 現在會依序取得 drops token：

1. `dropsTokenProvider`
2. legacy `webTokenProvider`，相容舊版 WatchPage 傳 `_dropsAuthService.getToken` 的寫法
3. 直接讀取 `SharedPreferences`：`new_twitch_app_twitch_drops_token`

Android / Drops Client-ID 會依序取得：

1. `dropsClientIdProvider`
2. 直接讀取 `SharedPreferences`：`new_twitch_app_twitch_drops_client_id`
3. `TwitchApiConstants.twitchDefaultDropsClientId`
4. `TwitchApiConstants.twitchAndroidClientId`

## Debug 訊息

如果 mutation 仍失敗，錯誤 details 會包含：

- tokenSource
- clientIdSource
- clientId
- OAuth validate summary
  - token 對應 client_id
  - login
  - user_id
  - scopes

這能判斷 Flutter 實際送出的 token 是否真的是 Android / Drops token。

## 下一步判斷

若 details 顯示：

- `validate.client_id != request clientId`：Flutter drops token 與 Client-ID 不配，必須重新設定 Drops Client-ID 並重新登入 Drops。
- `tokenSource=missing`：WatchPage 沒傳 token，且 SharedPreferences 沒有 drops token。
- `clientIdSource=TwitchApiConstants...` 但該值不是 StreamNook 的 Android Client-ID：需要修 `TwitchApiConstants.twitchDefaultDropsClientId` 或呼叫 `TwitchDropsAuthService.setDropsClientId(...)` 後重新登入。
- `validate failed`：token 已失效，重新跑 Drops device flow。
