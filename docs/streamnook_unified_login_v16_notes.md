# StreamNook-style Twitch Unified Login v16

## 目標

把 Twitch 登入整理成一個入口，但底層維持三個獨立 token slot：

1. 主 Twitch token
   - Helix
   - IRC / 聊天室
   - 追隨狀態查詢

2. Web GQL token
   - Twitch Web / kimne Client-ID
   - Channel Points / Web GQL
   - 內部仍會做 ChannelPointsContext probe，但 UI 不再把 kimne GQL 測試顯示成第四項

3. Drops / Android token
   - StreamNook-style FollowButton_FollowUser / FollowButton_UnfollowUser APQ
   - Drops / Android device flow

## v16 主要變更

- `TwitchLinkedLoginPage` 改成三項驗證畫面。
- 新增「一鍵完成 Twitch 登入」按鈕。
- 一鍵流程會依序補：主 Twitch token → Web GQL token → Drops / Android token。
- 完整後會直接返回主頁。
- 新增「清除登入資訊」功能，會清掉主 token、Web GQL token、Drops token、WebView cookies/cache。
- `TwitchStreamPage` 啟動時會檢查三種 token，缺少 Web GQL 或 Drops token 時自動開登入檢查頁。
- Follow / Unfollow 仍走 Drops / Android token，不允許 Web token fallback。

## 解壓方式

把 zip 解壓到 `new_twitch_app/` 專案根目錄，zip 內已包含 `lib/` 與 `docs/`。

## Debug 重點

新的登入畫面只應顯示三項：

- 主 Twitch token
- Web GQL token
- Drops / Android token

不應再出現：

- kimne GQL 測試作為獨立第四項
- `legacyWebTokenProviderAsDropsToken`
- Drops token validate 出 `client_id=kimne78...`
