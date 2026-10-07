# 私訊驗證生命週期

- 主 OAuth、Web GQL、Drops token 的現有儲存鍵和流程不變；不改 persisted query hash。
- 私訊完整性驗證獨立存入 FlutterSecureStorage：`vioclass_whisper_integrity_context_v1`。
- 加密內容為完整性 token、有效期、官方頁面的 Device ID/User-Agent，以及帳號、Client-ID、Web session token 綁定。此綁定只供確認驗證屬於同一 session，不用來取代原 OAuth 儲存。不得列印這些秘密。
- 重開後按需讀取快取；帳號、Client-ID、session 不匹配或過期，不使用舊資料。到期前 30 秒視為需要更新。
- 無常駐瀏覽器、無定時刷新。缺少或快到期時才執行背景 Twitch 正常 SDK 驗證，成功後關閉瀏覽器；訊息本身由原 GQL API 取得，無 DOM 抓取。
- Windows 的背景驗證改用既有 `flutter_inappwebview` 的 HeadlessInAppWebView；原生 host 建立時即不可見，不再先開視窗再隱藏。指定 WebViewEnvironment 沿用登入頁的 `new_twitch_app_shared_twitch_desktop_webview_v30` Cookie profile，結束先釋放 WebView 再釋放 environment。原登入視窗仍使用 desktop_webview_window，不新增或升級套件。Android 維持原生 HeadlessInAppWebView 的共用 Cookie。不中斷現有登入、不清 Cookie、不自動發起 OAuth 登入。
- 同一 session 的並行請求共用一次驗證。登出中斷進行中的驗證並刪除私訊驗證快取；排隊寫入不會把登出前資料寫回。
- 明確 `failed integrity check` 時，只作廢該請求用過的驗證，再背景更新並重試一次；再次失敗直接回報，不循環。舊回應不能清除已更新的新驗證。
- 真實 Twitch SDK／帳號環境仍需實測。單元測試覆蓋快取恢復、過期更新、並行合併、登出取消、錯誤重試上限；Android 真機未驗證。
