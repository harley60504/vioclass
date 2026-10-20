# Twitch 完整功能長期測試

建立日期：2026-10-11。目標持續進行；表中既有證據引用 `twitch-desktop-debug-test-report.md`，不代表本輪重跑。

## 邊界

- 依使用者 2026-10-12 指示，流程改為找出問題、定位、修正、同範圍回歸，再繼續下一項。可重現的問題不只列待修；間歇問題先補診斷，未驗證不宣稱修好。完整測試範圍與帳號安全界線不縮減。
- 保留既有登入；不清 cookie、不登出真實帳號、不存取或記錄憑證內容。
- Windows 真實 App 透過 Flutter 合成事件操作，不占用系統滑鼠。測試 binding 使用 fullyLive，避免測試等待使畫面停更。
- 帳號寫入一律假的 API／模擬，不對 Twitch 發言、追隨、訂閱、私訊、剪輯建立、點數兌換或管理。
- 不以服務單元測試冒充完整頁面或播放器驗證。已建立不讀原帳號的Windows訪客隔離：fake auth／discovery搭配正式頁面、真實匿名直播與唯讀IRC；尚非完整App訪客首頁與所有資料接線，不清除原帳號來製造訪客。
- 每回合最多一次 analyze；範圍、修正與協議限制遵循 AGENTS.md。

## 測試矩陣

| 功能 | 已有證據／測試方式 | 狀態與剩餘要求 |
| --- | --- | --- |
| 儲存登入初始化、預設追隨 | Windows App 斷言儲存登入解析後 selectedSection=following；獨立真實流程不切瀏覽，點首頁第一張顯示的追隨直播卡，頻道一致、聊天室連線與 60 秒互動播放通過 | 需補無追隨 scope、無直播追隨卡／失效重試；僅此帳號當下 UI 第一張，不宣稱所有排序／篩選狀態 |
| 追隨頁篩選、分頁與重試 | 29 項 widget／mock 通過：既有篩選／分頁／重試／刷新／離頁／profile／授權提示；離線多頁去重、第二頁失敗／重複 cursor 的 footer 實際重試、離頁／刷新後不續取舊 cursor；新 service 替換後重載並忽略舊多頁成功／錯誤、失權新來源不顯示舊追隨；25 頁 2,500 筆全收齊 | service 替換不是同一 authService 的真實帳號切換；選單入口／直播分頁仍使用公開方法，不冒充工具列／捲動。>100 開台追隨的離線分類、真實多頁／篩選／網路耗時與完整帳號路由仍需補；不宣稱 HTTP 取消 |
| 驗證中／訪客／登入、換帳號與晚到回應 | 共用session與聊天面板自動測試；session／discovery檔23項通過，含追隨直播／頻道服務晚到身分防護及新增4項正式Browse／Following頁面：訪客／checking公開卡片載入，追隨checking不誤叫登入、authenticated後才讀資料，訪客只有實際按鈕才觸發假登入 | 這是正式頁面＋服務配合fake auth／傳輸，非完整App初始首頁／直播聊天室／快捷入口矩陣；更多路由與權限仍需補，真實帳號不登出 |
| 追隨讀取服務授權 | 直播／頻道兩方法：訪客驗證零次／資料請求零次，已登入缺 user:read:follows 保持 authenticated 但請求零次；有效權限才發送 mock GET 並用已驗證 user_id／Bearer。正式頁面初始缺scope／授權後retry及中英提示、guest與失權切換均有隔離回歸；與Following／home共105項通過 | 修正缺權限卡片誤寫「需要登入」為「已登入，但缺少追隨權限／重新授權」，不是token儲存變更。完整登入流程及真實失權恢復仍待測，不操作真實OAuth |
| 公開瀏覽、搜尋 | 既有home／browse與home39＋watch20回歸保留。Windows隔離guest搜尋riotgames，實際riotgames3的VOD與clip卡→guard→watch，目的ID／Native及兩層影格、同App實際UI返回再開及新client通過；VOD兩次自然到30秒、API20／Authorization0，clip兩次各十秒前進、API18／Authorization0。Archive模型既有證據保留 | 每種媒體只一張卡，auth／帳號／chat與補充metadata mock、音訊關閉；其他入口／多頁／錯誤／上限去重及返回偏好仍待驗。新返回用UI，舊mock返回為Navigator.pop；Archive是时间推測，未取消已送出HTTP，不把入口成功當黑畫面結案 |
| 頻道與媒體庫 | 匿名清單 API；Windows 真實 VOD／剪輯分頁切換、卡片導頁、返回、關於與搜尋清空通過；載入更多 VOD 20→31、剪輯 30→60，前綴保留且無重複 ID；VOD 播放器實際點入口、三頁讀取、關閉後原 VOD 持續前進通過 | 初始媒體庫仍直接開 sheet；直播／首頁入口、命中篩選、多頁耗盡及錯誤恢復仍需補，搜尋空結果不當成網路錯誤 |
| 直播播放與聊天室讀取 | 真實 App 連線／15 秒前進與跨頻道通過；追隨第一張卡後 60 秒／六次點播放器，進度增加 62,200 ms，無取樣停滯／緩衝；直接監聽 runtime 每 10 秒通知 19／20／18／19／17／34 次。新增隔離訪客ow_esports匿名媒體與畫面，zackrawrr真實IRC runtime訊息10／raw22、connect1／sendAttempts0、canSend=false、卸載連線解除及10秒直播增10,000ms通過 | 斷線恢復、更多頻道／格式／更長觀察待測；訪客discovery／startup補充仍mock、無音訊／歷史API、非完整App訪客入口。原已登入runtime數字為批次／狀態通知，不是逐則訊息數或高流量門檻，未保存聊天內容 |
| 左側追隨欄 | 13 項元件測試；Windows 真實點不同追隨頻道，頁面替換、新來源／chat 前進、選中標記與再點不重開通過；迷你展開、首頁及追隨欄新 watch 各 12 次 100 ms 左邊位置差異 <0.5 logical pixels | 僅已登入三次有界窗口；完整驗證中／訪客路由幾何、API 失效恢復、hover 展開與 profile 效能仍待測 |
| 完整 DVR | 修正後 Windows 單次與延伸流程通過：暫停恢復、45 秒跨分段、1/3／2/3 重複跳轉各 10 秒、再觀察 120 秒增量 121,715 ms、返回直播；七項本機回歸通過。新增真實 Slider 30% 拖曳，修正測試換源位置重設的起算競態後，十秒 native 增 10,115 ms、控制列同步前進、返回直播增 10,013 ms | 保留修正前進度斷言失敗與逐秒重設證據；本次只修測試，不當成正式卡頓已修。更多頻道／不同格式、錯誤恢復、逐幀跳轉精度仍需補；不把單一樣本的長測當成全部完成 |
| VOD／剪輯播放 | 既有已登入與匿名riotgames直入證據保留，早期暗影格失敗不撤銷。新增匿名搜尋riotgames3各一張普通VOD／clip，精確ID點卡、同App實際返回再開及新client通過；VOD十秒增10,034／10,000ms且兩次自然到30秒、六個取樣兩層有內容；clip各十秒增10,000ms，Authorization皆0 | 單一頻道／每種一張媒體，auth／chat／帳號與補充metadata mock，非完整App startup。拖曳／畫質／音訊／回放聊天／剪輯跳轉、其他訪客入口與返回偏好仍待驗；歷史卡死／原生內部重疊未結案，直接seek不冒充手勢 |
| 播放授權與完整性證明 | 本批播放完整性 19 項測試通過（其中一項僅驗證服務編譯接線） | mock 涵蓋直播／VOD／剪輯授權、匿名 fallback、受限拒絕、帳號／client 隔離與競態；不代表真實媒體播放通過 |
| 播放快捷鍵、音量、畫質、全螢幕 | Windows 真實 VOD／剪輯暫停／播放與左右方向鍵 ±10 秒通過；完整 DVR 左右鍵產生新 stream generation、解析目標誤差 <2 秒且各持續解碼 10 秒；既有完整DVR長測已涵蓋UI暫停後左鍵跳轉保持暫停與canonical目標，UI恢復10秒後接續長測及返回直播通過；VOD 時間輸入框與 DVR 切直播聊天室後的 ExtendedEditableText 有焦點時左右鍵不跳轉，點回播放器後恢復；既有部分音訊測試 | 其他編輯框焦點防護、拖曳、音量／畫質／全螢幕仍需補整合證據；暫停跳轉為既有單一樣本證據，非本輪重跑或所有頻道；解析目標不等於逐幀或畫面時間精度，不改無關偏好 |
| 迷你播放器與路由恢復 | Windows直播／VOD／clip短返回、展開同來源與位置接續、close／pause通過；影片touch／mouse及footer mouse修正後皆拖50px並回位，VOD／clip縮小保留暫停通過；新來源進入後舊mini清除、owner／URI與10秒解碼前進通過；受控恢復中close重疊通過；VOD／clip受控pre-open等待與新owner重疊有通過樣本 | clip→live仍有90秒黑畫面／buffering間歇失敗，不以成功重跑判定修好；native open內部重疊、keep-mini=false、完整DVR／播放結尾／推疊路由及真實斷網仍待測。VOD／clip為正式route guard直入短樣本，不替代媒體卡接線／長時間／所有平台驗證 |
| 聊天發言、貼圖、身分與特殊訊息 | 普通 IRC 核對 chat:read+chat:edit；缺權限提示與重新授權 callback、正式頁面送出／草稿保留及普通 send 晚到身分防護已有隔離回歸。缺 chat:read 改匿名傳輸但保留 authenticated viewer，四組 scope 核對 token／nick／factory 與發言資格；既有 lifecycle／watch／permission 三檔 69 項證據保留。最新 lifecycle 單檔 49 項通過：特殊點數訊息晚到結果十案、送出前身分／pending／runtime 變更與雙入口重複送出四案 | 真實缺權限帳號的匿名讀取／重連、OAuth 重新授權及其他特殊 API 權限仍待驗。特殊點數訊息生命週期已驗收；watch streak／resub 的各自 API 結果、同控制器新送出與舊結果重疊，以及完整 UI 草稿接線仍待測。沒有真實寫入或 IRC 協議／Points payload 變更 |
| 管理、AutoMod、置頂、管理紀錄與快捷鍵 | 部分假的 API／鍵盤測試；AutoMod 設定／封鎖詞兩檔 16 項 mock 通過，含 scope／帳號／頻道校驗、取消確認、遠端變更、失權／失敗、分頁去重與小螢幕 | 其他管理功能的完整權限矩陣、快捷鍵、失權／換帳號與跨頻道頁面防護仍待測；不執行真實管理寫入 |
| 追隨／訂閱／建立剪輯 | 僅登入門檻已檢查 | 使用假的 API 驗證可用／拒絕／失敗；不執行真實操作 |
| 私訊 | 聯合登入四項 mock；選取／恢復／刪除生命週期三檔40項通過；完整inbox隔離測試171項兩輪各20秒全通過，涵蓋分頁、mock送出／失敗、草稿／帳號隔離、恢復／取消、通知假事件、歷史捲動與多尺寸鍵盤 | 尾端測試已修正fake清單缺少選中peer的前提，未改正式同步規則；先前間歇溢位及cache計時器未重現且未定位，不宣稱修好。原生平台通知／背景與更廣入口接線仍待驗證，未讀寫真實私訊 |
| Channel Points／預測／Hype Train | 點數三項假的 API 測試通過：未登入不查詢、缺少餘額不當成零、有效餘額 | 預測／Hype Train 與其他點數功能仍待測；不修改 payload、不兌換 |
| Drops 與聯合登入 | 聯合登入四項 mock 測試通過；調整主帳號 fixture 的 accessToken 與 getValidAccessToken 一致 | 保留原憑證協議；未完成 Drops 全流程，不操作真實登入對話框 |
| 通知 | 17 項模擬政策測試通過：去重、過期、有界歷史、載入競態、帳號私有資料、點數聚合、登出取消、更新通知 | 原生通知、完整頁面與實際失敗恢復仍待測 |
| 設定／語言／字體／聊天室樣式 | 音訊十項 mock、聊天室鍵位五項 widget 測試本批通過 | 涵蓋保存競態／失敗、損壞／重設取消、關閉後晚到回應、音效拒絕回復；語言／字體／樣式及完整設定頁仍待測，不覆寫使用者現有設定 |
| 更新檢查 | controller dispose晚到下載防護已修，9項隔離測試通過；service stable10、beta12項通過：數字版本比較、GET endpoint、無授權header、平台asset、缺檔拒絕、網路重試、beta排除draft／空版本與數字最大版 | beta同數字版本prerelease順序、真實下載、更新頁／OS安裝仍待測，不安裝或取代使用者App |
| 網路錯誤與恢復 | 部分 session／背壓測試 | 503、401、斷線、載入取消、重開待補完整頁面證據 |
| 一般 App 卡頓 | 時間軸整頁 setState 已改局部刷新並有兩項元件回歸；完整 DVR 長測通過。新增 60 秒直播同步觀察：播放前進 60,433 ms，無取樣停滯／緩衝，P95 build=4,792 us／raster=3,624 us；build 最大 43,982 us，8 幀 >33.333 ms | 使用者留前景感覺沒改善，仍未排除卡頓；只是 debug／integration 樣本，chat controller 計數不是 runtime 訊息頻率，不是一般 App／同頻道前背景 A/B 或 profile；1 秒取樣可能漏掉短停頓，不推算 FPS，不宣稱已修好 |
| 行動裝置專屬功能 | Windows 優先；內嵌瀏覽器設定四項平台 override mock 通過（含 Android UA／viewport、iOS desktop 設定、Windows 保留選項） | 未啟動原生手機 WebView，不等於實機驗證；platform 原始碼仍不手動讀取，裝置專屬項目另列限制 |

## 2026-10-13 最新驗收摘要（案例層級）

上方矩陣保留原始盤點基線；以下摘要與「已修問題與回歸結果」補充最新證據。已收尾的是指定案例，不是整列功能全部完成；不要因上方舊待測描述再次重跑已驗收案例，也不要把不同批次的重疊測試數累加成總完成數。

| 範圍 | 已收尾案例 | 仍需驗證 |
| --- | --- | --- |
| 聊天與特殊訊息 | 普通／特殊送出生命週期、重複送出、streak／resub 結果分支、新舊送出隔離、草稿與通用失敗提示；兩尺寸缺聊天室 scope 保留已登入判定，重新授權取消返回；輸入法送出防重複、失敗與途中登出通過 | 真實缺 scope 讀取／重連與 OAuth、實體鍵盤 Enter；特殊 API 真實權限、其他貼圖入口 |
| 管理與管理紀錄 | 確認前更換 API／頻道阻止舊操作；紀錄停止／失權／換分區時拒絕晚到載入；觀看頁假帳號切換拒絕舊 MOD／API，舊 DELETE 零請求；真正非同步等待下假新帳號重連恢復管理，舊 API 仍失效 | 跨頻道完整管理入口、真人 EventSub／網路、其他管理權限矩陣；隔離重連不替代真人連線 |
| 公開搜尋與媒體庫 | 重試／搜尋清除／分頁去重／取消及來源替換；兩個真實匿名 API 案例通過且無 Authorization／Cookie；兩尺寸訪客直播卡、搜尋直播卡、離線卡媒體庫／觀看／返回的正式路由通過，窄離線卡溢出已修正 | 非空離線 VOD 與真實媒體播放、更多入口／條件；替身播放器和 API 成功不替代解碼證據 |
| 點數、預測、Hype | 過期 engagement、點數／貼圖／claim 的隔離案例及觀看頁點數入口；觀看頁實際下注卡片開正確面板、點外部返回仍是原頻道／聊天；Hype 升級、共享參與者、自然結束動畫及清理兩尺寸通過 | Hype 卡片沒有詳情點擊入口，是否接上既有面板待使用者決定；其他完整入口與真人權限仍待驗 |
| 追隨、訂閱與剪輯 | 正式觀看頁追隨／取消、訪客導頁、驗證中停用、過期結果隔離；側欄點選新路由／舊聊天室斷線；Clip／訂閱目的地服務；剪輯器建立失敗／重試／離頁後失敗；訂閱準備成功／失敗／關閉，登出／換帳號阻止或移除舊頁與正式觀看頁按鈕接線通過 | 側欄新播放器掛載、真實權限；剪輯成功播放／原生資源清理；訂閱原生 WebView／cookie 寫入與清理、裝置登入與重開恢復，不真人付款／發布 |
| 通知與設定 | 通知 owner 切換、首頁假登出清舊通知；播放／聊天／字體設定的保存失敗與重試；兩尺寸完整設定五分頁導航及 Windows 首頁實際設定入口；帳號設定三動作未處理例外已修正，失敗／重試／離頁晚到結果隔離通過 | 原生通知／背景與其他帳號跳轉；正常字體原生顯示／選檔、其他未涵蓋設定；回復寫入再次失敗、原生增強效果、真人帳號操作 |
| Drops | 兩尺寸訪客／無效授權／空庫存／讀取失敗重試／讀取中返回；庫存及活動詳情 Dialog 領取成功、失敗人工重試、重複點擊防護與離頁晚到結果；Windows 首頁實際入口；榜單統計頁等待／排序／503重試／返回，背景讀取重複請求已修正；快取跨服務／憑證切換及查詢中換帳號的服務層隔離通過 | 其他帳號切換與領取結果語意、活動消失分支；真人 OAuth／領取未驗收，假 API 不代替真人權限 |
| 更新 | Beta prerelease 排序；controller 與正常／失敗／重試的兩尺寸更新 sheet 假安裝流程 | 真實下載／OS 安裝、其他版本標籤政策與平台；不得直接取代使用者 App |
| 登入與原生播放 | App 根元件兩尺寸假登入／訪客／缺scope／驗證中／離開；Windows獨立首頁讀實際已存OAuth並真實validate，初次與root重建都選追隨；保留真實Windows／DVR有界樣本；本機影片音量／靜音、OS全螢幕、PCM 48kHz音訊時鐘、180p／360p畫質與暫停保留通過 | main()完整啟動／整個process重啟、真實cookie／OAuth刷新與授權；寬畫面假登入路由Socket清理待定位；黑畫面／AV冷啟動保留但依使用者指示排除；來源恢復／不同格式、聽覺、Twitch／錄播換源、profile效能與手機裝置 |

剪輯器的初始 Player 建立、訂閱的 Cookie 準備與 WebView 建立已有可替換入口，隔離測試不建立原生播放器／WebView、不讀真實憑證。預設正式路徑維持原依賴；剪輯成功後的預覽重建仍直接使用 Player。原生驗收需獨立測試視窗與裝置條件，不能以服務或占位元件替代。原黑畫面無新證據時不作為其他項目前置條件；完整目標仍未完成。

## 完成條件

每列「狀態與剩餘要求」都需對應足以證明該範圍的驗收證據。服務、控制器、widget、完整路由與原生裝置證據分開；局部測試通過不替代完整流程。可重現問題需修復並通過同案例及必要回歸；原黑畫面等未定位問題仍保留待定位，不以成功重跑結案。仍有未驗證要求時，完整目標保持未完成。

### 2026-10-12 剩餘驗收順序

依使用者要求，2026-10-12 19:57 至 22:57（台北時間）優先處理 Windows 常用流程與可重現問題。已驗收案例不重跑；沒有新證據的原生初始化或間歇問題保留待定位、改測其他缺口。截止時交付已完成、已修正與剩餘限制，不把本批時間盒當成完整矩陣已完成，也不刪減原目標。

1. 完整觀看頁接線：點數／管理的帳號與頻道切換、側欄實際換台、訪客快捷入口。使用假 auth／API，驗證實際入口及返回，不真人寫入。
2. 設定與跨頁資料：儲存失敗、自訂字體匯入、通知帳號跳轉；先確認可替換依賴及既有覆蓋，不重跑已收尾的正常設定案例。
3. 原生專屬流程：剪輯器成功預覽與資源清理、訂閱 WebView、音訊／畫質／全螢幕、通知背景與手機功能。初始錯誤與取消的隔離案例已收尾；原生部分先建立安全隔離或具體裝置驗收條件，不操作使用者目前手動測試的 App，不用 mock 替代。
4. 真人唯讀與效能：完整訪客網路入口、不同 DVR 格式／恢復、profile 效能及原黑畫面。有新證據才對照；不得因此反覆重跑相同成功樣本或阻擋其他項目。

此順序只安排後續工作，不刪減原矩陣要求；已完成的局部案例不再無限追加邊界。

2026-10-13 02:42 至 03:42（台北時間）的後續時段只處理高優先常用流程。使用者明確排除黑畫面：保留待定位，但不重跑、不投入定位或盲改；不將其作為其他驗收的前置條件。延長時段需另行確認，不把時段結束算作完整目標完成。

### 2026 年 10 月 13 日一小時批次交接

本批修正四類問題：Drops背景讀取防重複、領取成功到庫存刷新完成的防重送空窗、榜單最後憑證等待的舊帳號結果競態、訂閱面板在帳號變更後的舊內容有效性。缺聊天室scope／重新授權取消、輸入法送出及媒體卡目的地另有隔離驗收。測試數有重疊，不相加成總完成量。

Windows原生唯讀兩案證明既存有效OAuth經真實驗證後初次與root重建選追隨，追隨／瀏覽主清單完成及實際切換回同帳號／首頁；這是API client白名單，不是整個process的網路防火牆，公共圖片載入可有獨立GET。未開播放器、未刷新憑證，不能取代完整main()、真正process重啟、WebCookie或實體鍵盤。黑畫面依使用者指示排除；Socket計時器來源仍待定位，沒有因果證據不重跑。

收尾已將唯讀原生測試剩餘大括號info修正，該檔單次analyze No issues found；正常lib/main.dart入口的Windows Debug編譯33.5秒成功，未啟動App，不把整合測試入口當作正式啟動版。時間盒结束後不新增測試，完整目標仍未完成。

優先留給實機驗收的是直播／VOD／DVR換源与網路恢復、profile卡頓、完整重啟與憑證刷新；訂閱WebView／cookie寫入與清理、手機及實體Enter也未驗收。正常登入儲存、Cookie與播放器底層限制維持，不在本批盲改或自行擴張權限。需要延長、啟動正常App或更換裝置時，由使用者決定下一步。

## 已修問題與回歸結果

- 2026-10-13 原生唯讀清單及分區切換另案通過：原saved-session測試共享一次讀取的記憶體快照，新增獨立completed-followed-feed案例，不多讀真實prefs、不刷新token。等待正式Following的loadingFirstPage結束且errorText為空、真實追隨HTTP response完成，再點正式Toolbar瀏覽／追隨圖示；Browse主清單完成且無error，回Following完成、同首頁State／同viewer、無登入頁、playback=0。初次exit1是測試找不存在的文字按鈕；依目前圖示UI修正finder，正式程式未改。最新原生兩案通過（編譯35.2秒、測試7秒、exit0），新增案followResponses=4；5個白名單外請求均攔截，未發送，不能以此驗收附加查詢／所有Browse功能。測前後無vioclass常駐process，不操作使用者App。唯一analyze無error／warning、1新大括號info（311:13）；原兩info已在本輪分析前補括號，不反覆修檢查。原生root／清單／切換通過仍不代替完整main()／process重啟／憑證刷新／播放器與網路恢復。

- 2026-10-13 Windows實際已存OAuth的唯讀首頁驗收通過：新增integration_test/twitch_readonly_home_session_test.dart，必須顯式VIOCLASS_READONLY_STORED_SESSION=true。原生SharedPreferences只讀主OAuth及client ID，去掉refresh token與非追隨scope；其後所有prefs寫入轉mock記憶體。readonly auth不呼叫原儲存載入／遷移／刷新，只有真實Twitch validate與白名單Helix GET可通過，禁止其他請求；Web／Drops為無儲存替身、watch factory禁止播放器。Windows獨立視窗初次及root卸載後重建兩階段：saved／unexpired／authenticated／follows均true，兩次selectedSection=following、無登入頁、auth load一次／階段、playback=0；GET累計6→12、追隨GET請求2→4、攔截非讀取0，未輸出token／cookie／帳號內容。編譯34.9秒、原生測試3秒通過exit0，測試前後沒有vioclass常駐process，未操作使用者App。只證明讀取既有有效OAuth後的native首頁選區及root重建，不等於完整main()、process重啟、實際Helix清單完成、OAuth刷新、WebCookie或播放。唯一analyze無error／warning、2個大括號info（93／234），不反覆修檢查。未連手機／平板；低優先及黑畫面不在本輪驗收。

- 2026-10-13 訂閱面板帳號有效性已補齊：既有介面新增可選sessionChanges／isCurrentSession後，兩尺寸準備中登出／換帳號與已顯示後換帳號六案重現舊placeholder仍建立／保留。面板監聽失效並停用重新載入，FutureBuilder不再建立或保留舊WebView；正式觀看頁開啟時捕捉viewer identityRevision／auth instance／頻道，非authenticated不直接開訂閱。六案修正，加實際訂閱按鈕在開啟後立即登出／换帳號四案：正確失效提示、無InAppWebView、零寫入、關閉回同觀看頁。觀看頁／訂閱初始化／訂閱API共111通過（16秒）；初始按鈕測試fixture缺subscribeApi，補正式純URI服務後通過，不當成正式bug。cookie準備函數、儲存及付款流程未改；不能取消已開始的cookie操作，沒有原生WebView清理證據。首輪analyze無error／warning、4 info含新增大括號；下一輪補括號及英文映射契約，訂閱測試13通過（1秒），單次analyze面板／該測試No issues found，不重跑已通過111案。

- 2026-10-13 榜單最後憑證等待的帳號競態已重現修正：fake Drops getToken第二次讀取暫停時，僅切換主帳號，原主帳號比對在await前，最後回傳非空舊結果。改先完成Drops token讀取，再同步比對當前主帳號／Drops token／client ID，舊結果回空，新帳號重查後命中自身快取；與既有Drops回歸36通過（8秒），唯一analyze No issues found。不改token儲存或真人憑證。

- 實體Enter的widget模擬不作驗收：sendKeyEvent(Enter)三案沒有送出，但[Flutter官方文件](https://api.flutter.dev/flutter/widgets/EditableText/onSubmitted.html)說明此API不經引擎轉換、不觸發onSubmitted；不是正式Enter故障證據。暫時案例全部撤回、未改正式程式，保留TextInputAction.send驗收與實體鍵盤待實機確認，不反覆重跑。

- 2026-10-13 Drops 領取成功到刷新完成的防重送空窗已重現修正：兩尺寸活動Dialog，claim成功後卡住下一個快照讀取，原claimDrop在通知／runCheck前就解除busy，實際第二次點擊使claim=2而非1。busy改在通知與刷新後的finally解除，mounted防护保持；不改服務／payload／hash／憑證或樣式。兩個刷新等待案例，及原成功／失敗重試／離頁、榜單、快取同範圍共35通過（5秒、exit0）；等待中按鈕停用且第二次點擊claim仍1，刷新完成已領取按鈕停用。唯一analyze無error／warning、1既有大括號info（537:19）。全為假API，不真人領取。

- 2026-10-13 重要入口補驗：觀看頁無聊天室scope／只有chat:edit／只有chat:read各兩尺寸，仍是viewer=42而非guest、禁止發言、重新授權開正確假依賴登入頁、取消回原State／頻道／草稿、零送出／寫入；6新案加觀看頁回歸85通過（14秒），analyze無error／warning、3既有info。輸入法TextInputAction.send另補成功／失敗／途中登出，等待中第二次提交不重送，保留相應草稿；與同範圍27通過（5秒），typed ExtendedTextField finder後新3案重跑通過，analyze仍3既有info。不是實體鍵盤或真人OAuth驗收。媒體庫兩尺寸剪輯／普通VOD／追看中archive六個卡片目的地，ID／頻道／元資料／分流正確，probe在掛載原生前移除目標並保留原媒體頁State，不多載入；加媒體庫回歸32通過（3秒），analyze無error／warning、1既有info。只證明目的地，不代替訪客播放器／登入或解碼；growing fixture初始預估結束在未來30分鐘，改到現在後符合既有判定，未改正式程式。

- 已登入首頁離頁殘留Socket的兩個有界診斷仍未定位：250ms timer堆疊確認來自NativeSocket地址連線與DNS分支；HTTP connectionFactory診斷未記錄到來源host，失敗仍相同。不能從這些證據判定正式登入／播放器／上游有錯；兩次exit1，暫時診斷全部撤回，保留原失敗，不重跑相同案例。黑畫面未測。

- 2026-10-13 榜單正式統計頁背景重複讀取已重現修正：1000×760／390×844 各成功、503重試與讀取中返回六案，原先 runCheck 的背景 load(showLoading:false) 沒有設 busy，切統計立即產生第二個追隨讀取。背景與前景現共用 loadingChannelPointsLeaderboard 防重複，等待中的更新按鈕停用；不改榜單服務、登入儲存、GQL或樣式。正式頁面搭配 fake main／Drops auth、攔截 validate／追隨／使用者／點數 GQL，兩頻道200／500排序及總計700、503後人工更新成功、離頁後無新增通知／畫面更新通過。六案加既有Drops頁26案及快取契約共33通過（4秒、exit0）。新fixture的Tooltip finder類型、平台override及通知8秒timer收尾已修正，不作正式bug；唯一 analyze 無 error／warning，1則既有大括號info（504:19）。查詢中換假帳號舊榜單結果回空、新帳號重新讀取及命中自己的快取，先前後補服務契約亦已通過；原生剪輯測試兩個warning也在上一時段後補移除，該檔analyze無問題，不改仍未通過的原生結果。

- Drops 榜單快取跨帳號已重現修正：假服務 A 先載入 fixture-a，另一個假帳號 B 的服務未強制刷新時原先得到 fixture-a 而非 fixture-b。原 static 快取在讀憑證之前回傳，改為實例快取並先讀現行 Drops 憑證，比對主帳號憑證／Drops 憑證／client ID／查詢數量；沒有 Drops 憑證清除舊快取，結果完成時也檢查憑證仍一致。單案含同帳號命中不增加 GQL、另一實例讀 B、同實例換憑證讀 C、移除 Drops 憑證回空且不查 GQL，修正後通過；加 Drops 頁面26項共27通過（7秒、exit0）。初始 fixture token 欄位撞既有 getter 已改 fixtureToken；實例欄位使 const constructor 不合法，局部引用確認無外部 const 使用後移除，不當成原始功能問題。唯一 analyze No issues found。全使用假身分與攔截傳輸，不改 OAuth／憑證儲存；此為服務快取證據，不代替實際榜單頁、查詢中換帳號、其他限制值或真人權限验收。

- Drops 活動詳情領取狀態未同步已重現修正：1000×760／390×844 各成功、失敗重試、離頁成功／失敗，八案原先都在 claim=1 後仍沒有「領取中」而失敗。showDialog 的獨立路由使用開啟時的 group，主頁 setState 不會重繪彈窗；新增頁面持有並清理的 campaignRevision，領取開始／結束及快照更新時通知彈窗，依原 game key 讀取最新 group。不改領取服務、payload、hash、OAuth 或樣式。八案修正及原庫存／讀取回歸共26通過（4秒、exit0）：等待按鈕停用且重點不多送請求；失敗保留待領取且可人工重試；成功兩項讀取刷新、彈窗按鈕停用；關閉彈窗與頁面後晚到結果不刷新或加通知。全部 fake auth／Dio，不真人領取。唯一 analyze 無 error／warning，1則既有大括號 info（docs 測試313:19）；活動從新快照消失的分支、榜單與真人權限仍待驗。

- 原生剪輯器測試的靜態收尾：補啟動前置條件大括號、移除三處冗餘非空断言並格式化。單次 flutter analyze 無 error，仍有兩個 closure 內冗餘非空斷言 warning（190／191），留待下一輪，不反覆修檢查。只修改測試排版與靜態寫法，未重跑已失敗的原生案例；先前初始15秒失敗與成功／清理未驗收的結論不變。

- VioClassApp 根元件啟动隔離十案通過：lib/app.dart 增加可選 homeServices 傳到既有 StartupSafeHome，再交給正式 TwitchStreamPage；未提供時依賴／300ms延遲／主頁行為維持原樣，不改儲存登入。1000×760／390×844 各 guest、signed、缺follows scope、checking、啟動中離開：延遲前沒有首頁且auth load=0，離開後不建立首頁或呼叫API；正常只loadStoredSession一次，guest公開browse且不validate，signed有權限進following、缺scope仍authenticated並保留browse且不查追隨；checking先公開browse、不跳登入，驗證完成後進following。通知讀取可另做一次驗證，測試保留最多兩次驗證而非誤認必須一次；未因此修改程式。十案加Windows首頁實際設定／Drops兩案共12通過（2秒、exit0），唯一 analyze 無 error／warning、1則既有大括號info（614:19）。正式App theme／localization／overlay／延遲根路由有接線證據，但使用fake auth／傳輸／window_manager，不是 main()原生初始化／真實cookie／真人換帳號／實機播放驗收。

- Windows 首頁實際設定／Drops 入口兩尺寸通過：1000×760／390×844 的正式 notification overlay＋首頁，Windows title bar 設定 icon 實際開啟、第二次點同 icon 關閉、再開及面板關閉；工具列 Drops 連接進正式頁、訪客提示未取得 token、實際關閉通知再按返回，首頁 State／browse／空搜尋／guest 保留。窄畫面的通知暫時覆蓋返回鈕，使用現有關閉通知按鈕後可返回，不以此聲稱 App 卡死，也未改通知樣式。fake auth／discovery／window_manager，validation=0、player factory=0、API寫入=0、原生視窗變更=0，不跳登入頁；平台 override 不代替完整 App 啟動／真實 cookie／原生視窗驗收。兩案通過，唯一 analyze 無 error／warning、1則既有大括號 info（520:19）。正式程式未改。

- 剪輯器原生成功／清理流程新增有界測試但尚未通過：新增 integration_test/twitch_local_clip_editor_test.dart，fake begin／finalize／render-ready／playback API 搭配本機180p編輯素材與360p成品，預期實際建立按鈕、新預覽解碼前進、舊／新 player disposed與返回。兩次 Windows 獨立執行都在初始15秒門檻失敗（編譯各約30秒、exit1），未到建立成功驗收。第二次數值診斷 begin=0、create=0、hasPlayer=true、hasVideo=false、hasSource=false、height空、playing／buffering=false，只收到初始Texture ID；分類有未分類GPU／EGL提示，不能以此認定解碼或GPU根因。問題发生在素材 API／開檔前，來源尚待定位，不繼續重跑同例、不改正式 runtime。現行依賴 source 確認 VideoController.create 要等平台 Create 回應及Texture ID，尚未觀察哪個等待未完成，也不把它等同原使用者黑畫面。既有初始化失敗／剪輯服務9項回歸通過；唯一 analyze 0 error、5 warning（179／186／187／190／193冗餘 !）、2 info（111／115大括號），未反覆修檢查。前後未發現 vioclass 常駐process；未建立／發布真人剪輯，正式程式未改。

- 搜尋離線頻道的窄卡溢出已重現修正：390×844 使用 MaxCrossAxisExtent=300 時離線卡被分成兩欄，「媒體庫」按鈕 RenderFlex 溢出且不可點。改用隨可用寬度向下取整的固定欄數，搜尋／Browse／Following 三处同用最小300寬的計算，保留原卡片樣式與168高度；補離線觀看入口的可選 watch factories，預設正式依賴不變。1000×760／390×844 實際首頁搜尋離線頻道，開媒體庫（不建播放器）、關閉、點觀看、同假訪客／正確頻道／無VOD離線占位、按返回保留搜尋與首頁 State 均通過；不當成原生播放成功。欄寬門檻與首頁三種入口9項，Browse／Following／媒體庫77項同範圍回歸合計86通過。唯一 analyze 無 error／warning，2則既有 info（首頁import與原測試大括號）。已知簽入首頁 Socket 清理案例沒有重跑或撤銷；非空離線VOD播放與更多入口仍待驗。最初測試深層 Map 不允許 null，已修 fixture，不當成正式搜尋錯誤。

- 原生錄播測試替身契約已補齊、冷啟動仍待定位：直接 getter 契約重現 _PlaybackMountServices 缺 thirdPartyEmotes／officialEmotes，補 forwarding 後由 NoSuchMethodError 轉通過，觀看頁79項回歸通過（12秒、exit0）；補 mock preferences 後契約單案也通過。啟動 emote port 實際使用 services.emotes 群組，不是這兩個直接 alias，因此這個契約缺失不能視為冷啟動原因。Windows 獨立本機 clip AV 兩次仍失敗（編譯各約32秒、執行各11秒、exit1）：API resolves=0、generation=1、loadingAuth／loadingWatch=false、offlinePlaceholder=false、尚無 video／audio params；先前另一次的 offlinePlaceholder=true 不作因果證據。第二次只記錄缺失依賴名稱，未取得新紀錄，停止同例重跑；初始化原因未知，也不能歸因 codec／上游或宣稱使用者黑畫面修好。正式 runtime／頁面未改；唯一 analyze 無 error／warning、3則既有 info，後補 mock preferences 僅經編譯／單案測試。測試前後未發現 vioclass 常駐 process，不操作使用者 App。

- 完整設定 sheet 五分頁導航兩尺寸通過：1000×760／390×844 實際開啟 unified sheet，依次點聊天／播放器／外觀／更新／帳號並核對各內容；compact 橫向分頁可捲到，面板幾何留在視窗內，關閉完成呼叫返回，再開回預設帳號頁。chat／player／update 使用正式控制器與 fake SharedPreferences，自動更新關閉，未點登入／登出／檢查更新／安裝／匯入（account calls=0、latest=null、checking／installing=false）。新增兩案與帳號錯誤防護、設定載入同範圍 13 項通過（2 秒、exit 0），唯一 analyze No issues found；未改正式程式。此為獨立 route harness 的設定面板，不代替首頁工具列完整入口、原生字體／選檔、增強效果或真人帳號操作。

- 帳號設定動作未處理例外已重現修正：正式設定 sheet 的登入／重新檢查／登出共用 _run 僅 try/finally，三個 fake action 失敗及離頁後晚到失敗，在 1000×760／390×844 八案皆向外拋 StateError。加 catch 與 mounted 防護，現行面板顯示通用友善提示、不洩漏原始錯誤，按鈕恢復可重試；已卸載不跳提示，OAuth／token 儲存及呼叫回呼不變。八個 widget 案與一個英文翻譯契約，加播放設定同範圍回歸共 27 通過（3 秒、exit 0），唯一 analyze No issues found。最初 close fixture 只換 MaterialApp.home 而保留 popup route，已改真正卸載 App，未以此判定正式 mounted 防護失效；英文映射有契約證據，不是英文整個頁面實機驗收。真實登入／登出、帳號切換及完整設定導航仍待驗。

- Drops 非空庫存領取八項隔離驗收通過：1000×760／390×844 各成功、GQL errors 後實際重試、離頁後成功／失敗。實際切庫存／展開遊戲／點獎勵，等待期間「領取中」按鈕停用且重複點擊不多發請求；失敗保留 ready 且僅第二次人工點擊重試，成功後庫存／活動各刷新一次、已領取按鈕停用；離頁後不刷新或新增通知。全部使用 fake Drops auth、Dio 攔截、Windows 平台 override 的 App 內通知，不真人領取或改 payload／hash／憑證。首輪 fixture 未等捲動及服務 microtasks、誤認 ElevatedButton 類型與成功後按鈕仍顯示但停用，修正測試前提後通過，正式程式未改。與空庫存／授權網址同範圍 23 項通過（3 秒、exit 0）；唯一 analyze 無 error／warning，1 info（原 guest 分支的 curly_braces_in_flow_control_structures，299:19）。活動詳情 Dialog 的領取入口、榜單及真實授權仍待驗；此批未驗證帳號切換或所有領取結果語意。

- Drops 頁小螢幕標題溢出已重現修正：390×844 的 guest 案固定 RenderFlex 向右溢出 252px，AppBar 標題 Row 的 Text 缺少彈性寬度。僅加 Expanded／單行 ellipsis，原字體、色彩與功能不變。新頁面十案（1000×760／390×844 各 guest、驗證失敗、空庫存三分頁、503 後點刷新恢復、讀取中按返回後晚到結果）與既有 Drops 授權網址五案合計 15 通過（1 秒、exit 0）；guest／驗證失敗未查 GQL，正常與重試僅查假的庫存／活動，claim=0。pending 案使用有限六幀完成返回動畫，不以 pumpAndSettle 等無限 spinner；關閉後不新增通知。僅正常單頁 route harness，不是首頁工具列入口／真人授權；非空活動、領取及榜單仍待驗。唯一 analyze 0 error、1 warning（新 docs 測試 setMockInitialValues 的 invalid_use_of_visible_for_testing_member，52:27），不重跑；後續動畫 fixture 修正僅有編譯／測試證據。

- 已登入追隨卡路由補測仍有清理失敗：1000×760／390×844 的 fake auth（viewer=42、follows／chat scopes）初始 following，實際點直播卡、掛載 guard／watch、正確 fixture_follow 頻道與同帳號、canSend=true、點返回保留首頁 State／following、回呼刷新一次及聊天室 disposeRuntime=1 均通過。Following 未傳首頁提供的 watch factories，首輪誤建原生播放器；已比照 browse 接上可選依賴，預設未提供 factory 的路徑不變。最新首頁／Following 回歸 74 通過、1 失敗（7 秒、exit 1）：寬畫面最後卸載首頁後留下 NativeSocket 的 250ms 計時器；窄畫面整案通過。identity client 攔截與 HttpOverrides 對照未解決，後者已撤回；不能宣稱背景網路全部隔離或清理修好，來源待定位，不持續重跑。API／IRC 使用假的身分與回應，未觸發模擬發言／写入；本批不含真人權限／原生播放驗收。唯一 analyze 無 error／warning、5 則既有 info（首頁 import、兩測試檔大括號及 super parameter），未重跑。

- 首頁直播卡完整隔離路由四項通過：1000×760／390×844 各實際點瀏覽直播卡與搜尋直播卡，掛載正式 guard／watch，再點觀看頁「返回」。選取頻道、同一 fake auth、guest readonly 與首頁 State／搜尋／browse 分區一致；返回保留狀態且既有回呼重新整理一次，watch 卸載、未觸發錄播解析。首次發現 StreamPage 的 watchServicesFactory／watchChatRuntimeFactory 僅媒體卡接上，直播 grid／sliver 卡忽略，測試因此誤建原生播放器而缺 DLL；補傳可選依賴至 Browse 與搜尋直播卡，未提供 factory 的正式預設路徑不變。這是隔離測試接線修復，不是已定位的使用者黑畫面原因。首頁／browse 同範圍 64 項回歸通過（6 秒、exit 0）；唯一 analyze 無 error／warning、2 則既有 info（首頁 import、原測試缺大括號）。播放器仍替身，真實直播解碼、其他完整入口與追隨卡的同依賴傳遞仍待驗。

- 觀看頁使用者資料入口六項隔離驗收通過：1000×760／390×844 各測訪客、假登入、官方資料 503 後重試。實際點聊天室名稱的文字範圍，開啟正式個人資料面板；選取 user-id=30 的請求及資料一致，訪客不做官方使用者／驗證請求且私訊停用；兩則本機紀錄可查看，關閉回到同一觀看頁／頻道，chat connect=1、send=0、寫入請求=0。觀看頁與 profile 同範圍回歸 94 項通過（12 秒、exit 0）。新增 fixture 先漏 resolvedBadges／emote forwarding 與平台 override 清理，補齊後通過，未修改正式程式。唯一 analyze 無 error／warning，3 則既有 info（兩則 use_super_parameters、一則 curly_braces_in_flow_control_structures）；本批不代表真實私訊開啟或原生播放完成。

- 帳號通知晚到操作已重現並修正：900×700 與 320×640 的四個隔離案例，在帳號切換後尚未重繪時點擊舊卡片，原先仍執行舊開啟動作；切換前已開始的動作晚到失敗，原先會向新帳號顯示失敗通知。overlay 現在以通知中心仍保留同一物件作為有效性判斷，拒絕已移除卡片的開啟，並忽略過期動作的錯誤提示。四項修正案例與通知 overlay／帳號／期限同範圍 23 項回歸通過。唯一 analyze 無 error／warning，測試檔既有 1 info（135:11 curly_braces_in_flow_control_structures）。此為假的帳號與 UI 操作；不能取消已開始動作的所有副作用，原生系統通知與背景行為仍待測。

- 2026-10-12 普通 VOD 切畫質保留暫停修復：highlight VOD 的 switchVodQuality 方法合約在暫停時重現 lastPlay 期望 false、實際 true，該分支同樣固定 play=true。改傳切換前 playing，原 duration／position clamp 邏輯不變；播放中／暫停兩案均保留 7 秒目標與相應播放旗標，同檔觀看頁回歸 72 項通過（12 秒，exit 0）。只改上層開檔旗標，未改底層 runtime、API payload 或真實帳號。

  測試由已成功載入的假剪輯頁面設定普通 VOD current-media 合約，再呼叫正式切換方法；不是普通 VOD 啟動、回放聊天、原生時間接續或 DVR archive 路徑驗收。此輪不啟動原生視窗，已有直播原生暫停切換證據保留、不重跑；原生錄播冷啟動仍待定位。唯一 analyze 兩檔無 error／warning、3 個既有 info。

- 2026-10-12 直播畫質切換保留暫停修復：player port 的 paused 方法案例重現 lastPlay 期望 false、實際 true；switchQuality 已取 wasPlaying，卻又與預設 play=true 做 OR，覆寫暫停。改直接傳 wasPlaying，播放器不存在時仍沿用呼叫端 play 的 fallback；播放中、暫停、無 player 時的播放／暫停四案及觀看頁同範圍回歸共 70 項通過（12 秒，exit 0）。只改上層 port 旗標，不改底層 runtime。

  修正後 Windows 原生本機 UI 案例通過：實際點 180p、暫停、點 360p，原生尺寸為 320×180／640×360；第二次換畫質仍 playing=false，觀察兩秒位置差 <500ms，按播放後再觀察兩秒前進 >1 秒。來源與按鈕值一致、選擇 2 次、對外請求 0，編譯 36.6 秒、測試 10 秒、exit 0，獨立視窗已結束。首輪原生案停在測試誤找 pause_rounded，改用正式 pause／play_arrow 圖示；不能把它當成原生修復前已重現。根因與修復前失敗來自 port 方法案例，原生提供修復後驗收。唯一 analyze 無 error／warning、11 個既有 info；Twitch HLS／所有解析度及錄播冷啟動仍另列待驗。

- 2026-10-12 剪輯切畫質保留暫停修復：正式觀看頁搭配成功的假剪輯解析與假 player session，播放中切畫質通過；暫停案重現 lastPlay 期望 false、實際 true，來源是 switchVodQuality 的剪輯分支固定 play=true。改傳切換前 player.state.playing，維持原位置參數。播放中／暫停兩案均保持 7 秒目標、選中變更與 resolver 僅 1 次；同檔觀看頁回歸 66 項通過（12 秒，exit 0）。只改上層開檔旗標，不改播放器底層、API payload 或憑證。

  本機原生錄播畫質案例仍未驗收：新增 TWITCH_READONLY_RECORDED_QUALITY，預期播放到 5 秒後低畫質切換、暫停時高畫質切換及 UI 恢復；實際編譯 34.2 秒、測試 46 秒，未通過初始解碼／Texture 門檻，position=0、playing=false、buffering=false，exit 1，沒有操作到畫質。停止重跑這個冷啟動；前述 mock 驗收不替代原生時間接續／暫停行為。唯一 analyze 三檔無 error／warning、11 個既有 info。原生視窗已結束，沒有對真實帳號寫入。

- 2026-10-12 Windows 本機畫質 UI 整合通過：既有正式觀看頁先解碼並掛載影片畫面，再提供兩個本機品質選項；合成滑鼠實際點 QualityButton 與 180p／360p 選單，經正式 player port／host 開檔。兩次來源 URI、按鈕選中值一致，原生解碼尺寸分別 320×180／640×360，各觀察兩秒位置前進 >1 秒；fake variant 切換恰好 2 次、對外請求 0、viewerId=null。編譯 34.9 秒、測試 8 秒、exit 0，獨立視窗已結束，未改正式 App。

  只替換 variant-to-local-file 的測試 runtime，不驗證 Twitch 清單解析／HLS proxy 或真實網路換源，也不宣稱錄播時間接續／逐幀與所有解析度通過。原生尺寸為換源證據，沒有追加每次換源的 Flutter 像素比對；音訊保持關閉、不重跑已驗收 PCM。前輪測試誤用不存在的 width getter、編譯失敗，改成固定樣本寬度後本輪編譯執行通過；不是正式畫質 bug 修復。本輪唯一 analyze 無 error／warning、8 個既有 info。

- 2026-10-12 Windows 本機原生音訊管線通過：沿用已成功解碼與 Texture 掛載的隔離觀看頁，停止舊影片後啟用音軌，透過正式 host 開啟本機 H264／PCM 測試影片；video height=360、音訊輸入／輸出皆 48,000 Hz，兩秒音訊時鐘增量 >1 秒、原生音量 20、media URI 正確，audio_decode_failed／audio_output_failed 皆 0、對外請求 0。最新編譯 33.9 秒、測試 5 秒、exit 0，獨立視窗已結束。未讀原帳號、不改正式 App 或原生 runtime。

  首輪已通過 PCM 參數與時鐘，但換片前在舊 AAC 影片啟用音軌，混入 89 個 audio_decode_failed、整輪 exit 1；補 stop 再啟用後錯誤為 0，僅修測試換片順序。此案例不重跑失敗的 AV 冷啟動，錄播初始化原因仍未確認；不是 Twitch AAC／HLS 音訊、實際喇叭／耳機聽覺或畫質 UI 驗收。唯一 analyze 無 error／warning、8 個既有 info；後補 stop 經編譯／執行驗證，未再次分析。

- 2026-10-12 聊天恢復失敗與重試修復：正式觀看頁搭配假 reconnect，回傳 runtime.error 的案原先沒有友善提示；拋例外、等待中換帳號、離頁後拋錯三案都會把錯誤往外傳遞。控制器改接住重連例外並檢查回傳錯誤，只有 generation、runtime、頻道及共用 viewer snapshot／status 仍一致時才提示；沿用已有中英翻譯的「聊天室暫時連線失敗，稍後再試。」。既有 finally 解除忙碌，不修改 IRC runtime 或憑證儲存。

  修正後四案通過：當前失敗提示可見、重試恰好第二次成功且不再忙碌，提示自然消失；換帳號／離頁後的舊失敗不提示也不漏出例外，聊天與管理寫入皆 0。兩檔同範圍完整回歸 123 項通過（12 秒，exit 0），唯一 analyze 無 error／warning、3 個既有 info。中途兩項 pending notice timer 是 fixture 未等 2.6 秒提示壽命，補有界等待後通過，未改正式提示元件。真實 OS 網路通知、Twitch 斷線／重連與播放器恢复仍待驗。

- 2026-10-12 聊天網路恢復身分防護修復：正式觀看頁搭配 fake runtime，先建立登入聊天室，切換假帳號或登出後再直接呼叫 chat controller 的網路恢復入口，原先兩案都錯誤呼叫舊 runtime.reconnect 一次（期望 0、實際 1）。重連前改核對共用 viewer session 與原連線 token；驗證中不重連，身分不同則走既有 connectChat，以目前帳號／訪客重新建立連線。未改 OAuth/token 儲存、IRC 協議或真人帳號。

  修正後重複恢復、checking、換帳號、登出四案通過：重複只重連一次，checking 不啟動舊連線，新帳號與訪客使用正確 fake token／runtime，聊天與管理寫入皆 0。觀看頁與 chat lifecycle 兩檔完整同範圍回歸 119 項通過（12 秒，exit 0），唯一 analyze 無 error／warning、3 個既有 info。這是正式頁面與控制器的隔離恢復驗收，尚未涵蓋 OS connectivity 通知、真實 Twitch 重连與播放器斷網恢復。

- 2026-10-12 訪客聊天入口與外觀失敗介面：正式觀看頁在預設寬版及 390×844 窄版實際點聊天室登入按鈕，進隔離登入頁、返回原頻道且 viewerId=null，仍唯讀、沒有 send 按鈕，預先保留的草稿不清除，聊天／帳號寫入皆 0。新增兩案与相鄰觀看入口共 17 項回歸通過（4 秒，exit 0），不操作真實帳號。

  正式外觀頁兩尺寸的語言／內建系統字體選擇各測 false／例外，失敗保留原選擇並顯示對應友善提示，重試保存第二次成功，重新載入一致；八個新 UI 案與相鄰外觀／控制器回歸共 17 項通過（3 秒，exit 0）。首次 fixture 沒重設全域語言控制器，後续字體提示斷言誤用一般設定文字，均只修測試。未修改正式 App、原生字體顯示或自訂匯入流程。唯一 analyze 無 error／warning、3 個既有 info。

- 2026-10-12 設定頁時間戳儲存失敗入口：正式 TwitchAppSettingsSheet 在 900×700、320×640 兩尺寸實際點聊天頁籤與時間戳開關；假儲存回傳 false 或拋例外時，控制器與可見 Switch 都維持原值，顯示通用提示且不暴露原始錯誤，重試恰好第二次保存成功，重新載入一致。四個新 UI 案例與原外觀／控制器回歸兩檔共 18 項通過（2 秒，exit 0）。首次失敗為測試誤找「聊天室」頁籤，正式名稱是「聊天」；只修 fixture 選取，未修改正式設定程式或真實偏好。其他設定失敗入口仍按各自範圍待驗。

  AV 最小初始化對照另 1 項通過：同一隔離服務與普通 runtime、不建立原生 Player 時，觀看頁可呼叫 clip loader 一次，明確 stopCurrentSession 重設亦在兩秒上限內成功；與原生視窗失敗形成差異，但仍不能確認根因或宣稱音訊／畫質已修復。本輪沒有重開視窗。唯一 analyze 無 error／warning、3 個既有 info。

- 2026-10-12 本機音訊／畫質的有界對照：在既有獨立 AV 測試新增明確 live mode，兩個本機 H264／PCM 48kHz 來源供實際畫質按鈕切換；原 recorded mode 保留，不以新分支代替錄播驗收。第一輪 Windows 編譯 33.1 秒、測試 11 秒，未開檔；再注入直接返回直播模型的 discovery，編譯 35 秒、測試 11 秒，仍未開檔，兩輪皆 exit 1。狀態均為 generation=1、loadingAuth=false、loadingWatch=false、offlinePlaceholder=true、playerError=null，沒有原生影片／音訊參數，也沒有非預期 playback API 呼叫。

  直接假直播資料未解決初始化，原因仍未確認；不能據此歸因音訊解碼、上游或正式 App。停止重開相同視窗，音訊／畫質保持待定位；下一步需不啟動原生視窗的最小初始化診斷，或繼續其他可驗證功能。唯一 analyze 無 error／warning、3 個既有 info；之後 discovery 注入由編譯驗證，未再分析。未修改正式 App，實際喇叭／耳機出聲仍未確認。

- 2026-10-12 Windows 訪客直播模式剪輯入口：使用既有本機影片、真實 Player／VideoController 及假 auth／資料，不讀原帳號。先通過解碼與 Flutter Texture 掛載門檻，再以合成滑鼠實際點 CreateClipButton，進隔離登入頁並核對三個 auth service；返回仍為原訪客頻道、同一 media URI，寫入與对外請求皆 0。編譯 39.8 秒、測試 3 秒、exit 0；獨立視窗已結束。這是正式直播模式入口搭配本機影片，不宣稱真實 Twitch 直播、剪輯建立或音訊通過。

  新旗標 TWITCH_READONLY_GUEST_CLIP_ENTRY 共用本機隔離啟動防護，拒絕遠端／首頁分支混用。先前無影片控制器的 fake pipeline 無法顯示正式直播控制列，已撤回，沒有修改正式 App。唯一 analyze 無 error／warning、8 個既有 info；只跑新入口，不重跑已驗收音量／全螢幕或原黑畫面。

- 2026-10-12 訪客觀看頁入口：實際訂閱按鈕進隔離 TwitchLinkedLoginPage，核對三個 auth service 都是 fixture；返回保留原頻道、viewerId=null 與唯讀聊天，追隨 calls、聊天 sends、非讀取 HTTP／GQL mutation 請求計數皆 0。離線頻道的建立剪輯按鈕 onPressed=null，實際點擊不進登入、不寫入；這是正確離線限制，不是直播訪客剪輯入口已驗收。相關追隨／點數／入口 15 項回歸通過（5 秒，exit 0），未修改正式 App。

  首次停用播放器的測試設定隱藏整個控制列，改回原 fake player fixture。整檔首輪 52 通過／1 失敗，唯一失敗是新增離線案例漏清平台 override；補清理後只重跑同範圍 15 項，不追認整檔全通過。前輪管理測試補 mounted guard，唯一 analyze 無 error／warning、3 個既有 info，兩個新增 BuildContext 提示已消除。直播中訪客剪輯、其他快捷路由與真實登入流程仍待驗。

- 2026-10-12 管理確認框跨頻道：從觀看頁實際聊天身分與管理入口開清除確認框，再以 Navigator.replace 替換下層觀看路由、保留既有確認框。新假頻道與新 chat runtime 掛載、舊觀看頁卸載及舊 runtime 釋放一次；按舊確認框後兩個 client 的 DELETE 合計 0、失權提示可見，關閉管理面板後仍是新頻道，聊天送出為 0。新案例與相鄰送出／管理回歸共 16 項通過（4 秒，exit 0），正式程式未修改。這是受控路由替換，不代表側欄換台手勢或真人連線驗證。

  首輪測試錯把 runtime 釋放當 disconnect 計數，改核對 disposeRuntime，使用真正非同步等待且上限 2 秒；未修改正式斷線邏輯。唯一 analyze 無 error／warning、5 個 info，其中 2 個為新測試的跨非同步 BuildContext 提示，下一輪補 mounted guard；其餘 3 個為既有提示。

- 2026-10-12 觀看頁管理確認框換帳號：從實際聊天身分按鈕、管理員工具入口、清除聊天室按鈕開確認框，切換假帳號後按確認，DELETE 為 0、顯示失權提示；舊 API 無效，關閉管理面板後原觀看頁與頻道仍存在，聊天送出為 0。新案例及相鄰普通／特殊送出、管理失權／換帳號回歸共 15 項通過（3 秒，exit 0）。所有 HTTP 都由 fixture 攔截，播放器停用，不真人管理或發言；跨頻道管理、真人重連仍待驗。

  入口首次失敗是 fixture 缺少 IRC 顏色 getter，補成只允許讀顏色的 fake；接著正式管理 ListTile 重現底色遮住 Material 水波紋的框架警告，僅在該 ListTile 補透明 Material，未更動樣式與權限。後續測試修正為捲動面板清單而非文字輸入框、捲回查看失權提示，以及等待退場動畫，不把測試選取／等待失敗當正式權限問題。唯一 analyze 無 error／warning，3 個既有 info。

- 2026-10-12 本機音訊與畫質測試待定位：獨立 Windows 測試尚未呼叫 clip resolver（0 次），沒有影片或音訊參數，初始化原因未確認；不據此歸因解碼器或正式 App 黑畫面。保留新測試診斷，不繼續重跑相同初始化；音訊輸出、畫質切換均未驗收，使用者亦未確認實際聽到測試音。

- 2026-10-12 Windows 本機原生控制驗收收尾：使用者允許獨立測試視窗後，最新編譯 36 秒、測試 8 秒，完整 exit 0。實際控制列音量套用、靜音／取消靜音恢復原值、全螢幕進出均通過；同時核對 windowManager 的 OS 全螢幕狀態，播放前進斷言及原生／Flutter 影片像素通過。對外網路請求為 0，假訪客與隔離偏好，不操作原帳號。測試視窗已結束。

  前幾輪失敗保留：測試只找窄版音量元件；寬版套用後 UI／原生 volume property 都為 18.636364、stream 快照仍為 100，改核對實際 property；取消靜音前漏等按鈕重畫，補 pump。這些只改測試，不據此宣稱正式播放器 bug 已修。原影片只有 2.8 秒，播放觀察與像素驗證前重新開始本機影片，不當作直播長測或 UI 拖曳證據。影片 aid=no，實際出聲、畫質切換、Twitch 直播／DVR 穩定性仍待驗。此回合唯一分析無 error／warning、8 個既有 info。

- 2026-10-12 最新收尾與原生執行條件：管理重連等待以最小對照確認兩種 Stream 的 cancel 都不能只靠 fake-frame pump 完成，runAsync 下皆完成；此現象不是 Stream.empty 特有，未據此修改正式連線邏輯。觀看頁同一換帳號案例改用 runAsync、兩秒上限，假新帳號恢復管理且舊 API 仍失效，觀看頁加對照兩檔 50 項通過，分析 3 個既有 info。下注觀看頁卡片開面板／點外部返回加 launcher 回歸 12 項通過；面板背景刷新成功未包含在此入口案例。Hype 自然到期與退場加既有動畫／參與者全檔 8 項通過，分析 No issues found。

- 2026-10-12 字體清單保存與移除：四筆資料的 false／例外均曾忽略或先改狀態，移除甚至先刪字體檔；改多筆保存失敗回復、成功才移除檔案，匯入失敗清除本次副本與記憶體項目，保留來源。隔離匯入／移除 16 個失敗案例加既有字體回歸共 23 項通過；後續只補兩處大括號，一次局部分析 No issues found。未驗證回復保存再次失敗、原生引擎載入與所有介面錯誤入口。

- 2026-10-12 原生控制測試準備：新增 TWITCH_READONLY_NATIVE_CONTROLS，限定 TWITCH_READONLY_GUEST_SURFACE 的本機影片／假訪客，測音量數值、靜音／恢復、原生全螢幕進出與三秒播放前進；影片 aid=no，不包含實際出聲或畫質。啟動前防護拒絕單開旗標或混入遠端／首頁網路分支，5 項純旗標測試通過；整合檔分析無 error／warning、8 個既有 info。原生分支尚未執行，等待獨立測試視窗許可，不能算通過。裝置盤點目前只有 Windows／瀏覽器，無手機／平板；原黑畫面保持待定位，不重跑同樣對照。

- 2026-10-12 字體與聊天外觀：字體匯入忽略載入失敗，改保留原選擇、移除失敗項目並刪除本次匯入副本，來源不刪；假選檔、臨時目錄與假引擎載入的匯入／缺檔回歸 3 項通過，非原生字體顯示證據。字體與語言選擇保存失敗改保留原值並提示，相關 9 項通過。聊天外觀六操作在 false／例外後保留原值與連結政策，依序保存不丟兩筆網域新增、失敗保留输入，相關三檔 16 項通過；最後分析無 error／warning、有兩個大括號 info。本輪只補大括號，不重跑功能案例。

- 2026-10-12 剪輯與訂閱初始化：剪輯播放器建立失敗原為未接住例外且停留載入，補通用錯誤與重新初始化；兩尺寸初始失敗／離頁後失敗及服务回歸共 9 項通過，未建立 Player，未驗證成功播放或原生清理。訂閱 FutureBuilder 原忽略準備失敗，仍建立頁面；補失敗時停止建立頁面並提示。兩尺寸準備成功／失敗／關閉後晚到結果／返回加 API 回歸共 13 項通過；準備與頁面都是假依賴，不讀憑證、不建立付款 WebView。兩批各一次 analyze No issues found，原生完整流程仍待測。

- 2026-10-12 活動與設定案例收尾：claim 在送出後換頻道，晚到成功／失敗不刷新新頻道、不顯示舊結果；相關三檔 65 項通過。Hype 兩尺寸共享參與者替換、空顯示名稱回退 login、升級動畫退場與清除通過，全檔 6 項。原兩項動畫失敗是測試漏等 AnimatedSwitcher 的 200ms 淡出，補等待並核對已切回進度，不改正式動畫。

- 2026-10-12 播放設定儲存失敗：聊天室與 Android 子母畫面開關先更新記憶體、忽略 false，例外也缺介面提示；改成功才更新、失敗 reload 快取。音量／靜音先更新及兩筆部分保存問題已重現，改依序保存、失敗回復原偏好，介面顯示通用提示。畫面增強五種偏好原忽略 false 並先更新 runtime config；保存成功才更新 config，失敗回復五筆資料，控制器回到已保存值並解除忙碌。重設加入音量／靜音與增強失敗回復，與音量操作共用依序保存。未改解碼、播放器開檔或著色器套用邏輯。

  最新增強失敗 14 項通過，含非預設增強值的重設、false／例外、重試與 reload；同範圍三檔回歸 39 項通過，其後只加強重設初值的同檔 14 項再通過，不重複累加。相關五檔 analyze No issues found。皆為隔離偏好、player=null，未寫使用者設定；控制器／儲存證據不替代原生效果或所有介面失敗入口。回復寫入本身再次失敗仍未驗證，不能保證多筆資料在任何故障下皆原子化。

- 2026-10-12 近期完整入口驗收更新：觀看頁實際點數按鈕搭配 fake runtime，修正正式 port 成功沒有 displayResult 時缺完成面板；launcher 使用開面板時的共用身分 snapshot，假登出或切換另一個已驗證帳號即拒絕舊面板，新帳號重開可正常兌換。管理入口換帳號後，舊 MOD runtime 不能維持資格、舊 API DELETE 在傳輸前拒絕；新帳號重新連線的 fixture 等待未定位，不宣稱恢復管理已驗收。側欄點選在 Navigator observer 攔截新路由，核對 login、streamId、title、discovery 與舊聊天室斷線一次；新頁未建立 Player／client／storage。最後觀看頁加 rail 元件兩檔 61 項通過，分析 3 個既有 info；不同批次測試數不累加成完成總數。

- 2026-10-12 設定與通知修復收尾：小窗開關原在儲存 false／例外時仍改記憶體，且重試同值被略過；改成功後更新、失敗 reload 快取並保留原值，設定頁顯示通用提示，兩尺寸四失敗案例及設定回歸 9 項通過。自訂字體缺檔原被吞錯並標示已套用；恢復退回內建、重新選取失敗保留原選擇，相關四檔 11 項通過。通知面板 owner 切換兩尺寸通過；首頁假登出仍留舊帳號通知已重現，清除 owner 改接共用 guest 身分事件，保留一般通知，home／overlay／account 三檔 53 項通過。以上都是隔離儲存／帳號，不動真實偏好與憑證；正常字體檔匯入、系統通知與背景仍待原生驗證。

- 2026-10-12 真實匿名公開讀取：啟用 twitch_guest_media_test 的 TWITCH_GUEST_LIVE_TEST，兩個真人網路案例一次通過：瀏覽／分頁／搜尋／當前直播／分類，以及四個公開頻道 VOD、剪輯與頭像。每個請求檢查沒有 Authorization／Cookie，無帳號儲存載入；全檔 5 項通過，其中另 3 項為 mock。分析 No issues found，正式服務未改。此證據只覆蓋匿名 API 讀取，不宣稱 App 訪客全路由、DVR、VOD／剪輯解碼或真人帳號權限完成。

- 2026-10-12 驗收狀態整理：claim 重按曾在等待中發出兩次，領取按鈕補局部請求中狀態，finally 且 mounted 時解鎖；兩尺寸重按／失敗後重試通過。貼圖清單第一次 fake 載入失敗只顯示通用提示、無 raw error，重新載入成功後只兌換一次，兩尺寸通過；最後相關三檔回歸 61 項、analyze No issues found。觀看頁另有 checking gate 證明追隨／訂閱／剪輯回呼驗證中為 null、放行後正常追隨；Navigator 替換為不同 channelId 後舊取消追隨成功／失敗不改新頻道已追隨標記、不提示或寫入新 API。這些是前輪證據，本輪只核對現行案例與接線、更新紀錄，沒有重跑測試；側欄實際換台及原生流程仍未完成。

- 2026-10-12 點數文字、貼圖與領取流程驗收：正式 launcher→sheet 搭配 fake engagement port，900×700／320×640。文字獎勵只建立 pending，不直接兌換；取消零 pending，換頻道後舊獎勵不掛到新草稿。一般兌換曾把舊獎勵送往新 snapshot 的頻道 ID，launcher 已在文字準備／兌換前核對面板開啟時的 login、id、snapshot channelId。選擇貼圖成功曾丟棄結果，過期來源錯誤曾未處理；sheet 補完成面板及通用錯誤提示。修改貼圖先選 base／效果，確認前零呼叫，fake port 核對最終 modified emoteId 與 modifierId，取消／過期零寫入，未改 payload。

  本輪 claim 正常成功通過，但 API ok=false 仍刷新、例外無提示、換頻道仍送舊 claim，在兩尺寸各重現。launcher 補送出前來源防護、核對 ok，失敗只顯示「領取點數失敗，請稍後再試。」並只記 error type；成功才刷新。points sheet flow、reward UI、prediction launcher 三檔共 55 項通過；唯一 analyze No issues found，diff check 通過。這是隔離面板接線，不是完整 watch 帳號切換或真人 API；claim 重按／重試、送出後晚到結果、貼圖來源載入失敗／重試仍待驗證，不以這批結果宣稱點數全功能完成。

- 2026-10-12 觀看頁追隨按鈕修復與訪客導頁驗收：正式頁面搭配 fake relationship API，追隨／取消／拒絕／等待中假登出四案原皆未顯示忙碌狀態；控制器已擋重複寫入，但觀看頁漏傳 followBusy。補該欄位後按鈕等待時 busy=true，成功更新標記、拒絕保留標記、假登出後舊成功不提示。另補訪客實際點追隨→TwitchLinkedLoginPage→取消返回，核對三個 auth service 都是原隔離服務，返回後仍唯讀訪客，零 follow／unfollow 呼叫。本輪頁面單檔 40 項通過；初版 fixture 曾使用不存在的 getter、未及時還原 platform override／消耗提示計時器，修正測試清理後通過，未為此改正式行為。唯一分析無 error／warning、3 個既有 info。本輪只增訪客測試，正式 followBusy 修正為上一輪；無真人 OAuth／寫入／原生播放。此五案收尾，跨頻道路由、驗證中入口與真實 API 權限仍待驗。

- 2026-10-12 取消追隨控制器驗收：正式 relationship controller 搭配 gated fake port，新增成功、拒絕、等待中換 viewer、等待中換 channel 四案；每案連按兩次只呼叫一次 unfollow，核對原 channel login／id／viewer。僅目前成功改為未追隨、清 followedAt 並提示；拒絕保留追隨狀態並顯示通用提示，過期成功不套用或提示，所有完成後均解除 busy。單檔 22 項通過，正式程式未改，未呼叫真實 API。此控制器分支收尾；完整觀看頁按鈕、確認／路由及真實權限仍待驗證，不以控制器結果代替完整頁面。

- 2026-10-12 管理入口不再依賴 IRC 發言權限：正式 watch 的 canManageChat 原使用 canSendForCurrentViewer，已登入 MOD 缺 chat:edit 時入口為 false，新增 moderator-no-chat-edit 頁面案例穩定失敗。chat controller 公開 hasCurrentViewer（沿用目前 viewer／connected token／generation readiness），管理入口改用該身分門檻加原角色判定，實際管理 scope 仍由原 API 驗證；不改 token 儲存或發送協議。依 [Twitch 刪除訊息授權文件](https://dev.twitch.tv/docs/api/reference/#delete-chat-messages)，管理 scope 與 IRC 發言 scope 分開。修後 watch／role actions／user profile／message actions 四檔76項通過，包含假登出後 canManageChat 與已建立 API 的 canModerate 皆 false。首輪修後唯一失敗是 fixture 已登出卻仍期待登入缺權限文案，調整斷言順序後通過。本輪再補既有五組 IRC scope 案例：初始化前及 disposeRuntime 後 hasCurrentViewer=false，就緒後 true，發言仍按原 scope 拒絕；5項通過。此身分／發言權限分離案例收尾，無真人管理操作，不等於管理 HTTP 全 scope 或完整使用者資訊路由驗收。唯一分析無 error／warning、8項既有測試風格 info。

- 2026-10-12 訪客 AutoMod 佇列接線修復：補同panel明確readOnlyGuest=true但仍保留舊mod API／角色資料的widget斷言，configured true／false兩案原皆仍掛載TwitchAutomodQueueStrip而失敗；不是已證明顯示真人私人紀錄。正式panel只在非明確guest且有API時建立strip，guest切換使舊strip卸載；一般聊天及使用者資訊不動。相同兩案修後通過，watch keyboard／AutoMod queue／AutoMod settings／guest四檔39項全過，唯一analyze No issues found。此管理佇列元件入口案例收尾，沒有真人接收／管理寫入，不冒充所有使用者資訊／訊息選單的管理動作或完整帳號路由完成。

- 2026-10-12 訪客管理快捷入口防護修復：既有 keyboard／permission／guest 四檔31項全過，但新同panel由readOnlyGuest=false→true、仍留舊viewerId／mod runtime及canModerate=true時，message area／feed gate原仍true，configured案失敗。正式panel快捷gate及eligible派送兩處優先拒絕明確guest旗標，不改mod API／IRC；補直接callback不能開確認，再切回false仍保留既有授權確認、失權後拒絕、文字焦點不誤觸等案例。修後四檔31項通過，最後把測試還原guest旗標的時序明確移到拒絕斷言後，單檔6項通過；不重複累加。此殘留角色資料快捷繞過案例收尾，沒有真人管理寫入，不冒充完整watch route帳號切換或其他管理面板入口已驗收。

- 2026-10-12 播放設定與畫質控制隔離驗收：新增900×700／320×640正式 App settings sheet→播放器tab，mock SharedPreferences、正式 player settings controller，實際 Slider／Switch 修改音量、靜音、預設聊天室與保留小窗；新 controller load核對相同保存值，帳號／更新操作均禁止。連既有 quality menu、player control layout、audio settings 四檔31項全過，正式程式未改。Windows platform override只讓設定頁避開Android原生背景卡，不是實機；未開Player、未動原偏好。此預設保存與既有畫質選單回呼案例收尾，不冒充真實串流畫質切換、全螢幕／音訊輸出、影片增強或效能驗收。

- 2026-10-12 點數 sheet 整頁與 launcher 接線隔離驗收：先將detail回呼catch改對應context.mounted，解前輪新增async context info。新增900×700／320×640各成功／fake API拒絕／未知餘額六案，正式launcher→modal sheet→reward grid→detail→redeem port；核對channelId、reward id／cost、無輸入payload原值，成功只刷新一次並顯示完成pane，失敗只一通用showMessage、零刷新／完成pane、raw error不顯示。首輪unknown誤期待不能開detail，實際仍可唯讀查看，改測允許detail、兌換button.disabled＋零callback，不修改正常browse行為。三檔sheet flow／detail UI／下注launcher共24項全過，唯一analyze No issues found。此普通無輸入reward整頁案例收尾，不冒充完整watch登入／跨帳號、文字準備／貼圖選擇／claim流程或真人兌換；除了context提示修正，未另改正式功能。

- 2026-10-12 點數獎勵詳情不可用／失敗修復：兩尺寸900×700／320×640各unknown balance／insufficient／paused／success／failure十案。原unknown仍允許兌換、fake回呼失敗拋未處理例外且零通用提示，共四失敗；availability helper 改未知餘額不可兌換，detail button catch 只在mounted時通用提示並在finally解busy；watch launcher原catch吞錯只debug，補showMessage並僅記錄error type，不更改任何兌換payload。相同十案修後通過，等待中重按只有一次callback，正常流程仍可完成；連下注launcher／points auth／watch四檔53項通過。detail測試不冒充整個reward grid／文字或貼圖輸入流程，launcher提示是接線尚無專屬端到端失敗案；沒有真人兌換。唯一analyze無error／warning、1項新context async gap info（detail widget:576），下一輪改成對應BuildContext存活檢查，不重跑分析。本unknown／拋錯案例達驗收，仍保留整頁與路由失效限制。

- 2026-10-12 觀看頁下注回呼本機門檻修復：實際 sheetLauncher.placePredictionBet 原無餘額檢查，只有賭盤存在即呼叫 engagement；新假 port 的未知／0／9餘額下注10三案失敗，剛好10正向通過。正式 launcher 新 required canPlacePredictionBet 由 watch 共用 viewer session authenticated＋mounted 接線，拒絕訪客／驗證未就緒；點數 context 必須成功、對應當前 login／channelId，點數正整數且不超過已知balance。下注 mutation／payload、token儲存與API授權不改。新未登入×四餘額八案皆通過，連下注sheet與完整隔離watch回歸46項通過，未真人下注。此本機拒絕案例收尾；fake predicate 不冒充完整觀看頁 guest→logged-in 下注手勢、same-viewer token切換或餘額即時性；伺服器仍需最新授權／餘額核對。唯一 analyze無error／warning，1項既有watch if大括號info，未重跑。

- 2026-10-12 正式預測下注 sheet 隔離驗收：900×700／320×640，各正常成功／fake下注失敗／選擇後 realtime LOCKED 六案。注入 onRefreshPrediction 返回 null、onBet gated callback，不建立 Hermes runtime 或網路；0點數零callback且提示、50點送出一次、等待中 button.disabled阻止重按；成功切加注並保留viewer choice，失敗保留50輸入、通用提示且不顯示fixture raw error；LOCKED無確認按鈕／零下注。六新增案全過，正式程式未改，此基本sheet案例收尾。頁面不接餘額，餘額驗證在watch onBet回呼，不能把本輪當餘額不足／未知餘額、訪客權限或完整觀看頁接線完成；下一項檢查該回呼，不真人下注。

- 2026-10-12 更新 sheet 完整隔離流程：新增900×700／320×640兩案，正式 showVioClassUpdateSheet＋controller、fake service／installer。檢查失敗顯示通用狀態而不暴露 fixture raw error、明確 retry 等待中按鈕禁用／只兩次檢查、找到新版、fake下載失敗零install、再次點擊成功只一次fake install且busy釋放；File僅假路徑物件，沒有任何建立／下載／讀取／process或替换App。連controller兩檔11項全過，正式程式未改；此頁面案例收尾，不當成OS安裝成功。同步補最新案例摘要，保留完整矩陣／未完成範圍，避免反覆測已收尾案例。

- 2026-10-12 設定載入重疊與聯合登入隔離回歸：新增 language.load＋select(en)、appearance.load＋setFontScale(1.3) 兩同步起始案例，mock 偏好載入及新 controller 重讀皆保留選擇，未重現覆蓋，不改正式程式、不擴張任意延遲測試。連 appearance UI、既有 Drops callback URL 與 linked cached identity 四檔19項全過，涵蓋既有精確 redirect／grant 與 denied、狀態 URL 不展示 credential、快取 identity 暫時失敗保持、401／403 拒絕及卸載後晚到結果。全為 mock／純 URI，未真人 OAuth、未寫原憑證；唯一 analyze 新檔 No issues found。此兩種設定交錯案例收尾，不當成任意平台儲存延遲／失敗或 Drops 端到端授權通過。

- 2026-10-12 剪輯編輯服務空錯誤陣列相容性修復：頁面仍直接 Player.create／VideoController.create，訂閱頁直接 WebView 與讀 stored Web token；本輪不操作真人元件、不更動憑證、不把服務層冒充頁面驗收。新 fake post 五案，帶可用 data 及 errors:[] 的 CreateRawMedia／Finalize／RenderStatus 原皆拋例外（三失敗），與既有 persisted result 的空 errors 判定不一致。正式 _clipGql 只對非空 List 或非 List errors 拒絕，原 hash、發布 payload、重試上限與 token providers 不改。準備素材／slug 解析、CREATED 且有 source 才 ready、缺來源／缺 raw token 零請求、非空 errors 零自動重試通過；連前輪 create／subscribe service 共12項全過，唯一 analyze No issues found。此相容性問題收尾，未證明 Twitch 實際曾回傳 errors:[]、未結案原生播放／剪輯時間軸或訂閱 WebView；頁面須安全的可替換依賴或另行裝置驗收，仍保留未完成。

- 2026-10-12 Clip／訂閱目的地服務隔離驗收：新增 clip fake postJson 七案中的五案（無 OAuth／無 broadcaster 零寫入、正常一次假 Helix write 與目的地解析、三種缺／空 id 拒絕、失敗保留原例外且只有明確重試再寫一次），禁止 raw-media provider 被呼叫。訂閱兩案以 overridden external opener 收集 URI，正確 normalize 指定 login 至官方 /subs、空 login 零 opener，不開瀏覽器或付款。新單檔7項＋relationship18項共25項全過，正式程式未改。服務層基本驗收收尾，不等於實際 clips:edit／OAuth、剪輯 editor raw-media／時間軸／發布、訂閱 WebView／登入付款或完整頁面入口；下一项仍為頁面接線，不把這兩列標全完成。

- 2026-10-12 追隨關聯回應上下文修復：原 controller 只有 reset／dispose generation 防護；新增 refresh／toggle×換 login／viewerId×舊成功／失敗八案，不呼叫 reset，全失敗（舊狀態／resolved channel callback／失敗提示仍套用）。正式 controller 捕獲 targetId／viewerId，發送與套用／錯誤前核對 generation、目前 login、channelId、viewerId；使用捕獲的請求參數，不改追隨 API／憑證。相同八案修後通過，三檔 relationship／watch／home 回歸87項通過；後補正常讀取／fake追隨兩正向案，relationship單檔18項通過，不重複累加成全批89。唯一 analyze No issues found；此過期回應案例收尾。全假 port、不真人追隨／取消，沒有以 controller 門檻冒充完整 OAuth、取消追隨、訂閱或建立剪輯入口驗收；後三者仍待測。

- 2026-10-12 公開搜尋與媒體來源替換隔離驗收：既有 home／channel media／guest media 三檔 64 過、2 跳過；新增 VOD／clip 等待中更換 discoveryService，各舊成功／失敗四案，新資料保持、舊卡／舊錯誤不顯示、新來源零額外請求。最終 68 過、2 跳過（TWITCH_GUEST_LIVE_TEST 未啟用的真實訪客網路案例），不把 skip 計入完成；既有 first-page UI 重試、pagination 原 prefix／cursor 重試、空搜尋清除、重复 ID、卸載及首頁搜尋 supersede 的同範圍證據保留。正式程式未改，不操作現有 App／真人憑證；唯一 analyze 無 error／warning、1項既有 public helper/private type info。此來源替換案例收尾，真實網路／媒體播放與更多入口限制保留。

- 2026-10-12 通知 overlay 晚到失敗修復：假偏好與通知中心、TargetPlatform.linux override 避開 Windows frame native methods，正式 overlay 五新增案（開啟成功／失敗／卸載後失敗、900×700／320×640面板已讀與清除）。原卸載後 action failure 仍新增全域警告，零舊警告斷言失敗；正式 overlay 在 action／whisper catch 通知前檢查 mounted，正常失敗保持通用提示、不顯示 fixture 原始錯誤。首輪另有 fixture 平台旗標清理太晚、第二輪正常警告 dismiss timer 留到測試 invariant；改 test body 卸載後清假中心與恢復旗標，不改正式計時器。最終 overlay／policy／expiry／style／account 五檔 52 項全過。action catch 同案例已验收收尾，whisper guard 只接線未做真人或專屬分支驗收；不宣稱 Windows titlebar／原生通知權限、帳號換身分導頁或網路回復完成。

- 2026-10-12 外觀與聊天設定頁基本流程隔離驗收：SharedPreferences mock、正式 settings sheet＋語言／字體 controller，900×700 與320×640 同一測試 zone。實際切外觀、English 後頁面變英文、選 System font、聊天 Slider 拖動改 scale、Switch 開時間戳；卸載後新 language／font／appearance controller 從假儲存載入相同值。窄畫面首輪直點位於橫向捲動外的 tab 失敗，修 fixture 先 ensureVisible／hitTestable，不改正式 UI。連既有 App 鍵盤與鍵位設定三檔 7 項全過，不修改正式程式，不讀寫 host 偏好、不進播放器／更新／帳號操作。此正常保存與基本頁面接線收尾；尚非實際重啟 App、匯入自訂字體、儲存失敗／載入競態或全樣式矩陣。

- 2026-10-12 Hype Train widget 隔離驗收：新增 model 進度負值／超額／零 goal 邊界及 ended 不啟用、三個尺寸（900×700／320×640／844×290，後兩者 2×字體）banner＋details 正式元件。fake API 經正式 controller 更新 level3→4／25%→60%，details 原 25／100、捲動存在空參與者資料，clear 後 banner 隱藏，卸載後无異常。四新增項通過，不修改正式程式；無真人活動、Hermes／網路或寫入，reduced-motion=true，不冒充升級動畫、自然到期動畫、黃金／共享參與者或完整 watch 頁面接線。此基本活動進度與多尺寸呈現案例收尾。

- 2026-10-12 預測／Hype API 錯誤與無活動隔離驗收：新 fake persisted single 六案，prediction GQL errors 原被 fromRawResponse 解析成成功空模型，穩定失敗；正式 prediction 在解析／bus publish 前核對 hasErrors、拋固定 StateError，不改 hash／query／下注 payload。正常無活動、count 0→1／99→10、空 login 零請求、Hype GQL 拒絕通過；Hype 無活動原回非啟用空模型，首輪 null 斷言不符合既有 fromDynamic 契約，改驗 isActive=false／空 id，不修改 Hype 正式程式。四檔 API／engagement lifecycle／points auth／watch page 回歸 45 項全過；唯一 analyze No issues found。沒有真人網路／下注／兌換，也未建立 Hermes；此誤把拒絕當空預測問題收尾，活動進度／裝飾／UI 與各自真人 API 權限仍待驗。

- 2026-10-12 engagement 刷新上下文修復：新增正式 controller＋gated fake port／無網路 Hype controller 四案。正常載入通過，但同 login 兩刷新反向完成時舊 pins 蓋新、reset 後舊結果再觸發 Hype refresh、viewerId 變更後套用舊 pins 三案穩定失敗。正式 controller 增 refresh serial、reset 使舊 serial 失效，套用前核對 login／channelId／viewerId；不改點數、預測、GQL、payload 或 token。修後相同四案通過，連 points auth／pin management／watch page 四檔回歸 47 項全過。新 fixture channelId=null、不建立 Hermes，Hype refresh 純 mock；證據為共享資料套用防護，不冒充三種 engagement 真實內容、下注／兌換、同 viewerId 的 token 變更或真實網路。此亂序／reset／viewer 過期結果問題收尾，獨立預測及 Hype API 仍待驗。

- 2026-10-12 管理紀錄載入失效隔離驗收：既有 controller／panel／API／EventSub／entry／archive 六檔 56 項通過；新增已保存舊紀錄的讀取 gate，讀取中 stop／撤權／換 owner+channel 三案，舊紀錄不顯示、舊 receiver 不再安裝，切換只開新 receiver，原分區資料保留。首輪切換案 30 秒逾時，原因是 fixture 等新 archive.load 完成才放行排在前面的舊 load；正式 archive 有共用序列佇列。改測試先發起切換、再放行舊讀取並等待兩者，不改正式程式、不放寬資料隔離斷言。修正 fixture 後六檔 59 項全過，此載入失效案例收尾。未操作真實 EventSub／帳號、未讀寫使用者管理紀錄；完整 watch 路由接線與真實網路仍另列限制。

- 2026-10-12 管理確認上下文失效修復：五份既有 message actions／moderation sheet／batch panel／user batch panel／pin management 隔離測試 80 項通過。新增確認視窗等待中重建同 widget、更換 API instance 或 channelName 的兩案，權限仍 true、訊息 ID 相同；原程式均仍呼叫舊 delete API，兩案失敗。正式 message actions 在確認後、寫入前核對目前 canModerate、API instance 及 channelName，失效時拒絕並提示，不改任何 API payload。相同兩案修後零舊／新 API 寫入，五檔回歸 82 項全過；全為 fake API，沒有真人管理。此確認前更換上下文問題收尾，不冒充完整 watch 帳號／頻道路由整合、送出後晚到結果或所有管理功能完成。

- 2026-10-12 特殊訊息失敗提示修復：正式頁面 special-failure 新期望通用提示，原程式零提示而穩定失敗；controller 特殊送出 catch 僅在 generation／runtime／身分／pending 仍有效時顯示「特殊訊息送出失敗，請稍後再試。」，然後 rethrow 保留原例外。頁面保留草稿且不顯示 fixture 原始拒絕內容；點數／watch streak／resub 的有效失敗提示與舊失敗不提示已有隔離斷言。兩檔回歸 91 項全過。補完前輪另列的缺提示問題，本案例收尾，不以此宣稱所有特殊 API 權限或真人網路已驗收，不再延伸同一提示問題。

- 2026-10-12 正式觀看頁特殊訊息草稿修復：既有普通送出頁面 fixture 加 mock watch streak runtime，經實際 send 按鈕驗證特殊成功／拒絕／新草稿／fake logout／unmount／送出前取消六案。首輪十二個頁面送出案例十一過、一失敗：notify 中取消 pending、特殊 API 零呼叫，頁面卻清空原草稿。正式 controller 的 sendMessage／sendPendingSpecialMessage 回傳是否完成送出的 bool，拒絕／過期／未送出回 false，頁面只對 true 且原身分／runtime／草稿仍一致時清除。兩檔回歸 91 項全過，包含原普通 send、特殊控制器與完整隔離觀看頁。此取消誤清問題收尾；mock 拒絕保留草稿，但特殊失敗的使用者提示仍只有 debug type 記錄、未在本輪新增，另列待處理。未發送真人訊息、不改協議／payload／憑證、不操作執行中的 App。

- 2026-10-12 更新 prerelease 排序修復：原比較忽略全部後綴，五新增排序案有四案失敗（beta.2／beta.10、RC／正式版、beta／RC、短／長識別序列）；依 https://semver.org/#spec-item-11 補正式版高於同版 prerelease、數字／字串識別及序列長度比较，忽略 build metadata，保留既有核心版本比較與 GitHub endpoint／下載規則。相同案例修後通過，beta service 17 項、stable service 10 項全過；全部攔截 HTTP、不下載或安裝 App。此排序案例收尾，非法版本標籤政策、真實下載與更新 UI／OS 安裝仍不是本輪證據。

- 2026-10-12 新舊特殊送出重疊驗收：舊 mock reward 等待中 disposeRuntime＋connectChat，同 controller 新 pending 開始第二次送出；放行舊成功／原 StateError，兩案皆保留新 sending=true／pending，零舊提示／刷新／通知；放行新結果後才正常解鎖、清 pending、提示且刷新一次。lifecycle 單檔 59 項全過，不修改正式聊天程式。特殊訊息 controller 目前這批生命週期案例收尾，完整 UI 草稿、特殊 API 真實權限及網路整合仍待驗。

- 2026-10-12 watch streak／resub 控制器分支隔離驗收：各自正常成功／API result.ok=false，以及 controller dispose 後晚到成功／拒絕，共八新增案；驗證對應方法、原 payload 物件、channelId fallback、viewerId 與文字，成功提示內容及 refreshSpecialMessages(autoSelectPending=false)。拒絕時不成功提示／刷新、保留 pending；dispose 後不通知／刷新，且不以清理錯誤覆蓋原拒絕。lifecycle 單檔 57 項全過，不修改正式程式、不呼叫真實 API。這只證明 controller 對 fake runtime 結果的處理，不證明實際 runtime／HTTP 權限、完整 UI 草稿或新舊送出重疊完成；此八案收尾，接續新舊特殊送出重疊。

- 2026-10-12 特殊訊息生命週期隔離驗收：前輪十案重現六失敗，正式 controller 補 generation／runtime／viewer snapshot／pending 防護，避免釋放後通知、舊成功提示／刷新、清掉新 pending；失敗保留原例外。本輪新增四案，notify 期間身分／pending／runtime 變更均零兌換呼叫；等待中從普通送出與特殊送出兩入口重按仍只有一次 mock 呼叫，完成後解鎖並正常提示／刷新。單檔 49 項全過，本輪只新增測試與紀錄、不再修改正式程式。這是點數文字訊息 mock 驗收，不冒充 streak／resub 全流程或真人 Twitch 寫入；同案例收尾，下一項驗證獨立特殊 API 分支。

- stylishnoob4（第二個eligible archive）Windows FULL_DVR＋三次實際drag＋chat focus＋左右鍵＋extended全序列5分12秒exit0：45秒增45,484ms，30%／70%／20%拖後十秒增10,116／10,117／10,133ms且控制列一致；focus防誤seek、1/3／2/3續播、120秒增121,350ms與返回live十秒增10,000ms通過。TS／無MAP，不是fMP4黑畫面證據；初始archive直入，不冒充首頁卡。extended build P954,521us但其他phase仍有慢幀，debug非profile。只紀錄、未analyze，不改憑證／正式功能，完整目標仍待恢復換源、其他格式與矩陣剩餘項目。

- AAC初始化兩素材欄位相同；原fragment多軌tfhd缺default-base-is-moof，測試專用記憶體副本只補該bit、原檔／樣本／正式媒體不改。兩unit驗所有差異位置與bit／輸入不變／可重複exit0；同音訊四重設Native由first-map音訊解碼失敗改14秒exit0，单opens1到12,210ms、44100Hz／2聲道→48000Hz、四點avsync<0.25秒／mute=yes、map5／fragment5、3,822,373bytes完整／兩層有內容。只修fixture定址相容性，不代表歷史Twitch黑畫面、不同codec或全程聲畫完成。唯一analyze無error／warning、八info；後加helper由unit／Native編譯確認。接續真實流程及完整矩陣。

- 官方未分段bear AAC/H.264（715,963bytes）只記憶體＋有限HTTP對照，首輪4秒exit1是仍啟動router暖機而零map／片段斷言失敗；完全停用對照router後Windows8秒exit0，opens1／端點1，音訊44100Hz／2聲道→48000Hz、avsync0.000020／mute=yes、router GET／map／fragment0。證明這份AAC可解碼，不撤銷分段檔audio_decode_failed89，也不代表fMP4音訊／Twitch已修。只測試／紀錄，唯一analyze無error／warning、八info，後改由編譯驗證；下一步比對AAC初始化描述，完整目標未完成。

- 原生音訊四重設測試兩次46秒exit1停在第一段，764,465bytes完整收取flush相等，但position0、音訊參數缺值、音訊hint89；未進重設。加固定分類及直接檔案對照後2秒exit1：video567ms、audio_decode_failed89／音訊採樣率仍缺，router GET／map／fragment0。公開素材hash未變，不能歸因tfdt／代理，也不宣稱App音訊或Twitch黑畫面同根因；音訊仍待定位。診斷18项exit0，唯一analyze無error／warning、六既有info，後加對照由編譯驗證。只測試／去敏診斷／紀錄，先確認素材／Native codec相容性再驗A/V。

- RESET_INIT_TIMESTAMPS擴充24次有界重設、正確滑動discontinuity序號，Windows1分9秒exit0：25 map／fragment、单opens1／GET1，Native到67,156ms、各邊界等待後非緩衝，19,111,913bytes收取flush相等、兩層末尾有內容與恢復再前進400ms。相同codec／解析度、音訊停用，不代表逐幀／零短暫緩衝、真實聲畫、Twitch黑畫面或全DVR完成。只測試／紀錄；唯一analyze無error／warning、六既有info，完整目標持續。

- 兩軌fixture重現逐軌offset消除新200ms A/V差、空tkhd拋RangeError（3過／2失敗）；正式timeline改共同有理數wall-time偏移及full-box長度／版本檢查。多次邊界、timescale48000→44100、正負offset、tfdt0／1與extended moof逐byte、32bit溢位等連七檔44項exit0。Windows時間重設影片回歸6秒exit0、單open到3,536ms／兩層有內容／恢復前進；音訊停用，非真實A/V或多次Native邊界。唯一analyze No issues found；歷史Twitch黑畫面與完整目標持續未完成。

- 正式fMP4 timeline依discontinuity序號／track timescale／已輸出duration重接tfdt，樣本及box長度不改；TS走原路徑。相同RESET_INIT_TIMESTAMPS由前輪2,569ms停滯改成Native單opens1到3,536ms、非緩衝／兩層有內容／恢復再前進400ms，6秒exit0；正常map等待重開回歸7秒exit0。相關七檔32項exit0，部分prefetch增真實fMP4後21項exit0（含原14，不重複累加）。唯一analyze兩入口No issues found；後補fatal metadata停止條件以test／Native編譯驗證。已修受控時間重設，不代表歷史Twitch黑畫面、不同codec／多次邊界／全DVR完成。

- 新fMP4 discontinuity＋tfdt重設受控Native失敗：48秒exit1，資料完整1,528,942bytes收取flush相等、pumpFailures0，position2,569ms從4秒停到44秒／buffering，Native已讀第二段；不是未送達，也不等同歷史position0／idle-active=yes黑畫面。正式parser／模型補discontinuitySequence（base／boundary／所有future形式），三新增案連格式與timestamp共9項exit0；writer尚未使用新欄位，Native停滯未修。唯一analyze只整合無error／warning、六既有info；後加正式解析由test編譯確認。下一步修世代邊界媒體時間／decoder並回歸同一失敗。

- 受控新map下載gate內forceOpen同來源，Native第二GET先解碼舊完整replay，gate未放行時667ms／764,465bytes／opens2；放行後3,667ms／1,528,942bytes收取flush相等、兩層有內容、恢復再前進400ms，Windows7秒exit0。相同codec／解析度，不是格式變更或真實Twitch故障；初次錯參數跑預設唯讀29秒exit0另列、不冒充fMP4通過。唯一analyze無error／warning、六既有info；只測試／紀錄，真實黑畫面及不同初始化／timestamp重設仍待驗。

- 既有 LIVE_FORMAT_SCAN 使用已掛載觀看頁 playbackApi，六台 caseoh_／kato_junichi0817／stylishnoob4／bisradio／supertf／pikabooirl，各 web3／Android2／iOS3 共48個媒體前綴均 TS、無MAP，Windows43秒exit0；授權解析狀態未記錄，不能稱每個请求均authenticated。此模式掃描後返回，未執行mini恢復切換；不撤銷歷史MP4＋MAP、read_failed／format_unrecognized及90秒黑畫面。只紀錄、未analyze；下一步受控fMP4初始化／格式切換，不原樣重掃六台。

- FIND_FMP4 在同一 App 有界探測六個開台追隨頻道，每台三畫質；mimiluckying／yulihong22／xargon0731／erycyoo／shuteye_orange／anninmiru_ 共18次均匿名ios-site TS、無MAP、playlist200／segment206／4096bytes。Windows24秒exit1停在找不到fMP4，不計直播切換通過；既有helper五項本機回歸exit0。唯一analyze無error／warning、六既有info。不能由匿名預探測推論App全部來源或歷史黑畫面，未改正式播放；下一步對照實際選源context或受控fMP4故障，不原樣重跑相同六台。

- 指定 recovery 頻道透過首頁搜尋與精確直播卡，新增 REQUIRE_FMP4 清單 MAP＋router MP4 init 門檻，避免 TS 成功冒充 fMP4。nix 59秒exit1停卡片可見、未取得offline證據；補搜尋完成診斷後sam1268 19秒exit1、live=false／offline=true／error=false，未開台且未進直播。均不是黑畫面重現／修復。唯一analyze無error／warning、六既有info，後加診斷由Windows編譯驗證；下一步有界探測目前開台的fMP4來源。

- 黑畫面取樣 helper 原 Native 截圖 null／錯誤會跳過 Flutter，已分開診斷；新增隔離注入兩案，Windows nativeSamples0／flutterSamples2，整體28秒exit0。前一輪29秒exit0與此輪皆caseoh_ TS，十秒增10,017／10,033ms、pre-open三點重疊、單GET及兩層有內容；不是fMP4黑畫面或Native open內部競態修復。唯一analyze無error／warning、六既有info。正式播放未改，下一步針對fMP4故障證據，不再原樣重跑TS成功樣本。

- 缺 chat:read 原仍以帳號 token 建立 IRC 認證連線，四組 scope 先兩通過／兩失敗；正式控制器改用既有匿名傳輸、無寫入連線，同時保留已登入 viewer 與帳號身分防護。69 項隔離回歸 exit0；唯一 analyze 無 error／warning、五個既有 fixture info、exit1。真實缺權限帳號讀取與重連待驗，不改憑證／協議，也不把此修正當黑畫面結案。

- 正式Watch缺chat:edit帳號canSend=false卻無提示，頁面fixture先失敗；missingSendPermission依已驗證身份／IRC scope經adapter→panel→section顯示已登入重新授權，不把checking／一般disabled當缺權限，pending特殊API保留。中英四狀態8案fake callback點後才1／send0，正式頁面non-guest／提示存在／無send；guest英文兩缺翻譯修正後三檔40項exit0、guest說明追加後8項再過。唯一analyze無error／warning、4info；未開OAuth／改憑證，匿名read fallback與真實授權仍待驗，完整目標持續。

- Signed fake auth＋正式WatchPage實際send按鈕到fake runtime，五案成功清稿／失敗保留且通用notice1／直接變更新稿保留／fake登出保留／卸載晚到無例外；各send1、無真實IRC。首輪5案是fixture平台override還原太晚而invariant失敗，結尾還原後三檔62項exit0，唯一analyze無error／warning、3fixture info。只fixture／紀錄，不是Windows原生App、真實發言或live playback；不同帳號／來源完整頁面gate與授權入口仍待驗，完整目標持續。

- 正式watch頁await controller後無條件clear，guest公開入口拒絕仍清draft；補extension fixture import後19過／1失敗重現。正式頁面核對起始可送／generation／channel／runtime／snapshot／未變草稿再clear，錯誤log僅type；三檔57項exit0，唯一analyze無error／warning、2既有info。直接呼叫頁面方法非訪客停用UI按鈕，沒有真實發言；已登入UI成功／等待中新draft及來源身分gate仍待驗，完整目標持續。

- 普通send原地fake換token／登出補六窗口：通知listener當場變更兩案runtime.send0，已開始四案（成功／失敗）保留send1但不向新身分controller報舊錯，原StateError同物件回呼叫者、sending收尾false；再送不增次數，guest僅登出true。連input／watch鍵位三檔43項exit0，唯一analyze無error／warning、5既有info。只mock／紀錄、不再改正式程式；完整watch Future接線、自動重連、特殊API與重新授權入口仍待驗，完整目標持續。

- InputBar舊失敗在停用／換draft後仍跳notice，五widget原3過／2失敗；正式核對目前enabled／controller／sendContext，watch panel傳(runtime, viewerId)經InputSection、日志僅error type。六案保留同情境與busy錯誤、四過期情境不提示，三檔37項exit0；relay追加斷言＋input12項exit0，唯一analyzeNo issues found。未改布局／協議／真實寫入；完整watch Future接線、特殊訊息與原地身分變更仍待驗，完整目標持續。

- 普通send在換runtime／dispose後成功或失敗四案先重現：新sending被舊操作卡住，dispose後notify及原StateError被覆蓋。正式send綁generation／runtime，current identity才發controller notice，原錯誤仍回呼叫者；新connect／dispose清舊busy，舊finally不清新send。四gate與既有三檔44項exit0，唯一analyze無error／warning、5fixture info。沒有真實IRC寫入或撤回已開始傳輸；input bar晚到提示、特殊API與原地身分變更仍待驗，完整目標持續。

- 前輪身分防護補connect／startup／listener各換token／登出六個獨立mock：連線晚到清runtime／viewer及dispose1，listener當場變更connect0，startup晚到supplement／channel callback0；fake sends全0、guest僅登出true。三檔40項exit0，唯一analyze無error／warning、5既有info。只fixture／紀錄，startup案不冒稱自動釋放已完成IRC或匿名重連；發送中身分競態、缺權限入口與完整矩陣仍待驗，完整目標持續。

- Drops補充載入等待時fake換帳號／登出，两案重現仍用舊token connect1（期待0）；正式核對共享snapshot，不符只清本世代runtime及舊viewer／連token，晚到startup與通知後亦防護。三檔34項exit0，最後notify同步檢查另lifecycle15項exit0；唯一analyze無error／warning、5fixture info，未再跑。沒有真實憑證／IRC寫入；只直接重現Drops gate，connect／startup／listener身分競態各自gate與自動重連仍待補，完整目標持續。

- 同controller舊connect成功／失敗晚到都清掉新connecting，兩gate測試先失敗；正式加connection generation、post-await／finally防護，disposeRuntime取消世代並清連token，network reconnect收尾亦核對世代／runtime／disposed。舊完成時新仍不能送、新完成後只新fake送1，reconnect晚到新源／close兩案通過；三檔32項exit0，唯一analyze無error／warning、5fixture info。沒有真實IRC／帳號切換／發言，缺權限提示與發送中身分競態仍待補，完整目標持續。

- 聊天controller普通canSend漏IRC scopes，五fixture四失敗／一通過重現；正式hasIrcSendPermission核對chat:read+chat:edit，普通composer與真正send前防護，特殊API保留原身分規則。驗證前0、缺scope0、完整1假傳輸；preview不誤擋且清除後防護恢復，三檔28項exit0。唯一analyze無error／warning、3fixture info，不重跑；未改IRC／token／Points payload，composer缺權限提示、匿名fallback與其餘寫入權限仍待驗，完整目標持續。

- Following已登入缺scope原有提示誤稱需要登入，新增文字斷言先失敗；共用卡片可選標題／按鈕，正式Following依已驗證auth／canReadFollows顯示重新授權，其他入口預設不變。中英初始／guest失權四組合與grant retry、API0／callback防護核對，連home三檔105項約7秒exit0。唯一analyzeNo issues found；英文翻譯追加由test編譯確認、不重跑。僅權限提示／fixture／紀錄，不動布局／憑證／協議，真實失權與完整路由仍待驗，完整目標持續。

- REPLACE_INIT_NATIVE相同codec／解析度、換map URI／增加free box、第二段tfdt平移3秒；gate期間保留完整首段，放行Native同open到3,600ms／stream-pos990,649，map2／segment2／opens1，1,528,942bytes／兩層內容、恢復前進。Windows35.0秒／6秒exit0；共用fixture空map分支34.4秒／3秒亦exit0。時間戳與傳輸13項exit0、唯一analyze無error／warning、6既有info。只fixture／紀錄，不擴稱不同codec／解析度或廣告切換，更不結案歷史Twitch黑畫面；下一步訪客權限，完整目標持續。

- EMPTY_INIT_NATIVE首次空map→有效map等待reader→放行，prefetch0／放行前segment0，Native同open成功decode、map2／segment1／opens1、764,465bytes／兩層內容及恢復前進。首輪34.7秒／48秒exit1是fixture期待持續直播HTTP自然EOF，修正為正確續播契約後35.2秒／3秒exit0；不改正式流結束語意。新增持續空map取消，至少3次空body／無分段輸出、close兩秒內終止；聯合18項exit0。唯一analyze無error／warning、6既有info；只fixture／紀錄，替換map原生連續解碼、任意長失敗自動截止與歷史Twitch黑畫面仍待驗，完整目標持續。

- HTTP200空map重現原程式快取空初始化、九bytes首段為moof不是ftyp；正式loader拒絕空body快取，既有重試重新取得有效map。持續503超過14次後保留舊init+分段，同reader服務恢復接新版本、主動close兩秒內結束；close fixture修正重複Completer／預期HttpException處理，非正式缺陷。五檔17項約6秒exit0，唯一analyzeNo issues found；未重跑Windows，不將合成box傳輸當原生解碼或任意長度永久失敗上限，歷史黑畫面與完整目標持續。

- 本機HTTP新reader三gate重現替換map下載中舊分段先被清掉、僅舊init而三秒逾時；正式writer先取得map才切分段，等待保留完整舊replay。初版14次map失敗回歸揭露舊buffer誤當新部分輸出，補每項output-started判定；最終init／replay／failed switch14項exit0。Windows原生fMP4 EOF恢復35.6秒建置／11秒exit0，position600ms／764,465bytes／兩層內容、decode／output1280×720；非map gate原生測試、非歷史Twitch黑畫面重現。唯一analyze無error／warning、1新info，不重跑；替換map原生解碼與永久失敗仍待補，完整目標持續。

- 新診斷Windows真實clip→caseoh_：34.9秒建置／27秒exit0，受控pre-open三pending均true但native-open均false；十秒增10,017ms，兩層有內容、TS／無MAP、router1GET／11,213,072bytes收取與flush相等／pumpFailures0。早於延遲門檻解碼，因此新增native欄位未觸發，不作零值或黑畫面修好證據；build P95=19,811us／12慢幀保留。初始化HTTP測試現有窗口是writer完成後重連，map下載中／分段串流中新讀取者待補；不重跑相同TS樣本，歷史fMP4黑畫面及完整目標仍待驗。本輪只紀錄、未analyze。

- 黑畫面switch nativeFlags原算法重現網址導致八個假旗標；改用去除HTTP／HTTPS網址的固定旗標helper，保留真實訊息分類。新增解碼高度／濾鏡後輸出尺寸及掉幀數字白名單，不支援欄位省略；16項診斷測試exit0，唯一analyze無error／warning、6既有info。只診斷／fixture／紀錄，未改正式播放或重跑相同Windows串流；舊nativeFlags不可單獨作原因證據、新欄位仍待真實故障取樣，歷史黑畫面未結案，完整目標持續。

- GUEST_HOME_KIND=vod保留目的ID／guest／fresh client核對，選非疑似growing普通影片。Windows34.7秒建置／1分13秒exit0，query riotgames→riotgames3 VOD，兩次自然到30,350／30,417ms，十秒增10,034／10,000ms、六次兩層影格有內容；實際UI返回再開、bundle2／API20／Authorization0。clip同範圍回歸34.7秒／34秒exit0，兩次各十秒增10,000ms、新client／API18／Authorization0。只fixture／紀錄，唯一analyze無error／warning、6info（1新if提示）；一頻道各一媒體、補充服務mock／音訊關閉，不撤銷歷史黑畫面，完整目標持續。

- GUEST_HOME_REOPEN同Windows程序query riotgames→riotgames3同一clip卡，34.6秒建置／33秒exit0；實際UI返回搜尋首頁再開，兩次各十秒增10,000ms且首尾兩層影格有內容。每次新watch／播放API client、runtime/session，主動關閉首個測試播放client後第二次仍成功，bundle1→2／API17→18／Authorization0；新頁external recorded初始化核對，非mini續播冒充掛載。只fixture／紀錄，唯一analyze無error／warning、5既有info；watch補充服務mock、首頁client共用、音訊關閉，VOD／其他返回與歷史黑畫面仍待驗，完整目標持續。

- 新GUEST_HOME_MEDIA經正式首頁搜尋卡→guard→watch，以共享空auth及獨立bundle/session接匿名真實discovery／播放，帳號／chat／補充metadata mock。59項隔離回歸通過，唯一analyze無error／warning、7info，後續selector修正由Windows編譯確認。六次新fixture wrapper／資格／懶載入／同名卡片失敗保存並定位修正；最終34.5秒建置／19秒exit0，query riotgames但實際riotgames3 clip、目的ID／guest唯讀／bundle1核對，十秒增10,032ms、兩層影格有內容、remoteClient API17／Authorization0。只fixture／紀錄、未改正式播放或帳號，不代表VOD入口、完整App或歷史黑畫面結案，完整目標持續。

- strict原生時序增加atNextOpen與oldCompleted：Windows34.5秒建置／9秒exit1，tap時舊opens2／completed1，但新open開始前舊completed2、atNextOpen=false，ownership亦false；新watchposition600ms仍嚴格失敗，不推論所有後端串行或重疊已修。唯一analyze無error／warning、5既有info。另home39＋watch20共59項約6秒exit0，既有搜尋VOD／clip卡片實際掛載／重進用獨立client／空auth共享及唯讀通過；播放故意mock失敗、Navigator.pop非UI返回，不當真實播放。只時序fixture／紀錄、未改正式播放器或搜尋factory，完整目標持續。

- segment診斷改Dio stream＋4096保留上限／取消剩餘订閱，新增大chunk／取消／短空及跨chunk，連既有14項通過，不改播放通道。strict WATCH_OPEN_SWITCH首輪輪詢34.1秒建置／22秒exit1未取得窗口；改無延遲開啟事件，34.2秒／10秒exit1，oldOpens2／completed1、atClick=true，但新watch解碼position633ms時atNewOwner=false，sourceLine3065嚴格條件失敗，不能宣稱ownership／原生內部重疊通過。唯一analyze無error／warning、5既有info，在最後事件改動前執行、Windows確認編譯；兩失敗保存、不放寬或重跑冒充修好，完整目標持續。

- OBSERVE_RESTORE_OPEN增加await實際耗時與mini開始至新ownership計時；15項mock競態回歸通過，未延遲或改正式行為。Windows真實clip→kaicenat34.9秒建置／29秒exit0：lastCompletedOpen281,443us、newOwnerElapsed3,642ms，atClick／atMount=true、atNewOwner=false，仍未達原生重疊。10秒前進10,000ms、兩層影格有內容、TS／無map／1GET／pumpFailures0；build P95=15,634us及16慢幀保留。唯一analyze無error／warning、5既有info；Range診斷被忽略回HTTP200／1,959,524bytes，4096硬上限待修。下一步改以open等待信號觸發受控route，不以media等待或本次成功宣稱重疊／黑畫面已修，完整目標持續。

- 新HTTP gate三案驗證清單持續等待：正式截止TimeoutException後原直連仍可讀；改源／close在不放行舊回應時兩秒內結束舊switch、無錯誤／旧inner，改源新資料保留、close不運作。新3連既有傳輸／init共27項約10秒exit0；清除上輪多餘?. warning，唯一analyzeNo issues found。只測試／警告清理／紀錄、不重開App，不涵蓋RPC status=null或Native open內部重疊，歷史黑畫面與完整目標仍待驗。

- 持續503案重現prewarm700ms後才5次請求即接手未就緒候選，未等既有14次重試結果。正式router等playlistVersion>0或stopped、每次await校驗generation，50ms輪詢及額外8秒截止；503耗盡後保留原直連，前6次503再成功仍讀到初始化／分段。成功案fixture另一次正常刷新誤算失敗已分開計數；聯合24項通過。唯一analyze無error、1新warning（router270多餘?.）未重跑；Windows原fMP4恢復35.0秒建置／11秒exit0，position734ms／764,465bytes／兩層影格通過。未知status／截止、503完整App及原生內部重疊仍待驗，歷史黑畫面未結案，完整目標持續。

- 換源失敗fixture增加原HLS兩案，與原直連共4組合：未被取代時原HLS URL／inner、ftyp／moof byte=7及running=true保持；被新直連取代時舊失敗不還原，仍收到[4,5,6]且無錯誤。連既有傳輸／init共22項通過，唯一analyze fixtureNo issues found；只補測試／紀錄、不改正式runtime或重開App。不是合成box原生解碼、HTTP重試耗盡或內部open重疊證據，完整目標持續。

- 損壞清單的真實本機HTTP重現候選引擎已停止但router仍接手、原直連遺失；首輪1失敗／1過期案通過。正式prewarm後檢查明確running=false拒絕handoff，未知status不當失敗，current catch還原direct URI／upstream、stale不撤回新來源。兩新案及既有傳輸共20項通過，唯一analyzeNo issues found。Windows正常fMP4 WATCH_EOF34.9秒建置／11秒exit0，原poll重open、764,465bytes完整送出／pumpFailures0、position600ms與兩層畫面恢復。不是損壞清單完整App端到端、HTTP重試耗盡或原生內部重疊證據，歷史黑畫面與完整目標仍持續。

- 診斷改對照原生／Flutter中央60%，記錄aspectMatches／positionDelta／paused，亮邊框不同解析度fixture加既有共12項通過，不降原視覺門檻。Windows匿名kaicenat Archive／paused34.6秒建置／1分8秒exit0：播放中差33ms時中央0.006982／0.407559，paused差0ms則0.409524／0.407559，支持本次兩層接近但不能解釋前轮暗影格。實際完整Slider80%續播增10,034ms，paused30%／保持／UI恢復增10,016ms，返回live增10,000ms；API7／Authorization0、TS／無map、不存實況圖。唯一analyze無error／warning、5既有info；只診斷／fixture／紀錄，歷史黑畫面未結案，完整目標持續。

- 新DVR interrupt案重現上一輪防護收尾缺口：舊pending HLS取消後health仍switching=true。正式interrupt取得主導權時清除switching，fast HLS及初始化／分段byte=2保留，聯合18項通過；唯一analyzeNo issues found。Windows匿名kaicenat Archive／paused34.9秒建置／11秒exit1：666→5,383ms自然前進但兩層非黑比例<0.1，原生0.086033／Flutter0.031802且1,108色，sourceLine2351視覺門檻失敗。不是全黑或已證明停播，pause由擷取主動執行、API7／Authorization0；未降低門檻或同源重跑，DVR拖曳／恢復／返回尚未执行，完整目標持續。

- 新playlist gate重現舊switchUpstream完成後覆蓋新直連或close狀態，首輪2案全失敗。正式router加入source change generation、start／prewarm／replay await後校驗及catch／finally過期防護；新3案含新HLS來源與ftyp／moof byte=2保留，連既有傳輸／init共17項通過，唯一analyzeNo issues found。修改後Windows WATCH_SWITCH34.5秒建置／24秒exit0，media gate放行後新URI／generation及两層影格保持、UI恢復增1,534ms到自然EOF，舊opens2／新1。正式來源競態已修，不等於新清單gate的原生重現、Native open內部重疊或歷史真實黑畫面結案；完整目標持續。

- 真實剪輯mini自然恢復→首頁kaicenat直播卡，Windows34.6秒建置／1分49秒exit0；九段10秒共前進90,166ms，無取樣停滯／緩衝，首尾兩層影格有內容。TS／無map、router1GET／1attachment／pumpFailures0，最終received與flushed91,838,000bytes；未存實況圖片。restore atClick／atMount=true但atNewOwner=false、started／completed1，不是ownership或native open內部重疊。build P95=12,402us、38慢幀仍保留；仅紀錄、未跑analyze，不能以本次成功撤銷歷史fMP4／90秒黑畫面，完整目標持續。

- 晚到回應防護後Windows受控WATCH_SWITCH35.2秒建置／24秒exit0：舊media gate等待時新watch同Player解碼，放行後URI／generation保持，兩層影格及公開fixture目視通過；10秒主動暫停不算續播，實際UI play再增1,601ms到自然EOF，舊opens2／新1不變。另不換源WATCH_EOF34.3秒／11秒exit0：原頁poll重open、generation+1、reader764,465bytes／pumpFailures0、position600ms及兩層影格通過。仅紀錄／受控圖片、未跑analyze；兩次建置成功，不替代真實90秒黑畫面、新標頭缺陷的原生重現或open內部重疊，完整目標持續。

- 正式router換源時舊GET標頭尚未到達，active iterator取消無法涵蓋；本機gate重現切換後舊reader仍收到[1,2,3]。在標頭await後及逐chunk加來源／reader generation防護，過期回應不接回active iterator、不輸出舊資料。兩種新reader順序及既有傳輸14項、另partial／init19項共33項通過；唯一analyze正式router與新fixtureNo issues found。正式傳輸漏洞已修，但無本輪Windows原生解碼證據，不能將歷史90秒黑畫面結案；完整目標持續。

- 原生錯誤診斷新增網址污染回歸：成功開啟訊息只因假網址含error就被錯算unclassified_failure，首輪10通過／1失敗。診斷helper改為所有分類前排除HTTP／HTTPS網址，修正後11項通過；本輪唯一analyze兩診斷檔No issues found。僅修正診斷、不改正式播放器或登入；不重寫歷史錯誤解讀，90秒黑畫面及起播暗影格仍需同次失敗的傳輸／時鐘／兩層影格對照，完整目標持續。

- 正式WatchRouteGuard新增可選完整services／chat factory轉交watch，預設與route／mini／pause行為不改。錄播8案改真實guard掛載，連watch其餘12及home37共57通過；home卡片仍掛載前移除，不拼成端到端。Windows guest guard→watch匿名zackrawrr Archive／paused35.6秒／1分7秒exit0：80%拖十秒增10,016ms、paused30%拖及兩秒保持／解析display通過、UI恢復增10,017ms／返回live增10,000ms，兩層影格／Authorization0／API7。唯一analyze7.7秒無error／warning、5既有info。只補依賴接線與fixture，完整首頁卡片factory、push-pop矩陣及暗影格／歷史黑畫面仍待驗，完整目標持續。

- 第二頻道匿名kaicenat Archive：首輪35.5秒／8秒exit1，起播366ms原生非黑0.066161／Flutter中央0.008594／373色未達比例門檻，非兩層全黑；尚未測DVR，失敗保留。補起播及自然5秒取樣後34.4秒／1分8秒exit0，但第二輪起播766ms已正常，不能宣稱等待修復前次失敗。公开20 videos中1匹配Archive，warm／80%拖／paused30%拖／UI恢復及返回live通過，三段十秒增10,016／10,017／10,000ms，Authorization0／API7、TS。唯一analyze7.4秒無error／warning、5既有info在五秒取樣補充前，最終Windows編譯驗證。只改fixture診斷／紀錄，初始暗畫面原因仍未定、其他故障及完整入口待補，完整目標持續。

- 匿名zackrawrr Archive補UI pause→實際30%拖曳→保持暫停2秒→UI play十秒→按鈕返回live。Windows35.5秒／1分2秒exit0：新URI／bridge解析差<2秒、paused／非buffering且2秒位置差<500ms、display近preview；target8,022,726ms、恢復增10,017ms／返回增10,017ms、Authorization0。初始80%Archive十秒增10,016ms，兩層影格有內容；本輪預設10秒，非重跑60秒。唯一analyze7.5秒無error／warning、5既有info，只改fixture與紀錄；TS／單頻道／隔離入口，不當全部比例、音訊、回放chat、故障或fMP4通過，完整目標持續。

- GUEST_ARCHIVE fixture修正日期difference／usingLiveDvrBridge及多餘!後，Windows匿名zackrawrr35.3秒／1分35秒exit0。公开8筆videos中1筆匹配目前live Archive，正式warm可用／Strip非20秒窗口；實際拖80%、解析位置差<2秒、bridge解碼，60秒增60,083ms／六段playing非buffering、lag5,291,618ms漂移0，兩層影格有內容。实际按鈕返回live增10,017ms、API7／Authorization0。日志replay=false是短buffer flag，Archive bridge斷言正常。唯一analyze7.5秒無error／warning、5既有info，前輪編譯失敗保留；這是單頻道native樣本、非完整App訪客入口／回放chat／所有故障，更多Archive／暫停拖曳及黑畫面仍待驗，完整目標持續。

- GUEST_ARCHIVE補公開live／前20錄影時間匹配、initialActiveDvrVideo及正式metadata、完整Strip拖曳／60秒／UI返回的fixture接線，尚未執行。Windows zackrawrr28.6秒編譯exit1、App未啟：DateTime减法與3處不存在usingLiveDvrReplay；唯一analyze7.0秒4error／1archiveTarget! warning／5既有info。正式介面核對為difference及usingLiveDvrBridge／usingLiveTimelineReplay；依限制不循環修跑，當前fixture編譯待修，不當匿名DVR不可用或已通過。只改測試／紀錄，完整目標持續。

- 匿名ow_esports短回看補60秒／六次取樣與实际返回按鈕：Windows35.6秒／1分33秒exit0，Slider拖曳後回看增60,073ms，六段10,026／9,994／10,027／10,010／10,009／10,007ms、playing／非buffering／replay保留，lag皆5,178ms／漂移0；兩層末尾影格有內容。Flutter tap可點LiveStatusButton後返回live十秒增10,010ms、API4／Authorization0。單一TS／公開metadata快照＋其餘隔離mock、fixture無Archive，非完整匿名Archive DVR、每幀或20秒全長可取證明；前輪失敗保留。唯一analyze7.5秒無error、1新增多餘! warning／5既有info未重跑；只改fixture與紀錄，完整目標持續。

- 匿名ow_esports短回看新增真實公开stream開播時間快照＋隔離auth／startup／chat：實際20秒Strip Slider拖到約80%後解碼。首次35.6秒／29秒十秒進度失敗、末尾9,380ms保留，起算未記錄、原因未證明；補fixture穩定2秒／前進1秒起算後34.7秒／43秒exit0，回看10秒增10,014ms、方法返回live再增10,027ms，兩段resets0、Authorization0／API4，兩層影格有內容。非正式卡頓修復；fixture不提供Archive，不能推論頻道無VOD，也不是完整匿名Archive DVR或返回按鈕UI驗證。20項fixture回歸通過；唯一analyze7.8秒無error／warning、5既有info在最後clock helper前，最終以Windows編譯驗證。完整目標持續。

- 格式檢查補正式runtime已有web-site／android-autoplay／ios-site三組參數，Windows35.9秒／53秒exit0；ow_esports、zackrawrr、kaicenat、jynxzi、trymacs、dona各3／2／3畫質，共18來源／48前綴全部TS、無init map，未取得真實fMP4。media多206、jynxzi web前兩項200，讀取仍限4,096bytes。不算48個解碼、全Twitch格式結論或黑畫面修復。隔離format5＋晚到停止1＋inflight4共10項通過；唯一analyze7.4秒覆蓋改動測試及前輪正式防護／新HTTP案，無error／warning、5既有info。只改測試及紀錄；真實fMP4／native內部重疊保留待驗，繼續訪客DVR與正式頁面，完整目標持續。

- 新去敏原生cache診斷10項通過。Windows再次requests3失敗後，gated HTTP定位engine停止時await中的playlist晚到仍schedule；正式poller新增post-await停止／server核對。新案修前有第三GET失敗，修後禁止GET通過但初版version錯比停止前1／停止snapshot0，校正停止snapshot基準後與既有共39項通過。Windows同故障34.8秒／11秒exit0，checkpoint2、poll自動opens2／requests3／generation+1／position600ms，完整764,465bytes與兩層影格通過；原生故障cache duration0，恢復1.935267秒／stream-pos226,172，unsupported不當零。唯一analyze7.7秒無error／warning、5既有info，在新正式防護／HTTP案前執行、最終以測試與Windows編譯驗證。native open內部重疊及歷史90秒黑畫面未結案，完整目標持續。

- 真實clip→mini→首頁直播ow_esports補60秒／六次取樣，Windows36.1秒建置／1分18秒exit0。各10秒增10,001／10,010／10,017／10,011／10,012／10,014ms，共60,065ms，playing／非buffering及來源保留；HTTP latest reader單一連線、status200／pumpFailures0，收到／flush至66,265,488bytes，50秒暫時flush pending於60秒收齊。首末原生及Flutter影格皆有內容，分類空，未保存真實畫面。TS非fMP4；native恢复click=true但mount／newOwner=false，不記為內部重疊。唯一analyze7.3秒無error／warning、5既有info，歷史90秒黑畫面仍未結案，完整目標持續。

- WATCH_SWITCH補新來源UI恢復及自然結尾：Windows36.0秒／24秒exit0，舊media response放行、像素驗證pause與10秒來源觀察後，Flutter tap控制列播放圖示；playing／非buffering且增>300ms，再native completed且增>500ms。實測增1,601ms／duration2,802ms、來源與兩頁generation保留、舊opens2／新1。是本機短素材結尾，非10秒長播、完整錄播EOF或native open內部重疊；隔離live fixture未等待下一輪completed poll。唯一analyze7.4秒無error／warning、5既有info，只改測試及紀錄，歷史切直播黑畫面仍未結案，完整目標持續。

- 恢復新inflight測試必要async import，當前28項聯合回歸通過；唯一analyze6.6秒無error／warning、5既有info。Windows WATCH_SWITCH35.9秒／22秒exit0，故障checkpoint requests2，原頁poll opens2後第三media回應pending時Flutter tap新watch。同Player新URI／generation接手與短解碼，放行舊回應後URI／兩頁generation不變、500ms增>150ms、舊opens2／新1；兩層像素通過。nativeOpenPending=false，非原生open內部重疊；像素helper主動pause，末尾10秒只來源保留、position仍1,167ms，不當長播。歷史90秒黑畫面與新來源續播仍待驗，完整目標持續。

- 第三次分段請求定位為正式writer取走prefetch後、markWritten前的playlist reload重複schedule。新增fallback gated、playlistVersion再增3次的MP4／TS×正常／前綴變更4案，修前全2→3失敗；engine claimed集合＋writer finally釋放／stop清除後聯合28項通過。Windows同故障35.7秒／11秒exit0，checkpoint requests2、poll自動opens2／requests3／generation+1，完整764,465bytes／MP4 init及原生／Flutter畫面通過。不是歷史90秒黑畫面全部結案。28項之後誤刪新測試必要async import，唯一analyze7.6秒3個Completer error／5既有info，當前新測試編譯仍待修；下一輪恢復import再驗，不重跑analyze循環。完整目標持續。

- stable router新增去敏最新HTTP reader診斷，只輸出計數／bool、保留8-byte header分類、不改串流順序。新HTTP7＋init3及既有partial14共24項通過。Windows參數首次漏外層分支只跑唯讀主流程exit0，不算恢復通過；正確故障分支34.8秒／1秒exit1，native completed但checkpoint分段請求3而非2、停止於斷言。最新reader收到／flush各1,317bytes、MP4 init開頭=true、HTTP200，不等同原生消費或完整解碼。請求時序差異與歷史90秒buffering仍待定位，真實切來源診斷接線尚未執行。唯一analyze7.5秒無error、2新增warning／6info，下一輪先處理局部提示及故障注入時序；完整目標持續。

- 匿名VOD同來源時間回看：Windows36.5秒建置／48秒exit0，自然前5秒黑、15／30秒有畫面、10秒增9,992ms後暫停seek。1,008／4,996ms兩層仍全黑；15,006ms原生非黑0.704377／Flutter0.753177，三次來源不變且沒有重新open，支持來源固定片頭黑場而非一次性起播延遲。同解碼器非獨立來源解碼證明，歷史切直播90秒buffering仍待定位，不修改正式runtime或遮蓋片頭。唯一analyze7.2秒無error／warning、5既有info；完整目標持續。

- 匿名riotgames VOD正式觀看頁補實際API／native／Flutter取樣：起播591ms及5,196ms全黑斷言exit1保留。延長自然播放、不seek／重開／換源後，624ms與5,362ms仍全黑，15,439ms及30,421ms兩層有畫面、再續播10秒增10,027ms，exit0。1080p60非audio-only且直接variant，匿名請求4／Authorization0，不能當片頭來源黑場已證明或歷史90秒黑畫面已修。watch fixture20項通過；唯一analyze7.7秒無error／warning、5既有info。只補隔離測試與紀錄，搜尋卡片完整route隔離仍待補，完整目標持續。

- growing搜尋卡片3案補同近期時間的Archive／Highlight／Upload；修正前兩非Archive被誤走DVR、initialVodVideo=null。正式video模型isLikelyGrowingArchive先限制type正規化為archive，保留原時間窗口；空／unknown不推測growing，不改UI排版或runtime。home37＋browse21共58項、model12＋guest media3＋DVR init3共18項通過，2真實網路預設skip；總76通過／2skip。唯一analyze三修改檔6.5秒No issues found，route未真正掛載非解碼；Archive仍likely heuristic、真實growing／完整播放器／黑畫面未結案，完整目標持續。

- 搜尋媒體新增title大小寫／影片作者／clip curator匹配與VOD／clip卡片實際捲動tap、正確TwitchWatchRouteGuard欄位4案；clip pending取消clear／換詞／dispose×晚到成功／error6案不追加下一頻道，驗證既有generation修復。首輪2卡片因捲動後未重繪tap超畫面失敗，補settle／ensureVisible／hitTestable後home34＋browse21共55項约5秒exit0。唯一analyze修改fixture6.6秒No issues found，未改正式程式；route掛載前移除非解碼、純mock未讀帳號，媒體真實資料／growing分支／上限去重與完整目標仍待補。

- guest正式首頁搜尋補非空舊結果：換詞2→4、clear／dispose0→2媒體請求三案重現；影片pending時clear／換詞／dispose×晚到成功／錯誤6案亦各多取剪輯1次。正式searchChannels頻道await後與media helper迴圈／每次await後校驗mounted及generation，過期不續取，未改UI／auth協議、不取消既有HTTP。home24＋browse21共45項約4秒exit0，空結果／失敗重試／篩選分頁／guest權限仍通過；唯一analyze父library＋fixture6.7秒無error／warning、1既有import info。只兩正式搜尋part＋測試／紀錄，無真實App／憑證操作，不宣稱黑畫面修好，完整目標持續。

- GUEST_REMOTE＋REAL_CHAT測zackrawrr，真實IRC token=null連線與正式runtime讀取、入口寫入防呆但sendAttempts0，未真實發言。首輪34.5秒／21秒因fixture在卸載前要求disconnect而失敗；移到卸載後，34.5秒／17秒exit0：runtime訊息10／raw22、connect1、無dual寫線、pendingOutgoing0、canSend=false、local isConnected=false；真實匿名TS播放API3／Authorization0、native與Flutter像素通過、10秒增10,000ms。24項chat／watch隔離回歸通過，唯一analyze6.9秒無error／warning、5既有info。只fixture／紀錄，更新矩陣訪客隔離範圍；discovery／startup仍mock、audio關閉、不是全部guest／黑畫面結案，完整目標持續。

- GUEST_REMOTE隔離空auth／mock discovery及chat，不進app.main或讀原帳號；正式匿名播放API／runtime／代理／Native Player／VideoController播放ow_esports。Windows34.3秒／16秒exit0，播放client請求3次／Authorization0／viewer state anonymous，guest畫面native非黑0.999060／Flutter中央非黑0.998487／16,327色；只記憶體摘要不保存實況截圖，resume後10秒增9,991ms。源為TS／206／4096bytes無init，chat mock唯讀、audio關閉、單一短樣本非完整guest IRC／音訊／DVR／fMP4。聯合58項exit0，唯一analyze整合入口7.2秒無error／warning、5既有info；僅fixture／紀錄未改正式程式／憑證，完整目標持續。

- LIVE_FORMAT_SCAN只讀目前mounted watch API及公開home卡，6個頻道ow_esports／zackrawrr／kaicenat／trymacs／eliasn97／rubius各前3個非audio畫質共18樣本：均TS、無init map、清單200、媒體前綴4096bytes（ow_esports index1回200、其他206）、fMP4候選0。Windows34.9秒建置／23秒exit0，scan結束未做mini換源，不算fMP4播放或黑畫面修復。新5項本機HTTP格式／403／無media／Range忽略上限加native8共13項通過；唯一analyze7.0秒無error／warning、5既有info。僅探測／測試／紀錄、未改正式runtime或憑證；有限候選無fMP4不推廣全部Twitch，保留原驗證缺口並可繼續其他功能，完整目標持續。

- 真實clip mini自然恢復→另一首頁live card新增native／Flutter frame aggregate，僅記憶體擷取不保存實況或chat圖片；helper黑像素／裁切／invalid尺寸等新1＋舊7共8項exit0。Windows34.5秒／28秒exit0，native467ms／1920×1080非黑0.998225／137,897色，Flutter中央非黑1.0／27,977色；HTTP206 4096bytes為TS無init，清單DATERANGE非廣告證明，十秒續播與URI／owner保留通過。恢復與nativeOpen atMount／NewOwner=false，非內部重疊；未重現fMP4黑畫面，不算修復。probe接等待10秒診斷可分proxy資料／native／Flutter，debug build仍14慢幀；唯一analyze6.9秒無error／warning、5既有info，僅診斷／測試／紀錄，完整目標持續。

- GUEST_SURFACE分controller建立／watch播放／擷取／收尾記錄，加EGL／OpenGL／D3D11／Vulkan固定hint，7項helper測試exit0。Windows34.7秒建置／3秒exit0：未開媒體的controller階段收到未分類1／GPU1／EGL1，後續watch與capture無新增分類；position367ms、native非黑0.960943／Flutter非黑0.903897／23,459色，安全截圖影片可見。收尾listener在Host.dispose前取消，非完整dispose證據。這筆播放前訊息不足以證明換源黑畫面根因，不改GPU設定；唯一analyze6.9秒無error／warning、5既有info。僅診斷／測試／紀錄／截圖，前輪間歇fixture失敗及真實黑畫面仍未結案，完整目標持續。

- 原生診斷新增固定hardware/video failure分類與13種unclassified hint，只輸出key／計數、hint前移除URL；新2＋舊4共6項exit0。WATCH_SWITCH首次新診斷34.9秒建置／約1秒失敗，EOF後框架斷言被舊print篩選隱藏、原因未定位；補安全檢查點及例外型別／本檔行號後34.6秒／22秒exit0，EOF requests2／open1／completed=true／position0，未分類1取得GPU hint1。新來源切換仍保留URI／generation、10秒不重開，position1267ms及像素／安全截圖通過。成功不抹除前次間歇失敗，也不把GPU文字hint當黑畫面根因；唯一analyze6.9秒無error／warning、5既有info，gate新info已補括號。僅診斷／測試／紀錄／截圖，下一步分段對照controller初始化與解碼／擷取，完整目標持續。

- WATCH_SWITCH本機第三segment response gate等待中，Flutter實際tap fixture按鈕Navigator.push另一正式guest觀看頁，新來源使用同一nativePlayer／controller且先解碼；放行舊response後位置增>150ms、Host新URI與兩頁generation保留，10秒舊opens2／新opens1不重開。Windows34.5秒建置／22秒exit0，position1234ms、native非黑0.960836／Flutter非黑0.903413／21,612色，獨立切換截圖確認影片可見。切換時原生open已完成2次、nativeOpenPending=false，僅media pending，不冒充內部重疊。改獨立輸出路徑後EOF回歸33.8秒／11秒exit0、position600ms及像素通過；切換分支檔名改後未重跑。唯一analyze6.8秒無error／warning、6info（5既有＋1新gate括號）；僅fixture／截圖／紀錄，同頻道不同来源短片非全部黑畫面結案，完整目標持續。

- WATCH_EOF新增可見surface，正式Host VideoController／low latency profile與兩層proxy、觀看頁8秒poll同程序：殘片斷線→重抓前綴變更拒絕→native completed→原頁同ID自動重載opens2／requests3／generation+1，position567ms且completed=false；恢復後native非黑0.952065、FlutterTexture中央33,048點非黑0.881385／21,569色，安全截圖檢視影片可見。Windows34.0秒建置／11秒測試exit0，原生unclassified_failure1保留；唯一analyze6.9秒無error／warning、5既有info，未重跑。僅fixture／截圖／紀錄、本機短片／fakeguest非真實Twitch長播或全部黑畫面結案，恢復中換源仍待補，完整目標持續。

- Windows新增隔離guest觀看頁實際VideoController／surface／Texture：本機Chromium bear素材、mock auth／discovery／chat，不進app.main或讀原帳號；Player只aid=no、不再vo=null。首次screenshot字串參數與專案ScreenshotFormat不符，28.5秒建置失敗；改預設呼叫後34.1秒建置／約2秒測試exit0。position567ms、native非黑0.952065，FlutterTexture中央取樣33,048點非黑0.881385／21,569色；保存並檢視安全截圖確認影片可見。原生unclassified_failure1保留，未細分；唯一analyze6.7秒無error／warning、5既有info。僅測試／截圖／紀錄，非真實Twitch授權／proxy恢復／長播或歷史黑畫面結案，完整目標持續。

- 訪客正式觀看頁新增VOD／clip×暫時失敗／授權拒絕×留頁／等待中卸載8案：auth pending不解析，guest完成後對應媒體解析1次且不自動登入／切直播；失敗loading與bootstrapping解除、20秒不自動直播重試，公開loadWatch再載入只解析原媒體、storage不重讀，卸載晚到失敗無框架錯誤或續取。fixture型別及debug平台還原問題修正後聯合45項約4秒exit0；唯一analyze修改fixture6.6秒No issues found。僅改測試／紀錄、無native Player或真實憑證，非訪客解碼成功／UI重試按鈕／黑畫面結案，完整目標持續。

- 已登入快照的聯合登入頁暫時驗證失敗重現誤報尚未登入：修正前新增7項中1案失敗；正式_readStatus移除吞所有驗證錯誤並設mainReady=false，改由原狀態／登入錯誤流程處理，不改session或憑證儲存。最終新11項涵蓋storage／一般驗證例外／503、登入按鈕後重讀失敗、等待中卸載晚到成功／失敗，以及真正401／403仍guest；暫時失敗保留authenticated身分、無外部HTTP／OAuth導頁，loading解除。聯合37項約8秒exit0，唯一analyze登入頁＋新測試3.8秒No issues found。隔離mock非真實登入成功／網路故障或黑畫面結案，完整目標持續。

- 完整guest fixture補暫時／持續storage讀取失敗，公開頁各loading解除、chat唯讀可讀、不自動跳登入；暫時失敗的正常Snack預期已校正。持續失敗實際tap登入重現聯合頁把未知狀態誤標尚未登入；正式_loadStatus只修失敗狀態與稍後重試提示，取消返回仍guest／chat1連線，未改憑證儲存／OAuth協議／排版。修正前單案失敗，後聯合26項exit0；唯一analyze6.7秒無error／warning、1fixture102格式info，未重跑。模擬storage非真實故障或cached已登入身分驗證，完整目標持續。

- 補先前未完成的mini恢復開啟重疊：fixture const PlayerState編譯錯誤修正後，entry換源／close／session替換／不變×舊open成功／失敗8項通過。換源後不seek舊30秒且新URI保留；正常不變成功恢復30秒；失敗以same(originalError)驗證未吞或取代。聯合Host7＋session18共33項exit0，唯一analyze4.7秒No issues found，最後error identity斷言後只重跑測試。fake Player介面邊界非真實native內部重疊；正式程式未改、未啟App，完整目標持續。

- zackrawrr完整開啟DVR_DRAG＋DRAG_REPEAT補三次Slider30%→70%→20%：Windows34.2秒編譯／2分17秒exit0，45秒續播增45,516ms；穩定起算前捕捉1／1／2位置重設，三次10秒native增10,133／10,117／10,117ms，display增量差0／7／5ms，取樣未緩衝／未換源，返回live解碼後增10,017ms。此輪才補手勢，不追溯改上輪未執行結果；TS非fMP4，lifecycle unknown，drag build仍5慢幀。只更新紀錄、未改程式／未跑analyze，其他格式／故障及訪客缺口仍在，完整目標持續。

- 代理／EOF恢復修正後具名zackrawrr（eligibleIndex2）Windows完整DVR長測：36.1秒編譯／4分21秒exit0，TS／HTTP200來源；45秒增45,566ms、UI暫停跳轉保留暫停與恢復續播、1/3／2/3各10秒通過，120秒增121,484ms／每10秒取樣無緩衝，返回live解碼後增10,000ms。DRAG_REPEAT未搭DRAG入口，拖曳未執行不算通過；首次lifecycle unknown／inactive、後段resumed，非前背景A/B。debug extended build仍12慢幀，不宣稱無卡頓／全部黑畫面或所有格式已修。只更新紀錄、未改程式／未跑analyze，完整目標持續。

- same-ID completed恢復poll等discovery時，實際Navigator.push另一個正式同頻道watch；新頁初始化1次後放行旧回應，旧State仍mounted／Player仍completed，但兩頁generation與初始化次數皆不被額外增加，pop返回原State通過。聯合24項exit0；唯一analyze6.4秒無error／warning、2context info改保留NavigatorState後同24項再通過，未重跑analyze。僅改fixture與紀錄，驗證既有post-await owner防護；fake Player／傳輸不冒充原生或跨頻道競態。長播／完整DVR及訪客缺口仍在，完整目標持續。

- WATCH_EOF同流程串起正式觀看頁／原8秒poll／正常router／proxy／原生Player，本機init等native掛載後故意截斷並回不同前綴。EOF後沒有測試手動重載，同ID由頁面poll自動重開，generation+1、opens2／requests3、completed=false／position633ms>500。初版替身介面漏參數編譯失敗，補齊後Windows34.1秒編譯／10秒exit0；既有隔離24項通過。fixture guest／fake discovery＋本機URI、原生vo=null無可見影片，不冒充真實Twitch或長播。唯一analyze6.8秒無error／warning、5info（3既有2新格式）；只改測試與紀錄，專門切頁競態待補，完整目標持續。

- 受控原生PARTIAL_REJECT驗證：client先掛載再放init，預取殘片後重抓前綴變更，正式proxy拒絕收尾；5秒後completed=true／position0／playing=false／buffering=false，代理stopped，原生分類空。測試直接同Player重open同網址後第三GET成功，10秒position2,268ms／completed=false，Windows33.9秒編譯／15秒exit0。確認completed信號及原生重開有效，但未掛router／觀看頁，不冒充App8秒poll端到端恢復；有限素材尾端仍buffering。唯一analyze6.8秒無error／warning、3既有info；只改fixture與紀錄、正式程式未改，完整目標持續。

- 正式guest觀看頁8秒poll重現same-ID直播completed不重試：profile預期1→2實際1；paused與錄播completed零重載正常。正式poll新增live＋completed重載，await discovery後核對generation／mounted／top owner；修正後same-ID重試一次，paused／recorded仍零次，聯合24項exit0，唯一analyze6.4秒No issues found。fake Player僅狀態、profile故意失敗，非native EOF事件映射或解碼续播證據；專門離頁競態及端到端恢復待補，不改帳號協議／UI，完整目標持續。

- 正式固定網址router隔離重現隱藏EOF：直接inner兩案通過，正常router包覆相同前綴變更／過短兩案2秒逾時。_proxyStreamLoop未switch時80ms重接同target，外層不結束；改同generation／target自然EOF就break傳給讀者。明確switchUpstream仍同reader從a18 bytes接b18 bytes通過；聯合24項exit0，唯一analyze2.8秒No issues found。只改router／HTTP測試與紀錄，非原生自動重連證據；App同直播身分的EOF恢復仍待補，完整目標持續。

- 拒絕重抓後舊client等待EOF兩案皆2秒逾時，確認writer停止卻沒結束殘片流。正式writer只有當前segment已輸出bytes時才stop engine／bus，下一GET乾淨重建；初版無條件stop造成14次init失敗重試回歸失敗，縮限bufferedBytes>0後恢復。舊HTTP讀者EOF、新讀者init＋完整段、3次segment請求兩案通過；聯合21項exit0。拒絕狀態現改engine stopped／buffered0，上輪保留10 bytes為歷史證據。唯一analyze2.8秒無error／warning、1新格式info已补括號，最終條件後只測試未重跑。不啟原生Player或App，App自動重連／解碼续播仍待補，完整目標持續。

- 部分預取回歸補MP4／TS樣式各0／1／7／10／15-byte斷線續接與10-byte前綴變更／過短拒絕，共14項。有效重抓精確輸出原分段一次；拒絕後hasWriter=false、sequence=-1、duration0、buffered僅原10 bytes。初版誤等engine running=false的4項逾時，改測writer狀態後聯合init HTTP／replay共19項exit0；唯一analyze2.7秒No issues found。兩側分開flush但TCP可合併，不當成必然跨核心接收chunk；非可解碼fixture，拒絕後重新啟動／既有讀者恢復仍待補。僅改測試與紀錄、未改正式程式／未啟App，完整目標持續。

- 正式proxy＋原生Player长連線重現部分預取拼接原因：修正前33.5秒編譯／20秒診斷exit0，完整763,158 bytes／position2,268ms；截斷重抓多10 bytes、position0／playing／buffering=true，原生分類空。正式fallback核對並略過已送前綴，只接剩餘bytes，前綴變更／過短拒絕。位元組＋init回歸6項通過；同故障注入修正後35.7秒編譯／20秒exit0，兩組均763,158 bytes與2,268ms，證明此起播0原因修復。有限素材結尾仍buffering，不代表長播／歷史黑畫面全部修好；前綴防護分支及更多格式待補。唯一analyze7.4秒無error／warning、4info（3既有＋fixture1763:17格式），不改憑證協議／UI／原生open，完整目標持續。

- 原生殘片因果對照取得有效影像基線：修Player.create後完整素材先因音訊分支失敗；file／mp4 MIME／mp2t MIME皆0且audio failure token89，不能怪MIME。獨立fixture設aid=no／vid=auto／vo=null後Windows35.0秒編譯／16秒exit0，三個完整來源position2,769 ms，唯殘片版本0，原生失敗分類空。證實殘片會使此影像播放路徑不前進，但有限來源buffering=false，非既有90秒buffering的根因結案；需正式proxy＋可解碼素材長連線驗證。只斷言完整HTTP>500ms，殘片0為觀察值；正式程式未改。唯一analyze7.2秒無error／warning、3既有info，最終fixture後只編譯未重跑，完整目標持續。

- 新增PARTIAL_DECODE原生fMP4完整／殘片重抓對照分支與公开Chromium素材，未進帳號App流程。編譯30.1秒exit1、唯一analyze6.9秒：新Player()建構方式錯誤1723:26及3項既有info；專案使用await Player.create，下一輪修fixture後再驗證。尚無解碼結果，不當成黑畫面原因證明；正式程式未改，已確認的代理部分預取資料錯位保留，完整目標持續。

- 黑畫面資料路徑診斷新增本機HTTP截斷：正式prefetch先送16-byte分段前10 bytes後失敗，fallback完整GET接在殘留前綴後；讀者得到init8＋partial10＋full16共34 bytes，MP4區塊邊界錯位，確認可重現的代理資料損壞。單案及init HTTP／replay聯合6項exit0，診斷pass不是修復pass。初版detachSocket時機修正後才重現；唯一analyze3.1秒No issues found。正式程式未改、未重跑Windows；非可解碼fixture，與既有黑畫面的因果仍需驗證，不宣稱根因已確定或完整目標已完成。

- VOD自然恢復切換直播啟用REQUIRE_NATIVE_OPEN_OVERLAP嚴格驗證：編譯34.0秒／測試31秒exit1，播放與十秒來源保留通過，但native atNewOwner=false，934行重疊斷言失敗。atClick／atMount=true、started=completed=1，無恢復錯誤；未達時點不當成正式播放故障或重疊通過。TS無特定廣告／原生失敗分類，未重現黑畫面；後續改補可控原生開啟重疊隔離測試，避免只重跑自然時序。未改程式／未跑analyze，完整目標持續。

- Windows剪輯mini自然恢復切換另一首頁直播卡續測：34.0秒編譯／27秒exit0，解碼／owner接手／十秒前進／來源保留通過。native atClick／atMount=true、atNewOwner=false，started=completed=1，仍未達接手時原生open內部重疊。TS來源HTTP200、媒體206／4096bytes，無特定廣告標記或原生失敗分類；DATERANGE不等於廣告，未重現不當成fMP4黑畫面修好。只依既有報告格式補紀錄，未改程式／未跑analyze，完整目標持續。

- 晚到恢復回應補足開台與離線兩分支：正式8秒輪詢先捕捉舊回應並延遲，同頻道重載新stream及不同開台時間後才放行；新直播ID、開台時間、載入generation與profile初始化次數均保留。injection／auth startup／chat lifecycle聯合24項通過、exit0；唯一analyze6.5秒無error／warning，1項既有watch page 565:11格式info。僅補隔離測試與紀錄，正式程式未改；不建立原生Player，不代表訪客解碼、真實斷線恢復或間歇黑畫面已完成，完整目標持續。

- 觀看頁載入／晚到防護後Windows剪輯mini→自然恢復→另一直播card實際導頁回歸，34.3秒編譯／28秒exit0，新source／owner／十秒續播保留通過。native restore在Click／Mount=true、NewOwner=false，started=completed=1，未達新owner接手時內部重疊。來源TS、無特定廣告標記／init／原生失敗分類，DATERANGE不等於廣告；不以成功樣本抹除fMP4黑畫面。未改程式、未跑analyze，完整目標持續。

- 正式恢復poll舊回應延遲、同頻道先重載新stream後放行，重現新stream-3被蓋回stream-2。refreshLiveTimelineStartedAt增加watchLoadGeneration提交前校驗，修正後舊回應不改新身分／generation／初始化次數；聯合23項通過，正常恢復輪詢亦保留。WindowsFOLLOWING_ENTRY34.0秒編譯／23秒exit0，追隨第一卡、chat與15秒播放通過；唯一analyze無error／warning、1既有565:11格式info。此為身分晚到提交競態修復，不冒充native開啟重疊或黑畫面結案，目標持續。

- 初始化完成後正式8秒recovery timer回歸：離線→開台generation+1／初始化1次，相同stream下一輪不重開，stream ID改變再generation+1／初始化共2次；storage仍1次、原chat連線仍1次、guest唯讀與卸載清理通過。聯合23項通過，唯一analyze正式guard檔＋測試6.5秒No issues found。本輪只改測試與紀錄；mock傳輸與播放失敗不冒充訪客解碼／真實網路恢復，完整目標持續。

- 新增已開台訪客fixture重現storage尚未完成時recovery先loadWatch，profile初始化預期0實際1、正常startup後共2次。正式恢復輪詢略過auth pending／首輪generation0／loadingWatch，初始載入由原pipeline負責；補初始零請求／零初始化與開台身分／單次初始化，22項隔離回歸通過。WindowsFOLLOWING_ENTRY34.2秒編譯／24秒exit0，預設追隨第一卡、chat與15秒播放正常。唯一analyze6.3秒No issues found在正式guard前，最終以測試與Windows編譯驗證未再跑。不改憑證／協議／播放器底層；此修復限初始化競態，不代表訪客解碼、native內部重疊或黑畫面已修，目標持續。

- 訪客完整頁面503→200離線回應後正式loadWatch重載通過：新請求／generation+1、各loading與bootstrapping解除、原chat runtime保留且只連線1次、guest唯讀、storage不重讀，登入取消返回與卸載清理仍通過。初版callback guard衝突及fixture缺channelLogin／重連預期錯誤已補正，未改正式程式；聯合21項最終通過，唯一analyze6.4秒No issues found，最後fixture修正後未再跑。不是UI重試按鈕／真實網路恢復／開台解碼；完整訪客播放、native恢復重疊與黑畫面仍待補，目標持續。

- 訪客完整掛載503分支改Dio badResponse reject，不以resolve503冒充傳輸失敗；storage完成後未知直播狀態走正式播放啟動，fake profile初始化拒絕一次，再收尾至離線占位。loading與四類bootstrapping解除、guest chat唯讀、無自動登入／OAuth誤提示、登入入口取消返回及卸載20秒無續取／timer通過。fixture計數型別編譯錯誤修正後injection7＋startup10＋chat4聯合21通過；唯一analyze6.4秒No issues found。未改正式程式、未連真實IRC或建立Player；不是已開台解碼／播放授權成功，訪客播放、恢復重試與完整登入流程仍待補，目標持續。

- ow_esports具名Windows樣本完成三次Slider拖曳後UI暫停→左鍵跳轉保持暫停→UI恢復續播→返回直播，33.9秒編譯／2分38秒exit0。三次十秒native增10,109／10,106／10,128 ms，display增量差9／4／2 ms；暫停跳轉目標與解析差1 ms，等待後仍暫停，恢復十秒>7秒、返回直播增10,012 ms。與前輪trymacs確認兩個具名TS來源，不宣稱所有頻道／fMP4／廣告切換或間歇黑畫面已修；本輪未改正式／測試程式、未跑analyze，完整目標持續。

- 完整DVR新增候選index選擇及公开頻道名稱紀錄，index1選到trymacs；Windows35.7秒編譯／2分27秒exit0。30%→70%→20%實際拖曳較長時間軸，十秒native增10,100／10,133／10,117 ms，與display增量差5／5／4 ms，返回直播增10,000 ms。只改測試與紀錄、正式程式未改；唯一analyze無error／warning、3既有info。舊DVR樣本未記頻道，不能稱已證明跨頻道；更多具名頻道／fMP4／廣告與間歇黑畫面仍待補，完整目標持續。

- 完整 DVR 同一 Windows App 程序實際 Slider 30%→70%→20% 往返拖曳與返回直播通過，33.9 秒編譯／2分25秒 exit0。三次十秒 native 增10,098／10,127／10,115 ms，display 增10,112／10,132／10,111 ms，差14／5／4 ms；各捕捉一次啟動重設後穩定起算，每秒取樣非緩衝且來源保留，返回直播增10,007 ms。只擴充整合測試與保存證據，正式播放器未改；唯一 analyze 7.3秒無error／warning、3既有info。單一TS來源不替代其他頻道／fMP4／廣告或間歇黑畫面驗證，完整目標持續。

- 完整 DVR 實際 Slider 拖曳首次進度斷言失敗；逐秒重現 native 6,313→801 ms 換源重設，之後逐秒穩定前進，display 同步更新。橋接器固定 seek 起點不是控制列時鐘。整合測試改等待新來源至少 2 秒／1.5 秒連續前進，保留十秒 >7 秒門檻，另加 display 前進與 URI 保留。Windows 回歸 34.0 秒編譯／1分54秒 exit0，捕捉一次 reset，native 十秒增10,115 ms、返回直播增10,013 ms；正式播放器未改，不以此宣稱間歇黑畫面／廣告或全部 DVR 卡頓修好。唯一 analyze 7.4秒無error／warning、3既有info，gate新增後未重跑；完整矩陣持續。

- 剪輯mini→自然恢復→另一直播Windows編譯33.9秒／30秒exit0，新source／owner／URI／10秒前進通過；native atClick=true但Mount／NewOwner=false，未達內部重疊。受控beforeOpen gate＋require recovery overlap情境33.8秒／28秒exit0，pending三點true、新解碼後放行仍保留來源；native三點false且started0，僅pre-open恢復競態，不稱native內部重疊。兩來源都是TS／无init／無特定廣告標記、原生分類空，DATERANGE不等於廣告，不以成功樣本抹除fMP4／間歇黑畫面失敗。debug慢幀保留；未改正式程式、未跑analyze，保存兩情境證據，完整目標持續。

- 正式離線訪客watch實際tap聊天登入FilledButton，掛聯合登入頁／原readStatus，確認同主WebDropsclient、尚未登入，再返回watch仍guest／唯讀、chat連線不增加；三組load各3均fixture，輔助getToken=null，不開授權。初版finder誤用OutlinedButton更正後通過；上輪格式info處理。六檔聯合102項約5秒exit0，唯一injection測試analyze6.4秒No issues found。正式程式未改、未啟動真實App；證據限聊天登入導頁與取消，不等於授權成功／其他入口／訪客開台解碼，原生恢復重疊與黑畫面／廣告仍待測，完整目標持續。

- 正式訪客watch在mounted完成storage gate後走原離線pipeline：loading／四類bootstrapping解除、offline placeholder、channel7、guest chat連線一次／不可發言與實際唯讀UI提示通過，卸載20秒不續取、不留下timer。chatStartup／runtime是假依賴，原playlist runtime配fail-closed播放API／fakePlayer；首輪fixture缺roomState補齊，不改正式程式。injection6＋startup10＋chat4聯合20通過，補UI後injection6再過；唯一測試analyze6.3秒無error／warning、5新增格式info待修。本輪未啟動真實App，證據限完整掛載離線啟動／聊天UI，不算访客開台解碼／真實訊息／登入導頁完成；完整矩陣、原生恢復重疊與黑畫面／廣告仍待測，目標持續。

- 訪客初始watch改明確Dio攔截HTTP200／503，不再只靠binding400；兩分支均實際發請求且無Authorization，卸載完成storage gate／ensure／20秒後請求不增加、無Player或timer。injection5＋startup10＋chat4聯合19項通過；fixture區塊與docs測試註記處理後唯一injection analyze6.3秒No issues found。正式程式未改、未啟動真實App。仍僅storage pending初始頁與卸載，503不是播放中斷線恢復；runWatchStartupPipeline離線／player／延後chat需在mounted完成auth後補全，不能冒充完整訪客功能。原生恢復重疊與黑畫面／廣告仍待測，完整目標持續。

- 正式訪客watch初始widget挂載／storage pending離頁案例，在fixture依賴補齊後重現8秒live recovery Timer殘留；正式dispose立即釋放Expando recovery，ensure拒絕unmounted建立。injection4＋startup10＋chat4聯合18通過，補離頁ensure與20秒推进後injection4再通過。只覆盖原init/build/postFrame至storage pending，不是完整loadWatch／聊天室／解碼；binding阻擋HTTP初始timeline回400，下一輪補mock傳輸。唯一三檔analyze6.6秒無error、1測試註記warning／9info待處理。WindowsFOLLOWING_ENTRY＋LIVE_ROUTES編譯33.9秒、57秒exit0，返回／mini拖動展開關閉／換台owner與chat／15秒通過。原生open內部重疊、訪客完整啟動與黑畫面／廣告仍未完成，慢幀保留；未改憑證／協議／UI／播放底層，完整目標持續。

- 訪客watch隔離續作：chat controller optional runtimeFactory由watch交接，預設IRC建立與協議不變。新增正式connectChat的guest成功／失敗重試、startup補資料／dispose、零驗證及不可發言兩案，chat4＋injection3＋startup10聯合17通過；首輪fixture badge參數誤用更正後通過。唯一三檔analyze6.5秒無error／warning、3格式info（新測試52、既有測試212、watch565），下一輪處理。Windows預設FOLLOWING_ENTRY編譯34.0秒、24秒exit0，追隨第一卡／chat／解碼／15秒通過。仍非完整訪客widget與真實換帳號，runtime為fake；完整掛載、原生恢復重疊、黑畫面／廣告及慢幀仍待測，憑證／協議／UI／播放底層未變，目標持續。

- 完整訪客watch隔離前置：正式watch optional initialServices交給session factory，供給依賴取代自建服務，不跳過啟動；混用auth／runtime拒絕。三項交接／拒絕與startup10聯合13通過；唯一三檔analyze6.5秒無error／warning、watch563既有格式info。預設Windows FOLLOWING_ENTRY編譯34.1秒、23秒exit0，追隨第一卡／chat／解碼／15秒通過、debug慢幀仍有。尚未挂完整訪客widget；chat controller直接建立IRC，須再隔離runtime建構及完整Player／服務行為，不能把placeholder交接當完整功能證據。未改憑證／協議／UI／播放底層，原生恢復重疊與黑畫面仍待測，完整目標持續。

- 共用 session 已驗證新身分但 watch 未新 load 的 listener 路徑重現 loading 卡住／舊一般錯誤提示兩案；正式 syncViewerIdentity 同步 checking 狀態，loadAuth 採用目前 snapshot 並以身分 revision 忽略舊錯誤。修正前2失敗／8通過，修正後聯合92項及補強 pending 舊請求前已解除 loading 的startup10通過。唯一三檔 analyze6.4秒無error／warning、1既有watch559格式info；Windows FOLLOWING_ENTRY編譯34.7秒、23秒exit0，預設追隨第一卡／chat／解碼／15秒通過。無真實換帳號、完整訪客watch／native恢復重疊仍未完成，debug慢幀及黑畫面／廣告待測，未改憑證／協議／UI／播放底層，完整目標持續。

- 觀看 startup 新增目前驗證失敗後重試、訪客不驗證並清 viewer、pending 登出新 load 與模擬離頁後舊成功／錯誤六案。startup8＋home17＋session35＋following30 聯合90項通過，約4秒exit0；首輪測試 enum 名稱誤用造成編譯失敗，更正後通過。唯一 startup 測試 analyze6.4秒 No issues found。本輪正式程式未改、未啟動真實 App。State getter fixture 不等同 widget dispose 或完整訪客 watch，記憶體登出不更動真實憑證；無新 load 的通知接線、完整 watch／聊天室、原生恢復重疊與黑畫面廣告切換仍待補，完整目標持續。

- 觀看loadAuth方法隔離重現新viewer已完成後舊一般驗證錯誤仍跳OAuth提示；正式startup用State讀取版本保護完成／catch，舊成功與錯誤兩案均保留新viewer／loading及共用snapshot、無舊提示。startup2＋home17＋session35＋following30聯合84項通過，唯一兩檔analyze6.4秒No issues found。真實FOLLOWING_ENTRY編譯33.9秒、23秒exit0，預設追隨第一卡／chat／解碼／15秒通過。fixture為State子類執行正式extension，不掛widget／Player／IRC，不能算完整訪客watch；factory依賴隔離、現在請求失敗／更多競態與原生恢復重疊仍待补，debug慢幀保留。未動token儲存／協議／UI或真實帳號，完整目標進行中。

- 訪客Browse／搜尋兩實際卡片tap，正式Navigator route builder建立WatchRouteGuard的頻道／標題／broadcaster／同discovery與訪客auth／未知追隨狀態交接通過。觀看頁掛載前移除測試路由，返回公開卡仍可用、validation／Helix零請求；不算watch掛載／chat／解碼或完整訪客App完成。home17＋session35＋following30聯合82項通過，唯一home測試analyze6.5秒No issues found。正式程式未改，不連真實IRC／Player，不動帳號；下一步須隔離watch startup與輔助auth／chat依賴，完整觀看／捷徑／原生恢復重疊仍待補。

- 訪客完整首頁新增實際搜尋頁按重試恢復、換query後舊成功／失敗不覆蓋新結果、清除後舊成功不還原、離頁後舊成功／失敗無未處理例外，以及root換身分後舊驗證一般失敗不蓋掉新登入。七案配合既有fixture，home15＋session35＋following30聯合80項通過，唯一home測試analyze6.4秒No issues found；不等同正式library／全專案乾淨，既有import info保留。訪客validation／Helix零請求，未改正式程式／UI／協議、未啟動真實App，不把回應淘汰算HTTP取消或一般錯誤算401／403完成。訪客watch／捷徑與原生恢復重疊仍待補，完整目標持續。

- 正式首頁非空公開／追隨卡片、訪客實際toolbar輸入／搜尋／清除返回、同State登入轉追隨／登出回公開卡通過。新增root初始驗證pending换身分案重現loading持續true；正式_loadLoginState改身分通知replacePending取代旧讀取並以loadId保護提交、catch与收尾，新身分不等舊Completer即可完成。home8＋session35＋following30聯合73項通過。新home兩info清理，唯一analyze6.7秒無error／warning、只剩既有stream page4:8 unnecessary_import；不反覆analyze。預設真實FOLLOWING_ENTRY編譯33.9秒、23秒exit0，追隨第一卡／chat／解碼／15秒通過，debug慢幀仍存在。未改憑證／協議／UI，訪客watch／快捷入口、搜尋失敗競態與原生恢復重疊仍待補。

- 正式完整首頁可注入一致帳號／discovery依賴，保留原預設建立與啟動流程。新home4案掛載正式root＋Browse／Following，fixture隔離憑證、傳輸、prefs與平台；guest首頁讀取結束但session仍checking已重現，session constructor依既有token空值初始化guest／checking修復，不動憑證儲存。guest／有效follows／缺scope／pending四案與既有兩檔共69項通過；公開fixture為空，不當成非空卡片／watch／捷徑完成。預設未注入的真實FOLLOWING_ENTRY編譯34.0秒、23秒exit0，預設追隨第一卡／chat／解碼／15秒通過。唯一analyze6.5秒無error／warning、3 info（新home11:8 unnecessary_import、129:9 curly_braces；既有stream page4:8 unnecessary_import），未反覆修lint，下一輪清理新測試info。真實登入未更動，慢幀、完整訪客路由與恢復重疊仍待補。

- 身分通知修正後FOLLOWING_ENTRY＋LIVE_ROUTES真實Windows回歸編譯34.3秒、1分5秒exit0：預設追隨第一張卡直入對應watch、chat／解碼／15秒通過；返回原home、mini三種拖50px回位與持續播放、展開fresh chat／owner、關閉pause、另一首頁卡新上游／proxy／owner／URI及15秒通過。兩watch左欄各12次幾何穩定，未啟用RAIL_SWITCH。唯一既有兩正式檔＋兩測試analyze6.2秒No issues found；正式程式與入口未改。debug仍有慢幀，不算效能／黑畫面結案；訪客完整首頁、keep-mini=false、原生open重疊仍待補，完整目標持續。

- 訪客轉有效身分無reload仍停checking，以及初始pending换帳號未啟動新讀取兩案已重現並修正。共用session新增既有generation的唯讀identityRevision；Following版本變更即清除重讀，不另判token，驗證成功版本不變避免自我重載。新帳號在舊驗證未完成前用viewer99請求，舊完成不覆蓋；pending登出在舊完成前guest／零請求、晚到成功不還原；版本遞增規則通過。session35＋following30聯合65項通過，唯一四檔analyze6.6秒No issues found。未改憑證政策／UI／播放runtime或真實帳號，正式子頁接線不等同完整首頁／watch／快捷入口，完整目標仍持續。

- 無首頁reloadTick時舊追隨卡殘留的訪客／缺scope兩案已重現並修正；正式Following頁訂閱共用session，已有清單身分變更時立即清除重載，不新增token或登入決策。四分支（有／無reload）與監聽換服務／dispose生命週期通過，session31＋following30聯合61項通過；唯一三檔analyze6.5秒No issues found。這是已載入清單的正式子頁通知接線，不是完整首頁／watch／快捷入口或初始pending身分切換；訪客轉登入无reload仍待補。未動真實憑證、UI或協議，完整目標仍進行中。

- 同service／同Following State收到reloadTick後，訪客或新缺scope帳號仍保留舊追隨卡的兩案已重現並修正。正式頁面以共用session快照隔離已載入清單；身分／權限改變先清除舊直播、離線與cursor，再走原刷新，不改登入／協議／UI。session29項與既有following29項聯合58通過；舊fake缺cachedAuth首跑失敗，補記憶體fixture後通過。唯一三檔analyze6.6秒No issues found（含前輪HTTP格式切換），之後fake介面補齊僅編譯／測試，下一輪補靜態檢查。這是首頁reload訊號至正式子頁的隔離回歸，不是完整App訪客／登入路由或無reload即時清除，真實帳號未登出，完整目標持續。

- TS來源clip→mini→live真實回歸編譯35.1秒、28秒exit0，解碼／十秒前進／owner及URI保留通過、native失敗分類空；清單無所檢查廣告標記，DATERANGE=true不單獨算廣告。native接手時恢復已完成，不能算open內部重疊；debug仍有慢幀。HTTP初始化三案新增MP4→TS→原map MP4，新client在TS不帶舊init、回MP4再先收init；聯合16項通過，不是原生解碼／真實廣告證據。首次指令檔名錯誤更正後重跑通過，正式程式未改。唯一五檔analyze7.0秒No issues found補前輪session頁面；後續fixture擴充只測試編譯通過，下一輪補靜態檢查。完整訪客路由、原生重疊與黑畫面限制保留。

- 完整DVR返回門檻補非緩衝實際解碼、十秒增量>7秒及playing／buffering檢查。相同四旗標真實回歸編譯34.2秒、4分44秒exit0，45秒增45633ms、暫停跳轉／方向鍵／重複方法跳轉通過，120秒增121649ms，返回解碼與十秒增10017ms／非緩衝通過。另新增正式Following缺scope頁面測試：authenticated不改guest、零請求、不自動登入，點fake授權後取得權限再實際點重新檢查才讀取；session全檔27通過。唯一整合analyze6.9秒無error／warning、3既有info；docs新增後只測試驗證，下一輪补analyze。正式程式未改，單一頻道不算完整範圍完成，完整App訪客路由仍待補，debug仍有慢幀。
- 初始化HTTP fixture擴0／2／14次503三案皆通過，map GET總次數2／4／16，包含一次重試批次用盡後重新載入與新init送late client。唯一analyze正式proxy library＋fixture3.1秒No issues found。修正後完整DVR四旗標Windows回歸編譯34.4秒、4分44秒exit0，fMP4 init1125bytes、暫停恢复45秒增45600ms、UI暫停跳轉保持暫停與恢復十秒、左右鍵新generation／目標<2秒／十秒、1/3及2/3方法跳轉各十秒、120秒增121549ms均通過；返回live十秒position增加通過，但舊門檻偏弱，下一輪補明確解碼／增量>7秒與非緩衝要求。不是所有頻道、拖曳、真實斷網或間歇黑畫面結案；debug慢幀仍存在，正式程式本輪未改。
- 初始化HTTP接線新增正式proxy隔離執行緒＋本機上游fixture：writer第4段後才連入、第5段重連皆init＋目前段；map更新後新client收到新init，同map僅GET一次、兩版本共兩次。接線1＋bus2＋open race7＋diagnostics4聯合14項通過，案例約3秒；唯一analyze正式proxy library與init測試3.1秒No issues found。VOD→live真實編譯33.7秒、29秒exit0，解碼／10秒／URI與owner保留通過、分類空；接手時native open已完成，非內部競態證據。正式程式本轮未改，保留先前黑畫面限制；map下載失敗／半包時點、長測、完整DVR與訪客路由仍待補，debug慢幀仍存在。
- 直播初始化replay缺失已隔離重現並修復：writer每段清空bus replay但只寫一次map，晚連入client缺初始化；bus改獨立保留map並先送新client，更新時送現有client、TS清除，writer成功載入才記住map。修正前clip→live真實90秒黑畫面，afterMount read_failed=2／format_unrecognized=1，來源206／4096bytes、MP4＋init、無AES／BYTERANGE標記；代理仍輸出78秒。兩bus＋四診斷6項通過，修正後編譯33.9秒、真實28秒exit0，解碼／10秒／URI與owner通過，失敗分類空。單次真實回歸不算所有黑畫面完成；下一輪補writer HTTP接線與多時點回歸。唯一analyze在正式修正前7.2秒無error／warning、3既有info，正式修正後只測試／编譯驗證，下一輪補analyze；debug慢幀仍存在。
- 新增原生日誌固定category計數，不保存原文／URL；整合分route建立前後，10秒與finally輸出，快速成功也有摘要。helper兩項＋競態七項共9通過；處理docs測試用途warning後唯一analyze6.9秒無error／warning、3既有info。真實clip→live兩輪编譯34.5／34.7秒、各28秒exit0，解碼／10秒／URI／owner通過；第二輪beforeMount／afterMount皆空，native接手時open已完成，僅成功比較基準。正式播放未改，不以兩輪通過宣稱先前黑畫面修復；下一輪取得失敗分類、核對代理格式／讀取。finally摘要追加後僅编譯驗證，黑畫面與debug慢幀保留未定位。
- 過期native open完成會覆蓋來源狀態已由隔離Player兩案重現並修復：共用request revision與player身分防護，pause／stop／dispose取消晚到提交，不更改原生open排程。新增7項＋既有18項聯合25通過、約5秒exit0。唯一analyze4.5秒無error、2項docs測試使用visibleForTesting warning，下一輪局部註記。真實clip→live回歸編譯35.2秒、1分46秒exit1，90秒position0／buffering、idle-active=yes，代理writer／client存在且輸出增到78秒；舊恢復已完成、owner／URI正確。黑畫面期間10至90秒清單均HTTP200／HLS、stitched-ad=false／DATERANGE=true／DISCONTINUITY=false／SCTE35=false，沒有特定廣告標記，仍不排除未標記廣告。狀態競態修復不等於黑畫面修復；下一輪補原生格式／讀取失敗分類。僅修改PlayerHost、隔離測試与紀錄，帳號協議／UI不變。
- 原生恢復open新增預設關閉的去敏計數與整合嚴格斷言。真實clip→live編譯35.0秒、測試29秒exit1；新直播解碼／10秒>7秒／URI與owner保留通過，native atClick／Mount=true、atNewOwner=false、開始／完成各1，嚴格native重疊斷言失敗。首次區分真正open與恢復future的等待，仍未驗證接手時的native競態；下一步以可控原生open隔離測試檢查晚到狀態提交。唯一analyze6.9秒無error／warning、3既有info；不改開啟順序或協議。黑畫面仍未定位，debug仍有慢幀。
- 自然恢復切換剪輯／VOD兩輪：不使用pre-open閘門，編譯35.2／35.1秒、測試31／29秒皆exit1；新直播解碼、10秒增量>7秒、URI／owner保留通過，但pendingAtClick／Mount=true、pendingAtNewOwner=false，嚴格接手重疊斷言失敗。這是測試未撞到所需時點，不判正式故障，也不列native open內部競態通過。兩成功播放清單皆HTTP200／HLS、stitched-ad=false／DATERANGE=true，黑畫面廣告假設仍未證實。下一步補原生open開始／完成觀測與可控開啟等待，不靠延長恢復future冒充；正式程式／測試未改、未跑analyze，完整目標仍進行。
- 無archive候選改用loadedStreams並合成捲動至匹配卡片：十二台皆growingArchive=true的首輪6秒exit1後，取消上限，本次21台中index12候選成功，watch確認hasArchive=false。真實回歸編譯35.4秒、測試2分40秒exit0，120秒增121816ms、最長停滯0、lag漂移1ms、20秒窗口／slider約0.39965比例通過、控制列外框位移0，返回live解碼與10秒持續播放通過。僅單一無archive樣本，非所有頻道／內部字元幾何或間歇黑畫面修復。唯一analyze6.8秒無error／warning、3既有info；只改測試與紀錄，正式播放未改，debug仍有慢幀。
- 無archive測試入口已新增：候選回放唯讀篩選、watch實際無archive確認、20秒窗口與slider比例對應斷言。兩輪候選前置條件失敗（編譯37.2／35.1秒、測試4／5秒exit1），六個已建立卡片皆growingArchive=true；提高上限12仍只有六張Widget，未取得十二台或無VOD播放證據，不當正式故障。下一輪需用loadedStreams候選並捲到對應卡片。唯一analyze7.2秒無error／warning、3既有info；只改測試，正式程式未改，完整無VOD回歸仍未完成。
- 短回看長測門檻補強：總增量改>觀察時長75%（120秒需>90秒），要求控制列／lag真的取樣、秒級連續停滯不超過3次、結束非緩衝；返回live新增解碼及10秒增量>7秒／非緩衝。真實回歸編譯34.4秒、測試2分37秒exit0，120秒增122183ms、最長停滯0、lag漂移0、控制列位移0，返回live新增斷言通過。hasArchive=true、非無VOD／所有頻道證據；仍有debug慢幀與未定位黑畫面。唯一analyze6.3秒無error／warning、3既有info，正式程式未改。
- 追隨第一台短回看120秒真實觀察：編譯34.0秒、測試2分27秒、exit0，首頁第一卡與直播相符、chat／live通過，usingLiveBufferReplay確實解碼。120秒增121733ms、每10秒未緩衝，edge落差固定12173ms，控制列高度／上緣差0；返回live狀態通過。hasArchive=true，非無VOD樣本；slider比例非20秒窗口證據，返回後持續播放仍需補。現有進度斷言固定>45秒，需下一輪按觀察時長比例化，不能僅依綠燈判定120秒穩定。正式程式／測試未改，未跑analyze，間歇黑畫面仍未定位。
- 新增完整DVR實際拖曳分支：首輪live初始解碼60秒不前進，測試1分15秒exit1，拖曳尚未執行；補該失敗點去敏原生／proxy／清單標記診斷，不改正式播放。第二輪1分49秒exit0，45秒恢復增45566ms，合成按下／移動／放開至比例0.30與預覽5055213ms，新來源解析誤差<2秒、解碼後10秒持續及返回直播10秒通過。單一完整DVR fMP4證據，不替代VOD／clip／20秒窗口或所有頻道；首輪初始解碼間歇問題未定位。唯一analyze7秒無error／warning、3既有info，追加診斷後僅編譯／整合驗證。
- 最新完整DVR真實回歸：四分支FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR，編譯34.4秒、測試4分44秒、exit0。fMP4樣本完成唯讀chat／live、DVR恢復45秒增45550ms、UI暫停跳轉保持暫停與canonical目標、UI恢復10秒、左右鍵各新generation／目標誤差<2秒／10秒播放、1/3與2/3各10秒、120秒增121650ms、返回直播10秒。長測每10秒取樣未緩衝；extended build P95=13363us仍8幀逾33.333ms，不宣稱無卡頓。未改程式／測試，未跑analyze；多頻道／新格式／真實斷網／拖曳手勢及clip→live黑畫面仍待驗證。
- 共用session新增3項通知回歸：fake auth發ChangeNotifier後立即guest／snapshot空；等待中的舊驗證晚到成功／401都不能恢復身分或再通知；換帳號先checking／清空舊snapshot，再驗證公布新身分。session檔26項，與聊天面板／離頁生命週期聯合34項通過、2秒、exit0。前輪mock偏好測試warning以局部測試用途註記處理；唯一analyze兩入口6.5秒無問題。正式程式與憑證儲存未改，完整watch路由通知及IRC換帳號重連仍需補，不以分層測試替代完整接線。
- 聊天面板旗標測試由guest／非guest擴為checking／guest／authenticated／sending，實際按鈕驗證停用、假送出／登入回呼；authenticated再於同一正式面板State切checking→guest→authenticated，顯示與送出狀態即時更新、不自動登入、不需重建。sending中途pumpAndSettle因無限動畫逾時，改有界pump；三檔聯合12項通過、2秒、exit0。唯一analyze6.6秒、exit1，1項docs mock偏好測試用途warning，無error；下一輪處理局部註記。只驗證傳入旗標後正式面板反應，非shared session／完整watch路由／真實登出矩陣，正式程式未改。
- 畫質選單onChanged=null仍顯示可選已由實際展開widget重現（6項中1失敗）；正式QualityButton讓非空項enabled與回呼可用性連動。新增6項涵蓋可用／不可用／空清單、overlay忙碌／已選防重按、關閉、240×180捲至音訊選項；聯合既有控制列共19項通過、5秒、exit0，唯一analyze2.9秒無問題。無原生播放／網路／偏好寫入，真實畫質切換與黑畫面仍待驗證，不改runtime或排版。
- 廣告診斷續測：真實Windows剪輯→mini→首頁另一直播，舊恢復受控pre-open等待；兩次編譯34.5／34.8秒、測試28／27秒皆exit0，pendingAtClick／Mount／NewOwner全部true，放行後新來源保留且10秒前進>7秒。成功樣本皆HTTP200／HLS、stitched-ad=false／DATERANGE=true，沒有黑畫面當下廣告證據，原間歇黑畫面保留未定位。未改正式程式／測試，未跑analyze；矩陣「DVR暫停跳轉」依既有完整長測通過紀錄校正，不冒充本輪重跑。
- 聊天 connectChat 驗證等待中離頁，再晚到失敗會由 finally 通知已釋放 controller，把原 StateError 蓋成 FlutterError；隔離測試已重現並補 disposed 防護。晚到成功／失敗兩項及既有聊天鍵盤／訪客測試聯合10項通過、3秒、exit0，不建立真實 IRC。唯一 analyze 5.6秒、exit1，無 error／warning，1項 unnecessary_underscores info。並行 connect、完整登入路由與直播黑畫面仍未驗證完成，不修改憑證／IRC 協議。
- 新增4項登入狀態探索頁面測試：正式Browse／Following與DiscoveryService／ViewerSession配合隔離auth及回應。公開卡片在guest／checking下均完成載入，不觸發登入；following checking不顯示登入要求，valid完成才發讀取；guest實際點登入按鈕才呼叫假登入。session檔23項，與guest mode／guest media／following page聯合59通過、2跳過、4秒、exit0；兩項真實匿名API因未開旗標跳過，不列完成。唯一analyze6.5秒無問題，後續fixture強化以編譯／測試驗證；正式程式未改，完整App路由矩陣仍未完成。
- 私訊尾端捲動測試固定失敗來自 fake threads 完整清單未含選中 peer 2，正式快取清理後列表消失。只讓此測試的 fake 清單包含 peer 2，保留原捲動與同步斷言，新增 active peer／列表存在檢查；單項通過，完整 inbox 171項兩次各20秒通過。尚未儲存狀態桌面／手機兩項單獨通過；原間歇溢位及cache計時器未定位，不算修復。正式私訊程式未改，唯一 analyze 4.8秒、No issues found。
- App 設定既有 ListTile 警告已定位到 Android 帳號頁背景收件開關，增加局部透明 Material；沒有改背景服务。整合 widget 測試明確分 Windows 900×700／Android 320×640，確認平台可見性、無框架例外，聊天鍵位 H 透過正式 controller 保存至 mock storage。中途測試平台 override invariant 失敗已由 finally 清理修正；最新測試通過、exit0，唯一 analyze 兩入口5.3秒、No issues found。此為平台 override／模擬儲存，不等於原生 Android 背景服務或實際設定驗證。
- mini 播放網址身分比對固定失敗已修：修正前 playback session state 測試13項通過、1項失敗，原因為 isActiveMediaUri 只 trim 查詢參數而不 trim entry.mediaUri。現在兩邊都 trim 首尾空白，保留原 playback 物件及完整 query。新增 live／liveDvr／VOD／clip 四項 padded URI 案例，包含 query generation 不同、query 缺失、空白／null 拒絕；最新18項全通過、exit0。此為無 native Player 的狀態回歸，不等於黑畫面已修。本輪唯一 analyze 兩入口4.1秒、exit0、No issues found。
- 廣告假設增加唯讀清單標記探測：最新 clip→live 27秒通過，成功樣本 HTTP 200、HLS=true、stitched-ad=false、DATERANGE=true；一般 DATERANGE 不作廣告判定，來源 hasAds 也不是當下廣告證據。黑畫面時的廣告／native 診斷仍待取得，沒有修改正式廣告或播放邏輯。
- 黑畫面去敏重現：clip→nix 的新直播90秒 position=0／buffering，代理 writer=true、clients=1，分段輸出累計前進至78秒，仍需定位代理到 native 的讀取／解碼；相同流程下一輪27秒通過，屬間歇成功而非修復。新增 native 快取／影像數值屬性白名單及 log 關鍵字計數，沒有保存簽名網址／憑證或修改正式播放行為。
- 最新受控 pre-open 恢復重疊：VOD→另一直播通過，新 owner 接手時舊 future 仍 pending，待新來源解碼後放行，來源保持且10秒前進。clip→另一直播失敗：新直播90秒持續 buffering、position=0，舊恢復尚未放行，不能歸因舊來源搶回。黑畫面根因仍待上游／代理／解碼去敏診斷；不宣稱 native open 內部競態或完整恢復已完成。
- 新來源替換舊mini的狀態殘留已重現並修正。原本新live已playing、非buffering、owner／URI匹配，但miniActive=true，導致兩輪1分46秒／1分45秒逾時。新watch非reuse來源改在post-frame清除仍相同的舊entry；mini恢復完成後確認entry／session仍相同才seek。同步init清除的中途版本造成建構期setState及90秒buffering，已改post-frame，不把中途結果抹掉。
- 最新真實來源替換回歸編譯32.6秒、測試29秒、exit0，mini退出、新source解碼、owner／URI／upstream匹配且10秒前進>7秒。pendingAtClick=true，但pendingAtMount=false／pendingAtNewOwner=false，所以只證明來源替換，不算重疊競態完成；新增TWITCH_READONLY_REQUIRE_RECOVERY_OVERLAP=true可要求重疊斷言，未默認把未重疊樣本当成功競態。
- 本輪唯一analyze三入口5.8秒、exit1：無error／warning，4 info（整合18:8 unnecessary_import、1901:34／1930:26 prefer_collection_literals；watch549:11 curly_braces），post-frame後修僅經最新整合編譯／執行驗證。完整目標持續，下一輪補可控制的恢復延遲及既有固定失敗。
- 修正後最新Windows直播路由回歸編譯32.8秒、測試1分17秒、exit0：video-touch／video-mouse／footer-mouse皆位移50.00px且回位0.00px，failedSamples=0；拖動後播放前進、展開fresh chat、close／pause、首頁及追隨欄跨頻道來源／owner／聊天與各15秒前進全部通過。影片區先前0px失敗已由同範圍實際回歸驗證修正，不宣稱原生實體滑鼠或所有視窗大小已覆蓋。
- 瀏覽頁增加刷新期間及generation防護，忽略舊分頁成功／失敗，來源物件替換會重載；分類初始載入失敗改為重試首頁；語言ListTile補局部Material以避免背景／水波紋框架警告。
- 媒體庫依ID去重，來源／頻道替換增加generation防護並重載，極矮視窗取消無效的360像素clamp下限。更新下載progress、下載完成後啟動installer與finally增加dispose防護。
- browse 21項、channel media 22項、update controller 9項，共52項測試修正後兩次全數通過，不重複計數；第二次4秒、exit0。這是隔離widget／mock，不等於真實帳號或OS更新安裝。
- 迷你播放器新增playOnOpen記錄縮小前playing，開片及回前景保留暫停；影片子surface IgnorePointer且外層GestureDetector opaque接收整片操作。實際VOD／clip PAUSED流程最新測試34秒、exit0：UI pause→Home→mini仍paused且2秒位置差<500ms，手動play後mini前進、展開同片／位置接續及close皆通過。只證明縮小暫停保留，不包含未恢復就展開的暫停延續。
- 第一輪真實回歸抓到間歇disposed的具體物件TwitchWatchRelationshipController（notifyListeners、原137行）。修正dispose／reset後拒絕晚到query或mock follow成功／失敗及callback；新增8項lifecycle隔離測試全部通過。未發真實追隨寫入；後續真實VOD／clip通過不代表其他未知disposed原因全部排除。
- 本輪唯一analyze七個入口檔無error／warning、3 info（整合檔18:8 unnecessary_import、1886:34／1915:26 prefer_collection_literals），7秒、exit1。其後relationship修正與opaque點擊修正僅有測試編譯／執行證據，未重跑analyze。
- 被中斷的恢復中換來源測試未取得有效結果，只返回測試runner暫存檔PathNotFoundException；保留待驗證，不當成正式App功能失敗或通過。

第十三批續測（受控恢復中關閉mini）：

- 新增TWITCH_READONLY_MINI_RECOVERY_CLOSE。32999初版編譯37.9秒、測試28秒、exit0，但只量pendingAtClick，不能单独證明close生效仍重疊。補controller listener在mini entry清空通知時量pendingAtClose；81264編譯38.4秒、測試27秒、exit0，VOD及clip皆pendingAtClick=true／pendingAtClose=true。
- 81264兩種真實解碼媒體各先Home到mini、3秒前進，再rememberNetworkLoss／recoverAfterNetworkRestored未await並點正式close按鈕；恢復future完成無錯，等待3秒miniActive=false／playing=false，playableState=null。證明本輪兩個樣本受控恢復future與close重疊後未復播，不代表任意network時序、換來源競態或真正OS斷網已驗證。close分支刻意不展開，不能算新增展開證據。
- 唯一analyze無error／warning、3 info（18:8 unnecessary_import；1758:34／1787:26 prefer_collection_literals），7.2秒、exit1；其後增加close通知觀察器只以81264編譯／執行驗證，未重跑analyze。未改正式功能、偏好或憑證；disposed與clip decode間歇失敗仍未修／未定位。

第十二批續測（clip恢復通過與間歇disposed例外）：

- 同一MEDIA_MINI／MINI_PAUSED／MINI_RECOVERY流程兩輪：31644編譯40.1秒、測試31秒、exit1；74584編譯38.6秒、測試36秒、exit0。第二輪只增加去敏exception類型／檔名行號診斷，未修正式程式，不把重跑通過當例外修好。
- 本輪clip初始decode皆通過；兩種媒體皆實際pause UI→Home觀察mini自動播放。VOD受控恢復／展開／close两輪通過；clip受控paused恢復保持暫停、playing恢復forceOpen同來源／位置差<10秒／3秒前進兩輪通過。74584亦完成clip再3秒mini前進、展開同片／kind／URI／位置接續、再次Home／close／pause全部通過。
- 31644在clip受控恢復通過後、後續mini前進完成前捕捉FlutterError flags=disposed，尚無物件類型或source stack。74584未重現，所以正式生命週期原因仍待定位；29147上輪clip source decode逾時也保留為間歇未解釋失敗。
- 唯一analyze8.1秒、exit1：無error／warning，3 info（18:8 unnecessary_import；1693:34／1722:26 prefer_collection_literals）。其後追加exception診斷只由74584編譯／執行驗證；不重跑analyze。這是受控入口，不是實際斷網／網路事件接線證據。

第十一批續測（暫停handoff與受控恢復）：

- 29147 Windows MEDIA_MINI／MINI_PAUSED／MINI_RECOVERY整合整體失敗：編譯38.5秒、測試1分55秒、exit1。VOD完整執行，clip初始source decode等90秒逾時，未執行clip暫停／mini／恢復；前輪clip短返回通過仍保留，不替代本輪失敗。
- VOD實際點pause後Home，觀察mini自動恢復播放；不是「暫停狀態保留」通過。正式mini openOrResume(play:true)與此現象一致，未改正式功能／偏好。後續在mini中透過原生player.pause，再rememberNetworkLoss／recoverAfterNetworkRestored，1秒仍暫停且位移<500ms通過；原本播放時記錄loss→pause→recover強制重開，原URI保留、位置差<10秒、再3秒前進>1秒通過，並通過展開／接回／close。
- 受控恢復是直接呼叫正式controller且使用真正原生player／網路開片；沒有斷OS網路，不代表網路通知接線、真正401／503或斷線恢复完成。clip初始失敗根因未定位，後追加每10秒布林／位置解碼診斷尚未編譯執行。
- 唯一analyze無error／warning、3 info（18:8 unnecessary_import；1685:34／1714:26 prefer_collection_literals），7.6秒、exit1；診斷後追加未重跑。完整DVR、keep-mini=false及真實斷線仍待測。

第十批續測（VOD／clip mini 真實返回通過）：

- 補正式播放快照extension import後，92522 Windows整合 TWITCH_READONLY_MEDIA_MINI=true 完整通過：編譯44.5秒、測試27秒、exit0。沿用既有帳號、公開搜尋選頻道，同一App依序完成VOD與clip，不做帳號寫入／憑證修改。
- 兩種類皆真實解碼→點Home到mini→保持kind／URI／VOD或clip ID→mini播放3秒且前進>1秒→點影片展開成新watch→mini退出、同來源／kind、接回位置差<10秒→再3秒前進>1秒→第二次Home→close且shared player不再playing。正式route guard直入，並非本輪新媒體卡導頁證據。
- 單一完成VOD及單一40秒以上clip的短返回样本，不宣稱完整DVR、暫停狀態handoff、keep-mini=false、長播放／結尾／網路恢復或所有媒體來源完成。前輪影片區拖動兩失敗仍保留。
- 唯一analyze已無error／warning；3 info（unnecessary_import 18:8，prefer_collection_literals 1616:34／1645:26），8.5秒、exit1。整合編譯與執行通過，不把有info的analyze寫成exit0。

第九批準備（VOD／clip mini 真實返回）：

- integration_test/twitch_readonly_app_test.dart 新增 TWITCH_READONLY_MEDIA_MINI 與獨立 exerciseMediaMiniRoutes：預計同一 App 讀取完成 VOD／40秒以上 clip，正式 route guard 直入、控制列 Home 接 mini、metadata／kind／URI、3秒前進、點影片展開後位置連續及 close／pause。這是新測試原始碼，尚未編譯執行，不計通過；直入不替代媒體卡導頁驗證。
- 唯一analyze失敗：兩個 undefined_method，buildPlaybackSnapshot缺 extension import（517:25、560:21）；另兩則既有prefer_collection_literals info（1615:34、1644:26），8.6秒、exit1。依規則未反覆修正／重跑。下一輪先引入正式 twitch_watch_playback_state.dart 的 extension，再執行此新旗標；所有VOD／clip mini解碼返回仍待驗證。

第八批續測（拖动目標差異與完整直播路由）：

- 74797 Windows 真實整合：編譯54.9秒、測試1分23秒、exit1。補影片區touch／mouse及資訊列mouse合成事件、數值位移與finally放開；保留失敗至流程末尾，不以繼續測後半掩蓋拖動失敗。
- 影片區touch、mouse皆movedPixels=0.00／returnPixels=0.00；資訊列mouse movedPixels=50.00／returnPixels=0.00。只有影片區兩樣本失敗，資訊列拖動／回位通過，三次手勢後原媒體identity保留且播放持續前進。整卡並非完全不能拖，尚未證明原生實體滑鼠與合成事件結果一致，也未確認哪個內層recognizer接收pan。
- 本輪後半實際執行通過：mini展開、新watch／新chat、原媒體接回、3秒前進、回首頁／close／pause；首頁另一頻道新來源與15秒前進；追隨欄跨頻道替換、新舊聊天生命週期、來源／owner匹配、選中標記與再點不重開、另15秒前進。三個watch窗口各12次側欄offset取樣穩定。最终僅dragFailures非空斷言失敗，不宣稱整體綠燈。
- 唯一analyze無error／warning、2則prefer_collection_literals info（1452／1481行），12秒、exit1。本輪未改正式功能、使用者偏好或帳號憑證；未重跑60秒性能觀察，keep-mini=false、其他播放種類返回與真實網路恢复仍待測。

第七批續測（Windows 真實迷你播放器拖動）：

- 使用者允許整合測試檔及本輪必要範圍。擴充 integration_test/twitch_readonly_app_test.dart，透過 Flutter 合成事件驗證影片區拖動位移、放開回位及播放前進；未修改正式 UI、播放器或憑證。
- 37032 真實流程整體失敗（執行 1 分 33 秒，exit 1；另編譯 59.1 秒）：登入首頁追隨／第一卡頻道一致、聊天連線、15 秒播放、60 秒六次控制列點擊通過；60 秒觀察進度增加 62,450 ms，取樣停滯／緩衝皆 0。build P95 11,017 us、70 幀 >33.333 ms、最大 81,078 us；raster P95 10,979 us。不代表 profile 或卡頓完全排除。
- 回首頁、舊聊天斷線、mini 解碼與 3 秒播放前進通過；新增影片區 drag 的位移 >10 logical pixels 斷言失敗。補第一段移動跨越 pan slop 後，79854 定向流程仍在同一位移斷言失敗（31 秒，exit 1；另編譯 53.8 秒）。尚未取得精確位移數值與事件接收者，保留正式互動／合成事件路徑待定位，不宣稱 mini 一定不能拖動。
- 本輪兩次均未到拖動後回位、播放、展開、跨頻道斷言；舊輪成功不能冒充新版拖動流程通過。真實 App 的測試結束由 runner 關閉，不是人工逐頻道重開。
- 唯一 analyze：無 error／warning，兩則 prefer_collection_literals info（當時 1415／1444 行），14.8 秒、exit 1。後加三行手勢門檻程式只以第二次編譯／執行驗證，未再 analyze。

第六批續測（迷你播放器／路由狀態）：

- 新增docs/twitch_playback_session_state_test.dart，14項13通過／1失敗，exit1；兩次執行結果相同，不重複計數。只測正式state controller與entry，不建立Player、不acquire原生session、不發網路、不改使用者keep-mini偏好。
- 通過範圍：live／liveDvr／VOD／clip的revision、metadata、DVR/VOD/clip來源、ratio與回放聊天偏好；空entry不覆蓋既有；close(false)保留session、close(true)清除session；null/empty URI拒絕；無原生Player時network recovery不建立Player。路由owner隱藏回應不改頂層、移除隱藏owner不恢復、pop跳過不可播放owner還原先前snapshot、最近restore callback只執行一次、hidden invalid不清visible皆通過。
- 失敗：Mini.show傳入' fixture-live '後，isActiveMediaUri('fixture-live')為false。showPlayback只用trim判空與debug輸出，entry保留原始URI；identity比較只trim查詢值。正式程式未改；session controller平常會先trim，未證明一般App會實際傳入空白或因此停播。
- 仍需keep-mini=false真正離頁分支、實際mini拖移／surface移交、DVR/VOD/clip解碼後接回、原生播放中網路恢復與route guard互動。不能以此14項state測試宣稱迷你播放器全流程完成。
- 此回合唯一analyze新測試：No issues found，8.9秒、exit0。

第五批續測（分類／語言與合成捲動）：

- 本輪只擴充 docs/twitch_browse_page_flow_test.dart。新增7項定向執行4通過／3失敗；整檔最新版21項15通過／6失敗（6秒、exit1），包含前輪3個固定失敗，不把定向重跑另加總。
- 新通過：1000／390寬的官方分類sheet搜尋、選分類、清回全部，API的game參數與頁面選中值一致；分類grid實際合成drag到底，失敗保留30筆、點可見重試後去重成31筆且cursor耗盡；公開瀏覽grid實際合成drag到底，下一頁失敗保留100筆、點可見重試後101筆／耗盡。入口是測試自有按鈕呼叫正式公開showGameMenu／showLanguageMenu，不當成真實首頁工具列接線驗證。
- 新失敗：分類初始載入失敗，sheet 的可見重試只呼叫loadMoreGames；此時nextGameCursor=null，直接返回且不發新請求（期望第3次，實際仍2次）。尚未修正式功能。
- 語言sheet兩個寬度皆失敗：選中zh／取消不重新讀取／清全部語言的狀態與請求斷言有執行，但takeException抓到多則ListTile背景／水波紋被中間DecoratedBox遮住的框架警告。不能算整體通過；同类問題前輪在設定頁也出現，不聲稱release會崩潰。
- 本輪唯一analyze新擴充的browse測試無error／warning、1 info（312:11 curly_braces_in_flow_control_structures），9.9秒、exit1，未重跑。

第四批續測（公開瀏覽完整頁與來源替換）：

- 新增 docs/twitch_browse_page_flow_test.dart，共 14 項：11 通過、3 失敗；擴充媒體檔兩個 source replacement 案後 22 項：17 通過、5 失敗。最新合併執行 28 通過、8 失敗（5 秒、exit 1）。中途 browse 10／1 不重複計數，媒體既有 17 通過／3 失敗是重驗而非新增覆蓋。
- 瀏覽頁通過：1000／390 寬公開卡片且未呼叫登入；模擬 TwitchApiException statusCode 401／503 後點重新整理恢復；已載入內容的搜尋空結果與搜尋錯誤有不同提示；離頁後初始成功／錯誤被忽略；新 refresh 拒絕舊初始成功／錯誤；100→101 的重疊 ID 分頁去重與 cursor 耗盡。搜尋文字由父元件參數提供，分類／語言／首頁搜尋輸入仍待測；分頁時鐘案例使用公開 state 方法控制順序，不冒充捲動手勢。
- 瀏覽頁新增固定失敗：舊 loadMore 在新 refresh 完成後成功會把 stale0／stale1 混入 fresh0／fresh1；舊 loadMore 失敗會設置新畫面的 paginationError。refresh 本身有 generation 防護，loadMore 只有 mounted 判斷，尚未修正。
- 來源替換三案失敗：保留相同 page State、reloadTick=0 但替換 discoveryService 時，browse 不請求新來源，媒體 VOD／clip 也不請求新來源，仍保留舊內容。這是來源物件替換的 widget 契約測試，不是實際帳號／頻道切換已重現；同一 authService 改身分及首頁 reloadTick 行為仍需另外驗證。
- TwitchStreamPage 直接建構各項服務，沒有 fake 注入入口。本輪只測正式 TwitchBrowsePage／TwitchChannelPage，不以此聲稱完整首頁啟動、訪客 App 路由、登入切換或媒體播放完成；正式程式未修改。
- 本輪唯一 analyze 兩份測試：無 error／warning，1 info（媒體 helper 的 public API 使用 private fixture type，當時89:3），11.3 秒、exit 1，未重跑。

第三批續測（既有輪次保持原始結果）：

- 聊天 mention、訊息快捷鍵、鍵位保存、Android background 四份隔離測試共 29 通過（5 秒、exit 0）。覆蓋編輯框／重複鍵／修飾鍵不誤送動作、長清單鍵盤導航、保存失敗與晚到回應、Android 拒絕權限不保存啟用及 Windows 不呼叫 Android plugin。平台 override／假的 MethodChannel 不當成原生實機驗證。
- 新增 docs/twitch_channel_media_page_test.dart，完整 TwitchChannelPage 與 showTwitchChannelSheet 使用 fake discovery；所有未預期 API 呼叫立即拋錯，沒有 token／HTTP／播放／帳號寫入。最新 20 項中 17 通過、3 失敗（4 秒、exit 1）；本批與前述四份合計 46 通過、3 失敗，不重複計入中途 14 項測試的結果。
- 媒體庫已有頁面證據：VOD／片段在 1000、390 寬搜尋命中／空結果／清空；首次失敗點重試；載入更多失敗保留前綴、同 cursor 重試及耗盡；等待載入時按鈕停用不重複送出；離頁後成功／錯誤忽略；切換兩分頁保留各自搜尋且不重讀；1000×900、390×844 從按鈕開 sheet／點關閉及視窗內幾何。
- 新增兩個媒體分頁失敗：VOD／片段第二頁含上一頁 ID 時各顯示重複卡片；正式 page 直接 append，尚未修正。原真實樣本「沒有重複 ID」僅代表當次上游未重複，不涵蓋重疊分頁。
- 新增短視窗失敗：844×260 開媒體庫，showTwitchChannelSheet 的 .clamp(360.0, viewport.height) 下界大於上界，ArgumentError，未顯示面板。頁面最低高度邏輯尚未修正，不能以正常手機直向通過排除。
- 此回合唯一 analyze 僅新媒體檔：無 error／warning、1 info（測試 helper 的 public API 使用 private fixture type），exit 1，未重跑。

後續續測（先前四批原始結果仍保留如下）：

- 真實訪客 API 兩個原先跳過案例已啟用並通過（4 秒、exit 0）：公開 browse／search／live／games 及四個公開頻道 VOD、clip／profile 請求都檢查沒有 Authorization header；不登出真實帳號，不代表完整訪客頁面或媒體解碼通過。
- 新 update service 測試 stable 10、beta 12 項通過（版本 override 1.2.3，所有 HTTP 用 fixture 攔截）；尚未測同數字版本不同 prerelease 序號的排序，不能稱完整 SemVer 驗證。
- 私訊改動僅測試：四個同步錯誤案保留 controller 原始錯誤斷言、UI 改核對現況友善提示；兩個通知案明確使用 Windows／假的 window_manager，panel 案先隱藏 toast，確認通知只由面板重新顯示並點擊。六項定向重跑全部通過（3 秒）。正式 sheet／overlay 未修改。
- 最新整份私訊收件匣 168 通過、3 失敗（37 秒、exit 1）：訊息列表 Scrollable 找不到、desktop receipt 右側溢出 10 pixels、cache cleanup timer。timer 這次出現在 1000×760 composer，前轮是在 390×844，確認是會改變落點的間歇性 fixture 清理問題。原六項失敗已被同檔完整重跑覆蓋為通過，但整檔仍失敗。
- 此續測四個主要執行合計 192 通過、3 失敗（包含真實訪客 2、新 service 22、整份 inbox 168；不把定向六項重複加入）。前輪設定頁及更新 controller 的失敗未修正、未重跑，仍列待處理；不是整體矩陣已通過。
- 此回合唯一 analyze：docs/twitch_whisper_inbox_test.dart、docs/twitch_update_service_test.dart，No issues found，9.2 秒、exit 0。

- 四批模擬測試合計 456 項通過、11 項失敗、2 項跳過；失敗重跑不重複計數。沒有新增真實 App 整合證據，沒有對帳號發送訊息／管理操作／下注，沒有真實下載安裝。
- 私訊收件匣／API／EventSub、使用者角色、管理 API、AutoMod queue、下注／忠誠列車及聊天身分 API：256 通過、9 失敗。9 失敗皆在私訊收件匣；定向重跑 12 項有 4 通過、8 失敗，cache cleanup timer 一項此次未重現，仍保留間歇性失敗紀錄。
- 批次管理、管理面板／訊息操作、封鎖詞、AutoMod 設定、通知期限／卡片樣式：103 項通過。permission revoked、取消／關閉、未知結果不重送等證據僅適用隔離 mock，不代表真實管理帳號操作完成。
- 訪客 discovery／media、登入取消、設定鍵位頁、管理紀錄 API／controller／panel／EventSub、置頂管理、聊天身分面板、表情符號 picker：89 通過、1 失敗、2 跳過。失敗是設定頁 ListTile 背景／水波紋被 DecoratedBox 遮住的框架警告，單檔重跑仍失敗；兩個真實訪客 API 測試未開 TWITCH_GUEST_LIVE_TEST，不能計為通過。
- 新增更新控制器隔離測試 9 項：8 通過、1 失敗。重複檢查、錯誤重試、通知去重、釋放後忽略檢查回應、無更新不安裝、重複安裝及假的失敗重試有證據。下載中 dispose 的晚到 progress／finally 會 notify disposed controller，尚未修正。service 版本比較、beta 選版、更新頁、OS installer 仍未驗證。
- 完整真實訪客／切換帳號導頁、VOD／剪輯真實拖曳及畫質、迷你播放器各返回路徑、完整設定頁、網路恢復及 profile 效能仍保持待測。詳細重現與失敗分類見桌面測試報告的「2026-10-12 接續功能測試」。

每列須有範圍相符的證據與明確結果；補齊盤點發現的遺漏功能。失敗須保留可重現步驟與去敏紀錄。沒有證據或只測到部分時保持待測，不以綠色測試總數宣稱完整功能已測完。

## 下一個執行批次

1. 重驗 fullyLive 下的真實 DVR 暫停／恢復／返回直播與 UI 卡頓。
2. VOD／剪輯播放、媒體庫與頻道導頁。
3. 其餘矩陣項目按唯讀整合及模擬寫入分批驗證。

## 本批結果

- 近直播20秒回看新增真實失敗：追隨第一卡hasArchive=false，两次觀察都由起初解碼前進到第20秒native位置倒退且buffering=true、其後60秒不再前進（兩輪1分27秒、退出碼1）。Flutter截圖實際包含影片／控制列且顯示落後20秒，起始只回10秒；容器位置／高度取樣沒有位移，不排除內部時間／進度抖動。完整archive先前長測不能代替此路徑；有VOD的20秒路徑接線相同，但本輪尚無有VOD真實樣本。正式程式尚未修改。
- 最新使用者要求時間與操作同排：surface恢復48高，desktop時間置中、小螢幕整排可水平捲動，時間軸保留全寬／貼邊／無圓點。八項widget與三檔analyze通過；不當成新版真實播放／完整矩陣已驗證。
- 最新52437真實DVR長測整體通過（4分44秒、退出碼0）：45秒恢復、UI暫停跳轉與canonical穩定／UI恢復、左右鍵、1/3／2/3各10秒及120秒增量120,833ms、返回直播10秒。每10秒取樣未緩衝；extended build P95=4,137us但仍六幀逾33.333ms，debug不是profile／A/B，不排除全部卡頓。97188未知失敗保留，其他頻道／格式／恢復仍待測。
- 使用者確認時間標示水平置中；八項VOD與直播時間群×四寬度mock通過，維持全寬無圓點時間軸貼上邊框。真實長測編譯在UI調整前，不把播放通過當新版視覺驗證。
- 使用者授權搜尋共用主頁模板：抽出shared scroll surface統一背景與70／118工具列占位，空結果亦共用；六項模板×寬度／狀態mock加原29追隨共35項通過。真實SEARCH_LAYOUT_ONLY整合通過（7秒、退出碼0），搜尋結果header在toolbar下方間距8；不代表所有搜尋篩選／分頁、真實空結果或窄畫面完成。
- 最新extended DVR 97188整體失敗（2分48秒、退出碼1）：暫停時canonical新斷言／UI恢復／左右鍵與repeated seek2有通過，未取得120秒及返回直播完整證據，原因待定位；保留前輪17945完整短回歸通過，不能替代新修正的長測。
- 暫停DVR顯示時鐘偏末端已重現並修正；17945完整真實回歸通過（2分17秒、退出碼0）：45秒恢復、新暫停跳轉保持正確canonical目標、UI恢復10秒、播放中左右跳轉各10秒及返回直播。六項widget與兩檔analyze通過；未重跑extended120秒，不宣稱所有DVR情境完成。使用者搜尋重疊已定位為搜尋清單缺共用70／118工具列占位，本輪僅診斷、尚未修正。
- 最新使用者控制列樣式：時間軸 noThumb／noOverlay、上角直角、painted 半透明垂直漸層而非直播背景模糊；四寬度 widget 斷言 dock 無 BackdropFilter 且實際點擊／拖曳 fake seek 通過，不當成效能提升或真實 DVR 播放驗證。
- 最新控制列依使用者要求改為框外時間／時間軸，拖曳條中心貼面板上緣上方3像素，下方面板48高；九項 widget 通過並保留實際 fake seek。真實 DVR handle 5309 整體失敗（49 秒、退出碼1），僅到初始 DVR 解碼，未到新增 controls preflight，原因待定位；不把 mock 排版成功當 DVR 整合成功。
- 使用者追加 PIN 下方頭像及控制列改版：置頂五項 widget（含垂直位置／中心對齊）及四項 VOD 控制列寬度／時間軸點擊 mock 共九項通過。時間軸獨立完整寬度、按鈕另列、不整排縮放；真實 live／DVR 新排列仍待驗證，原 controls 失敗仍保持待定位。
- DVR 暫停跳轉新增真實 UI 測試首輪失敗，橋接 openMedia 沿用跳轉前 playing 後保持暫停／位置穩定、UI 恢復與 10 秒前進通過；但同輪接續原 DVR controls 仍 TestFailure（整體退出碼 1），返回直播未驗證，保持待定位，不能宣稱整體修復完成。使用者追加置頂留言風格／卡片內 PIN 統一，五項窄寬畫面／字級／展開收合／假的 Clipboard widget 測試通過；此樣式證據不替代完整置頂權限或三卡同時顯示驗證。
- 接續直播路由整合 handle 58150 完整通過（2 分 16 秒、退出碼 0）：追隨第一卡、60 秒六次控制列點擊、迷你展開／關閉、首頁及追隨欄跨頻道、新舊 chat 生命週期與各 15 秒播放；側欄三個窗口各 12 次取樣穩定。觀察播放增量 62,083 ms、無取樣停滯／緩衝，P95 build=5,815 us／raster=3,863 us，但仍有 10 幀 build >33.333 ms，不代表卡頓完全排除。前輪 69274 最終輸出未保留且 handle 已消失，整體結果仍未確認，不追認通過。
- 點數、聯合登入、通知三份測試共 24 項通過；皆為假的 API／隔離偏好，不執行帳號寫入。
- 真實 DVR 整合失敗，登入、瀏覽點擊、搜尋、直播聊天室與直播時間前進則通過。同一整合測試的前半通過不計成完整測試成功。
- 第二次真實 DVR 重跑：首批 24,637 bytes 的 flush 在 792 ms 完成，但 60 秒內仍未達成非緩衝且位置前進的解碼門檻；尚未操作暫停就失敗。第一輪 flush 成功不代表後續資料轉送完成，根因仍待定位。
- DVR 四項 loopback 回歸再次全部通過；本批共 28 項模擬／本機回歸通過，真實 DVR 整合兩次失敗。
- 接續批次：每 10 秒去敏資料轉送紀錄確認在 262,144 bytes 持續 waitingForFlush=true。省略開檔初始跳轉的獨立診斷也失敗，約 250,247 bytes 後等待 flush；此對照不算完整 DVR 成功。加入原生播放器僅數值／布林狀態及固定警告關鍵字紀錄，繼續定位。
- 原生狀態重跑發現 error／failed 類警告且 idle-active=yes，與 Flutter 舊 playing=true 不一致；因此必須追查播放器開檔失敗，而非僅以 UI 緩衝旗標猜測。完整 DVR 保持失敗／待修正，未操作真實帳號寫入。
- 使用者留前景觀察仍失敗；binding lifecycleState=unknown，不當成 OS 前景證明。hasMap=true／compressed=false 及程式檢查確認 pump 漏送 EXT-X-MAP；已補每 client／seek 初始化順序，新三項初始化加四項背壓回歸全部通過。真實 DVR 修正後解碼與長測仍須確認，尚未算通過。
- 修正後真實重跑成功（1 分 36 秒，退出碼 0）：初始化 fMP4 1,125 bytes 成功送出後開始解碼；暫停 10 秒恢復、跨多個分段 45 秒增量 45,516 ms，buffering=false；返回直播再觀察 10 秒持續前進。前一輪修正後測試在直播 15 秒觀察先失敗，未到 DVR，不當成 DVR 修正失敗；補先等直播位置開始前進的門檻後保留原持續觀察斷言。
- 延伸真實 DVR（4 分 4 秒、退出碼 0）：原 45 秒恢復增量 45,600 ms；時間軸 1/3、2/3 兩次跳轉各自重新收到初始化，解碼並前進、各觀察 10 秒通過；其後 120 秒增量 121,715 ms，返回直播後 10 秒持續前進。效能記錄在該次編譯後才新增，不能引用該長測作 FrameTiming 證據。
- 本回合 analyze 一次，範圍為整合測試與聯合登入測試：No issues found，退出碼 0。後續新增的 DVR 診斷未再 analyze，透過整合編譯驗證；不代表全 repo 靜態檢查通過。
- 近直播20秒回看：兩次真實重現約20秒後停滯，移除兩層片段 flush 一秒期限後，31372追隨第一卡（無archive）60秒持續前進及返回直播狀態通過。時間軸另修正連續位置／分段端點時鐘不一致與拖曳視窗漂移；14項本機時間對齊、排版、毛玻璃、操作及慢讀測試通過。仍不等於全功能矩陣完成。本輪analyze有一則info（慢讀fixture缺大括號），無error；後追加時間軸修改未重跑analyze。
- 使用者追加落後兩分鐘：修正同回看revision的原生時間倒退／回前景重設舊target，以及緩衝狀態切換使用過期_position。三項新時鐘fixture及既有排版共16項通過；真實60521三分鐘lag固定12003ms、slider約0.3998、native增量182800ms與返回直播狀態通過。真實本輪未觸發特殊重設分支，不能視為使用者原問題已直接重現。一次analyze三檔No issues found，後追加緩衝修正只有編譯／測試證據。
