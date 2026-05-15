# StreamNook / Flutter Twitch Token Split v15 Notes

## 問題定位

v13/v14 診斷顯示 Follow / Unfollow 仍拿到：

```text
tokenSource=legacyWebTokenProviderAsDropsToken
validate.client_id=kimne78kx3ncx6brgo4mv6wki5h1ko
```

這代表 Flutter 把「互動 Web token」存進 / 傳進 Drops token 路線。這不是使用者沒登入，而是 token storage/provider 分流錯誤。

## v15 分流規則

### Main OAuth token

用途：

```text
Helix /channels/followed
IRC chat
官方貼圖 / Helix user API
```

Storage：

```text
new_twitch_app_twitch_auth_token
new_twitch_app_twitch_client_id
```

### Web GQL token

用途：

```text
kimne Web GQL
ChannelPointsContext
WebView cookie / storage 互動 token
```

Storage：

```text
new_twitch_app_twitch_web_gql_token
new_twitch_app_twitch_web_gql_client_id
new_twitch_app_twitch_web_gql_validated_at
```

### Drops / Android token

用途：

```text
StreamNook-style FollowButton_FollowUser
StreamNook-style FollowButton_UnfollowUser
Prediction / Drops / Android-client GQL actions
```

Storage：

```text
new_twitch_app_twitch_drops_token
new_twitch_app_twitch_drops_client_id
new_twitch_app_twitch_drops_validated_at
```

Expected Client-ID：

```text
kd1unb4b3q4t58fwlpcbzcbnm76a8fp
```

## v15 主要變更

```text
1. 新增 TwitchWebGqlAuthService，Web token 不再放進 TwitchDropsAuthService。
2. TwitchInteractionWebLoginPage 改存 Web GQL token。
3. TwitchLinkedLoginPage 新增 Drops / Android device flow 登入入口。
4. TwitchWatchPage：Channel Points 使用 Web GQL token；Follow / Unfollow 使用 Drops token。
5. TwitchPrivateGqlRelationshipApiServiceV1 移除 legacyWebTokenProviderAsDropsToken fallback。
6. TwitchDropsAuthService 會把舊版誤存的 Web token 遷移到 Web GQL storage，並清空 Drops slot。
```

## 覆蓋後操作

1. 進入登入頁。
2. 按「重新檢查」，舊 Web token 會從 Drops slot 遷移到 Web GQL slot。
3. 若 Drops / Android token 未完成，按「登入 Drops / Android token」。
4. 依照頁面顯示的 Twitch device URL 與 code 完成授權。
5. 回播放頁再測 Follow / Unfollow。

## 正確診斷狀態

Follow / Unfollow 失敗時不應再出現：

```text
legacyWebTokenProviderAsDropsToken
client_id=kimne78kx3ncx6brgo4mv6wki5h1ko
```

若缺 Drops token，應顯示缺少 Drops / Android token，並引導回登入頁做 Drops device flow。
