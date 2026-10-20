# 私訊驗證生命週期

## 2026-10-10：Android Client-ID 唯讀列表與歷史

- 現有 Drops token 只透過 `TwitchDropsAuthService.getToken()` 讀取，不新增儲存鍵、不改 OAuth/token 儲存。每個候選 token 都先呼叫 Twitch validate，只接受 owner 相同且 Client-ID 精確等於 Twitch Android public Client-ID 的 session；外帳號、失效或未知 Client-ID 皆不發送私訊請求。
- 列表與歷史優先使用這個 Android session，不夾帶 Web `Client-Integrity`；若 Android 路線收到 GQL 錯誤或 HTTP 401/403，只允許重新驗證同 owner Web session 並回退一次。Web 路線仍沿用原本 Integrity 與一次更新上限，不會把 Web token 改成 Android Client-ID。
- 2026-10-10 Windows 唯讀實測：列表首頁 2 edges，無 pageInfo，最後 edge cursor 可用；用該 cursor 請求第二頁得到 0 edges、無 GQL 錯誤，才能確認本次列表到底。不能因首頁只有 2 筆就宣稱帳號沒有更多封存／其他類型對話。
- 同一實測的歷史回應無 pageInfo；連續 25 頁共 500 edges，每頁最後 cursor 均可用且前進，沒有空 cursor、重複 message ID 或 GQL 錯誤。因達本次 25 頁安全上限而停止，尚未到空頁，所以這是「分頁路線有效」證據，不是「完整歷史已同步」證據。
- persisted query operation/hash 與請求變數維持原值；只讀實測沒有發送私訊、封存對話或其他 mutation。
- 2026-10-10 SM X510（Android 16）實機驗收：對話列表兩頁為 2→0 edges，兩頁均驗證同 owner、使用 Android client、不取得 Web Integrity，無 GQL 錯誤；兩個匿名對話的歷史首頁分別為 1 edge（空 cursor，無 pageInfo）與 20 edges（cursor 皆有效，無 pageInfo），均成功保留訊息且沒有誤報完整歷史。實機操作僅開啟列表與選取對話，未發送、封存或領取任何內容。

## 2026-10-10：根據 Windows 終端回應修正歷史解析

- 終端證實列表與歷史請求均通過驗證；失敗頁有一則訊息、空 edge cursor、沒有 pageInfo。先前只接受明確最後一頁的修正未涵蓋這個形狀。
- 有效訊息與分頁完整性分開處理：新增僅存在於 API 回應模型的 `paginationKnown`，未知邊界仍合併訊息並去重，但保留既有游標／完整性狀態，不憑空宣稱歷史全部完成。沒有新增儲存欄位或更動 token 儲存。
- 完整恢復遇到未知邊界先保留訊息，再停止並保留恢復 checkpoint，避免原游標重複請求或錯誤完成。明確 hasNextPage=true 卻無可用邊界、外帳號訊息、錯誤型別及停滯游標仍拒絕。
- 此修正不改 UI、登入、persisted query hash。實際對話重新開啟後的同步仍需實測。
- 驗證：歷史解析與恢復兩份測試 55 個通過；一次六檔 scoped analyze 為 0 error、1 既有 warning（history retry 在 try 內 return Future 沒有 await）。額外 inbox UI 套件有 3 個失敗（尾端定位、通知中心開對話、toast 開對話），未修改相關 UI，也尚未判定與本次修改的關聯；尾端定位個案在列表刷新後找不到預期 widget。

- 主 OAuth、Web GQL、Drops token 的現有儲存鍵和流程不變；不改 persisted query hash。
- 私訊完整性驗證獨立存入 FlutterSecureStorage：`vioclass_whisper_integrity_context_v1`。
- 加密內容為完整性 token、有效期、官方頁面的 Device ID/User-Agent，以及帳號、Client-ID、Web session token 綁定。此綁定只供確認驗證屬於同一 session，不用來取代原 OAuth 儲存。不得列印這些秘密。
- 重開後按需讀取快取；帳號、Client-ID、session 不匹配或過期，不使用舊資料。到期前 30 秒視為需要更新。
- 無常駐瀏覽器、無定時刷新。缺少或快到期時才執行背景 Twitch 正常 SDK 驗證，成功後關閉瀏覽器；訊息本身由原 GQL API 取得，無 DOM 抓取。
- Windows 的背景驗證改用既有 `flutter_inappwebview` 的 HeadlessInAppWebView；原生 host 建立時即不可見，不再先開視窗再隱藏。指定 WebViewEnvironment 沿用登入頁的 `new_twitch_app_shared_twitch_desktop_webview_v30` Cookie profile，結束先釋放 WebView 再釋放 environment。原登入視窗仍使用 desktop_webview_window，不新增或升級套件。Android 維持原生 HeadlessInAppWebView 的共用 Cookie。不中斷現有登入、不清 Cookie、不自動發起 OAuth 登入。
- 同一 session 的並行請求共用一次驗證。登出中斷進行中的驗證並刪除私訊驗證快取；排隊寫入不會把登出前資料寫回。
- 明確 `failed integrity check` 時，只作廢該請求用過的驗證，再背景更新並重試一次；再次失敗直接回報，不循環。舊回應不能清除已更新的新驗證。
- 真實 Twitch SDK／帳號環境仍需實測。單元測試覆蓋快取恢復、過期更新、並行合併、登出取消、錯誤重試上限；Android 真機未驗證。

## 2026-10-10：手機桌面識別與歷史游標

- Android 的主登入 WebView 建立前、背景驗證 browser 啟動前，先透過原生 WebView `getDefaultUserAgent()` 取得實際 Chromium/WebKit 版本；共用桌面識別不再在這兩條驗證路徑硬編碼 Chrome 120。Windows 保留原生 WebView2/Edge 識別。
- 原生版本準備完畢後，Android 若私訊快取的 User-Agent 與新的識別不同，沿用既有正常驗證流程更新私訊 proof。沒有改主 OAuth／Web GQL／Drops token 儲存鍵、Cookie profile 或 persisted query hash。
- 歷史解析原本要求每一條 message edge 都有非空 cursor。改為檢查頁面邊界：`pageInfo.hasNextPage == false` 明確表示最後一頁時，允許 message edge 沒有 cursor；非最後一頁可以使用有效的 `pageInfo.endCursor` 或最後 edge cursor。沒有游標、也沒有明確結束證據的非空回應仍然拒絕，不把它當成空列表或假成功。
- 這是根據使用者提供的 `messages/edges/cursor` 失敗階段新增的安全相容處理，尚未看到該對話的實際回應，不能宣稱已涵蓋所有缺欄位情況。Android 完整性拒絕与 Windows 歷史格式錯誤是兩條不同問題。
- 回歸測試：5 份共 53 個通過。一次 scoped analyze：0 error、1 warning（既有 history retry 在 try 內 return Future 沒有 await）、1 info（既有 if 大括號）。沒有重新 analyze 或順手修正其他流程。
