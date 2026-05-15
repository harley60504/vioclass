# StreamNook Unified Login v20

修正 Drops / Android device flow 在 WebView 授權頁按下授權後容易卡住的問題。

重點：

- 保留 Drops device flow，不回到 OAuth redirect。
- 參考 Frosty 對 Twitch auth WebView 進行 JS layout/scroll 修正的做法。
- 不自動點擊授權，只自動捲動可能的 consent container，讓 Twitch 授權按鈕能正常啟用。
- 新增「自動捲到底」按鈕。
- 新增 onUpdateVisitedHistory 後立即 poll，避免 Twitch SPA 導航後沒有觸發完整 load stop。
- 外部瀏覽器 fallback 保留。
