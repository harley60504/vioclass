# StreamNook Follow / Relationship v11 Notes

## 查證結果

使用者提供的 `src-tauri/src/services/twitch_service.rs` 內，StreamNook 的 Follow / Unfollow 實作不是 WebView 操作，也不是 full mutation query，而是：

```text
DropsAuthService::get_token()
+ TWITCH_ANDROID_CLIENT_ID
+ Authorization: OAuth <drops token>
+ gql.twitch.tv/gql
+ persistedQuery APQ
```

## Follow mutation

```text
operationName: FollowButton_FollowUser
variables.input.targetID: target_user_id
variables.input.disableNotifications: false
sha256Hash: 800e7346bdf7e5278a3c1d3f21b2b56e2639928f86815677a7126b093b2fdd08
Authorization: OAuth <drops token>
Client-Id: TWITCH_ANDROID_CLIENT_ID
Accept: */*
```

## Unfollow mutation

```text
operationName: FollowButton_UnfollowUser
variables.input.targetID: target_user_id
sha256Hash: f7dae976ebf41c755ae2d758546bfd176b4eeb856656098bb40e0a672ca0d880
Authorization: OAuth <drops token>
Client-Id: TWITCH_ANDROID_CLIENT_ID
Accept: */*
```

## Follow status check

StreamNook 的 `check_following_status` 使用主 OAuth token 走 Helix：

```text
GET https://api.twitch.tv/helix/channels/followed?user_id=<viewer_id>&broadcaster_id=<target_user_id>
Authorization: Bearer <main OAuth token>
Client-Id: TWITCH_APP_CLIENT_ID
```

## Flutter v11 對應

`TwitchPrivateGqlRelationshipApiServiceV1` 改成：

```text
checkFollowingStatus → main OAuth token + Helix /channels/followed
followChannel        → drops/android token + Android Client-ID + APQ hash
unfollowChannel      → drops/android token + Android Client-ID + APQ hash
```

v11 保留相容性：如果 WatchPage 仍然把 `_dropsAuthService.getToken` 傳進 `webTokenProvider`，service 會把它當作 legacy drops-token fallback 使用。

## 重要修正

v8-v10 的錯誤原因：

```text
1. 主 OAuth token + Web GQL client 會 failed integrity check
2. full mutation query 會 failed integrity check
3. APQ hash 沒找到時不應 fallback full query
4. StreamNook 實際用的是 DropsAuthService token + TWITCH_ANDROID_CLIENT_ID
```

v11 已內建 StreamNook 提供的兩個 APQ hash，不再動態掃 Twitch Web asset。
