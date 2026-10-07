# Twitch 功能對齊路線圖

### 2026-10-04 最新續接：依真實 Web 回應修正列表 GQL

使用者提供實際 Twitch Web 回應，確認 operation `Whispers_Whispers_UserWhisperThreads`、`node.messages.edges`、首 cursor 可為空、thread id 排序格式；已修正 raw query/parser，27 項列表／controller 測試全過。未改既有歷史 persisted hash、OAuth/token或儲存。這是實際回應格式證據，尚非 App 真人重新呼叫成功；下一步直接驗同步回應與錯誤分類，完整私訊／兩平台仍未完成。

### 2026-10-04 最新續接：私訊刪除等待時的登出／帳號切換

修前測試重現等草稿保存時登出仍刪舊資料；controller generation/owner gate，archive queued／read後write前 canApply取消false、提交true，write開始後不假取消。6新測試驗原資料與新帳號草稿／收件隔離，八份263項全過、唯一analyze無問題，無API/schema/token或真人動作，詳私訊清單。下一單元核對草稿與session刷新保存隔離；原真人Web列表、雙向背景、可靠ID、Windows/Android與完整工作包仍未完成，goal active。

### 2026-10-04 最新續接：回到私訊，修待存歷史刪後復活

私訊故障測試在修前重現成功刪除後舊待存收件復活；改 owner/peer 補存 barrier 與起始物件快照，只有刪除成功才清舊暫存，失敗／期間新ID／其他peer保留，逐筆flush拒絕過時物件。2新測試，七份257項全過，唯一analyze無問題。無新API／保存schema／token，詳私訊API/storage與audit。

重新讀上游send/merge仍只有本機sent ID，不能宣稱可靠官方ID映射。下一單元私訊清理／跨帳號生命週期與可靠關聯證據；真人Web列表、雙向背景、Windows/Android與全工作包繼續保持未完成，不以MOD進展取代私訊原門檻。

### 2026-10-04 最新續接：訊息直接 MOD 快捷入口

watch 實際訊息局部 Ctrl+D／T／W／B／Shift+B 已接原刪除／禁言／警告／封鎖／解除確認，無按鍵直接寫入。原 API/runtime 身分與 visible 目標確認後再核，消失／撤權拒絕；新增確認中 guard，設定分類有固定鍵說明。無新 API／scope／儲存或 token 變更，完整規則見 keyboard API/storage 清單。

六份鍵盤與設定／單筆管理39項、五份MOD回歸87項各自全過（含重複檔案），唯一analyze無問題；完整可配置組合鍵、context 切換／尺寸與真人兩平台、原私訊官方對話列表雙向可靠ID、完整全工作包仍未完成，goal active。下一單元補 context 與配置，不把固定五鍵等同 StreamNook 全命令已複刻。

### 2026-10-04 最新續接：正式聊天設定與共享保存已驗

正式 App settings 在桌面900×700／手機320×640切聊天、捲動並保存 H 已通過 widget 測試；default SharedPreferences adapter 使用 mock 平台資料驗新 controller 重讀／reset 及其他設定保留；兩個 feed 共用鍵位同步、不搶焦點與正確對象回呼已驗。六份32項全過，詳 keyboard API/storage 清單。只有測試與紀錄變更，無 OAuth/token／API／schema／真人動作。

本輪唯一 analyze 無問題。下一單元直接 MOD 動作快捷入口與確認／權限 gate，不重複把基本接線當完整功能；低高度／字級、真人 Windows／Android 與原私訊官方列表、雙向及可靠 ID 仍未驗完。整體目標 active，未宣告完成。

### 2026-10-04 最新續接：鍵位設定介面與App chat入口

App聊天分類新增五命令選鍵／停用、保存結果／衝突與錯誤、reset明確確認；用原共享controller与schema，晚回應／controller替換隔離。5新320px及失敗／corrupt／關閉時序widget，五份29項全過，未改API／token／hash／保存key或真人資料；完整規則詳keyboard清單。

下一輪真Prefs mock roundtrip與兩feed同步，補完整settings tab入口及低高度／字級測試。現有App入口是靜態接線與編譯、card為fake保存UI測試，非完整App／實機驗收。原直接MOD鍵／組合鍵、私訊真人双向與可靠ID、完整全工作包仍未完成，goal active。

### 2026-10-04 最新續接：自訂鍵位保存核心已接dispatch

新增獨立key/schema的串行讀存controller，完整五命令、唯一鍵／停用、壞資料鎖修改直到明確reset、保存成功才發布；feed／wrapper／pane讀同新binding並解除舊listener。4fake存儲與1實際feed重綁測試，四份24項全過；前輪watch fixture警告已局部標註測試用途。無API／token／hash或真人操作，完整規則詳keyboard API storage清單。

唯一analyze無問題。尚未接App設定UI，下一輪接選鍵／停用／重設確認及保存錯誤，再驗實際Prefs／兩feed同步。直接制裁鍵與組合鍵／角色context／實機、原私訊雙向及完整工作包仍未完成，goal active。

### 2026-10-04 最新續接：watch鍵盤權限呼叫已修

修上輪panel函式對bool比較，呼叫可空API canModerate回呼，缺API／回呼保持拒絕。2新真WatchChatPanel→area→list→feed widget驗原gate多次呼叫、K最新→U原user callback與撤權即時false；缺gate不提供pane focus。原role旗標不代替API閉包，無API／token／保存或真人操作。

三份19項全過，唯一analyze 0errors／1warning（docs新watch test:46，setMockInitialValues測試專用API標註），未循環修正；詳keyboard API storage清單。下一輪先處理fixture警告再做自訂鍵位與獨立儲存／衝突校驗，不把此接線當主觀看頁真人實機完成。原私訊真人列表／雙向／可靠ID、直接MOD鍵確認與全部工作包保持未完成，goal active。

### 2026-10-04 最新續接：MOD初始鍵盤入口，watch接線須先修

修前輪5大括號提示，feed新增可選權限回呼與pane Tab→J／K聚焦最新；只primary／KeyDown／無修飾、事件及frame後核權限。5新widget，含撤權及兄弟TextField不搶字母，連回歸17項全過。

watch panel→area→list接線本輪唯一analyze有1 unrelated_type_equality_checks info（panel:534）：canModerate是bool Function()?卻與true比較，實際watch入口仍不可用，按規則留下一輪先修可空回呼呼叫並補adapter證據；不得將fake feed成功冒充watch完成。無新API／保存／真人操作。直接動作鍵／自訂鍵位保存、角色context生命週期与私訊真人雙向及全工作包仍未完成，goal active。

### 2026-10-04 最新續接：J／K跨lazy訊息導航

實際feed接聚焦列K舊／J新及邊界，含divider反向index用ListController逐項定位，frame後移焦點；generation隔離晚callback，鍵盤瀏覽保留選取不被live／晚follow推走，原恢復最新／Esc解除；節點依source／visible快照淘汰並dispose。無API／保存／真人操作。

2新長清單／時序widget、連原鍵盤與訊息管理12項全過，唯一analyze 0errors／0warnings／5格式infos（message_list:308、363、466、475、487），留下一輪補大括號。詳keyboard API storage清單，不宣稱未聚焦J／K MOD入口、直接制裁鍵／配置保存或實機已完成；私訊真人雙向與可靠ID及全工作包仍未完成，goal active。

### 2026-10-04 最新續接：聊天訊息鍵盤入口

重新核對上游 chatModController／commands，現有 watch 聊天原無訊息快捷入口。實際 feed 新增局部可Tab聚焦列，U開原user card、Enter開原context、Esc解除；只primary focus、不搶TextField子焦點或修飾／重複按鍵，不直接寫MOD API。3新widget＋原訊息管理共10項全過，詳 twitch-chat-keyboard-api-storage.md，無新API／持久化／真人操作。

下一單元仍需J／K訊息導航／lazy捲動、直接動作確認與可配置鍵位／存儲，不能將局部入口當全部StreamNook快捷鍵完成；原私訊真人雙向／可靠ID與全工作包仍未完成，goal active。

### 2026-10-04 最新續接：單筆管理動作確認矩陣

16新widget覆蓋固定／自訂禁言、封鎖／解除，各成功、取消及確認中target升MOD／消失。發現自訂禁言確認漏原因，保留原斷言並補捕捉原因與可捲動確認內容；五份81項全過，唯一analyze無問題。無API／保存／token／hash或真人操作，非官方實際制裁或實機證據。

下一輪回桌面快捷鍵的現有接線與可配置工作，不再以相同管理矩陣替代缺口；仍需長理由／低高度、其他context即時目標角色與實機。原私訊真人列表／雙向／可靠ID及全部工作包保持未完成，goal active。

### 2026-10-04 最新續接：手機選取與單筆目標角色缺口

3新user模式測試驗範圍51整次拒絕、320×640／844×290字級1.3觸控拖曳及開表單，非實機或全部拖曳上限證據。核對原單筆封鎖／解除已存在，不另做重複 API；發現管理面板確認後未重查目標，補目前可見訊息保守角色 gate，警告／禁言／封鎖／解除包括自訂時間均送出前檢查，失權由原自身gate負責。

2新警告確認中target升MOD／消失測試零送出，五份65項全過，唯一analyze無問題。沒有新API／保存或真人操作。下一輪先核對同一保護在固定／自訂禁言及封鎖解除的實際入口，再回桌面快捷鍵與原完整聊天工作包；不得把未實作批次永久封鎖當作原單筆功能也不存在。私訊真人雙向／可靠ID、雙平台等完整門檻保持未完成，goal active。

### 2026-10-04 最新續接：使用者多選功能缺口已補

批次面板提供訊息／使用者模式；缺官方 message ID 的合法使用者可選，刪除仍用原 canDelete。資格涵蓋同人角色矛盾／原來源／echo保護，範圍與拖曳走同模式 policy；切模式清空選取與手勢狀態。Ctrl+Enter 在 user 模式只開表單，不刪除或確認。快照資格快取僅本機記憶體，寫入仍重新檢查原 context／當前目標，不改 API／保存。

3 新功能 widget、五份 60 項全過，唯一 analyze 無問題；無真人操作。下一單元完成 user 模式手機／拖曳／上限必要證據後回核對剩餘 MOD 動作及原完整聊天工作包，非持續增加同類測試來宣告全對齊。原私訊真人列表／雙向、可靠 ID、雙平台與其他完整門檻保持未完成，goal active。

### 2026-10-04 最新續接：使用者批次生命週期證據

僅新增 8 項面板操作測試：成功禁言固定秒數／理由且每人一次、停止及關閉的晚成功／晚失敗矩陣、第一人後失權、明確拒絕与結果不明停止不重送。五份管理回歸 57 項全過，唯一 analyze 無問題；沒有改 UI／API／存儲或操作真人。不是所有手勢或實機證據。

下一輪補真正使用者選取模式：父面板目前初選／範圍／拖曳／列表仍依 canDelete，缺官方 message ID 就無法進入，雖 user 核心只需有效 user ID。新增模式須維持刪除的官方 ID 保護、切模式不殘留不合法選取、原角色／context／50 上限；不以繼續增加相同生命週期測試取代此功能缺口。其他批次／實機／原私訊真人雙向與可靠 ID 等完整門檻仍未完成，goal active。

### 2026-10-04 最新續接：批次禁言／警告已接面板

動作／原因／秒數表單、去重使用者預覽與原頻道確認、逐人結果及停止已接上批次入口。watch 與管理面板供應固定原 context 權限及目前可見訊息的保守目標資格檢查，缺資料或受保護角色提示拒絕；不冒稱官方即時角色查詢。沿原 API，無新 endpoint／scope／hash／保存／真人操作，詳批次 API storage 清單。

新增 4 項 policy／操作／父入口測試，五份管理回歸 49 項全過；本輪唯一 analyze 無問題，並處理前輪格式提示。下一輪驗成功禁言、停止／關閉／未知回應生命週期，補目前仍需官方 message ID 的使用者選取缺口。永久封鎖／解除、可配置快捷鍵、完整實機與原私訊真人雙向／可靠 ID 等門檻仍未完成，goal active。

### 2026-10-04 最新續接：批次禁言／警告核心

沿原ban與warn API新增使用者批次計畫及執行，固定reason／duration、user去重、選取內同人任一受保護角色提示全部排除、自身／台主／MOD／其他來源／echo保護，timeout必有範圍內秒數、不退成永久ban。與delete共用串行／單次計畫／停止runner以保留安全規則，executeUsers必需逐筆動態canManageTarget，false不寫入該人並停止。無新增API／scope／hash／持久化或真人操作，尚未接App UI，詳batch API storage清單。

6新fake測試及原delete9核心15項全過，四份管理回歸45項全過。唯一 analyze 0errors／0warnings／1info（batch controller:217，多行if throw缺大括號），按規則不反覆修正。下一輪先補格式提示，再接動作／原因／禁言時間表單、user預覽與確認、原context動態角色檢查及結果UI；永久封鎖／解除等尚未做，不將核心當App可用。拖曳最大範圍、實機、原私訊真人／可靠ID與其餘原工作包门檻仍未完成，goal active。

### 2026-10-04 最新續接：拖曳失權立即停止與小尺寸預覽

拖曳timer原等post-frame選取才查權限，3新測試發現撤銷後仍多捲88px；改每tick捲動前先查permission，失效停timer／提示，不能以shortcut進入可送出預覽。320×640、844×290字級1.3觸控模式控制區移動／列拖曳／邊缘選取／預覽無overflow，進預覽退出拖曳模式，恢復正常捲動。沒改API／保存／token／播放器或直播runtime，無真人操作。

四份39項全過；最後預覽physics小修後重跑2尺寸全過，本輪唯一 analyze 無問題。完整證據與局限見batch清單，非實際Android或所有字級／最大拖曳。下一單元核對拖曳上限與後續批次禁言／警告的preview、對象去重、角色保護及原因／duration，沿現有API而不變更協議；仍須實機、原私訊真人／可靠ID與其他工作包門檻，goal active。

### 2026-10-04 最新續接：批次拖曳與逆向取消

處理上輪test格式提示。面板新增預設關閉的拖曳開關，固定pointer-down起點與初始集合、回拉恢復baseline、50／policy／permission檢查；局部viewport手勢與邊缘timer自動捲動，不因lazy起點列卸載中止，結束／關閉／失權停timer，拖曳時快捷預覽不作用。開關關閉維持原捲動，沒有改直播／播放器runtime、API或存儲，僅批次面板記憶體。不是直接直播清單拖曳。

3新測試含逆向range取消至0、touch拖曳回拉、mouse邊缘捲動及拖曳中dispose；首次drag測試揭露pan-start取錯起點、門檻事件未更新末端，修成down起點＋start當前位置而非放寬斷言。四份36項全過；最後僅補兩處大括號，唯一 analyze 無問題。詳batch清單，無真人操作；尚需拖曳最大範圍／失權／各尺寸深入時序與實機驗證，再擴其他批次動作／聊天工作包。原私訊真人列表／双向、可靠ID與全部原門檻維持未完成，goal active。

### 2026-10-04 最新續接：批次局部快捷鍵与範圍選取

面板內Ctrl+Enter只開預覽，沒有快捷批准刪除；Shift點選依上次端點選／取消範圍，手機可用範圍模式點兩端，切模式清anchor。範圍排除不合法訊息、總選取超50整次拒絕保持原集合，保留原逐項選取。所有新狀態只在面板記憶體，不新增API／schema或更動IRC／登入／runtime；不是直播清單拖曳。

3新widget驗桌面Shift及手機範圍模式跳過共享來源、Ctrl+Enter預覽後重按不開確認／無寫入、51則範圍原子拒絕。四份回歸33項全過；唯一 analyze 0errors／0warnings／1info（batch panel test:144，多行if缺大括號），依規則不循環修正。下一輪先補格式提示，再補範圍取消／逆向與拖曳工作流，繼續其他批次／原聊天工作包；目前不宣稱可配置快捷鍵、完整直播多選或真實裝置完成。原私訊真人與可靠ID、其他完整门檻保持，goal active。

### 2026-10-04 最新續接：訊息管理直達批次與選取邊界

既有訊息context管理選單增加批次入口，僅canDelete合法訊息且提供回呼才顯示。watch捕捉原runtime、重新核對原API固定owner/channel/runtime permission，開批次快照帶原官方ID；面板預選合法相符項，不直接預覽／確認／提交，角色已失效不開啟新頻道批次。沒有改原長按／右鍵協議、IRC／API／token或存儲。

3新測試驗context選單直達預選零發送、51筆逐項選滿50停用額外項且取消仍可用、來源ID／頻道tags與list突變不改快照／送出目標。四份回歸30項全過，唯一 analyze 無問題。完整watch／直播卡長按或右鍵事件鏈仍非此次mock證據；詳細狀態列batch清單。下一單元接批次局部快捷鍵／範圍選取，再核對拖曳、多種批次動作及其他原聊天工作包；原私訊真人列表／雙向／可靠ID與雙平台等門檻保持，goal active。

### 2026-10-04 最新續接：批次刪除介面接線

修前輪controller格式提示，新增批次選取→固定預覽→不可復原確認→結果／停止面板，從既有聊天室管理入口開啟，沿原watch固定owner/channel/runtime closure，不改watch／IRC／播放器runtime。來源tag與清單開啟時複製，選取限50、不合法項禁用，顯示原文／ID及每筆狀態；取消確認與失權不發送，關閉只停後續，未知結果停止且無直接重送。UI／API／僅記憶體保存規則見 twitch-moderation-batch-api-storage.md。

面板7項＋核心9項＋原管理面板5項共21項全過；涵蓋桌面900×700、手機320×640、短橫向844×290，實際打開父管理入口、權限在確認中撤銷、未知結果、進行中停止／關閉。首輪framework ListTile ink祖先assert修局部Material，舊warning測試因新增入口lazy元素未build改scrollUntilVisible，未知結果斷言改精確目标b而非同樣含未送出說明，不屏蔽例外。唯一 analyze 無問題，沒有真人操作、新API／hash／token／schema。下一步核對最大選取／來源突變等邊界，接訊息長按／右鍵直接選取及快捷鍵／拖曳，再擴其他批次動作；完整watch／雙平台及原私訊真人／可靠ID仍未驗收，goal active。

### 2026-10-04 最新續接：批次管理缺口與刪除執行層

處理上輪身分面板測試格式提示。讀回訊息卡與context／管理動作，手機長按、桌面右鍵／點擊入口已有，未找到批次或快捷鍵接線；不重做原單筆功能。新增 TwitchModerationBatchController：沿原刪除API，固定不可變預覽ID／名稱／原文，最多50選取、原policy排除與去重、衝突拒絕；每筆串行間隔350ms、權限核對、計畫一次、防重入／舊計畫，取消只停後續，拒絕或unknown停止且不自動重送，無虛假復原。

API／記憶體狀態完整列 docs/twitch-moderation-batch-api-storage.md；無新API／scope／存儲／憑證或真人操作。新9項核心測試全過；新增dispose測試前批次＋身分共34項全過，未宣稱最新合併35項命令已跑。唯一 analyze 0errors／0warnings／1info（batch controller:104，多行if缺大括號），依規則不循環修正。下一輪先補大括號，再接選取預覽／不可復原確認／結果與取消UI，固定watch原owner/channel/runtime；之後快捷鍵、拖曳與其他批次動作，不能將目前未接App的核心當完成功能。原私訊真人／可靠ID與全部工作包门檻保持，goal active。

### 2026-10-04 最新續接：徽章手動刷新確認與手機身分操作

直接核對watch回呼發現外層仍立即顯「已套用」且先額外刷新，使面板自己的accepted/readback分離不完整；改外層只回報提交接受，拿掉重複刷新，由面板統一讀回確認。沒有改runtime、GQL query／hash、登入或API。面板以記憶體_pendingBadgeId／_pendingBadgeChannel追蹤本次已接受提交，手動刷新只有同頻道selected badge ID相符才確認，null／其他頻道不清目前資料，失敗保持已提交／勿重送提示；新的徽章預覽不被舊確認文字覆蓋。欄位只活在該面板State、不持久化、不新增key／schema，關閉後由下一次讀回實際配戴，不自動重送。

5新widget透過提交→header重新整理涵蓋確認／舊資料／null／其他頻道／拋錯，submit恆1、讀回2，仍有原徽章可選；2新尺寸測試涵蓋320×640鍵盤240、844×290鍵盤100、字級1.3，驗色碼提交／授權錯誤／草稿／關閉且無overflow。身分兩份26項全過；外層watch改動為靜態接線證據，非完整watch實機。唯一 analyze：0errors／0warnings／1info（docs/twitch_chat_identity_panel_test.dart:143，if缺大括號），未修後重跑。下一輪先補格式提示，再回原工作包核對MOD快捷鍵／批次及聊天事件未覆蓋項，不以身分mock當全面完成。私訊真人列表／雙向、可靠ID、WindowsAndroid與其餘原門檻仍保持，goal active。

### 2026-10-04 最新續接：色票提交與身分面板關閉生命週期

修正上輪160／416兩處if大括號提示，未更動身分API／儲存或版型。新增2項面板實際操作測試：預設blue色票預覽為#0000FF但送出官方名稱blue；自訂無效#123停用套用、合法#abcdef才可送出；預覽及尚在等待不寫入／不顯示成功，callback完成才回報更新並解除busy。

新增6項關閉測試：顏色提交、徽章提交及接受後刷新，各涵蓋晚成功／晚失敗；透過實際關閉按鈕pop面板，確認沒有dispose後setState、沒有額外重送或在已關閉時啟動badge刷新。這是原mounted防護的驗證，不另造取消已送出的網路操作。身分面板及顏色API合計19項全過，本輪唯一 analyze 無問題。没有真人／裝置操作，不將mock當Twitch配戴或實際顏色驗收；原私訊與全面對齊門檻維持。下一單元核對身分面板手機鍵盤／低高度，以及提交未確認後手動重新整理的狀態回饋，再按原工作包補齊其他缺口。

### 2026-10-04 最新續接：聊天身分操作互斥與顏色授權測試

徽章與顏色原可同時提交、互相覆蓋共用結果文字；面板改為同時只處理一項身分更新，重新整理／色票／色碼輸入／套用按鈕與方法入口均尊重 loading、徽章等待及顏色等待。沒有更改版型、API、token／持久化或真實帳號。2新widget驗等待期间另一套用入口停用、色碼保持、顏色權限錯誤原文、徽章拒絕不刷新且保留草稿可重試；測試第二次點擊最初因錯誤框改變高度未命中，加入捲動後等待及實際可見定位，不忽略警告。

新增 twitch_chat_identity_api_test.dart，使用現有預設 client 搭配假 HTTP adapter，4項驗不同owner／缺scope跳過、有權限同帳號用驗證client-ID且PUT參數正確、400／403拒絕不成功也不換token重送。連同面板本輪11項全過，不宣稱真人驗收或所有錯誤支援。本輪唯一 analyze：0 errors、0 warnings、2 infos（special_message_sheet.dart:160、416，if多行return缺大括號），exit1；依規則未循環修正或重跑。下一輪先補兩處大括號，再核對預設色票／自訂色碼預覽、成功及關閉等待面板的生命週期。私訊真人Web列表／雙向、可靠ID、WindowsAndroid及原其他功能門檻保持未完成，goal仍active。

### 2026-10-04 最新續接：徽章提交與目前配戴確認

核對既有聊天身分面板，修正徽章套用已接受卻因重新讀取失敗顯示一般更新失敗，以及讀回舊狀態仍宣稱已套用。接受後清除草稿並顯示已提交；只有同頻道讀回所選徽章 ID 才顯示已套用，不同頻道回應不替換目前資料；讀取失敗明示請重新整理、勿直接重複套用。沒有新增 API、修改 hash／token／儲存、變更版型或使用真人帳號。

新增 twitch_chat_identity_panel_test.dart，透過實際開面板、預覽與套用按鈕，驗證讀取拋錯／null／舊狀態／確認相符／其他頻道共5項。首輪測試定位到 TextField 的 Scrollable 與尚未建立的 lazy 按鈕，改為面板 ListView 捲動，不略過 UI 操作。與六份管理紀錄回歸合計61項全過；本輪唯一 flutter analyze 無問題。這是模擬提交／讀回證據，非真人徽章、Windows／Android或整體完成。長時間目標維持 active；私訊真人列表／雙向、可靠送出 ID 與其餘原範圍門檻不變。下一單元核對顏色套用及徽章拒絕／等待期間的操作回饋。

### 2026-10-04 最新續接：長時間目標重建與管理事件來源呈現

使用者指出長時間任務入口消失並要求重開續作。實際 get_goal 回傳 null，不是專案檔案遺失；已依使用者明確要求以原完整目標重新 create_goal，回傳 active，不另開聊天或重做已完成項目。中斷前尚未驗證的面板修改仍在，這輪讀回並完成測試。

管理紀錄：空白user_name原先阻止回退login／ID，現採第一個非空名稱，並顯示原官方使用者ID；搜尋含broadcaster與共享source ID，不把共享事件當本頻道來源。4新widget測試驗共享來源搜尋／原刪訊換行、空白名稱回退login／ID、未知action明示官方動作／未提供詳情、已知warn缺details不造目標。沒有改事件payload、parser、archive schema／key或API；沒有讀真人事件／發送管理操作。

六份MOD紀錄回歸56項全過，本輪唯一 analyze 無問題。長時間目標保持active；私訊真人Web列表／雙向／WindowsAndroid與可靠ID、MOD完整watch／實機及原其他功能門檻仍未完成。下一輪按原路線圖繼續盤點聊天身分／互動與事件工作包，維持已列出的私訊剩餘門檻，不把面板細節當全面完成。

### 2026-10-04 最新續接：管理紀錄已開面板的context隔離

直接讀取watch頁chat接線：chatController listener 呼叫 syncModerationLogContext；context以moderator/channel/login與runtime判斷變更，無權限stop、force明確重連；canModerate closure固定原runtime／viewer／頻道且要求mounted，dispose移除listener並dispose log controller。未修改watch或播放器runtime；此是靜態接線證據，不是完整watch widget／實機驗收。

新增真實controller＋面板整合測試（假授權API／receiver／memory archive）：面板開著時start新owner/channel先清舊列／顯示loading，停止原receiver；新授權gate完成後新列顯示，舊callbacks／status不更新新畫面，disk分partition，stop後事件忽略。初始化runAsync跨fake queue首次卡住，核對並停止該指定Dart test process後改逐幀等待＋明確完成斷言，沒有略過帳號隔離斷言。六份管理紀錄回歸52項全過，唯一 analyze 無問題；没有真人／平台操作、新API／schema／token變更。完整watch渲染／角色與runtime真切換仍須驗收，私訊原真人與ID門檻保持未完成。

下一單元：依原工作包核對管理紀錄角色／未知action與共享來源的面板呈現，再對照聊天身分／互動／事件等原功能缺口；不把控制器面板整合當所有功能完成。

### 2026-10-04 最新續接：管理權限失效與待存紀錄

上一輪2項protected notifyListeners警告改由fixture subclass的setSaving方法通知，不新增ignore。直接核對EventSub服務已有_allowed失效停止socket，以及相關測試；不重做原停止機制。新增controller測試：失效前已接收但write失敗的事件留待存，失效後事件不進列表／磁碟；僅本機retry可保存原已接收紀錄，不是重新取得管理權限；無權限start不開receiver，恢復權限再start讀回原紀錄。測試發現角色／頻道失效被誤報登入owner不符，controller拆開條件，提供正確原因，真正owner mismatch仍原樣拒絕。

六份MOD紀錄回歸51項全過；本輪唯一 analyze 無問題。没有更動token／授權儲存、事件協議或archive欄位／key，也没有使用真人帳號。此為controller與fake socket證據，完整watch context listener、實際角色撤銷與雙平台仍須驗收；私訊真人／可靠ID門檻及原其他功能範圍保持未完成。下一步核對watch管理紀錄context切換及面板已開時狀態更新，不以mock當完整生命週期完成。

### 2026-10-04 最新續接：管理紀錄保存防重入

controller retrySaving 原可反覆把同批待存事件排入寫入佇列；新增 generation 隔離的 saving 狀態，保存中／loading／沒有待存資料時不再次啟動。try/finally 解除當前操作狀態，stop 重設當前狀態，舊 generation 完成不重設新畫面。面板保存中停用重試按鈕並顯示「正在保存…」，失敗仍保留錯誤與待存資料供後續重試。没有變更 archive schema／key／API／token 或既有 accepted writes 原 partition 完成規則；不宣稱處理所有自動寫入與手動重試間去重。

3新controller測試驗反覆activation只寫一次、失敗解除busy並成功重試、換owner晚完成只存原partition；1新UI測試驗按鈕禁用／進度及錯誤保留。六份MOD紀錄回歸50項全部通過。本輪唯一 analyze：0 errors、2 warnings（panel test:73／81 呼叫 notifyListeners 的 invalid_use_of_protected_member），exit1；依每輪一次規則未重跑或循環修正。下一輪先把fixture狀態通知移入subclass公開方法（不以豁免隱藏warning），再核對權限失效與管理紀錄watch生命週期。私訊真人／可靠ID與其他原Twitch工作包仍未完成，無真人管理或資料寫入。

### 2026-10-04 最新續接：有資料的管理紀錄與低高度操作

重新核對原路線圖：AutoMod 佇列／片段及管理紀錄 API、收件、archive、controller／watch入口已有實作，不重做或冒稱原本缺失。管理紀錄面板先前只有空面板尺寸證據；本輪補12筆假事件的桌面900×700、手機320×640字級1.5鍵盤280、横向844×290字級1.3鍵盤100搜尋／分類／無結果流程。重現横向底部46px overflow，改控制區和紀錄共用 CustomScrollView／SliverList，列表仍lazy且狀態／錯誤／重試入口保留，未改API／事件／儲存／權限。

3新widget測試驗搜尋大小寫與空白、指定目標／原因、分類排除使用者事件、無結果但原12筆不變；分類操作先取消搜尋焦點再等待捲動，不忽略hit-test警告或放寬斷言。六份MOD紀錄回歸46項全部通過；本輪唯一 analyze 無問題，之後僅改測試焦點等待，未重跑analyze。沒有讀取真人事件或執行真人封鎖／清聊天室。

私訊仍缺真人 Web 列表／雙向／WindowsAndroid與可靠local↔official ID證據，沒有勾成完成；本輪依原路線圖核對可安全完成的管理紀錄裝置操作缺口，未用MOD進展取代私訊門檻。下一步核對管理紀錄面板／watch生命週期與保存錯誤入口、原其他Twitch工作包；最終實機需驗手機keyboard與分類、長事件／共享來源、保存重試與角色撤銷，模擬面板不代表實機或完整watch驗收。

### 2026-10-04 最新續接：刪除寫入與重新載入结果分離

F 清理找到已刪成功後read失敗仍顯一般儲存失敗／殘留舊列，已改固定提交結果、成功先移除可見目標、後續讀失敗明示不必重複刪除；寫失敗保留原資料／可重試。3新mock含 gate 固定刪除中收到同peer與其他peer訊息，新收件各保存1筆、其他草稿保留。七份252全過，唯一 analyze 無問題；契約／非跨程序與真實驗收限制見儲存清單。下一步重新核對 A—F 的可實作缺口與真人門檻，按原路線圖銜接其他Twitch工作包，不因清理測試當作全部功能完成。

### 2026-10-04 最新續接：精簡版對話管理與刪除帳號固定

F／手機分類直接核對發現精簡版缺本機刪除入口。沿用原一個header按鈕，提供對話操作／歷史選單，更新對象資料與本機刪除共用；有history API才顯示遠端項目，不新增header寬度。刪除確認框可捲動，沿原不可復原／只刪本機說明；開確認時固定owner，切帳號不刪新owner同peer。選單亦固定建構時owner，舊選單換帳號不執行。4新mock涵蓋取消、確認、確認中換帳號、選單中換帳號，確認本機紀錄移除與另帳號草稿不動；原精簡profile測試改從實際選單操作。七份249項全部通過，唯一 analyze 無問題。沒有刪使用者資料或做真人操作，無新 API／儲存格式；真人／雙平台與可靠送出 ID 門檻仍在。下一步核對清理失敗回饋／正在收件與清理的生命週期，以及原 A—F 與其他工作包，不以入口補齊宣告整體完成。

### 2026-10-04 最新續接：精簡私訊錯誤可讀取

直接核對 B／C／F 發現共用 errorText 只顯示於一般版；精簡橫向／低高度版沒有入口。出錯時精簡標題區現提供錯誤詳情按鈕，開可捲動對話框讀完整原因，關閉不清錯誤、不重送、不動草稿／歷史。沒有增加控制列高度、改儲存／API／授權。3新測試涵蓋390×260字級1.4、320×640鍵盤250字級1.3、壞archive保持原文；七份245項全部通過，本輪唯一 analyze 無問題。真人 API／雙平台與可靠送出 ID 關聯仍未完成；接續整體 A—F 與分類門檻核對，不以精簡版錯誤入口當私訊全面驗收。

### 2026-10-04 最新續接：列表搜尋與背景收件核對

直接核對私訊 B／E 的列表：最近、名字、本機未讀排序已有實作；新增桌面1000×760與手機390×844操作測試，驗證三種排序、忽略大小寫與前後空白的搜尋、篩選時仍收件／未讀增加、清除搜尋後內容與排序更新。修正無匹配結果卻顯示「尚無本機對話」的誤導，改顯示沒有符合搜尋的對話。沒有更動列表版型／新增持久欄位／API／授權。七份私訊回歸242項全過；本輪唯一 analyze 無問題。真實列表／雙向收發／雙平台仍未驗收，可靠送出 ID 關聯未解；接續按 A—F 與原其他工作包區分可實作缺口及真人驗收門檻，不把模擬通過當全面完成。

### 2026-10-04 最新續接：新匯入對話的遠端狀態隔離

修正新 peer 備份沿用遠端未讀／歷史游標／已完成標記：新對話還原內容與草稿，遠端狀態從未同步開始；既有對話及後續同步進度不被重複匯入覆蓋。2項重啟／原子失敗／新游標測試，七份240項全過，本輪唯一 analyze 無問題，細節見儲存清單。仍缺可靠送出 ID 關聯、真人 API 與双平台證據；下一步核對私訊資料管理與原 A—F 剩餘要求，不以備份局部修正宣稱整體完成。

### 2026-10-04 最新續接：匯入與live提升提示

查閱官方發送／EventSub及StreamNook send實作仍未找到可靠local↔official ID關聯，不猜配刪記錄。實際修backup匯入假新訊息提示、新ID標historicalOnly及同ID首次live不增count漏提示；3新測試雙尺寸anchor／未讀一次與重啟／同文不同ID保留，來源與最終驗證見儲存清單。仍有真人列表／雙向／WindowsAndroid背景／送出ID關聯門檻，後续核對原A—F未證明項及其餘Twitch工作包，不宣稱完整完成。

### 2026-10-04 最新續接：鍵盤與低高度history閱讀

history anchor矩陣擴到10項、加6項，涵蓋320手機keyboard/scale1.3、844横向keyboard及390低height/scale1.4；三頁原anchor≤1px，live後未讀1／閱讀位置保留，點返回最新才已讀0，輸入在鍵盤上。找到並修general可用高度不足及compact新訊息提示擠掉scroll，緊湊判斷考慮字級／keyboard。完整證據與最終結果見A—F audit；非真人Web／Windows／Android保證。接續仍需可靠送出ID與真人API證據、雙平台/原其他Twitch門檻，不因已有mock縮小目標。

### 2026-10-04 最新續接：大量歷史重讀與重寫減量

archive以每次來源read後相同owner/raw的單一immutable snapshot重用，外部變更／壞檔／刪除／讀失敗不以cache隱藏；相同草稿／已讀0不整份重寫。3新mock含3MiB資料20次無變更操作零寫入，真正改草稿保存。仍非分區磁碟／手機RAM保证，詳儲存清單；原私訊A—F核對仍有真人Web列表／双向／Android背景與可靠送出ID等門檻，不以性能小修縮小原目標。下一步核對真功能剩餘證據與低高度／鍵盤歷史閱讀組合，再接原其餘Twitch工作包。

### 2026-10-04 最新續接：大型備份可還原的對稱容量

本機歷史檢查發現export不限／import僅2Mi字元、自己的大型備份不能回復；兩端改同一預設32MiB UTF-8预算，輸入不強制裁切、容量錯誤明示，原資料不刪。3新測試驗實際3MiB roundtrip／byte邊界／App錯誤。不是全archive限制／任意大小還原／Android記憶體保證；下一步大歷史分份／檔案備份及記憶體策略、真人双平台／原完整功能門檻仍須核對。儲存完整規則見清單。

### 2026-10-04 最新續接：缺口待存確認不重播舊會話

已保存事件碼原留待存 map、切回會覆寫新會話；改 archive 回傳保存／取消結果，controller僅確認同碼且不清較新信號，已開始提交跨owner完成亦可確認原owner。4新 mock，詳見儲存清單。下一步本機／metadata 成長与全部儲存故障策略、真人私訊完整收發／雙平台與其餘原對齊門檻；不擴掃 repo、不改 token／hash／協議／播放器。

### 2026-10-04 最新續接：缺口識別與裝置時間分離

真正斷線與新會話保存獨立128-bit事件碼，恢復快照同步保存／比對；時鐘倒退或同時間不同信號不再被 timestamp 先後忽略，同事件重試不旋轉。新增4項 mock，欄位與相容／限制列於 twitch-whisper-api-storage.md。仍未實機 Windows／Android／真人 API；下一步核對待存事件跨會話順序、全部本機資料成長／儲存失敗，以及原真人完整收發與其餘功能門檻，目標不縮小。

### 2026-10-04 最新續接：新缺口重開完整恢復

receiveGapObservedAt 與工作 gapObservedAt 快照分離最早 gap；新斷線／新會話不能沿舊 cursor 跳過先前 peer，下一次完整恢復從列表頭開始，途中／末頁新缺口不報成功。待存缺口未補存前不發恢復请求。資料保留，gap 不清；6新 mock，詳細契約／驗證紀錄見 twitch-whisper-api-storage.md。裝置時鐘異常、真人雙平台／完整收發與其餘原目標仍待核對，繼續保持完整範圍。

### 2026-10-04 最新續接：正常重開會話標記

原 owner archive 新增可選 receiveSessionStartedAt，下一生命週期保守記錄可能離線區間；一般同帳號刷新不旋轉、原訊息／草稿／游標／恢復工作保留、失敗提示與重試、舊資料相容。完整儲存契約列於 twitch-whisper-api-storage.md。此標記不代表精確漏訊息或已補齊；新 gap／工作覆蓋語意、真人雙平台與其餘 Twitch 對齊仍未完成。

### 2026-10-04 最新續接：history遠端容量原子拒絕

逐peer歷史同步也檢查帳號500peer/20MiB conversations payload，超限不改原JSON/草稿/未讀/gap/cursor/job；App顯示明確容量與逾時理由、不自動重試。5新測試、七份205全過；唯一analyze0errors/0warnings/1測試大括號info（307），未再跑。非全部本機/metadata硬上限，正常離線窗口/新增gap覆蓋、實機重啟/timeout、真人API與其餘Twitch仍需完成，下一輪依原範圍續接。

### 2026-10-04 最新續接：全peer恢復可由 App啟動

Home controller與一般/低高度私訊menu接恢復/進度/取消/原頁續接，磁碟checkpoint載入、保存中不可取消、衝突操作鎖與owner生命周期隔離；完成不清gap、不宣稱Twitch完整保留範圍。6新controller/3尺寸測試，七份200全過；唯一analyze0errors/0warnings/1info（144），最後busy通知/send disabled微調未重跑analyze。上一輪「未接線核心」已處理。下一步容量/正常離線窗口/新增gap覆蓋/重啟與timeout流程，真人雙平台及其餘功能仍未完成，原目標不縮小。

### 2026-10-04 最新續接：全peer恢復核心與同頁保存

新增receiveRecovery持久工作：全thread列舉、本機+未知peer逐歷史頁、頁資料與下一進度同次保存，獨立於瀏覽cursor；取消/45秒待讀timeout/原頁續接/owner與循環檢查。8新測試、七份194全過；唯一analyze0errors/0warnings/11格式infos，未再跑。尚未接controller/UI，下一步完成可用App進度/取消/重試流程，不能把核心mock當實機完成。gap保留，complete僅當次可讀API游標耗盡；正常離線窗口、總容量、新gap與真人雙平台仍需核對，原目標未縮小。

### 最新續接：已保存的缺口可跨重啟恢復

owner archive version1新增optional receiveGapSince，保留最早已知缺口及既有cursor/草稿/未讀；clearSession不删已保存metadata，新store/controller/session恢復提示，寫入失敗載入重試，非法資料拒絕且原檔不覆寫。3新測試，最終六份回歸186全過；唯一analyze於最後讀取/測試等待調整前0errors/0warnings/1info，未再跑。仍缺正常離線窗口、全peer恢復工作與checkpoint/取消/續接，真實/雙平台未驗收。下一輪實作恢復工作列舉與持久進度，不把已知gap保存當全部訊息恢復。

### 最新續接：已重連不等於歷史已恢復

EventSub typed owner缺口信號接到controller，不靠文案猜狀態；一般面板與低高度警告選單提供列表/目前對話歷史同步，單頁成功不清標記，正常server交接不誤報。4新測試/既有EventSub擴充，六份回歸183全過，本輪一次analyze無問題。尚無跨App退出缺口checkpoint/所有peer斷線區間完整補齊；下一輪核對完整恢復流程而非以入口當結案，真人Web/收發/雙平台門檻仍未完成，保持原目標範圍。

### 最新續接：背景收件保存失敗不再立即丟事件

新增owner/官方whisper ID記憶體暫存，重新載入補存、成功後移除；去重未讀/通知，隔離owner，通知callback故障不阻擋後續。容量500事件/512Ki本文codeunits，超限需恢復儲存後同步歷史，無持久/定時retry保證。通知使用已保存最新profile，首次回歸舊名失敗已修正。4新測試、六份回歸179全過；單次analyze0errors/0warnings/3大括號infos（test611/616、controller125），未再跑。下一步核對斷線缺口提示／歷史恢復入口；未收到App的事件、真人與雙平台仍未完成。未改限制內協議/token/hash。

### 最新續接：私訊提交結果與持久化狀態分離

已接受但未存的結果按 owner/原訊息ID暫存，顯示「已提交・尚未儲存」；儲存恢復僅條件更新仍存在的原訊息，不重建已刪對話、不重發。換帳號隔離、切回補存，clear/dispose清暫存；退出前沒保存仍結果不明。新增5項、擴充2項，六份回歸175項通過；一次 analyze 0errors/0warnings/1 controller大括號 info（369），留下一輪。詳見儲存清單，未改token/hash/發送協議。接續核對背景收件斷線與保存失敗恢復，不轉 MOD；真人驗收與官方ID關聯仍未完成。

### 最新續接：持續儲存故障與恢復 checkpoint

修正後續讀取錯誤蓋掉已接受提交警告，以及恢復 checkpoint 寫入失敗卻提前標為已恢復。新增3項持續 read/write 故障與恢復重試測試，六份回歸170項通過；一次 analyze 0errors/0warnings/1測試大括號 info（436），下一輪處理。尚需區分執行中已知 submitted 和磁碟舊 sending 的展示，不宣稱已有持久回執。未改 token/hash/發送協議；真人重啟與私訊驗收仍未做，整體目標保持未完成。

### 最新續接：提交結果不被保存錯誤改成失敗

API 接受提交後，本機紀錄或草稿保存失敗維持 submitted、提示勿直接重送，不自動重發。兩項寫入故障測試及六份回歸167項通過，單次 analyze 無問題。持續磁碟故障仍有未驗收限制，詳見儲存清單與 A—F audit。查閱 StreamNook 發送/歷史路徑亦只有本機 sent ID 與 ID 合併，未找到可靠官方 ID 關聯；不猜配刪資料。真人列表、双向收發、重啟與裝置驗收仍待做，整體未完成。

### 最新續接：主登入失效不改用另一身份

無owner的私訊session只由第一provider建立主身份，無效時停止；已知owner可用同owner補scope，但主provider已換人就拒絕舊owner。沒有改token保存/更新。新增8項API/controller測試，六份回歸165項通過，單次analyze 0errors/0warnings/2測試大括號infos（336/347），下一輪處理。剩餘優先local outgoing與官方history-ID可靠關聯，查上游/API證據、不猜文字時間刪掉；真人Web列表/双向收发/装置未驗收，整體仍未完成。

### 最新續接：私訊 A—F 要求核對

已依六單元直接核對相關程式和測試，完整證據/剩餘缺口見 `twitch-whisper-requirements-audit.md`。修正備份同ID不同內容/參與者默默略過，以及raw JSON內衝突被模型去重；整份拒絕、不部分保存，合法發送狀態推進不受影響。新增4項，六份回歸157項通過，一次analyze無問題。明列待查：主provider失效時fallback身份、local outgoing與官方ID可靠對應、真人Web/API及双裝置。下一輪先核對登入失效身份，不跳回MOD；整體未完成。

### 最新續接：單一對話歷史取消／逾時

歷史加入45秒待讀逾時、取消、原模式/游標重試和peer切換隔離，沿用既有選單；保存中不可取消，不宣稱停止底層HTTP。session/clear/dispose釋放等待；query/token/草稿/anchor維持。新增4控制器+3尺寸測試，六份回歸153項通過，一次analyze無問題。下一輪對照私訊A—F和實際相關檔案做剩餘缺口核對，避免僅累積局部測試；真人讀取、收發和雙裝置仍未完成，整體目標持續。

### 最新續接：私訊列表同步恢復操作

遠端列表45秒讀取逾時、明確取消與同分頁重試已接controller和列表狀態區。cancel以request serial擋晚頁及晚錯誤；不推cursor、不刪資料，commit開始後不可取消，不宣稱中止底層網路。session刷新／clear／dispose釋放待讀。新增4控制器+3尺寸入口測試，六份回歸146項通過，單次analyze無問題。仍缺單一對話history的取消／逾時操作；下一輪優先補這部分，再核對其餘私訊驗收與路線圖，不以mock宣告真人完成。

### 最新續接：較早歷史保留閱讀內容

私訊改用穩定 center 雙 SliverList，歷史向上延伸，較新訊息向下延伸，原拖曳／最新尾端流程維持。新增桌面/手機×等高/變高4項連續三頁 anchor測試，以相對閱讀 viewport 的 top 誤差≤1px驗證同一live及歷史訊息未換位；非只是 pixels 不變。六份回歸139項通過，一次analyze無問題。沒有涵蓋全部字級/220px/鍵盤prepend組合，也沒有真人資料；下一輪繼續列表錯誤恢復與取消/超時，私訊仍優先、整體未完成。

### 最新續接：Home／面板刷新並行

本輪僅一次 analyze，無問題（exit code 0）。

修正 refreshSession loading 時立即返回造成授權重試用舊 session 的問題；一般呼叫共享 Future，授權使用 afterCurrent 等待後驗證新憑證。clearSession 斷開舊等待、generation 擋晚回應；同帳號重新載入疊回新草稿。新增6項控制器／介面測試，六份回歸135項通過。沒有改授權儲存、query或協議；真人列表與装置未驗收。下一輪繼續私訊歷史閱讀 anchor 和列表錯誤恢復，完整目標仍未完成。

### 最新續接：私訊授權／重試獨立於 Drops

本輪一次 analyze 無問題，exit code 0。

修正 Home 私訊重新授權接整套 linked login、連帶要求 Drops 的問題；改走既有 main/Web OAuth WebView 的獨立私訊入口，token/runtime 原樣。列表選單可授權後重試，同帳號且面板仍開才續接；失敗、換帳號、關閉不重試。5項新測試及六份回歸129項通過。集中真人／雙裝置驗收清單新增 `twitch-whisper-device-acceptance.md`，全部未測，不宣稱完整完成。續接優先 Home／面板 refreshSession 並行及登入後 GQL 列表錯誤恢復，不切回 MOD。

### 最新續接：私訊歷史與即時收件去重

本輪單次 analyze 無問題（exit code 0），已修正前輪 controller 大括號提示。

修正遠端同步先保存訊息導致同 ID 的首次 EventSub 被當重送、漏未讀及通知。新增持久化 historicalOnly，真正 live receipt 只提升一次；重開及後續同步不退回歷史。controller 索引從 archive 重建。4項新測試與五份私訊回歸121項通過。未擴充 MOD、未改授權或 query；真人 Web 列表與裝置收發尚未驗證，整體目標未完成。下一輪優先確認列表同步授權入口與錯誤恢復，保持私訊優先。

### 最新進度：遠端私訊列表入口與保存

私訊列表選單已接手動同步及載入更多、未知 peer 建立、session 進度恢復與獨立 Twitch 未讀顯示。保存保留草稿/本機未讀/較新 profile，錯帳號晚回應不合併；明確同步重啟列表分頁，載入更多續接保存進度。新增6項測試，五份私訊回歸117項通過；一次 analyze 0 errors、0 warnings、1 info（controller:718 大括號），留下一輪。API及保存細節見 `twitch-whisper-api-storage.md` 最新狀態。未驗證真人 Web 授權列表或 Windows／Android 實際資料，完整目標仍未完成，繼續私訊優先。

建立日期：2026-10-03。狀態：私訊 A—E 已接上 App，模擬回歸測試通過；F 僅完成本機備份／匯入／刪除。真實收發、裝置驗收及整体功能尚未完成。

## 目標與範圍

依 StreamNook 的 Twitch 功能與分類，以 Flutter 重現可使用的行為，並適配 Windows 與 Android。不把有按鈕、表單或預覽視為整個功能完成。

參考功能與已核對的上游來源見 [功能差異清單](streamnook-feature-parity.md)。該文件固定的上游版本作為起點；之後若更新參考版本，先記錄差異，不讓工作範圍無聲擴張。

- 納入：Twitch 私訊、聊天室、MOD、身分／官方徽章、互動事件、Drops／點數、觀看功能，以及服務這些功能的設定、通知、更新與視窗安排。
- 排除：Kick／YouTube、7TV 徽章／名字特效／登入、StreamNook 專用帳號／會員／排名服務。保留既有第三方貼圖。
- Twitch 多直播、多聊天室、插件及直播覆蓋層先列為後段工作，開始前核對是否需要受限制的播放器或平台檔案。
- 此清單不是上限：讀到上游 Twitch 相關的新功能、子選項或例外流程時，追加到差異清單並安排工作單元；不可只完成最初列出的項目就宣稱全面對齊。
- 不整份搬入上游程式碼；採用具體程式碼前先核對授權條款。

## 每次工作的規則

1. 一次選一個工作單元，先讀該項上游功能與本地直接相關檔案，不掃整個 repo。
2. 記錄真實差距、預計修改檔案、依賴與驗收條件；不把未核對的本地功能直接列為缺失。
3. 需要修改受限制範圍時，先列出路徑、原因、必要性並詢問；使用者同意 Twitch 整體目標，不代表取消 AGENTS.md 的限制。
4. 實作後作適量測試，最多執行一次 flutter analyze；若仍有問題，留下明確錯誤與下一項工作，不反覆執行到通過。
5. Windows 與手機排版分別驗證；無 Android 測試環境時標為待驗證，不宣稱已通過。
6. 真實帳號權限、收件、對方是否收到、MOD 外部操作須分開驗證。不要為測試自行向真人發私訊、封鎖或清除真實聊天室。
7. 完成後更新底部續接紀錄：改了什麼、已驗證什麼、剩下什麼、下一單元。
8. 不逐項要求使用者測試。自查結果與需要真人帳號／手機的測試先集中記錄，整體完成後交付一份測試清單；中途只有必要授權、範圍突破或無法自行決定的條件才詢問。

狀態僅使用：待核對、待實作、實作中、待驗證、完成、待使用者確認。遇到外部条件未滿足時，記錄條件，不以模擬資料冒充完成。

## 推進順序

| 順序 | 工作包 | 起始狀態 | 完成標準 |
| --- | --- | --- | --- |
| 1 | 完整悄悄話／私訊 | A—E 已接入，待真實帳號與裝置驗證；F 部分實作 | 獨立對話介面、背景收件、回覆、未讀、帳號隔離與歷史保存 |
| 2 | UI 分類與入口 | 待驗證；已移除聊天室內私訊／更新 | Windows 外框獨立入口；手機可直接找到；更新不混進身分設定 |
| 3 | MOD | 房間控制／自訂禁言／警告已補，待實測；其餘實作中 | 訊息就地操作、權限門檻、房間控制、事件紀錄、風險確認 |
| 4 | 聊天身分與互動 | 待核對；已有色票與徽章预覽 | 預覽與配戴清楚、錯誤可理解、套用結果能刷新 |
| 5 | 聊天基本體驗與個人設定 | 待核對 | 回覆、補全、使用者卡片、滾動暫停、高亮／忽略符合實際行為 |
| 6 | Twitch 事件與聊天室功能 | 待核對 | 訂閱、續訂、觀看連續、Bits、預測、Hype Train、釘選等逐項驗證 |
| 7 | Drops／忠誠點數／徽章追蹤 | 待核對 | 真實資料、進度與錯誤回饋；不變更既有點數 payload |
| 8 | 觀看、VOD 與頻道瀏覽 | 待核對 | 品質、離線狀態、VOD／聊天室、子母畫面等逐項驗證 |
| 9 | 通知、更新、設定與資料管理 | 待核對 | 清楚分類、可恢復設定、權限與快取界線、更新失敗可重試 |
| 10 | Twitch 多視窗／多聊天室／多直播與擴充 | 待核對，必要範圍先確認 | 各視窗狀態與音訊一致、資源能釋放、平台可支援 |

## 第一包：完整私訊的可執行單元

| 單元 | 工作 | 驗收條件 | 依賴 |
| --- | --- | --- | --- |
| 私訊 A | 對話／訊息資料模型、本機歷史、草稿 | 兩個帳號資料隔離；重啟能載入；損壞資料不造成當機；事件去重 | 不儲存 OAuth/token；現有登入供應者 |
| 私訊 B | 對話列表與雙向對話 UI，替換發送表單 | 桌面双欄；手機列表→對話→返回；草稿保留；空／載入／錯誤狀態齊全 | A；測試資料僅用於測試，不作實際收件 |
| 私訊 C | 官方發送、使用者搜尋、失敗／重試 | 收件者選擇清楚；不切到另一帳號代發；失敗不丟草稿；不虛構送達／已讀 | A、B；既有授權含發送權限 |
| 私訊 D | 官方 EventSub 背景收件與重連 | 面板關閉仍收件；重複事件只記一份；reconnect／撤銷／切帳號釋放舊連線 | A；核對接收 scope，缺授權明確提示；不擅自修改 OAuth |
| 私訊 E | 未讀、通知、入口徽標、已讀 | 正在閱讀的對話不增加未讀；未開面板會增加；桌面與手機入口一致 | B、D；已讀是本機閱讀狀態，非對方回執 |
| 私訊 F | 舊歷史／匯入、清理與端到端驗收 | 明確區分本機歷史、匯入與遠端資料；分頁合併／去重；清理範圍明示 | A—E；歷史能力需核對，不能保證取得全部 Twitch 歷史 |

私訊 A—F 全部驗收前，只回報完成的單元，不稱作「完整私訊已完成」。原有發送能力在新介面接好前保留，避免破壞可用功能。

## 後續工作包拆分

### 入口分類

- Windows：私訊獨立圖示／未讀數；有更新才出現更新提示；一般設定與身分分開。
- Android：首頁私訊入口與未讀；更新在更多／設定的更新分類；聊天室只放頻道相關工具。
- 驗收：小視窗、橫直版、字體放大不 overflow；進入／關閉面板、返回與全螢幕 fallback 都有明確行為。

### MOD

- 先完善權限提示、房間控制、自訂禁言時間與原因。
- 再做訊息旁／使用者卡片的刪除、禁言、封鎖、解除、警告與釘選。
- 再接背景管理事件紀錄，區分「本機送出的操作」與「完整頻道事件」。
- 最後做桌面快捷鍵、拖曳與批次處理；手機長按選單需同等可用。批次操作預覽、確認、限流；刪除不可逆，不提供虛假撤銷。

### 身分與互動

- Twitch ID 顏色、可用官方徽章、預覽／套用／刷新與授權不足提示。
- 台主／MOD／VIP 身分並非徽章選擇能授予，不開放任意配戴未擁有徽章。
- 續訂、連續觀看和分享屬互動子區；不與 App 更新或私訊混淆。

### 聊天、事件與貼圖

- 每項獨立核對：回覆、提及、補全、使用者卡片、本機暱稱／顏色／備註。
- 暫停與恢復滾動、載入歷史、聊天模式提示、高亮／忽略、聲音與通知。
- 命令面板／自訂命令／常用文字／拼字檢查分別驗收，不透過修改 IRC 協議硬接。
- 現有第三方貼圖、動畫／零寬貼圖、官方表情、Twitch 系統事件逐項測試。

### 瀏覽、觀看、獎勵及設定

- 先盤點已存在的功能，避免重做現有追隨、搜尋、播放器與點數邏輯。
- 更新 UI 和下載／套用流程分開驗證；手機 APK 安裝權限、Windows 更新檔案與復原需求不能以桌面結果替代手機結果。
- 對播放器底層、平台檔案、點數 payload、OAuth 或 GQL hash 的修改需求先詢問。
- 多視窗、覆蓋層、插件與整合在核心 Twitch 功能穩定後再逐項設計；不假設 StreamNook 的專用服務能直接接入。

## 驗收紀錄模板

每單元追加紀錄：

- 單元／日期／狀態：
- 對照來源與版本：
- 本地直接相關檔案與現況：
- 本輪變更與不處理項目：
- 已驗證結果（分析／編譯／Windows／Android／真實權限）：
- 失敗或待驗證項目：
- 下一單元與所需確認：

## 需真人／裝置的最終測試待辦（不是現在要求使用者測試）

持續追加，交付整體完成版本時才整理成操作順序、預期結果與回報格式：

- 兩個真實 Twitch 帳號互傳私訊；面板關閉時收到訊息、未讀與通知。
- 缺少私訊／MOD 授權、無管理身分、授權撤銷與斷線恢復。
- 私訊帳號切換、重啟歷史與草稿、不重複收件。
- 有權限的測試頻道驗證 MOD，不在陌生頻道測試封鎖或清除。
- Android 橫直版、返回、鍵盤、背景／前景與 App 更新安裝。
- Windows 小視窗、全螢幕、外框入口與 App 更新。

## 實作紀錄

### 2026-10-03：私訊 A 的純資料底層

- 狀態：實作中，尚未完成整個私訊 A。
- 新增 `TwitchWhisperMessage`、`TwitchWhisperConversation` 與 `TwitchWhisperArchiveStore`。
- 訊息狀態區分收到、發送中、已提交、失敗；不虛構對方送達／已讀。
- 歷史按擁有者 Twitch ID 隔離，儲存讀寫介面可注入；序列化寫入避免同一實例並行操作覆蓋。
- 已自查：重啟還原、草稿、帳號隔離、重複事件／未讀去重、發送中斷恢復、損壞與擁有者不符資料的保護。驗證腳本：`dart run docs/verify_twitch_whisper_archive.dart`。
- 本輪 flutter analyze 執行一次：沒有編譯錯誤，5 個提示待下一單元處理（驗證腳本的兩個相對 lib import、一個 print，以及模型／儲存服務的兩個 if 大括號）。未重跑分析。
- 尚未接入 App 實際持久化後端；此階段測試後端是記憶體，沒有讀取真實私訊或發送任何外部訊息。每個帳號歷史由同一個 store 實例管理；跨多視窗儲存同步需另行設計。
- 下一步：接上本機持久化後端與單一服務擁有者，之後實作私訊 B 的對話列表／聊天頁。

## 目前續接點

- 已完成：Twitch 範圍確認、參考來源文件、此路線圖。這是規劃完成，不是產品功能完成。
- 最近程式狀態：私訊已替換為列表與對話，接入共用持久化、官方發送、EventSub 收件、未讀與通知；具體驗收見下方紀錄。不是全面對齊完成。
- 下一單元：先修本輪 pin test 124 行與 moderation API 235 行的 if 大括號提示，接續 AutoMod 佇列／管理事件紀錄。釘選管理已接上官方 API，尚需事件即時刷新、官方 fragment 渲染與多管理員競態補驗。直播列表直接管理快捷操作、拖曳及快鍵仍未完成；封鎖詞與單張資料卡角色刷新不是全域角色事件同步。資料卡追隨、本機暱稱／顏色／備註仍待核對，不能等同完整卡片對齊。台主投票／預測控制在事件工作包接續。私訊仍需 API 真實回應契約測試、系統返回／暫停滾動、官方貼圖與多對話操作自查；不因舊 Twitch 歷史 hash 限制停掉其他安全工作。
- 說明：此文件讓後续回合可接續工作，不是已建立的自動排程或離線背景任務。實作、帳號實測、平台測試與需額外授權的變更仍按每輪規則處理。

### 2026-10-03：私訊 App 接線、對話介面與背景收件

- 狀態：A—E 實作已接入，測試資料驗證通過；真實 Twitch 帳號／Windows 視窗／Android 裝置仍待驗證。F 部分實作，不能稱作完整私訊完成。
- App 主頁生命週期擁有單一 inbox/store，使用既有登入供應者；SharedPreferences 保存帳號隔離的本機歷史與草稿，不另存憑證。
- 桌面左右雙欄、手機對話返回列表、新增精確帳號、列表搜尋及排序、訊息時間與提交／失敗狀態。發送失敗保留草稿；發送等待期間輸入的新草稿不會被清空；登出中止尚未送出的請求。
- 依官方 EventSub `user.whisper.message` 實作收件，接受既有 `user:read:whispers` 或 `user:manage:whispers` 授權。Welcome 後建立訂閱、keepalive watchdog、退避重試、伺服器 reconnect 在新 welcome 前保留舊 socket、不重複訂閱；授權撤銷停止重試。這些操作未改 OAuth/token 儲存、IRC 或既有 GQL hash。
- 面板關閉仍由 App 服務收件，訊息 ID 去重，正在前景閱讀的對話不增未讀；Windows 外框與手機更多入口顯示徽標。通知不顯示正文；Windows 用既有內部通知列，Android 用既有系統通知路徑。
- **背景界線**：此處「背景」是面板關閉、App 程序仍運作；沒有新增 Android 常駐服務或伺服器推播。OS 暫停／終止程序時不保證收件。Twitch 官方說明斷線期間事件不重播，UI 有明示，不能假装會自動補齊。
- 本機備份复制到剪貼簿前有私密資料提醒；只允許同帳號備份匯入，限制 2 MB，原子合併去重，不產生未讀或對 Twitch 發送；保留現有草稿。刪除本機對話有不可復原提示與確認，不代表刪除 Twitch 遠端資料。本輪測試沒有刪除使用者真實歷史。
- 舊 Twitch 歷史：已核對上游 `whisper_history_service.rs` 的 `Whispers_Thread_WhisperThread` persisted query。未新增或變更此 hash；依目前限制保留未實作項，不把 VioClass 備份匯入冒稱為 Twitch 歷史匯入。
- 已驗證：`flutter test --no-pub docs/twitch_whisper_inbox_test.dart docs/twitch_whisper_eventsub_test.dart --reporter expanded`，13 項全部通過；`dart run docs/verify_twitch_whisper_archive.dart` 通過。測試完全使用假帳號、記憶體儲存及假 socket，未向真人發訊息或操作真實 MOD。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、5 infos，皆為 `curly_braces_in_flow_control_structures`；位置為私訊 sheet 119／187、EventSub service 93／152、inbox controller 301。分析 exit code 1，不記作完全通過；留待下一單元修正，未反覆執行。
- 尚待自查：普通斷線和 watchdog、reconnect 失敗、通知只觸發一次、手機鍵盤／放大字體、私訊表情與歷史操作回饋；尚無真實 EventSub 訂閱結果或手機通知測試，不用單元測試取代真實驗收。
- 真人最終驗收追加：有收件授權但沒發送授權、電話未驗證、Twitch 隱私抑制送達、兩帳號切換、App 在背景／終止後的實際行為，以及剪貼簿備份私密性與本機刪除範圍。

官方參考：[WebSocket 事件](https://dev.twitch.tv/docs/eventsub/handling-websocket-events/)、[私訊訂閱授權](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#userwhispermessage)。

### 2026-10-03：私訊邊界驗收與 MOD 房間控制／安全補強

- 狀態：本輪有程式與證據進展，非等待／停滯；目標保持進行中。沒有自動暫停或宣告全部功能完成。
- 私訊新增普通斷線重新訂閱、keepalive 重設與 watchdog、失敗 handoff 後恢復及通知去重測試。手機橫版鍵盤測試找到真實垂直 overflow，已改短高度精簡標頭／輸入區，對話列表改為整體可滾動；320×640 鍵盤／1.3 倍字體、844×390 橫版鍵盤、桌面 1.6 倍字體均無 overflow 且輸入區在鍵盤上方。
- 私訊補 Unicode 表情插入游標位置、列表最後訊息時間、複製備份與匯入合併數的結果提示。測試確保表情保存成草稿但不自行發送；上輪 5 個格式提示已修正。
- MOD 已核對固定版本的 `ModeratorMenu.tsx`：慢速選項、追隨／訂閱／貼圖／不重複模式、清除確認，以及尚未接入的封鎖詞、解除釘選、台主投票／預測與管理紀錄。`ModRoomPane.tsx` 屬專用支持者房間，記入排除清單而非任意替代。
- MOD 本輪補上：慢速 3–120 秒、追隨門檻 0–129600 分鐘，自訂禁言 1–1209600 秒；警告要求非本人／台主目標與 1–500 字原因。顯示／確認的時間取自實際回應，不再用硬編碼標題暗示目前房間數值。
- 房間設定僅接受合法欄位／型別；時間參數必須同時開啟對應模式。警告使用官方 `/moderation/warnings` 與既有含 `moderator:manage:warnings` 的授權。沒有修改登入流程來追加 scope；缺 scope 就明確失敗。
- API 在驗證既有憑證後、外部操作前再次檢查觀看頁的頻道、viewer ID、runtime 與角色；切換帳號／頻道則中止。確認包含頻道、對象、動作及已輸入原因。409／429 分別提示，不自動重送外部管理操作。
- 測試：四份 docs regression harness 共 **28 項通過**（私訊 20、MOD API 5、MOD UI 3）；資料保存腳本亦通過。HTTP／socket／帳號與訊息皆為測試替身，未使用真實 Twitch 做禁言、警告、清除或發訊息。
- 靜態分析：本輪只執行一次 `flutter analyze --no-pub lib/features/twitch docs`，exit code 0，`No issues found!`，0 errors／warnings／infos；未重跑分析。
- 仍待驗證：真實角色／授權、警告確認通知到對方、房間設定回應與實际生效、Android 裝置鍵盤與通知；視窗尺寸測試不等同實機驗收。
- 下一單元按上方續接點進行，不逐項請使用者現在測試；最後測試清單追加「改時間取消不送出、警告必填原因、切頻道後舊確認不生效、409／429 不重送」。

官方參考：[房間設定](https://dev.twitch.tv/docs/api/reference/#update-chat-settings)、[禁言／封鎖](https://dev.twitch.tv/docs/api/reference/#ban-user)、[警告](https://dev.twitch.tv/docs/api/reference/#warn-chat-user)。

### 2026-10-03：MOD 訊息回覆串的就地操作

- 本輪分類：有進展。新增可用操作與測試證據；目標持續進行，沒有重定義成只完成私訊／管理面板。
- 已檢查觀看頁→聊天 port adapter→聊天面板→訊息 context sheet→回覆串卡片的實際接線。新增 `messageActionBuilder` 只傳遞聊天功能，未修改播放器 runtime；一般觀眾與 VOD 回放仍保留原本回覆串／複製流程，不額外授予管理能力。
- 新增 `TwitchModerationMessageActions`：從直播訊息點擊／長按／右鍵打開回覆串後，每則合格訊息旁有刪除、自訂禁言、警告、封鎖、解除封鎖／禁言。顯示頻道、目標與選中的內容；取消不送出、原因與時間驗證、等待時禁止重送、確認按鈕重複点击防護、結果／錯誤提示。刪除不可復原；封鎖則清楚說明可解除，不混淆兩者。
- 操作凍結原本 API／對象／頻道及權限檢查，不因鍵盤／尺寸重建換成新的目標；送出前再次檢查原本頻道、viewer ID、runtime 與角色。由 HTTP API 再驗證正確帳號與 scope，未改 OAuth/token 或 IRC 發送協議。
- 共用 `TwitchModerationTargetPolicy` 也套入原本管理面板：排除共享聊天室外台來源、本人／台主／MOD 的禁言與警告目標；本人一般訊息可刪除。沒有官方 ID、local echo 或 synthetic 訊息不提供刪除。台主對其他 MOD 的角色管理仍待實作，不假裝選單能先自動解除 MOD 再封鎖。
- 驗證：五份 docs regression harness 合計 **34 項通過**。本輪新增 6 項涵蓋共享來源／本機假 ID 的目標保護、一般观眾保留回覆串、刪除確認與取消、警告必填／單次發送、權限改變中止、320×640 自訂禁言。修改封鎖提示與保留原本 API 之後，新增的 6 項再通過；測試只操作假資料。
- 本輪只跑一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、1 info，exit code 1；`chat_message_context/twitch_reply_thread_card.dart:88` 的 `use_null_aware_elements` 留下一單元處理，未重跑或循環修分析到成功。
- **界線**：這輪是回覆串卡片旁的操作，不是完整使用者資料卡，也不是直播列表直接 hover／拖曳快捷鍵。這些原始需求仍在續接點；不把共用 widget 可重用當作已完成使用者卡片。
- 最終裝置／帳號測試追加：Windows 右鍵、Android 長按、共享聊天室外台訊息、沒有官方 tag 的訊息、確認途中換帳號／頻道、取消操作、同時管理衝突、警告／禁言實際生效。沒有為驗證封鎖或警告真人。
- 參考：[UserProfileCard 固定版本](https://github.com/StreamNook/StreamNook/blob/76b81ca0d935cd01b8e3cffaafcfc23de716aae9/src/components/UserProfileCard.tsx)。來源尚有資料卡、官方／第三方身分、角色授予／撤銷、歷史與私訊入口；第三方徽章／專用裝飾維持已確認排除，其他 Twitch 部分繼續盤點。

### 2026-10-03：使用者資料卡與直接私訊接線

- 本輪分類：有進展，修改實際程式／接線並補回歸證據。沒有全面完成或暫停目標。
- 新增獨立使用者資料卡：官方 Get Users 的名字、頭像、簡介、建立日期；顯示選取訊息上的 Twitch 徽章與 ID 顏色，不冒稱完整擁有徽章清單，也不加 7TV 身分。官方資料失敗仍保留本機訊息與重試入口。
- 本機歷史依 user-id、觀看聊天室與來源 room 隔離，訊息 ID 去重並包含原本選取訊息；同 ID 改名仍合併，外頻道／共享外台來源不混入。清楚標示只包含目前載入資料，不是 Twitch 完整遠端歷史；接入原本官方／第三方貼圖渲染器。
- 直播訊息 ID 可直接點擊開資料卡；訊息正文仍開回覆串，Windows 右鍵／Android 長按流程保留。作者 recognizer 由訊息內容 StatefulWidget 擁有並 dispose，避免建立後無人釋放；回覆串仍有資料卡入口。資料卡防重複開啟，非管理者沒有管理動作。
- 資料卡管理區重用已驗證的確認／權限動作。私訊需明確點選後才關資料卡並開獨立對話；launcher 核對原本 viewer ID、精確 login 與有提供的 peer ID，帳號變更或 ID 不符時中止。不發送、不清空草稿、不把私訊嵌回特殊訊息。
- 官方唯讀資料 API 驗證既有憑證，以 validation.client_id 搭配 token；對已選定 viewer 不借另一帳號，送出與返回前核對觀看 context。未改 OAuth/token 保存、IRC 協議、GQL hash、點數 payload 或播放器 runtime。
- 六份回歸 harness 共 **46 項通過**：新增 11 項 profile／ID 點擊測試，私訊 harness 追加 1 項 launcher／帳號／對象／草稿測試。包含 320×640、844×390、1200×800 的 1.5 倍字體、資料失敗／重試、面板已關才收到資料，以及 ID 點擊不誤觸回覆串。假 API／HTTP／socket；沒有對真人發訊息或做管理操作。
- 靜態分析僅一次：`flutter analyze --no-pub lib/features/twitch docs`，0 errors、0 warnings、2 infos，exit code 1；`twitch_watch_page_chat.dart:33` 與 `twitch_chat_user_profile_sheet.dart:115` 的 `curly_braces_in_flow_control_structures` 留下一單元，不反覆修後重跑。上輪 reply card null-aware 提示已修。
- 尚未對齊：官方 MOD／VIP 授予與撤銷、封鎖狀態讀取、追隨狀態／操作、本機暱稱／顏色／備註、完整遠端使用者歷史、直播 hover 管理／拖曳。上游第三方歷史服務沒有擅自當成 VioClass 可用來源；受限制 hash 仍不修改。
- 最終真人／裝置驗收追加：聊天 ID 與正文的點擊區分、共享聊天室來源隔離、自己的私訊入口停用、原本帳號／對象改變時中止、私訊面板保持獨立、官方頭像／資料及缺授權錯誤。尚未啟動最新版 Windows App 或在真實 Android 裝置測試，不以 layout test 冒稱實測。

官方資料來源：[Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)。

### 2026-10-03：台主 MOD／VIP 角色管理與官方封鎖狀態

- 本輪分類：有進展。實作並驗證上游使用者資料卡的官方角色操作子單元，整體目標保持進行中。
- 先核對 Twitch Get Moderators／Get VIPs／Get Banned Users 及角色授予／撤銷的 scope、token 擁有者與 query。官方狀態查詢需要 broadcaster_id 與台主 token 相符；沒有借其他已連結帳號、沒有把 MOD scope 當成台主身分。台主對自己、共享外台來源及無有效 user-id 的角色操作不提供入口。
- 在直播資料卡接入 `TwitchUserRoleActions`，台主可讀 MOD、VIP、封鎖／禁言狀態，並明確授予或撤銷 MOD／VIP。狀態讀取分開失敗，缺授權顯示未確認及原因，不拿選取訊息的歷史徽章冒充現在角色。
- 使用官方 `/moderation/moderators`、`/channels/vips`、`/moderation/banned`。角色 query 只有 broadcaster_id／user_id，不加這些 endpoint 不要求的 moderator_id；Client-ID 取已驗證憑證。角色寫入只需該角色的 manage scope，不額外強迫取得其他 read scope；合法但未能查詢狀態時仍可選擇明確動作，由 Twitch 判定目前資格。
- 每項角色變更都有頻道、對象與權限影響確認；取消不寫入、重複確認防護、送出前再次核對原本管理 context。只提交一項角色操作，不會自動撤銷另一角色、解除禁言／封鎖或串連不可預期動作。
- 422 角色衝突、409 VIP 名額不足、425 VIP 未開放與 429 限流各有提示；不自動重送或撤销現有角色。測試發現自訂 Dio 預設會攔截 4xx，已在此管理 request 設定可解析 4xx，避免吞掉這些細分錯誤；未修改共用 client 或登入儲存。
- 操作被接受後重新讀官方狀態，重新讀取失敗保留「已提交」結果但目前狀態為未確認，不虛構已配戴／已撤銷。已封鎖或已有另一角色的已知狀態禁止直接授予；未知狀態不假裝沒有角色，也不強迫增加授權。
- 七份回歸測試共 **55 項通過**，新增角色 API／介面測試 9 項；包含 exact endpoint/query/Client-ID、只有單項 manage scope、台主身分／帳號隔離、取消與確認、角色撤銷後刷新、確認中失去權限、寫入成功但刷新失敗、小手機放大字體，以及衝突／名額錯誤只寫一次。使用假 HTTP／帳號，未改任何真人角色或封鎖。
- 只跑一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、2 infos，exit code 1；兩項均在新 test 的 if 大括號（29／74 行），留下一單元。上轮 profile／watch 的格式提示已修，未反覆跑分析。
- 界線：目前是台主官方角色面板，不是一般 MOD 可讀完整狀態，也不是完整管理事件紀錄；不新增 GQL hash 来绕过官方界线。撤銷 MOD 後，舊訊息卡的歷史 MOD 徽章仍保守限制禁言／警告，需下一單元接入新官方角色狀態刷新；不會自動先撤 MOD 再封鎖。
- 最終帳號／裝置驗收追加：台主的 read/manage scope 組合、合法 MOD 與台主的入口差異、VIP 名額／角色冲突、撤銷後實際權限、确认中切帳號／頻道、操作成功但缺讀取授權及手機角色確認布局。App／真實裝置尚未啟動驗收。

官方參考：[MOD 查詢](https://dev.twitch.tv/docs/api/reference/#get-moderators)、[MOD 授予](https://dev.twitch.tv/docs/api/reference/#add-channel-moderator)、[VIP 查詢](https://dev.twitch.tv/docs/api/reference/#get-vips)、[VIP 授予](https://dev.twitch.tv/docs/api/reference/#add-channel-vip)、[封鎖狀態](https://dev.twitch.tv/docs/api/reference/#get-banned-users)。

### 2026-10-03：封鎖詞分頁管理與資料卡角色刷新

- 本輪分類：有進展；沒有重新定義整體範圍，也未進入等待。新增正式入口／API／UI 並增加測試。
- MOD 設定加入獨立封鎖詞面板：讀取非私人封鎖詞、分頁（每頁 100）、按 ID 合併去重、明確「搜尋已載入」而非假裝伺服器搜尋；重复 cursor 停止繼續載入並提示刷新。刷新失敗保留已載入資料，不用空清單代表缺授權。
- 新增／移除需頻道、詞句及規則影響確認。2–500 字驗證，原封鎖詞 ID 刪除；新增同一詞由 Twitch 返回原 ID，不重複造 ID。等待操作禁止重送、取消不寫入、權限／帳號／頻道變更中止。失敗保留新增草稿；回應不完整或不明外部操作結果先提示刷新確認，不自動重送。
- 使用官方 `/moderation/blocked_terms` GET／POST／DELETE；read 或 manage scope 均可讀，寫入須 manage，moderator_id 必須是已驗證登入者，Client-ID 對應 token。回應缺 ID／text 或來源 broadcaster 不符拒絕，未更改 OAuth、hash、IRC 或点數 payload。
- 封鎖詞不等同所有 AutoMod 規則，面板明示官方只提供非私人詞。沒有對真人新增、移除或修改任何規則。
- 新增 `TwitchUserModerationControls` 串接同一張台主資料卡的角色狀態與訊息操作：官方刷新確認撤 MOD 後，可在保留舊徽章的訊息上使用管理動作；確認仍是 MOD 則保持保護。只有台主官方狀態能覆蓋歷史 MOD badge，一般 MOD 不能藉參數解鎖另一 MOD。本人／台主／共享外台的保護仍保留。
- 角色變更確認與寫入期間鎖住旁邊高風險操作；已接受角色操作但 MOD 狀態刷新失敗時，顯示未確認並繼續鎖住，直到成功刷新。管理確認送出前再檢查最新受保護角色。不會自動先撤 MOD 再封鎖，也未宣稱所有卡片的角色事件全域同步。
- 測試找到確認框底下不必要的 loading 動畫，已拆分確認中／實際寫入狀態；只在載入或寫入時顯示進度，不讓確認對話期間持續背景動畫。
- 八份 harness 共 **64 項通過**，新增封鎖詞 6 項、角色刷新／保護 3 項。涵蓋 official query／body／read/manage、非法詞句與帳號、外頻道回應、分頁合併／搜尋、取消／失敗草稿、重複 cursor、手機鍵盤／1.5 倍字體，以及撤銷舊 MOD 徽章後重新判斷、狀態未確認時鎖住操作。測試替身沒有外部真人變更。
- 本輪只跑一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、1 info，exit code 1；API 167 行 `curly_braces_in_flow_control_structures` 留下一單元，不重跑。上輪 test 兩項格式提示已修。
- 最終測試追加：台主／MOD 實際 scope、超過 100 個詞分頁、萬用字元的 Twitch 規則、取消不送出／失敗草稿、不同管理員同時操作、角色操作後实际權限／其他資料卡同步。尚未啟動新 Windows App 或在 Android 實機驗收。

官方參考：[封鎖詞讀取](https://dev.twitch.tv/docs/api/reference/#get-blocked-terms)、[新增](https://dev.twitch.tv/docs/api/reference/#add-blocked-term)、[移除](https://dev.twitch.tv/docs/api/reference/#remove-blocked-term)。

### 2026-10-03：官方釘選管理與聊天室釘選列接線

- 本輪分類：有進展，新增可操作官方釘選單元與回歸證據；未完成全部 MOD／聊天室，也未縮小原目標。
- 核對目前 Twitch `/chat/pins` GET／PUT／PATCH／DELETE：讀取需 read 或 manage chat_messages，寫入需 manage；維持既有使用者憑證驗證、Client-ID 與 moderator_id 相符，不新增 OAuth 儲存或 GQL hash。
- 管理設定提供釘選管理；直播訊息的管理選單、回覆串／使用者資料卡能以選取的官方 message-id 開啟面板。外台共享來源、local echo、synthetic／缺 ID 不提供釘選；本人／台主／MOD 的有效官方訊息可以釘選，不混用封鎖對象的角色限制。
- 面板顯示官方當前內容、釘選者、到期時間；可釘選選中訊息、調整時間或解除當前釘選。30–1800 秒驗證；「直到直播結束」省略 duration_seconds，非硬編碼成永久日期。
- 確認包含頻道、内容、時間與「新增会取代當時釘選」提醒；取消不寫入、確認防重複、等待禁止再次操作。正式寫入前再 GET 核對 message-id／updated_at／ends_at；確認期間被更換或改時間則中止並更新目前狀態，要求再確認。**界線**：Twitch 沒有此處可用的原子 compare-and-swap，重讀與寫入間仍有競態窗口，不宣稱完全排除多管理員競態。
- 正式回應後再查釘選；查詢失敗顯示未確認並停用依賴當前狀態的變更，不冒稱沒有釘選。寫入錯誤／409 已釘選提示刷新，不自動重送。重新整理入口保留，讀取前仍核對權限，讓原身分恢復後可重試。
- 官方模型轉為既有 TwitchPinnedChatMessage，保留原觀眾 GQL 讀取／显示流程不改 hash。觀看頁將已驗證官方讀取結果回饋 engagement controller，立即刷新目前頻道釘選列；revision 避免正在等待的舊 engagement refresh 覆蓋較新的官方快照。不改點數 payload 或播放器 runtime。
- 九份 harness 共 **72 項通過**，新增 pin 測試 8 項：exact HTTP/query／Client-ID、scope 與對象防護、目前頻道快照／reset、時間驗證與取消、直到直播結束／解除、確認期間他人更換、失去權限／狀態失敗，以及小手機鍵盤／1.5 倍字體。測試 controller 接受快照與 reset，舊 refresh 競態 revision 仍需擴充專門測試，不能以窄測試宣稱全部時序通過。
- 本輪 `flutter analyze --no-pub lib/features/twitch docs` 僅一次：0 errors、0 warnings、2 infos，exit code 1；新 pin test 124 行、API 235 行 if 大括號提示留下一單元；上輪 API 167 行提示已修，未反覆分析。
- 仍待完成：釘選 EventSub／即時跨管理員更新、Helix message.fragments 貼圖／提及呈現、無額外授權的一般觀眾持續顯示驗收、到期與直播結束、完整端到端及 Android 實機。此輪 Helix 管理面板以官方 plain text 顯示，不能稱作完整貼圖釘選渲染。
- 最終測試追加：真實權限／404 訊息過期／409 已釘選、30 與 1800 秒、直到直播結束、取代確認、確認中換頻道／帳號、其他管理員同時操作、釘選列讀取失敗與恢復。沒有釘選／解除真人訊息，尚未啟動新 Windows／Android 實測。

官方參考：[釘選讀取](https://dev.twitch.tv/docs/api/reference/#get-pinned-chat-message)、[釘選](https://dev.twitch.tv/docs/api/reference/#pin-chat-message)、[調整時間](https://dev.twitch.tv/docs/api/reference/#update-pinned-chat-message)、[解除](https://dev.twitch.tv/docs/api/reference/#unpin-chat-message)。

### 2026-10-03：AutoMod 官方待審接收與審核列

- 本輪分類：有進展，實作可接收及操作的 AutoMod 單元；全功能目標仍進行中，沒有暫停或宣稱全面完成。
- 核對固定版 StreamNook AutomodQueueStrip：獨立待審列放在聊天訊息與輸入框之間、預設收合、允許／拒絕，依官方 update 移除。依此功能分類獨立寫 Flutter 版本，未複製上游元件程式碼。
- Twitch EventSub `automod.message.hold`／`automod.message.update` v2 使用既有 token providers，先驗證 selected moderator 與 `moderator:manage:automod`；welcome 後以驗證的 Client-ID/token 建立兩筆官方 WebSocket 訂閱。condition 同時核對 broadcaster／moderator，收到事件也核對版本及頻道；不把事件中的處理者限制成自己，其他 MOD 的正式更新也能移除列。
- 新增頻道範圍 socket 接收：keepalive watchdog、10 秒 welcome deadline、指数回退重連、官方 wss host 限制、handoff 保留旧连接直到新 welcome、不重建既有訂閱；handoff 失敗恢復舊連線 watchdog。撤銷／缺授權停止而不無限重试，role/context 改變時停止；dispose 釋放 timers/socket。既有私訊 receiver 沒有修改。
- queue 只收官方有效 hold，message-id 去重、拒絕外頻道／畸形內容。approved／denied／expired update 可先於 hold，已處理 ID tombstone 防止晚到事件復活；保留最近 2000 個 tombstones，並非無限遠端歷史。斷線／終止會清除已不可信的本次快照；新連線無法自動補齊離線期間隊列。
- 對官方 message-id POST `/moderation/automod/message`，body 只有 user_id／msg_id／ALLOW 或 DENY，不加 endpoint 不要求的 broadcaster/moderator query。送出前核對當前頻道／帳號／MOD，不借別的帳號；404 提示失效／已處理、不自動重送。204 僅標示已送出等待更新，不以本地先移除冒充完成；網路結果不明鎖住重送直到官方更新／重新連線。
- 觀看頁經 chat adapter/panel 接入接收列，只提供台主／MOD；key 隔離 runtime、頻道、帳號，重新建構同一 context 不重複開 socket。展開內容限制為聊天可用高度 25%、最高 200 px，可捲動；高度不足則隱藏展開內容但保持接收，不加到私訊／特殊訊息中。
- 十份 harness 共 **84 項通過**，新增 12 項：HTTP exact payload/scope/Client-ID、訂閱 v2 條件、失去授權、去重／更新先到、跨 MOD 處理、socket handoff／撤銷、320px／鍵盤／1.5 倍字體、等待正式更新、pending 防重複與 dispose 後晚回應、短橫向高度。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、9 infos，exit code 1。model 31／65／74、strip 109、socket 139／156／161 的 if 大括號，model 53／54 的 collection literal 提示留下一輪；未反覆分析。上輪 pin test/API 的兩項提示已修。
- 下一個安全單元：先修上述格式提示，再補 AutoMod 等級設定、審核原因／命中位置呈現、MOD EventSub 操作紀錄，繼續釘選及私訊未完成時序驗證。不得以本單元代替全部 MOD、聊天或全功能完成。
- 最終真人／裝置測試追加：MOD 真實 scope 和沒有 scope 的提示、實際 hold／allow／deny／expired、另一 MOD 處理、切帳號／頻道、role 撤銷、斷線／重連與 Android 背景限制。v2 只通知公開封鎖詞，不保證私人封鎖詞完整隊列。尚未啟動最新版 Windows 或用 Android 實機測試，也沒有為驗證而對真人做審核操作。

官方參考：[AutoMod hold／update v2](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#automodmessagehold-v2)、[Manage Held AutoMod Messages](https://dev.twitch.tv/docs/api/reference/#manage-held-automod-messages)。

### 2026-10-03：AutoMod 完整等級設定與官方命中原因

- 本輪分類：有進展。新增實際設定 UI/API 與審核原因資料，不把它當成整體完成；原目標與排除項目不變。
- 管理設定接入獨立「AutoMod 設定」面板，顯示官方整體等級或八類自訂值（0–4）；讀取失敗不建立假的 0 等級，保留重新載入入口。整體等級由 Twitch 套用建議分類，不在本地猜每類應該是多少。
- 依官方 GET／PUT `/moderation/automod/settings`：讀取接受 read 或 manage automod_settings，寫入只接受 manage；selected moderator 與已驗證 Client-ID/token 不變。回應只接受相同 broadcaster/moderator、完整八類有效值與 overall_level；不借其他帳號，不改 OAuth/token 儲存或任何既有 hash。
- PUT 是覆寫：自訂模式一定帶全八類且不帶 overall_level，不能部分送出而意外歸零未編輯分類；整體模式只送 overall_level。API 也拒絕混用、缺分類、額外欄位與範圍外值，並用官方回應更新顯示而非本地樂觀數字。
- 儲存確認列出頻道與實際全部變更；取消不寫入。確認期間凍結快照／草稿，先重讀官方設定；若其他 MOD 已改動，鎖住寫入並保留未送出的草稿，必須明確重新載入後再編輯。重新載入會替換草稿，面板有提醒。**界線**：重讀與 PUT 間沒有原子 CAS，仍存在競態窗口，沒有宣稱完整消除多管理員競態。
- 網路／回應未確認的写入鎖住直接重送、保留草稿；寫入成功後才失去原管理 context 時提示「已送出但需回原頻道確認」，不再誤說未送出。沒有為測試更改真人頻道設定。
- 待審模型區分 blocked_link／blocked_term／automod，從官方 boundaries／terms_found.boundary 保留合法、去重的 inclusive 位置。現階段顯示原文與官方位置數字；文件沒有證明非 BMP／emoji 的索引單位，因此沒有用未證實的 UTF-16／codepoint 假設切錯或高亮內容。片段貼圖、語意高亮與非 BMP 映射仍待核對／實測；不稱完整原因渲染完成。
- Update status 兼容官方參考表的 Approved／Denied／Expired 大寫與 payload 範例的小寫，不讓已處理訊息因文字大小寫留在隊列。原本斷線不補回、公開封鎖詞限制維持。
- 修正新設定 SwitchListTile 在既有裝飾底色上的 Material/ink 警告；設定內容可捲動，小手機大字體不溢出。原設定面板開啟 AutoMod 的接線有獨立測試，不只單測孤立元件。
- 十一份 harness **95 項通過**：新增設定 harness 10 項、原 MOD sheet 追加入口 1 項，涵蓋 exact API/query/body、read/manage、不可部分覆寫、異帳號／頻道／畸形回應、官方快照、自訂保留其他分類、確認取消／競態拒絕／失去角色、已寫入後失去角色不誤報、unknown result 鎖住、320px／1.5 倍字體及設定入口。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、2 infos，exit code 1；`docs/twitch_automod_settings_test.dart:96`／`:104` if 大括號留下一輪，不反覆 analyze。上輪 9 項 model/strip/socket 提示已修；scoped `git diff --check` 通過（CRLF 提醒不屬錯誤）。
- 本輪檔案：`models/chat/twitch_automod_settings.dart`、`models/chat/twitch_automod_queue.dart`、`api/moderation/twitch_moderation_api_service.dart`、`services/chat/twitch_automod_eventsub_service.dart`、`presentation/sheets/twitch_automod_settings_sheet.dart`、`presentation/sheets/twitch_moderation_sheet.dart`、`presentation/widgets/chat/twitch_automod_queue_strip.dart`、`presentation/localization/vioclass_localizations.dart`（以上相對 lib/features/twitch）；`docs/twitch_automod_settings_test.dart`、`docs/twitch_moderation_sheet_test.dart`、本 roadmap 及 parity 文件。沒有碰禁用平台／生成資料夾。
- 續接：修兩項 test 格式提示；MOD 官方 EventSub 操作紀錄與跨管理員更新，接續釘選 fragments／revision 競態、私訊未完成契約／手機返回／捲動／通知跳轉等。全功能範圍仍以原盤點逐項完成，不縮成只做 MOD。
- 最終真人／裝置驗收追加：AutoMod read-only/manage scope、0 與 4、官方推薦 default 值、自訂保留其他分類、多 MOD 同時儲存、缺權限／授權失效、非 BMP 與中文命中位置、未知寫入結果後刷新。Windows／Android 最新 App 未啟動實測，測試替身不能代替這些驗收。

官方參考：[Get AutoMod Settings](https://dev.twitch.tv/docs/api/reference/#get-automod-settings)、[Update AutoMod Settings](https://dev.twitch.tv/docs/api/reference/#update-automod-settings)、[AutoMod event 欄位](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#automod-message-hold-event-v2)。

### 2026-10-03：私訊手機系統返回與草稿保存驗證

- 本輪分類：有進展；回到私訊的必要未完成操作，不用 MOD 單元取代先前的私訊需求。整體目標保持進行中。
- 目前私訊窄版雖有畫面返回箭頭，但缺少系統返回攔截。新增 route PopScope：只有單欄正在對話時先返回列表，再按一次才關閉；桌面雙欄已同時顯示列表／對話，系統返回直接關閉。短高度即使寬度夠大仍採單欄返回，與實際畫面一致。
- 明確按面板「關閉」直接 pop，不讓關閉按鈕被系統返回的分層規則攔住。保留外部關閉後 panelVisible=false 與 flushDrafts、既有選取序列與草稿保存；沒有改寫 controller／archive／背景收件的協議或 OAuth。
- `twitch_whisper_inbox_test.dart` 追加四個情境：390×844 手機先回列表、844×290 短橫向先回列表、1200×900 桌面雙欄直接關閉、手機明確 close 直接退出。前兩者第二次返回關閉；前三者確認記憶體草稿與注入本機磁碟 JSON 均保存、不發訊息。
- 新測試初版在 widget fake async 中等待 setup real async zone 建立的序列儲存 future 會卡住；中止已確認卡在測試等待的 session 後，修成讓兩個 zone 的微任務都前進再檢查真正磁碟結果。不刪除 persistence assertion、不以記憶體草稿冒充存檔；產品儲存碼未因此重寫。所有新測試通過。
- 十一份 regression harness **99 項通過**，其中私訊 inbox 18 項。上輪 AutoMod test 的两個 if 大括號提示已修。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、**4 warnings**、0 infos，exit code 1。`docs/twitch_whisper_inbox_test.dart:366`／`:382` 呼叫 test binding `handlePopRoute` 各產生 visible-for-testing／protected-member 警告；harness 在 docs 而不是 test/，分析器不把它視為 test。下一轮改成公開的模擬系統返回通道，或以最窄測試例外處理合理測試呼叫；本輪不反覆改後再 analyze。沒有宣稱分析完全通過。
- 本輪檔案：`lib/features/twitch/presentation/sheets/twitch_whisper_sheet.dart`、`docs/twitch_whisper_inbox_test.dart`、`docs/twitch_automod_settings_test.dart`、本 roadmap、`docs/streamnook-feature-parity.md`。
- 續接優先：先修本輪 harness 警告，再補私訊官方 API 契約測試、長對話捲動暫停與新訊息提示、通知點擊導向獨立對話、官方貼圖及 peer 資料更新。MOD 全記錄／跨管理員、釘選、其餘原盤點保持未完成，不缩小目標。
- 最終真實裝置驗收追加：Android 系統／手勢返回與鍵盤開啟的第一下返回、橫豎切換、單欄／雙欄切換、草稿實際重啟保存、Windows Esc/返回與 close 區分。測試是 Flutter route 模擬，不稱 Android 實機已通過；最新 App 尚未啟動，沒有對真人發私訊。

### 2026-10-03：私訊官方 API 契約與不確定結果保存

- 本輪分類：有進展。補官方私訊 HTTP 契約及產品錯誤狀態，不縮減原完整功能目標，也不宣告私訊或全部已完成。
- 核對 Send Whisper：選定 from_user_id 與 token user 相符、validated Client-ID、user:manage:whispers、POST body/message 與 query；204 仍可能被 Twitch 靜默丟棄，維持「已提交」而不是送達／已讀。400/401/403/404/429 原因各異，不自動重試或借其他已連結帳號。
- 修正 Get Users 只接收單一資料、數字 user-id 與指定 normalized login 相符，防止異常回應把私訊導向別人；不能對自己、無效 ID 或空白內容送出。收件訂閱檢查 session-id 與 read/manage whisper 授權，契約測試核對 websocket condition/type/version/body。没有改 OAuth/token 儲存、IRC 或 GQL hash。
- Send API 僅以官方 204 確認提交；網路逾時、5xx 或非預期 2xx 的結果標成 outcomeUnknown，帶可讀提示，不將它當成已證實拒絕。不自動重送；已證实拒絕使用電話驗證／帳號限制／找不到對象／限流等對應提示，沒有輸出 token 或私訊內文日誌。
- 新增 archive 可持久化的 `unconfirmed` 訊息狀態。controller 保留草稿並保存未確認狀態，UI 與已提交／已失敗區分；重啟仍保存未確認。從 process 中斷的 sending 恢復、匯入 sending 也改成未確認，不知道網路是否已接受時不冒稱失敗；沒有刪除或重寫其他狀態的舊歷史。恢復 loading sending 有專門測試，匯入 sending 的新分支尚需追加專門測試，不能以現有 backup merge 測試代替它。
- 上輪四項 test binding 警告以兩處單行 ignore 處理，保留真實返回測試；原因已註明：harness 依 repo 指示放在 docs/，但實際是 widget test，分析器的路徑判斷未識別。例外只限 test 呼叫，不抑制產品檔案警告。
- 十二份 harness **109 項通過**：新增 API 8 項＋inbox 2 項。涵蓋 exact HTTP/query/body／Client-ID、異帳號不可借授權、read/manage 收件、await validation 時 context 失效、精確收件者、400–429 不重試、timeout/5xx/非預期 2xx 未確認、草稿保存及 interrupted sending 恢復，不向真人發送。
- 本輪只跑一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、4 infos，exit code 1。`docs/twitch_whisper_api_test.dart:61/:66/:68` 與 `docs/twitch_whisper_inbox_test.dart:62` if 大括號提示留下一輪，不反覆分析。
- 發現且明確保留待完成：官方長度是未收過對方私訊 500、曾收過則 10000；目前 UI/controller/API 還是統一 500。不得因此把完整 Twitch 私訊勾作完成。下一單元需以正確帳號／對象的收件證據決定可用長度、處理離線歷史未知與 Unicode 字數、同步草稿／輸入／API 防截斷並測試；不能直接讓陌生人長訊息被官方靜默截短。
- 續接：修四項 test 格式提示；先做上述長訊息一致性及 import interrupted branch，再完成長對話捲動暫停／新訊息提示、官方貼圖、通知點擊跳轉及對象资料更新。其餘 MOD/釘選／原完整盘點照舊未完成。
- 本輪檔案：`api/chat/twitch_whisper_api_service.dart`、`models/chat/twitch_whisper_conversation.dart`、`services/chat/twitch_whisper_inbox_controller.dart`、`services/chat/twitch_whisper_archive_store.dart`、`presentation/sheets/twitch_whisper_sheet.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch），`docs/twitch_whisper_api_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 及 parity。沒有讀改禁止平台／生成資料夾。
- 最終驗收追加：真實電話驗證／陌生人私訊限制、Twitch 實際限流、204 靜默丟棄不能判定送達、斷網時結果未知及重啟保存、長訊息／emoji 字數及對方回覆證據。最新版 App 未啟動或實機驗證；所有 HTTP 為替身。

官方參考：[Send Whisper](https://dev.twitch.tv/docs/api/reference/#send-whisper)。

### 2026-10-03：私訊長內容額度與收件證據保存

- 本輪分類：有進展。接上已確認關係的較長私訊，不縮小全功能目標，且保留未證實的 Unicode／離線關係界線。
- conversation 新增可持久化 `hasReceivedWhisper`：只有當前 owner 的官方 receiveEvent 對應 peer、有效 incoming 且 state=received 經 archive.append 保存時取得；自己的已提交／失敗／未確認不解鎖，異帳號事件不解鎖。新欄位隨 owner 隔離 archive 保存，重新載入同帳號保留，切另一帳號不借用。
- 模型 sendLimit 與 UI／controller/API 一致：未確認關係 500、取得收件證據 10000。API 新增 optional hasReceivedWhisper，預設 false 保留既有呼叫保護；controller 凍結原 peer 的資格與 draft，並仍在 await auth 後核對當前 owner/context。沒有改 OAuth/token 保存、GQL hash 或 IRC。
- 不用備份裡可被改寫的 received 狀態／旗標當成新官方證據：新匯入 peer 強制未知，已存在 peer 保留本機當前旗標，匯入不降級已確認資格也不升級未知資格。匯入 interrupted sending 轉 unconfirmed 有新專門測試，不只一般 backup merge 測試。
- UI 移除會提前截短草稿的固定 maxLength；使用相同長度計數顯示額度，超額顯示錯誤並停用傳送，內容原樣保存。表情插入使用同一 peer 額度；輸入與表情更新立即刷新 counter／按鈕。空白草稿也停用傳送，不發假請求。
- **Unicode 界線**：官方只寫 characters，沒有明訂非 BMP、組合字／ZWJ 的計數單位。本單元沿用且統一 Dart UTF-16 code-unit 計數，介面提示部分表情佔兩格；這是防止被伺服器默默截短的保守判定，不宣稱與 Twitch 完整 Unicode 字數規則相同。10000 ASCII exact body 與 500-unit emoji 邊界有測試；完整 Unicode 容量仍需官方證據／真人裝置验收。
- **離線／舊歷史界線**：舊 archive 缺少新旗標、純匯入／遠端既有對話未收到新事件時，仍是未確認 500。未加未授權私有 hash 或冒稱已查完整 Twitch 關係；不能以本單元替代遠端歷史／所有舊對話的完整對齊。
- 十二份 harness **114 項通過**：新增 API 長度 1 項、inbox 4 項，驗證 10000 原樣送出／10001 擋住、emoji 額度一致、501 未知關係留草稿、自己發送／外帳號不解鎖、真正 incoming 解鎖、同帳號重載與他帳號隔離、import 偽造旗標不解鎖與 interrupted branch、手機超額內容顯示與停用傳送。不對真人發送。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。上輪四項 test if 大括號提示已修，沒有分析修正循環。
- 本輪檔案：`models/chat/twitch_whisper_conversation.dart`、`services/chat/twitch_whisper_archive_store.dart`、`api/chat/twitch_whisper_api_service.dart`、`services/chat/twitch_whisper_inbox_controller.dart`、`presentation/sheets/twitch_whisper_sheet.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch），`docs/twitch_whisper_api_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。只在允許範圍工作。
- 續接優先：長對話捲動暫停／新訊息提示及實際接線測試、通知點擊導向正確帳號／獨立對話、官方貼圖／peer 資料。Unicode／舊 archive 關係仍需補證據；其餘原盤點 MOD/釘選/聊天/播放/設定/多視窗範圍未變，不用本單元當作全部完成。
- 最終驗收追加：真正首次／已互傳對象 500／10000 邊界、手機貼入長文、emoji／ZWJ／組合字、來訊當下額度切換、切帳號／重啟／匯入備份後顯示與資格。尚未啟動最新版 App 或在 Android 實機驗收；mock 204 不证明 Twitch 真正接受完整內容或送達。

### 2026-10-03：私訊閱讀位置與新訊息提示

- 本輪分類：有進展，僅完成私訊閱讀位置子單元，整體功能對齊仍未完成。
- controller 區分對話已開啟與正在最新位置閱讀。往上閱讀時收到來訊保留未讀，不因對話仍顯示或 App 恢復前景而提前清除；返回最新位置才清除。這是本機未讀狀態，不是 Twitch 已讀回執。
- 面板保留往上閱讀時的捲動位置，顯示「新私訊 · 數量 · 返回最新訊息」入口；點擊後回到最新並清除提示。owner／peer 一起隔離捲動觀察，避免不同帳號的同一 peer 共用畫面判定。
- 已顯示的對話即使往上閱讀，也不重複發出全域通知；關閉面板、其他對話與背景收件維持既有通知入口。沒有修改遠端 API、OAuth、IRC 或原生平台檔案。
- 追加兩項測試：controller 驗證暫停閱讀、前景恢復及返回最新的未讀狀態；390×844 widget 以 35 筆歷史驗證來訊不跳動、提示顯示、點擊後最新內容與未讀清除。十二份 regression harness 共 **116 項通過**。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。不重複執行分析。
- 本輪檔案：`lib/features/twitch/services/chat/twitch_whisper_inbox_controller.dart`、`lib/features/twitch/presentation/sheets/twitch_whisper_sheet.dart`、`lib/features/twitch/presentation/localization/vioclass_localizations.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- 尚待驗證／補齊：高度差異很大的長訊息是否一次跳到真正末尾、鍵盤與視窗尺寸改變時的閱讀判定、快速切帳號／對話、Android 真正捲動與返回。現有固定歷史測試不能替代全部幾何與實機情境。
- 下一單元：通知點擊導向正確 owner／peer 的獨立私訊對話，避免切帳號或對方改名後誤開；再接官方貼圖與 peer 資料更新。完整 MOD、釘選及其他原盤點保持未完成，最新版 App 尚未啟動實測。

### 2026-10-03：私訊通知精確對話跳轉

- 本輪分類：有進展。Windows 浮出通知及通知列現在都能點擊開啟對應私訊；不是只開空白列表，也沒有把私訊併入聊天室事件。既有通知外觀不改。
- 通知保存 owner ID／peer ID，launcher 只選取同帳號已存在的本機對話；不重新以舊 login 查人、不因改名誤開另一人、不自動發訊息。選取等待期間若帳號、選取對象、launcher 或 opener 改變，拒絕舊通知；刪除的對話不以查人重建。草稿維持原保存流程。
- 通知點擊先關閉通知列及隱藏該浮出卡片，避免遮住私訊；重複點擊等待中不再開新面板。錯帳號／不存在對話提供一般提示，不借另一帳號。卡片的關閉按鈕仍只關閉通知。
- Windows showWhisper 接入型別化 target；Android payload 改為 owner／peer 雙 ID，現有 plugin 的 onDidReceiveNotificationResponse 接到相同 launcher。舊缺 owner 的 payload、不合法 ID、自傳及非私訊 payload 都不採用，未加入訊息正文或 token。
- **Android 界線**：這次接的是 App 已執行時的通知點擊回呼。完全關閉 App 後的 notification launch details、launcher／archive 尚未就緒的暫存與重播、背景恢復時序仍未實作／驗證，不宣稱手機完整通知跳轉完成。未讀仍是本機狀態而非 Twitch 已讀回執。
- 十二份 regression harness **121 項通過**，私訊 inbox 31 項。本轮新增五項：Windows 通知產生的 owner/peer target 與無正文、payload 驗證、ID 選取／不查 login／草稿保留／錯帳號及失效 launcher 拒絕、浮出卡片點擊、通知列點擊。這些是模擬測試，不是 Android 原生 plugin 或真實系統通知驗收。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。沒有為驗證向真人發私訊。
- 本輪檔案：`presentation/settings/twitch_app_settings_launcher.dart`、`presentation/pages/twitch_stream_page_parts/01_color.dart`、`presentation/widgets/notifications/twitch_app_notification_overlay.dart`、`services/notifications/twitch_app_notification_service.dart`、`services/notifications/twitch_system_notification_service.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。沒有讀改禁用平台／生成資料夾。
- 續接：Android 冷啟動及帳號／資料未就緒的通知處理、長內容可變高度末尾定位與鍵盤尺寸判定、官方貼圖／對象資料；其餘 MOD/釘選/聊天/播放/設定/多視窗仍依原盘點未完成。真人／裝置驗收：Windows 通知列與浮出卡片、關閉與快速連點、切帳號及已刪對話、Android 前景／背景／冷啟動通知點擊。最新 App 尚未啟動實測。

### 2026-10-03：Android 通知冷啟動與就緒等待

- 本輪分類：有進展。依 plugin 官方 getNotificationAppLaunchDetails 接入通知啟動目的地；首頁第一幀後初始化，未使用禁用 Android 原生檔案，也沒有修改 OAuth/token 儲存。
- launcher 保存最新明確點擊的 owner／peer 目的地，等待 inbox attachment、第一次 session/archive 載入完成、畫面導航就緒及前景狀態，再走原 ID 精確開啟。多個待處理點擊以最後一個為準；同一對話正在開啟時忽略重複，另一對話待前一面板返回後再處理。dispose 清理待處理資料；detach 暫停，不自行換帳號或送訊息。
- 已登出／缺授權／載入失敗在 session 已解析後拒絕並提示，不把通知留到往後登入任意帳號再誤開。通知屬於其他 owner 或已刪對話仍依上輪規則拒絕。sessionReady 只代表首次載入已結束，不表示認證一定成功。
- controller 前景變更現在通知 listener，修正新測試發現的「背景點擊回到前景仍停在等待」；相同前景狀態不重複通知，disposed 不再操作。原本閱讀舊訊息不提前清未讀的回歸保持通過。
- service 只讀一次冷啟動資料，不因再次 initialize 重播；讀取過程已有 live response 時不採舊 launch 目的地覆蓋較新點擊。啟動資料讀取失敗不因此取消正常系統通知初始化，但該次目的地可能無法恢復，仍需實機異常情境驗證。
- 十二份 regression harness **125 項通過**，私訊 inbox 35 項。本輪新增四項：attachment/navigation/session 等待、foreground／重複點擊／後續目的地、登出後拒絕且不延遲借用、真實 Dart plugin + 模擬 method channel 的 cold launch/live callback/initialize 不重播。初版兩項失敗正確找出 foreground listener 缺失，修正產品接線後完整回歸通過，未刪除失敗斷言。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、**3 infos，exit code 1**。`presentation/settings/twitch_app_settings_launcher.dart:53`、`services/notifications/twitch_system_notification_service.dart:56/:70` 的 if 大括號提示留下一輪，不反覆 analyze。
- 本輪檔案：`services/chat/twitch_whisper_inbox_controller.dart`、`presentation/settings/twitch_app_settings_launcher.dart`、`services/notifications/twitch_system_notification_service.dart`、`presentation/pages/twitch_stream_page_parts/01_color.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- **驗證界線**：method channel 模擬證明 Dart/plugin 接線，不是 Android 真正殺程序後的系統 Intent、通知權限或背景保活驗收。App 關閉期間沒有新增後台遠端接收能力；已有通知啟動也只能讀取原本保存的對話，沒有補齊離線訊息。最新 Windows／Android App 未啟動實測。
- 续接：先修三項格式提示，再處理私訊可變高度長文末尾定位、鍵盤／尺寸改變的閱讀判定與快速切換，繼續官方貼圖／對象資料及其餘原全功能盤點。Android 真實前景／背景／冷啟動、尚未登入、缺 scope、錯帳號／已刪對話、連續點不同通知、權限拒絕仍列最終驗收。

官方來源：[plugin 冷啟動 API](https://pub.dev/documentation/flutter_local_notifications/latest/flutter_local_notifications/FlutterLocalNotificationsPlugin/getNotificationAppLaunchDetails.html)、[plugin 官方說明](https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/README.md)。

### 2026-10-03：私訊可變高度末尾定位與尺寸變更

- 本輪分類：有進展。上輪 launcher／notification service 三項 if 大括號提示已修；接續私訊長文閱讀行為，不縮小完整對齊目標。
- 保留原本由舊到新排列的訊息列表，沒有改成插入後會移動舊內容的倒序列表。返回最新改為等待排版後校正 lazy ListView 的估算最大位置；實際最後一則必須已建立、且 extentAfter 到達末尾，才結束校正。捲動中的暫時估算位置不提前清除未讀。
- 列表接入 ScrollMetricsNotification，鍵盤／視窗幾何改變時重新確認閱讀狀態：原本在最新位置則重新跟到末尾，原本往上讀則保留位置並重新判斷。不在 layout 通知當下 setState，改在 frame 後處理。
- 待處理捲動使用 request 序列與 owner/peer 觀察鍵；換對話或使用者開始拖動即取消舊校正，過期尺寸／自動捲動 callback 不再拉回。最後訊息 key 隨對話更新，避免把前一對話的 tail 當作新對話末尾。這些取消分支仍需追加直接時序測試，沒有以程式碼存在冒稱全部驗證。
- **校正界線**：每次最多 33 個 layout 校正步，避免異常內容造成永久 frame 循環。此輪測試達到真正末尾；極大歷史／持續變動高度或達到步數上限仍需壓力驗證，不能宣稱任何大小歷史都已保證末尾。仍以實際最後列是否建立判斷閱讀，不以估算 end 冒充全部訊息已讀。
- 擴充原有等高歷史測試的 extentAfter 斷言，另加可變高度案例：35 筆歷史每四筆含 35 行長文，新來訊 50 行；390px 手機最新位置開鍵盤、往上讀時關鍵盤並變寬至 420px、返回最新、再開鍵盤。確認位置保留、未讀仍為 1、返回後末尾 <=0.5px／未讀清除／沒有例外。
- 十二份 regression harness **126 項通過**，私訊 inbox 36 項。本輪一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、**2 infos，exit code 1**。`presentation/sheets/twitch_whisper_sheet.dart:85/:94` 多行 if 大括號提示留下一輪，不反覆 analyze。
- 本輪檔案：`presentation/sheets/twitch_whisper_sheet.dart`、`presentation/settings/twitch_app_settings_launcher.dart`、`services/notifications/twitch_system_notification_service.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。沒有改協議、token、原生平台或播放器 runtime。
- 續接：先修兩項格式提示，補拖動中取消校正／快速切 owner/peer 的直接測試，再接官方貼圖及對象資料更新。其餘原盤點保持未完成；Android 真正鍵盤／旋轉／手勢、Windows 拖曳視窗、極大長歷史與通知冷啟動仍列最終實機驗收，本輪未啟動 App。

### 2026-10-03：私訊對象名稱更新與資料保存

- 本輪分類：有進展。核對官方 Whisper Received Event 的 from_user_login／from_user_name，更新同 user ID 的既有對話，而不是新增另一份改名後的歷史。未改私訊發送協議、OAuth 或任何 persisted hash。
- controller 對資料欄位檢查型別與非空值，login 正規化為小寫；缺漏／畸形資料不以數字 ID 或空白覆蓋既有名字。archive append 只接受有效 incoming received 的名稱更新，自己發送不改資料；只改提供的欄位，保留頭像、草稿、歷史、未讀與收件資格。
- profileObservedAt 隨本帳號 archive 保存，用來排除較舊事件或相同 ID 重複事件的名稱回退；只代表觀察事件的時間，不是 Twitch 官方 profile 修改時間。缺欄位的舊 archive 仍可載入。單一觀察時間對部分欄位採保守拒絕舊事件，沒有宣稱官方完整 profile 版本同步。
- 新匯入 peer 不信任備份裡的觀察時間，避免未來時間阻擋後續真實來訊更新；既有 peer 匯入不改本機 metadata。通知名稱使用 reload 後保存的對話，不讓晚到旧事件的名稱顯示在新提示。
- 十二份 regression harness **130 項通過**，私訊 inbox 40 項。本輪新增四項：改名／晚到事件與持久化／草稿歷史未讀頭像保留、部分／畸形欄位與 duplicate、import 未來時間與既有 metadata 保護、已開面板即時顯示新名稱而輸入草稿不變。widget 初版 finder 同時找到搜尋框與輸入框，修成精確選取最後的 composer，完整回歸通過；沒有刪除草稿 assertion。
- 上輪 sheet 兩項 if 大括號提示已修。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、**1 warning**、0 infos，exit code 1。`services/chat/twitch_whisper_archive_store.dart:172` 的多餘 non-null assertion 留下一輪；本輪 test finder 修改後未重跑 analyze，遵守單次限制。
- 本輪檔案：`models/chat/twitch_whisper_conversation.dart`、`services/chat/twitch_whisper_archive_store.dart`、`services/chat/twitch_whisper_inbox_controller.dart`、`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- **界線**：這是官方來訊提供的名字更新，不是 Get Users 主動 profile／頭像刷新；沒有新來訊時的改名／新頭像仍待接入精確 ID 查詢。未收到的離線私訊、官方貼圖、遠端歷史、捲動取消／快速切換直接測試以及其他原盤點仍未完成。本輪未啟動 Windows／Android App，沒有使用真人帳號發訊息。
- 續接：修單一 warning，接私訊官方貼圖及必要 user ID profile 讀取，補捲動時序測試；最終真人／裝置驗收加入改名與換頭像、對方改名後點舊通知、App 重啟顯示、姓名部分欄位與多語字體，不以替身測試替代。

官方來源：[Whisper Received Event](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#whisper-received-event)。

### 2026-10-03：私訊固定 ID 主動名稱與頭像刷新

- 本輪分類：有進展。增加對話頁「更新對象資料」入口，主動讀取 Get Users 的固定 peer ID，不以可能已更換的 login 查另一人。尚未加入背景批次／開面板自動刷新，不以手動入口冒稱即時全域 profile 同步。
- API 使用目前 owner 的既有已驗證 token／Client-ID，GET `/users?id=peerId`，不要求額外 email scope 或改 OAuth 儲存。拒絕自己／非法 ID、空／多筆／不符 ID 或畸形名稱；頭像只接受有效無 userinfo 的 HTTPS URL，官方空字串可清除舊頭像。不符合資料時保留原本對話，不猜測已停權／刪除原因。
- controller 凍結 owner、generation、peer 與 selection 序列；查詢授權完成前及回應／archive 排隊後檢查 context。從 A 切列表再回 A 也不套用舊請求；查詢中鎖住重複刷新。重載 session／登出重置刷新狀態，舊請求不會把另一帳號狀態改回來。
- archive 只更新已存在的 ID 對話，不建立另一份遠端歷史；草稿、messages、unread 與 hasReceivedWhisper 原值保持。若等待查詢期間已有较新 incoming 名稱，保留較新名字；更新頭像因 incoming 不提供圖片而獨立套用。空頭像以明確 replaceAvatar 清除，不因 nullable copyWith 而無法清掉。profileObservedAt 仍是本機觀察順序，並非官方版本／原子 CAS。
- 十二份 regression harness **135 項通過**，私訊 API 11 項、inbox 43 項。本輪新增五項：GET exact ID／selected headers、context／錯 ID／畸形資料與非 HTTPS 拒絕／空圖片、controller 成功與失敗保留及 A→列表→A 舊回應拒絕、archive 較新名字與清頭像／未讀歷史保留、390px 手機實際按刷新入口且 composer 草稿不變。現有窄版／鍵盤／長文回歸維持通過。
- 上輪 archive 多餘 non-null assertion warning 已修。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**；scoped diff check 通過。沒有查真人帳號或發私訊。
- 本輪檔案：`api/chat/twitch_whisper_api_service.dart`、`models/chat/twitch_whisper_conversation.dart`、`services/chat/twitch_whisper_archive_store.dart`、`services/chat/twitch_whisper_inbox_controller.dart`、`presentation/sheets/twitch_whisper_sheet.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_api_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- 尚待：極短橫向 compact header 未放手動刷新入口；自動／批次 profile 刷新、完整官方貼圖、遠端歷史、捲動快速切換／取消時序及原 MOD/聊天/播放/設定/多視窗盤點。最新 App 未啟動；真實改名後刷新與舊通知、實際換／清頭像、斷網／失去授權、切帳號等待、Android 橫豎切換仍列集中實機驗收。
- 續接優先：私訊官方貼圖資料、選擇與顯示接線，再补上述未驗證時序與 compact 入口。沒有以新增刷新功能代替完整私訊或整體目標完成。

官方來源：[Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)。

### 2026-10-03：私訊官方貼圖資料、選擇與推定顯示

- 本輪分類：有進展。私訊開啟時載入官方全域貼圖與當前 owner 的 Get User Emotes；選擇器提供搜尋、圖片、名稱、載入／錯誤／重試。原 Unicode 表情入口保留，不接 7TV 登入、徽章或名字特效，不修改既有貼圖 GQL hash。
- Get User Emotes 使用同帳號的 user:read:emotes 與已驗證 Client-ID/token，不借其他帳號。query 只有 user_id 與 after，沒有把對方當 broadcaster_id 加入頻道限定 follower 解鎖；依官方 API 的跨頻道可用回應收集全頁。缺 scope／個人載入失敗顯示原因並保留 globals；重複 cursor 或超過 100 個非空 cursor 終止並丟棄部分 user 結果，不讓使用者誤以為部分回應是完整清單。
- catalog 以 ID 去重，用既有官方 emote 模型；合法 ID 才形成官方 CDN URL，沒有使用回應中的任意圖片 host。名稱索引只建立一次，同名不同 ID 不做推定替換；保留大小寫、空白與原文。
- **顯示界線**：官方 Whisper Received Event 只有 whisper.text，沒有 emote positions/fragments。此處是當前 catalog 的完整空白分隔 token、大小寫精確比對，不冒充官方訊息貼圖標籤；Kappa!／kappa／URL／未知或歧義 token 保留文字。無法用 viewer 的 catalog 保證辨認對方全部個人貼圖，也沒有離線完整貼圖歷史。
- 已辨認 token 以 inline image 顯示，支援模型的 animated URL，圖片失敗顯示代碼；未知部分維持文字。archive 一律存原始文字。因 SelectableText.rich 官方不支持 WidgetSpan，貼圖內容改用 SelectionArea/Text.rich；新增明確「複製原始訊息」按鈕保留整則原文。**未完成**：標準局部選取／快捷鍵複製的圖片 token 仍需映射驗證，不能把整則複製入口當作所有選取功能完成。
- 選擇貼圖只插入代碼與必要空白到原 cursor／選取區，使用現有 500／10000 額度，不截短／自動發送。面板等待期間 owner、peer、草稿或 catalog 改變就不套用舊選取；載入中／全域失敗時停用選取，避免使用舊 personal 資格。選擇器可捲動，手機有鍵盤時不溢出。
- 十二份 regression harness **141 項通過**，私訊 API 14 項、inbox 46 項。本輪新增六項：API exact owner/headers/query/pagination、缺 scope／重複 cursor fallback、歧義／大小寫／URL／空白原文解析、logout 及晚回應清除 catalog、390px 手機鍵盤關／開兩個实际 picker→草稿插入→inline SelectionArea 情境。測試確認不傳訊息；圖片下載與動畫是錯誤 fallback 的替身環境，不稱實際 CDN 像素／動畫已驗收。
- 本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、**1 info，exit code 1**。`api/chat/twitch_whisper_api_service.dart:233` 的 use_null_aware_elements 提示留下一輪，不反覆 analyze。
- 本輪檔案：新增 `models/chat/twitch_whisper_emote_catalog.dart`；修改 `api/chat/twitch_whisper_api_service.dart`、`services/chat/twitch_whisper_inbox_controller.dart`、`presentation/sheets/twitch_whisper_sheet.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_api_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- 續接：先修 info，补 picker 搜尋／取消／選取區／額度／context 改變的直接測試，局部複製原文映射、第三方貼圖與對方未知官方 token 的資料界線、圖片完成後捲動定位；再回原完整 MOD/聊天/播放/設定/多視窗盤點。compact profile 入口與捲動取消／快速切換仍待完成。本輪未啟動 Windows／Android，也未使用真人帳號發私訊；真實 scope、訂閱權益／follower 跨場景、靜態／動畫 CDN、背景與改帳號仍列最終驗收。

官方來源：[Get User Emotes](https://dev.twitch.tv/docs/api/reference/#get-user-emotes)、[Whisper Received Event](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#whisper-received-event)、[SelectableText.rich 限制](https://api.flutter.dev/flutter/material/SelectableText/SelectableText.rich.html)。

### 2026-10-03：私訊貼圖選擇器時序與原文複製驗證

- 本輪分類：有進展。新增六項直接 widget 測試：搜尋／取消／反向選取替換、未知對象 500 額度拒絕、選擇器開啟中收到有效來訊後使用 10000 額度、草稿改變拒絕舊選取、切換帳號拒絕舊選取、整則原文複製。沒有自動傳訊息或改授權／發送協議。
- 測試找出實際問題：選擇器開啟後收到來訊，插入仍使用開啟時的舊 peer 額度；現在通過 owner／peer／草稿／catalog 檢查後，改採目前 activeConversation 的額度。499 字未知草稿不能加貼圖；同一草稿在有效收件解鎖後可插入，原文不截短。
- 整則複製以模擬 Clipboard.setData 捕捉實際內容，確認貼圖代碼、換行、emoji、tab 與未知 token 完整保留，沒有圖片佔位符。這只證明「複製原始訊息」入口，**不是局部選取或快捷鍵複製圖片 token 已完成**；CDN 圖片像素與動畫仍未實測。
- 帳號切換測試初版卡在 fake／real 排程交界，已中斷該次測試並修正等待方式；保留 session 完成、owner、對話／catalog 清空與不送訊息斷言。單獨 inbox **52 項通過**，十二份完整 regression harness **147 項通過**。
- 上輪 API null-aware info 已修。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：0 errors、0 warnings、**1 info，exit code 1**。`docs/twitch_whisper_inbox_test.dart:1120` 的 if 大括號格式提示留下一輪，不反覆分析或修到通過。
- 本輪修改：`api/chat/twitch_whisper_api_service.dart`、`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。沒有啟動 App、使用真人帳號或推送 GitHub。
- 續接：修單一測試格式提示；處理局部複製圖片 token 的正確映射、短橫向／大字體貼圖選擇器及 compact profile 入口，補捲動取消／快速切換時序，再回完整 MOD／聊天／播放／設定／多視窗盤點。完整目標仍未完成；最終 Windows／Android、真實 scope／訂閱資格／CDN／通知驗收保持待測。

### 2026-10-03：私訊短橫向入口與貼圖選擇器可用高度

- 本輪分類：有進展。compact 私訊頁標題列補上「更新對象資料」，使用同一固定 ID refreshActiveProfile 與刷新中停用規則；原返回／關閉保持。不改其他頁面外框或播放器。
- 貼圖選擇器改用扣除鍵盤及安全區後的可用高度，貼圖區限制在 76～380 logical pixels；搜尋／錯誤提示與貼圖區不再同塞固定高度 Expanded Column，改由 dialog 外層捲動容納，內層 grid 仍可獨立捲動。貼圖列高度依文字縮放調整，不關閉大字體設定。
- 新增三項直接 widget 測試：844×390 短橫向加 160px 鍵盤、390×844 手機加 280px 鍵盤／兩倍字體，都實際搜尋並選取 Kappa、確認草稿及不發送／無例外；844×260 compact 標題列實際刷新 peer ID，名稱更新且草稿保留。不是只檢查按鈕存在。
- inbox **55 項通過**，十二份完整 regression harness **150 項通過**。上輪測試 if 大括號 info 已修；本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。scoped diff check 通過。
- 本輪修改：`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。未啟動 App、未使用真人帳號、未推送或發布。
- 續接：局部選取／快捷鍵複製圖片 token、圖片完成後捲動與取消／快速 owner／peer 切換直接時序；其後回完整 MOD／聊天／播放／設定／多視窗盤點。極短視窗／多行錯誤提示／大量貼圖及真實 Android 鍵盤旋轉、Windows 大字體仍列最終驗收，不以三項尺寸替代所有裝置。

### 2026-10-03：私訊捲動取消時序與未解的估算末尾問題

- 本輪分類：有進展，**尚有失敗回歸，不能稱完成**。新增四項測試，保留 pointer gesture 失敗案例且沒有 skip／刪除斷言：直接 drag-start notification、真實 tester pointer gesture、待處理 metrics 切 peer、待處理 metrics 切 owner。
- peer／owner 切換與直接 notification 案例通過；45 筆混合長短歷史加 40 行新訊息，在返回最新尚未完成排版時開始 pointer 拖曳，extentAfter 預期 >90，實際 0。observer 證明已收到含 dragDetails 的 ScrollStartNotification，不是沒有觸發手勢。
- 新增 scrollTrace 隨失敗輸出保留證據：初始 jump 估算最大 30314.68，拖動位置 30134.68／29954.68，下一排版最大縮到 13714.68，之後位置回到末尾。這支持「可變高度估算縮短造成 out-of-range／回彈」而非單純舊回呼未取消；精確 Flutter layout／ballistic 因果仍需進一步驗證。
- 產品增加 _userDragging：拖曳開始即退出 readingLatest、取消 seeking；拖曳期間 scroll listener／metrics 不自動跟最新或確認已讀；ScrollEnd 重新判斷，換 peer／owner 重置。此保護尚不能解決上段估算回彈，**不能宣稱拖曳已修好或未讀完整保證**。
- 十二份完整 regression harness **153 通過、1 失敗，exit code 1**（總 154）；失敗名稱 `pointer gesture cancels pending private latest correction without clearing unread`。前一版只直接通知時 58 項 inbox 通過，但不足以證明真實 gesture；因此把 pointer 失敗測試加回正式回歸。曾有 DragStartDetails 誤加 const 的編譯錯誤，已修。
- 本輪只一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**；scoped diff check 通過。分析沒有問題不代表 pointer 測試已通過。沒有操作真人帳號、App 或禁用平台資料夾。
- 本輪修改：`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- **下一輪優先**：沿保留的失敗測試處理可變高度估算校正與使用者拖曳的交錯，不降低 extentAfter／未讀斷言，也不以通知模擬取代 pointer gesture。之後續接局部複製貼圖及原完整 MOD／聊天／播放／設定／多視窗盤點；整體目標保持未完成。

### 2026-10-03：私訊拖曳中估算範圍縮短修正

- 本輪分類：有進展。沿上輪失敗的 pointer gesture 測試修正，保留 extentAfter >90、readingLatest=false、未讀=1、後續位置不變的原斷言，沒有 skip 或換成只通知測試。
- 私訊 ListView 使用局部 ScrollPhysics 包裝，經官方 adjustPositionForNewDimensions hook 在 layout 修正位置。只在使用者拖曳中、仍在 scrolling、viewport 高度未變、估算最大縮短、原位置未越界而新位置超出新末尾時，保留原本離末尾的距離，並限制在新合法範圍。普通捲動／idle、鍵盤或尺寸改變、範圍增長、真正 overscroll 交還父平台 physics；不改播放器 runtime、訊息順序或全 App physics。
- 上輪失敗的長短歷史／返回最新中斷案例現在通過，擴充 Windows 與 Android TargetPlatformVariant 的 pointer 手勢；都有 observer 證明 drag-start，未讀保持且 500ms 後不被拉回。再按返回最新，實際 extentAfter <=0.5、readingLatest=true、未讀=0。
- 新增維度校正邊界測試：1000 最大／800 位置縮為 500，拖曳校正為 300，保留 200 距離；viewport 改變、仍在合法範圍、真 overscroll、範圍增加、idle、拖曳結束均與繼承平台規則一致。這是幾何／捲動行為測試，不證明極大歷史任意內容或實際裝置都已驗收。
- 平台測試初版直接設 debugDefaultTargetPlatformOverride 於 addTearDown 恢復，觸發 framework invariant；改用正式 TargetPlatformVariant，在測試 framework 正確時機恢復，沒有刪除操作斷言。
- 十二份完整 regression harness **156 項通過**，inbox **61 項**，exit code 0；本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。scoped diff check 通過。上段 153 通過／1 失敗為歷史結果，本輪已修該案例。
- 本輪修改：`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。沒有 App 啟動、真人收發、GitHub 推送或平台原生檔案改動。
- 續接：私訊貼圖局部選取／快捷鍵原文映射與圖片完成後尺寸／位置，再回完整 MOD／聊天／播放／設定／多視窗盤點。真正 Windows 滑鼠拖曳／觸控板、Android 手勢與鍵盤旋轉、極大長歷史／33 步校正上限仍待最終實機與壓力驗收，完整對齊未完成。

官方來源：[ScrollPhysics 維度校正 hook](https://api.flutter.dev/flutter/widgets/ScrollPhysics/adjustPositionForNewDimensions.html)。

### 2026-10-03：私訊圖片貼圖參與原生選取與複製

- 本輪分類：有進展。建立真正成功載入圖片的測試 fixture：記憶體 Canvas 28×28 bitmap 預載至 NetworkImage cache，斷言 RawImage.image 非空，再操作 SelectableRegion 的標準 copy action。原本複製 `before Kappa after` 得到 `before  after`，確認既有圖片 fallback 測試不足以驗證圖片選取。
- 新增 `TwitchSelectableEmote` RenderProxyBox，依 Flutter 公開 Selectable／SelectionRegistrant 介面把圖片視為一個原文 token；bounding box 與 highlight 是圖片真實矩形，clipboard content 為代碼。不是隱藏文字、把整則複製按鈕冒充局部選取，或修改 InlineSpan 佔位長度破壞文字索引。
- WidgetSpan 的图片／tooltip 包進 selectable wrapper，child 以 SelectionContainer.disabled 防止失敗 fallback Text 再註冊而複製兩次。保留既有 image 尺寸、原文 archive、明確整則原文複製入口及未知 token 文字。
- 支援 select-all、clear、圖片單字選取與 start/end edge；geometry 包含兩端 points、真實 selection rect，paint 接 handle layers。單一 edge 暫時狀態採 collapsed geometry，修正新 mouse double-click 測試發現的 SelectionGeometry assertion；文字或 registrar 更新、移除／dispose 不留舊 listener。
- loaded image widget 測試現在標準全選 copy 保留完整句子，滑鼠雙擊貼圖後標準 copy 只得到 `Kappa`，不發訊息。新增兩項 rendering 測試驗證 bounds／代碼／clear／dispose 及正反向 edge／previous-next traversal，不以只測 pure catalog 代替 UI。
- 十三份完整 regression harness **159 項通過**；隨後針對 selectionColor repaint／dispose／公開 override 型別調整重跑兩份相關 harness **64 項通過**（inbox 62、selectable emote 2）。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**；scoped diff check 通過。
- 本輪檔案：新增 `presentation/widgets/chat/twitch_selectable_emote.dart`、`docs/twitch_selectable_emote_test.dart`；修改 `presentation/sheets/twitch_whisper_sheet.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。未啟動 App、真人收發、改 token 或平台原生檔案。
- **尚未完成**：跨多行／多貼圖／RTL 混合的實際 drag selection、Android 長按／handle 拖曳、Ctrl+C keyboard routing、Shift+方向鍵／word／paragraph 延伸。自訂圖片尚未處理 directional／granular／paragraph selection event，不把 select-all + mouse double-click 通過當成完整原生選取完成。圖片 CDN／動畫、完成後捲動與極大歷史仍待測。
- 續接：優先完成上述 selection event 與跨文字／圖片範圍測試，再回原完整 MOD／聊天／播放／設定／多視窗盤點；完整對齊目標保持未完成。

官方來源：[Selectable 介面](https://api.flutter.dev/flutter/rendering/Selectable-mixin.html)、[SelectionRegistrant](https://api.flutter.dev/flutter/rendering/SelectionRegistrant-mixin.html)、[標準選取選單 copy action](https://api.flutter.dev/flutter/widgets/SelectableRegionState/contextMenuButtonItems.html)。

### 2026-10-03：貼圖鍵盤事件、Windows copy 與未解交界選取

- 本輪分類：有進展，但保留一項失敗，**完整選取仍未完成**。圖片加入 granular character／word／較大範圍與 directional horizontal／vertical event，單一 token 以兩端邊界移動，超出 token 時 previous／next 讓 delegate 繼續相鄰內容；paragraph hit／absorb 也已接入。word 命中回傳 end、paragraph absorb 回傳 next，不只改 geometry 而不回報路由。
- Windows 正式 TargetPlatformVariant 的 loaded image 測試驗證標準 copy、雙擊 token 與真正 Ctrl+C key event；Ctrl+C 已能複製 Kappa。初版 default Android copy 會清 selection，不能沿用清掉的 selection 測 Windows keyboard，因此使用 Windows variant，沒有降低複製斷言。
- Windows 保留 selection 關閉面板時發現晚到 pushHandleLayers 對 disposed renderer 的 assertion；現在 registrar 隨 attach／detach 取得／解除、dispose 清註冊與 guarded 晚到 handle 更新。原測試移除整棵 widget 樹後不再例外，不以先清 selection 隱藏 lifecycle 問題。
- 新增三項 render-level event 測試：character／word 正反向與 edge traversal、水平 dx／上下行、paragraph hit／absorb。另有純 Flutter 普通 Text 對照：雙擊 Kappa 後 Shift+右再 Ctrl+C，正確結果 `Kappa `（只增加空白）。
- **保留失敗**：同樣操作圖片 Kappa 得到 `Kappa after`，而非 `Kappa `。圖片事件追蹤收到 `GranularlyExtendSelectionEvent forward=true isEnd=true character`，不是快捷鍵被當 word。曾嘗試放寬為整個 after，但普通文字對照否定；已恢復原正確 `Kappa ` 斷言，沒有 skip。臨時 debugPrint 已移除。
- 核對 Flutter 3.38.4 官方 paragraph source：WidgetSpan 分隔文字片段與各片段的 range／character boundary 涉及全域及局部 offset；**疑似**相鄰文字片段的 offset 問題，還未以純 WidgetSpan 對照證實完整因果，不能直接宣稱 Flutter 已確診。下一輪先補該對照並檢查本機 selection range／路由；如需局部整則 renderer 或 delegate 修正，限 Twitch scope，不讀改 SDK 或禁用平台。
- 十三份完整 regression harness **162 通過、1 失敗（總 163），exit code 1**。失敗為 `loaded private emote selection copies original tokens through native copy action (variant: TargetPlatform.windows)` 的 Shift+右交界斷言；其他新增直接事件與普通文字對照通過。先前只 Ctrl+C＋事件測試的相關 67 項通過，不足以表示新交界測試完成。
- 本輪單次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**；scoped diff check 通過。分析通過不是 keyboard 交界回歸通過；沒有修改 tokenizer/hash／OAuth／平台或真人操作。
- 本輪修改：`presentation/widgets/chat/twitch_selectable_emote.dart`（相對 lib/features/twitch）、`docs/twitch_selectable_emote_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- 續接優先：修保留交界案例，不能用只直接 dispatch 的通過代替真鍵盤；再补跨多行／多圖／RTL drag、Android 長按／handles、圖片後排版，回原完整 MOD／聊天／播放／設定／多視窗盤點。完整目標仍未完成。

官方來源：[granular event](https://api.flutter.dev/flutter/rendering/GranularlyExtendSelectionEvent-class.html)、[directional event](https://api.flutter.dev/flutter/rendering/DirectionallyExtendSelectionEvent-class.html)、[paragraph event](https://api.flutter.dev/flutter/rendering/SelectParagraphSelectionEvent-class.html)、[Flutter 3.38.4 paragraph source](https://github.com/flutter/flutter/blob/3.38.4/packages/flutter/lib/src/rendering/paragraph.dart)。

### 2026-10-03：私訊貼圖逐字交界映射與反向收回

- 本輪分類：有進展。純 Flutter WidgetSpan（內嵌普通 Text Kappa、沒有本機自訂 selectable）雙擊後 Shift+右，仍得到 `Kappa after`，普通 Text 對照是 `Kappa `。新增 SDK diagnostic 固定記錄此差異；產品 regression 仍要求 `Kappa `，沒有把錯誤行為當成功條件。
- 新增私訊局部 `TwitchWhisperSelection` delegate，character keyboard 移動由完整原文的 CharacterBoundary 計算，再映射到 RenderParagraph 的文字／圖片佔位 caret，透過標準 SelectionEdgeUpdateEvent 更新兩端。貼圖代碼按完整 token 移動；pointer、原生 copy、其他事件仍走 Flutter。不是改 SDK、InlineSpan 文字長度或貼圖發送 payload。
- 補反向收回時發現 image 左邊界命中仍按完整 token 選取；改依 image TextBox 的實際 direction／矩形，在 token 邊界外 0.01 logical pixel 定位。geometry 保留 collapsed range 及反向 start/end，不再讓圖片 getSelection 一律回正向全長或在 collapsed 回 null。修正對應 range 測試以驗證反向 5→0；完整內容仍為 Kappa。
- 實際 Windows key regression 現在通過：雙擊圖片／Ctrl+C=Kappa；Shift+右／Ctrl+C=`Kappa `；Shift+左回 Kappa；再 Shift+左收成空選取（不複製或空內容）。原 Shift+右失敗斷言保留，沒有 skip；標準全選原文與 dispose 保持通過。
- 十三份完整 regression harness **164 項通過，exit code 0**（inbox 62、selection 7、其餘 95）。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**；scoped diff check 通過。上段 162／1 失敗屬歷史，本輪已修該案例。
- 本輪檔案：新增 `presentation/widgets/chat/twitch_whisper_selection.dart`；修改 `presentation/widgets/chat/twitch_selectable_emote.dart`、`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_selectable_emote_test.dart`、`docs/twitch_whisper_inbox_test.dart`、本 roadmap 與 parity。
- 續接：新增 delegate 的 emoji／組合字、多貼圖、多行／換行、RTL 索引與動態 catalog 改變需直接測試；Android 真長按／handles、word／line／paragraph 整則交界及圖片後排版仍待完成。局部圖片 primitive 的事件通過不等於整則跨行都驗收。未啟動 App／真人收發／推送；完整 MOD／其他聊天／播放／設定／多視窗目標保持未完成。

官方來源：[CharacterBoundary](https://api.flutter.dev/flutter/services/CharacterBoundary-class.html)、[RenderParagraph caret 定位](https://api.flutter.dev/flutter/rendering/RenderParagraph/getOffsetForCaret.html)、[StaticSelectionContainerDelegate](https://api.flutter.dev/flutter/widgets/StaticSelectionContainerDelegate-class.html)。

### 2026-10-03：私訊選取內容更新、Unicode 與 Android 長按

- 本輪分類：有進展。新增獨立 selection harness 四項直接 widget 測試：Android TargetPlatformVariant 長按圖片以標準 copy 複製 Kappa 並清除選取；Windows 逐字延伸／反向收回跨家庭 ZWJ emoji、組合字 é 與第二張貼圖；內容更新後採新原文索引；不變內容重建保留選取與方向鍵操作。
- 新更新測試先重現失敗：由 `a Kappa old` 更新為較長前綴及 emoji 後，Shift+右複製得到 `prefix ` 而非 `Kappa `。原因是 delegate 在 initState 捕捉舊 parts。改由元件內部依原文及 token 結構識別 selection subtree，內容改變時一起重建 registrar／children；不變內容維持原狀態，不依賴呼叫端額外 key。保留正確斷言，修後通過。
- 十四份完整 regression harness **168 項通過，exit code 0**（新增 selection 4、inbox 62、selectable emote 7、其餘 95）。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。新測試 Clipboard handler 的大括號格式已修。
- 本輪修改：`presentation/widgets/chat/twitch_whisper_selection.dart`（相對 lib/features/twitch）、新增 `docs/twitch_whisper_selection_test.dart`、本 roadmap 與 parity。新 harness 用固定 28px ColoredBox 隔離選取幾何，並非下載成功的 CDN 或動畫驗證；既有 inbox 的 bitmap fixture 測試仍在完整回歸中。
- 續接：多行／換行、RTL、catalog 從原文轉圖片的結構更新與 Android handle 拖曳尚需直接測試；word／line／paragraph 整則交界也未驗收。之後回完整 MOD 紀錄、AutoMod 原因片段、釘選事件與其餘原盤點。未啟動 App、真人收發、實機操作或推送／發布，完整對齊目標仍未完成。

### 2026-10-03：私訊換行交界與動態 catalog 的選取註冊

- 本輪分類：有進展。新增三項直接 widget regression：明確換行跨第二張圖片的逐字雙向選取；128px 寬度實際自動換行、不在 clipboard 插入原文沒有的換行；同一原文 catalog empty→Kappa image→empty，在原生全選狀態變更後仍可全選及滑鼠雙擊／Shift+右複製。斷言實際兩張 image 的 y 位置不同，並檢查 clipboard 與 renderer selected content。
- 明確換行反向收回先失敗：預期 Kappa，實際仍含下一行 x 及空白。image token end 的定位在矩形外，使後續跨行文字片段收到落在其聯集矩形右側的座標，經 drag-offset clamp 跳到下一行末尾。改 token end 使用圖片內 0.01px、token start 使用邏輯起點外 0.01px；左右位置依 TextBox.direction，保留 LTR 與既有反向收回測試。RTL 尚無直接證據，不宣稱 RTL 完成。
- catalog 切換測試亦找出真實問題：上輪依 key 替換整個 nested SelectionContainer，在已有全選時新圖片沒有收到父層 selection event；不只 keyboard focus，renderer selected content 也為 null。替換上輪實作為穩定 Stateful 選取容器，在 didUpdateWidget 核對每段 text／emote ID，改變時清除本地舊選取並更新 parts／raw，不變時保留選取；Text.rich 原地更新，移除私訊呼叫端的內容 key。三項新測試與上輪更新／不變重建測試均通過。全無圖片時整則仍走既有 SelectableText，不把元件 harness 當成所有面板資料載入時序已驗收。
- 十四份完整 regression harness **171 項通過，exit code 0**（selection 7、inbox 62、selectable emote 7、其餘 95）。本輪唯一一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。
- 本輪修改：`presentation/widgets/chat/twitch_whisper_selection.dart`、`presentation/sheets/twitch_whisper_sheet.dart`（相對 lib/features/twitch）、`docs/twitch_whisper_selection_test.dart`、本 roadmap 與 parity。測試仍是固定幾何替身，不是實際 CDN／動畫、Android 或 Windows 實機操作；不改 SDK、授權／傳送協議或平台檔案。
- 續接：Android handle 拖曳、RTL、多行 word／line／paragraph 與面板動態 catalog 時序仍待驗證；接回完整 MOD 紀錄、AutoMod 原因片段及釘選事件，再按原完整功能清單續作。未啟動 App／真人收發／推送／發布，完整目標未完成。

定位核對來源：[Flutter paragraph 的 selection edge 與片段處理](https://github.com/flutter/flutter/blob/3.38.4/packages/flutter/lib/src/rendering/paragraph.dart)、[SelectionUtils 的 drag offset 處理](https://github.com/flutter/flutter/blob/3.38.4/packages/flutter/lib/src/rendering/selection.dart)、[SelectionContainer 註冊生命週期](https://github.com/flutter/flutter/blob/3.38.4/packages/flutter/lib/src/widgets/selection_container.dart)。

### 2026-10-03：AutoMod 命中原文與 Unicode 位置歧義

- 本輪分類：有進展，接回完整 MOD 清單。待審列從普通 Text 改用獨立 `TwitchAutomodMessageText`，官方位置可對應時在原文以主題色背景及底線標示；原文保持完整、可選取／標準 copy，原數字位置提示與允許／拒絕時序保持。沒有改動管理 API、授權、真人聊天室或訊息 payload。
- 核對官方 EventSub 文件：起點／結尾都 inclusive，但未定義非 ASCII 索引單位。官方 issues #1206 有 AutoMod 非 ASCII 前綴位置按不同長度回傳的重現，仍開啟；不是已被 Twitch 證實修復的規格。模型以 UTF-16、Unicode scalar、UTF-8 三種合理解讀作候選，不把任一單位硬編成官方保證。超出範圍／落在 surrogate 或 UTF-8 字元中間的解讀整組拒絕，不 clamp 或填字湊索引。
- 同一命中結果合併成單一候選後才標示；重疊／相鄰／重複位置合併、排序，顯示擴展到完整 grapheme，不切開 emoji、ZWJ 或組合字。多個有效解讀不同時主原文不亂高亮，列各單位候選及「命中位置有不同解讀，請核對原文」；全無有效對應時維持原文並提示。單一有效解讀是本機位置推定，不保證遠端回傳的索引一定正確，也不代表上述三種單位涵蓋所有未知行為。
- 新 highlight harness 九項：ASCII inclusive／合併、issue 範例 UTF-8 位置、有效歧義、非 BMP 不切 surrogate、組合字及 ZWJ 完整、無效組拒絕／空值、實際 SelectableText 原生全選 copy 含換行、歧義候選及無效提示。新增一項實際 AutoMod strip 收件測試，模擬公開封鎖詞與歧義 EventSub，在 320px／鍵盤／1.5 倍字體捲動到列檢查 highlight/candidates，確認不送管理動作與關閉 receiver。初版因 lazy list 未建立不可見列而失敗，改用真捲動到列，沒有放寬 highlight 斷言。
- 十五份完整 regression harness **181 項通過，exit code 0**（新增 highlight 9、queue 新增 1；其他 171 保持）。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。
- 本輪檔案：新增 `models/chat/twitch_automod_highlight.dart`、`presentation/widgets/chat/twitch_automod_message_text.dart`，修改 `presentation/widgets/chat/twitch_automod_queue_strip.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch）；新增 `docs/twitch_automod_highlight_test.dart`，修改 `docs/twitch_automod_queue_test.dart`、本 roadmap/parity。
- 續接：AutoMod 官方 emote／cheermote fragments 尚未圖片呈現；原文位置與圖片跨度需維持 copy 不漏字，不能把本輪高亮當作完整 fragments 已完成。完整 MOD EventSub 操作紀錄、釘選事件、其餘聊天室／播放／設定／多視窗清單及私訊 Android handles／RTL 待續。真實權限、不同 AutoMod 模式的 Unicode 邊界及 Windows／Android 實機列最終測試；本輪未啟動 App、真人收件／管理、推送或發布。

來源：[Twitch AutoMod Hold V2](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#automod-message-hold-event-v2)、[官方問題追蹤 #1206](https://github.com/twitchdev/issues/issues/1206)。

### 2026-10-03：AutoMod 官方 emote fragments 與原文選取

- 本輪分類：有進展。Held model 保留官方有序片段、emote ID／set ID 及 cheermote prefix／bits／tier；所有片段串接必須等於 message.text，否則整組退回原文。未知 type／無效 metadata 維持該片段文字；不透過名稱推定圖像、不使用 viewer 的私訊 catalog、不接 7TV。
- 官方 emote 僅接受 1～128 字的 ASCII ID 安全字元，固定官方 CDN default/dark/2.0 URL，不使用 event 任意 host；圖片失敗保留代碼。命中范围跨片段时一般文字按精確交集標示，image token 任一部分命中則以圖片背景／邊框標示整個 token。歧義位置維持上輪候選提示，不任意標 image。
- 圖像訊息重用已驗證的選取 primitive／raw-offset delegate（現有 TwitchWhisperSelection／TwitchWhisperTextPart，未改名或重構），官方 fragment 明確轉成同一原文→image slot 結構；無圖片時仍 SelectableText.rich。整則／局部 copy 保留代碼，不以 placeholder 或 metadata 提示替代原文。Bits 片段本輪保留原文字與官方 bits 提示，**尚未載入 Helix Cheermotes 的圖片 catalog，不能稱 Bits 動畫／圖片完成**。
- 新四項 harness：完整片段順序與 ID／set／Bits 保存、無效 ID／metadata 不造圖或數額、缺失／未知／不一致片段回退、已載入 bitmap 的實際 image 非 null／命中邊框／Bits 提示／全選原文 copy／mouse 雙擊及 Ctrl+C=Kappa／Shift+右=Kappa+空白／dispose。圖片是 cache 預載固定 bitmap，並非真 CDN 下載或動畫驗收；沒有真人收件／管理。
- 十六份完整 regression harness **185 項通過，exit code 0**。初版 constructor named parameter 多一個逗號造成編譯錯誤，已修正。唯一一次 `flutter analyze --no-pub lib/features/twitch docs`：**0 errors、3 warnings、2 infos，exit code 1**；不在本輪反覆修／分析。下一輪先處理 `models/chat/twitch_automod_queue.dart:66/67/68` unnecessary_cast，以及 `presentation/widgets/chat/twitch_automod_message_text.dart:74/84` curly_braces_in_flow_control_structures。
- 本輪修改：`models/chat/twitch_automod_queue.dart`、`presentation/widgets/chat/twitch_automod_message_text.dart`（相對 lib/features/twitch），新增 `docs/twitch_automod_fragments_test.dart`，本 roadmap/parity。
- 續接：先清五項分析提示，再補官方 Cheermotes 圖片來源、image fallback／多图多行／事件到 strip 的直接測試；不因原文選取 fixture 通過把完整 fragments 全勾完成。原完整 MOD 紀錄／釘選事件／其餘功能清單與私訊 handles／RTL 保持待續。Windows／Android 真裝置、CDN／動畫、實際管理 scope 仍列最終驗收，未啟動 App／推送／發布。

官方片段結構：[AutoMod Hold V2](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#automod-message-hold-event-v2)。

### 2026-10-03：AutoMod 圖片失敗與雙圖片跨行驗證

- 本輪分類：有進展。清除上輪三個多餘 casts 與兩個 if 大括號提示，不改解析／管理協議。
- 新增三個測試情境：Windows、Android TargetPlatformVariant 的兩張圖片失敗後顯示 Kappa／BibleThump，標準全選 copy 保留 `Kappa\nBibleThump`，無重複 fallback 選取註冊；Windows 兩張成功 bitmap 實際 RawImage.image 非 null、y 位置跨行且標準全選 copy 保留原文。均檢查 dispose 無例外，不稱實機或實际 CDN／動畫驗收。
- fallback fixture 初版在 Image widget 訂閱前立即 Future.error，造成未處理錯誤與 cache eviction；改用受控 Completer，在畫面建立／listener 就緒後才觸發下載失敗，直接驗證產品 errorBuilder。没有忽略 framework 錯誤、刪除 no-exception 斷言或改成成功圖替代失敗情境。
- 十六份完整 regression harness **188 項通過，exit code 0**（fragments 7 項）；本輪唯一一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。上輪 3 warnings／2 infos 已在本輪清除。
- 本輪修改：`models/chat/twitch_automod_queue.dart`、`presentation/widgets/chat/twitch_automod_message_text.dart`（相對 lib/features/twitch），`docs/twitch_automod_fragments_test.dart`、本 roadmap/parity。
- Bits 接續核對：已讀現有 moderation 的 automodSession 與所選局部聊天／emote API 範圍，未找到現成 Cheermotes 接入。官方 Get Cheermotes 是 `GET /helix/bits/cheermotes`，帶 broadcaster_id 可含該頻道清單，圖片需讀 API 的 images，而非依 prefix 拼網址。**本輪尚未接 API/catalog/UI**。下一輪以當前 MOD 同帳號驗證／Client-ID 讀官方清單、核對 prefix/tier 並在 loading／failure 保留原文字，切頻道／身分時拒絕晚回應，再加 fake HTTP 與 widget 測試。
- 原完整 MOD 紀錄、釘選事件、其他聊天室／播放／設定／多視窗盤點及私訊 handles／RTL 仍待完成。未操作真人聊天室／啟動 App／推送／發布；範圍未突破 AGENTS 限制。

Bits 圖片資料來源：[Get Cheermotes](https://dev.twitch.tv/docs/api/reference/#get-cheermotes)。

### 2026-10-03：AutoMod 官方 Cheermotes API、圖片与時序隔離

- 本輪分類：有進展。`automodCheermotes` 使用既有唯讀 `_request` 同選定 moderator owner 驗證及 Client-ID，GET /bits/cheermotes 的 query 只有 broadcaster_id，沒有 moderator_id／額外 scope，不改 OAuth/token。200 且 data 是 List 才返回 catalog，回應後核對管理 context；錯 owner／身分失效拒絕，unexpected 2xx／資料格式不完整不冒充成功空清單。
- catalog 用官方 prefix 大小寫無關 + event exact tier 配對，bits 需至少達到該 tier 的 min_bits；未知／不符／重複 prefix-tier 不猜。只讀 API images 的 dark/light、animated/static，優先 2 倍並允許其他已提供尺度，不拼 prefix 網址。HTTPS、無 credentials／非標準 port 且已知 Twitch CDN host 才顯示；新未知 CDN 會保留文字，需核對後擴充，而非宣稱所有 CDN 都支持。
- AutoMod 收到首筆 Bits fragment 才載入一份當前頻道清單。loading／失敗保留原文及數額，失败入口手動 retry；每個 generation 的 attempt/loading guards 避免新來訊連續重取。切換 broadcaster／moderator 或重啟 receiver 重設 catalog/generation，dispose／舊 generation／當前身分失效的回應不套用。未知prefix／tier或圖片錯誤保持原文字。
- Bits 圖像接現有原文 selectable token，未以 metadata 文案或圖片 placeholder 取代代碼；主題選擇與 caption 數額保持。新七項 catalog/API/widget：exact prefix/tier/min/theme、unsafe URL、重複／未知資料、驗證 owner/client/query/headers 且无需新scope、錯 owner及回應後失權、不完整／unexpected status、成功 bitmap 原生全選copy保留 Cheer100。queue 新兩項是真實 strip loading／failure／手動 retry 不管理，及換頻道 A→B 拒絕 A 晚回應、不覆寫 B loading；初版 fixture subscription condition 留 A 值使 B 正確拒收，已讓 fixture condition/event 一致，不繞過接收檢查。
- 十七份完整 regression harness **197 項通過，exit code 0**（新增 7、queue 新增 2）。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**0 errors、0 warnings、5 infos，exit code 1**；本輪不再修／分析。下一輪先處理 `docs/twitch_cheermote_catalog_test.dart:3` unnecessary_import，`models/emotes/twitch_cheermote_catalog.dart:22` 及 `presentation/widgets/chat/twitch_automod_queue_strip.dart:113/117/120` 的 if 大括號提示（lib 路徑相對 lib/features/twitch）。
- 本輪新增 `models/emotes/twitch_cheermote_catalog.dart`、`docs/twitch_cheermote_catalog_test.dart`；修改 `api/moderation/twitch_moderation_api_service.dart`、`presentation/widgets/chat/twitch_automod_message_text.dart`、`presentation/widgets/chat/twitch_automod_queue_strip.dart`、`presentation/localization/vioclass_localizations.dart`（相對 lib/features/twitch）、`docs/twitch_automod_queue_test.dart`、本 roadmap/parity。
- 續接：清五項 info；成功 API→strip→實際圖片、改 moderator／dispose晚回應、動畫失敗切 static／不同主題與 channel custom Bits 仍需直接驗證。本輪 bitmap 不是動畫或真 CDN驗收；不稱完整 Bits/fragments 已完成。完整 MOD 紀錄、釘選事件、原其他功能盤點及私訊 handles／RTL 仍待續，未真人收發／管理／啟動 App／推送／發布。

API 核對：[Get Cheermotes](https://dev.twitch.tv/docs/api/reference/#get-cheermotes)。

### 2026-10-03：AutoMod Bits 動畫失敗切靜態與保留選取

- 本輪分類：有進展。前一個狀態回報沒有實作進展；本輪重新核對目前檔案並接續保留的兩項失敗，不把狀態說明當作完成。
- catalog 提供當前 dark/light 主題的有序 animated→static URL 清單，去除重複網址；仍只讀官方 API 提供且既有安全檢查接受的 URL，不跨主題猜圖。動畫載入失敗才嘗試靜態圖，兩者都失敗顯示原代碼，命中邊框與 selectable token 保持。
- 原兩項 Windows 測試失敗原因是 pumpWidget 後立即 selectAll，nested selection 尚未完成註冊，從未成功選取。先 pumpAndSettle、明確斷言圖片完成前已存在標準 copy，再觸發受控圖片失敗。圖片切換後直接用同一選取複製完整 `before Cheer100 after`，沒有重新全選或放寬原文斷言。
- 新增五項案例：當前主題／URL 去重，以及 Windows／Android TargetPlatformVariant 的動畫失敗→已載入靜態 bitmap、動畫及靜態皆失敗→原文字。检查实际 RawImage.image、fallback 文字、命中邊框、原生 copy 及 dispose 無例外。受控 completer／bitmap 不是實際 CDN 或 GIF 動畫解碼，也不是裝置操作。
- 十七份完整 regression harness **202 項通過，exit code 0**。清除上輪五項 infos；本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**0 errors、0 warnings、1 info，exit code 1**。新提示是 `lib/features/twitch/models/emotes/twitch_cheermote_catalog.dart:75` 的 prefer_collection_literals，依規則留下一輪，不重跑分析。
- 本輪修改：`models/emotes/twitch_cheermote_catalog.dart`、`presentation/widgets/chat/twitch_automod_message_text.dart`、`presentation/widgets/chat/twitch_automod_queue_strip.dart`（相對 lib/features/twitch）、`docs/twitch_cheermote_catalog_test.dart`、本 roadmap/parity。沒有修改 OAuth/token、hash、發送 payload、播放器底層或禁用平台檔案；未啟動 App／真人收發或管理／推送／發布。
- 續接：先清一項 info；尚需 API→strip 成功圖片、moderator／dispose 晚回應直接驗證及真實 custom Bits／CDN／動畫驗收。接回完整 MOD EventSub 操作紀錄與釘選同步，再繼續原聊天／播放／設定／多視窗盤點；私訊 handles／RTL 與裝置測試仍保留，完整目標未完成。

### 2026-10-03：Bits 待審列整合與 MOD 紀錄訂閱基礎

- 本輪分類：有進展。上輪集合寫法提示改為集合 literal，不改去重順序與安全規則。
- 新四項 queue widget 測試：受控 catalog 回應在真正 EventSub hold→strip 路徑顯示已載入 RawImage bitmap；同頻道 moderator 10→11 拒絕舊 catalog、不清新 loading；dispose 後才成功或失敗均不更新、不例外。各測試檢查沒有管理操作且 socket 關閉。320px、1.5 倍字體及鍵盤 fixture 保留，真捲動到 lazy list 的 Bits 列。catalog API 使用服務替身，先前獨立 HTTP 契約測試保留；不是一條真实 HTTP→CDN 的裝置驗收。
- 接回完整 MOD 紀錄：核對官方 channel.moderate v2，增加 `moderationLogSession` 與 `subscribeModerationLog`。同選定 moderator owner 的 token 必須同時具備八組權限（六組 read/manage 可擇一，MOD／VIP 必須 read），不能用 AutoMod 權限替代。驗證後再訂閱，使用匹配 Client-ID、官方 v2、精確 broadcaster/moderator condition 與 websocket session，不讀改既有 OAuth/token 儲存或借其他帳號。
- 新四項 log API 測試：全部 read scopes 的完整 POST 契約、每組缺權限均拒絕與 manage alternatives、錯 owner／驗證及訂閱期間失權、無效 session 不送與只接受 202（401/403 terminal）。只用 fake adapter，未對官方建立真人訂閱。**本輪僅完成 API 基礎；尚無管理紀錄 receiver、事件解析、持久化、UI 或背景收件，不宣稱完整紀錄已可用。**
- 十八份完整 regression harness **210 項通過，exit code 0**；本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**No issues found，exit code 0**。scoped diff check 通過。未啟動 App／真人收發或管理／推送／發布。
- 本輪檔案：`models/emotes/twitch_cheermote_catalog.dart`、`api/moderation/twitch_moderation_api_service.dart`（相對 lib/features/twitch）、`docs/twitch_automod_queue_test.dart`、新增 `docs/twitch_moderation_log_api_test.dart`、本 roadmap/parity。
- 續接優先：MOD log receiver 的 welcome／keepalive／reconnect／revocation/context guards、官方 action payload 全分類與 Shared Chat 來源、事件去重、帳號與頻道隔離本機紀錄，再接頻道 MOD 入口。缺授權需明示，斷線不冒稱完整遠端歷史；持久化檔案權限與 storage 實作需按現有 scope 核對。釘選即時同步及其他原盤點依舊未完成，Bits custom/CDN/動畫與 Windows／Android 裝置驗收保留。

官方訂閱與授權來源：[Channel Moderate V2](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelmoderate-v2)、[Twitch scopes](https://dev.twitch.tv/docs/authentication/scopes/)。

### 2026-10-03：MOD 紀錄 EventSub 收件與連線生命週期

- 本輪分類：有進展。新增獨立 `TwitchModerationLogEventSubService`，接上輪同 MOD owner 的 session／subscribe API；預先驗證再連 socket。只接 channel.moderate v2，subscription condition 的 owner／頻道與 event broadcaster 都需一致，不能把 event actor 限為本人而漏掉其他 MOD。官方 metadata message_id 與有效 timestamp 必須存在，2000 筆有界 ID 去重跨重連交接重複；尚非永久歷史去重。
- 10 秒 welcome／訂閱 deadline、官方 keepalive timeout 加兩秒容忍、1–32 秒 backoff。停止／重啟 generation 拒絕晚回應，權限失效及匹配的 revocation terminal、不持續重試缺授權；狀態明示斷線事件不會自動補回。只收官方資料，不發聊天室／IRC 流量。
- 官方 handoff 保留原 socket 至新 welcome，redirect 不重新訂閱；交接失败保留原活連線、原連線先丟失仍可等新 welcome。只接受官方 wss host、無 userInfo／fragment 且明寫 port 時需 443，網址原樣使用。新測試先抓出無明寫 port 的 wss 被舊 `uri.port != 443` 條件誤拒，改 hasPort guard；保留合法交接與惡意host／credentials／port案例。
- 新九項 service 測試：context/version/broadcaster與其他MOD actor、malformed／duplicates、welcome及pending subscription逾時、heartbeat重置與斷線重新訂閱、正常handoff overlap去重、handoff失敗／原連線先掉、backoff、untrusted redirect／terminal revocation、失權及stop後晚訂閱完成、缺scope不開socket。初版三測試在 widget invariant 前未停止 service 而有pending timers，改在驗證後主動stop；未略過timer檢查。全為fake socket/API及虛擬時鐘，非真人收件／裝置網路驗收。
- 十九份完整 regression harness **219 項通過，exit code 0**。本輪僅一次 `flutter analyze --no-pub lib/features/twitch docs`：**0 errors、0 warnings、7 infos，exit code 1**，依規則留下一輪：`docs/twitch_moderation_log_eventsub_test.dart:26` 的大括號；`services/chat/twitch_moderation_log_eventsub_service.dart:18` 的集合literal及 :101/:118/:134/:147/:191 大括號（lib路徑相對lib/features/twitch）。
- 本輪新增 `services/chat/twitch_moderation_log_eventsub_service.dart`、`docs/twitch_moderation_log_eventsub_test.dart`，修改本 roadmap/parity。未改 OAuth/token、GQL hash、IRC傳送、點數payload、播放器底層或禁用平台檔案；未啟動App／真人管理或收发／推送／發布。
- 續接：先清七項infos，再接官方 action 全分類、Shared Chat 來源、帳號／頻道隔離保存及MOD紀錄介面。**收件服務尚未掛入觀看頁或面板生命週期，尚無 action 解析、歷史保存或 UI；不稱使用者已可看即時紀錄**。後續仍需背景收件、斷線缺口顯示、跨帳號去重保存及裝置驗收；釘選同步及原全部功能清單保持未完成。

連線來源：[官方 WebSocket 處理流程](https://dev.twitch.tv/docs/eventsub/handling-websocket-events/)。

### 2026-10-03：使用者實測 Drops 登入失敗

- 使用者要求保留既有登入容器：Windows 獨立 desktop WebView 視窗；Android App 內 Flutter InAppWebView。核對 device login page、linked login page、device API、Drops device API 與 Drops auth service，修改前這些檔案對 Git 均無差異；執行輸出有 Windows 主 OAuth WebView 建立及載入紀錄，不能把 Drops failure 歸因於新私訊／MOD 改成外部瀏覽器。
- 以現有 public Android Client-ID、不帶使用者 token 的相同 form device 授權請求直接重現：官方 `https://id.twitch.tv/oauth2/device` 回覆 HTTP 400，message `invalid client`。未取得 device/user code；不能因此斷言永久停用或推測有效替代 ID，也未發生真人登入／管理／私訊操作。
- 只修 device login page 的錯誤回饋：辨識 HTTP 400 invalid client、其他 HTTP status 與一般啟動失敗，不顯示完整 exception／token／body；失敗後不再顯示仍在產生代碼。Windows／Android 平台分流、client 常數、授權流程及 token 儲存均保持。**提示修正不是登入修復；實際完成 Drops 登入仍需要可用且符合原需求的 Client-ID／官方授權路徑。**
- 本輪一次 analyze：0 errors／0 warnings／既有7 infos，exit code 1；新增登入頁修改未產生分析提示，diff check 通過。未新增授權成功宣稱，未更换未知 client 或借用主 OAuth token 冒充 Drops Android token。

### 2026-10-03：清除本機登入資料與分離 Drops WebView

- 使用者要求重回未登入狀態測試。停止 Windows App 後，將 `shared_preferences.json`（包含 App 設定、私訊 archive／草稿、各 Twitch token key）移到同層 `.reset-backup`；將舊主 OAuth WebView profile 與 Drops 共用的 desktop profile 移到同層 `.reset-backup`。原路徑現在不存在，App 下次會建立空資料；未刪除 repo、編譯資料或其他 App。
- 核對後確認 Drops page 原先和主 OAuth 使用相同 desktop WebView profile。改為 Drops 專用 `new_twitch_app_drops_desktop_webview_v1`，主 OAuth profile 不再共用；Android 仍使用內嵌 Flutter WebView。這只分隔 Cookie 容器，不改 OAuth/token 儲存格式或 Device Flow payload。
- Drops 端點仍以現有 Client-ID 回覆 HTTP 400 `invalid client`；官方文件要求 Device Flow 使用已註冊 Client-ID，清 Cookie 不會修復被 Twitch 拒絕的 Client-ID。官方與第三方近期資料也顯示部分內建／平台 Client-ID 的 device endpoint 行為變動；未擅自替換未知 ID。
- 本輪唯一分析在分離 profile 修改前後的結果：0 errors、1 warning（舊 profile helper 未使用，隨後已移除）及既有 7 infos；未在本輪重跑分析。diff check 通過。需要下一輪重新啟動，確認 Drops 使用新 profile 且錯誤能明確顯示 `invalid client`。

### 2026-10-03：恢復目標，補齊私訊登入權限

- 本輪分類：有進展。使用者恢復完整目標；權威 goal 狀態為 active，整體未完成。使用者截圖確認收件授權失敗與缺遠端對話；前一輪已查明主 OAuth 的預設 scopes 沒有私訊權限。
- 主 OAuth 登入頁新增 `user:read:whispers`、`user:manage:whispers`。整合登入從官方 validate 回應核對權限；舊登入仍有效但缺少私訊收發時明示補授權並重新進入原主 OAuth/Web GQL 頁，不鏡像主 token 到 Web/Drops。只有兩項私訊權限都確認才回報整合登入完成；未完成授權的既有 session 仍可登出。沒有改 token key、序列化、持久化、刷新、IRC 發送協議或 GQL hash。
- 新三項 widget 測試覆蓋：舊 token 缺 scope 重新打開正確登入頁並保留 logout、只有 read 權限不冒稱完整收發、read/manage 都已驗證才完成。native WebView 尚需真人同意，測試只驗證 route 與參數，採 bounded pump 而非等待外部視窗完成。連同原私訊 API/EventSub 回歸共 **24 項通過**，無真人發送或官方訂閱。
- 本輪一次 analyze：**0 errors、1 warning、10 infos，exit code 1**。新增 warning 為 `lib/features/twitch/presentation/pages/twitch_linked_login_page.dart:81` 的多餘 `!`，依規則留下一輪移除；10 infos 為已有的點數測試相對 import 與 MOD 大括號/集合寫法。沒有重跑 analyze。
- 遠端歷史核對：StreamNook 的 `whisper_history_service.rs` 以 `Whispers_Thread_WhisperThread` 私有 GQL persisted query 分頁讀取已知 peer，而非官方 Helix 的歷史 API。它不能僅憑此宣稱發現全部對話；尚需核對 inbox discovery/import。AGENTS 的 hash 限制未撤銷，這輪沒有搬入或新增該 hash。預計必要檔案為 `lib/features/twitch/api/chat/twitch_whisper_history_api_service.dart`（獨立唯讀查詢）、`models/chat/twitch_whisper_remote_history.dart`（相對 Twitch 目錄的分頁模型）、既有 inbox controller/sheet（合併與入口），以及 docs 測試。遠端功能不以假資料或本機列表替代，限制確認後才實作。
- 更正先前 Drops profile 紀錄的最終狀態：分離 profile 曾實作但已依使用者要求還原 GitHub，現在 browser redirect 登入沿用主 OAuth 的 v30 desktop profile；整合入口已接 `TwitchDropsWebViewLoginPage`，預設 redirect 為 `https://www.twitch.tv/`，Windows 獨立視窗、Android 內嵌。5 項 browser URL 測試與 Windows 建置/啟動已通過，但未在這輪確認真人 Drops 授權成功；SharedPreferences/WebView reset backup 仍是可恢復備份，沒有恢復或再清資料。
- 本輪修改：兩個登入頁、新增 `docs/twitch_linked_whisper_authorization_test.dart`、roadmap/parity。下一步補分析 warning，核對遠端 inbox discovery 與 history hash 的必要限制，再續接完整私訊/MOD/原盤點；Android 與真人收發驗收保持未完成。

授權來源：[Whisper Received](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#userwhispermessage)、[Send Whisper](https://dev.twitch.tv/docs/api/reference/#send-whisper)。遠端來源：[StreamNook whisper history](https://github.com/StreamNook/StreamNook/blob/main/src-tauri/src/services/whisper_history_service.rs)。

### 2026-10-03：私訊面板補授權入口

- 目標保持 active，整體未完成。私訊面板新增「重新授權私訊」，小高度面板亦有入口，沿用整合登入流程；先保存草稿、阻止重複點擊，返回後重新驗證 session 與收件狀態。失敗提示不輸出 exception，保留本機資料；切換帳號由既有 controller 隔離舊對話。沒有改 token 儲存、GQL hash、IRC 或真人發送。
- 新四項測試覆蓋草稿持久化及防重入、切換帳號、授權失敗重試、緊湊面板及關閉後晚回應；連同私訊 inbox、授權、API/EventSub 回歸 **90 項通過**。非真人授權／收發驗收。
- 移除上輪 linked login 的多餘 non-null assertion，點數測試加入相對 import 的檔案級豁免。一次 analyze：**0 errors、0 warnings、7 個既有 MOD infos，exit code 1**；未反覆執行分析。
- 續接：遠端對話發現／歷史仍未實作，新增私訊 persisted hash 的限制確認仍待使用者回覆；不因補授權入口而宣稱遠端列表完成。可繼續其他不涉及限制的 MOD 功能。真人 Windows／Android 授權、既有 Twitch 對話同步及收發仍在最後驗收清單。

### 2026-10-03：MOD 官方事件分類資料層

- 前輪為實際進展；本輪同樣有進展，完整目標保持 active。新增 `models/chat/twitch_moderation_log_entry.dart`，核對官方 channel.moderate v2 的 34 種 action，分類使用者／聊天室模式／身分／揪團／AutoMod。未知 action 明示未知，缺 detail 不製造對象；白名單欄位與不可變列表保留原因、警告規則、解封申請、詞彙、秒數、刪訊與到期資料。
- 廣播頻道與 Shared Chat 來源分開保存；共享動作缺來源不生成 typed entry。performing actor 不假設是 subscription owner，拒絕缺 actor／錯頻道；未知 payload 不儲存任意欄位。收件服務新增可選 `onEntry`，在既有官方 context filter 與 ID 去重之後解析，原 raw callback 保留。服務尚未掛入觀看頁，亦未新增永久保存或面板。
- 新九項模型測試及一項收件整合測試，加上原九項 EventSub 測試，共 **19 項通過**（fake socket，無真人管理操作）。清除先前大括號提示；一次 analyze **0 errors、0 warnings、1 info，exit code 1**，剩 `twitch_moderation_log_eventsub_service.dart:20` 集合 literal 提示，下一輪處理，未重跑。
- 續接：補帳號／頻道隔離 archive、bounded 去重及斷線狀態，然後接 controller／面板生命週期；不宣稱管理紀錄功能完成。遠端私訊 hash 限制仍待確認，未改 hash／token 儲存／IRC／點數／播放器或平台檔案。

資料格式來源：[Twitch Channel Moderate V2](https://dev.twitch.tv/docs/eventsub/eventsub-reference/#channel-moderate-event-v2)。

### 2026-10-03：MOD 本機 archive 資料層

- 本輪為有進展，整體目標仍 active。新增 `services/chat/twitch_moderation_log_archive_store.dart`，沿用注入 read/write 的可測試方式，不依賴或更動 OAuth 儲存。模型新增正規化 toJson/fromJson；保留 actor、來源頻道、未知 action 與缺 detail 狀態。資料按 owner／訂閱頻道分鍵，驗證 envelope owner、channel、version 與每筆 broadcaster。
- 同一 store 的操作串列化讀／合併／寫，避免並行收件覆蓋；保留範圍內 ID 第一筆優先，跨重啟去重。預設最多500筆及2 MiB UTF-8，按事件時間及ID排序淘汰最舊；單筆超量拒絕，損壞／錯帳號／错頻道 archive 不覆寫。去重有界，不宣稱永久去重或可補回斷線事件。需 runtime 使用單一 shared store，尚未注入實際持久化 adapter。
- 新8項測試覆蓋重啟 roundtrip、owner/channel隔離、20筆並行append、重啟重複、時間序保留、unknown／缺detail、損壞資料、UTF-8容量及寫入失敗後queue恢復。連同模型/EventSub共 **27項通過**。不是真人／平台保存驗收。
- 移除上一輪集合literal提示。一次 analyze **0 errors、0 warnings、2 infos，exit code 1**：archive test:22 null-aware element及模型:118大括號，依規則留下一輪，不重跑分析。
- 續接：補分析提示，接收件／archive controller、驗證登入owner與頻道生命週期、storage failure與斷線缺口狀態，再接MOD面板。尚未掛入觀看頁，沒有使用者可見管理紀錄功能完成宣稱；私訊遠端hash限制仍待確認，完整功能清單未完成。

### 2026-10-03：MOD 收件與 archive 控制器

- 前輪寫入 controller 後被使用者進度詢問中斷，未驗證；本輪重新讀取並修正 factory 名称衝突，補齊測試，分類為有進展。新增 `services/chat/twitch_moderation_log_controller.dart`，start先驗證官方session owner與管理身分，再讀當帳號／頻道archive，成功才建立獨立收件receiver。stop/start/dispose generation隔離晚回應，開始切換立即清空舊畫面。
- 接 typed事件至archive，保留範圍內ID去重、記憶體有界排序。已接受事件的排隊寫入仍落到原帳號／頻道，完成不更新新畫面。保存失敗保留當前畫面未保存資料並提供retrySaving；未保存達上限時停止收件並明示離線缺口，無自動重送聊天室操作。狀態轉交收件service，面板是否開啟不影響controller本身。
- 新6項 controller測試加原archive／model／EventSub共 **33項通過**；覆蓋重連去重、切換隔離、晚驗證、錯owner／損壞archive不開receiver、失敗重試、晚寫入原partition。上輪兩項infos已修正；本輪一次analyze **No issues found，exit code 0**。
- 尚未接runtime adapter／觀看頁生命週期／面板。續接需補權限失效、保存壓力及停用時失敗資料處理測試：目前stop清除當前未保存buffer，排隊已接受寫入會完成但若失敗無跨session重試；不能宣稱未保存資料跨切換保證不丟失。需處理這個缺口後再掛入UI，並集中真人裝置驗收。遠端私訊hash限制未解除；完整目標active，沒有真人收發／管理操作。

### 2026-10-03：MOD 跨切換待存資料修復

- 上輪有進展，本輪亦有進展。controller 待存資料改為 owner／頻道／事件ID分區，stop/start不再清除；重新驗證回到原partition後合併待存資料並顯示重試提示。retrySaving只存當前驗證partition，新帳號不會看見或重試舊帳號資料。跨generation寫入成功仍清除原pending，失敗保留原partition，不更新新UI。
- pending上限改為controller全部partition共用archive.maxEntries（預設500），達上限停止新收件並明示缺口，不以丟棄舊待存資料騰空。新增3項測試：切換失敗資料保留及原帳號重試、晚寫入失敗、跨partition壓力上限。連同原回歸 **36項通過**；一次analyze無問題。
- 此保證限同一controller生命週期；dispose／程序結束後未成功持久化的資料仍不能恢復，不宣稱磁碟失效時跨App重啟零遺失。尚未掛入watch／runtime／面板，下一步需使用長生命週期controller、接持久化adapter及面板，再做裝置驗收。私訊遠端hash仍待限制確認，完整目標保持active。

### 2026-10-03：新增私訊 GQL 已獲授權

- 使用者明確允許新增私訊 API／GQL hash，要求清楚清單與儲存設計；既有hash與token儲存維持。新增history API、remote page模型及archive分頁合併，詳見 `docs/twitch-whisper-api-storage.md`（operation/hash/headers/授權/欄位/容量/限制完整列出）。目前唯讀已知peer歷史，尚未接面板，不宣稱遠端列表完成。
- 新8項及原私訊回歸95項通過；一次analyze 0 errors、1 warning、4 infos，留下一輪。頁面和checkpoint同archive一次保存，原草稿／未讀／live flag保留；錯帳號、過期cursor、ID衝突、容量或write失敗不覆寫原資料。
- 補記前輪中斷的MOD驗證：已接觀看頁chat listener context及dispose、MOD面板內紀錄入口、local SharedPreferences archive adapter與搜尋分類panel。3項新adapter/空面板尺寸測試及原回歸39項通過；當轮analyze為1個測試呼叫warning。沒有真人管理／收件、populated/小高度面板或完整watch生命週期驗收，不宣稱MOD全部完成。本輪不再擴充MOD。
- 續接優先私訊：先處理提示，再接history同步controller/入口與分頁；查證對話發現的必要查詢。新增hash限制已解除，不再以此阻擋後續私訊。完整目標active。

### 2026-10-03：私訊已知對話歷史同步入口

- 前輪為有進展，本輪亦有進展。Home注入Web-only歷史API；controller新增近期同步／更早一頁、owner/generation及archive內canApply防晚合併，reload保留新草稿及即時收件。archive新增refreshOnly，近期刷新不倒退更早cursor或清除完成標記。同步期間禁止刪對話/匯入，無真人發送。
- 面板新增history選單與error/status；已有對話可選近期刷新或更早一頁。新增4項controller测试加原回歸 **99項通過**；先修正通知參數導致的編譯失敗再完整重跑。一次analyze **0 errors、0 warnings、2 infos，exit code 1**（controller:267/579 大括號），未循環分析。
- 續接：清這兩項infos並新增history-enabled UI小尺寸／選單／閱讀位置測試，再查證未知peer的遠端對話列表取得。现有尺寸tests historyApi為null，不能當新選單尺寸驗收；真人Web API、Windows／Android讀取仍未完成。完整目標active，不宣稱完整私訊對齊。

### 2026-10-03：私訊歷史選單與舊訊息提示驗證

- 上輪為有進展，本輪亦有進展。新增history-enabled UI tests涵蓋桌面1000×760、直向390×844、緊湊390×260之近期/更早點擊。緊湊版profile移入同一歷史選單，不額外增加按鈕數。錯誤可見且保留draft，profile入口仍可用，不發送私訊。
- 修正歷史合併被計入新私訊提示：controller維護session內有界歷史IDs，builder計新收件時排除。新增非底部閱讀合併測試，驗證pixels不拉回底部、無新私訊badge；沒有驗證prepend後同一可見訊息exact anchor。新增5項與四份私訊完整回歸共 **104項通過**；修上輪兩項infos，單次analyze **No issues found，exit code 0**。
- 續接優先未知peer discovery：公開搜尋未找到可靠query/hash，不自行猜造。核對上游網站匯入／列表實際取得方式及只讀schema可行性；真人GQL成功、全部對話列表、其他字級/220px/鍵盤尺寸仍未完成。完整目標active，不切去擴充MOD。

### 2026-10-03：遠端對話列表 API／原子保存

- 上輪有進展，本輪亦有進展。以不帶token的只讀GQL驗證得知currentUser.whisperThreads完整欄位查詢被接受（currentUser:null且無errors）；introspection明示disabled。StreamNook未知對話wizard實際呼叫scrape_whispers，history refresh只刷新已知peer。
- 新增`api/chat/twitch_whisper_threads_api_service.dart`，使用獨立raw唯讀query `VioClassWhisperInbox`，不猜hash、既有hash不改。僅同owner Web session，嚴格owner/thread/participant/cursor/null/error解析。API及新增儲存完整清單見`docs/twitch-whisper-api-storage.md`。
- archive新增列表checkpoint與原子merge，保留draft/local unread/history checkpoint/live flag；remoteUnread另存。一般write保留列表checkpoint；空頁不清除本機對話。新7項與五份私訊回歸 **111項通過**；一次analyze **0 errors、0 warnings、6 infos，exit code 1**（threads API:77/95/102/107、archive:171/185大括號），不循環修分析。
- 續接：清infos、把列表API接controller及可見同步／更多對話入口，測owner切換晚回應與live profile競態；真人列表/完整UI仍未驗收。本輪不稱private chat完成、不拓展MOD，目標active。
