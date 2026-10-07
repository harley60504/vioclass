# MOD 批次操作 API 與狀態規則

## 2026-10-04 最新續接：單筆動作確認矩陣

新增 16 項假 API widget：固定禁言600秒、自訂90秒、永久封鎖及解除，各驗成功一次／取消零寫入／確認框開啟後升MOD或消失零寫入。檢查原頻道、對象、時間及原因；真 API 仍沿原同帳號授權／scope，本輪沒有更動API。

首次矩陣發現自訂禁言確認框沒有顯示實際會送出的原因，4項原斷言失敗；已將捕捉的 trim 原因加入自訂禁言確認，並讓共用確認內容可捲動。不放寬斷言，五份管理回歸81項全過、唯一analyze無問題。沒有持久化／token／hash變動或真人操作；成功代表fake API被呼叫一次，不是Twitch實際制裁結果。

下一單元回桌面快捷鍵實作盤點，避免反覆擴同一矩陣取代未完功能。單筆完整低高度／長理由與實機、不同來源及其他context入口即時角色資料、可配置快捷鍵与原私訊／全工作包門檻仍未完成。

## 2026-10-04 最新續接：手機選取與單筆目標確認

新增 3 項 user mode widget：51 則有效使用者來源範圍整次拒絕、保持原 1 則選取；320×640／844×290、字級1.3的觸控清單移動→列拖曳→邊緣選取→快捷鍵開表單，無 overflow、無刪除提交，父清單恢復原生捲動。這不是 Android 實機或拖曳跨 50 上限全證明。

回核對單筆管理時發現選單確認後只有自身權限 gate，目標角色可能改變。管理面板警告／固定及自訂禁言／封鎖／解除在送出前增加目前 runtime 可見使用者保守 gate；目標變受保護角色或消失就不寫入。刪除仍按原訊息 ID policy，不改成使用者 gate。不新增官方角色查询，過舊角色線索仍可能阻擋，官方最終權限依原 API。

新增 2 項確認框開啟後 target 升 MOD／移出清單測試，均零警告 API。五份管理回歸 65 項全過，本輪唯一 analyze 無問題。無新 endpoint／scope／hash／OAuth-token／持久化改動、無真人操作。完整 user 模式實機、其他單筆動作角色時序、可配置快捷鍵與原工作包仍未驗收。

## 2026-10-04 最新續接：使用者選取模式

父批次面板新增可切換的訊息／使用者模式，只有原入口提供 canManageTarget 才提供切換。預設訊息模式與刪除 canDelete 保護不變；使用者模式允許沒有官方 message ID 的本頻道 PRIVMSG，但必有合法 user ID，排除 localEcho／synthetic、自身／台主／MOD／共享來源；快照內同人任一有效受保護角色提示會阻擋該人全部來源。初始預選仍按原刪除規則，不用空 ID 比對任意列。

列表 checkbox、範圍及拖曳統一使用當前模式資格，仍限 50 則來源訊息、使用者預覽再去重。切換停止手勢／timer、清選取／anchor／drag／range／錯誤，不讓前模式選取殘留；使用者模式的 Ctrl+Enter／預覽按鈕只開動作表單，不進刪除或批准送出。開使用者表單後退出拖曳模式以恢復原生捲動，防同時重複開啟。

選取資格快取只針對不可變開啟快照、每個 user 一次，不作授權或官方角色快取；執行每筆仍沿原 runtime 當前資料／原 context gate。模式、資格快取及原選取均只存在面板記憶體，無新 API／scope／GQL／hash／token 或持久化欄位。

新增 3 項 fake widget 測試：缺 message ID 使用者可選且打開表單、切回刪除清空且該列仍不可刪；同人矛盾角色／self／owner／shared 排除；使用者範圍跳共享來源及 Ctrl+Enter 只開表單。五份相關回歸 60 項全過，本輪唯一 analyze 無問題。沒有真人操作，user 模式的完整拖曳／50 上限／手機鍵盤与 WindowsAndroid 實機仍需驗收；永久封鎖／解除與其他原工作包未完成。

## 2026-10-04 最新續接：使用者批次結果與生命週期驗證

本輪僅新增測試，不變更產品 UI、API、角色政策或保存邏輯。真實面板搭配 fake API 新增 8 項：成功禁言兩人固定 60 秒及 trim 原因、同人去重；等待第一筆時停止／關閉，分別接晚成功／未知失敗的四種時序；第一筆後原權限撤銷；Twitch 明確拒絕與未知回應。均驗第二人不送、已送不可取消、結果不冒稱成功、結束後不能返回設定或再次確認重送，dispose 晚回應無框架例外。

五份相關回歸 57 項全過；本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。沒有真人寫入、Windows／Android 實機或可靠官方角色查詢證據。已核對父面板仍在初選、範圍、拖曳及列表使用 canDelete，造成缺官方 message ID 的合法 user 不能多選；下一輪應補符合使用者動作的選取模式，保留刪除模式完整官方 ID 保護，而不是放寬刪除 API。原完整目標與私訊真人門檻維持未完成。

## 2026-10-04 最新續接：批次禁言／警告操作面板

- 已從批次選取面板接入使用者動作表單，提供警告／限時禁言、原因與秒數；預覽按使用者去重，列出排除數、固定名稱／示例／ID，再以原頻道及固定參數確認。取消不提交，結果逐人顯示，不提供原批直接重送。永久封鎖與解除仍未提供。
- 管理面板及 watch 訊息選單接線皆提供原頻道／帳號／runtime 的權限檢查；每筆寫入前另用原 runtime 目前可見訊息核對目標。沒有符合來源的訊息或任一受保護角色提示就拒絕。這是保守的本機角色證據，不是官方即時角色查詢；舊角色提示可能阻擋操作，最終權限仍由 Twitch 判定。
- 現在來源選取仍依刪除訊息 policy，需要官方 message ID；使用者核心本身只需 user ID，但缺官方 message ID 的使用者尚不能從此多選入口操作。不能將目前入口視為完整使用者多選功能。
- 沿原 warn 與 ban(duration) API／scope，沒有新增 endpoint、GQL／hash、OAuth／token 儲存或 archive schema。來源快照、草稿、預覽、結果、控制器與文字欄位都只在此面板記憶體；關閉停止尚未送出的項目，不復原已送出操作、不保存或啟動重送。
- 新增 3 項使用者面板／policy 測試及 1 項父面板入口測試；連批次核心、刪除面板、單筆管理與管理面板共 49 項全過。涵蓋原因／時間驗證、去重、取消确认零寫入、警告逐人一次、320×640 禁言預覽及確認前目標失效零寫入。使用假 API，沒有真人管理操作或 Windows／Android 實機驗收。
- 本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。下一輪補成功禁言、停止／關閉及未知回應的使用者面板生命週期，再處理缺官方 message ID 的選取入口；可配置快捷鍵、直接直播多選與其他原門檻仍未完成。

## 2026-10-04：批次刪除執行層（未接 App 介面）

- 沿用 TwitchModerationApiService.deleteMessages 與現有 DELETE /helix/moderation/chat；每筆必有固定非空官方 message_id，絕不以 null 回退為清除整個聊天室。不新增 API、scope、query／hash 或 token 儲存。
- prepareDelete 最多接受 50 則選取，超限整批拒絕而非默默截斷。既有 canDelete policy 排除其他來源頻道、台主訊息、非 PRIVMSG、synthetic/localEcho 與空官方 ID；同 ID 同內容／user 去重，同 ID 衝突拒絕建立新計畫。
- 預覽捕捉不可變 messageId、userId、displayName、text，來源 tags 後來改變不改預覽或送出目標。列表不可修改；舊計畫替換後不能執行，計畫限执行一次，開始前必須由 UI 做明確不可復原確認（尚未接線）。
- 每筆發送前核對 canModerate；正式 API 仍自行驗證帳號、scope 與既有 permission closure。UI 接線須固定原頻道／帳號／runtime 並於失效 dispose，不可用只代表新帳號仍是MOD的泛用 true。
- 逐筆 await，下一筆間隔 350ms。這只是保守節流，不是 Twitch 配額保證；API 拒絕（含限流）或未知例外即停，不自動重新送出。既有 API 本身的授權供應者行為不改。
- results 逐 ID 標 pending／submitting／submitted／rejected／unknown。submitted 是 API 接受，不是恢復能力或聊天室已觀察到刪除；unknown 請先核對官方狀態，不直接重送。剩餘 pending 是未送出，須結合 cancelled／problem 呈現原因，不能當失敗或成功。
- cancelRemaining／dispose 只停止尚未送出的項目；已送出操作不能取消或復原。正在等待的回應仍記錄該筆結果，dispose 後不通知畫面或繼續後續項目。
- 所有計畫、結果及問題只存在 controller 記憶體；沒有持久化、key／schema、啟動恢復或自動重送。原管理事件 archive 不變；不把此批次結果冒充完整官方事件紀錄。

## 證據與未完成

2026-10-04續接：批次使用者核心prepareUsers／executeUsers已實作（未接UI），動作只含timeout／warn。沿原ban(duration必填)與warn API、既有scope及授權供應者，沒有新增API／GQL／保存；timeout不允許null秒數轉成永久封鎖。警告原因trim後1–500字，禁言1–1209600秒／原因至多500，warn不帶seconds；最多50來源選取，非法設定不替換舊計畫。對象ID為原有效數字user-id，按user去重，固定名稱／示例原文／理由／秒数；原policy排除自身／台主／MOD與其他來源，另排除非PRIVMSG與echo／synthetic。同一user選取內若有任何本頻道受保護角色提示，所有該user出現均排除，不能先去重丟角色證據。

刪除與user動作共用同一串行runner／一次計畫／取消與unknown停止規則，不可交叉使用舊計畫重送；user結果key為user ID。executeUsers必須提供每筆canManageTarget回呼，在原owner/channel permission之後、寫入前檢查目標當前資格，false停止後續且不寫入此人。這不是自動取得官方即時角色，也不代替Twitch最後拒絕；UI接線必須提供有效原context目標檢查，不能硬編碼true。role gate本機拒絕亦標rejected、problem明示目標已變更，不冒称是Twitch已收到。

6新fake測試：同人多訊息只警告一次／原因與ID凍結、角色矛盾保護、無效原因與秒數不破壞舊delete計畫、時間上下邊界及第二人角色改變停止。無真人管理動作。尚需介面選動作／reason／seconds、user預覽與confirm／結果、watch的動態目標資格接線；永久封鎖／解除等其他批次尚未提供。這輪核心不表示批次禁言警告可從App使用。

2026-10-04續接：每次拖曳timer在任何捲動前檢查原permission；失效立即停timer並提示身分／頻道變更，不等post-frame選取才檢查。此前fake測試重現撤銷後200ms仍從22px滑到110px，修正後偏移保持22px，原斷言不放寬。進入預覽時退出拖曳模式，結果清單恢復原生ScrollView physics。

新增3widget：邊缘拖曳失權停止、Ctrl+Enter不能建立可發送預覽；320×640與844×290字級1.3的觸控模式控制區移動清單→列拖曳→邊缘選取→預覽且無overflow／寫入。四份39項全過（在退出拖曳模式小修前），最後2尺寸測試另重跑全過且斷言預覽physics恢復。不是Android實機／鍵盤、所有字級、拖曳50上限的證明，其他原門檻保持。

2026-10-04續接：拖曳選取預設關閉，顯式開啟後從合法列按下作固定anchor，移動選／取消範圍，以手勢開始前的集合為baseline，回拉不殘留本次已移出範圍的項目；同原50限制／policy／permission。pointer-down而非pan-start位置作anchor，pan開始亦處理當前移動位置。拖到面板邊緣由50ms局部timer每次22px捲动，手勢recognizer放在viewport外而非lazy列，避免原列卸載終止手勢；結束／cancel／dispose／失權停止timer。預覽快捷鍵在拖曳進行中不作用，不提供手勢直接發送。模式開啟時從控制區拖動可移動清單；關閉模式恢復原ScrollView手勢。scroll controller／row keys／baseline均只在該面板，非播放器／聊天室runtime變更、無新保存欄位。

新增3項widget：逆向範圍及取消至零；touch拖曳與回拉baseline；mouse邊緣捲動超200px、lazy列仍選取、拖曳未結束即dispose不留timer或寫入。首次回拉失敗揭露錯誤anchor與pan門檻漏處理初次移動，已修並保留原斷言。四份36項全過；雙平台實機、拖曳跨全部50上限／角色失效時序／不同高度與字級仍需深入驗證。沒有真人操作。

2026-10-04續接：局部CallbackShortcuts／Focus提供Ctrl+Enter，只在選取階段開預覽，空選取／已預覽／確認中／已開始均不作用；沒有快捷鍵直接批准刪除。Shift+點選使用上一個選取端點作範圍，手機可開範圍模式後點兩端；範圍跳過原policy不合格項，加入或移除依端點checkbox動作，超過50整次拒絕保留原集合，不默默截斷。模式切換清anchor，原初始預選合法項可作桌面Shift anchor。端點與模式只在面板記憶體，不新增儲存key或API。這是面板範圍操作，不是直播清單拖曳。

3新widget驗桌面Shift／手機範圍模式跳過其他來源頻道，Ctrl+Enter開預覽、第二次不開確認／無發送，以及51則範圍原子拒絕。連批次核心／面板／單筆與管理面板四份33項全過。未做實機键盤或觸控驗收；原拖曳、快捷鍵可配置與其他批次動作仍待補。

2026-10-04續接：watch訊息管理動作新增可選onOpenBatch，只有原canDelete合法訊息且有接線才顯「批次選取訊息」。沿既有context入口（手機長按／桌面右鍵），開批次面板時帶initialMessageId，快照中符合原policy才預選第一筆相符訊息；不提交、不預覽代替確認。watch回呼捕捉原runtime並重新檢查固定API permission，失效不開另一頻道批次。沒有新API／儲存欄位。

新增3項證據：訊息context選單實際開啟批次並預選但零發送；51筆清單選滿50後停用額外選取、仍能取消已選恢復入口；來源tags與list在面板開啟後改動，預覽及送出仍固定原ID、零新增目標。四份批次／單筆／管理面板回歸30項全過。context callback與批次UI為fake API驗證，watch的原runtime與權限接線為靜態證據；未模擬完整直播卡的長按／右鍵事件鏈或真人實機。

2026-10-04續接：已由聊天室管理面板新增「批次刪除訊息」入口，沿原 watch createChatModerationApi 的固定 owner／channel／runtime canModerate closure；開啟時複製來源 tags 與清單形成快照，不因即時訊息改變預覽。逐項選取最多50（可取消已選）、不合法項停用；預覽列名稱／原文／官方ID、排除數，確認框再次顯示原頻道／數量及不可復原。取消確認不提交、確認前失權不提交；執行中可停後續，關閉dispose亦只停後續；結果逐筆呈現、不提供原批直接重送。未新增持久資料或API。

新面板7項fake操作測試涵蓋900×700、320×640、844×290的選取／預覽／取消確認／正式確認，失權、未知結果與請求中停止／關閉；原管理面板新增實際打開批次入口測試。連9核心及原管理面板合計21項全過。首次清單因Material祖先位於DecoratedBox外而觸發framework assert，加入局部Material（不改共用框架）；原lazy面板測試改實際scrollUntilVisible，未屏蔽例外／放寬斷言。尚未完整watch渲染或真人兩平台測試。

docs/twitch_moderation_batch_test.dart 的 9 項 fake API 測試：排除／去重／凍結、超限／衝突、確認前取消／權限撤銷、請求中取消／防重入、舊計畫、dispose 晚回應、拒絕／未知停止與兩筆間撤權。沒有真人操作。

待補可配置快捷鍵與直接直播清單多選工作流；兩平台現可從管理面板或既有訊息context→管理選單進入批次刪除與禁言／警告，面板有範圍／局部快捷鍵／拖曳及保守本機目標資格檢查，這不等於完整手勢鏈、官方即時角色或實機已驗收。缺官方 message ID 的使用者可切使用者模式選取，仍需完整 user 模式手勢與尺寸測試；其他批次動作尚未提供，需真人測試頻道與兩平台驗收。模擬面板及核心測試不代表全部批次功能完成。
