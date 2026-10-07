# StreamNook 功能對齊與入口分類

2026-10-04最新：使用者提供 Twitch Web 真實私訊列表回應，確認 operation `Whispers_Whispers_UserWhisperThreads`、`messages.edges`及空首cursor；VioClass已修正列表query/parser並通過27項列表／controller測試，未改歷史hash或token。尚缺原始request hash/query與真人重新同步成功證據；不是只照StreamNook歷史query，列表仍需實機驗證。

2026-10-04最新：私訊刪除等待登出仍刪舊資料已由新測試重現並修正；generation/owner與串行queued/read後write前gate，取消false／提交true、已開始write不假取消。6新mock驗新帳號草稿及期間收件、舊成功／失敗隔離，無API/schema/token或真人變更。下一單元草稿／session保存競態，原官方列表雙向可靠ID與兩平台及全目標未完成，詳私訊清單。

2026-10-04最新：回到私訊原門檻，修成功刪除後舊待存收件復活（修前新測試確實失敗）；owner/peer局部補存barrier、成功才移除原待存快照，失敗及新收件／其他peer保留。七份257項通過，唯一analyze無問題，無新API/schema/token或真人動作。上游重新查閱仍無local/official ID可靠映射證據；私訊真人列表雙向、背景／兩平台與全目標仍未完成，接續私訊生命週期與證據，詳私訊清單。

2026-10-04最新：watch實際訊息局部Ctrl+D/T/W/B/Shift+B接原五種MOD確認與結果，确认後重核runtime/API身分、目前訊息／使用者資格與管理回呼，消失／撤權拒絕，沒有快捷鍵直接寫入；固定鍵說明接設定分類。六份39項全過，無新API/scope/保存/token或真人操作。尚非全命令與可配置組合鍵完成，context/兩平台與原私訊官方列表雙向可靠ID及全目標仍待完成，詳keyboard清單。

2026-10-04最新：完整App聊天設定在900×700／320×640實際切分類、捲動選鍵與保存通過；default Prefs adapter mock重讀／reset保留其他設定，以及兩feed同步鍵位不移焦點已驗。六份32項全過，無產品API／token／schema或真人變更；非磁碟重啟或兩平台實機證據。下一單元直接MOD快捷動作與確認，原私訊真人列表／雙向／可靠ID及完整目標仍未完成，詳keyboard清單。

2026-10-04最新：App chat設定接五命令選鍵／停用與reset確認，保存才顯成功、衝突／失敗保留原值、corrupt需明確復原，close晚回應與換controller隔離。5新card widget、五份29項全過，无API／token／hash／schema或真人變更。settings入口目前為靜態接線證據，真Prefs adapter／兩feed同步、完整App設定與實機、直接MOD鍵及原私訊／全目標仍待完成。

2026-10-04最新：自訂鍵位controller＋實際dispatch已接，五命令唯一鍵／停用、serial持久化成功才套用、壞檔保留鎖修改直到reset；新Prefs key/schema詳keyboard清單，不動token。4存儲＋1真feed重綁測試，四份24項全過；前輪fixture警告已局部標註。未接App設定UI／組合鍵或直接制裁，下一輪補入口與確認、adapter同步／實機；原私訊與全目標仍未完成，無真人操作。

2026-10-04最新：已修watch panel可空canModerate回呼呼叫；2新完整聊天panel→area→list→feed widget驗gate／K最新與U、撤權false、缺gate停用，連回歸19項全過。唯一analyze 0errors／1warning（docs test:46的Prefs測試專用API），留下一輪處理。無新API／保存／token或真人操作，詳keyboard清單。不是主watch真人實機／直接動作或鍵位配置完成，接續独立自訂鍵位保存與衝突檢查；原私訊與完整目標仍未完成。

2026-10-04最新：feed接MOD權限回呼、pane Tab→J／K初始最新及逐frame核權，5新測試连回歸17項全過、前輪格式修正。但唯一analyze有watch panel:534函式對bool比較info，實際watch入口目前被停用，下一輪先改可空canModerate回呼呼叫並補adapter證據，不宣稱實機可用。無新API／保存／真人操作，自訂鍵位／直接動作、context與原私訊／全目標門檻仍未完成。

2026-10-04最新：已聚焦訊息可K舊／J新，實際feed跨lazy／100則視窗以ListController index定位與generation移焦點，live／follow不搶鍵盤目標，節點依來源淘汰及dispose。2新160則導航／邊界live關閉測試，連原回歸12項全過；唯一analyze0errors／0warnings／5大括號infos，詳keyboard清單，留下一輪。無新API／保存／真人操作；未聚焦MOD入口、直接動作鍵／可配置保存与實機、私訊及完整目標尚未完成。

2026-10-04最新：依上游chatModController及commands重新盤點MOD鍵盤工作；實際訊息feed接局部Tab聚焦、U原user card／Enter原context／Esc解除，不全域攔鍵、不直接制裁，TextField子焦點保留。3新widget連原訊息管理10項全過，API／記憶體界線與來源詳twitch-chat-keyboard-api-storage.md。J／K導航、直接動作確認、自訂鍵位及保存／實機未完成，不視為完整快捷鍵；原私訊與完整目標維持未完成。

2026-10-04最新：固定／自訂禁言、永久封鎖與解除16新確認矩陣驗成功一次、取消及確認中升MOD／消失零寫入。測試重現自訂禁言確認漏送出原因，已補捕捉原因與可捲動內容，保留原斷言；五份81項全過，唯一analyze無問題。無新API／保存／憑證／真人操作；續接桌面快捷鍵盤點，完整context／低高度／實機及私訊與全目標仍未完成。

2026-10-04最新：user模式3新測試涵蓋51來源範圍原子拒絕、兩種小尺寸字級1.3觸控拖曳至表單；核對原單筆封鎖解除已存在，補管理面板確認後目標即時可見角色gate（警告／禁言／封鎖／解除含自訂時間），非官方角色查詢。2新升MOD／消失測試，五份65項全過，唯一analyze無問題。沒有新API／保存／憑證或真人操作；其他動作完整入口／桌面快捷鍵及原私訊、雙平台與全目標仍待完成。

2026-10-04最新：新增批次訊息／使用者選取模式，使用者不需 message ID，刪除仍保留原 ID policy；切模式清選取與手勢、同人角色矛盾保護，範圍／拖曳資格统一，Ctrl+Enter只開user表單。資格快取只針對本次快照且不取代執行gate，無新API／存儲。3新widget、五份60項全過，唯一analyze無問題。無真人操作，完整user模式手機／拖曳上限與實機、其他MOD及原私訊／全範圍門檻未完成。

2026-10-04最新：使用者批次新增 8 項 fake 面板測試，涵蓋成功禁言、停止／關閉晚成功及晚失敗、第一筆後失權、明確拒絕與未知結果不重送。五份 57 項全過，唯一 analyze 無問題；本輪無產品／API／保存改動或真人操作。下一輪補使用者選取模式以解除合法 user 被刪除所需 message ID 阻擋的功能缺口，維持刪除保護；雙平台及原私訊／完整目標未完成。

2026-10-04最新：批次禁言／警告已接原因／時間表單、使用者去重預覽、原頻道確認與逐人結果／停止；watch／管理入口接原 context 權限及可見訊息保守角色 gate，非官方即時角色查詢。4 新測試、五份管理回歸 49 項全過，唯一 analyze 無問題。沒有新增 API／保存／憑證或真人操作；目前選取仍需官方 message ID，成功禁言與停止／關閉等深入驗證、永久 ban／解除、雙平台及原私訊／完整門檻尚未完成，goal active。

2026-10-04最新：禁言／警告user batch核心已新增，user去重、固定原因秒數／受保護提示合併、逐筆動態target gate，沿原API及共用串行停止、不重送；無新儲存／token／hash或真人操作。6新核心測試、四份45項全過，唯一 analyze 0errors／0warnings／1格式info（controller:217）。尚未接App動作表單／確認與target回呼，永久ban／解除等未提供；完整批次與原私訊／其他全範圍門檻仍未完成。

2026-10-04最新：拖曳失權測試重現timer仍捲動，改每tick動作前檢查並立即停止；新增2小尺寸字級1.3觸控拖曳／預覽測試，進preview退出drag恢復原physics。四份39項全過，最後小修2尺寸再驗，唯一 analyze 無問題。未改API／存儲／runtime或操作真人；拖曳最大上限／Android實機、後續批次禁言警告與原私訊及全部目標仍有门檻。

2026-10-04最新：批次面板顯式拖曳模式（預設關）支援固定down起點、原集合baseline回拉、邊缘自動捲動與結束／dispose停timer；修實際錯誤pan anchor与首移動問題，無API／runtime／持久化變更。3新逆向取消／touch拖曳／mouse自動捲動及dispose測試，四份36項全過，唯一 analyze 無問題。不是直播直接拖曳或實機全面完成；50上限／角色時序／不同尺寸深入拖曳與其他批次、原私訊／全部門檻仍保持。

2026-10-04最新：批次面板Ctrl+Enter只預覽、不快捷確認刪除，桌面Shift範圍與手機顯式範圍開關均跳不合法項、超50原子拒絕保留原選取。3新操作測試，四份33項全過；唯一 analyze 0errors／0warnings／1測試大括號info（panel:144），留下一輪。不新增API／持久化或真人操作；不是拖曳或快捷鍵配置完成，逆向／取消與其餘批次、完整私訊／實機門檻仍未完成。

2026-10-04最新：訊息context管理選單可直達批次且僅預選原合法官方ID，不直接提交；watch沿原固定permission並捕捉runtime。3新測試涵蓋直達／零發送、50上限可取消、開啟後來源突變不改目標；四份30項全過，唯一 analyze 無問題。原直播卡長按／右鍵完整鏈及watch實機尚未驗收，快捷鍵／範圍／拖曳、其他批次與原私訊／完整目標仍有門檻；無API／存儲／憑證變更或真人操作。

2026-10-04最新：批次刪除核心已接管理面板入口與選取／預覽／不可復原確認／逐筆結果／停止UI，固定開啟快照、限50，沿watch原固定權限closure；7面板＋9核心＋5原管理面板共21項全過，唯一 analyze 無問題。API與記憶體規則詳批次清單，沒有新API／持久化或真人操作。兩平台目前皆可管理面板進入，尚非訊息直接長按／右鍵多選、快捷鍵／拖曳或其他批次動作完成；完整watch實機與原私訊／全部對齊門檻保持未完成。

2026-10-04最新：核對訊息卡既有長按／右鍵context及單筆管理，不重做；批次未找到接線，新增刪除執行核心與9假API測試，固定預覽／過濾去重／限50／串行350ms／取消與失權／未知停止／無重送復原。規則見 twitch-moderation-batch-api-storage.md；未接App選取确认UI、快捷鍵／拖曳及其他批次動作，非功能全面完成。唯一 analyze 0errors／0warnings／1大括號info（controller:104），下一輪先修再接UI。未操作真人或改API／儲存／token，原私訊与完整门檻保持。

2026-10-04最新：watch徽章回呼不再立即冒稱已套用或重複刷新，面板記憶體追蹤本次提交、手動刷新依同頻道selected ID確認，null／其他頻道保留資料、錯誤勿重送。無新API／query／儲存／runtime變更。5新手動刷新＋2手機／短橫向鍵盤字級操作測試，身分相關26項全過；唯一 analyze 0errors／0warnings／1大括號info（panel test:143），留下一輪。watch僅靜態接線、非真人／裝置或所有身分验收；下一輪回完整工作包核對MOD快捷鍵／批次與聊天事件缺口，私訊及完整原門檻維持未完成。

2026-10-04最新：處理前輪2項格式提示；新增色票／自訂色碼預覽與成功流程2項，以及顏色／徽章／徽章接受後刷新關閉面板晚完成6項。實際UI操作驗預覽不提交、無效碼禁用、預設色送官方名稱、等待不提前成功、晚成功／失敗不更新已dispose畫面或重送。身分相關19項全過，唯一 analyze 無問題。未改API／儲存／版型或操作真人，手機低高度／鍵盤及pending後手動刷新續接核對；原私訊真人与雙平台、整體功能仍未完成。

2026-10-04最新：聊天身分面板修正徽章／顏色並行覆蓋狀態，等待更新時其他身分操作鎖定、拒絕保留草稿可重試；2新widget與4顏色API mock，含同owner／scope／validated client-ID、400／403不重送，連既有面板11項全過。唯一 analyze：0errors／0warnings／2大括號infos（sheet:160、416），未反覆修正，留下一輪處理。沒有新API／schema／儲存／真人修改；成功色票流程與關閉等待生命週期接續核對，原私訊及完整實機門檻仍未完成。

2026-10-04最新：聊天身分徽章套用拆開「提交已接受」與「同頻道目前配戴已確認」，讀回舊資料／null／其他頻道不冒稱已套用，接受後讀取失敗不誤導成提交失敗。5新面板操作測試，連同六份管理紀錄共61項全過，唯一 analyze 無問題；沒有新API／儲存／憑證變更或真人操作。仍非真人或雙平台验收，私訊及原完整目標保持未完成；接續顏色套用與拒絕／等待流程。

2026-10-04最新：依使用者要求重建遺失掛載的長時間goal（get_goal=null、create_goal=active），保留完整原範圍與現有進度。完成中斷前管理紀錄改動：空白名字回退login／ID、顯示使用者ID、來源ID可搜尋；4新mock含共享來源／未知action／缺details，六份56項全過，唯一 analyze 無問題。没有改API／schema／parser或操作真人，原私訊與其他完整門檻仍未驗收。

2026-10-04最新：直接核對watch管理紀錄listener／context／dispose接線，新增真controller與開啟面板的換owner/channel整合測試；loading先隱藏舊資料、舊callbacks隔離、disk分帳號頻道、stop拒絕後續事件。六份52項全過，唯一 analyze 無問題。API／receiver是假替身，不宣稱完整watch或WindowsAndroid驗收；没有改watch／播放器／token／schema，私訊及原完整門檻仍保持。

2026-10-04最新：修正前輪測試通知warning；管理紀錄新增角色失效／待存保存／恢復權限測試，既有收件服務失效停socket已核對，沒有重做。角色失效提示與登入owner不符拆開，失效後新事件拒絕、既有待存可本機保存。六份51項全過，唯一 analyze 無問題；无新API／schema／token變更／真人操作。watch實際生命周期、雙平台與私訊原門檻仍未完成。

2026-10-04最新：管理紀錄重試保存新增 generation 隔離的防重入／保存中UI，失敗可再試，切owner晚完成不改新面板。4新mock、六份50項全過；唯一 analyze 有2個panel測試 protected notifyListeners warnings，未重跑，留下一輪改fixture通知方法。没有更動API／schema／憑證，不是真人或整體完成；私訊既有門檻保持。

2026-10-04最新：核對既有AutoMod／管理紀錄程式，不重做現有佇列。補有12筆假事件的管理紀錄面板桌面／手機／短橫向搜尋分類測試，重現keyboard下46px overflow並修共用可捲動控制區與lazy紀錄列表。3新測試、六份管理紀錄回歸46項全過；唯一 analyze 無問題（後補測試焦點等待未再分析）。未改API／保存／授權或操作真人。私訊真人列表／雙向／裝置與可靠ID關聯依舊未完成，這是原MOD工作包進展而非全面對齊完成；來源／完整範圍與排除項不變。

2026-10-04最新：精簡私訊補對話管理／本機刪除，沿原一個控制按鈕不加寬；確認可捲動及固定owner，舊選單／確認中切帳號不得刪新owner同peer。4新mock驗取消、刪除、兩種換帳號，七份249項全過，唯一 analyze 無問題。未動真實資料／API／儲存格式；真人、雙平台、可靠官方ID及整體功能仍未驗收。

2026-10-04最新：補齊私訊精簡版遺漏的共用錯誤詳情，低高度／鍵盤下可捲動讀取完整原因，關閉不重送或清資料；3新mock含壞archive不覆寫，七份245項全過，唯一 analyze 無問題。一般版仍沿既有錯誤展示，沒有新增 API／儲存欄位／授權；真人與完整對齊仍未完成。

2026-10-04最新：核對既有私訊列表最近／名字／本機未讀排序與搜尋，桌面／手機新增2項操作測試，含篩選時收件及清除搜尋後未讀／內容／排序保留。無匹配結果改顯示搜尋沒有結果，不再誤稱歷史為空；沒有新增 API／存儲欄位或改分類。七份242項全過，唯一 analyze 無問題；真人列表／双向與裝置仍未驗收，非全面對齊完成。

2026-10-04最新：重新核對上游send仍本機sentID，官方204無內容／收件事件非發送回執，沒有可靠匹配證據；查閱來源列儲存清單。補匯入新IDhistoryOnly、防備份冒充新私訊，以及同ID真正live提升只提示一次；3新mock並保留未讀／anchor。不同ID可能雙筆的限制仍未解，真人API／雙平台與完整目標不以mock完成。

2026-10-04最新：鍵盤／字級／低高度history anchor新矩陣找到真实overflow，修compact判斷與新私訊提示占高；10項各3頁＋live未讀與返回最新操作，詳A—F audit。沒有改儲存／憑證／API，真人雙平台及所有功能仍未完成，不以mock當全對齊。

2026-10-04最新：大型本機歷史避免同raw重复解析、同草稿／已讀0重复全檔寫入；單一owner immutable cache仍每次讀來源，外部變更／損壞不回舊snapshot。3新mock含3MiB無變更零寫入；非手機RAM／真人API／全部功能完成，實機與原私訊完整門檻仍待驗收，詳儲存清單。

2026-10-04最新：修正大型本機私訊備份可匯出卻因2Mi字元限制不能還原，兩端同32MiB UTF-8預算，原文不截断、超限明示且歷史保留；3新mock含實際3MiB roundtrip。限制詳見儲存清單；任意大小／檔案分份／低記憶體與真人雙平台仍未驗收，整體保持未完成。

2026-10-04最新：缺口待存項目在真正保存後確認，取消不丟、較新信號不被舊提交清掉，切回不再重播已存舊碼覆寫新會話。4新 mock及保存結果契約列於儲存清單；真人私訊／Windows／Android與全部Twitch對齊仍未驗收，不宣告完成。

2026-10-04最新：缺口新增獨立觀察識別碼與工作快照，真正信號／新會話不受裝置時間倒退或同時間影響，同碼重試保留；4新 mock，欄位與限制見儲存清單。未改 API/hash/token；真人雙平台／完整私訊與其他原功能仍未驗收，不以本機回歸宣稱整體完成。

2026-10-04最新：新收件缺口／新會話會使舊恢復快照過期，下次從列表頭完整列舉；中途或末頁新 gap 不回報成功，未存 gap 先阻擋請求，既有訊息／草稿／進度資料不刪。6項新 mock，儲存清單列 receiveGapObservedAt／gapObservedAt；真人雙平台、時鐘異常與完整功能仍未驗收。

2026-10-04最新：正常退出／重開亦有 owner 隔離的保守收件會話標記，保存規則／舊資料相容／失敗重試列於 twitch-whisper-api-storage.md。不是精確離線時間，也不以重新連線或歷史頁耗盡清 gap；真人 Windows／Android、私訊端到端及全部功能仍未驗收。

2026-10-04最新：一般/恢復history亦套遠端帳號payload容量檢查，超限原子拒頁不清資料/進度；App保留容量/逾時原因與原頁續接。5新測試、七份205全過；唯一analyze0errors/0warnings/1測試info，未再跑。20MiB不含metadata/所有本機寫入，仍有正常離線/新gap語意、真人API/裝置及其餘功能門檻，未全面完成。

2026-10-04最新：全peer恢復已接Home controller及一般/低高度歷史圖示menu，可開始/進度/取消/續接；保存禁止取消、衝突鎖、owner晚頁/忙碌UI隔離，gap保留。6新測試、七份200全過；唯一analyze0errors/0warnings/1info，最末UIbusy微調只test不重跑analyze。由未接線核心進展為可操作App/mock流程，但真人API/重啟/雙平台與完整功能仍未驗收。

2026-10-04最新：全thread/peer歷史恢復核心與持久進度已實作，頁資料/進度原子保存、取消與失敗原頁續接、不改瀏覽cursor/本機即時未讀，保留gap。8新測試、七份194全過；唯一analyze0errors/0warnings/11infos。核心尚未接App控制器/畫面，下一輪接進度/取消/重試；API實機/雙平台/正常離線窗口及全部對齊仍未完成。

最新續接：最早已知收件缺口receiveGapSince持久化於原owner archive，其他寫入保留、clearSession不刪；新store/controller恢復提示、故障重試、壞資料不覆寫。3新測試、六份186全過；唯一analyze於最後調整前0errors/0warnings/1info，依限制未再跑。仍未完成正常離線窗口與全thread/peer恢復任務，真人雙平台未驗收，整體保持未完成。

最新續接：EventSub主連線缺口有typed owner信號，正常server交接不誤報；重連或單頁同步不宣稱全部私訊恢復。一般/低高度面板提供列表及選定對話歷史入口，4新測試與既有EventSub斷言擴充，六份183全過、一次analyze無問題。仍僅記憶體缺口標記與手動逐頁恢復，跨退出/所有peer完整補齊、真人/裝置未完成，下一步核對完整恢復流程。

最新續接：背景私訊保存失敗按owner/官方ID暫存，重新載入補存，不重複未讀/通知；通知callback失敗不阻擋下一則，通知名稱取已保存最新profile。容量上限與退出遺失明列儲存清單；不等於斷線期間完整補齊。4新測試、六份回歸179全過（首次舊profile通知失敗已修正）；一次analyze0errors/0warnings/3大括號infos，未再跑。下輪核對斷線提示與歷史恢復入口，整體未完成。

最新續接：私訊顯示區分「已提交・尚未儲存」，controller按owner/ID暫存結果；恢复後只更新存在且身份/內容相同的原訊息，不復活刪除對話，不重發。5項新測試、2項擴充，六份回歸175項通過；一次 analyze 0errors/0warnings/1controller大括號 info（369），未再跑。非持久回執，真人/官方ID關聯未驗收；接續核對背景收件斷線／保存失敗。

最新續接：持續儲存故障不蓋掉已接受提交／勿重送警告；sending 恢復 checkpoint 寫入成功後才完成 owner 恢復，失敗再讀仍重試。新增3項測試、六份回歸170項通過；一次 analyze 0errors/0warnings/1測試大括號 info（436），下一輪處理。執行中磁碟舊 sending 展示、真人重啟與完整收發仍待核對，無持久回執或全面完成宣稱。

最新續接：查閱上游 whisper_inbox 發送後建立本機 sent ID、按 ID 合併，未找到可靠官方 ID 關聯；不以文字時間猜配去重。修正 VioClass 已接受提交後本機保存錯誤被誤判 failed，提示勿直接重送、不自動重發；新增2項測試，六份回歸167項通過，單次 analyze 無問題。持續磁碟故障、真人收發/重啟仍待驗證，完整限制列於儲存清單與 A—F audit；本輪未新增 API/hash。

最新續接：主provider失效不讓次要Web/Drops建立另一私訊身份；已驗證主身份/明確owner可同帳號補scope，主身份換人則拒絕舊owner。8項新測試，六份回歸165項通過，單次analyze0errors/0warnings/2測試infos。local submitted與official ID仍未可靠關聯、真人驗收未做，非全面完成。

最新私訊A—F核對見 `twitch-whisper-requirements-audit.md`：本輪修正備份與raw JSON同ID身份/內容衝突，合法state推進維持，4項新測試及六份回歸157項通過，單次analyze無問題。主provider失效身份選擇與本機提交/遠端官方ID對應仍有缺口，真人API／裝置未驗收，不能宣稱全部私訊完成。

最新續接：單一私訊歷史已有取消／45秒待讀逾時／原游標模式重試，切換peer停止待讀並隔離晚回應；保存階段不可取消。新增7項測試，六份回歸153項通過，單次analyze無問題。下一輪核對私訊A—F功能缺口；真人服務／裝置未驗收，未宣稱全部對齊。

最新續接：私訊列表提供取消／原分頁重試／45秒遠端讀取逾時，晚結果不套用，開始寫入後取消禁用；底層網路未宣稱已中止。新增7項測試，六份回歸146項通過，單次analyze無問題。單一對話history尚缺相同恢復操作，真人装置未完成；仍私訊優先。

最新續接：私訊較早歷史向上延伸，穩定 anchor 保留當前閱讀訊息；4項桌面/手機/變高測試連續三頁相對 viewport top 誤差≤1px。六份回歸139項通過，本輪一次analyze無問題。尚非所有字級/鍵盤組合或真人裝置驗收；未擴充MOD，整體未完成。

Home／面板刷新並行這輪單次 analyze 無問題，exit code 0。

最新續接：私訊授權等待 Home 正在執行的 session 刷新後，再驗證新 token 所屬帳號；不拿舊帳號狀態重試。一般重複刷新共用等待、登出斷開舊 session，新增6項測試與六份回歸135項通過。真人列表及裝置驗收未完成，維持私訊優先。

私訊授權入口本輪一次 analyze 無問題，exit code 0。

最新續接：私訊授權從完整 linked login 改為既有 main/Web OAuth 專用入口，不連帶要求 Drops；列表可授權後重試，失敗/換帳號/關閉不續接。5項新測試，六份回歸129項通過。真人 Windows／Android 清單集中 `twitch-whisper-device-acceptance.md`，尚未執行。未新增 query/hash/token 儲存，整體目標未完成。

本輪單次 analyze 無問題（exit code 0）。

最新續接：私訊遠端歷史和背景即時收件的同 ID 競態已修正，來源狀態寫入 message archive；即時收件提升一次後去重，不漏首次未讀／通知，重開不失去來源。4項新增測試，五份私訊回歸121項通過。真人列表及裝置私訊收發仍未完成；本輪沒有切換至 MOD 或擴充其他平台。

最新私訊進度：列表選單已加入手動同步 Twitch 對話／載入更多，按帳號保存對話及分頁 checkpoint，並區分 Twitch 上次同步未讀與本機未讀。新增6項回歸（含3種尺寸），完整五份私訊測試117項通過；一次 analyze 0 errors、0 warnings、1大括號info。未使用真人帳號驗證列表，不能宣稱私訊已全面完成；新增API／保存清單見 `twitch-whisper-api-storage.md`。本輪未擴充 MOD。

核對日期：2026-10-03。參考版本：`76b81ca0d935cd01b8e3cffaafcfc23de716aae9`。

此文件是實作清單，不代表功能已完成。除明確列出的現況外，尚未逐項驗證 VioClass；不得把 UI 入口、模擬資料或發送表單稱作完整功能。

## 已確認的工作範圍

使用者於 2026-10-03 確認：先完整對齊 Twitch。Kick／YouTube 暫不納入；維持不加入 7TV 徽章、名字特效與登入，既有第三方貼圖保留。工作採逐項規劃、實作、驗收的方式接續推進。

實際執行順序、驗收與續接紀錄見 [Twitch 功能路線圖](twitch-feature-roadmap.md)。此文件保留來源核對與功能差異，不作為完成狀態的替代品。

## 已確認的分類

| 功能 | Windows 入口 | 手機入口 | 原則 |
| --- | --- | --- | --- |
| 悄悄話／私訊 | 外框獨立聊天圖示 | 首頁獨立私訊入口；目前在更多選單 | 不放聊天室身分面板；需要真正的對話列表、收件與回覆 |
| App 更新 | 外框獨立更新提示、設定的更新分類 | 首頁更多選單、設定的更新分類 | 不混入頭像、徽章、聊天身分或聊天室工具 |
| 顏色、Twitch 徽章 | 聊天身分面板 | 聊天身分面板 | 必須區分預覽與實際套用 |
| 聊天室與 MOD | 頻道聊天室設定 | 頻道聊天室設定 | MOD 身分與 OAuth 管理授權分開檢查 |

StreamNook 的 TitleBar 將私訊、身分／徽章、設定與更新分成獨立入口；VioClass 的手機排版另作適配，不照搬桌面視窗。

## 私訊：現況與必要工作

現況：VioClass 已把發送表單替換為對話列表／聊天頁，接入本機帳號隔離歷史、草稿、官方發送、EventSub 收件、未讀徽標與通知，並有同帳號本機備份／匯入／刪除。13 項模擬回歸測試通過；真實收發與裝置驗收尚未完成，不宣稱完整對齊。舊 Twitch 遠端歷史匯入依賴受限制的私有 GQL hash，尚未實作。已移除聊天室工具裡的私訊與更新項目；Windows 外框與手機首頁更多選單保留獨立分類。

- 對話列表：頭像、名字、最後一則訊息、時間、未讀數。
- 搜尋使用者、新建對話；依最近、名字、未讀排序。
- 桌面左右雙欄；手機列表與對話頁切換，返回時保留草稿。
- 對話內容：雙向訊息、時間、發送中／失敗／已提交狀態、回覆輸入與表情。
- 官方 EventSub 背景接收：面板關閉仍收件；斷線與 reconnect、授權撤銷、重複事件處理。
- 未讀與通知：開啟對話時已讀；外框與手機入口顯示未讀，不重複通知。
- 按 Twitch 帳號隔離本機歷史；切換帳號不得讀到另一帳號的內容。
- 歷史載入與匯入：StreamNook 使用私有 GQL 查詢已知對話並另有匯入流程，不能宣稱單靠官方發送 API 就能取得全部歷史。
- 本機刪除對話與歷史清理要說明範圍並確認，不暗示會刪除 Twitch 伺服器上的對話。
- 發送被 Twitch 接受不等於對方一定收到，不顯示虛構的已送達／已讀狀態。

## MOD：現況與差異

目前已實作：聊天室模式切換、清除、最近訊息操作、固定／自訂禁言時間、封鎖／解除封鎖、警告、原因與確認框。慢速時間與追隨時間門檻可調整；確認包含目標頻道。HTTP 送出前再次檢查帳號／頻道／管理身分，授權 scope 不等同 MOD 身分。5 項 API 與 3 項介面測試通過，但只有本次面板的操作紀錄，不是完整管理紀錄；尚未完成帳號實測。

已追加：直播訊息點擊／長按／右鍵的回覆串卡片旁管理選單，保留原有回覆串與複製。共用目標檢查排除外台共享來源與本機假 ID；確認可取消、警告原因必填、身份改變中止。6 項新增測試通過，未操作真人。

待對齊：直播列表直接 hover／快捷操作、完整使用者卡片操作、拖曳管理、可配置快捷鍵、釘選、封鎖詞、AutoMod 佇列、即時管理事件紀錄與持久歷史；台主的投票／預測控制另核對。批次處理與撤銷需另有防誤操作設計；刪除訊息不能假裝可復原。

使用者資料卡已追加：直接點擊直播訊息 ID 或回覆串入口，查看官方帳號資料、該訊息的 Twitch 徽章／顏色、按 user-id 與来源頻道隔離的本機訊息歷史；官方資料失败可重試，既有管理動作放在卡片內。私訊明確選擇後開啟獨立對話，核對 viewer／peer ID 並保留草稿。11 項資料卡測試與 1 項 launcher 測試已通過；官方 MOD／VIP 角色管理、封鎖狀態、追隨、本機身分自訂與遠端歷史仍未全面對齊，不能稱作完整 UserProfileCard 複刻。

角色子單元已追加：台主資料卡可用官方 API 讀取 MOD／VIP／封鎖狀態、確認後單獨授予／撤銷角色；缺 read scope 顯示未確認，僅有合法 manage scope 仍可提交明確動作。官方限制不允許用一般 MOD token 讀這些台主狀態，不借另一帳號或新增私有 hash。9 項角色回歸測試通過；不自動撤另一角色／解除封鎖，不虛構寫入後刷新結果。尚需驗證真實授權／名額、角色變更後舊訊息的管理資格刷新；追隨、本機自訂與遠端歷史依然未全面對齊。

封鎖詞與角色刷新已追加：管理面板提供官方非私人封鎖詞分頁、已載入搜尋、確認後新增／移除、失敗保留草稿／清單；不是 AutoMod 完整佇列或私人詞清單。台主資料卡可將官方新 MOD 狀態套入當前訊息動作，角色寫入未能刷新狀態時暫停高風險動作；不以舊徽章假裝角色未變。新增 9 項回歸通過；其他卡片全域角色同步、AutoMod 佇列、釘選、事件紀錄、直接 hover／拖曳／快鍵仍須接續。

釘選子單元已追加：官方 `/chat/pins` 的讀取／釘選／時間更新／解除，訊息管理選單與 MOD 設定入口、30–1800 秒或直到直播結束、取代提醒、確認前後狀態與權限檢查，並回饋目前觀看頻道的釘選列。新增 8 項測試通過。尚無原子競態保證或釘選 EventSub 即時刷新，管理面板只顯示 plain text；官方 fragments 渲染、真正到期／直播結束、多管理員／装置驗收與完整管理紀錄仍需接續，不能將此單元視為整個 MOD 對齊完成。

新增來源核對：`ModeratorMenu.tsx` 包含慢速下拉、房間模式、清除確認、解除釘選、加入封鎖詞、管理紀錄開關、台主投票／預測結束控制。`ModRoomPane.tsx` 則是 StreamNook 支持者／訂閱者的私人管理房間，依已確認的專用服務排除範圍不移植，也不拿 Twitch 警告或管理面板冒充它。7TV 管理入口依既有不登入 7TV 的決定維持排除。

## 上游功能盤點（尚非完成清單）

私訊返回續接：手機單欄與短橫向的系統返回先回對話列表，再返回才關閉；桌面雙欄直接退出，明確 close 不被返回規則攔住。四項 route 測試驗證操作及本機草稿保存；Android 真正系統／手勢／鍵盤返回仍需實機，私訊長對話捲動、新訊息提示、官方 API 契約與通知跳轉仍未全面完成。

私訊 API 續接：8 項 HTTP 契約測試與 2 項保存／恢復測試已補；精確收件者、防錯帳號、204 僅提交、已知拒絕與 timeout/5xx 不確定結果分開。不確定結果及 process 中斷以 unconfirmed 本機保存，不自動重送。官方已回覆對象的 10000 字能力尚未接入（目前全線 500），離線關係未知、Unicode 長度與全部收發實測仍是未完成項目，不能以本輪測試通過替代完整對齊。

長內容續接（更新上段歷史狀態）：新官方 incoming 的帳號／對象證據已持久化並開放 10000 額度，未知 500；UI/controller/API 一致、草稿不截短、備份不能偽造解鎖。UTF-16 保守計數尚非已證實的完整 Twitch Unicode 字數規則；舊 archive／離線既有關係未確認、遠端完整歷史、捲動／提示／通知跳轉／貼圖及實機仍未完成。

AutoMod 子單元已接入官方 EventSub v2 的 hold／update 與 Helix Allow／Deny，位置對齊獨立收合待審列。只有連線後接收資料，不冒稱完整遠端队列；斷線缺口、公開／私人封鎖詞界線、真實 scope 與裝置驗收仍須測試。AutoMod 設定、原因位置／貼圖片段、完整 MOD 日誌及其他聊天室功能沒有因此勾作完成。

續接實作：管理設定已有官方 AutoMod 整體／八分類完整編輯與確認、覆寫前重讀、未知結果鎖住重送；待審原因区分封鎖連結及保留官方命中範圍數字。尚未驗證非 BMP 索引映射，不以數字顯示冒充高亮／貼圖片段完整呈現；完整管理紀錄與跨裝置實測仍未完成。設定 read/manage scope 與待審 manage scope 分開處理，沒有因新增設定要求重新改寫 OAuth 儲存。

依 README 與已核對元件整理，逐項核對本地實作後才可勾選完成：

- Twitch 頻道、追隨、分類、搜尋、離線聊天室、VOD。
- 聊天回覆、提及、補全、使用者卡片、本機暱稱／顏色／備註。
- 貼圖、動畫與零寬貼圖、表情選擇；聊天樣式、高亮、忽略規則與聲音。
- 訂閱／續訂、連續觀看、Bits、Hype Train、預測、釘選與其他 Twitch 事件。
- 私訊、MOD、命令補全、自訂命令、常用文字、拼字檢查。
- Drops 進度／庫存、忠誠點數領取與跨頻道統計、徽章追蹤及身分選擇。
- 播放品質、子母畫面、劇院模式、精簡視窗、滑鼠控制、台離線時切換。
- 通知、主題編輯、快捷鍵、命令面板、備份、快取、更新與多帳號。
- MultiNook 多直播、獨立視窗、跨螢幕排列、音訊焦點与各視窗品質。
- MultiChat 多聊天室、分頁／分欄、獨立視窗、背景運作與跨視窗同步。
- 直播聊天覆蓋層、樣式編輯與場景設定。
- 插件、整合與 StreamNook 專用服務。
- Kick／YouTube 平台暫不納入；7TV 徽章、名字特效與登入不納入。7TV 貼圖不受影響。StreamNook 專用服務不能假設可供 VioClass 使用。

## 實作界線

Drops 登入清理與 Cookie 隔離：依使用者要求將 Windows 本機 SharedPreferences（含私訊歷史／草稿／設定／token）及兩個舊 WebView profile 移出到 reset backup，原路徑乾淨；未清其他 App。查明 Drops 與主 OAuth 原先共用 desktop WebView profile，已改為 Drops 專用 profile，Android 仍內嵌 Flutter WebView。這修正 Cookie 混用風險，但 Twitch `/oauth2/device` 目前仍直接回 `400 invalid client`；官方 Device Flow 要求已註冊 Client-ID，尚未取得有效 Drops Client-ID，不能宣稱登入修復。

MOD log receiver 最新續接：新增獨立 channel.moderate v2 收件服務，同帳號／頻道條件、官方 metadata ID有界去重、welcome／訂閱deadline、心跳與backoff、handoff不重訂閱且新welcome前保留原連線、revocation／失權停止與generation拒絕晚回應。九项fake socket／虛擬時鐘案例通過，包含合法wss無明寫port與惡意redirect。十九份完整 **219 項通過**，單次分析 **0 errors／0 warnings／7 infos** 留下一輪（詳roadmap）。**服務尚未掛入實際頁面，事件分類、保存與紀錄UI仍未做，不能稱已可用或完整歷史**。按 [官方 WebSocket 流程](https://dev.twitch.tv/docs/eventsub/handling-websocket-events/) 明示斷線無補回，真人網路／裝置、釘選同步及原清單保留待驗收。

MOD log／Bits 最新續接：Bits catalog→實際待審列載入 bitmap、同台切 MOD、dispose 後成功／失敗四案例已通過；服務回應與圖片仍為受控替身，並非真 CDN。另接官方 `channel.moderate` v2 的 session／subscribe API，檢查同 owner token 的八組授權、匹配 client、精確頻道／MOD／websocket session；四項 fake HTTP 測試通過，沒有改 OAuth/token 儲存。**receiver／action 解析／持久化／紀錄介面尚未接，不能當成完整 MOD log 已可用**。十八份完整 **210 項通過**，唯一分析 **No issues found**；原一項 info 已清。下一步以 [官方訂閱規格](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelmoderate-v2) 接 log 連線／來源隔離／去重／記錄 UI，保留斷線缺口與真實授權裝置驗收，釘選同步及原完整清單仍未完成。

AutoMod Bits fallback 最新續接：catalog 保留當前主題 animated→static 的去重 URL，動畫失敗切靜態、皆失敗回原代碼，不猜其他主題。Windows／Android 模擬平台先確認選取成功，再觸發圖片失敗；切換後直接複製原文且保留命中邊框。原兩項失敗是測試未等選取註冊完成，不是已選取內容在切圖後消失；沒有重選隱藏問題。新增五案例後十七份完整 **202 項通過**。上輪五 infos 已清，本輪唯一分析 **0 errors／0 warnings／1 info**（catalog:75 prefer_collection_literals）留下一輪。受控 bitmap 並非真 CDN／動畫或實機；API→strip 成功圖片、MOD／dispose時序、完整 MOD 日誌／釘選同步和原完整清單仍未完成。

AutoMod Bits 圖片續接：官方 Get Cheermotes 已接同 moderator owner/client 驗證、只有 broadcaster_id query且無額外scope；catalog exact prefix/tier/min bits、dark/light、API提供的animated/static與安全CDN URL，不拼網址，未知保留文字。首筆Bits才載入，loading/failure保留原字，手動retry、generation隔離跨頻道晚回應，圖像native copy保留Cheer100。新增七項catalog/API/loaded bitmap與兩項queue時序，十七份完整 **197 項通過**；單次分析 **5 infos** 留下一輪。API→strip成功圖片、MOD身分／dispose時序、實際動畫／custom Bits與完整MOD／原盤點仍未完成。

AutoMod 圖片驗證續接：上輪 3 warnings／2 infos 已清；新增 Windows／Android 模擬雙圖片失敗的文字 fallback 原文 copy，及 Windows 雙成功 bitmap 跨行原文 copy／dispose，共三情境。十六份完整 **188 項通過**，單次分析無問題。失敗圖在 listener 就緒後由受控 Completer 觸發，不抑制 framework error。Bits 官方 Get Cheermotes 資料來源已核對，API／catalog／UI 尚未接，下一輪須同 MOD owner auth、頻道清單及晚回應隔離，不拼猜測網址；完整 MOD／原盤點與實機未完成。

AutoMod 官方 emote fragments 續接：保留有序原文／emote ID與set／Bits prefix數額tier，串接不符原文整組回退，未知或無效metadata保留文字。固定官方 CDN 有效ID圖片、命中token邊框與原文選取接入；已載入bitmap測試全選copy、圖片雙擊Ctrl+C及Shift+右不漏代碼。四項新測試後十六份完整 **185 項通過**；單次分析 **3 warnings／2 infos** 留下一輪，不稱分析全綠。Bits目前保留原字與數額，Cheermotes圖片catalog未完成；CDN／動畫、fallback與多圖整合、完整MOD／釘選及其他原盤點仍待續。

AutoMod 命中片段續接：新增原文 selectable highlight 與位置候選模型，inclusive 官方邊界轉本機 UTF-16 範圍時比較 Unicode scalar／UTF-16／UTF-8 解讀，拒絕無效組、不切 grapheme；單一有效結果標示，歧義則原文不亂標並列候選／核對提示。官方文件未說 Unicode 單位，issues #1206 有非 ASCII 偏移回報，故這是本機推定而非官方索引保證。九項模型／原生 copy／提示加一項窄版真捲動 EventSub strip 整合，十五份完整 **181 項通過**，單次分析無問題。官方 emote／cheermote fragments、完整 MOD 紀錄、釘選事件及原其他功能仍未完成；真實 AutoMod 模式／權限與實機保持待測。

私訊多行／catalog 續接（替換上段歷史實作）：新增明確換行、自動換行及原文→image→原文三項直接測試。修正 token end 在圖片外造成跨行反向多選；改 token end 定位於圖片內。catalog 在已有全選時更換整個 nested container 使新圖片收不到事件，故替換上一輪 keyed subtree 為穩定容器及 didUpdateWidget 更新 parts／raw，變更清本地選取、不變保留，移除呼叫端內容 key。十四份完整 **171 項通過**，單次分析無問題。元件層 catalog 時序有證據，整則 SelectableText→SelectionArea 面板切換、Android handles、RTL、多行其他 granularity、實機與完整 MOD／原盤點仍未完成。

私訊選取更新續接：新增四項直接測試，Android 模擬長按標準 copy／清除選取、Windows 多貼圖與 ZWJ emoji／組合字雙向逐字移動、內容更新與不變重建。更新測試先重現旧 delegate 複製 `prefix ` 而非 Kappa；元件內部依原文及 token 結構重建 selection subtree 後通過，不依賴外層 key，不變內容保留選取。十四份完整 **168 項通過**，單次分析無問題。此 harness 用 ColoredBox 幾何替身，不是 CDN／動畫或 Android 實機驗收；多行／RTL／catalog 結構變化／handles、完整 MOD 與原其他功能仍未完成。

私訊逐字交界續接（更新下段失敗）：純 WidgetSpan 對照重現 SDK 多選 after；私訊新增局部原文→image slot caret 映射，不改 SDK。保留 Windows Shift+右正確斷言並通過，擴充 Shift+左回 Kappa／再收為空；圖片反向及 collapsed range 正確保存。十三份完整 **164 項通過**；emoji／組合字／多圖／換行／RTL delegate、Android handles、其他 granularity 整則交界與原完整盤點仍未完成，不能稱整體對齊完成。

私訊貼圖鍵盤續接：已接 granular／directional／paragraph event，Windows Ctrl+C 真 key routing 能複製原 token，並修正保留 selection 關閉時的 disposed handle 回呼。新三項事件測試及普通 Text 對照通過；但是图片雙擊後 Shift+右多選 after，和普通文字只多選空白不同，保留正確斷言、不 skip。完整 **162 通過、1 失敗（163 項）**；下一輪先補純 WidgetSpan 對照／檢查 range 並修交界，不以新增事件當作全面選取完成。Android handles、跨行／多圖／RTL 與原完整盤點仍未完成。

私訊貼圖原生選取續接：成功圖片 fixture 證明原本標準 copy 漏掉 Kappa；新增真正圖片 Selectable renderer，以矩形幾何／highlight／handle layers 回傳原文代碼，不使用隱藏文字。標準全選 copy 與滑鼠雙擊圖片單獨 copy 現在通過，clear／正反向 edge／dispose 有直接測試。十三份完整 **159 項通過**，最後 lifecycle／color 調整後相關兩份 **64 項通過**，單次分析無問題。跨行／多貼圖／RTL drag、Android handle、Ctrl+C、Shift 方向鍵與 granular／paragraph event 尚未完成，不宣稱全面選取功能完成。

私訊拖曳範圍續接（更新下段失敗狀態）：局部 ScrollPhysics 在拖曳中估算末尾縮短且原合法位置變成越界時保留離末尾距離；正常捲動、viewport 變更及 genuine overscroll 維持平台規則。上輪保留的 pointer 失敗已修，擴充 Windows／Android 模擬手勢、返回最新再次可用及校正邊界測試。完整 **156 項通過**、inbox 61 項，單次分析無問題；未做實際 Windows／Android、極大歷史驗收。局部複製貼圖、圖片後排版與原完整盤點仍待完成。

私訊捲動時序續接：新增直接 drag-start、pointer gesture、metrics 切 peer／owner 四項測試。三项通過；pointer 在返回最新未排版完即拖曳時仍回末尾，trace 顯示估算最大從 30314.68 縮到 13714.68。新增拖曳期間退出跟隨／已讀判斷保護，但未解估算回彈，保留失敗正式回歸、不 skip。完整 **153 通過、1 失敗（154 項）**，下一輪優先修此案例；不能沿用上一輪 150 全通過表示目前綠燈，完整對齊仍未完成。

私訊手機布局續接：compact 標題列已有固定 ID 對象資料刷新入口；貼圖選擇器按鍵盤後可用高度配置，搜尋／提示外層可捲動，grid 列高隨字體縮放。三項新增測試實際操作短橫向鍵盤、手機兩倍字體鍵盤與 compact 刷新，十二份回歸 **150 項通過**，inbox 55 項，單次分析無問題。局部複製貼圖 token、捲動時序與原完整盤點仍未完成，真人／裝置驗收仍待集中執行。

私訊貼圖操作續接：六項新增 widget 測試驗證搜尋／取消／反向選取替換、超額保護、來訊解鎖後即時額度、草稿／帳號切換拒絕舊選取及整則原文 Clipboard 內容。修正選擇器使用舊 peer 額度的實際問題；十二份回歸 **147 項通過**，inbox 52 項。單次分析只剩 `docs/twitch_whisper_inbox_test.dart:1120` 一項 if 大括號 info，留下一輪。局部選取／快捷鍵複製圖片 token、真正圖片／動畫、短橫向／大字體 picker 與原完整盤點仍未完成；本輪未啟動 App／真人收發／推送。

私訊官方貼圖續接：接入 globals／owner user:read:emotes 分頁、獨立搜尋選擇器、插入草稿與 inline 推定顯示；缺 personal scope 保留 globals，不新增 7TV 登入。官方私訊沒有 emote tags，因此只依當前 catalog 精確完整 token 推定，未知／歧義仍為原文；不是對方全部貼圖或歷史辨識。原文存檔與整則複製入口保持，局部選取／快捷鍵複製圖片 token 仍待補。六項新增測試後十二份回歸 141 項通過，單次分析 1 個 null-aware info 留下一輪；真正 CDN／動畫／訂閱資格、picker 深入時序與原完整盤點尚未驗收／完成。

私訊主動 profile 續接：標準對話頁已有手動刷新入口，Get Users 固定 ID 更新名稱／頭像，不靠舊 login；錯資料／失敗保留原對話，切換 selection 或帳號拒絕舊回應，草稿／歷史／未讀與收件資格不變。新增五項 API/controller/archive/手機入口測試，十二份回歸 135 項通過，單次分析無問題。此輪不是自動／批次同步，短橫向 compact 入口、官方貼圖、遠端歷史、快速捲動時序與原完整盤點仍未完成；未做真人／實機驗收。

私訊 peer 名稱續接：官方 incoming 的 login／display name 現在更新同 ID 對話，保存原草稿／历史／未讀／頭像；舊事件、重複事件與缺漏欄位不回退 metadata，備份未來觀察時間不阻擋後續更新。新增四項包含實際面板更新測試，十二份回歸 130 項通過；單次分析 1 個多餘 non-null assertion warning 留下一輪。這不是主動 Get Users／頭像刷新，沒有新來訊的 profile 變更、官方貼圖、遠端歷史、捲動時序及完整盤點仍未完成。

私訊可變高度續接：返回最新等待實際 tail 建立並校正排版後的估算末尾，鍵盤／尺寸變化區分跟隨最新與保留舊位置；新增混合長短歷史／50 行來訊／鍵盤與變寬案例通過，十二份回歸 126 項。单次分析 0 errors、0 warnings、2 個大括號 infos 留下一輪。每次校正有 33 步安全上限，極大歷史、拖曳中取消／快速切對話的直接時序及真實裝置仍待驗證；官方貼圖／peer 更新與完整盤點未因此完成。

Android 私訊通知續接（更新下段歷史狀態）：已接 plugin 冷啟動資料與 live 回呼共用的待處理目的地，等待 session/archive、畫面与前景再核對 owner／peer 開啟；拒絕錯帳號與已登出，不自動切帳號。四項新增測試含 Dart plugin method channel 模擬，十二份回歸 125 項通過；單次分析 0 errors、0 warnings、3 個大括號 infos 留下一輪。未做真正 Android 殺程序／Intent／權限驗收，也沒有新增 App 關閉期間收件或離線補齊；完整私訊與其他原盤點仍未完成。

私訊通知跳轉續接：Windows 浮出通知與通知列已能直接選取 owner／peer ID 對應的本機對話，拒絕錯帳號／失效 context／已刪對話，保留草稿且不查舊 login、不傳訊息。Android 已執行時的通知點擊回呼接同一入口；冷啟動及資料尚未就緒的暫存／重播仍待完成，沒有把接線當作原生實測通過。新增五項測試，十二份回歸 121 項通過，單次分析無問題。私訊其他項目及原完整盤點保持未完成。

私訊閱讀位置續接：往上閱讀時保留位置與本機未讀，新來訊提供返回最新提示；返回最新才清除未讀，恢復前景不提前清除。controller 與 35 筆歷史手機 widget 兩項新測試通過，十二份回歸共 116 項通過，單次分析無問題。變動高度長文、鍵盤／尺寸改變、快速切換及真實裝置仍待驗證；通知精確跳轉、官方貼圖、對象資料與其他原盤點沒有因此視為完成。

- 不修改既有 Twitch GQL persisted query hash、OAuth/token 儲存、IRC 發送協議、Channel Points payload 或播放器底層 runtime。
- 完整移植若需要更改上述範圍或平台原生檔案，先列出必要檔案與原因並取得使用者確認。
- StreamNook 使用 React／Tauri／Rust；VioClass 使用 Flutter，應重現功能與分類，不當作檔案直接搬入。
- 上游 LICENSE 標示 PolyForm Noncommercial 1.0.0 及額外條款，並非無限制的 MIT；採用上游程式碼前需先核對適用條款與保留要求。尚未直接移植上游程式碼。

## 來源

- [README](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/README.md)
- [TitleBar](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/TitleBar.tsx)
- [WhispersWidget](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/WhispersWidget.tsx)
- [whisper_service](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src-tauri/src/services/whisper_service.rs)
- [whisper_inbox](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src-tauri/src/services/whisper_inbox.rs)
- [whisper_history_service](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src-tauri/src/services/whisper_history_service.rs)
- [MOD 說明](https://docs.streamnook.app/moderation)
- [ModeratorMenu](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/chat/ModeratorMenu.tsx)
- [AutomodQueueStrip](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/chat/AutomodQueueStrip.tsx)
- [ModRoomPane](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/modroom/ModRoomPane.tsx)
- [LICENSE](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/LICENSE)

## 2026-10-03：真人截圖後的授權與剩餘缺口

主 OAuth 預設未要求私訊 read/manage scopes，已補齊；linked login 現在檢查官方 validate 的實際 scopes，缺任一項會要求再授權，不因舊 token 可用就跳過。舊 session 的登出入口仍可用。新三項 route/read-only/complete widget 回歸及原 API/EventSub 測試共24項通過；真人同意、官方收件與實際送達尚待驗收。一次 analyze 0 errors、1個多餘 non-null assertion warning、10個既有infos，留下一輪，不宣稱乾淨分析。

Twitch 既有遠端列表/歷史依然沒有接入。當前 StreamNook history 使用 Whispers_Thread_WhisperThread 私有 persisted query 讀已知 peer；尚需核對對話發現、分頁完整性、帳號一致性與保留本機草稿/未讀/去重。hash 限制仍待確認，不把本機空列表或已接 EventSub 當作遠端歷史完成。

先前「Drops 專用 profile」段落是中途狀態，已按使用者要求還原；目前整合登入改接 browser authorize redirect，Windows 使用共享 v30 profile 的獨立視窗、Android 使用內嵌 WebView。token 儲存格式未改，真人 Drops 授權成功仍未確認。

## 2026-10-03：私訊補授權入口驗證

私訊面板新增重新授權入口（包含緊湊高度），沿用整合登入並在返回後刷新 session。先保存草稿、避免重複登入；失敗可重試，換帳號不顯示舊對話，面板關閉後不更新已卸載介面。四項新測試及相關回歸共90項通過；一次 analyze 0 errors、0 warnings、7個既有 MOD infos。真人授權與收發未驗收；遠端對話／歷史仍缺，不把入口完成視為完整私訊對齊。既有 GQL hash 未改，新增私訊 hash 的必要限制仍待確認，完整目標保持 active。

## 2026-10-03：MOD 事件解析進展

依[官方 v2 格式](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#channel-moderate-event-v2)新增 34 種管理動作分類與不可變 detail 快照，區分訂閱頻道及 Shared Chat 原來源；unknown／缺資料不冒稱完整結果。EventSub 新增 typed callback，經 context filter／ID 去重後解析。19項模型與收件回歸通過；一次 analyze 0 errors、0 warnings、1項集合 literal info。尚無永久保存、controller／觀看頁生命週期或紀錄面板，故仍未達管理紀錄對齊，下一步補 archive 與介面；未進行真人管理操作。

## 2026-10-03：MOD archive 保存層

新增 owner／頻道隔離的注入式 archive，模型可序列化；操作串列化、保留範圍內ID去重、時間排序，預設500筆／2MiB UTF-8容量。損壞資料拒絕覆寫、寫入失敗不毒化後續queue；unknown與缺detail不冒稱完整資料。新8項加既有模型／收件測試共27項通過；一次 analyze 0 errors、0 warnings、2 infos。此為保存資料層，尚未注入runtime持久化adapter、串接controller／觀看頁或提供紀錄面板，真人／平台保存及最終功能對齊仍未完成。

## 2026-10-03：MOD 收件／保存 controller

新增登入owner驗證、archive讀取後才開receiver、背景typed收件保存、未保存錯誤／重試及generation隔離。切換立即隱藏舊紀錄，已接受排隊寫入仍落原partition且晚完成不影響新UI。6項新測試與原回歸共33項通過；一次analyze無問題。尚未掛runtime／watch／面板；stop後保存失敗資料尚無跨session重試，需要先補缺口，不能宣稱跨切換未保存資料必不丟失。真人功能及私訊遠端歷史仍未完成，目標active。

## 2026-10-03：MOD 跨切換待存隔離

修復前段缺口：同一controller內stop/start保留按owner／channel／ID分區的待存資料，重新驗證原帳號後恢復並可重試；晚寫入失敗不污染新帳號。全partition共用500筆預設pending上限，壓力達限停止收件，不替換原待存紀錄。新3項及原回歸共36項通過，一次analyze無問題。dispose或程序終止後仍無未保存資料恢復保證；runtime、watch及MOD面板尚未接入，完整功能仍未完成。

## 2026-10-03：私訊新增 GQL／儲存授權

使用者已允許新增私訊API及hash，現新增已知peer的history query與原子archive分頁合併；清單、hash、token來源及容量限制見 `docs/twitch-whisper-api-storage.md`。8項新測試加原私訊回歸95項通過，analyze 0 errors、1 warning、4 infos。未知對話發現、controller／UI同步與真人API仍未驗收，不能稱完整遠端列表。

MOD前輪已接watch context listener／dispose、local保存adapter及面板入口／分類搜尋；39項mock回歸通過，但真人與populated/緊湊面板驗收未完成。接下來優先私訊，不再以已解除的hash限制切去MOD。

## 2026-10-03：已知私訊歷史同步入口

Home的Web-only history API已接controller與面板歷史選單，可近期刷新或更早一頁。owner/generation與archive內canApply擋晚回應，保存/reload保留同步期間草稿及即時收件；近期刷新不倒退更早cursor。新增4項及原回歸99項通過，分析0 errors、0 warnings、2項大括號infos。history-enabled選單尺寸／點擊／閱讀位置及真人API仍待驗收，未知peer discovery仍未接，不能稱全部Twitch遠端對話列表完成。

## 2026-10-03：history-enabled UI 回歸

三種桌面/直向/緊湊尺寸可操作歷史選單，緊湊profile合併入選單；錯誤提示保留draft。歷史IDs不計新私訊提示，非底部閱讀合併不拉回底部；精確可見訊息anchor尚未驗收。5項新增加四份私訊回歸104項通過，單次analyze無問題。未知peer discovery／真人API仍未完成，維持私訊優先，不以mock測試宣稱完整私聊完成。

## 2026-10-03：遠端對話列表查詢與保存

Twitch不帶token的raw列表完整query返回currentUser:null且無errors，已新增同owner Web-only的獨立唯讀列表API（無新persisted hash）及原子archive checkpoint合併。保留local drafts/unread/history/live flag，remoteUnread另存；空頁不刪對話，錯身份/null/errors不當空頁。7項新及完整私訊回歸111項通過，分析0 errors、0 warnings、6大括號infos。尚未接controller/UI或驗證真人登入列表，詳見API／儲存清單；保持目標active。
