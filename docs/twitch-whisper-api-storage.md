# 新增私訊 API 與儲存清單

## 2026-10-05：私訊驗證併入既有登入視窗（取代同步時背景開窗）

新增 TwitchWhisperLoginIntegrityService，僅以記憶體保存 owner/client/Web token identity/到期時間及配對完整性 context，不新增任何持久儲存 key。一般聯合登入的 OAuth WebView 原本便會導向 Twitch 首頁擷取 Web/GQL token；現於同一個既有容器 document-start 監聽官方 kpsdk-ready，完成 Web token 驗證且核對主登入帳號後，在此容器 fetch /integrity，最多等待 40 秒，再關閉既有登入視窗。Windows 使用原獨立登入視窗，Android 使用原 Flutter InAppWebView，不再額外建立 SDK 測試視窗。SDK 失敗不改寫已完成的主 OAuth 登入為失敗；私訊端會明確拒絕缺少或失效的 context。

Home 的列表 integrityProvider 及單一對話歷史的 integrityHeadersProvider 均改讀登入快取；讀取不能開窗、導頁、重登或持久寫入。同期同帳號多次 GQL 沿用原 context，帳號/client/Web token 變更或過期拒用；Home 與聯合登入的登出入口清除快取，也使尚未完成的舊擷取失效。旧 TwitchWhisperSdkIntegrityProbe 檔保留為未接線的先前測試工具，正常私訊入口已不呼叫它，TWITCH_WHISPER_SDK_PROBE 啟動參數不再使同步背景開窗。未改 persisted hashes、OAuth/token 儲存、IRC、Points payload 或播放器 runtime。

限制：不保存完整性 context，因此 App 重開或 context 到期後，要由使用者既有登入入口重新準備；聯合登入按下登入時會檢查有效 context，必要時使用原登入流程，即使既有 OAuth 仍有效。沒有自動背景視窗續期，也不宣稱 Cookie 可取代完整性驗證。Android 同容器取得與真人 Windows 新登入尚未驗收；64 項快取／列表／歷史測試通過、限定修改檔案的一次 flutter analyze 無問題。下方背景開窗章節是歷史紀錄，不是本輪正常入口。

## 2026-10-05：移除殘留的歷史恢復入口與常駐缺口提示

automaticSync=true 的正常介面不再顯示恢復全部歷史的時鐘按鈕，也不常駐顯示「可能有未恢復的收件區間；連線不代表歷史已補齊」。這是離線收件缺口紀錄，不是最近一次列表同步的成功／失敗狀態；僅移除容易誤會的日常顯示，未清除底層缺口紀錄或冒稱完整歷史已補齊。同步進行中、真正失敗與失敗重試仍保留。兩項自動同步介面測試通過；本輪一次 analyze 仍有原第 141、153 行兩項大括號格式提示，未反覆修正。

重要澄清：目前成功的 Windows SDK 測試仍建立背景 desktop_webview_window，官方 SDK 取得 context 後關閉，再直接 HTTP 查詢 GQL。它不是網頁私訊抓取，但絕不是完全不用 WebView。create 後才呼叫 setWebviewWindowVisibility(false)，存在短暫露出視窗的可能。本輪未改 SDK 驗證途徑，未宣稱消除閃窗或已有無 WebView 替代方案。

## 2026-10-05：私訊開啟時背景同步

預設 automaticSync=true：先顯示既有本機對話與草稿，開啟私訊後沿用 controller.syncThreads 更新列表，最多自動讀 10 頁；未讀完的列表在向下捲動接近尾端時繼續分頁。進入對話時更新近期歷史，往上捲到歷史開頭時讀下一頁。每個視窗合併同步工作，重新 build 不會重複開新同步，關閉視窗後不發後續頁／歷史請求；已開始的安全儲存仍由原 controller 管理。帳號變更後不借用舊頁面，新帳號另開工作。同步結果僅沿用既有 archive merge/checkpoint/draft 流程，沒有增加任何儲存 key 或修改 token / persisted hash。

正常畫面的同步列表／歷史按鈕與手動同步選單項目隱藏；只顯示進行中或失敗狀態。失敗保留本機資料及游標，顯示重試，沒有自動清空、重登或無限重試。手機 compact 介面的歷史錯誤以對話操作的錯誤圖示及重試項目呈現。進入後若使用者已向上閱讀，背景結果不追尾。仍需真人驗收遠端歷史 API；改成自動觸發不代表既有 parser／完整性限制已消失。

參考：[Flutter offline-first 官方文件](https://docs.flutter.dev/app-architecture/design-patterns/offline-first) 的「Using a Stream」先輸出 local 再取得 remote，以及 [TanStack 官方快取說明](https://github.com/TanStack/query/blob/main/docs/framework/react/guides/caching.md) 的背景 refetch；本專案沒有因此新增套件，只改現有同步入口。

舊手動同步 widget fixture 明確 automaticSync=false，保留原 controller／備份／恢復流程回歸測試；新增預設自動流程的獨立測試，覆蓋列表分頁、失敗重試、草稿保留、往上載入不追尾、關閉後停止後續請求。

本輪唯一一次 flutter analyze：沒有編譯錯誤，兩項 curly_braces_in_flow_control_structures（sheet 第 141、153 行）。依專案規則不反覆 analyze／修正，下一輪可補大括號。

## 2026-10-05：進入私訊定位最新、聊天室與私訊底部貼圖面板

本節取代下方「開啟對話不主動跳到底部」的舊決定：使用者要求進入對話先顯示最新，因此只在 owner/peer 改變時定位一次；收訊、載入歷史、鍵盤或尺寸變動不自動追尾，使用者滾動可取消尚未完成的定位。私訊頁首與對象資料的醒目重新整理按鈕移除，對象更新保留在對話操作選單；錯誤重試與歷史同步入口仍保留。

聊天室及私訊的貼圖選單皆改為輸入框下方的內嵌面板，展開會向上推輸入框，不另開對話框。私訊 Unicode 表情亦用同樣位置；官方貼圖可搜尋、連續插入與關閉，使用目前輸入選取範圍，不覆蓋外部更新的草稿，切換帳號或對象會收起舊面板。聊天室沿用官方／第三方快取、最近與收藏邏輯，來源分類仍保留；底部面板用剩餘空間限制高度，短視窗不擠出畫面。未新增儲存 key、未改 OAuth、GQL hash、IRC 或播放器 runtime。

本輪針對三個介面檔與兩個測試檔執行一次 flutter analyze，無問題。私訊與聊天室 widget 測試共 156 項通過，涵蓋開啟定位最新、手動往上後收訊不追尾、內嵌貼圖推高輸入框、短視窗與鍵盤、大字體、草稿及帳號切換。尚未執行真人 Windows／Android 視覺驗收。

## 2026-10-05：私訊捲動改為手動

開啟對話、新訊息、尺寸或鍵盤變更均不主動跳到底部；僅點「返回最新訊息」才尋找實際尾端，滑鼠滾輪、觸控拖曳與觸控板操作可取消尚未完成的手動尋尾。讀取狀態以實際尾端是否可見判斷，不以距尾端 90px 內視為已讀。同步狀態列增減時以固定 viewport key 保留訊息區，避免重建 ScrollPosition。搜尋框、對話卡片與訊息邊框做局部樣式整理，未改 API、授權或持久化格式。

本輪唯一一次 flutter analyze 無問題；其後的 viewport key 與閱讀狀態 UI 更新由 widget 測試編譯及驗證，依專案規則未再跑 analyze。

列表同步之所以在這個 Windows profile 成功，實測差異是由官方 SDK 正常初始化後取得完整性 context，並配對同裝置 ID 與該環境原生 UA，再直接 HTTP 發 GQL；先前直接取得 token 的流程仍遭 integrity 拒絕。不能僅憑這次成功斷言某一個 header 是唯一原因，也不代表 Android 或所有帳號已驗收。

## 2026-10-05：隔離 SDK 取得流程測試（Windows 列表實測通過）

新增 TwitchWhisperSdkIntegrityProbe，僅 kDebugMode 且 TWITCH_WHISPER_SDK_PROBE=true 時注入列表服務；目前只支援 Windows。重用既有 v30 WebView profile，建立暫時視窗後立即隱藏，載入正常 Twitch 首頁。文件建立時先監聽官方 kpsdk-ready；收到事件後透過頁面的正常 fetch 送 /integrity，使用同帳號已驗證 Web token 與頁面既有 unique_id device cookie，沒有合成裝置 ID，也不觀察悄悄話 operation。SDK 取得結果只放在記憶體，傳回前核對 owner/client/期限與 header 值，finally 關閉暫時視窗，再由既有 HTTP client 發列表 GQL，配對 device ID、原生 UA、Client-Integrity。這不是常駐瀏覽器，也不是網頁列表擷取。

未新增 token 儲存 key、未改 OAuth/token 儲存、未改 hash；正常瀏覽器載入可能更新既有 profile 的 SDK cookies。不輸出 token/device/UA 值或私訊內容。沒有登入時不開授權、不清資料；SDK 缺 device、請求失敗或 40 秒內未就緒則回報失敗，不退回網頁擷取。38 項列表測試通過，涵蓋 provider 接線、配對 headers、錯帳號與過期 context 不發請求；不代表實際 SDK 已取得或列表已接受。單次 analyze 發現 JS 正規式在 Dart 字串的語法錯誤，已改用長度與非法字元檢查、format 成功，未重跑 analyze。實機結果待下方更新。

實機結果：測試版以開關啟動後，由本機 Debug VM 呼叫既有 syncThreads，無需使用者開列表網頁或重新登入。官方 SDK 約 10.6 秒就緒，取得配對驗證資料並關閉背景環境；隨後直接 HTTP 列表回應 errors=0、integrityRejected=false，第一頁 3 個對話／29 則回應訊息，合併後本機 3 個對話，有 nextCursor。再透過有最多 10 頁限制的 Debug harness 按原 controller 讀下一頁：SDK 約 6.9 秒就緒、關閉後直接請求成功，下一頁 1 個對話／1 則回應訊息、無 nextCursor，合併後本機 4 個對話。至此證實這個 Windows 登入 profile 的列表與後續分頁可由 SDK 取得資料後直接 HTTP 完成，不須常駐瀏覽器、不讀私訊列表畫面。

實際 Debug build 與後續 hot reload 編譯成功；未重跑 analyze。尚未測 Android、完整性 token 到期後的長時間續用、其他帳號或網路；不宣稱所有環境都能通過。單一對話歷史 parser 仍是另一個未完成問題，本輪沒有修改。仍僅限隔離測試開關啟用，未將未驗收的跨平台流程全面取代正式版。

## 2026-10-05：目前採用的列表同步方式（優先於下方歷史紀錄）

使用者要求：同步沿用先前 WebView 登入留下的 Web 授權；不要每次另開 WebView、不要讀官方網頁作為正式列表同步、不要因 integrity 拒絕而要求重登。Home 已移除 browserResponse 注入及同步頁 import，使用既有 webGqlAuthService.getToken → history.webSession 同帳號驗證 → 直接列表 HTTP 請求。未改任何 OAuth/token 儲存邏輯或 persisted hash。舊瀏覽器同步頁保留但不再接到正式入口，沒有刪檔。

列表完整性驗證遭拒時，明確區分「登入驗證成功但列表 integrity 遭拒」，不自動開窗、不清除資料、不當成空列表。這仍是尚待解決的直接列表請求限制，移除網頁抓取不等於已證明遠端同步成功。

本輪已透過執行中 App 的 Debug VM 呼叫既有 syncThreads（非模擬 HTTP）：既有 Web token 的 sameOwner=true、webClient=true；/integrity 回 HTTP 2xx 且 token 存在、未過期；列表 GQL 仍 errors=1、integrityRejected=true。既有兩筆本機對話保留，未進入 archive merge。直接同步尚未成功，問題不是缺少登入或 parser。不能要求重登作為修正，也不能將本輪稱為列表功能完成。

修正缺少 pageInfo 的分頁判斷：若伺服器提供非空末筆 edge cursor，保留為下一頁游標；若有 pageInfo.hasNextPage=false 則結束；明示有下一頁卻沒游標，或游標未前進，拒收整頁。使用實際游標、不合成游標。刷新成功依既有 archive 流程更新 checkpoint，失敗不變更 checkpoint。

## 2026-10-05：單一對話歷史解析診斷

實機兩次單一對話歷史請求均為直接 HTTP，同帳號驗證成功、HTTP 2xx、GQL errors=0、integrityRejected=false，但 parser 拒收；尚不能視為歷史同步完成。新增 response/batch、data/whisperThread、messages/edges/cursor、node/from/id/content/sentAt/identity、pageInfo、nextCursor 的失敗階段，以及型別／筆數／游標是否為空的 Debug 記錄。不得輸出私訊文字、ID、游標值、Cookie 或 token。不改 hash、授權、儲存格式或放寬 parser；下一次實機回應應先定位欄位再決定修正。列表同步仍為瀏覽器輔助方式，與此直接歷史請求是兩條不同路徑。

## 2026-10-05：官方頁面列表同步入口

Home 的私訊列表 service 注入 browserResponse：Windows 使用獨立 desktop_webview_window 與既有 v30 登入 profile；Android 使用 Flutter InAppWebView。開啟正常 Twitch 首頁後，使用者登入同一帳號並開啟悄悄話。document-start observer 僅在 www.twitch.tv 觀察 fetch，不改 request、headers、token 或完整性 SDK；只接收官方列表 operation 及指定 cursor 對應的 batch response。回應交回既有 parser 核對 owner，再走原 archive/controller 保存。

不抽取或儲存瀏覽器 headers、OAuth 或完整性 token。不新增持久 key。observer 的回應只存在 WebView 記憶體，頁面結束關閉視窗；110 秒無回應返回失敗，controller 等待上限為兩分鐘。同步可見官方視窗，尚非無互動背景同步。若 Twitch 改用 XHR／Request body 或手機頁未發出此 operation，觀察器可能逾時；真人 Windows／Android 接收與完整列表分頁尚待驗收，不能宣稱已解決完整性檢查。

新增兩個測試核 browser 回應走解析而不呼叫直接 HTTP、以及異帳號回應拒絕。32 項列表測試通過，單次 analyze 無問題（新增測試後未重跑 analyze）。

## 2026-10-05：私訊同步診斷

Debug 模式的 `[WhisperThreads#序號]` 記錄 Web session 帳號匹配、完整性請求階段、token 是否存在／期限是否未到、GQL 回應型別／錯誤筆數／integrity 拒絕分類／server request ID，以及 parser 的欄位階段與對話／訊息筆數。成功 postJson 僅能確定 HTTP 2xx，失敗則記錄 TwitchApiException 的實際 HTTP status。`[WhisperSync generation=... request=...]` 記錄 controller 回應、merge 返回與 reload 筆數／上下文有效性。沒有輸出 Authorization、完整性 token、Cookie、游標值、私訊內容或帳號 ID；沒有新增永久紀錄。

2026-10-05 實機證明：直接 HTTP POST /integrity 取得 token 後，列表仍被 Twitch 回覆 `failed integrity check`。因此先前「端點回 token 就能修正」的推論不成立。Streamlink 的參考實作在瀏覽器中等待 Twitch 完整性 SDK 就緒後請求 token，並維持 device context；本 App 的直接 Dio 請求沒有這段瀏覽器工作階段。參考：https://github.com/streamlink/streamlink/blob/master/src/streamlink/plugins/twitch.py 。這是待核對的原因，不等於已證明某個額外 header 即可解決。

更正：使用者原始 JSON sentAt 是 ISO 時間。先前 PowerShell ConvertFrom-Json 自動轉日期，再以中文區域格式顯示，造成誤判；中文時間 fallback 不應被當作本次真人失敗的根因。

## 私訊列表完整性驗證

列表 persisted request 在實機回傳 `failed integrity check`。列表服務現在於每次請求前以相同 Web OAuth、Client-ID、User-Agent、Origin、Referer 呼叫 `POST https://gql.twitch.tv/integrity`，取得 token 後加入列表請求的 `Client-Integrity`。token 僅存在該次工作的區域變數，未新增磁碟 key、未修改 OAuth/token 儲存。空 token 中止列表請求，既有對話保持不變。

完整性端點回傳 token 不等於 Twitch 接受列表操作；仍需真人同步驗收，不能將 mock 的標頭傳遞測試視為通過 Twitch 完整性檢查。沒有加入 challenge 繞過或使用人工貼上的 token。

## 2026-10-04 最新：對齊 Twitch Web 私訊列表 persisted request

使用者提供了實際 Network request：`Whispers_Whispers_UserWhisperThreads` 使用單操作 batch、`variables: {"cursor":""}`，以及 persisted hash `b9535d107dc5b016645d2ef895c295e8001df6ff89ca26231599e0d11b2a5927`。列表服務已改為完全照此 request 發送；既有 `Whispers_Thread_WhisperThread` 歷史 hash 未修改。下一步只驗證真人同步，不再用 raw query 推測列表請求。

## 2026-10-04 最新：依實際 Twitch Web 回應修正對話列表 GQL

使用者提供的實際 Twitch Web JSON 已確認原先列表 query/parser 有三個錯誤：回應 `extensions.operationName` 是 `Whispers_Whispers_UserWhisperThreads`；thread 內容是 `node.messages.edges`（不是 `lastMessage`）；第一筆 thread edge 的 cursor 可以是空字串。實際回應同時確認 thread id 為依數字大小排序的兩個使用者 ID（不是字串排序）、participants 兩人、`unreadMessagesCount`，message ID 為官方 UUID。

2026-10-05 實機同步紀錄顯示官方瀏覽器已取得兩筆 edges，後續在 threadId 檢查失敗。核對原始回應發現 9 位 owner ID 應排在 10 位 peer ID 前；先前的字串排序錯誤導致本機拒收。共用 threadId 改為 BigInt 數值比較，同時修正單一對話歷史請求所用的 ID。新增獨立指定官方排序的測試，避免測試 fixture 與實作共用同一錯誤而一起通過。登入視窗收到列表後自動關閉是既有流程，不是這次授權失敗的證據；實際 UI 合併與歷史同步仍需重測。

`TwitchWhisperThreadsApiService` 已改用該 operation name 與 read-only raw query，查詢 message edges（保留 owner／peer／時間／內容／官方 ID）；解析器接受空 cursor（只有 hasNextPage 時才拒絕空的下一頁 cursor），並保留舊 preview `lastMessage` 的相容 fallback。GQL 歷史既有 `Whispers_Thread_WhisperThread` persisted hash 未修改；OAuth／token provider 未修改。

新增實際回應形狀測試：空首 cursor、message edge 與 `historicalOnly` 通過；原列表／controller／帳號隔離測試仍通過。這證明回應格式解析，不等於已用真人 token 成功發出新 query；使用者提供的 JSON 沒有包含原始 request 的 persisted hash／完整 query，因此 operation 的可執行性仍需 App 重新同步驗證。列表分頁變數也對齊 Twitch Web 常見的 `cursor`（首頁保留 `null`），若 GQL 回應含 `errors`，現在會把第一個錯誤訊息帶回 UI，方便分辨 query、client ID、token 或權限問題。

## 2026-10-04 最新：刪除等待時登出／換帳號的提交邊界

新增測試重現 removeConversation 等待 flushDrafts 時 clearSession，舊工作仍繼續刪除原帳號歷史（修前原對話讀回空）。controller 新增 disposed／loading gate，flush 後核 captured generation/owner；archive.removeConversation 新增可選 canApply，串行佇列開始與讀取完成、寫入前各核一次，取消返回 false，成功保存返回 true。原未帶 gate 的直接 archive 呼叫仍會刪除；controller 只在 true 時認定提交／清舊待存。沒有取消已開始的 adapter write 或謊稱已取消。

新增三個 archive lifecycle 測試：queued／read 撤上下文零目標寫入、原 JSON/草稿保留；write 已開始後撤上下文仍返回 true、目標刪除，另一帳號資料保持原有或其自身正常草稿保存。queued fixture 最初以相同草稿觸發 write gate，但 store 正確省略無變更寫入，改成確有變更的正常保存，不取消 no-op 契約。新增 controller logout 等草稿保存取消測試，以及寫入期間切帳號的晚成功／晚失敗兩例：原 owner 結果獨立、新 owner 草稿與期間新收件保留、無舊錯誤或 busy 污染。

八份私訊回歸263項全過；本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。無 API/scope/query/hash／磁碟 schema/key 或 OAuth/token 變更；新增 gate/布林回傳是私訊 archive 內部提交契約，非遠端回執。未用真人發送或刪除。真實斷電／adapter 寫入後拋錯仍不能憑 gate 判斷磁碟結果；它也不是跨程序交易。下一單元核對 private 草稿刷新與已登入 session 的 owner-generation 保存隔離，以及可靠官方 ID 與真人服務／兩平台必要證據，原全目標保持未完成。

## 2026-10-04 最新：刪除前的待存收件不再復活

回到私訊主線發現 removeConversation 成功後 _reload 會補存舊 _pendingIncoming，將剛刪掉的歷史復活。新增測試在修正前確實重現 target 同時含 pending-old 與 arrived-during-delete；失敗刪除分支則原先已能保留兩筆。不是以假成功文案掩蓋問題。

controller 在刪除開始固定 owner／peer 的待存物件快照，暫停僅該 peer 的補存；archive 刪除正常返回後，才移除仍為原物件的舊待存事件。期間新的官方 ID 保留，可重建對話；同 ID 重送仍是原事件，不算新收件。刪除失敗不丟待存事件，finally 解除暫停，下次載入可恢復。其他 peer 不受暫停影響。flush 每筆亦核對記憶體 identity，拒絕已被另一工作處理或移除的舊快照；owner/peer barrier 的操作 token 避免舊 finally 解除後續新 barrier。

無新磁碟欄位／key、API／scope／GQL query/hash；未改 OAuth/token。barrier、事件快照與 token 僅記憶體，隨該刪除工作完成釋放；不是持久事件佇列、跨程序鎖、斷電交易或遠端刪除。同 ID 遠端歷史日後主動同步仍可重新匯入，不把本機刪除當封鎖。未成功 write／read-after-write 歧義仍沿原 adapter 契約。

2新控制器測試驗成功只移除刪除前暫存、失敗保留、刪除 write gate 內新收件保存、其他 peer 暫存保存及通知次數；沒有 API 發送。最終七份私訊回歸257項全過，本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。

重新讀取 [StreamNook whisper_inbox.rs](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_inbox.rs) 的 send／merge 路徑，仍為本機 sent ID 與 ID 去重，未提供可靠 local→official ID 映射證據；沒有猜文字時間配對。下一單元核對帳號切換／同peer待存刪除生命週期，繼續尋找可靠關聯的上游證據並保留真人Web列表、雙向／背景與 Windows／Android 驗收門檻；完整目標未完成。

2026-10-03：使用者明確允許新增私訊 GQL、API 與專用 hash，要求列清楚並做好儲存。既有 persisted hash 與 OAuth/token 儲存不變。

## 最新狀態：列表同步與保存已接入

### 2026-10-04 續接：本機刪除結果與列表重讀分離

controller removeConversation 以 archive.removeConversation 正常完成為已刪除證據，並先從當前 owner 的可見列表移除目標、清其草稿暫存／選取／歷史來源索引，再重讀列表。若後續 read 失敗，明示「本機對話已刪除，但列表重新載入失敗」，不把已保存刪除說成一般寫入失敗、不維持已刪舊列。flush／delete write 尚未完成則提示刪除未完成，原儲存資料保留；開始新刪除清舊錯誤，失敗後解除busy可重試。只在 await write 正常返回時認定提交，不聲稱能判斷adapter寫入後拋錯或斷電的結果。

沒有新 schema／key／API，不改 OAuth。本機刪除不是封鎖：在刪除寫入期間才排入的新收件依 archive 序列化順序保存，可重新建立同 peer 對話（不帶回舊草稿）；其他 peer 資料不刪。不承諾跨程序鎖或永久禁止重建；本輪未改既有待存收件／通知／遠端同步規則。

3新測試：delete write失敗磁碟不變且重試成功；delete成功後read失敗可見列表不留舊目標、恢復重讀確認其他草稿；以 gate 固定刪除寫入中排入同peer及其他peer收件，保留新訊息各一筆／未讀1、原目標舊紀錄不復活、其他草稿仍在。七份私訊252項全過，本輪唯一 analyze 無問題。假帳號／記憶體後端，無真實資料刪除；真人及裝置門檻仍未驗收。

### 2026-10-04 續接：新匯入對話不沿用遠端會話狀態

直接核對 importBackup 發現：新 peer 原本沿用備份的 remoteUnreadCount、remoteHistoryCursor、remoteHistoryComplete，會顯示另一同步時點的遠端未讀、甚至停用載入更早訊息或從舊游標跳頁。新匯入 peer 現在將三欄重設為 0／null／false，保留人物資料、草稿與訊息；原本已有 peer 的草稿、遠端未讀及歷史進度完全保留。重新匯入不覆蓋匯入後已取得的新同步進度。

沒有新增 key／schema／API，也沒有改 token 保存。備份格式仍 version1，export 仍保留原對話欄位，但 import 不把新 peer 的遠端狀態視為目前會話證據；舊 archive 正常讀取不自動重設其既有進度。帳號層級的列表 checkpoint、缺口與恢復工作仍由原 archive 保存，不從備份導入。

新增2項測試涵蓋有舊 cursor／已完成兩種備份，修正前分別重現錯誤；修後驗證寫入故障原檔不變、新 store 重啟、草稿／內容保存、既有 peer 與帳號 metadata 不變、從首頁取得新游標後重複匯入不退回。七份私訊回歸240項全部通過；本輪唯一 flutter analyze --no-pub lib/features/twitch docs 無問題。沒有真人或實機操作；可靠送出 ID 關聯、真人列表／雙向私訊及 Windows／Android 驗收仍未完成。

### 2026-10-04 續接：匯入歷史與首次live提示分離

重新查閱 [Twitch Send Whisper](https://dev.twitch.tv/docs/api/reference/#send-whisper) 仍是204 No Content，且可能靜默丟棄；[Whisper Received](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#whisper-received) 描述收件事件，不能當發送回執。[StreamNook whisper_inbox.rs](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_inbox.rs) send仍生成本機sent時間隨機ID。查閱的路徑未找到本機與官方歷史ID關聯證據，不代表所有私有API必定不能提供；本輪不猜文字／時間配對刪資料、不新增mutation/hash、不用真人發送查驗。

實際發現匯入只保證磁碟未讀不增加，卻保留備份原historicalOnly=false，非尾端面板會將新ID匯入顯示「新私訊」。修正新增匯入訊息一律copy historicalOnly=true；sending仍轉unconfirmed，其他狀態保留。既有同IDlive訊息仍保留原狀，不把重複匯入改成historical；新peer仍不因備份解鎖長訊息。沒有新schema／key，使用既有布林欄位；舊archive無法判斷哪些曾匯入，未自動遷移／改其live證據。

面板另補首次live提升：此前只在messageCount變動時計新提示，同ID歷史→live不增加count便漏提示；現在記目前peer上一幀historical IDs，當同ID成live且正在讀舊訊息時只計一次。history匯入不提示；真正live依原controller提升未讀／通知，重送不重計。沒有修改閱讀位置／發送協議／OAuth。

新增3项測試：desktop1000×760與compact390×260匯入不顯示新訊息、原anchor保留、首次同IDlive有未讀1與提示、重送仍1；新store重啟保存歷史flag、既有live不退、sending轉未知，文字／參與者／時間完全相同但本機與官方不同ID的outgoing兩筆不被猜配刪掉。最初widget runAsync等fake-zone queue卡住，核對指定test Dart PID後停止該run，改逐幀及完成斷言；修正前兩尺寸確實重現匯入假提示，修後單項通過。七份最終回歸共238項全部通過；本輪唯一 flutter analyze --no-pub lib/features/twitch docs 結果為 No issues found。

仍未證明真人Web列表、實際雙向收件、Windows／Android背景與可靠送出ID，原整體目標保持未完成；不同ID可能重複顯示的限制仍明列，不以保存兩筆測試宣稱已解決關聯。

### 2026-10-04 續接：鍵盤歷史閱讀的UI驗證

本輪沒有新增儲存欄位／key／API；history anchor矩陣由4擴10（新增6），並驗live未讀及點返回最新才清。修正初始低可用sheet/放大字級的general版溢位、鍵盤可用高度提前compact及低横向live提示擠掉scroll。維持原穩定center anchor、historyOnly與未讀邏輯；詳細尺寸／失敗原因／驗證紀錄見twitch-whisper-requirements-audit.md。不能以widget結果推論真人API／所有裝置，完整目標仍未完成。

### 2026-10-04 續接：大型歷史重讀與無變更寫入

archive新增僅在記憶體的單一 owner 讀取快照（已驗證原始JSON＋不可變conversations）。每次load仍先呼叫read，owner及raw完全相同且已完成首次sending恢復，才重用模型；讀取失敗照樣失敗，raw變更重新解析／驗證，損壞不覆寫，來源刪除返回空而不回舊cache。切換讀取owner只保留最後一份cache，不為每帳號累積完整歷史。沒有新永久key／schema／token保存。

同draft保存與已經0本機未讀的markRead，完成合法archive load後直接返回，不重建訊息／編碼／寫入整份archive；真正草稿／未讀變更仍走原serialized保存，remoteUnread來源不改。模型與消息列表已不可變，reuse不允許呼叫者修改原資料。首次sending→unconfirmed保存及失敗後重試規則保留，不能因cache略過恢復checkpoint；新JSON需重驗，不靠cache作磁碟成功保證。

新增3项：相同raw重用相同immutable snapshot、其他store改草稿立刻可見／壞檔拒讀；owner切換不保留第一份snapshot、來源read故障與刪除不回舊資料；實際3MiB歷史的10次相同draft＋markRead寫入數為0，而真正草稿改變只写1次且消息保留。七份回歸229項全過；本輪唯一 flutter analyze 無問題。這是解析／無變更I/O改善，不是低RAM保證或完整分區儲存：raw來源仍需讀取，metadata路徑仍可能JSON解析，真變更仍整份寫，最多一份原raw與模型仍可能很大；大型備份clipboard與真人雙平台尚未驗收。

### 2026-10-04 續接：大型本機歷史的備份還原容量一致

檢查本機成長發現匯出無限制，匯入卻限2×1024×1024 Dart字元；因遠端可合併至20MiB payload，App 自己匯出的備份可能無法還原。改成雙向相同 UTF-8 byte 預算，預設32MiB（`maxBackupBytes`注入供測試，須正數），支援原 JSON version1／owner隔離與相同merge規則。先檢查字串長度，再計算UTF-8 bytes；超限在解析／匯入保存前或匯出交付前明確拒絕，原歷史不刪、不截斷、不自動淘汰。不新增任何永久欄位或key。

32MiB是單份備份預算，不是全archive硬上限、磁碟剩餘量、Android可用RAM或全部消息永久保存保證。匯出資料仍只有owner與conversations，不携帶 token／gap／工作／游標等runtime envelope metadata；對話自身的原欄位仍依既有merge規則。超过32MiB的本機資料仍可讀，不在此輪清理；完整／分份檔案備份與大資料記憶體策略仍需要實作核對，不能宣稱任意大小均能還原。

App匯入 TextField 移除原2Mi字元的強制裁切，完整原文交由同一 byte guard；沒有改其他 UI。匯入 controller 與匯出錯誤提示保留 archive 的明確容量理由，不把超限只顯示成一般格式錯誤。既有已提交但未保存／草稿保留／未知發送結果／不自動重送流程未改；原 SharedPreferences adapter 已檢查setString回傳false，此輪確認其存在，未更動。

新增3项：實際>2MiB的3MiB消息備份還原／重复匯入／runtime隔離，中文字／emoji UTF-8 精確邊界（等於可用、差1byte拒絕且原檔不變），App容量錯誤來源／原archive保留且不發送。七份回歸225項全過；後補App容量測試單項通過（合計226項證據，未宣稱最後版完整226重跑）；本輪唯一 flutter analyze 無問題。真人／Windows／Android剪貼簿容量和完整私訊仍未驗收，未改API/hash/token/IRC/Points/播放器。

### 2026-10-04 續接：待存缺口的成功確認與會話順序

核對發現 controller 保存成功後仍保留事件碼及時間於待存 map；換帳號再切回時，新會話碼先落盤，隨後 `_reload` 又把已存舊碼寫回，可能讓舊恢復快照重新看似有效。修正 `recordReceiveGap` 回傳保存結果：false 代表 owner／generation 已取消，true 代表已保存或同觀察已存在；讀寫失敗仍拋錯。此結果不代表 Twitch 歷史恢復、私訊送達或連線成功。

controller 在提交前擷取該次觀察；true 且目前該 owner 待存碼仍等於該次碼，才清待存碼／時間，不清最早 gap 或磁碟 metadata。若提交開始後切帳號，已完成的原 owner 磁碟寫入仍可確認，不把它顯示在新帳號；若另一新信號已更新待存碼，舊提交不能清掉新信號。false／例外保持待存供回到合法 owner 或恢復儲存後重試。沒有新增 key、欄位或 API operation，OAuth/token 不變。

新增4項測試：取消與成功／同觀察回傳分離；已確認舊gap切回後不覆寫新會話、旧工作仍失效；兩信號重疊寫入不清較新待存；寫入開始後換owner，舊寫入完成確認而不在下一會話重播。七份回歸223項全過，之後僅加強切回測試的非空草稿保存斷言，該項單獨重跑通過；本輪唯一 flutter analyze 無問題。此修正只處理 App 內序列與確認，仍無跨程序鎖／持久事件佇列／未存突然退出保證；真人與雙平台門檻不以 mock 取代。

### 2026-10-04 續接：缺口識別不依賴裝置時鐘

原 owner key／version1 不變，新增可選 archive `receiveGapObservationId` 與工作快照 `gapObservationId`，null／缺少相容舊檔；非 null 嚴格限制為32位小寫hex字串。每個真正 typed 斷線信號生成128-bit隨機識別碼，controller按 owner 保留碼與觀察時間，重試同事件沿用、不為一般載入重新生成。它不是官方訊息ID、token或加密金鑰；不送至 Twitch，不改 OAuth/token 保存。

新會話若已有前一會話亦生成新碼，不用時間變大才判新缺口。archive在同次 serialized merge保存最早gap／觀察時間／識別碼；有不同非null事件碼即視為新觀察，即使時鐘倒退或時間相同。工作續接／runner檢查同时比對識別碼與原時間快照；原時間仍可紀錄，但不單獨決定新事件。呼叫者不提供碼的舊介面保留原 timestamp 比較，App 的真正信號已接新碼。碼缺失的舊工作首次遇到新碼從頭重開，不覆寫對話資料。

同碼重试、草稿／收件／分頁／其他普通保存保留原觀察及碼；失敗不改原JSON，碼仍留記憶體供同事件重試。換owner忽略錯誤信號，clear／dispose清記憶體而不刪磁碟碼；備份仍不匯入 runtime metadata。格式不合法的磁碟碼／工作碼拒讀、不覆寫。此碼不是歷次事件日誌，無跨程序鎖、無持久事件佇列；突然退出前未保存的信號仍不能保證恢復。

新增4项 mock：時間倒退與同時間不同碼均使舊工作失效、同碼重试不再推進；新 store 同時間新會話亦有不同碼；保存失敗重試及非法碼不覆寫；App 一般刷新保留碼／每信號換碼／錯owner不動。最終七份回歸219項全過；本輪唯一 flutter analyze 無問題。上一輪「時鐘異常尚未辨識」由此次接線取代，裝置時間顯示及真人收件仍需實機驗收，不能當全部私訊／對齊完成。

### 2026-10-04 續接：新缺口不能沿用舊恢復覆蓋

原 owner archive version1 新增可選 `receiveGapObservedAt`，recovery object 新增可選 `gapObservedAt`：null／缺少相容舊檔，非 null 必須是 UTC canonical ISO8601。前者記錄最新已保存的缺口觀察時間，後者是工作開始時的快照；與 `receiveGapSince` 最早保守下界分開。普通保存保留兩者，備份不匯入執行階段 metadata，非法日期拒讀、不覆寫。

typed 斷線信號更新 controller 的 owner 隔離觀察時間，保存失敗記憶體保留、重新載入可重試；重複保存同觀察不推進時間。重開／切回既有會話亦以本次開始時間記新觀察。`beginRecovery` 僅在快照相同且工作未完時續接原頁；有新觀察則原子建立新 threads 工作，由最新本機 peer 加完整遠端列舉重新開始，不刪既有訊息／草稿／未讀／瀏覽 cursor。

runner 每頁前及返回前核對觀察快照；執行中出現新缺口，可能已保存當頁資料，但不報恢復成功，明確要求重新恢復全部對話。不自動重跑無限工作；下次手動操作從頭列舉，不跳過以前讀過的 peer。controller 啟動前先補存待存缺口，仍失敗時不發恢復請求。歷史頁耗盡的 complete 仍只是工作游標狀態，若其快照已過期，不能表示新缺口被涵蓋；gap 本輪仍不清除。

新增6項 mock：中頁／末頁新缺口、原資料保留與新 store 重啟從頭、觀察及工作保存失敗原子性、同觀察仍可續接、新會話／壞 metadata、App 真正重試 cursor 序列、未存缺口先阻擋網路。初次 App 測試誤算兩頁列表請求數，改明確核對 `[null, null, next]`，不弱化從頭條件。最終七份回歸215項全過；本輪唯一 flutter analyze 無問題。

時間戳採裝置 UTC，沒有新增持久序號或跨程序鎖；時鐘倒退／同時間不同信號的完整辨識仍需補核對。不能把此 mock 當真人 Web、Windows／Android 背景／重開已驗收，亦不宣稱原全部功能完成。未改 OAuth/token、API operation/hash、IRC、Points 或播放器。

### 2026-10-04 續接：正常退出／重開的收件會話儲存

原 `vioclass_twitch_whispers_v1_<ownerId>` key、version1 不變，新增可選 `receiveSessionStartedAt`：UTC canonical ISO8601 字串或 null／缺少。它不是 token、最後一則訊息時間或精確離線開始時間。新 App／切換回該帳號時，serialized `beginReceiveSession` 把上一會話開始時間合併至最早 `receiveGapSince`，並與本次會話時間一起保存；同 owner 一般刷新不旋轉標記。普通寫入保留標記、訊息、草稿、未讀、瀏覽 cursor 與恢復工作，換帳號仍用各自 key。

舊資料缺少標記可讀，第一次新增不推斷以前離線區間。非法型別／日期拒讀且不覆寫；失敗保留原 JSON、顯示會話未保存提示，下次同 owner 刷新可重試。取消或過期 owner 不提交該次標記。備份仍只含對話，不導入其他執行階段 metadata；沒有改既有 OAuth/token 儲存、API operation 或 hash。

上一會話開始只是保守下界，可能涵蓋其正常在線時間，因此提示改為「可能有未恢復的收件區間；連線不代表歷史已補齊。」不宣稱每則漏訊息、精確退出時刻或恢復完成；gap 不自動清除。SharedPreferences 私訊仍未加密，無跨程序鎖／斷電交易保证；未成功保存的首次標記不能保證突然退出後辨識。實機 Windows／Android 重開、真人 API、新增 gap 與未完成工作覆蓋關係仍待驗收。

新增4項測試涵蓋新 store／controller、帳號隔離、一般刷新不旋轉、其他 metadata 保留、寫入故障重試、壞日期與取消不覆寫。首次完整回歸發現兩個 fixture 尚未考慮新的啟動寫入：首次 gap 故障 fixture 改為明確移除會話欄位，避免重開標記已涵蓋 gap 而根本不需寫入；列表 commit fixture 僅於同步時阻擋，不阻擋初始會話保存。最終七份回歸209項全過；本輪唯一 flutter analyze 無問題。上一輪大括號提示已處理，未修改 OAuth/token 儲存。

### 2026-10-04 續接：遠端歷史總容量與可辨識錯誤

原列表merge已檢查500peer/20MiB，逐對話history只檢查受影響peer（10000則/4MiB）；本輪共用 `_checkRemoteAccountCapacity`，一般history與恢復history在保存前亦檢查全帳號conversations JSON UTF8大小/peer數。恢復列表在推導工作前檢查既有工作peer union，超500回明確archive容量錯誤，不把容量當壞checkpoint。超限整頁拒絕、不刪訊息/草稿、不推游標/恢復進度；原資料保留。

20MiB指conversations JSON payload，不含receiveRecovery等metadata；這是所有遠端merge的預算，不是每種本機保存/備份的硬上限。live append、草稿、匯入原規則未擴成此限制，避免未經完整發送/草稿處理設計就拒絕本機紀錄；不宣稱總archive必≤20MiB。仍需評估metadata與本機成長的總量，無自動淘汰或清理。

controller辨識TwitchWhisperArchiveException容量理由及TimeoutException，面板/選單沿原recoveryError顯示明確原因；新增recoverySyncTimeout注入參數，預設45秒不變，逾時保留原頁、晚頁不写、不自動重試。首次controller容量測試顯示generic錯誤，原因為工作peer union先被model拒絕；改archive提前回明確容量錯誤，再完整回歸。

5新測試：一般/恢復history在原約19.8MiB、單peer<4MiB時拒絕新增至>20MiB，原JSON/草稿/未讀/gap/job保持；history拒第501peer；App逾時忽略晚頁且原頁續接；App容量理由/500原peer保留且一次請求不auto retry。七份205全過；唯一analyze0errors/0warnings/1測試大括號info（recovery_test307），未再跑。上一輪controller144提示已處理。

下一步正常離線窗口與新增gap的恢復覆蓋語意、實機退出重開/timeoutUI，以及本機/metadata總容量；真人Web列表、完整收發、Android背景和其餘Twitch對齊仍未完成。沒有改token/hash/IRC/Points/播放器或真人資料。

### 2026-10-04 續接：恢復核心接到 App

controller在有threads/history API時建立同Home生命週期runner，提供recoverHistory/cancelRecovery、progress/error/status、待讀可取消與保存中標記；session讀磁碟工作，換owner/clear/dispose停止舊待讀並以generation隔離晚進度。worker結束亦通知當前畫面解除busy，不拷貝舊owner資料。啟動前有generation busy鎖，恢复期間沿既有managingHistory介面禁止其他列表/歷史同步、發送、新增/刪除/匯入/匯出操作；草稿與live收件仍保持原owner規則。成功/失敗後重新載入已保存頁。

一般及<310低高度面板新增歷史圖示選單：恢復全部對話歷史／續接、取消恢復保留進度；顯示列舉/peer進度/保存/失敗/可讀範圍完成狀態。保存中取消disabled，失敗可原頁續接；恢復結果不當完整Twitch保留範圍，gap不清。session刷新可停止工作，不因busy擋掉帳號重驗證。沒有改OAuth/token/APIoperation/hash/發送協議。

6新controller/widget測試：衝突操作阻擋+取消再恢復、等待中換owner、commit不可取消、1000×760/390×844/390×260真選單開始取消續接；擴充owner UI解除busy斷言。初次一般視窗測試因全sheet載入動畫使pumpAndSettle推fake time到45秒失敗，改有限時間逐幀處理，仍assert正在執行/取消/完工。七份最終回歸200全過。上一輪11infos已處理；本輪唯一analyze0errors/0warnings/1controller大括號info（144），未再跑。之後worker busy通知與send disabled小調整有完整回歸，未追加analyze，不宣稱最後版靜態檢查已重驗。

App入口現在已接，不再只是未接線核心；真人API/Windows/Android驗收仍未做。下一步核對整帳號容量、正常App離線窗口、新gap/工作完成覆盖關係、跨重啟可操作續接與逾時UI，不能把mock200當原目標全面完成。

### 2026-10-04 續接：全對話恢復核心與持久進度

新增 `TwitchWhisperRecoveryCheckpoint` 與 `TwitchWhisperRecoveryService`，原owner archive version1新增可選 `receiveRecovery` object：since（最早gap或無gap時1970UTC，僅記錄工作背景、不以日期截斷讀取）、phase（threads/history/complete）、peerIds（本機+所有列舉到的遠端peer）、peerIndex、cursor、visitedCursors。上限500peer／每段1000已讀cursor、cursor4096字元；嚴格驗證日期/phase/index/重複peer/游標/owner，壞metadata拒絕讀取且不覆寫。

`beginRecovery` serialized建立工作或續接未完工作；列表/歷史merge新增可選 recovery 預期checkpoint，比對磁碟工作後推導下一頁，同一 `_save` 寫入訊息+checkpoint，錯頁/循環/不同owner/已刪peer拒絕。恢復游標獨立於一般瀏覽游標，其他草稿/收件/metadata寫入保留工作進度。歷史新ID仍historicalOnly、不增加本機未讀/即時通知；遠端未讀來源維持獨立。備份不携帶receiveRecovery。

runner先列舉所有可讀thread，再逐個本機/新peer讀至其API游標耗盡；每頁45秒待讀逾時、取消釋放等待（不宣稱HTTP中止）、保存期間不可取消，owner檢查/錯誤保持最近一次已寫checkpoint，再次run原頁續接。只有可存的頁能推進；API retention/容量上限仍可能阻擋。complete僅表示該次可取得cursor耗盡，非完整Twitch保留資料/送達/已讀；目前不清receiveGapSince，沒有把新gap當已覆蓋。

8項新測試涵蓋2頁列表、原peer+2個未知peer各2頁歷史、瀏覽cursor/草稿/未讀/gap保留、新store失敗續接、列表及歷史寫入失敗原資料/進度同時不變、舊work/循環拒絕、取消晚頁、owner切換、壞metadata。七份回歸194全過；本輪唯一analyze 0errors/0warnings/11infos（tests型別2、model格式3、archive格式5、service格式1），依限制未反覆修跑。

核心本輪尚未接controller或UI，App仍只有前一輪手動單頁入口，不能聲稱已能操作全量恢復。下一步接App生命週期、進度/取消/重試、相互同步衝突與最終可讀範圍提示，再核對整帳號容量、新gap/離線窗口與真人雙平台；未新增網路operation/hash、未改token/IRC/Points/播放器。

### 續接：跨重啟的已知收件缺口

原owner archive key與version1不變，新增可選 `receiveGapSince`：null/缺少代表尚無已記錄缺口，有值為UTC canonical ISO8601字串。讀取嚴格驗證型別與日期（含拒絕日期自動進位），不合格時拒絕且不覆寫原JSON。`recordReceiveGap` serialized讀merge寫，保留最早未處理時間；`_save`的所有既有寫入保留此欄位，沒有讓單頁同步、草稿、收件、刪單一對話或匯入清掉它。備份仍只匯出對話，不匯入另一執行階段的缺口metadata。

controller收到gap signal立即記憶體提示並嘗試保存；失敗明確提示未存/退出可能遺失，後續載入重試。session取得合法owner後讀磁碟缺口，取記憶體/磁碟最早值；clearSession/dispose只清記憶體，不刪已保存缺口，所以重新登入/新store亦恢復提示。沒有新增憑證儲存、更換hash或改通知/發送協議。

3新測試覆蓋新store/新controller恢復、較晚gap不覆蓋較早、草稿/未讀/消息/對話cursor共同保留、寫入故障重試及壞型別/非法日期拒絕；原clearSession測試改為恢復磁碟標記。回歸曾卡在fake zone queue與runAsync混用：中止已卡住的測試run，將貼圖選擇器收件測試改用unawaited加pump並明確assert完成；缺口磁碟讀取集中session，無缺口時不await保存。最終六份回歸186全過。本輪唯一analyze於最後調整前回報0errors/0warnings/1大括號info（當時controller484）；後續讀取位置/等待方式調整有test證據，依一次限制未再analyze。

這只能保留「已知且成功寫入」的缺口，不保證突然退出前寫入成功，也尚未記錄所有正常App離線區間。所有peer列舉/逐對話分頁恢復、恢復任務checkpoint、取消/重試及完成判據仍待實作；目前不提供清掉缺口的虛假完成操作。

### 續接：重連與歷史恢復分開

EventSub新增可選的typed `onReceiveGap(owner)`，於主socket遺失、重試、授權失效/撤銷通知；正常server reconnect交接保留舊socket直到新welcome，不因交接本身標缺口。controller `_receiveGaps`按owner保存記憶體標記，忽略非目前owner信號；已連線status、同owner session刷新及單頁列表/歷史同步不清標記。不同owner不显示原標記，切回仍有；clearSession/dispose清除，未新增永久key/schema。此標記不跨App退出保存，不能作跨重啟缺口保證。

一般私訊面板顯示「收件曾中斷；重連不代表遺漏私訊已補齊。」並提供同步列表／目前對話歷史；低高度<310視窗以警告選單提供同入口，不增加固定高度。沿用既有read-only API、取消/逾時/原頁重試及游標保存，不自動發送、不清除標記或宣稱已補全部對話。已知owner signal測試、三種尺寸1000×760/390×844/390×260入口與同步後仍保留標記，共4新增測試；既有EventSub測試補普通掉線/撤銷/缺scope信號、正常welcome/交接無信號斷言。首次低高度找不到提示（使用另一build分支）後補警告選單，最終六份回歸183項通過；本輪一次analyze無問題，上一輪三個大括號提示已處理。

目前恢復仍是列表及選定peer逐頁手動讀取，未實作所有peer斷線區間自動补齊，也不能由单页成功判定完整。下一步核對完整恢復流程、跨退出的缺口需求及真人/裝置證據，不以入口當作功能全部完成。沒有改OAuth/token保存、GQLhash或平台runtime。

### 續接：背景收件保存故障暫存

原 receiveEvent 保存失敗僅顯示錯誤，不保留事件；新增 `_pendingIncoming` owner→官方whisper ID的記憶體暫存，含原peer、內容、時間、閱讀狀態及profile欄位。`_reload`（新收件／可觸發載入的選取／session刷新／同步）先嘗試保存待存事件；append成功才移除，讀寫失敗保留且明確提示退出可能遺失。同ID/身份/內容衝突拒絕、不以文字時間去重。同controller換owner不flush原owner，切回可補存；clearSession/dispose清記憶體，無新永久key/schema。

每owner上限500事件及512×1024 Dart字串code units的本文總量（不是bytes）；超限拒絕新事件、不逐出舊事件，提示恢復儲存後同步遠端歷史。滿容量時不能靠新事件保證自動恢復，需明確重新載入；無定時自動重試，沒有持久佇列或退出後保證。失敗事件未保存前不發通知、不增加磁碟未讀；保存時亦檢查目前是否正在讀該peer尾端。通知callback拋錯不重新排入已存事件，也不阻擋下一則。

通知優先讀已保存的最新profile，避免遲到的旧事件名稱取代最新名稱；讀取失敗才退回可用資料，不因通知讀取失敗重寫已存事件。4項新增測試涵蓋read/write故障、重複事件、換owner/切回、通知callback故障、500事件上限、待存身份衝突與clearSession。第一次完整回歸失敗於遲到profile通知名稱；依原測試要求修正，再跑六份回歸179項全過。單次analyze 0errors/0warnings/3大括號infos（測試611/616、controller125），未反覆修跑；之後僅修通知profile并回歸，未再次analyze。上一輪controller369大括號已處理。

未改token/GQLhash/IRC/Points/播放器，未新增API。這只恢復已到達App的事件，不補EventSub斷線期間未到達的私訊；後者及真人Web列表/雙向/裝置仍待驗收。

### 續接：未保存的已提交結果

controller 新增僅記憶體的 `_pendingSubmitted`，按 owner/message ID 保存 API 已接受但 archive 尚未成功寫入的結果；畫面相同 owner/peer/ID/內容覆蓋為 submitted，並標「已提交・尚未儲存」。`_reload`（含 session 刷新）在儲存恢復後嘗試 archive `saveSubmittedReceipt`：serialized 讀取目前資料，只更新原 owner→peer、原 ID/內容一致的既有訊息；缺訊息或已刪對話不重建，矛盾身份拒絕。保存成功才移除暫存；不發 API、不推進遠端游標、不清草稿。

暫存不跟另一帳號混用，同 controller 切回原 owner 可補存；`clearSession`／dispose 清除，不新增永久 key/schema。App 退出前仍未保存的結果無法保證留存，新的 store 依磁碟 sending 恢復 unconfirmed。這不是官方 message-ID 關聯、送達回執或磁碟交易保證。

擴充原2項持續故障測試：當下 submitted+未存旗標、新 store unconfirmed、換 owner 不改原磁碟、切回只補存不重發。新增3项缺訊息/刪peer/衝突拒絕測試及桌面1000×760、手機390×844兩項狀態→保存恢復畫面測試。首次畫面測試因在 fake async 建立 serialized queue、轉 runAsync 等待而卡住；中止該測試，將建立與初始 send 留在同一 runAsync，沒有重啟 App 或改真人資料。最終六份回歸175項通過；本輪單次 analyze 0errors/0warnings/1info（controller:369大括號），未反覆修跑；後續僅修測試初始化並回歸，未再 analyze。上一輪測試大括號已修正。

### 續接：持續故障警告與恢復 checkpoint

後續 archive 讀取失敗時仍保留「Twitch 已接受本次提交／勿直接重送」，不以一般保存錯誤取代。archive 首次恢復 sending→unconfirmed，改為 checkpoint 保存成功後才把 owner 加入已恢復集合；保存失敗會拒絕此次 load，下一次 load 仍重試恢復，不暴露舊 sending 作為已恢復資料。

新增3項測試：提交後持續 read/write 故障、磁碟原 sending 和草稿保留、故障解除後新 store 恢復 unconfirmed；恢復 checkpoint 首次失敗不改原 JSON、第二次 load 再保存、後續不重複寫入。六份回歸170項通過。本輪僅一次 analyze：0 errors、0 warnings、1 info（`docs/twitch_whisper_inbox_test.dart:436` 的 if 大括號），依限制未反覆修跑；下一輪處理。

以上為注入的儲存故障／新 store 模擬重啟，非真人裝置重啟。App 執行中若 submitted 始終寫不進，列表仍可能顯示舊 sending；目前以明確警告防誤重送，尚未提供持久回執或磁碟交易保證。恢復時不猜已送達，只標結果不明。沒有改 OAuth/token 儲存、GQL hash 或發送協議。

### 續接：提交結果與本機保存失敗分開

`sendActiveMessage` 在 API 接受提交後保留該結果。本機 submitted 或清空草稿的寫入失敗，不再把訊息改成 failed；維持 submitted 並提示勿直接重送，不自動重發 API。新增兩項單次寫入失敗測試，確認發送僅一次、草稿保留、恢復寫入後磁碟狀態為 submitted。六份回歸167項通過；本輪僅一次 analyze，No issues found。上一輪兩項測試大括號提示亦已修正。

這不是磁碟交易保證：持續寫入失敗時，磁碟仍可能停在 sending；既有重啟恢復會將它改為 unconfirmed。讀取也失敗時，畫面可能只顯示一般保存錯誤。持續 I/O 失敗與真人重啟仍待驗收。OAuth/token 儲存、既有 hash 與發送協議未改。

2026-10-03 查閱 [StreamNook whisper_inbox.rs](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_inbox.rs)：發送後建立本機 sent ID，歷史按 ID 合併；此次查閱的 send/history 路徑未提供可靠的官方 ID 關聯。VioClass 不以內容與時間猜配刪除，因此 local/official ID 可能重複仍明列未完成。本輪沒有新增 API/query/hash；既有新增項目與保存 key/schema 清單維持下文。

### 續接：主登入失效身份隔離

私訊API session無明確owner時，第一provider必須先建立已驗證主身份，失效/空/拋錯/不合格validation停止，不取Web/Drops建立另一身份。已知owner仍可用同owner fallback補scope／恢復；但主provider驗證到另一人時拒絕舊owner，不借舊Web繼續發。這只改私訊API token選擇，未改OAuth/token保存、更新、scope或GQLhash。

新增8項API/controller測試，六份回歸165項通過；原帳號主token失效后session停用、草稿與磁碟保留、另一帳號未載入。一次analyze 0errors、0warnings、2測試infos（336/347大括號），留下一輪，未重跑。仍缺local提交/官方ID可靠對應與真人驗收；下一輪先處理提示再查證上游send/history-ID關聯，不以文字時間猜配刪資料。

### 續接：A—F核對與匯入一致性

完整audit新增 `twitch-whisper-requirements-audit.md`。備份與raw model遇同ID不同sender/recipient/text改拒絕，不默默略過；匯入整頁memory merge之後才一次save，後段衝突亦不造成部分寫入。合法同ID發送state推進仍可用。4項新測試及六份回歸157項通過，本輪單次analyze無問題。新增確切缺口：主要provider失效的fallback身份、local outgoing與official message ID對應；不把文字/時間猜配當可靠去重。沒有新API/query/hash或token保存修改。

### 續接：單一對話歷史恢復操作

controller 新增 historySyncTimeout（預設45秒遠端讀取）、canCancelHistorySync、cancelHistorySync、retryHistorySync 與歷史專用 request serial。取消／逾時不推進原游標，重試沿用失敗時近期或更早模式；切換 peer 在待讀階段取消原請求，session刷新/clear/dispose亦釋放等待。晚頁與晚錯誤不套用新操作。保存開始後取消禁用，不宣稱底層HTTP中止；commit期間切換peer仍可能完成原peer保存，不會把該頁附到新peer。

既有歷史選單提供取消／失敗重試；同步中禁止啟動另一頁或profile操作，保存中整個選單暫停。原草稿、anchor、近期刷新保留更早游標與完成標记的行為不變。未新增query/hash、未改token保存。

新增4控制器測試（取消晚錯誤、逾時原頁重試、切換peer晚頁隔離、commit不可取消）及3尺寸選單測試。首次peer fixture直接保存第三人但controller尚未載入，測試失敗；補面板可見後選取的正常 reload 路徑，完整回歸通過。六份私訊回歸153項通過，本輪僅一次analyze無問題（exit code0）。下一輪依路線圖核對私訊A—F剩餘功能與證據，不把mock當真人遠端驗收；裝置待辦集中 `twitch-whisper-device-acceptance.md`。

### 續接：列表失敗重試、取消與逾時

controller 新增 `threadsSyncTimeout`（預設45秒、只套用遠端列表讀取）、`canCancelThreadsSync`、`cancelThreadsSync`、`retryThreadsSync`。每次列表操作有獨立 request serial；取消令當次失效並結束等待，不推進 cursor、刪除對話或清草稿。晚頁／晚錯誤不改新重試狀態。底層 read-only 網路請求未以 Dio CancelToken 中斷，結果只是被忽略，不宣稱伺服器已取消。

等待網路時可取消；remote 回來、開始 archive merge 前關閉取消入口，避免保存已開始卻宣稱原資料完全未動。刷新 session、clear及dispose亦釋放待讀等待；generation仍保護帳號。timeout／API failure顯示保留資料的錯誤，明確重試使用失敗時的more旗標與原cursor，不把「更後一頁」重試改為第一頁；不自動迴圈請求。

面板列表狀態區以 Wrap 提供取消／重試，未新增外框按鈕或改其他 UI。新增4項控制器測試（取消+晚錯誤、新重試、逾時原頁、API failure原頁及commit不可取消）及3項桌面1000×760/手機390×844/短視窗390×260入口測試；六份完整回歸146項通過，本輪單次analyze無問題（exit code0）。新增 timeout 不是全部 API 的逾時政策，單一對話history讀取尚未接這些操作，下一輪處理該缺口。沒有新增 query/hash/token 保存，也没有真人發送。

### 續接：歷史 prepend 閱讀 anchor

私訊閱讀區由 ListView 改為有穩定 center 的兩個 SliverList：本次對話開啟時的第一則訊息作為 center ID，較早資料向上延伸，後续/即時資料向下延伸；切換 owner/peer 重設，空對話首則到達時初始化。原 ScrollController、最新尾端檢查、拖曳 physics、訊息選取與發送維持。列表 semanticChildCount 和兩側 chronological semantic index 也保留，未動儲存/query。做法依 [Flutter CustomScrollView 官方 prepend 範例](https://api.flutter.dev/flutter/widgets/CustomScrollView-class.html)，不是用平均高度猜 scroll correction。

新增4項 anchor 測試：1000×760桌面／390×844手機，等高／變高歷史，每案連續三頁。第一頁保留原 live 訊息，移入負向歴史範圍後再載入兩頁仍保留同一歷史訊息；以訊息 top 相對閱讀 viewport 的位置量測，誤差≤1px。不宣稱全螢幕座標固定（status/鍵盤改變 viewport 本身時不同）；沒有新增所有字級/220px/鍵盤與 prepend 同時發生的 anchor 組合。既有鍵盤、拖曳、返回最新及換 peer/owner tests 一起回歸。

六份完整私訊回歸139項通過；本輪一次 analyze 無問題（exit code 0）。目前未驗證真人 Web GQL／平台裝置。下一輪優先列表同步 failure/retry 和取消／超時情況，整體目標未完成。

### 續接：授權後等待最新 session

本輪一次 `flutter analyze --no-pub lib/features/twitch docs`：No issues found，exit code 0。

`refreshSession()` 現在共用正在執行的 Future，不再因 loading 直接回傳已完成結果；一般重複呼叫只驗證一次。面板授權後使用 `refreshSession(afterCurrent:true)`，先等現有請求完成，再驗證授權後的新憑證，避免原請求在授權前捕捉舊 token。只有完成最新驗證且 owner 與重試開始時相同才同步。

`clearSession` 切斷舊的共享等待，使新 session 可另起刷新；generation 保護舊回應不覆蓋新帳號。失敗會釋放共用等待讓下一次可重試。刷新同帳號 archive 时疊回刷新期間尚未保存的草稿。沒有改 OAuth/token 保存、GQL query、發送或背景收件協議。

新增6項測試（4控制器、2介面）：共享等待、清 session 後晚回應、失敗後重試、授權期間 token 對應帳號變更，以及 Home callback 已啟動刷新後面板同/不同帳號重試。六份完整回歸135項通過。首次 pending UI 測試用 pumpAndSettle 等待刻意保持的 loading 動畫而超時，改為有界 pump 驗證等待中狀態後再放行，完整回歸通過。真人 GQL／裝置驗收仍未完成；下一輪優先私訊歷史分頁閱讀 anchor 與列表錯誤恢復，不以 mock 宣告整體完成。

### 續接：私訊授權入口不走 Drops

本輪單次 `flutter analyze --no-pub lib/features/twitch docs` 無問題，exit code 0。

Home 的私訊 callback 改呼叫 `runWhisperAuthorizationFlow`，經新 `twitch_whisper_authorization.dart` factory 建立既有 OAuth WebView 頁；main/Web dependencies 原樣傳入，captureWebGqlToken=true、mirrorMainTokenToInteraction=false、interactionAuthService=null。只改私訊入口路由，不改 token 保存、OAuth scopes、平台 WebView runtime 或一般完整登入的 Drops 流程。

列表選單加入「授權並重試對話同步」。先 flush 草稿，授權後 refresh session；成功且 owner 未變且面板仍開啟才同步。授權失敗或關閉不重試；換帳號不自動同步新帳號；同步中禁止啟動授權。沒有自動發送訊息。callback 完成仍不代表 Web GQL 能用，實際 retry 的 Web validation／query 仍可能報錯。

5項新測試（1頁面設定、4介面成功/失敗/換帳號/關閉），六份私訊回歸129項通過。首次 fixture 錯用 single 讀取成功新增對話的列表而失敗，改以 peer ID 查草稿後完整重跑通過。未測真實 WebView 授權或伺服器列表。集中真人清單見 `twitch-whisper-device-acceptance.md`；下一輪檢查 Home 登入刷新与面板 session 刷新的並行等待，避免測試只覆蓋即時 callback。

### 續接：歷史與背景收件競態

新增 message JSON 欄位 `historicalOnly`，遠端列表 preview／對話歷史新建訊息保存為 true；既有即時訊息合併同 ID 不退回歷史狀態。第一次收到同 ID 的 EventSub 時由 true 轉為 false，依現有面板閱讀狀態處理一次本機未讀／通知與 live-receipt flag；後續重送去重。來源 ID 的參與者或內容衝突拒絕，不覆蓋既有訊息。舊 JSON 缺欄位預設 false（保守維持舊去重，不猜舊收件是否歷史）；錯欄位型別阻止讀取，不自動清空。

controller 的歷史 ID cache 改由已保存訊息來源重建，刷新 session／reload 後依然正確；不再把同步回應中的所有 ID 都標為歷史，避免把先到的 live 訊息重新排除。cache 為目前已載入 archive 的索引，不另寫一份獨立的無界通知紀錄。

新增4項測試：歷史先到後即時收件／重送／重開、即時先到再同步、舊 JSON 相容與錯型別、同步等待期間背景收件及草稿競態。完整五份私訊回歸121項通過。首次回歸發現順手改動 profile avatar 的處理違反既有行為，該改動已撤回，保留原本獨立 avatar 刷新；再完整回歸通過。本輪未新增 API／query／hash，未改 token 保存。

真人 Web GQL 列表成功、雙裝置實際收發及最終驗收仍待完成；mock 不能證明遠端服務可用。

本輪只執行一次 `flutter analyze --no-pub lib/features/twitch docs`：No issues found，exit code 0。上轮 controller 大括號提示已修正。

私訊列表的「本機私訊歷史」選單已加入「同步 Twitch 對話／載入更多對話」。同步為手動觸發，不自動傳送私訊；不宣稱真人登入後的列表 API 已成功。

- 控制器先保存草稿，捕捉 owner/generation，再請求、合併與重讀；晚到的其他 session 回應不套用。列表同步與訊息歷史同步、刪除、匯入互斥，不阻止草稿輸入。
- 保存鍵仍是 `vioclass_twitch_whispers_v1_<ownerId>`；同一 owner 的對話與列表 cursor/completion 放在同一 JSON，序列化佇列保護程序內寫入。一頁合併只呼叫一次既有保存 adapter，不拆成資料與 cursor 兩次寫入；失敗不推進進度。這不是跨程序交易或斷電安全保證。
- session 讀回列表進度，「載入更多」續接保存 cursor；明確「同步 Twitch 對話」重新從第一頁開始並更新列表進度，避免舊完成標記阻止新對話分頁。單一對話近期歷史刷新仍保留較早歷史 cursor，兩種進度不混用。
- 若同步開始後已有較新 `profileObservedAt`，保留較新名字、login 與頭像；本機草稿/未讀及即時收件合併保留。列表 preview 不發新收件通知、不改 live-receipt flag。
- 面板顯示 `remoteUnreadCount` 為「Twitch 未讀（上次同步）」；本機 badge 仍只使用本機未讀，開啟本機對話不宣稱遠端標讀。
- 既有 SharedPreferences JSON **未新增加密**，不保存 OAuth 憑證。備份含私人內容；此輪沒有新增跨程序鎖、磁碟回滾或自動刪除資料。
- 新3項 controller/storage及3項 UI 測試；五份私訊回歸共 **117項通過**。短視窗測試首次因未捲動找不到 lazy list 項目失敗，補捲動及回到選單操作後完整通過。
- 本輪僅一次 analyze：**0 errors、0 warnings、1 info**，controller:718 大括號建議，未重跑。下一輪先處理提示，再驗證登入後列表/分頁與 Windows、Android 實際資料。117項皆 mock，沒有向真人發訊息。下方為歷次紀錄，早期「尚未接入」不是最新狀態。

## 已新增：單一已知對話歷史

- 檔案：`lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart`
- API：`TwitchWhisperHistoryApiService.page(ownerId, peerId, cursor)`，唯讀 POST `https://gql.twitch.tv/gql`。
- operation：`Whispers_Thread_WhisperThread`
- persisted hash：`c11d356f7e2d8a2b7da3f90c11487414b7fb188649bafe331e93937a5da2310d`
- variables：`id`（兩個 user ID 字串排序後以底線連接）、可選 `cursor`。
- 授權：注入既有 Web token provider，先官方 validate；只接受 owner 相同且 Client-ID 等於 Twitch Web Client-ID 的 token。GQL 使用 `Authorization: OAuth`；不借另一帳號、主 App Client-ID 或 Android Client-ID，不儲存／修改 token。
- 來源核對：[StreamNook history service](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_history_service.rs)。此為私有 API，格式/hash 可變，真人請求尚未驗收。
- 不提供未知 peer 的對話發現；[StreamNook inbox refresh](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_inbox.rs) 也是對本機已知 peer 逐一刷新。完整遠端列表仍需另行查證與實作，不能只新增這支查詢就稱完整同步。

## 新增儲存

- 模型：`lib/features/twitch/models/chat/twitch_whisper_remote_history.dart`；owner、peer、不可變訊息列表、requestedCursor、nextCursor。
- 對話模型新增 `remoteHistoryCursor`、`remoteHistoryComplete`；舊資料缺欄位時為 null／false。已完成不可同時保存非空 cursor，游標上限4096字元。
- 沿用帳號隔離的 `vioclass_twitch_whispers_v1_<ownerId>`，不另存 token。`TwitchWhisperArchiveStore.mergeRemotePage` 在同一 serialized queue 中讀取、驗證、合併並一次保存訊息與 checkpoint，避免寫入失敗卻提前翻頁。
- 同 ID 去重並保留原本 state；不同 sender／recipient／text 的同 ID 衝突拒絕整頁。錯帳號、錯 peer、過期 cursor 不寫入。
- 合併保留草稿、未讀、現有 profile 與 live-receipt flag；歷史資料不發通知，也不提升 live 收件解鎖狀態。歷史 outgoing 僅表示 Twitch 資料存在，不宣稱已送達／已讀。
- 遠端合併後單一對話最多10000則、4MiB UTF-8。超限拒絕整頁，原資料保持；不自動刪除舊訊息。此上限目前針對遠端合併，不是全部既有寫入路徑或所有帳號總容量保證。
- 損壞 archive 阻止合併；write 失敗不改已保存的 cursor／草稿。尚未實作完整備份／migration rollback／跨程序鎖，也未接 controller 或面板同步入口。

## 驗證與續接

新增8項 parser/API/header/account/merge/checkpoint/compatibility 測試；連同 inbox/API/EventSub 共95項通過。全部是 mock，沒有使用帳號向真人私訊。

本輪一次 analyze：0 errors、1 warning（MOD 測試 setMockInitialValues 位於 docs 而非標準 test 目錄）及4 infos（新 API 大括號），未重跑。下一輪處理這些提示、接同步 controller 與可見入口，再核對遠端對話 discovery；真人 Windows／Android 與 API 成功仍待驗收。

## 續接：控制器與面板已接入

`TwitchWhisperInboxController` 新增可選 historyApi 及 `syncActiveHistory(older)`；Home 注入僅 `webGqlAuthService.getToken`，不混主／Android token。對話的歷史選單提供近期刷新及更早一頁；歷史已讀到底時禁止繼續更早請求。近期刷新保留原有更早 checkpoint／完成狀態，不讓刷新把分頁位置倒退。

先flush草稿、捕捉owner/generation，再請求及原子merge；archive queue內再核對canApply，帳號變更晚回應不合併。reload保留同步期間尚未持久化的草稿；archive合併保持即時收件。同步期間不允許刪除對話或匯入備份，以免晚頁重新建立被刪對話；不阻止正常草稿輸入。錯誤與狀態按peer保存，不當作新私訊通知。

新增4項controller測試；連同原回歸99項通過。曾因通知函式參數名稱不符導致測試編譯失敗，已修正後完整重跑通過。本輪一次analyze 0 errors、0 warnings、2 infos（controller大括號），依規則留下一輪。前輪API大括號及MOD測試提示已處理。

尚需history-enabled面板尺寸／點擊／更早頁閱讀位置测试與真人Web授權API驗收；現有尺寸回歸的fixture沒有historyApi，不能宣稱新增選單在所有尺寸皆驗收。遠端未知peer discovery仍未接，不宣稱所有Twitch對話已同步。

## 續接：history-enabled UI 驗證

新增5項widget測試：1000×760桌面、390×844直向、390×260緊湊版的近期/更早選單操作；錯誤提示與草稿保留、緊湊版profile入口；閱讀非底部時合併歷史不跳底、不增加新私訊提示。緊湊版profile收進歷史選單以維持按鈕數量。controller記住本session已合併歷史ID（最多10000），UI不把這些舊訊息當新收件；換session清除標記。

四份私訊完整回歸104項通過，單次analyze無問題。閱讀測試證明非底部pixels位置不拉回底部，不等於prepend後同一可見訊息的精確anchor已驗收；未涵蓋所有字級/220寬/键盤組合。真人GQL與未知peer列表仍未完成。公開搜尋未找到可靠的對話列表hash來源，不猜造hash。

## 新增：遠端對話列表 API

- 檔案：`lib/features/twitch/api/chat/twitch_whisper_threads_api_service.dart`。
- API：`TwitchWhisperThreadsApiService.page(ownerId, cursor)`。
- operation：`VioClassWhisperInbox`；完整唯讀 `query` 放在該檔 `query` 常數。**沒有新增或替換列表 persisted hash**。
- 路徑：`currentUser.id`、`currentUser.whisperThreads(first:20, after:$after)`；edges cursor/thread ID、participants ID/login/name/avatar、lastMessage、unreadMessagesCount、pageInfo.hasNextPage。變數型別 Cursor，header沿用history.webSession的同owner Web驗證及OAuth token。
- 直接對Twitch做兩次**不带token**的只讀schema驗證：精簡列表和上述完整欄位查詢皆回 `data.currentUser:null` 且沒有GraphQL errors。這是欄位查詢接受的證據，不是已登入列表成功。introspection則回 `GraphQL introspection is disabled`，未繞過身份驗證。
- 上游核對：`WhispersWidget.tsx`刷新已知peer，`WhisperImportWizard.tsx`呼叫`scrape_whispers`取得未知對話；不能說StreamNook僅靠history hash就完整發現列表。本API為独立實作，不複製上游程式碼。
- parser要求currentUser ID等於owner、每個thread恰有owner及不同peer、thread key相符、有效preview sender、cursor前進及bool pageInfo。未登入/null/error不當作空列表；真空列表則保留本機對話。

## 列表新增儲存

- `TwitchWhisperThreadsPage`包含owner、對話metadata/preview及requested/next cursor。
- conversation新增`remoteUnreadCount`（舊資料預設0），與本機unread分開；不把遠端讀取當live收件，也不宣稱已在Twitch標讀。UI尚未顯示這個額外欄位。
- 同一v1 owner archive新增`remoteThreadsCursor`與`remoteThreadsComplete`。`mergeThreadsPage`一次保存合併對話與列表checkpoint；既有草稿/即時收件/標讀等write也保留列表metadata。舊archive缺欄位兼容，錯型別/完成卻有cursor拒絕讀取，不覆寫。
- 重複preview按官方ID去重，同ID内容/參與者衝突拒絕；保留本機draft/unread、history cursor和live-receipt flag。列表空頁不刪對話。fresh refresh可保留既有分頁checkpoint。
- 此合併限制500個對話、每個10000則/4MiB及owner對話內容20MiB；超限拒絕整頁，不自動丟棄原資料。限遠端列表合併路徑，非全部既有寫入容量保證。
- 新7項API/parser/account/merge/checkpoint/failure測試，連同完整私訊回歸111項通過。一次analyze 0 errors、0 warnings、6大括號infos，下一輪處理。**列表尚未接controller/UI，真人Web登入列表仍待驗收**。後續需補晚帳號切換、與live profile更新競態及可見入口，不宣稱完整私聊已完成。
