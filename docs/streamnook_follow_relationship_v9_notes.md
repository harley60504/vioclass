# StreamNook Relationship v9 Notes

## 結論

v8 的錯誤證明：

- main OAuth token + Twitch Web GQL Client-ID + full mutation query 會被 Twitch integrity check 擋下。
- app Client-ID 不能拿來打 Twitch Web GQL follow/unfollow mutation。
- web auth-token + full mutation query 也會被 integrity check 擋下。

因此 v9 改成：

1. Follow status 仍然優先走 Helix `/channels/followed`。
2. Follow / Unfollow 改成 APQ / persisted query 優先。
3. 若沒有手動提供 APQ hash，會嘗試從 Twitch Web 靜態 JS assets 中動態尋找：
   - `FollowButton_FollowUser`
   - `FollowButton_UnfollowUser`
4. 找到 APQ hash 後才送 `extensions.persistedQuery` payload。
5. full query 只保留為最後診斷 fallback。

## Token 分工

- Relationship / IRC：主 Twitch OAuth token。
- Channel Points / Drops / Prediction：Drops Android token 或對應功能 token。
- 不要用 Drops token 做 Follow / Unfollow。

## 如果 v9 仍失敗

代表 Twitch 目前對 follow/unfollow write mutation 還要求額外 Web session context，例如：

- Client-Integrity
- Client-Session-ID
- Client-Version
- X-Device-Id
- 其他 Twitch Web runtime 產生的 header

這時下一步要從實際 Twitch Web Network request 抓 headers，而不是再猜 GQL 欄位。
