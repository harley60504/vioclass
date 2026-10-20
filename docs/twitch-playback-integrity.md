# Twitch 播放 Client-Integrity 管理

## 現行播放接線

- `TwitchWatchServices.create` 的共用 `publicGqlApi` 仍是匿名 Web Client-ID；播放服務在自己的 request wrapper 中才按次加入已驗證的 Web viewer token，不改全域 GQL transport。
- 正式直播起播走 `TwitchPlaybackApiService`，由 `TwitchPlaylistPlayerRuntime` 平行取得 web／android／ios 三種播放參數，再讀 usher master playlist；`platform=android` 只是 GraphQL 變數，Client-ID 仍是 Web Client-ID。
- `TwitchPlaybackService`／`TwitchGqlClient` 是另一條未接到目前 watch runtime 的舊路徑，本輪未修改。

## 2026-10-10 實作

- 起播先讀既有 Web GQL 登入，不使用 Drops token。Web token 必須經 `/oauth2/validate` 證實屬於 Web Client-ID、有 user ID、與主登入 token 的 user ID 相同，且兩邊剩餘時間都超過 30 秒，才加入 `Authorization: OAuth ...`；驗證成功最多快取五分鐘且不超過兩個 token 最早到期前 30 秒，失敗只快取 30 秒。沒有新增或修改 token 儲存。
- 沒有 Web token 時直接匿名。儲存 token 無效或 Client-ID 不符時，普通公開直播可以匿名回退；若匿名 playback token 明確列出 `chansub.restricted_bitrates`，則丟出 `TwitchPlaybackAuthorizationException`，runtime 不再吞掉它並改成模糊的「所有來源失敗」。這不能判斷所有年齡／地區／訂閱限制，只處理 Twitch token 明示的 bitrate 限制。
- 正常播放先送原本的 `PlaybackAccessToken` query；沒有快取 proof 時不建立 WebView。登入可用時 query 帶同帳號 Web token，否則匿名。
- live、VOD 與 Clip 的播放授權都使用同一個已驗證 viewer 身分；Client-Integrity 更新仍只套在 live token 的明確拒絕，不把 Streamlink 明示不需要的 VOD 或一般 Clip 錯誤誤判成 integrity。
- 只有 GraphQL errors 明確包含完整字串 `failed integrity check` 才取得同一播放身分的 proof 並重試一次。一般 HTTP 401／403、逾時、網路失敗、格式錯誤與其他 GQL errors 都不觸發更新。
- proof 綁定 Web Client-ID、匿名／viewer identity、Device ID、原生 User-Agent 與官方 expiry，只存在記憶體；不讀寫 OAuth／Drops／私訊驗證快取。不同 Client-ID、帳號或 token 分開快取，同一身分並行更新共用 singleflight。
- 若帶 proof 的重試仍被明確拒絕，作廢該次 proof 並停止；不循環，也不把「已取得 proof」當成播放成功。晚到的舊拒絕不能清掉較新的 proof。
- Windows／Android 更新使用既有 Twitch WebView profile 的 headless 容器，等待官方 `kpsdk-ready`，再從相同頁面 context 呼叫 `/integrity`。其他平台目前明確回覆不支援，不假裝成功。

## Streamlink 與 StreamNook 核對

- Streamlink `master` 的 Twitch plugin 會先嘗試直播 access token；錯誤時才啟動 browser 取得 Client-Integrity，將 Device-ID 與 token 一起快取至官方 expiration，再重試一次。VOD 不走這個更新。其 browser 會攔截頻道主文件、改成 minimal document，再載入官方 KPSDK script，因此不是純 HTTP 永久產生 proof。
- VioClass 目前保留既有 Windows／Android 共用 profile 的正常 Twitch 文件載入；尚未採用 Streamlink 的 minimal-document request interception，因現有 Flutter WebView 兩平台攔截能力尚未做一致性實測。這是效能優化候選，不應先於 protected endpoint 成功驗收。
- StreamNook `main` commit `f0e2af02e421bfc2dc89ab17bf114e47fcf3b647` 已在 `twitch_resolver.rs` 明載「no Streamlink subprocess」。目前是 Rust 直接送 `PlaybackAccessToken`、取得 usher master、解析 variant，再由內建 `StreamServer` relay。
- StreamNook 的 `commands/streaming.rs` 先讀目前 Twitch OAuth；`twitch_resolver.rs` 在有 token 時判斷 Turbo／channel subscription，`auth_proxy.rs` 用 Web Client-ID 並為播放 GQL 加 `Authorization: OAuth ...`。VioClass 本輪採同樣的「登入優先、未登入匿名」原則，但只使用已經與 Web Client-ID 配對的 Web token，不把 Drops token 套到 Web Client-ID。
- StreamNook 的非 entitlement fallback 是可選 `playback.resolve` plugin hook；plugin decline、失敗或回傳 unusable master 時回到 core resolver。Cargo 與 `src-tauri` 播放程式沒有 Streamlink 依賴或子程序呼叫。
- StreamNook 目前的 `auth_proxy.rs` 沒有 Client-Integrity 管理；它的成功不能證明 Twitch 永遠不要求 proof。VioClass 因此採 Streamlink 的按需概念，但不採用 persisted query hash、不把所有 token 錯誤都當 integrity 拒絕。

## 驗證邊界

- 2026-10-11：19 項自動測試全部通過，使用假回應驗證 happy path、不超過一次 retry、generic 403 不更新、proof expiry、Client-ID／viewer 隔離、singleflight、stale rejection、live／VOD／Clip 登入 header、登入驗證 expiry、主登入 owner 配對、普通匿名回退、受限 bitrate 明確錯誤與 runtime 保留錯誤。新增測試確認取得中的 proof 到期或 manager 被 clear 時，每個等待者都收到拒絕；singleflight 現在共用驗證完成的結果，避免後加入的等待者略過 expiry／generation 檢查。
- 2026-10-10 唯讀真實探測：既有 Web token 的 validate 成功且 Client-ID 配對；對當下直播頻道，登入與匿名 `PlaybackAccessToken` 都取得有效 token 節點，均未遭 integrity 拒絕。該次測試帳號／頻道沒有可用的 Turbo 或訂閱 entitlement 案例，兩邊也都沒有 restricted bitrate，因此不能宣稱訂閱／Turbo 差異已實測，也不代表登入一定改善卡頓。
- 2026-10-11 00:50（Asia/Taipei）：SM X510／Android 16 實機探針通過。官方 Twitch WebView 取得匿名 proof；兩個並行要求只建立一個 browser、使用同一 proof、cache 可用，帶 proof 的真實 `PlaybackAccessToken` 端點回傳有效授權。安全摘要為 `passed=true browserAcquisitions=1 singleflight=true cache=true protectedEndpoint=true`。
- Android 真實 proof 取得與 protected endpoint 已驗證；Windows 尚未實測。這次沒有自然觸發播放端點「首次拒絕、再成功」，該有限重試與第二次拒絕停止由自動測試驗證。不能由此宣稱完整串流播放、訂閱權益或兩平台全部情境皆已通過。
- 最終播放範圍 `flutter analyze` 執行一次：0 error、1 warning（docs 測試檔使用 `SharedPreferences.setMockInitialValues` 的 visible-for-testing 提示）、1 info（既有測試的 if 缺大括號）；exit code 1，未重跑。正式播放來源無診斷，測試與實機 probe 均成功。
- 2026-10-11 重新查詢 StreamNook `main`，仍為上述 commit；重新閱讀 Streamlink 現行 Twitch plugin，按需 browser fallback 的研究結論仍適用。
- 真實驗收應記錄：首次匿名 token 是否成功、若明確拒絕是否只開一個 headless browser、取得 proof 後 protected endpoint 是否成功、第二次拒絕是否停止。記錄不得包含 token、Device ID、Cookie 或播放授權內容。
- `twitch_playback_integrity_device_probe.dart` 是獨立實機 probe：不讀登入資料、不顯示 proof，並行要求同一匿名 context 後確認只建立一次 browser、cache 可用，再以該 proof 呼叫 `PlaybackAccessToken`；不接正式 UI。

## 原始來源

- Streamlink Twitch plugin：<https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/twitch.py>
- Streamlink Twitch plugin 文件：<https://streamlink.github.io/cli/plugins/twitch.html#client-integrity-token>
- StreamNook resolver：<https://github.com/StreamNook/StreamNook/blob/f0e2af02e421bfc2dc89ab17bf114e47fcf3b647/src-tauri/src/services/twitch_resolver.rs>
- StreamNook auth proxy：<https://github.com/StreamNook/StreamNook/blob/f0e2af02e421bfc2dc89ab17bf114e47fcf3b647/src-tauri/src/services/auth_proxy.rs>
- StreamNook streaming command：<https://github.com/StreamNook/StreamNook/blob/f0e2af02e421bfc2dc89ab17bf114e47fcf3b647/src-tauri/src/commands/streaming.rs>
