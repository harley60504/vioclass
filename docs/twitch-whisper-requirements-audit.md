# 私訊 A—F 要求與證據核對

## 2026-10-04 最新：取得並套用列表 persisted request

使用者提供的 Network payload 確認列表 operation、空字串首 cursor 與 hash `b9535d107dc5b016645d2ef895c295e8001df6ff89ca26231599e0d11b2a5927`；App 已改為同一個 batch request。這是請求層的直接證據，仍需登入後真人同步確認 response 能寫入本機對話。

日期：2026-10-03。依 `twitch-feature-roadmap.md` 的原始六單元核對，保持完整範圍。以下是程式／mock 證據，不等於 Twitch 真人服務或裝置驗收。此次直接讀取對應模型、archive、controller、API、EventSub、Home接線、入口與測試；未掃描整個 repo 或讀平台／生成資料夾。

| 原要求 | 已存在的直接證據 | 尚缺／不可宣稱 |
| --- | --- | --- |
| A 帳號隔離、重啟、草稿、損壞、去重 | `twitch_whisper_conversation.dart`、`twitch_whisper_archive_store.dart`；按 owner key、serialized merge、錯檔不覆寫；inbox/threads/history 回歸 | SharedPreferences 私訊未加密、無跨程序鎖或斷電交易保證；本次補匯入同 ID 衝突，真實重啟待測 |
| B 真正列表、双向UI、導航、空載入錯誤 | `twitch_whisper_threads_api_service.dart`、`twitch_whisper_sheet.dart`、Home 01_color接線；未知 peer mock、桌面双欄、手機返回、閱讀anchor | raw GQL 僅證明未授權 schema 接受，真人登入列表成功未證明；local outgoing 與 remote outgoing 尚未可靠對應 |
| C 官方發送、搜尋、失敗/重試 | `twitch_whisper_api_service.dart` send/session/findUser；controller 發送中/已提交/失敗/結果不明、草稿保留；API/inbox 回歸 | 官方204可能丟棄、無回傳message ID，對方收件/電話驗證待真人；另需核對主要provider驗證失敗時的跨provider帳號選擇，不把一般同owner測試當全部失效情境 |
| D 背景收件/重連/撤銷/釋放 | `twitch_whisper_eventsub_service.dart` app-owned start/stop/watchdog/backoff/handoff；Home持有controller，不隨私訊面板銷毀；EventSub 回歸 | Android OS背景限制、App完整退出後收件沒有證據；斷線期間不自動補齊，不宣稱連線持續接收 |
| E 未讀/通知/徽標/本機已讀 | controller readingLatest/panelVisible/foreground；Home callback、launcher、toolbar badge；歷史→live提升及通知路由回歸 | 入口及 Android system/Windows內部通知真人未測；Twitch遠端未讀為上次同步，並未遠端標讀 |
| F 遠端歷史/匯入/清理/端到端 | history/threads page與cursor保存、取消/45秒待讀逾時/原頁重試；同owner備份、刪本機確認；分頁/草稿/anchor回歸 | 無完整Twitch歷史保證、沒有真人端到端；本機刪除不刪遠端；匯入衝突修正須納入回歸 |

## 本輪確定修正

匯入相同 ID 卻不同 sender/recipient/text 原先直接忽略；改為拒絕整份匯入，不寫入先前已合併到記憶體的其他 peer。單一 JSON 中同 ID 的不同內容原先經模型被默默去重；模型亦改拒絕矛盾資料。合法同 ID 狀態推進（sending→submitted）仍去重，不改發送協議。

新增4項測試，六份私訊回歸157項通過；本輪單次 analyze 無問題。沒有真人私訊、封鎖、清除聊天室或改token保存。

## 下一個實作／驗證缺口

### 2026-10-04 實際 Twitch Web 對話列表回應已取得

B：使用者提供的 `currentUser.whisperThreads` 真實回應確認列表 operation 為 `Whispers_Whispers_UserWhisperThreads`，資料在 `node.messages.edges`，首 edge cursor 為空合法；修正 raw query/parser 並新增形狀測試，27 項 threads 測試全過。這比舊自訂 operation 的 mock 證據更直接，但仍沒有原始 request 的完整 query/hash，也未證明 App 的 Web token 可再次成功呼叫。真人列表與端到端仍待在 App 中重試。

本輪另將列表分頁變數改為 Twitch Web 常見的 `cursor`，並保留 GQL 第一筆 `errors[].message` 到私訊錯誤。這只改善請求形狀與診斷，不涉及 OAuth/token 儲存或既有歷史 persisted hash；需由實機重新同步取得實際錯誤才能判定剩餘阻礙。

### 2026-10-04 私訊刪除提交的帳號生命週期

A/F：新測試確實重現等草稿保存時登出仍刪舊對話。新增 controller generation/owner 檢查與 archive 排隊／讀後 write前 canApply，false取消與true保存分離；已開始write不假取消。三個archive階段測試與controller取消／切帳號晚成功晚失敗共6新測試，保留新帳號草稿與期間收件。未改token/schema或真人資料；具體契約見私訊清單。下一步核對草稿保存／刷新owner-generation競態，不把此生命周期當官方列表／可靠送出ID／兩平台實機已完成。

### 2026-10-04 回到私訊：刪除前待存收件復活已修

F/D：新增故障測試證明成功刪除後旧待存收件會被 _reload 補回，修正 owner/peer 暫停補存、成功提交才移除刪除開始時的原事件物件；失敗保留、期間新 ID 和其他 peer 保留。flush 舊快照逐筆 identity 校驗，barrier token 隔離舊 finally。2新 mock 與七份257項全過，唯一analyze無問題；契約詳 API/storage 清單。無新永久保存、API/hash/token 或真人動作。這不解決從未到達App的收件或 local/official ID 映射；重新讀上游send路徑仍只有本機ID。下一步同owner／跨owner生命週期與原真人服務／兩平台門檻，不以此次清理修正宣告私訊完成。

### 2026-10-04 本機清理儲存失敗與新收件

F：刪除已保存／後續列表讀失敗不再合併成一般儲存失敗，成功即先移除當前owner可見目標；寫失敗仍保留原資料並可重試。3新測試驗write失敗原JSON相同、read失敗已刪結果明示／恢復載入，以及刪除write gate內才排入同peer／其他peer收件各一筆與其他草稿保留。新收件可重建對話，不代表刪除是封鎖；既有待存收件與跨程序／斷電保證未擴充。七份252項全過，唯一 analyze 無問題；無真人／實機操作，原未驗收門檻不變。

### 2026-10-04 精簡版刪除入口與帳號確認邊界

F：補精簡版本機刪除入口，不額外增加header按鈕；共用對話選單的profile與條件history項。原刪除確認未固定owner，已補確認後比對；舊選單亦比對建構時owner。可捲動確認保留本機／遠端範圍及不可復原說明。4新widget測試使用390×260字級1.4、假帳號1／9同peer2：取消不改disk、確認刪原owner並讀回空列表、確認中／選單中換owner不動兩邊資料；没有發送。七份249项全過，唯一 analyze 無問題。原profile操作測試仍核對精確ID與草稿，入口改選單；不是實機或真人刪除驗收，也未承諾後續新收件不會重新建立對話。

### 2026-10-04 精簡版共用錯誤回饋

B／C／F：原精簡版未渲染 errorText，與一般版不同；新增標題區「私訊發生問題（點此查看）」及可捲動詳情框，不增加header高度。3項實際面板測試驗已知發送失敗、草稿保留／不重送、低高度大字／鍵盤下完整錯誤、損壞archive不覆寫。七份245項通過，本輪唯一 analyze 無問題。此輪使用假 API 與記憶體disk，沒有真人操作；沒有更改錯誤分類、儲存契約或 token，原真人／裝置及 ID 關聯缺口保留。

### 2026-10-04 列表搜尋／排序與篩選時收件

B／E：桌面與手機各一項實際面板操作測試，核對最近／名字／本機未讀排序、名稱搜尋、trim／不分大小寫、無結果、背景收件及清除篩選後復原。搜尋不選取對話、不清未讀、不發送；篩選時收到一則訊息，總未讀由4變5，原3個對話保留，未讀相同則依新訊息時間排序。找到並修正「搜尋沒有結果」被寫成「沒有歷史」的文案。七份242項全部通過，唯一 analyze 無問題；没有真人資料、實機驗收或新的保存契約，其他原驗收門檻未變。

### 2026-10-04 匯入新對話不導入遠端進度

F 的新 peer 匯入原會沿用另一備份的遠端未讀、cursor 與 complete，現改 0／null／false；人物／草稿／訊息保留，已有 peer 保留自己的同步進度。2新測試在修正前確實失敗，修後含寫入失敗原檔不變、新 store 還原、重新同步與再匯入不覆蓋新游標；七份240項全過，唯一 analyze 無問題。不是真人遠端歷史驗收，也未解送出 ID 可靠關聯；欄位相容與不遷移舊 archive 詳見儲存清單。

### 2026-10-04 匯入歴史不冒充live提示

重新查官方204/收件事件及StreamNook本機sent ID路徑，仍無可靠送出ID關聯證據，來源列儲存清單；不猜文字時間刪資料。核對另發現backup新ID historicalOnly=false造成面板假新訊息，改新匯入historyOnly=true、原live不退；同ID首次live提升沒有count變動原會漏面板提示，新增上一幀歷史ID識別，未讀／提示均一次，閱讀anchor保留。3新測試（雙尺寸widget＋重啟／同文不同IDoutgoing），最終結果見清單。關聯、真人API和雙平台仍未完成，不把保留兩筆冒充已消除重複；沒有新增API／token保存／真人動作。

### 2026-10-04 鍵盤／放大字級／低高度的真歷史閱讀

擴原4項history anchor測試為10項（新增6）：1000×760、390×844、320×640/keyboard250/scale1.3、844×390/keyboard220、390×260/scale1.4，各等高與變高訊息。每項走真歷史選單3頁，量同一可見anchor相對viewport位移≤1px；歷史不產新私訊提示。追加live收件確認未讀1、readingLatest=false且原anchor未換，點返回最新才變已讀0、提示消失，composer在鍵盤上方。

新矩陣發現320手機keyboard/scale1.3的155px溢位：general chrome在初始sheet高度已占掉過多conversation空間，不只是鍵盤動畫；僅縮放310閾值仍失敗，最終緊湊閾值改為400px×textScaler（最低400），亦核對立即可用viewport去鍵盤高度，PopScope的雙欄判斷共用useCompact。另發現低橫向收到live後固定新訊息button擠掉scroll區，compact改同訊息Stack內提示，不偷高度；一般版仍原位置，不改發送／儲存／API。最終七份回歸235項全過；本輪唯一flutter analyze無問題。

這是本輪實際UI問題修正，不是任意視窗／字級／實機鍵盤保證；真人Web列表、可靠local與官方送出ID、Windows／Android收發／背景仍無證據，完整目標不宣告完成。其餘Twitch工作包仍保留路線圖，不跳回MOD掩蓋私訊缺口。

### 2026-10-04 大量資料的重讀／無變更I/O

單一owner已驗證snapshot重用（每次仍讀source、相同raw才用），同草稿／已讀0不寫整份archive。3新增mock包含外部store變更、壞檔／read失敗／刪除、owner切換、不可變性、3MiB連續20次無變更零寫入；首次sending恢復仍原規則。不是完整分區儲存或手機低RAM證據。A—F重查仍有真人Web列表／完整双向／Android背景／可靠local與官方送出ID、完整低高度鍵盤prepend組合；詳細真實限制留清單，不以cache当原目標完成。

### 2026-10-04 大型歷史備份容量不一致修正

F檢查找到export無限／import2Mi字元造成自產大型備份無法restore；改雙向32MiB UTF-8同預算，byte邊界嚴格、超限原資料不寫不刪，UI輸入不裁切並保留錯誤原因。3新 mock，含實際3MiB restore。仍無任意大小／低記憶體／跨平台剪貼簿保證，需分份／檔案與記憶體方案；完整真人私訊及其餘要求未完成，不擴token或平台範圍。

### 2026-10-04 待存觀察的確認順序

修正已保存舊事件仍待存、換owner返回覆寫新會話的實際程式路徑；archive false取消／true已存分離，controller只確認同碼、不清較新信號、提交後換owner不重播舊碼。4新增回歸，詳細儲存契約見清單。沒有清 gap／改憑證／新API，實機與真人仍未測；本機資料及metadata成長／容量故障全流程和原完整目標尚需證據。

### 2026-10-04 時鐘異常的缺口識別

archive receiveGapObservationId／工作 gapObservationId 區別事件，不以時間先後判 App 新斷線；同事件重試碼保留、重開相同時間仍失效舊工作，錯 owner 不變。4新增 mock 覆蓋倒退／同時間、重试、保存故障與壞碼，詳見儲存清單。上一輪單靠時間的限制已補程式路徑；未保存突退出／跨程序仍無保證，待存事件跨會話及真人雙平台依然待核對，A—F 全完成未證明。

### 2026-10-04 新缺口的工作覆蓋

新增最新觀察及工作快照持久欄位；新 gap／重開會話後不續接已讀 peer 的舊工作，從 threads 重新列舉。執行中／末頁新 gap 顯示需重跑而非成功，缺口未存先阻擋恢復請求，原資料仍在。6新增 mock，契約與最終結果列 twitch-whisper-api-storage.md。仍不清 gap／不保證 Twitch 全保留；時鐘異常、真人 API、Windows／Android 與本機总容量需要證據，不能宣稱 A—F 全完成。

### 2026-10-04 正常重開的保守離線紀錄

owner archive 可選 receiveSessionStartedAt 與最早 gap 合併保存，正常退出不用等 socket 掉線才留下下一次可辨識的會話標記；同 owner 刷新不旋轉，切回／新 controller 恢復可能缺口，寫入失敗保持原檔並可重試。詳細 schema、未加密／無跨程序鎖／斷電保證等限制列於 twitch-whisper-api-storage.md。新增4項 mock，非 Windows／Android 實際退出證據。第一次舊 archive 沒標記不能追溯，新 gap／工作覆蓋關係仍未處理，不以此宣稱 A／D／F 全數完成。

### 2026-10-04 遠端全帳號容量核對

補historymerge原未套500peer/20MiB帳號conversations payload預算；一般/恢復history與列表共用檢查，超限拒頁且進度不動。恢復peer union先以archive錯誤回容量原因；controller保留容量/逾時文案、45秒預設與原頁續接。5新測試、七份205全過；一次analyze0errors/0warnings/1測試大括號info（307），未再跑。

此預算不含metadata、亦未擴到live/草稿/匯入全寫入，不能聲稱全archive硬限制。總metadata/本機成長策略仍待核對；不能未驗證就拒本機發送後紀錄或默默刪歷史。必要剩餘還有正常App離線窗口/新增gap覆盖、真人重啟/timeoutUI/Web與雙平台及原其餘功能。依此續接，不把容量mock當整體完成。

### 2026-10-04 App恢復流程接線

同Home controller建立runner、恢復進度／取消／失敗續接及磁碟工作載入；一般/低高度選單可操作全peer恢復。busy鎖阻擋衝突同步/發送/新增/歷史管理，換owner/clear/dispose釋放待讀、晚頁隔離；commit禁止取消，結束刷新當前owner的busy UI但不傳舊資料。6新測試（3尺寸真menu＋controller衝突/換owner/commit）、七份200全過。唯一analyze0errors/0warnings/1info（controller144）；最後busy通知/send disabled微調後只完整test未再analyze。

上一輪「核心未接App」缺口已處理，但仍不是全私訊完成。原D/F必要剩餘：總帳號歷史容量驗證、正常App離線窗口、恢復期間新增gap的覆蓋/完成語意、實機重啟續接與timeout UI、真人Web/雙向/Android背景。完整恢復仍讀到API頁耗盡且保留gap，不做虛假complete清除。可靠local/official ID與其餘Twitch對齊也保持未完成。

### 2026-10-04 全peer恢復核心：已處理與尚未接線

新增持久receiveRecovery工作與runner：全thread列舉、本機+未知peer逐頁到cursor耗盡；每頁訊息和工作checkpoint同一次寫入、預期work/游標循環/owner驗證，取消只於網路等待、45秒timeout、原頁續接。恢復不動一般瀏覽cursor、不增加本機即時未讀、保留gap。8新測試、七份回歸194全過，唯一analyze0errors/0warnings/11infos，未再跑。

沒有接controller/UI，因此此輪只證明核心/mock，不能替代原要求B/D/F的可用App流程。下一步接完整工作進度／取消／重試及其他操作鎖定，再核對timeout/保存中不可取消/跨owner生命周期組合、總容量及新gap覆蓋。正常離線窗口、可靠local/official ID、真人Web/API/裝置仍缺；complete是當次可取得API頁耗盡而非完整Twitch保留範圍，不能直接清gap。

### 已知缺口跨重啟：本輪已處理的範圍

archive version1 optional receiveGapSince記錄最早UTC已知缺口，serialized/owner隔離，其他保存保留，非法型別/日期拒絕且不覆寫；clearSession不清磁碟metadata。controller session恢復提示，寫入失敗於載入重試，非每則事件重讀gap。3新測試、clearSession範圍更新、六份回歸186全過。唯一analyze於最後調整前0errors/0warnings/1info（舊controller484）；後續缺口讀取位置/測試等待改動未再analyze，未聲稱最後版本重新靜態檢查通過。

跨重啟的已保存已知gap已處理，仍不等於離線完整恢復。下一階段依序實作：所有遠端thread列舉与獨立恢復cursor；固定該次gap/上界與逐peer歷史頁；每頁訊息與工作checkpoint同一次保存；取消/錯頁/owner變更/失敗後續接；新gap與執行中任務並存不被完成覆蓋；未讀保持本機/遠端來源區別。還需處理正常App离線窗口，不能只依已知掉線。缺口完成清除須有上述覆蓋證據，不用一次列表或一頁history成功判完整。

### 斷線提示與恢復入口：本輪已處理的範圍

EventSub typed owner信號記錄主連線遺失/重試/撤銷，正常server交接不誤報；controller owner缺口标記不被已連線或單頁同步清掉。一般視窗直接提示及同步列表/目前peer歷史按鈕，<310低高度用警告選單。4新controller/尺寸測試與EventSub既有斷言擴充，六份回歸183全過；一次analyze無問題。

這不是完整恢復：標記僅記憶體、clear/退出消失，恢復仍是手動列表/peer分頁，無所有peer斷線區間自動补齐或完整性證據。原要求D/F與真人列表雙向仍未完成。下一步先對照完整恢復需要的owner checkpoint、對話列舉、逐peer歷史邊界/取消/重試、未讀語意及跨退出範圍，不能因提示/入口存在而縮小原目標。

### 背景收件保存失敗：本輪已處理的範圍

receiveEvent原先失敗不保留事件；現在按owner/whisper ID暫存，重新載入先補存，成功後移除。避免重複未讀／通知、另一owner不補存原owner，clear/dispose丟記憶體但不刪磁碟。通知callback拋錯不阻擋收件；沿用已保存最新profile，不讓遲到舊事件改通知名。每owner500事件/512Ki本文codeunits上限，超出明確要求歷史恢復；無持久佇列、無定時retry。

4項新增測試、六份回歸179項通過（首次profile通知回歸失敗已修正）。一次analyze 0errors/0warnings/3大括號infos（test611/616、controller125），通知profile修正後未再analyze。仍不能恢復從未到達App的斷線事件；容量滿時要手動重新載入，歷史成功也未保證所有遺失事件。下一步核對EventSub斷線/重連是否讓使用者知道需補歷史，並清楚呈現恢復入口；不把本機暫存當斷線完整補齊。

### 未保存的提交結果：本輪已處理的範圍

controller 以 owner→message ID 暫存已接受結果，原訊息顯示 submitted+尚未儲存；儲存恢復後 serialized 條件更新原訊息，缺失不重建、身份/內容衝突拒絕。同 controller 換 owner 不補存原owner，切回可保存；clearSession/dispose 清除暫存。擴充2項故障測試，新增3項條件保存與2項桌面/手機畫面測試，六份回歸175項通過。一次 analyze 0errors/0warnings/1 controller大括號 info（369），未再跑。

執行中的舊 sending 展示已處理；退出前未保存仍依磁碟恢復結果不明，不能宣稱永久回執。接續核對背景收件斷線／保存失敗的恢復證據與 A—F 剩餘缺口；真人Web列表、完整收發、Android背景、可靠官方ID關聯仍未完成，不轉回 MOD 規避私訊缺口。

### 持續儲存故障：本輪已處理的範圍

提交後 read/write 持續失敗仍保留已接受提交／勿重送警告。首次恢復 sending→unconfirmed 的 checkpoint 保存失敗不再提前記錄 owner 已恢復；下一次 load 重試，原資料不被失敗寫入清空。新增3測試，六份回歸170項通過；單次 analyze 0 errors/0 warnings/1 info（inbox_test:436 大括號），未反覆修跑。

仍有明確缺口：執行中磁碟舊 sending 可能留在列表，需把記憶體中確知的 submitted 與磁碟故障分開展示且不宣稱持久化；真實裝置重啟、可靠官方 ID 關聯、雙向真人收發仍未驗收。後續優先檢查暫存回執的同 owner/peer 隔離、讀取恢復後合併與退出後不確定性，不用文字時間猜配。

### 提交成功後保存失敗：本輪已處理的範圍

API 已接受提交後，submitted 或清空草稿的保存失敗不再被標成 failed，也不自動重送。兩項一次性寫入故障測試確認僅呼叫發送一次、草稿保持、恢復保存後 submitted；六份回歸167項通過，單次 analyze 無問題。持續磁碟寫入失敗仍可能留下 sending，重啟既有恢復轉 unconfirmed；持續讀取失敗可能覆蓋具體提示，未宣稱完整磁碟故障恢復。

此次查閱 [StreamNook 的私訊合併與發送](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_inbox.rs)，亦使用本機 sent ID、按 ID 合併，沒有在查閱路徑找到官方 ID 關聯。下列第2項仍未完成，不猜文字或時間刪資料。沒有新增 API/hash 或改 OAuth/token 保存。

### 主登入失效身份：本輪已處理的範圍

`session()` 無明確owner時，第一個provider為主登入；token缺少、validate失敗、provider拋錯或缺有效ID/client時，不再讓次要provider建立新身份。已验证主身份但scope不足時仍可取同owner的次要token。明確owner的既有操作可在主token失效時取同owner已驗證token，但如果主provider已驗證為另一人，整次拒絕，不取舊Web帳號續發。

新增8項API／controller測試，含主失效後面板session清空但原草稿/磁碟保持，六份回歸165項通過。本輪單次analyze 0 errors、0 warnings、2 infos（測試:336/347大括號），未重跑。未改OAuth/token保存或刷新。下列第1項是原核對缺口，以上完成了程式與mock證據；真人失效/重登仍待驗收。

1. 核對主 provider token失效時，`session()` 的 fallback 能否選到另一個Web/Drops帳號；現有 primaryId 只在成功驗證後建立，不能以已通過「有效主帳號」測試宣稱所有登入失效情況皆隔離。
2. 本機已提交ID為local-*，歷史為官方ID。兩者關聯未建立，可能顯示同一次發送兩筆。不能猜文字+時間刪掉，因為使用者可重複發相同內容；查證能否取得可靠官方ID，不能虛構回執。這是明確未完成項，不以現有mock遮蔽。
3. 依 `twitch-whisper-device-acceptance.md` 集中實測真人Web列表、雙向收發、Android背景與 Windows入口。這些未測且仍是必要門檻，但不阻止安全的程式缺口修正。

官方來源：[Send Whisper](https://dev.twitch.tv/docs/api/reference/#send-whisper) 回204 No Content且可靜默丟棄；因此目前「已提交」文案合理，不能當送達、已讀或可靠 message-ID 回執。未呼叫真實發送API。
