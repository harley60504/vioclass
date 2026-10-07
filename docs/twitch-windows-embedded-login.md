# Windows 內嵌登入容器

- 已依使用者回報撤掉 Windows ExcludeFocus；保留原生及 Flutter 既有焦點整合，觸控問題另外追查，不當作 Google 跳轉的修正。
- 登入導航除 OAuth 回呼外皆回覆 ALLOW，沒有 Twitch 網域白名單。診斷僅記錄 scheme／host／決策，不記錄 query、Cookie、Token、輸入內容。
- 實測 Google 操作出現新視窗 `about:blank`；Windows 0.6.0 預設將 popup URL 載入 opener 原頁，會破壞先開空白子視窗再由 opener 導向的流程。主登入改以 action.windowId 建立真正的內嵌子 WebView，共用父 environment，不指定 initialUrlRequest、不替父頁導向、不自行釋放父 environment；先立即回覆 handled，再由原生建立完成 deferral。子頁回呼沿用原登入 state／驗證邏輯，先回到父登入 route 才完成授權。Google 是否接受此 WebView 仍須帳號實測，不宣稱已完整解決。

- 主 OAuth、Drops OAuth、Web GQL 補登入改用現有 flutter_inappwebview 的 InAppWebView，直接顯示於 App 登入頁。Android 原內嵌方式不變；Linux/macOS 原獨立視窗不變。
- 新共用 host 先建立 Windows WebViewEnvironment，指定既有 `new_twitch_app_shared_twitch_desktop_webview_v30` Cookie profile，再建立 WebView；失敗提供重試，絕不退回另一個預設 profile。
- Windows 採原生 WebView2 User-Agent，與先前獨立視窗及背景私訊驗證一致。Android Drops 原 UA 不變。
- OAuth URL、scope、state、回呼解析、Token 儲存、Drops Client-ID 驗證及 GQL persisted hash 都不變；不移除 OAuth 所需的授權同意步驟。
- 測試涵蓋 environment 準備前不建立登入 WebView、失敗重試、離開登入頁時釋放 environment。真實帳號仍需測主登入回呼、Web GQL 擷取、Drops 自動回呼，以及後續私訊背景更新。
- 實測發現 flutter_inappwebview_windows 0.6.0 的 Dart environment disposal channel 使用工廠 ID，而非原生建立的 environment ID。釋放發生 MissingPluginException 時改呼叫該 environment 的正確原生 channel；其他原生錯誤不吞掉。登入及背景私訊驗證共用此相容處理，未修改 Pub cache 或依賴版本。
- environment 建立失敗會留下錯誤碼與原生建立錯誤供追查，沒有記錄 Cookie、Token 或 OAuth URL。已確認釋放通道問題；其他啟動失敗仍需實測錯誤碼判斷，不能等同認定已全部解決。
- OAuth 導航攔截立即回覆 CANCEL，另外非同步完成既有 validate／儲存／GQL 擷取流程，避免讓原生導航一直等待到頁面切換或關閉。已登入 Cookie 可以直接回呼，不必出現登入表單。主登入的回呼網址與明確 CANCELLED 不顯示載入錯誤；其他主頁面錯誤仍保留，紀錄僅含錯誤類型及 host/path。
- 一鍵登入的 Drops 步驟接到同一個 OAuth WebView controller，完成主登入與 Web/GQL 後切換到 Drops authorize，不再 push 第二個 Drops 登入頁。Drops 已有效則跳過；每階段使用新的 state，Drops 回呼還須確認 Client-ID 及帳號與主登入一致。原 auth service 儲存方法和鍵不變。
- 正常流程只呈現 WebView 與必要的返回／關閉操作，不顯示登入標題、進度說明、URL、Token 預覽等除錯資訊；失敗才顯示錯誤及重試。重試留在目前階段，不要求重新建立 WebView。
- Windows 實測在成功的 OAuth/GQL/Drops 切換中回報 CONNECTION_ABORTED（about:blank 或 Twitch 首頁），不一定是 CANCELLED。僅將 about:blank 的中止、登入完成／GQL 擷取期間的 CONNECTION_ABORTED 視為預期切換；一般頁面中止及其他類型錯誤仍顯示。Token 驗證、GQL 擷取及 Drops 驗證的最終失敗不受這個 UI 分類影響。
