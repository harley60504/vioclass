# StreamNook Follow / Relationship v10 Debug Notes

PATCH VERSION: streamnook_relationship_apq_debug_v10

## 這版解決什麼

v10 的目的不是宣稱 Follow / Unfollow 已經完成，而是避免繼續用 full mutation query 撞 Twitch integrity check。

v9 錯誤顯示仍 fallback 到 full-query：

```text
.../unfollow/full-query -> failed integrity check
```

v10 改成：

```text
APQ hash 找不到 → 直接停
APQ hash 找到 → 只送 persistedQuery
full query → 完全不送
```

## 為什麼要這樣

StreamNook 線索顯示 relationship write action 更像 Twitch Web APQ：

```text
FollowButton_FollowUser
FollowButton_UnfollowUser
targetID
persistedQuery
sha256Hash
```

full mutation query 已經被 Twitch integrity 擋，所以繼續改 selection set 沒意義。

## Token 分工

```text
Follow / Unfollow / checkFollowingStatus：主 Twitch OAuth token
IRC：主 Twitch OAuth token
Drops / Channel Points / Prediction：Drops Android token 或對應 Web/GQL token
```

Drops token 不應拿來做 relationship action。

## 下一步判斷方式

1. 如果錯誤是 `APQ hash not found`：代表還沒抓到 hash，需要繼續查 StreamNook `twitch_service.rs` 或 Twitch Web Network。
2. 如果錯誤是 `failed integrity check` 且 request mode 是 `apq`：代表 hash 有了，但還缺 integrity/session/device context。
3. 如果 mutation 成功但狀態沒更新：檢查 Helix `/channels/followed` viewerUserId / targetUserId。
