# StreamNook Follow / Relationship 查證筆記

更新日期：2026-05-14

## 結論

StreamNook 的 Follow / Unfollow 不是單純開 WebView。前端會呼叫 Tauri command：

```text
follow_channel
unfollow_channel
check_following_status
```

後端再轉到 `TwitchService`。Flutter 版應對齊成：

```text
Flutter WatchPage / PlayerArea
→ TwitchRelationshipApiService
→ Helix / Twitch GQL
```

## Token 分工

```text
Follow / Unfollow / checkFollowingStatus → 主 Twitch OAuth token
IRC chat read/write → 主 Twitch OAuth token
Channel Points / Drops / Prediction → Drops Android token 或對應 Web/GQL token
```

不要把 Drops Android token 拿來做 Follow / Unfollow。

## v8 實作策略

1. 查 follow 狀態先用 Helix `/helix/channels/followed`。
2. Follow / Unfollow 使用 StreamNook/Twitch Web operation name：
   - `FollowButton_FollowUser`
   - `FollowButton_UnfollowUser`
3. Mutation variables 使用 `input.targetID`。
4. 主 OAuth token 優先，Web token 只做 fallback。
5. 如果日後查到 StreamNook 實際 APQ `sha256Hash`，可用 dart-define 補：

```bash
--dart-define=TWITCH_FOLLOW_APQ_HASH=<hash>
--dart-define=TWITCH_UNFOLLOW_APQ_HASH=<hash>
```

## 已踩過的錯誤

```text
Cannot query field "id" on type "Follow"
Cannot query field "user" on type "UnfollowUserPayload"
failed integrity check, path: [unfollowUser]
```

前兩者是 payload selection set 寫錯；後者可能與 operationName、token/header 組合或 Twitch APQ / integrity context 有關。
