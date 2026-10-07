# 聊天鍵盤入口與儲存界線

## 2026-10-04 最新：直接 MOD 快捷鍵接原確認流程

已聚焦訊息的 Ctrl+D／T／W／B／Shift+B 分別開刪除／自訂禁言（預設600秒）／警告／封鎖／解除確認。只 primary focus、KeyDown、Ctrl 且無 Alt／Meta；Shift 只允許解除，其餘组合／repeat 不派送，編輯子焦點仍保留原快捷鍵。此五組目前固定，非 StreamNook 完整可配置命令；既有五個單鍵設定與 schema 不變，設定卡有固定鍵說明。

實際 watch→area→list→feed→message wrapper 已接選定訊息與 enum 回呼。watch 初次及確認後核 captured runtime／API identity、mounted、原 canModerate 回呼、原訊息仍在相同使用者來源；delete 重查目前匹配訊息的刪除資格，其餘沿 canManageVisibleUser 保守合併角色。不用 viewerIsModerator flag 或舊快照放行。快捷入口的結果視窗與原 TwitchModerationMessageActions 共用確認／原因／秒數驗證及提交；新增確認中 guard 防同時多開。原刪除選單也在確認後重核本機資格。不代表官方即時角色查詢，最終 scope／role 仍由 Twitch 驗證。

無新 endpoint／scope／GQL hash／儲存 key：沿既有 deleteMessages（DELETE /moderation/chat，moderator:manage:chat_messages）、ban（POST /moderation/bans，moderator:manage:banned_users）、warn（POST /moderation/warnings，moderator:manage:warnings）、unban（DELETE /moderation/bans，同 banned_users scope）。未改 OAuth/token、IRC 或 Channel Points。新增 enum／回呼／確認 guard 都只記憶體、隨 widget 生命週期存在，不保存被選人或待管理操作，也不自動重送。

新增 wrapper 全五組與不攔編輯／repeat 測試、五動作確認後僅一次 fake write、確認中撤權零寫入；真 watch Ctrl+D 取消／關閉、確認途中訊息消失拒絕，以及撤權不再開確認亦驗。六份鍵盤／settings／單筆管理39項全過；五份原 MOD 單筆／批次回歸87項全過（兩組包含重複檔案，不相加）。本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。未向真人私訊或管理真實聊天室。下一單元補 context／owner-channel 更換、可配置組合鍵與低高度／大字級確認，並回到全功能盤點；原私訊官方列表／雙向與可靠ID及 Windows／Android 真人驗收仍未完成。

## 2026-10-04 最新：正式設定入口、共享鍵位與平台儲存 adapter 驗證

新增完整 TwitchAppSettingsSheet 渲染測試：900×700 與 320×640 從帳號分類切到聊天，實際捲到鍵位下拉、選 H，核對共享 controller 與 SharedPreferences adapter 保存結果。播放器／更新分類以未使用的 fake controller 隔離，沒有登入、下載或 runtime 動作。兩種尺寸放在同一 test zone，以免跨測試沿用 production singleton 的串行 Future 造成測試停滯；下拉捲動以 hit-testable 目標為準，不忽略點擊警告。

新增 default adapter mock roundtrip：新 controller 重讀 H／停用，reset 後另一新 controller 重讀預設，其他設定 sentinel 與 keys 保留。新增兩個真正 feed 共用同 controller 測試：改 H 後各自原 U 不再開卡、H 開各自正確訊息，更新不移走第一個 feed 的焦點。這是 mock 平台保存與兩個 widget，並非主機磁碟重啟、Windows 多視窗或 Android 實機證據。

六份 keyboard/settings/storage/watch/message-actions 共 32 項通過；本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。本輪僅修改 docs 測試及進度，無產品 API／scope／hash／儲存 schema／token 或真人資料變更。下一單元接直接 MOD 動作快捷入口及明確確認，沿既有動作與即時權限 gate；低高度／大字級／controller 移轉與原私訊真人雙向、可靠 ID、Windows／Android 全目標仍待完成。

## 2026-10-04 最新：設定 UI 已接 App 聊天分類

App settings 的 chat tab 在聊天室字體／信任網域後新增「聊天室鍵盤操作」區，沿同一共享controller，不放到身分／更新分類。五命令選擇支援鍵或停用，自動等待原串行保存；只成功才顯已保存，衝突／保存失敗維持原binding並顯原因，等待時全部入口停用。讀取失敗可重讀；損壞時選鍵停用，只允許明確reset復原。

reset確認明示只替換五項本機鍵位、不更動其他設定／聊天歷史；取消零寫入、確認才沿原reset。長確認内容可捲動。設定卡只訂閱controller，不dispose共用owner；close之後晚保存由controller完成而不更新已移除UI，換controller隔離舊operation狀態／reset確認。新UI不增加endpoint／scope／hash或存儲key，原鍵位schema不改，不碰OAuth-token。

新增5widget驗320×640選H、衝突零寫、停用成功、false保存維持U、corrupt重設取消與確認，以及等待保存close後晚true／false兩時序。初次popup測試因lazy未建立目標就取.last而失敗，改實際向上捲popup至hit-testable選項，不忽略錯誤或放寬保存斷言。五份設定／保存／訊息鍵盤／watch／單筆管理29項全過；App chat tab入口為已讀接線與編譯證據，尚非整個App settings pane渲染或實機證據。

本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。下一單元驗真SharedPreferences adapter的mock roundtrip／新controller載入及兩feed同步，再做完整設定分類入口與低高度／字級／controller移轉。直接MOD鍵／組合鍵、真人WindowsAndroid與原私訊／全工作包仍未完成；無真人操作。

## 2026-10-04 最新：自訂鍵位保存核心與按鍵接線（未接設定 UI）

新增 TwitchChatKeyboardController，五個 command（older/newer/user/context/clear）沿原 K/J/U/Enter/Escape 預設，可指定 A–Z、Enter、Escape 或 null停用。拒絕相同鍵給兩個 command、未知鍵／Tab與未知command資料，不將Ctrl組合或播放器鍵位納入此局部設定。尚無自訂組合鍵、設定面板或直接制裁command，不能宣稱使用者可從App設定操作。

新獨立 SharedPreferences key `twitch_chat_keyboard_bindings_v1`，JSON `{version:1, bindings:{older:...,newer:...,user:...,context:...,clear:...}}`，儲存穩定名稱而非平台keycode；單機App偏好，不含帳號、token或焦點、不做遠端同步。讀取最多8192字元、需完整五命令／合法值且無重複；壞資料／不支援版本保留原raw並鎖修改，暫用預設，只有明確reset可覆寫。讀取失敗不能直接set越過讀取寫入，reset為明確復原；不自動刪除資料。

load/set/reset在同controller串行；先讀原資料及校验，再等write成功才發布新bindings。false或例外不改目前鍵位，不冒稱已保存；等待時仍是舊設定，下一次可再試。reset亦須write成功才清corrupt狀態。預設單一共享controller供feed；controller替換／dispose解除listener，設定更新廢棄舊導航generation，wrapper與pane入口均讀新設定，不碰原OAuth／token存儲。

4新fake儲存測試驗重啟載入與停用、衝突／Tab零寫入、壞檔／版本保留及reset、保存失敗可再試、并發串行與等待不提前套用；1新實際feed驗user改H後U不作用、H才開原card且已保存。四份共24項全過。前輪watch test警告用局部ignore與說明標註真正flutter test fixture用途，正式Prefs程式不改。

本輪唯一 `flutter analyze --no-pub lib/features/twitch docs` 無問題。下一單元接設定面板的鍵位選擇、停用、保存錯誤及reset明確確認，驗真Prefs adapter／重啟與兩feed同步、衝突提示與角色context；原私訊真人雙向／可靠ID及全工作包仍未完成。沒有真人操作或新API／hash。

## 2026-10-04 最新：watch 接線錯誤已修，完整聊天面板測試

已讀原 TwitchModerationApiService.canModerate 欄位為 bool Function()?，watch panel改成 `widget.moderationApi?.canModerate?.call() == true`，兩層可空都不默認放行。沒有變更原API欄位／授權／token供應者。原watch建立的owner／channel／runtime閉包仍為權限來源，panel只呼叫它，不用viewerIsModerator偽造權限。

新增 twitch_watch_chat_keyboard_test.dart，建立真正的WatchChatPanel→MessageArea→MessageList→Feed，搭配可變假runtime、無網路動作的貼圖服務／Hype controller與mock SharedPreferences。2新widget驗原可呼叫gate確實多次執行、pane K選最新並U回到原user callback，撤權後area／feed回呼立即false；API未提供gate則pane不可聚焦、零user操作。不是只重測feed人工傳true，也不宣稱主WatchPage／真人scope／全部裝置端到端。

三份鍵盤與單筆管理回歸19項全過；唯一analyze 0errors／1warning（新watch test:46，docs下測試呼叫setMockInitialValues被辨認成非test的visible-for-testing警告），按規則未修正或重跑。下一輪先針對此實際flutter test fixture標註測試專用API用途，不變更正式Prefs邏輯。沒有真人登入、管理或私訊，也沒有新endpoint／scope／hash／存儲key或OAuth-token改動。自訂鍵位／衝突處理／重啟保存、直接動作確認與owner/channel切換等完整鍵盤門檻仍未完成；下一单元接独立鍵位設定及儲存，不反覆擴同一基本接線測試代替功能。

## 2026-10-04 最新：未選訊息的 MOD 入口（watch 接線尚有錯誤）

feed 新增 canStartKeyboardModeration 可選回呼；有權限時原生 Tab 可先聚焦聊天室區域，J／K初次皆選source最新訊息，不先偏移。只pane primary focus、無修飾、KeyDown，按鍵與兩次post-frame移焦點前重核回呼；TextField兄弟焦點不接事件。普通viewer／VOD未提供回呼，不新增pane tab-stop，原已聚焦訊息的只讀導航仍保留。

由watch chat panel→message area→list→feed傳遞，但本輪唯一analyze抓到watch panel:534的 `widget.moderationApi?.canModerate == true` 不同型別比较：canModerate是可空函式，不是bool，實際watch入口目前被此錯誤停用。下一輪首先讀原API欄位並改成呼叫可空回呼，再補watch adapter測試；不能以feed fake回呼測試宣稱watch可用。按規則本輪未再修正／重跑analyze。

新增5 widget：J／K各自從pane選最新，Ctrl組合不移焦點、按鍵前／定位途中撤權不移到訊息、原輸入框有MOD pane仍保留J／K。連前輪導航及單筆管理17項全過；本輪analyze 0errors／0warnings／1 unrelated_type_equality_checks info（非純格式），前輪5大括號提示已補。無新API／scope／hash／保存或真人操作，來源gate仍應沿原owner/channel API。

尚未提供mouse背景聚焦或全域入口；本機pane FocusNode只隨feed存在並dispose。不宣稱自訂鍵位／保存、直接管理鍵、已開始導航後的role/context移轉及兩平台實機完成，原完整目標active。

## 2026-10-04 最新：J／K 導航與 lazy 定位

聚焦訊息後 K 往舊、J 往新，邊界停於第一／最後一則，不跨頻道或 wrap。沿實際 widget.messages 的 stable key 找目標，展開原100則自動跟隨視窗，重新取得含歷史divider的反向列表index；使用套件官方 [ListController.jumpToItem](https://pub.dev/documentation/super_sliver_list/latest/super_sliver_list/ListController/jumpToItem.html) 定位，不自行估算像素／列高。下一frame才轉移焦點，generation／mounted／attachment及原source目標存在檢查拒絕舊定位。

鍵盤瀏覽暫停auto-follow／待flush，近最新時新訊息亦不搶選定焦點；原回到最新按鈕解除瀏覽並廢棄待定位，Esc清焦點與導航generation、恢復原一般捲動判斷，不強迫跳最新。原晚到follow settle亦尊重鍵盤瀏覽。J／K只在訊息primary focus處理，不全域攔字母；尚無未聚焦時J／K自動選最新的MOD限定入口。

FocusNodes由feed持有，wrapper只dispose自身fallback node；以當前source／可見快照keys在frame後淘汰已無來源的節點，整個feed dispose释放list controller与nodes。沒有新API、保存key／schema、owner資料或重啟恢復；角色授權仍在原user／context action入口，導航不直接送制裁。

2新widget：160則長清單从159連續115次K到44、J到45、目標實際hit-testable；起點边界／live append保留焦點／待jump移除feed無例外。連原鍵盤與訊息管理共12項全過。首次Tab定位測試假設Tab必選最新，實際原生幾何遍歷選134；改明確聚焦已建立159再驗導航，不改115次與目標44斷言。原Tab實際feed測試仍保留。

本輪唯一analyze：0 errors／0 warnings／5 infos，message_list.dart:308、363、466、475、487多行if缺大括號，未循環修正或重跑。下一輪先修格式，再補未聚焦入口、角色context與連續按鍵／淘汰時序；自訂鍵位及保存、直接動作確認、WindowsAndroid實機及原完整工作包保持未完成。

## 2026-10-04：訊息列的實際鍵盤入口

參考來源：[StreamNook chatModController](https://github.com/StreamNook/StreamNook/blob/main/src/keybindings/chatModController.ts)、[commands 的 MOD 分類](https://github.com/StreamNook/StreamNook/blob/main/src/keybindings/commands.ts)。上游先選訊息，再開使用者卡或操作；J／K、Delete、1／2／3、B／A 是其獨立命令，本輪不宣稱全部複刻。

VioClass 的實際 TwitchChatMessageFeed 每列接上局部 Focus，原 stable key 移到外層以保存訊息對應；Tab／Shift+Tab 沿 Flutter 原生 focus traversal，只有該列為 primary focus 時 U 才開原使用者卡、Enter 才開原 context 選單、Esc 解除焦點。沒有自動聚焦或全域 HardwareKeyboard handler，不攔輸入框／選取子元件的按鍵；含 Ctrl／Alt／Shift／Meta 的組合或 KeyRepeatEvent 不執行操作。

鍵盤入口只是導向既有 context／user callback，不新增 API、不直接發出制裁、不取代原 MOD 權限及確認流程。普通觀眾沿原 context 僅有其可用功能；沒有 onOpenUser 就不處理 U。焦點提示只在當列聚焦呈現，列表原暫停／緩衝／來源分頁及播放器 runtime 不改。

FocusNode 隨該列 dispose；沒有保存 last-message、帳號／頻道焦點、key/schema、token 或啟動恢復。不存在跨視窗全域註冊，因此移除清單後不留按鍵回呼。這不是 Android 軟鍵盤快捷功能，外接鍵盤沿相同局部行為。

3新 widget 含實際 feed Tab→U／Enter 與對象 identity、移除後無操作、修飾键／重複鍵與 Esc、TextField 子焦點不觸發；連原訊息管理回歸10項全過。沒有真人操作或 Windows／Android 實機驗收。

未完成：J／K 的歷史訊息導航與 lazy row 捲動、直接命令對接既有確認、可配置鍵位／衝突與重啟保存、焦點在舊訊息淘汰／owner-channel 切換的整合、完整 Windows／外接Android驗收。原本批次面板 Ctrl+Enter 仍是局部預覽功能，不代表完整快捷鍵系統。
