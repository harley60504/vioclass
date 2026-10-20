# 電腦版 debug 測試紀錄

## 測試界線

- Windows debug 版；保留使用者既有 cookie、token 與登入狀態。
- 不登出、不清除儲存資料、不操作授權對話框。
- 不發言、不追隨／取消追隨、不訂閱、不建立剪輯、不兌換點數、不執行管理操作。
- 只記錄非敏感結果，不保存 cookie、token、播放簽名網址或聊天室私人資料。
- 本輪未手動讀取或修改平台與 build 資料夾。

## 2026-10-12 Windows 迷你播放器拖動續測

### stylishnoob4 完整 DVR 操作與長播回歸

同一Windows真實App使用FULL_DVR／DVR_CHANNEL_INDEX1／DVR_CONTROLS／DVR_DRAG／DVR_DRAG_REPEAT／DVR_CHAT_FOCUS／EXTENDED_DVR。儲存登入解析後預設追隨通過，測試主動切瀏覽、搜尋、從前五台公開直播選第二個有growing archive的stylishnoob4，直接建觀看頁與active archive；不是首頁第一卡接線，也不把模型的growing判定當獨立直播存檔確認。

編譯34.6秒、執行5分12秒exit0。直播唯讀聊天室／15秒前進，archive暖機與DVR解碼、暫停恢復及45秒跨分段前進45,484ms通過。實際Slider三次拖到30%／70%／20%，各取得新stream／接近預覽目標、等待換源時鐘重設完成才取baseline；十秒Native各增10,116／10,117／10,133ms，控制列同步前進、來源不變及結尾非緩衝。

實際聊天室badge切live composer、輸入框focus時左右鍵不跳DVR、點播放器解除focus及切回replay聊天通過，沒有發送訊息。DVR左右鍵各新來源與十秒續播通過；1/3／2/3重複跳轉各解碼及十秒續播，再120秒Native增121,350ms、每十秒樣本playing=true／buffering=false；返回直播重新達既有解碼門檻後十秒增10,000ms、非緩衝。

此DVR來源hasMap=false、mpegts、片段HTTP200；不是近期fMP4時間重設／fixture音訊修正的真實來源回歸。extended build P95=4,521us／raster=3,481us、此phase零個取樣幀超33.333ms，但live build有14、drag有3、return-live有1個超門檻幀；debug樣本不代表profile或卡頓排除。只既有播放／時鐘門檻與有界取樣，未新增逐幀畫面內容、真實斷網、暫停中seek保持、跨頻道恢復或fMP4黑畫面證據。

本輪未修改正式程式／測試、未執行analyze，只更新紀錄。真實TS第二樣本的這套DVR序列通過，不等於全部頻道／格式／平台與完整功能矩陣完成。下一步恢復中換來源與剩餘已知生命週期失敗；歷史Twitch黑畫面仍保持未結案。

### 分段音訊素材的定址相容性修正

本輪AAC初始化對照：原分段檔764,465bytes與未分段檔715,963bytes，esds descriptor tag3／4／5、decoder object64、specific length2、audio object2／frequency index4／channel config2均相同，不能將音訊失敗歸因不同AAC設定。檢查首個moof，兩軌tfhd flags為0／32，都沒有absolute base或default-base-is-moof；兩個trun都有data offset。此多軌形態不符合[W3C MSE片段相對定址條件](https://www.w3.org/TR/mse-byte-stream-format-isobmff/#media-segments)，不等於宣稱所有ISO BMFF檔案都必須採相同形態。

新測試專用twitchMoofRelativeFixture僅在記憶體副本補各tfhd的default-base-is-moof bit，拒絕absolute base形態，沒有移動trun offset、改box長度、AAC設定或樣本；原檔不寫入。两項fixture測試exit0，驗證所有差異只在tfhd指定bit、輸入不變及操作可重複。這是針對公開bear fixture的修正，不改正式代理或Twitch媒體。

同一啟用音訊／四次tfdt重設／單open回歸，僅新增FIXTURE_MOOF_RELATIVE：Windows34.8秒編譯、14秒exit0。先前first map position0／audio_decode_failed89的問題不再出現；音訊輸入44100Hz／2聲道、輸出48000Hz、mute=yes。四邊界皆音訊参数有值／avsync絕對值<0.25秒，已見取樣0.001902／0.001734／0.001535，最終0.000973秒；不得由有限取樣宣稱全程聽感或逐幀同步。

opens1／GET1／attachment1，map5／fragment5，3,822,373bytes收取flush相等、pumpFailures0；Native末尾position11,810ms、取樣後恢復到12,210ms。原生中央非黑0.882981／Flutter0.882958、比例匹配、主動暫停取樣差0ms，恢復前進400ms通過。只相同codec／解析度、修正後公開素材；不同codec／實際廣告及歷史Twitch起播黑畫面仍未結案。

唯一analyze整合入口6.9秒exit1，無error／warning、八info（六既有及兩個前輪新增控制端點的大括號提示）。記憶體旗標helper及接線在其後新增，由兩項unit與Windows編譯驗證，未重跑analyze。完整目標持續；接續真實直播切換、完整DVR及矩陣剩餘項目，不把素材問題當App黑畫面根因。

### 未分段 AAC 的原生正向對照

只讀本機公開fragment fixture初始化，找到mp4a／avc1／esds，沒有命中enca／encv／senc／sinf；這些是格式提示，不是完整加密驗證。[Chromium官方資料表](https://chromium.googlesource.com/chromium/src/+/main/media/test/data/README.md)列bear-1280x720.mp4為AAC＋H.264，av_frag為其分段版。新 BASE_CONTROL 從官方Chromium GitHub mirror讀取未分段版，8MiB記憶體上限與HTTP讀取期限，僅記憶體供本機有限長度／Range端點播放，不新增影片檔或存直播／帳號資料。

首輪34.8秒編譯、4秒exit1：715,963bytes素材已使Native position633ms、音訊輸入44100Hz／2聲道、輸出48000Hz、avsync0.000061、mute=yes；但測試仍啟動不需要的router暖機，違反map／片段零請求門檻，整體不算通過。修正只在直接對照模式完全不啟動router，不更改正式播放行為或放寬零請求斷言。

最終34.5秒編譯、8秒exit0：有限素材端點requests1／opens1、position667ms、音訊44100Hz／2聲道→48000Hz、avsync0.000020、mute=yes；router GET／map／fragment全部0，無audio_decode_failed。既有GPU／EGL hint仍存在但未阻止此解碼。這只证明未分段AAC在本套Native路徑可解碼，不是聽感、多次discontinuity、實際Twitch或全AAC格式保證。

對照前輪相同App／原生設定直接播放av_frag仍有audio_decode_failed89／無音訊參數，不能把它歸因代理或時間重寫，也不能稱播放器完全不支援AAC。分段檔的初始化／demux／codec相容性待定位；下一步比對兩份素材的AAC初始化描述，保留原失敗，不以另一檔成功當修好。

唯一analyze整合入口6.9秒exit1，無error／warning、八info（六既有、兩新if大括號提示）。其後對照不啟動router由最終Windows編譯／執行驗證，未重跑analyze。只改測試與紀錄，正式runtime、憑證與使用者偏好不變，完整目標持續。

### 原生音訊起播失敗與直接檔案對照

INIT_NATIVE_AUDIO 啟用本機bear的音訊，播放器配置mute=yes；新增音訊輸入／輸出採樣率、channel-count、avsync、volume／mute的固定數字／布林白名單。每個檢查點要求音訊參數有值、保持靜音且avsync絕對值小於0.25秒，缺值不當零。依[mpv官方說明](https://mpv.io/manual/stable/)，avsync是音訊與影片的時間差；此門檻為本測試條件，不是完整聽感或逐幀同步標準。

四次重設模式第一次36.1秒建置／46秒exit1，第一段尚未達500ms、未進任何重設；補第一段與finally去敏診斷後35.1秒建置／46秒再次exit1。單GET／attachment，764,465bytes收取flush相等、pumpFailures0，Native stream-pos716,899、video decode／output1280×720，position0／buffering=false／core-idle=yes。2至42秒沒有音訊輸入或輸出採樣率，unclassified音訊hint89；取樣volume100但mute保持yes，沒有解除靜音。不能把playing=true／avsync0算音訊成功。

新增固定audio_decode_failed／audio_output_failed分類，補直接檔案控制模式，完全繞過router且不進重設。第三輪35.1秒建置／2秒exit1：檔案影片position567ms，但音訊参数仍缺失、audio_decode_failed89，router GET／map／fragment全部0。同一檔案SHA256仍為AFFC4CE6C872F9D4160A92A7B959523B3CAC2D171E89177E4CD211E55F756175，與既有公開素材紀錄一致。音訊解碼失敗不依賴代理或tfdt重寫；素材／原生解碼相容性仍待定位，不能由此宣稱正式App音訊壞掉或Twitch黑畫面同根因。PATH未找到ffprobe／ffmpeg，不推論電腦所有位置都未安裝。

白名單原17項exit0；新分類測試先17過／1失敗，原因是既有分類器允許同訊息同時命中open_failed，修正fixture保留重疊分類後18項exit0，未改既有分類規則。唯一analyze三入口7.6秒exit1，無error／warning、六既有info；後補診斷／直接對照由unit與Windows編譯驗證，未重跑analyze。只測試／紀錄／去敏分類，不改正式播放、真實音量偏好或憑證。音訊、多次A/V及完整目標仍未完成，下一步先確認可解碼的音訊對照素材或原生codec條件。

### 24 次 discontinuity 的原生持續播放

INIT_RESET_COUNT 新增1～24次有界重設，只允許在 RESET_INIT_TIMESTAMPS 下使用多次模式。fixture 每段更換 map／segment URI、tfdt歸零，滑動清單以正確DISCONTINUITY-SEQUENCE保留世代。每次在新段解碼超過500ms後才發布下一段，核對Native前進／當下非緩衝、map及片段請求數、opens不增加；同一App與Native HTTP讀取者，不逐段重開。正式播放程式未修改。

Windows34.6秒編譯、1分9秒exit0：24個重設邊界全部通過，末尾position67,156ms、mapRequests25／fragmentRequests25、opens1／GET1／attachment1。收取與flush各19,111,913bytes、pumpFailures0，Native stream-pos18,590,132；解碼及輸出1280×720、decoder drop0／VO drop1。末尾原生中央非黑0.877664／Flutter0.878026、比例匹配，主動暫停取樣差0ms，恢復再前進400ms通過。

這是相同codec／解析度的25段公開bear素材與24次時間重設，音訊停用；每個邊界等待後的狀態通過，不等於所有中間畫格、短暫緩衝或實際聲畫同步都已驗證。沒有真實Twitch、廣告／不同初始化編碼或完整DVR故障樣本；歷史起播黑畫面仍未結案。

唯一analyze整合入口7.4秒exit1，無error／warning、六既有info，未重跑。只擴充測試與紀錄，未修改帳號、偏好或既定協議。接續補不同初始化／音訊及其餘功能矩陣，不以本次長測縮減完整目標。

### discontinuity 的跨軌時間差與邊界檢查

新兩軌 metadata fixture 重現前輪逐軌 offset 的問題：舊軌從零開始，新世代音訊比影片晚200ms時，逐軌各自對齊舊origin會消掉新音訊的200ms差。另一空tkhd fixture期待FormatException卻拋RangeError；首輪五項3通過／2失敗，沒有放寬斷言。

正式timeline改用所有已知軌道的最早decode-time作共同起點，跨世代計算同一個有理數wall-time偏移，再按各軌timescale取最近tick，不使用浮點數。保留新片段的相對音視訊時間差，支援偏移正負與新timescale；初始化／tfdt full box先驗證長度及版本，空欄位回可控FormatException。樣本、box長度、登入及UI不改。

八個timeline案例連同初始化HTTP／錯誤恢復／replay／pending reader／prefetch與discontinuity七檔共44項6秒exit0。新增覆蓋三次世代邊界、200ms與100ms跨軌差、音訊48000→44100 timescale、正負offset；tfdt版本0／1、extended moof逐byte抵達與32bit溢位在metadata送出前拒絕。這些是時序欄位與輸出位元組證據，不是實際音訊聽感或不同codec解碼證明。

Windows同一RESET_INIT_TIMESTAMPS Native回歸，34.8秒編譯、6秒exit0：單opens1，position3,536ms／buffering=false，Native stream-pos1,020,555，收取flush各1,528,942bytes、pumpFailures0。原生中央非黑0.877906／Flutter0.877451、比例匹配與暫停取樣差0ms，恢復再前進400ms通過。音訊依舊停用，沒有驗真實A/V同步、Native多次discontinuity或不同codec／解析度。

唯一 analyze 正式proxy入口與fixture2.9秒exit0、No issues found。保存去敏結果，歷史Twitch起播黑畫面及完整功能矩陣仍未結案；接續補多次邊界的原生長播放、音訊及不同初始化，避免用metadata單元測試冒充解碼完成。

### fMP4 discontinuity 的正式時間銜接修正

正式 writer 接上 discontinuitySequence 與新的 fMP4 timeline：解析初始化 track timescale，記錄原始 decode-time 起點；跨世代時依已輸出 duration 計算每個 track 的 tfdt offset，後續同世代保留 offset。只改 decode-time 欄位，不改樣本內容或 box 長度；使用 BigInt 處理時間值與溢位，moof metadata 上限1MiB、mdat持續串流。一般世代位元組維持原樣，TS與無可解析track表的初始化走既有輸出路徑。未知track／非法片段停止輸出，不猜測時間；不修改登入、Twitch請求協議或UI。

同一 RESET_INIT_TIMESTAMPS 原生失敗案例，修正後 Windows 編譯35.4秒、測試6秒exit0：單opens1／GET1／attachment1，map2／fragment2、收取flush各1,528,942bytes、pumpFailures0。兩秒position3,102ms／buffering=false，後續到3,536ms、Native stream-pos1,020,555；原生中央非黑0.877906／Flutter0.877451、比例匹配、暫停取樣差0ms，恢復後再前進400ms通過。對照前輪position2,569ms停滯／buffering失敗，證明這個受控時間重設問題修正有效，不是一般重跑成功。

正常連續時間戳＋map等待中重開的 Native 回歸，34.7秒編譯、7秒exit0：gate未放行先解碼舊片段667ms／opens2，放行後position3,700ms、第二段收取完整、兩層有內容及恢復前進通過。相同codec／解析度、音訊停用；沒有驗不同codec／track拓樸、真實廣告、任意長播或所有DVR clock情境。

timeline三案（完整／跨addStream前綴尾段、同世代原樣、跨世代及後續offset、超大metadata拒絕）連discontinuity與timestamp fixture先7項exit0；初始化HTTP／持續失敗恢復／replay／pending reader／部分prefetch七檔32項exit0。後補有解析track的fMP4 metadata尚未輸出時也需終止fatal reader，並將部分prefetch擴充公開bear真實初始化與片段，21項exit0，包含原14項與新增7項，不重複加總。

唯一 analyze 正式proxy入口與新timeline fixture3.1秒exit0、No issues found。fatal條件及7個真實片段fixture為其後追加，由21項及正常Native回歸編譯／執行確認，未重跑analyze。紀錄只保存數字與固定錯誤類別，不存直播或帳號資料。歷史Twitch起播position0／format_unrecognized黑畫面仍未結案；接著驗多次discontinuity、不同初始化及取消／錯誤恢復，完整目標保持進行。

### fMP4 時間戳重設的原生停滯

RESET_INIT_TIMESTAMPS 在既有兩段公開 bear fixture 的第二 map 前加 EXT-X-DISCONTINUITY，第二段 tfdt 不加三秒，改成再次從零開始；map 的 codec／解析度不變。Windows 編譯 34.6 秒、測試 48 秒 exit1，第一段已解碼，新 map 與第二段均完整送出後仍未達到3.5秒進度。這是新受控失敗，不是等待逾時後重跑成功。

放行後兩秒 position1,101ms／buffering=false，四秒起至44秒 position2,569ms／buffering=true。單 GET／attachment、mapRequests2／fragmentRequests2，收取與 flush 各1,528,942bytes、pumpFailures0；Native stream-pos1,524,971 已進第二段尾端，解碼／輸出尺寸1280×720，cache-duration0／paused-for-cache=yes／eof=no／idle-active=no。資料未送達不是此樣本的原因；它與歷史起播position0／idle-active=yes／format_unrecognized並非同一組症狀，不能直接認定歷史黑畫面同根因。

正式 parser 原本跳過 discontinuity 與 discontinuity-sequence，segment 模型也沒有保留時序世代。新增 discontinuitySequence，解析 base 序號及各 boundary 的增量，普通段與 Twitch-prefetch／prefetch／preload 都保留相同世代；一般清單預設0。不改既有播放、授權或 Twitch 請求協議。

新增三案在原模型均因缺少 getter 失敗，不把此 API 缺失當作已測出錯誤序號。補正式欄位與解析後，滑動清單移除 boundary 仍保留7→8／8、三類 future 同世代及普通0；連格式與 timestamp fixture 共9項4.3秒exit0。這只是正式修復的前置資料接線，writer 尚未消費新欄位，時間戳重設的 Native 停滯仍未修復；没有以單元測試通過替代原生失敗。

唯一 analyze 整合入口6.9秒exit1，無error／warning、六既有info；正式 parser／模型及新fixture在其後新增，由9項test編譯確認，未重跑analyze。下一步處理世代邊界的媒體時間／decoder銜接，再回歸同一原生失敗及正常連續時間戳；不同codec／解析度與真實黑畫面仍待驗。

### 初始化等待中原生重新開片

REOPEN_PENDING_INIT_NATIVE 擴充既有 REPLACE_INIT_NATIVE：第一段已解碼後清單更換 map URI，新 map HTTP 以 gate 等待；尚未放行即由 session.forceOpen 重開同一 router 來源。要求第二個 Native GET 能先解碼舊完整 init＋片段，且 mapRequests2／fragmentRequests1／gate 未完成，再放行新 map。此為公開 bear 本機素材、相同 codec／解析度與三秒 timestamp 位移，不是不同格式或真實 Twitch 廣告切換；正式播放程式未修改。

首次啟動參數誤用 PARTIAL_NATIVE，沒有进入 PARTIAL_DECODE 分支；Windows 36.2 秒編譯、29 秒 exit0，實際只跑預設首頁／搜尋／直播唯讀、聊天室及15秒播放觀察。此結果不能列為新 fMP4 案例通過，沒有因觀察等待重啟該流程。

改正參數後，Windows 編譯 34.7 秒、測試 7 秒 exit0。新 map 仍等待時 opens2／requests2，Native position667ms、舊完整 764,465bytes 收取與 flush 相等、MP4 init=true、pumpFailures0。放行後仍 opens2，mapRequests2／fragmentRequests2、position3,667ms，Native stream-pos1,004,007 已超過首段大小；新 reader 共收取／flush 各 1,528,942bytes，無傳輸失敗。

放行後原生 1280×720、中央非黑0.881547，Flutter中央0.880991、比例匹配、主動暫停取樣差0ms；恢復後再前進400ms斷言通過。decode／output尺寸均1280×720、decoder drop0／VO drop1。unclassified GPU／EGL hint各1仍可解碼，不能以該 hint 判為原因。這補足 map 等待時重連的 Native 證據，不是歷史真實黑畫面重現。

唯一 analyze 整合入口 7.1 秒 exit1，無 error／warning，六既有 info。完整功能仍未完成；不同初始化編碼設定、時間戳重設／discontinuity、原生 open 內部重疊與真實黑畫面仍待獨立驗證。

### 觀看頁播放服務的三來源格式對照

沿用既有 LIVE_FORMAT_SCAN，在同一 App 的剪輯觀看頁已解碼後，使用該頁 watchServices.playbackApi 探測首頁既有六台直播卡的 web-site／android-autoplay／ios-site。未另外建立匿名播放 API，也未向本機 router 加 GET；只取得上游清單與至多 4,096bytes 媒體前綴。沒有輸出 token、簽名網址或影片內容。使用正式觀看頁的 API 物件不等同每次請求皆為 authenticated，本輪沒有輸出該授權解析狀態。

Windows 編譯 34.6 秒、測試 43 秒 exit0，App 儲存身分與預設追隨、公開搜尋、剪輯解碼通過。六台 caseoh_、kato_junichi0817、stylishnoob4、bisradio、supertf、pikabooirl，每台 web 三個、Android 兩個、iOS 三個畫質，共 48 個樣本全部 mpegts／無 MAP；清單 HTTP200，媒體 HTTP200 或 206、前綴均 4,096bytes，fmp4Channels0。此模式在格式掃描後返回，沒有執行 mini handoff／恢復切換，不把整體 exit0 當成那些功能通過。

本輪只更新紀錄，未修改正式程式或測試，也未執行 analyze。歷史失敗記錄仍有上游 MP4 box＋MAP、90秒 position0／buffering、afterMount read_failed2／format_unrecognized1；本次 TS 探測不能反證該次 fMP4 失敗或認定已修復。接續以受控 fMP4 初始化／格式切換分辨傳輸與解碼原因，保留真實故障樣本不足及完整矩陣未完成的限制，不原樣重掃這六台。

### 開台頻道的有界格式預探測

新增 FIND_FMP4：同一 App 取得目前追隨開台清單，排除剪輯來源後最多六台，各以既有 probeChannelLiveFormats 探測匿名 ios-site 前三個非音訊畫質。找到含 MAP 的 fMP4 才透過正式首頁搜尋卡片進入；進入後仍由 REQUIRE_FMP4 核對 App 實際傳輸，不把預探測視為正式選源或解碼證明。未改正式播放或帳號憑證。

既有格式 helper 五項本機 HTTP fixture 全通過，涵蓋 fMP4／TS／未知／HTTP 拒絕／無媒體；Range 只保留 4,096bytes，簽名網址不進結果。Windows 編譯 35.0 秒、執行 24 秒 exit1：剪輯解碼、Home 轉 mini 與三秒前進通過，六台預探測全部 TS，因找不到 fMP4 而停止，直播切換與恢復重疊沒有執行。沒有逐台重開 App。

本次六台為 mimiluckying、yulihong22、xargon0731、erycyoo、shuteye_orange、anninmiru_。每台三畫質共 18 次：playlist HTTP200、segment HTTP206、保留 4,096bytes、hasInitMap=false、format=mpegts。這是匿名 ios-site 當次來源，不代表已登入 App 的所有來源／畫質或其他時間均沒有 fMP4，更不能撤銷歷史黑畫面。

唯一 analyze 整合與格式 fixture 兩入口 7.0 秒 exit1，無 error／warning，六個既有 integration info。黑畫面原因仍未確認；下一步需對照實際 App 選源與不同 playback context，或以已有受控 fMP4 失敗案例繼續區分傳輸／解碼問題，不重跑此六台相同條件期待不同結果。完整功能目標保持未完成。

### 指定直播來源與 fMP4 測試門檻

整合測試新增 RECOVERY_CHANNEL：透過正式首頁搜尋輸入與精確頻道直播卡，保留原剪輯→mini→等待中的恢復→新直播流程。REQUIRE_FMP4 要求實際選用清單有 EXT-X-MAP，且 router 傳給 Native 的首段為 MP4 初始化；TS 能播仍不能算此輪通過。沒有改選源、播放 runtime、憑證或 Twitch 協議。

nix 首次編譯 35.1 秒、測試 59 秒 exit1，停在指定頻道直播卡可見門檻，未進入新直播／fMP4 播放，亦未取得搜尋完成與 offline 判定；不能歸因黑畫面或直接宣稱該台離線。補充搜尋完成、精確 live／offline match 及 error 布林，未輸出搜尋正文、私人資料或網址。

sam1268 第二次編譯 35.1 秒、測試 19 秒 exit1：搜尋完成、liveMatch=false／offlineMatch=true／error=false，確認該次超負荷未開台。前面的剪輯解碼、Home 轉 mini、三秒前進通過；直播、fMP4 門檻與恢復重疊未執行。這是測試來源不可用，不是播放器黑畫面重現，也不以剪輯通過宣稱整輪成功。

唯一 analyze 整合入口 7.9 秒 exit1，無 error／warning，六個既有 info。搜尋完成診斷在其後追加，由第二次 Windows 編譯／執行確認，未重跑 analyze。完整目標仍進行；下一步先在目前開台頻道做有界格式探測，再選實際 fMP4 來源取得故障當下證據，不反覆重開離線目標。

### 黑畫面診斷的兩層獨立取樣

正式播放未改動。整合測試的影格診斷原本在 Native 截圖回 null 或拋錯時提前結束，連 Flutter 取樣也跳過；現在分開兩層的錯誤處理，只有取得 Native 畫格才輸出兩層比較。原生截圖仍有兩秒期限，影格只在記憶體中計算，不保存圖片、聊天或播放網址。

修正前編譯 35.2 秒、執行 29 秒 exit0：剪輯→mini→caseoh_ 直播，舊恢復維持 pre-open 等待，pendingAtClick／Mount／NewOwner 皆 true，Native open 三觀察點皆 false。直播十秒增 10,017ms，單 GET／attachment，最終收取與 flush 均 11,117,380bytes、pumpFailures0；兩層中央有內容、比例匹配。上游 TS／HTTP206、無 MAP，不能替代歷史 fMP4 黑畫面證據。

新增 FRAME_PROBE_FAILURES 隔離注入 Native 截圖 null 與 StateError。修正後編譯 34.9 秒、執行 28 秒 exit0：兩案 nativeSamples0／flutterSamples2，Flutter 各有 42,042 取樣點，沒有因 Native 缺席偽造配對比較。這是模擬截圖失敗，不是實際解碼故障。原剪輯→直播流程仍通過，caseoh_ 十秒增 10,033ms、來源保留／不緩衝，收取與 flush 均 11,025,448bytes、pumpFailures0、兩層有內容；切換 build P95 18,799us、17 幀超過 33.333ms，debug 效能限制保留。

唯一 analyze 整合入口 7.1 秒、exit1，無 error／warning，六個既有 info（prefix、import、兩個 if 大括號、兩個 collection literal）。本轮沒有取得新的真實黑畫面；兩次 TS 成功不能證明 fMP4 問題已修復，也未驗證 Native open 內部重疊。下一步須針對實際 fMP4 來源收取故障當下的 transport／cache／decode／兩層取樣，而非原樣重跑 caseoh_。

### 缺聊天室讀取權限的匿名連線

已登入但缺 chat:read 時，正式控制器原本仍把帳號 token 交給 IRC 並建立雙連線。四組隔離 scope 測試中，空權限與只有 chat:edit 兩案先失敗，只有 chat:read 與完整讀寫權限兩案通過。

控制器現在分開帳號身分與聊天室傳輸：缺 chat:read 使用既有匿名連線與 justinfan12345，不建立寫入連線；有讀取權限保留原認證方式。已驗證 viewer 與帳號 token 的身分防護不變，匿名讀取不把帳號改成訪客，普通發言仍必須同時有 chat:read 與 chat:edit。未改 OAuth/token 儲存或 IRC 協議。

本輪重新核對正式程式後，lifecycle、watch injection、permission prompt 三檔 69 項全通過，約五秒、exit0。四個新案確認傳輸 token／nick／factory 選擇、viewer 保留、authenticated 狀態及發言權限；服務皆為 no-storage fake，沒有實際 IRC、Native 或帳號寫入。這是控制器選擇連線方式的證據，缺權限真實帳號的匿名聊天室讀取與自動重連仍待驗。

唯一 analyze 兩入口 5.7 秒、exit1，無 error／warning，五個既有 fixture info：54 行 if 大括號及 636／698／765／888 行 unnecessary_underscores。沒有重跑 analyze。黑畫面仍未結案；歷史代理輸出前進不能證明 Native 收到或解碼，後續須以故障當下的接收／flush、解碼尺寸及輸出影格定位。

### 聊天缺發言權限的重新授權提示

正式WatchPage已登入、只有chat:read的fixture重現缺可見說明：canSend=false／isReadOnlyGuest=false，但找不到重新授權提示。新增missingSendPermission從已驗證session與controller IRC permission推導，經正式PortAdapter／Panel送InputSection；不能用一般canSend=false推測缺權限，checking／連線等待不顯示此提示。pending特殊訊息沿用独立API入口，不因普通IRC scope隱藏composer。

缺權限顯示「已登入，但缺少聊天室發言權限。請重新授權後再發言。」與「重新授權」按鈕，保留已登入判定；訪客仍顯示訪客說明與登入，沒有送出控制。正式頁面fixture核對viewer42、非guest、canSend=false、提示／按鈕存在、send icon不存在、fake sends0。登入／授權按鈕仍使用原onLoginPressed，未修改WebView／OAuth/token或傳輸協議。

新增中英×checking／guest／missing／authenticated八個InputSection widget案；缺權限及guest都只在實際tap後觸發假login callback一次，不觸發send；checking只停用composer、登入有權限仍可用。第一輪英文guest找不到Sign in，定向確認原「登入」與訪客說明沒有翻譯，補兩key及本輪新缺權限說明。三檔最初39過／1英文失敗，補button後40項約6秒exit0；補guest說明及斷言後8項單檔再次exit0，沒有真實OAuth流程。

唯一analyze七入口6.9秒exit1，無error／warning，4info（fixture374／439 super parameter、717 if braces、正式watch565既有if braces）。翻譯追加在其後，test編譯確認，不再analyze。只權限提示、接線及翻譯，未改布局樣式、Points payload或既定Twitch協議；不冒稱真實授權、缺chat:read匿名fallback或所有特殊訊息驗證完成。完整目標持續。

### 已登入直播頁實際送出按鈕回歸

新增隔離SignedAuth／驗證scopes／SendableChat fixture，正式WatchPage建立正式chat controller、panel及InputBar，以Flutter點send_rounded按鈕而非直接呼叫send方法。所有服務請求由測試Dio interceptor回應，auth／Drops／Web儲存為no-storage fake，chat傳輸只記fake送出次數與gate，不建立IRC或Native；Windows只是widget platform override，非真實桌面App。

五案每次按鈕到runtime.send1、收到正確fixture submitted draft、sending=true。gate成功後同情境草稿清空；失敗保留原稿，通用失敗notice恰一個、原StateError文字不顯示；等待中直接更新controller的新draft保留（不是使用者在sending停用輸入框打字）；fake登出後原draft保留；卸載後晚到成功沒有已釋放controller／草稿例外。沒有真實訊息送出或真實登出。

首輪五案功能斷言已經通過，但fixture只在addTearDown還原debugDefaultTargetPlatformOverride，晚於binding invariant而五案全失敗；在測試結尾即還原，保留teardown後備，沒有改正式程式或放寬功能斷言。最終watch／auth lifecycle／input failure三檔62項約5秒exit0。唯一analyze fixture7.2秒exit1，無error／warning，3info（370／435 use_super_parameters、692新if缺braces），未重跑。

本輪把前輪頁面草稿修正補到登入狀態的實際widget按鈕接線，未改正式程式。不同登入帳號／來源切換、通知當場換身分的完整頁面gate、缺權限重新授權入口及特殊訊息仍待驗；此offline metadata fixture不驗實際直播播放或真實網路發言。完整目標持續。

### 直播頁拒絕送出時保留草稿

定向讀正式watch頁入口發現sendMessage await controller後無條件clear，controller拒絕訪客／未就緒時只是return，所以頁面把拒絕當成功。既有完整guest watch掛載fixture中新增公開頁面入口斷言：填入fake draft後直接呼叫state.sendMessage，原草稿被清成空字串。首輪fixture缺extension import而編譯失敗，補import後才取得19通過／1正式失敗；不是透過停用的訪客UI按鈕發言。

正式頁面保留原controller拒絕提示，但記錄送出起始資格、watch generation／channel、runtime／已驗證snapshot及原draft。await後只有原本可送、仍同頁面來源／身分／runtime、草稿內容與序列化內容未變才clear；未掛載時不讀已釋放draft。錯誤記錄只輸出runtimeType，不再印原文。未改controller傳輸、OAuth/token或聊天室布局。

watch injection／chat lifecycle／input failure三檔57項約4秒exit0；新直接斷言確認訪客被拒絕仍保留fixture guest draft，其他既有播放故意失敗及返回／dispose回歸保留。唯一analyze正式chat入口與fixture6.7秒exit1，無error／warning，2既有info（fixture314／379 use_super_parameters），未重跑。

本輪直接驗證拒絕入口，不代表已登入送出按鈕、成功清空、等待中新草稿／來源／身分保持都已做獨立頁面gate。未建立真實IRC／Native或發真實訊息。下一步補登入帳號的完整UI與fake send等待，完整目標持續。

### 普通送出原地換身分的六個窗口

新增same controller、同runtime的fake換token／登出矩陣。送出前notify listener兩案當sending=true同步換身分，runtime.send0；先前正式send的通知後snapshot核對確實擋下舊身分，而不是只禁用畫面按鈕。

送出已進runtime等待gate的四案（換token／登出×成功／StateError）在身分變更後canSend=false。放行原fake操作後sending清false、controller notice0；失敗future回傳同一個原StateError物件，不以其他生命週期錯誤覆蓋。runtime.send1是身分有效時已開始的操作，不宣稱撤回；之後再呼叫送出仍不增加次數。guest只在登出為true，replacement token仍非guest，避免把驗證中帳號當訪客。

六案加input failure／watch keyboard三檔43項約3秒exit0。唯一analyze lifecycle fixture5.8秒exit1，無error／warning，5既有info（53缺braces、562／624／691／814 unnecessary_underscores）。只新增mock測試與紀錄，正式controller未再修改，沒有真實發言或凭證操作。

本次不代表完整watch頁的Future／Notice接線或新登入自動重新連線；特殊API、缺權限重新授權入口及其他功能矩陣仍待驗。完整目標持續。

### 輸入框不再顯示過期送出錯誤

新增TwitchChatInputBar隔離widget五案：同情境、busy重建、停用、換TextEditingController、卸載。原程式3通過／2失敗，停用及換草稿仍顯示舊fixture failure，因catch只檢查context.mounted。原錯誤記錄也直接輸出錯誤原文與完整stack；本次fixture全是假資料，未用真實帳號重現。

正式catch讀取目前element上的InputBar，核對仍enabled、同draft controller及sendContext才顯示notice；同情境普通重建或busy變更仍保留錯誤，沒有用widget物件換掉就全部忽略。新增可選sendContext，watch panel傳(runtime, viewerId)經InputSection送至InputBar，不含token且不記錄識別值；其他呼叫者未指定時保持預設null。錯誤diagnostic只輸出runtimeType，不再印錯誤原文與stack。未改訊息傳輸或UI布局。

新增換sendContext第六案，四種過期情境無notice，同／busy两案仍显示fixture failure，所有fake onSend各一次且新draft不被改。三檔input failure／auth lifecycle／watch keyboard共37項約8秒exit0。另強化正式panel的sendContext relay斷言，input＋panel兩檔12項約8秒exit0，證明runtime／viewer key確實抵達輸入框；不是只單測未接上的欄位。唯一analyze三正式入口與新fixture6.6秒exit0、No issues found，relay斷言追加後未再analyze，由test編譯确认。

此為widget與mock future的晚到失敗，未發真實訊息；完整watch send callback的Future／Notice接線、特殊API、原地身分變更及缺權限重新授權入口仍待驗。同runtime／viewer但credentials變更依賴目前enabled更新，不宣稱sendContext本身監聽token。完整目標持續。

### 普通訊息送出晚到的生命週期修正

新增close／換runtime各含舊送出成功／StateError四案，fake send設gate。原程式四案均失敗：新connect後sending仍true，不能啟動新送出；dispose後舊finally仍notify，觸發已釋放controller錯誤，失敗送出原StateError甚至被FlutterError蓋掉。

正式sendMessage取connection generation、runtime與驗證snapshot，通知後再核對才呼叫傳輸；catch僅目前世代／同身分回報controller notice，錯誤仍rethrow；finally只由仍持有送出操作的runtime清sending與通知。新connect及disposeRuntime同步清舊sending，讓新來源可開始自己的送出，不讓舊結果清除新的sending。已釋放controller直接忽略新send。未改IRC封包、token儲存或已送訊息的實際傳輸行為。

四案修正後通過：舊操作完成／失敗都不產生controller notice；close後notification次數不增加；換源時新fake send可開始，舊完成後新sending仍true、新gate未完成，直到新結果才清false。傳輸各自只是假runtime，已開始的舊send不宣稱可撤回。三檔lifecycle／watch keyboard／message keyboard44項約5秒exit0；唯一analyze兩入口5.8秒exit1，無error／warning，5個fixture info（53缺braces、486／548／615／738 unnecessary_underscores），未重跑。

本輪直接驗證controller的換源與釋放，尚非真實帳號／IRC發送；原token原地變更、通知時換身分的send gate、特殊訊息API晚到、input bar呼叫者的晚到錯誤notice仍需個別回歸。特殊sendPendingSpecialMessage與API payload未在本輪調整。完整目標持續。

### 聊天身分防護的六個獨立窗口

新增connect／startup／listener三窗口，各含fake換token與登出，直接覆蓋前輪新增防護。connect案先讓舊runtime.connect開始並等待，再換身分放行；connect次數1是身分仍有效時已開始的操作，完成後runtime／viewer清null、dispose1、supplement與channel callback0，不把已開始的網路操作宣稱可撤回。listener案在正式controller通知、runtime已建立時同步換身分，connect0、runtime釋放及舊viewer清除。

startup案正常connect完成，但startup snapshot回應仍在gate，換身分後才放行；原runtime收到supplement0、channel callback0，不能送fake訊息。這案不要求controller自動dispose既已完成的連線，也不是已驗證登入變更會自動匿名重連；本輪驗證的是晚到補充資料不回填。六案canSend=false，guest判定只在真登出的fake狀態為true，replacement token仍checking而非guest；fake runtime送出均0。

三檔lifecycle／watch keyboard／message keyboard共40項約5秒exit0；唯一analyze fixture5.8秒exit1，無error／warning，5既有info（53缺braces、389／451／518／641 unnecessary_underscores）。只新增六個測試與紀錄，前輪正式防護未再修改。沒有真實IRC或憑證讀寫，自動重連、發送中換身分、缺scope composer提示／重新授權入口及完整功能矩陣仍待驗，完整目標持續。

### 身分變更後不再使用舊聊天室 token

新增同controller兩案：已驗證舊帳號，Drops補充載入設gate，等待期間fake auth換token或登出，再放行。初次fixture把String token欄位誤覆寫正式TwitchAuthToken getter而編譯失敗，改為currentToken後才取得正式重現：兩案舊runtime.connect均1，期待0；前輪connection generation只管新connect／dispose，未包含「身分變了但尚未呼叫新connect」的窗口。

正式controller在補充載入後及runtime.connect完成後比對共享session的驗證snapshot；失配時僅清理仍由本操作持有的runtime、清viewerLogin／resolvedViewerId及已連token，不清理新世代。清理通知可能立即啟動新connect，因此viewer回呼清null也要確認取消後世代仍相同。startup supplement晚到亦核對expectedIdentity，避免回填過期身分；真正connect前的notifyListeners後再同步檢查，防止listener當場換帳號。未更動OAuth/token儲存、Drops儲存或IRC協議。

两新案修正後runtime.connect0／runtime null／viewer null／最後viewer callback null／canSend=false。lifecycle＋兩keyboard三檔34項約4秒exit0；最後notify同步檢查追加後，lifecycle15項再次exit0，確認最终程式可編譯與既有生命週期相容。唯一analyze正式controller與fixture5.7秒exit1，無error／warning，5個fixture info（53缺braces、289／351／418／541 unnecessary_underscores），最後防護追加後未重跑。

全部換帳號／登出只發生在fake auth，不讀寫真實憑證、不發真實訊息。此為Drops等待中的身分失配重現；runtime.connect正在進行時、startup晚到及通知listener換身分新增防護尚缺各自gate斷言，登入完成後的自動重連與送出中身分變更仍待補。完整目標持續。

### 舊聊天室連線完成不再解鎖新連線

兩個受控mock同controller換來源：舊runtime.connect等待，新runtime.connect也等待，先完成舊連線（成功／StateError兩案），原finally無條件清connectingChat，兩案均重現期待true／實際false。舊future錯誤仍由原呼叫者收到，不吞失敗或把尚未準備的新來源當成功。

正式controller新增_connectionGeneration，connect每次取新世代；取消subscription、dispose舊runtime、解析身分、讀Drops存量與runtime.connect後都校驗仍為目前世代，只有目前操作才能收尾通知與套startup。disposeRuntime使舊世代失效、清connecting與已連token；reconnectAfterNetworkRestored的收尾也確認未釋放、世代与runtime相同。只改controller生命週期，不改IRC封包、OAuth儲存、Drops儲存或其他協議。

新增網路reconnect晚到兩案：新來源connect仍等待時舊reconnect完成，不清新connecting；controller.dispose後再完成reconnect不通知、runtime保持null、canSend=false。原連線成功／失敗兩案在舊完成後皆保留新connecting=true／canSend=false／fake sends0，新完成後只新runtime可送fake訊息1、舊0。這是換來源／mock連線，並非真的换帳號驗證或IRC斷線故障注入。

最終lifecycle／watch keyboard／message keyboard三檔32項約4秒exit0，沿用前輪scope五矩陣、guest與late validation回歸均通過。唯一analyze正式controller與fixture5.7秒exit1，無error／warning，5個fixture info（53缺braces、222／284／351／474 unnecessary_underscores），未重跑。真實發言零次。缺權限composer提示、授權入口與同controller身分改變／發送中競態仍待驗，完整目標持續。

### 普通聊天室發言的權限防護

TwitchWatchChatController原canSendForCurrentViewer只核對已驗證身分、連線token與connecting／disposed，沒有確認IRC scopes。新增五種隔離帳號：空scope、只有chat:read、只有chat:edit、只有user:write:chat，以及chat:read+chat:edit。前四種原程式均錯誤回canSend=true，新增斷言四失敗／完整權限一通過。依[Twitch官方IRC授權說明](https://dev.twitch.tv/docs/chat/irc)，IRC連線發言使用chat:read與chat:edit，不能把API的user:write:chat替代成IRC授權。

正式controller增加hasIrcSendPermission，普通composer與sendMessage實際runtime呼叫前均核對；缺權限保持已登入、不能普通發言，直接呼叫時提示「目前帳號缺少聊天室發言權限，請重新授權。」。特殊訊息不走普通IRC：沿用原本身分／連線token防護與各API授權，pending存在時不因IRC缺scope誤擋；預覽回歸確認沒有假IRC送出，清除pending後回到不可發言。未修改IRC協議、OAuth儲存、Channel Points payload或特殊訊息API。

測試包含驗證前發言零次、四種缺權限帳號fake runtime送出0、完整權限送出1，及既有guest連線／重試／晚到驗證dispose、正式panel鍵位與composer flags。最後三檔28項約5秒exit0；唯一analyze正式controller與fixture5.8秒exit1，無error／warning，3info（fixture53缺braces、189／312 unnecessary_underscores），未重跑。全部傳輸／帳號寫入是假的，沒有真實Twitch發言。

這修正普通發言許可，不代表所有特殊API權限已驗證；pending此次只驗preview。缺scope的composer提示／重新授權入口完整接線、缺chat:read帳號匿名讀取fallback、同controller登入變更與發送中競態仍待補，既有token／IRC連線方式沒有在本輪改動。完整目標持續。

### 追隨權限提示不再誤稱未登入

正式Following缺user:read:follows時已保持authenticated且不發私人資料請求，但共用提示卡固定標題「需要登入 Twitch」、按鈕「用 WebView 登入」，未區分訪客與缺權限帳號。強化既有missing-scope測試，先重現已登入卻沒有正確標題的失敗；不是token判定或儲存邏輯失效。

TwitchLoginRequiredView新增可選titleText／loginButtonText，未傳參數的其他入口保留原本行為。Following以已驗證cachedAuth與canReadFollows選缺權限提示「已登入，但缺少追隨權限／重新授權」及對應說明，訪客仍顯示登入；只修改這個權限情境的文字，不調整布局、token、登入WebView或Twitch協議。補三個英文翻譯，正式頁面英文widget斷言也通過，重新授權只触發假的callback一次。

測試保留初始缺scope authenticated／資料請求0、只有點按鈕才假登入、grant後retry讀取並移除提示；同service身份失權／guest與reload有無四組合，分別核對標題與按鈕。先兩檔65項通過，再補英文頁面連home回歸三檔105項約7秒exit0。唯一analyze正式Following、共用提示卡及session測試6.7秒exit0、No issues found；翻譯／英文fixture追加在其後，由完整flutter test編譯確認，未重跑analyze。

這是正式widget與服務配合隔離auth／傳輸，非Windows真實OAuth權限授予或真實失權帳號測試；沒有登出、改憑證或對外寫入。本輪修提示誤導，不宣稱登入／所有快捷路由已全面完成。下一步補其他登入入口的同類權限／失效提示與點擊防護，完整目標持續。

### 相同編碼設定的原生初始化更新

新增REPLACE_INIT_NATIVE：第一個本機bear fMP4先解碼至500ms以上，再讓清單更換map URI、下載第二份初始化時設gate。等待期間bufferedBytes仍為完整首段；放行後送第二段。第二map增加合法12bytes free box，編碼設定與解析度相同；第二段以各track mdhd timescale把tfdt平移三秒，僅改記憶體副本、不寫原始影片。新fixture測試核對零位移相同、正負三秒可逆、長度與原始輸入保留；這不是不同codec／解析度或任意MP4解析器的驗證。

Windows35.0秒建置／6秒exit0：mapRequests2／fragmentRequests2／session.opens1，Native進度3,600ms，跨過原首段2.769秒與新段3秒起点；stream-pos990,649大於首份完整媒體764,465，原生讀取已進第二段。transport單GET／attachment、1,528,942bytes收取與flush相等、pumpFailures0。Native中央非黑0.878472／Flutter0.878419，尺寸1280×720，主動暫停取樣時差0ms，恢復後再前進400ms斷言通過；没有換Player或重新open來掩蓋切換。EGL固定hint不是故障結論。

因共用fixture新增參數，回歸EMPTY_INIT_NATIVE：34.4秒建置／3秒exit0，map2／segment1／opens1、Native600ms、764,465bytes及兩層畫面，恢復後前進通過。新時間戳fixture連init／pending／failure／replay共13項約6秒exit0。唯一analyze三入口7.0秒無error／warning、integration6既有info。只新增測試與紀錄，未改正式播放／hash／token／協議；本輪補相同編碼map更新的原生證據，不撤銷歷史Twitch黑畫面。不同編碼／解析度、廣告discontinuity及完整功能矩陣仍待驗，下一步回到訪客權限頁面流程，完整目標持續。

### 空初始化修正的原生播放器驗證

EMPTY_INIT_NATIVE以本機可解碼bear fMP4接正式router與watch，第一個map HTTP200空body，第二個有效map先等Native reader接入才放行。prefetch=0，放行前分段請求0／Native position0；放行後mapRequests2／fragmentRequests1／session.opens1，同一次開啟成功解碼，不依watch八秒恢復poll重新open或重開App。帳號與chat為隔離fixture、音訊關閉，沒有真實Twitch帳號寫入。

首輪34.7秒建置／48秒exit1：已取得Native700ms與兩層內容，但fixture錯把保持HTTP開啟的直播proxy當成會隨短影片自然EOF，最後45秒等待失敗。修正fixture契約為恢復播放後進度再增400ms，仍要求不buffering及opens1；未更改正式proxy讓直播提前結束，也不把首輪局部解碼當整體成功。最終35.2秒建置／3秒exit0：Native667ms非黑0.952053，中央0.881547／Flutter0.880991，aspect匹配、取樣差0ms（主動暫停捕捉），恢復後前進斷言通過。只保留數字，不保存實況／chat圖。

transport一個GET／一個attachment、764,465bytes接收與flush相等、pumpFailures0、MP4 init首段true；原生decode／output尺寸1280×720、decoder drop0／VO drop1。EGL固定hint仍非原因。這是首次空map重試到同open原生解碼的受控證據，不是替換不同初始化的連續解碼或歷史Twitch黑畫面重現。

新增持續空map-close案：至少三次HTTP200空body，lastWrittenSequence=-1、無媒體bytes，Native外的HTTP讀取者已接入；主動close兩秒內attach／reader皆終止，僅容許正常關閉或HttpException。這測取消，不宣稱無限等待有自動截止。四案獨立通過，再連init／pending／replay／failed switch共18項約6秒exit0。唯一analyze新兩測試7.1秒無error／warning、6既有info；最後fixture契約修正在analyze之後，由Windows編譯執行確認，未重跑analyze。只測試／紀錄，正式修正沿用前輪；完整目標持續。

### 空初始化與持續錯誤的傳輸修正

新增empty-map／failed-map-recover／failed-map-close三案，使用本機HTTP與正式isolate proxy。empty-map第一個HTTP200回空body，原程式快取空map並直接輸出moof；首輪等18bytes逾時，再以九bytes前綴斷言明確重現期待ftyp、實際moof，不是只有測試時間不夠。正式_loadInitMapBytes在快取前拒絕空body，拋固定HttpException，由既有writer重試路徑重新取得map；沒有把HTTP成功當有效初始化，亦不新增hash／憑證／原生選項變更。

持續503兩案在替換map請求至少15次、超過一輪14次HTTP重試後，既有reader仍只收到完整舊init+分段3，沒有偽造新媒體或提前結束。recover案改HTTP200後，同一reader接到新init版本2+分段4且無錯誤；close案持續拒絕到主動proxy.close，兩秒內reader終止。首輪close fixture把onError及onDone重複完成Completer並讓預期強制斷線HttpException成未觀察錯誤，已分開紀錄readerError與單次完成，僅close容許HttpException，recover仍要求零錯誤。沒有把這個fixture錯誤當正式缺陷。

修正後連pending reader／init HTTP／replay／router failed switch共17項約6秒exit0。唯一analyze正式proxy與新fixture2.8秒exit0、No issues found。本輪未重跑相同Windows成功樣本；合成ftyp／moof只證明排列與恢復，不代表Native解碼。此持續503窗口約一轮重試，不能宣稱任意長度永久錯誤已有終止上限；空map持續無限回傳、初始化切換原生連續解碼及歷史黑畫面仍待驗。完整目標持續。

### 初始化下載中重連的正式修正

新增三個本機HTTP gate：初始map未回傳、分段只送四bytes、替換map未回傳。原程式初始map案通過；替換map案新讀取者三秒逾時，因writer先beginSegment清除舊分段、再等待新map，只留下舊初始化供重連。半段案首次未達bufferedBytes=4，定位fixture response緩衝，設bufferOutput=false後才形成真正部分傳輸窗口；首次fixture呼叫liveStatus方法的編譯錯誤亦不當正式重現證據。

正式writer先取得新map，再切分段及初始化，等待期間保留舊初始化與完整分段。修正初版回歸7通過／1失敗：14次map錯誤案因保留的舊buffer被fatal catch誤當成失敗項的部分輸出而停止engine。新增_itemOutputStarted，每項開始清false、成功取map後開始輸出才置true；只有該項已開始輸出且buffer非空才沿用既有停止規則，尚未輸出的新map失敗不把舊replay當損壞媒體。未改Twitch hash／token／協議或原生播放器設定。

最終三新案連既有init HTTP／replay／router failed switch共14項8.3秒exit0。新map等待中reader收到完整舊ftyp+moof，不需放行gate；放行後另一次reader收到新map版本2+新分段4。部分傳輸案先核對init+四bytes，再放行並核對完整分段，初始map案連線後先無媒體、放行才取得正確順序。合成box僅證明傳輸排列，不能冒充可解碼原生影片。

Windows既有WATCH_EOF／WATCH_SURFACE及partial reject原生回歸35.6秒建置／11秒exit0：故意截斷後Native EOF／position0，原watch poll再次open，opens2／requests3／generation+1、position600ms／completed=false、764,465bytes完整收取與flush、pumpFailures0。Native非黑0.950980／Flutter0.878419，原生解碼及濾鏡後尺寸均1280×720、decoder drop0／VO drop1。新增診斷欄位實際有值；EGL固定hint仍非原因證據。本案不是map gate的原生解碼或歷史Twitch黑畫面重現。

唯一analyze正式proxy入口與新fixture3.2秒exit1，無error／warning，1新info：fixture121:69 unnecessary_underscores，未反覆analyze。已修的是map等待時丟失可播放replay；永久map失敗、替換map的原生連續解碼、歷史90秒黑畫面及完整矩陣仍待驗。完整目標持續。

### 新診斷的真實剪輯切直播樣本

Windows以MEDIA_MINI／MINI_RECOVERY_SWITCH／CONTROLLED_RECOVERY／REQUIRE_RECOVERY_OVERLAP／MINI_CLIP_FIRST執行，34.9秒建置、27秒測試exit0。儲存身分解析後追隨為預設；測試明確點瀏覽並搜尋公開媒體作為剪輯來源，不把測試切瀏覽誤判為App預設頁。剪輯解碼、返回mini與前進後，Flutter點首頁另一直播caseoh_，舊恢复保持pre-open等待，新來源解碼後才放行。三個pending觀察點均true，但native-open觀察點均false，不能視為原生open內部重疊。

直播Native首尾500→11,500ms，十秒續播增10,017ms，playing=true／buffering=false／來源保留。原生中央非黑比例0.996624→0.976863，Flutter中央0.995481→0.977641，比例匹配、擷取差67／33ms；影格僅記憶體取樣。清單HTTP200／HLS=true／DATERANGE=true，其餘廣告marker=false；分段前綴HTTP206／4096bytes／TS=true、MAP=false。router一個GET、一個attachment，1,940,536→11,213,072bytes收取與flush相等、pumpFailures=0，前後去敏native分類均空。此為TS成功樣本，不能排除廣告或歷史fMP4黑畫面。

本次10秒延遲診斷前已解碼，新增解碼／輸出數字欄位未觸發，並非欄位零值或不可用。保留黑畫面未結案，不原樣再跑本樣本。定向檢查byte bus與writer：現有HTTP初始化測試在分段寫完後才連線，尚未覆蓋map下載中或分段串流中的新讀取者；下一輪補這些時序的受控證據，未由閱讀程式推定正式缺陷。switch階段build P95=19,811us、12幀超33.333ms，效能限制保留。本輪僅紀錄，未執行analyze、未更動正式播放與憑證；完整目標持續。

### 黑畫面切換診斷的網址誤判修正

切換來源的nativeFlags與分類器使用不同讀取方式：分類器已排除網址，但nativeFlags直接搜尋原始log。抽出原有固定關鍵字算法後，隔離fixture的「Opened」訊息僅因網址含decoder／moov／error／failed／403／404便產生八個旗標，重現診斷誤判；另一新測試也確認原白名單只收video-params/w，缺少解碼高度及輸出尺寸。初次測試在helper未實作時編譯失敗，後續原算法測試為14通過／2失敗，不把編譯失敗当重現證據。

切換計數改用twitchNativeLogFlags，先排除HTTP／HTTPS網址再取固定旗標；真正訊息中的failed與decoder仍保留。白名單增加video-params/h、video-out-params/w／h、decoder-frame-drop-count、frame-drop-count及vo-delayed-frame-count，只接受數字／布林，不支援欄位各自省略。依[mpv官方屬性說明](https://mpv.io/manual/master/#properties)，輸出尺寸是濾鏡後參數，不等於Flutter已顯示影格；掉幀計數亦不能單獨證明黑畫面原因。未修改正式播放流程、原生設定、憑證或協議。

修正後16項診斷測試3.8秒exit0；唯一analyze三入口7.1秒exit1，無error／warning，integration有6個既有info。本輪未重開相同Windows串流；新增欄位尚未取得真實故障時數值。歷史nativeFlags可能受網址誤判影響，不依舊error計數推定原因；既有去敏分類、傳輸及實際失敗證據保留。下一步以失敗當下的transport、解碼／輸出參數及兩層影格定位，不以本次診斷回歸宣稱黑畫面修好，完整目標持續。

### 訪客 VOD 搜尋入口與返回再開

GUEST_HOME_KIND新增vod選項，仍以首頁工具列搜尋及_SearchVodCard的影片ID／頻道精確點擊，未直接掛觀看頁。選擇至少60秒且非isLikelyGrowingArchive的普通VOD，以免把本項混成完整DVR；這個growing判斷仍是模型heuristic，不是來源直播狀態的獨立證明。guest、目的影片、external recorded初始化及獨立client條件保留，clip仍為預設。

Windows VOD模式34.7秒建置、1分13秒exit0：query riotgames、videos12／eligible12，實際riotgames3的一張VOD卡。第一次Native949→11,382→30,350ms，十秒增10,034ms；三時點Native非黑約0.978、Flutter中央約0.9998，有內容。實際UI返回搜尋首頁，關閉測試持有的第一個播放API client再點同影片，第二次Native1,050→11,450→30,417ms，十秒增10,000ms，三時點兩層影格亦有內容。全程不seek、不跳過片頭，影格只記憶體取樣，不保存實況或聊天圖。

watchBundles1→2，watch及播放client均不同，API18→20／Authorization0；guest viewer／chat唯讀／頻道與目的影片ID核對通過。接著同改動的clip回歸34.7秒建置、34秒exit0：同一搜尋的riotgames3 clip兩次各十秒增10,000ms，實際UI返回再開、两層影格及新client、API17→18／Authorization0仍通過。

本輪只改integration與兩份紀錄，正式UI／播放及協議未改。唯一analyze7.0秒無error／warning、6info（5既有＋1新的多行if括號提示），未重跑。匿名公開清單／播放真實，auth／帳號／chat與補充metadata仍mock、音訊關閉；只有單一頻道各一張VOD與clip，不代表畫質／拖曳／所有返回偏好或全頻道。

本輪影片起播已明亮，不能以它撤銷先前riotgames VOD早期暗影格或歷史黑畫面；也未涵蓋原生open內部重疊或完整App startup。下一步繼續訪客權限與其他入口／頻道的矩陣，完整目標持續。

### 訪客剪輯實際返回與同 App 再開

GUEST_HOME_REOPEN在同一Windows程序延伸既有首頁搜尋入口，query riotgames、實際riotgames3的同一剪輯卡。每次factory建立獨立播放API client、watch account client、runtime及session；返回後關閉第一個測試持有的真實播放API client，再點同一卡片。新頁須完成自己的external recorded初始化及channel核對，避免把原mini仍播放的進度當作新頁完成。正式程式未修改。

Windows34.6秒建置、33秒exit0。首開Native963→11,430ms、十秒增10,000ms，首尾Flutter中央非黑0.999304／0.999001。Flutter實際喚醒控制列並點arrow_back_rounded，watch卸載且搜尋首頁工具列重新可見，未呼叫Navigator.pop代替UI。再點同一ID／頻道剪輯卡，Native763→11,196ms、十秒亦增10,000ms，Flutter中央0.999425／0.998880；兩次Native非黑均約0.966、aspectMatches=true，真實影格只記憶體取樣。

watchBundles1→2，watchClients與playbackClients均不同；後者第一個已主動關閉後才第二次點擊。受監測匿名API17→18／Authorization0，guest viewer=null／loadingAuth=false／chat readOnly仍通過。首頁discovery client持續共用、watch補充metadata／chat／帳號服務mock、音訊關閉；這不是所有service client都由正式頁面持有／關閉的證據，也未驗證mini關閉或其他返回偏好。

本輪只改integration及兩份紀錄，唯一analyze7.3秒無error／warning、5既有info。單一clip兩次開啟的生命週期有真實播放證據，不代表VOD搜尋／返回、所有入口、原生open內部重疊或歷史黑畫面結案。下一步延伸VOD入口及其返回流程，完整目標持續。

### 訪客首頁搜尋剪輯卡片的真實匿名播放

新增GUEST_HOME_MEDIA隔離入口：正式TwitchStreamPage工具列輸入搜尋，公開discovery及playback API使用無Authorization的真實client；卡片factory每次建立watch服務及session，與首頁只共享空auth身分。登入儲存、Drops、Web token、聊天及帳號服務仍mock，補充watch metadata也mock。不進app.main、不讀原登入、不直接掛watch代替卡片點擊；正式播放器、UI與協議未修改。

原helper保留默认mock，另提供明確指定runtime／session／playback API的createPlaybackServices。home39＋watch20聯合59項约6秒exit0。唯一analyze7.1秒無error／warning、7 info（5既有integration、1既有fixture、1新增super parameter提示），在後續selector修正前執行，未重跑；最終Windows編譯確認修正後程式。

前六次Windows未算通過：34.7秒／6秒誤把搜尋result wrapper轉成clip而_TypeError；34.1秒／9秒及34.9秒／6秒指定頻道／片長資格為0；34.6秒／7秒及34.3秒／6秒捲動選擇器StateError；34.5秒／10秒同名文字未通過目的剪輯ID斷言，watchBundles1但不能算點對剪輯。相應修正只在fixture：取result.clip、依實際結果的頻道定位、不在懶載入尚無匹配時取first、等結果畫面、以_SearchClipCard的ID與頻道精確tap。沒有放寬目的ID／訪客／播放進度斷言。

最終Windows34.5秒建置、19秒exit0：query=riotgames、搜尋clips12／片長至少20秒的eligible8，實際channel=riotgames3，非主riotgames。正式搜尋卡→route guard→watch，目的initialClip ID與頻道一致；watchBundles1、共享空auth、viewer=null／loadingAuth=false／chat readOnly=true。Native起播830ms有畫面，原生非黑0.966493／76,809色，Flutter中央0.999395／18,749色；十秒進度增10,032ms，結尾Native11,297ms／0.965801，Flutter0.998820／21,762色。兩層比例匹配，播放中擷取時間差67／32ms，非同幀比較。

共用remoteClient API17次／Authorization0，不代表CDN及圖片全部網路請求數。真實影格只在記憶體取樣，不存影片或聊天圖；音訊關閉。這補到單一訪客真實搜尋剪輯入口解碼，非所有頻道／完整App startup、VOD搜尋入口、UI返回再開、畫質／音訊或登入切換。前六次是新fixture接線／選擇條件失敗，不是被成功重跑撤銷的正式間歇播放問題。歷史黑畫面、原生內部重疊與完整矩陣仍待驗，目標持續。

### 新開啟開始前舊開啟已完成的時序證據

受控fixture新增新session open開始時，舊session的pending及completed計數，不更動正式播放器或插入延遲。Windows strict WATCH_OPEN_SWITCH34.5秒建置、9秒exit1：舊等待時tap仍為opens2／completed1；新open開始時atNextOpen=false、oldCompletedAtNextOpen=2；新ownership時亦false。新watch同Player解碼position600ms，但sourceLine3073嚴格重疊條件失敗。

這次補到新呼叫開始前舊呼叫已完成的直接時序，不只是ownership事後狀態；尚不能據此判定所有Native後端都串行、或所有場景均不會重疊。保留strict失敗，不放寬條件、不再重跑相同受控窗口。唯一analyze該fixture7.0秒無error／warning、5既有info。

另外核對既有完整訪客搜尋媒體接線與fixture，再跑home39＋watch20共59項約6秒exit0。VOD與clip各從正式工具列輸入搜尋、捲動點卡片，經guard實際掛watch，驗證guest唯讀、共享空auth身分及各自媒體請求；每案開兩次，返回後factory建立不同client，零登入驗證呼叫且無Authorization。播放API故意回傳可控暫時失敗，這是掛載／生命週期及失敗流程，不是Native解碼成功。返回使用Navigator.pop API，非UI返回按鈕。

本輪只改integration時序診斷與兩份紀錄，既有搜尋factory程式未更動。真實搜尋卡片到Native播放、其他入口、RPC無回應及歷史黑畫面仍待驗，完整目標持續。

### 診斷前綴上限與原生等待時切換證據

修正上一輪segment診斷在Range被忽略時讀完整分段的缺口：Dio改stream response，twitchReadMediaPrefix只保留前4096bytes，達上限即取消剩餘訂閱，並保留4秒stream timeout。新增65,536byte首chunk、禁止取下一chunk、取消收尾，以及空／短／跨chunk案例，連既有診斷共14項通過。不改正式播放器資料通道，保留上限不等於網路層只傳4096bytes。

WATCH_OPEN_SWITCH新旗標要求WATCH_SWITCH，用舊open等待而非第三次media回應訊號觸發Flutter合成切換，並額外要求新ownership當下舊native open仍pending。首輪以輪詢等opens2／completed1，34.1秒建置、22秒exit1，未取得觸發窗口，sourceLine240是等待helper；不能推論原生沒有開始或原生卡死。

改以LocalWatchSession開啟開始事件通知，僅通知、不延遲或攔住Player.open。第二輪34.2秒建置、10秒exit1：切換前oldOpens2／completedOpens1、nativeOpenPending=true；實際Flutter tap後新watch同Player解碼且position633ms。ownership事件記錄atClick=true／atNewOwner=false，sourceLine3065嚴格斷言失敗，故不能宣稱ownership／原生開啟內部重疊已通過。它補到舊開啟尚未完成時使用者切換的真實信號，但原生操作排序原因尚未證明。

唯一analyze三個診斷／fixture檔7.0秒無error／warning、5既有info；在事件通知替換輪詢前執行，最終Windows編譯確認，未重跑。兩筆Windows失敗均保存，不降低條件、不加人為原生延遲；嚴格斷言後的影格取樣、恢復至結尾尚未執行。沒有保存實況／聊天圖片，原帳號未操作。

前綴保留上限已修；strict overlap仍未達成且不是已定位的正式播放缺陷。下一步檢查實際新open呼叫開始與舊restore完成的先後，或繼續矩陣中其他可驗項目，不再重跑相同嚴格失敗。歷史黑畫面與完整功能目標持續。

### 自然恢復開啟耗時與新來源接手時點

正式Host只在既有OBSERVE_RESTORE_OPEN旗標啟用時，量測restoreSharedMedia中await Player.open的耗時，公開最後完成操作的固定微秒數。正常旗標關閉不建立計時器，沒有改開啟／版本防護或延遲；integration另記mini recovery開始至新ownership的毫秒數。15項既有mock開啟競態回歸通過，不冒充原生重疊。

Windows真實剪輯mini自然恢復→首頁kaicenat直播卡，34.9秒建置、29秒exit0。restore open started1／completed1、最後await耗時281,443us；newOwnerElapsed3,642ms，atClick／atMount=true、atNewOwner=false。兩項計時分別起於restore await與mini recovery，非完全相同起點，但本次接手時舊開啟已完成的直接bool證據仍明確。這解釋本次沒有達成重疊，不能推論所有開啟都只需281ms，或此await代表整段影片已解碼。

新來源首尾原生／Flutter取樣有內容，10秒前進10,000ms；reader1GET／1attachment／pumpFailures0，收到及flush最終13,716,912bytes，TS／無map。切換階段build P95=15,634us、16幀>33.333ms，未修卡頓。native錯誤分類兩階段皆空，未保存實況或聊天室圖片。唯一analyze7.0秒無error／warning、5既有info，未重跑。

額外發現segment診斷的Range請求被忽略，HTTP200／1,959,524bytes，現有Dio bytes讀取沒有4096硬上限。這是診斷讀取負擔的待修缺口，不是播放器實際資料通道錯誤或黑畫面根因證明。下一步先限制診斷前綴，再在受控正式觀看頁中以舊open等待信號而非media gate信號觸發新route；只有新ownership當下仍pending才算原生開啟重疊。歷史黑畫面與完整矩陣未完成，目標持續。

### 候選清單逾時與等待中取消回歸

新增本機HTTP gate，候選清單的回應一直不放行。三案在best-effort prewarm後仍讓請求等待：自然啟動截止、改成新直連、close。自然截止由正式router回傳TimeoutException並保留原直連[1,2,3]；改源與close則在舊HTTP回應未放行時兩秒內結束舊switch，無晚到錯誤，亦未安裝舊inner或寫回清單。改源後新直連[4,5,6]仍可讀，close後router不運作。

新三案獨立通過，連既有失敗換源／pending switch／late headers／reader及init共27項約10秒exit0。正式程式僅將上一輪已提升為非空的candidateStatus多餘?.改成直接存取，未更改deadline、輪詢或重試行為；唯一analyze三個相關檔No issues found（2.9秒）。本輪沒有重開Windows App或操作真實帳號。

這驗證未收到清單的引擎狀態与候選截止／取消，不涵蓋isolate RPC完全無回應而status=null、所有慢網路或原生Player.open內部重疊。原生解碼證據仍引用前輪，不將本機傳輸測試當成歷史黑畫面已修；完整目標持續。

### HTTP 重試結果確定後才接手候選來源

新增持續503的本機清單測試。修正前switchUpstream的best-effort prewarm只等700ms，HTTP才請求5次便成功返回並接手候選，尚未完成既有14次重試；首輪要求重試耗盡的斷言失敗。上一輪明確running=false的檢查未涵蓋引擎仍在重試、尚無清單的情況。

正式router保留原重試協議，在prewarm後等待候選playlistVersion>0或明確stopped；每次status await後校驗generation，50ms輪詢間隔，另有8秒啟動截止時間。時間到回傳固定TimeoutException並依既有current catch還原原來源，不把暫時未知狀態立即當成失敗；舊操作過期則清理候選並退出。8秒截止與未知status分支尚需專門回歸，並非所有慢網路均已驗證。

持續503案實際14次失敗後回傳StateError，原直連[1,2,3]仍可讀。新增前六次503再成功案，成功後仍可讀ftyp／moof byte=7；首輪fixture錯把成功後正常刷新算成第八次失敗，改分開計數503回應與所有清單請求後通過，不改正式刷新頻率。聯合6個失敗換源案與既有傳輸／init共24項通過。

唯一analyze2.8秒無error、1個新warning：正式router第270行candidateStatus已被流程提升為非空，?.多餘；本輪未反覆analyze或清理該警告。計數fixture修正後由最終flutter test編譯確認。修改後Windows WATCH_EOF／WATCH_SURFACE35.0秒建置、11秒exit0：原8秒poll重新open、opens2／requests3／generation+1，position734ms／completed=false，reader送出及flush764,465bytes／pumpFailures0；原生非黑0.952411、Flutter中央0.882958／22,114色，恢復畫面通過。

本輪定位並修正候選清單未就緒就接手的正式缺陷。Windows是既有可解碼fMP4恢復回歸，不是503完整App端到端重現；原生open內部重疊、啟動截止／未知status及歷史真實黑畫面仍待驗，完整目標持續。

### 換源失敗後原 HLS 的資料還原驗證

既有損壞清單fixture擴充原來源為HLS的兩案，與原直連兩案合計四種組合：原來源類型乘上舊失敗是否已被新直連取代。所有來源均來自本機HTTP，不讀真實帳號。損壞清單仍由正式parser觸發停止，不以router mock例外取代。

原HLS未被取代時，候選失敗回傳StateError，原upstream URL／inner保持，重新GET router讀到原ftyp及moof各自識別byte=7，live status.running=true。舊失敗已被新直連取代時，原HLS不還原，新直連仍收到[4,5,6]且無晚到錯誤。這驗證的是初始化／分段傳輸及內層狀態，不是合成box的原生解碼。

四案與pending switch4、late headers2、reader7、init HTTP3及init replay2共22項通過（約4秒測試）；本輪唯一analyze修改fixtureNo issues found（2.8秒）。只改測試與兩份紀錄，沒有新正式缺陷或runtime修改，不重開Windows App。HTTP重試耗盡、原生open內部重疊、真實fMP4間歇黑畫面及完整矩陣仍待驗，完整目標持續。

### 換源候選已停止時保留原來源

新增真實本機HTTP損壞清單，segment URI無法解析，使用正式內層引擎而非注入router例外。首輪未被取代的換源案失敗：候選的HTTP服務仍開著，但播放引擎已停止，router卻安裝broken清單、丟失原直連。舊請求被新直連取代後才放行損壞清單的另一案原本通過，保留兩者差異。

正式router於候選prewarm後讀取既有live status，只在明確running=false時拒絕接手；未知status與正常尚在等待不當成終止失敗。此await之後仍校驗來源generation。當本次操作仍有效時，失敗收尾還原原direct URI及原upstream清單，保留既有inner／replay；過期操作不還原或撤回新來源。失敗訊息固定、不含URI，不改Native Player設定、登入或Twitch協議。

新兩案驗證原直連[1,2,3]仍可讀且收到固定StateError、舊請求過期時新直連[4,5,6]仍可讀且無晚到錯誤。加pending switch4／late headers2／reader7／init HTTP3／init replay2共20項通過；唯一analyze正式router與新fixtureNo issues found（3.0秒）。

修改後Windows WATCH_EOF／WATCH_SURFACE受控可解碼fMP4回歸34.9秒建置、11秒exit0：故障reader送出及flush1,317bytes、MP4 init=true，requests2／opens1／completed=true／position0。原頁8秒poll重新open後opens2／requests3／generation+1、position600ms／completed=false；新reader送出及flush764,465bytes、pumpFailures0，原生非黑0.950980、Flutter中央0.878419／22,118色，恢復畫面通過。

本機HTTP正式缺陷已修，Windows另驗證正常候選仍可恢復解碼；不是損壞清單在完整App的原生端到端重現，也不涵蓋HTTP重試尚未耗盡時的失敗、所有來源類型或Native open內部重疊。歷史黑畫面仍未結案，完整目標持續。

### 原生與 Flutter 中央區域對照診斷

診斷新增twitchCentralFramePixelSummary，取原生中央60%以對照既有Flutter texture中央60%。同時只輸出比例是否相符、擷取前後播放時間差及paused；不保存或回傳影格。新增不同解析度的亮邊框／黑中心fixture，證明整幅非黑比例>0.1但同區域為0，連既有診斷共12項通過。這修正量測可比性的缺口，不更改正式播放、UI或既有視覺門檻。

Windows匿名kaicenat Archive／paused加入新對照與暫停後額外取樣，34.6秒建置、1分8秒exit0。起播883ms原生中央0.805823／Flutter0.747035、aspectMatches=true、positionDelta50ms。5,233ms播放中原生中央0.006982／Flutter0.407559，差33ms；主動暫停後5,266ms對照為原生0.409524／Flutter0.407559、時間差0ms且比例相符。Sequential capture在播放中並非同一影片幀，不能單憑差值判定顯示異常；paused數據支持本次兩層接近，不足以還原或解釋前輪暗影格。

公開20 videos中1Archive匹配；正常匿名live續播10秒增10,017ms。完整Archive warm及實際Slider80%後十秒增10,034ms，lag2,766,707ms／漂移0、startupResets0。UI pause後Slider30% target4,153,404ms，解析／保持暫停通過；UI play恢復十秒增10,016ms，實際返回live按鈕後增10,000ms。API7／Authorization0，TS／無map，未保存實況或聊天室圖片。

本輪只改去敏診斷／integration fixture與紀錄；唯一analyze6.9秒無error／warning、5既有info，未重跑。前次低於視覺門檻的失敗仍保留，本次起播內容不同且未重現同一失敗，不當成正式黑畫面修復。原生open內部重疊、fMP4真實失敗、舊請求失敗及其他矩陣仍待補，完整目標持續。

### DVR 中斷的切換狀態收尾與暗影格失敗

補測上一輪generation防護的DVR中斷分支：保留fast HLS，slow HLS清單等待時呼叫interruptPlaybackStream，再放行舊清單。首輪舊來源沒有覆蓋回來，但health的switching=true，測試失敗。原因是中斷已使舊流程過期，而只有旧流程finally原本會結束切換狀態；這是上一輪新增防護的收尾缺口，不是已證明的歷史黑畫面根因。

正式interruptPlaybackStream在取得操作主導權時清除switching，既有reader取消及source generation防護不變。新案確認switching=false、fast來源／inner保留，新的HTTP reader仍收到原初始化與分段byte=2，不換回slow來源。pending switch4＋晚到標頭2＋reader7＋init HTTP3＋init replay2共18項通過；本輪唯一analyze正式router及fixtureNo issues found（2.8秒）。

修改後Windows匿名kaicenat Archive／paused流程34.9秒建置、11秒exit1：公開20 videos中1Archive匹配；起播666ms原生非黑0.075326／12,551色、Flutter中央非黑0.029987／1,017色。相同來源自然前進至5,350ms時原生0.084444／9,694色、Flutter0.030229／1,081色；最後取樣position5,383ms、原生0.086033／Flutter0.031802／1,108色，未達既有原生非黑>0.1門檻，sourceLine2351失敗。

這不是两層全黑；畫面內容過暗與顯示差異仍未區分，不能憑非黑比例推論停播。playing=false來自擷取前主動pause，buffering=false、API7／Authorization0；controller的GPU／EGL固定提示1，播放及cleanup階段無新增分類。沒有保存實況影格或聊天內容，沒有降低門檻或重跑同一來源。Archive warm、拖曳、paused seek、恢復與返回直播尚未執行，因此本輪Windows完整DVR回歸未通過。

來源競態收尾已有HTTP修正證據；暗影格及歷史黑畫面仍未定位，舊請求失敗分支與原生重疊仍待測。下一步需對照相同內容區域的原生與Flutter影格，避免整幅原生畫面和Flutter中央裁切的比例被當成同一量測。完整目標持續。

### 舊 HLS 載入不得覆蓋新來源或關閉狀態

新增本機playlist gate重現另一個正式router競態：switchUpstream還在等待舊HLS清單時，另一操作已切到新直連或close；放行舊清單後，舊流程仍安裝inner／replay並寫回upstreamPlaylistUrl。首輪兩案皆失敗，close後也殘留舊來源。這是整個換源流程的晚到完成問題，不是上一輪單一GET標頭防護所能涵蓋。

正式router新增獨立source change generation，在來源操作及close時使舊流程過期。HLS start、prewarm與replay start每次await後確認操作仍有效；過期只關閉自己建立的proxy，不安裝来源。catch／finally與重連結束也避免覆寫更新的狀態。保留既有Twitch協議、Native Player設定、UI及登入儲存。

新3案涵蓋切到新直連、新HLS，以及close。新HLS案除了來源身分，還讀取新初始化ftyp與moof各自的識別byte=2，確認舊載入放行後沒有換回byte=1。這些是合成box的傳輸測試，不是可解碼fMP4影片。新3＋晚到標頭2＋reader診斷7＋init HTTP3＋init replay2共17項通過；本輪唯一analyze正式router與新fixtureNo issues found（2.8秒）。

修改後另跑Windows本機可解碼fMP4 WATCH_SWITCH：34.5秒建置、24秒exit0。殘片EOF為requests2／opens1／position0，第三次media gate等待時opens2／completedOpens2，nativeOpenPending=false。Flutter合成按鈕push新watch，同Player／controller解碼；放行舊回應後URI／兩頁generation保持，取樣position1,234ms、原生非黑0.960836、Flutter中央非黑0.903413／21,612色。主動暫停取樣後實際UI play，增1,534ms到自然EOF，duration2,802ms、舊opens2／新1、sourceRetained=true。

正式來源競態已修並有同範圍HTTP及原生回歸。Windows流程是舊media回應等待，非新清單gate缺陷的原生專屬重現或Native open內部重疊；歷史真實Twitch黑畫面仍未結案。下一步補過期失敗與完整DVR中斷／返回直播對此防護的回歸，完整目標持續。

### 真實剪輯切直播的九十秒觀察

正式Windows App以既有唯讀登入進首頁、公開搜尋及剪輯卡片，剪輯解碼後返回mini，再點另一首頁直播卡切到kaicenat。使用自然恢復與OBSERVE_RESTORE_OPEN，不加controlled gate。34.6秒建置、1分49秒測試exit0；Flutter合成操作，不操作系統滑鼠、不改憑證，真實影格只在記憶體取樣，沒有保存實況或聊天圖片。

新來源初次影格position433ms、原生非黑0.265394／20,547色，Flutter中央非黑0.511417／7,364色。接續每10秒進度增加10,000／10,016／10,000／10,017／10,033／10,050／10,017／10,017／10,016ms，90秒共90,166ms；每個檢查點playing=true、buffering=false、sourceRetained=true。結尾原生position91,500ms、非黑0.236192／18,434色，Flutter中央非黑0.401741／5,216色。取樣時畫面有內容，不以單張影格證明整段每幀正常。

reader requests1／attachments1／pumpFailures0，received及flushed最終皆91,838,000bytes。媒體前綴HTTP206／4096bytes、TS／無init map；playlist DATERANGE=true，但stitched-ad／discontinuity／SCTE35=false，不能單憑DATERANGE判斷廣告。native分類beforeMount與afterMount皆空。restore open atClick=true／atMount=true／atNewOwner=false、started1／completed1；pendingAtNewOwner=false，因此只證明換源成功，不是舊恢復與新ownership重疊。

切換階段7,700個frame樣本，build P95=12,402us／raster P95=3,788us，38幀build超過33.333ms；未修卡頓，也不推算FPS。本轮只更新紀錄，未跑flutter analyze，Windows編譯及完整測試通過。TS來源90秒成功不撤銷歷史fMP4／90秒黑畫面失敗，不將晚到標頭修復宣稱為所有黑畫面的根因；完整目標持續。

### 晚到回應防護後的 Windows 恢復與換源回歸

使用既有隔離WATCH_SWITCH流程驗證目前正式router，35.2秒建置、24秒測試exit0。殘片／變更前綴造成EOF時，requests2、opens1、position0，reader已送出及flush各1,317bytes且MP4 init=true。原頁重新open後第三次media回應保持gate；切換時oldOpens2／completedOpens2、nativeOpenPending=false、mediaResponsePending=true。Flutter合成按鈕push新觀看頁，新頁使用同一原生Player及VideoController並解碼。

放行舊回應後新URI與兩頁generation保持，舊opens2／新opens1未重開；取樣position1,167ms，原生非黑0.948072、Flutter中央非黑0.867950／20,838色，公開bear fixture截圖目視確認有影片。取樣主動暫停後的10秒僅驗證來源保留，不算續播；接著實際點播放按鈕恢復，前進1,601ms到自然EOF，duration2,802ms、sourceRetained=true。未操作系統滑鼠或真實帳號。

另跑不換源的WATCH_EOF／WATCH_SURFACE原頁恢復，34.3秒建置、11秒測試exit0。同一故障後原8秒poll重open：opens2、requests3、generation+1、position600ms、completed=false。新reader送出及flush各764,465bytes，attachments1、pumpFailures0；原生影格position633ms、非黑0.950831，Flutter中央非黑0.878661／22,223色，畫面恢復通過。

本輪沒有修改正式程式或測試fixture，僅補兩份紀錄與受控fixture圖片；未執行flutter analyze，兩次Windows建置均成功。這是正式觀看頁與原生解碼的本機fMP4回歸，不是新晚到標頭缺陷的Windows專屬重現、原生open內部重疊或真實Twitch90秒黑畫面結案。固定GPU／EGL提示仍存在，但未阻止本輪解碼，不把提示單獨當成根因。完整目標持續。

### 換源後拒絕舊來源晚到的回應

本機HTTP gate重現正式router的來源競態：舊來源GET正在等待回應標頭時，switchDirectStream切到新來源；放行舊回應後，原播放器連線仍收到舊資料[1,2,3]，原本要求空回應的斷言失敗。切換時尚未建立active iterator，因此既有取消iterator不能阻止這個晚到回應。這是可重現的傳輸漏洞，尚未證明它就是歷史90秒黑畫面的原因。

正式TwitchStableHlsProxyRouter在標頭await後檢查server、reader generation與switch generation；過期回應不安裝active iterator、不計入目前連線診斷，也不輸出資料。直接來源切換結束舊連線；其他來源模式仍可依既有迴圈接回目前來源。逐chunk檢查也加入switch generation，避免等待資料期間跨來源輸出。不改Native Player設定、UI、憑證或Twitch協議。

新增兩案：舊回應放行後才開新reader，以及新reader已收到新資料後才放行舊回應。兩案都確認舊連線為空、新連線收到[4,5,6]、attachments只有1且pumpFailures為0。新2案連既有reader診斷7、stopped playlist1及inflight prefetch4共14項通過；另partial、init HTTP及init replay共19項通過。本輪共33項隔離回歸通過，唯一analyze正式router與新fixture為No issues found。

本輪沒有Windows原生解碼或實況長測。晚到標頭漏洞已修並回歸，不能以HTTP資料正確推論畫面解碼正確；歷史黑畫面、原生open內部重疊及完整DVR多來源驗證仍保留。

### 原生錯誤分類排除網址文字

診斷分類先前直接比對完整原生訊息，只有未分類提示排除網址。新增隔離測試重現：成功開啟訊息中的假網址含有error，即被錯算為unclassified_failure；首輪11項中10項通過、1項失敗。此問題會污染黑畫面的錯誤證據，不代表它造成播放器黑畫面，也不能據此撤銷歷史錯誤紀錄。

TwitchNativeLogDiagnostics改為先移除HTTP與HTTPS網址，再進行所有既有錯誤分類與提示比對。測試覆蓋網址不能憑空產生錯誤、真正未分類錯誤仍保留，以及真正read error仍正確分類。修正後11項全部通過；本輪唯一flutter analyze只檢查兩個診斷檔，No issues found。沒有改正式播放器、UI、登入或協議，也沒有重跑Windows實況。

歷史clip切live的90秒黑畫面與kaicenat起播暗影格仍未定位。後續需要在同一次失敗中對照代理資料、播放時鐘、原生影格與Flutter影格，不能以診斷測試通過或一次播放成功宣稱已修。

### 觀看 route guard 轉交完整隔離服務

正式TwitchWatchRouteGuard新增可選initialServices及initialChatRuntimeFactory，原樣轉交TwitchWatchPage。參數未提供時維持既有預設；不改route可見性、pause／mini判斷、登入／token或UI。這補上原先guard無法安全帶入完整watch服務的接線，不是已定位的正式登入／黑畫面修復，也尚未把首頁各卡片接上服務factory。

既有訪客錄播8案（VOD／clip×暫時失敗／拒絕×留頁／等待中卸載）改由真實guard掛載watch，auth pending不解析、guest唯讀、晚到失敗及retry來源保持的斷言仍通過。其餘watch12及home37聯合共57項約5秒exit0。home搜尋卡片route仍在watch真正掛載前移除，不能把home37＋guard8拼成完整卡片到播放器成功。

Windows隔離guest入口改以正式guard掛watch，zackrawrr匿名Archive／paused模式35.6秒建置、1分7秒測試exit0。公开8 videos中1Archive匹配，起播783ms／5,566ms兩層有畫面；正式warm、非20秒完整Strip80%拖曳十秒增10,016ms，兩層Archive影格非黑0.947051／0.945685。UI pause再30%拖曳target8,238,724ms，保持暫停兩秒／解析及display門檻通過，UI恢復十秒增10,017ms、返回按鈕後live增10,000ms。API7／Authorization0、chat仍唯讀，TS／無map。像素仅記憶體取樣，不保存真實影片／聊天圖片，未讀原帳號。

唯一analyze正式guard與兩fixture7.7秒無error／warning、5既有info，未重跑。只補正式依賴轉交及測試／紀錄；單一路由直接注入、非完整App訪客首頁／搜尋入口、push-pop所有路由、音訊或真實fMP4。kaicenat暗影格與歷史90秒黑畫面仍未定位結案，完整目標持續；下一步將安全factory接到實際卡片入口，保持每個watch獨立client生命週期。

### 第二頻道匿名 Archive 與起播暗影格診斷

GUEST_ARCHIVE_PAUSED換kaicenat，新增去敏失敗sourceLine，並將回看日誌區分archive及usingLiveTimelineReplay，避免Archive的短buffer flag=false被誤讀為沒有回放。首輪35.5秒建置／8秒exit1：公開20 videos中1筆匹配目前live Archive，已掛native／Texture；起播366ms原生非黑0.066161、Flutter中央0.008594／373色，於2338視覺比例門檻失敗。不是兩層全黑，API7／Authorization0；playing=false為擷取前主動pause，不能當自發停播或DVR失敗。Archive warm／拖曳尚未執行，原因未判定。

新增同一guest live起播及5秒自然前進的兩層影格取樣，再保留原比例斷言，不跳轉或換來源來掩蓋。第二輪34.4秒建置／1分8秒exit0：起播766ms原生非黑0.479468／Flutter0.560730；5,533ms原生0.512276／Flutter0.365015。該輪起播已與前輪不同，不能据此證明增加等待修好了前次暗畫面，來源內容及起播顯示差異仍未區分。

同輪匿名Archive warm可用、完整時間條80%拖曳後bridge解析差<2秒，十秒增10,016ms，lag2,203,202ms／漂移0；原生12,950ms影格非黑0.507427、Flutter0.527929／2,465色。UI pause再拖約30%、target3,305,687ms，新URI／bridge解析／兩秒保持paused與display門檻通過；UI play恢復十秒增10,017ms，按鈕返回live十秒增10,000ms，所有startupResets0、API7／Authorization0。分段HTTP200／TS／無map，未保存真實影格或聊天內容。

唯一analyze整合fixture7.4秒無error／warning、5既有info；在最後live五秒取樣補充前執行，最終Windows編譯驗證，未重跑。只改診斷／測試與紀錄、正式播放器／UI／憑證未改。第二頻道Archive取得及播放有通過樣本，但首輪視覺失敗保留，非間歇問題已修、更多畫質、真實fMP4、網路恢復或完整訪客入口證據，完整目標持續。

### 匿名 Archive 暫停拖曳與按鈕恢復

GUEST_ARCHIVE_PAUSED補實際UI pause、完整時間條再拖約30%、UI play恢復。要求新Host media URI與原先80%回放不同、bridge解析位置與preview差<2秒、無timeline action且native保持paused／非buffering；觀察2秒位置差<500ms、正式timeline snapshot仍近preview。之後實際點播放、等穩定時鐘，再十秒增>7秒，Archive bridge仍運行且非buffering，最後仍實際點返回live及十秒續播。

Windows匿名zackrawrr 35.5秒建置、1分2秒測試exit0。公開8 videos中1筆對應当前live；正常80%Archive十秒增10,016ms，兩層影格有內容。UI pause後30%preview target8,022,726ms，bridge generation3／client5的新流解析並保持暫停，2秒位置保持及display目標門檻通過；UI恢復穩定起點2,099ms、十秒增10,017ms。按鈕返回live再增10,017ms，Authorization0、chat仍唯讀，startupResets0。分段HTTP200／mpegts／無map，未取得真實fMP4。

唯一analyze修改fixture7.5秒無error／warning、5既有info，未重跑。只修改測試及紀錄、正式UI／runtime／憑證未改，影片僅記憶體取樣。本輪REPLAY_SECONDS使用預設10秒，不能追溯列為重跑前輪60秒；覆蓋兩次不同位置拖曳及一次暫停跳轉，不是所有比例、回放chat、音訊、更多頻道或網路故障驗證。完整目標持續，其他Archive樣本、故障／恢復與完整訪客入口仍待补。

### 匿名 Archive DVR 的完整時間軸拖曳與六十秒續播

修正前輪fixture日期差為difference、三处播放狀態為公開usingLiveDvrBridge，移除多餘archiveTarget!。Windows zackrawrr／GUEST_ARCHIVE／REPLAY_SECONDS60，35.3秒建置、1分35秒測試exit0：匿名公開live及8筆video中，1筆Archive符合類型／growing與開播時間差不超過120秒；選中錄影帶正式watch header及initialActiveDvrVideo。正式hasUsableLiveDvrArchive預熱可用，Strip liveSeekWindowDuration=null，確實是完整時間軸，不是20秒回看。

Flutter實際Slider從中心拖到約80%，放手後usingLiveDvrBridge=true且解碼，bridge解析位置與拖曳preview差<2秒；此為解析位置不是逐幀精度。換流穩定起點2,616ms，六段十秒增10,017／10,016／10,017／10,000／10,017／10,016ms，共60,083ms，末尾62,699ms。每次playing=true／buffering=false、Archive bridge保持運行，lag皆5,291,618ms、漂移0。舊日誌replay=false指usingLiveBufferReplay，而非Archive失效；各段另有usingLiveDvrBridge斷言通過。媒體分段診斷為mpegts／hasMap=false、HTTP200。

原生63,083ms影格非黑0.842813／86,387色、Flutter0.901446／14,703色。實際點LiveStatusButton後兩種replay狀態解除，返回live穩定起點1,966ms、十秒增10,017ms。初始live十秒增10,016ms，媒體API／metadata請求7次、Authorization0，player viewer auth為anonymous、chat保持唯讀；錄影及直播圖片僅記憶體取樣。

唯一analyze修改整合fixture7.5秒無error／warning、5既有info，未重跑。前輪編譯失敗仍保留，但當前fixture可編譯且實測通过；正式程式、UI、憑證與Twitch協議未改。這是單一頻道／單次拖曳的匿名Archive native播放證據，auth／startup／discovery續查與chat仍隔離mock、入口為直接注入已匹配錄影，非完整App訪客卡片路由或回放聊天室。更多頻道／畫質、暫停跳轉／重複拖曳、網路故障／恢復及歷史黑畫面仍待驗，完整目標持續。

### 完整匿名 Archive DVR 測試接線尚未編譯通過

GUEST_ARCHIVE模式新增公開live及前20筆錄影讀取，要求type為archive、疑似growing且createdAt／publishedAt與真實live開播時間差不超過120秒，避免拿舊VOD當目前DVR。選中錄影帶initialActiveDvrVideo、live帶正式header metadata，仍使用隔離auth／startup／chat與匿名媒體API。計畫等待正式DVR warm可用，核對Strip不是20秒窗口，實際拖完整時間軸約80%、解析位置接近preview、60秒续播及按鈕返回live。這些只完成fixture接線，尚未執行任何Archive資料或播放斷言。

Windows zackrawrr／GUEST_REMOTE／GUEST_ARCHIVE／REPLAY_SECONDS60：28.6秒建置exit1，App未啟動，沒有真實頻道／錄影／匿名授權結果。測試錯誤為2136使用DateTime减法，以及2464／2511／2550引用不存在的runtime.usingLiveDvrReplay。唯一analyze7.0秒同4error、2476多餘archiveTarget! warning及5既有info；前輪多餘initialLag!已移除。依每輪限制不循環修跑，當前整合fixture不可編譯，不宣稱既有訪客短回看回歸已重新通過。

已唯讀核對正式介面：日期使用created.difference(liveStartedAt)，Archive播放狀態為usingLiveDvrBridge（內部replay且bridge運行），usingLiveTimelineReplay涵蓋Archive及短回看。下一輪只修測試介面與局部警告後編譯，再驗證實際Archive是否可取得及匿名是否可播放；本輪不改正式程式、UI、登入或既定Twitch協議。完整目標持續。

### 訪客短回看六十秒與返回直播按鈕

GUEST_REPLAY加入有界REPLAY_SECONDS設定，預設10秒、允許10至120秒整十秒。實際Slider拖至約80%及換流時鐘穩定後，每十秒要求native進度>7秒、playing／非buffering、仍liveBufferReplay，並記錄正式timeline clock相對直播邊緣的lag；最大漂移須小於2秒。返回不再直接呼叫State方法，改Flutter tap控制列、確認Strip內可點的LiveStatusButton及其GestureDetector.onTap，再实际tap該按鈕。

Windows匿名ow_esports 35.6秒建置、1分33秒測試exit0。初始live十秒增10,011ms；回看穩定位置1,967ms，六段十秒增10,026／9,994／10,027／10,010／10,009／10,007ms，共60,073ms，末尾62,040ms。六次lag皆5,178ms、maxLagDrift0，playing=true／buffering=false／replay=true。末尾原生62,456ms影格非黑0.999454／171,206色、Flutter1.0／27,812色。实际tap返回後runtime離開replay、重新解碼，穩定起點2,168ms、十秒增10,010ms；兩段startupResets0、API4／Authorization0，chat保持唯讀。

唯一analyze整合fixture7.5秒無error、1新增warning（2441多餘initialLag!）及5既有info，未重跑，局部提示留下一輪。只補測試與紀錄、正式UI／runtime未改；影片僅記憶體取樣。這是同一TS來源的一次匿名60秒短回看及按鈕返回，不证明每幀精度、20秒全長可取、完整訪客入口或Archive DVR；metadata為公開快照，其餘auth／startup／discovery與chat仍隔離mock，fixture未提供Archive。前輪未穩定起算的十秒失敗仍保留，不以這次成功宣稱正式卡頓已修。完整目標持續，下一步完整匿名Archive及頁面接線仍待補。

### 匿名訪客短回看的實際時間條拖曳

GUEST_REMOTE新增GUEST_REPLAY模式，限匿名live來源。先以正式guest discovery讀ow_esports公開stream資料，將id／開播時間快照注入隔離watch fixture的metadata回應，驗證state開播時間等於真實快照；不使用原本固定fixture日期。其餘auth、startup／discovery回應及chat仍mock，沒有讀原帳號；fixture不提供Archive，因此hasUsableLiveDvrArchive=false不代表頻道真的沒有VOD。正式媒體API使用anonymous resolution，檢查所有Dio請求Authorization為0。

Flutter實際tap控制列、對20秒短回看Strip內hitTestable Slider做拖曳：從中心move寬度30%，preview約80%，放手後正式runtime進入liveBufferReplay並原生解碼。首次35.6秒建置／29秒exit1，已解碼及無buffering，但十秒進度斷言失敗，末尾position9,380ms；當時未記起算位置，不能確定是否換流時鐘重設或播放問題。保留失敗，沒有修改正式程式或放寬門檻。

fixture補換流後playing／非buffering／無timeline action並連續2秒前進至少1秒的起算檢查，之後十秒仍要求增>7秒。再測34.7秒建置／43秒exit0：匿名live初始原生399ms、非黑0.999098／Flutter1.0、26,074色；live十秒增10,010ms，TS／HTTP206。回看穩定起點1,902ms、末尾11,916ms，十秒增10,014ms；原生12,349ms影格非黑0.965183／141,921色、Flutter1.0／26,138色。正式returnToLivePlayback方法返回後起點2,619ms、十秒增10,027ms，兩段startupResets0，Authorization0／API請求4、chat仍唯讀。返回為公開方法，不當成返回按鈕UI測試；新增前置穩定門檻亦不證明前次失敗原因已定位。

watch session fixture回歸20項通過。唯一analyze兩修改fixture7.8秒無error／warning、5既有info；在最後穩定起算helper前執行，最終以Windows編譯／回歸驗證，未重跑。真實影格仅記憶體取樣，未保存直播／聊天圖片、未改憑證或正式UI／runtime。這是同頻道短回看的一次匿名拖曳＋續播，不是完整Archive DVR、所有訪客入口、精確影格seek、20秒實際可取長度或長期不卡頓證明。完整目標持續，返回直播UI按鈕／更長觀察及完整匿名Archive仍待補。

### 三種正式來源的有界直播格式檢查

前次format scan只查web-site，未涵蓋正式runtime已有的android-autoplay及ios-site。本次診斷helper新增platform／playerType可選參數，預設仍web／site；整合fixture以正式既有三組參數查詢，不改GQL、token儲存或正式runtime選源。範圍仍最多6個首頁頻道、每來源最多3個非audio-only畫質，每媒體只讀至4,096bytes，輸出固定格式／HTTP／count／bool，不保存網址、憑證或媒體。

Windows MEDIA_MINI／MINI_CLIP_FIRST／LIVE_FORMAT_SCAN：35.9秒建置、53秒測試exit0。原App登入與公開搜尋、真實clip導頁／解碼通過，之後只做API／HTTP格式探測，不切到每個頻道播放。ow_esports、zackrawrr、kaicenat、jynxzi、trymacs、dona各web3／Android2／iOS3，共18來源、48個畫質前綴，全部mpegts且hasInitMap=false；fmp4Channels=0。playlist皆HTTP200；media多206，jynxzi web前兩項HTTP200忽略Range，診斷仍限制4,096bytes。

這是本批時間／頻道／前三畫質的格式可用性證據，非全Twitch沒有fMP4、全部畫質、匿名授權、48個播放器解碼或黑畫面修復。真實fMP4未在這批取得，保留缺口；不以TS代替fMP4故障驗證。格式probe5＋停止晚到清單1＋inflight4共10項隔離回歸通過。唯一analyze改動helper／整合fixture及上轮正式poller防護／新HTTP案7.4秒無error／warning、5既有info，未重跑，補齊前輪新增防護的靜態檢查。

只改兩份診斷測試及紀錄、未修改正式程式或登入；本輪未重跑恢復／DVR／60秒續播分支，完整目標持續。後續繼續訪客DVR及正式頁面缺口，真實fMP4與native開啟內部重疊仍列待驗。

### 停止後晚到清單仍抓分段的防護與原生快取對照

新增固定numeric／yes-no原生欄位診斷，拒絕文字、網址、非有限值及超長值，unsupported／unavailable省略而非零；兩項新增與既有8項聯合10項通過。[mpv官方屬性說明](https://mpv.io/manual/master/#properties)中stream-pos描述送往解碼器的最近封包位置，demuxer快取時間是估計值，不表示已成功解碼或收到整個HTTP內容。新診斷接入真實換源等待及受控fMP4故障／恢復；未讀path、stream-path或metadata。

本輪受控Windows36.0秒建置／1秒exit1，checkpoint再次requests3而非2；reader送出1,317bytes且MP4 init=true，native EOF／cache duration0／core-idle=yes，原生stream-pos不可用。先前claimed修復只涵蓋writer仍在處理的窗口；這次定位另一窗口：_runPlaylistPoller在await清單後未核對停止狀態。writer拒絕前綴後stop清空prefetch及claim，等待中的舊playlist回來仍schedule，造成多餘第三GET。

新增gated HTTP案：第二清單response先等待，第二segment fallback再變更前綴讓engine停止，放行晚到清單後300ms檢查沒有新的segment GET。正式修正前unexpectedFetch=true失敗；正式poller於await之後加_stopped／server存在防護。初版修後測試仍誤要求保留停止前playlistVersion1，但服務停止snapshot正常為0；改成比較放行前後的停止snapshot版本，沒有放寬禁止第三GET。與inflight4／router7／partial14／init3／native診斷10聯合39項約4秒exit0；中間38通過／1失敗及版本斷言失敗保留。

同一Windows故障修正後34.8秒建置／11秒exit0：checkpoint requests2、native EOF，reader收到／flush各1,317bytes、MP4 init=true，cache duration0／eof=yes／core-idle=yes。原頁poll自動重open後requests3／opens2／generation+1、position600ms／completed=false；reader收到及flush各764,465bytes，原生stream-pos226,172、cache duration1.935267秒／cache time2.702700秒、core-idle=no／eof=no。原生非黑比例0.950980，Flutter中央0.878419／22,118色，恢復畫面通過。fw-bytes／total-bytes等此平台未回傳的欄位不視為零。

唯一analyze診斷helper／測試及整合fixture7.7秒無error／warning、5既有info；在後續poller防護及新HTTP案之前執行，最終以39項測試與Windows編譯驗證，未重跑analyze。未修改原生open等待或人為延遲正式播放器；真實native內部重疊及歷史90秒Twitch黑畫面仍待驗。只修正式poller停止防護、補診斷／測試與紀錄，不改UI、登入／Twitch協議；完整目標持續。

### 真實剪輯切直播的六十秒傳輸與影格對照

Windows唯讀MEDIA_MINI／MINI_CLIP_FIRST／MINI_RECOVERY_SWITCH／OBSERVE_RESTORE_OPEN，新增SWITCH_OBSERVATION_SECONDS=60有界觀察；預設仍10秒，允許10至120秒整十秒。36.1秒建置、1分18秒測試exit0：既有登入解析、公開搜尋、真實剪輯卡→迷你→首頁直播卡導頁通過，選中ow_esports。恢復native open在click=true、mount=false、newOwner=false，started=completed=1，pending亦同；新頁掛載前舊恢復已結束，不計為恢復／native內部重疊通過。

新直播清單HTTP200／HLS，媒體Range206／4,096bytes、TS sync=true／MP4 hint=false、無init map／BYTERANGE／AES128／SAMPLE-AES。variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY／SCTE35=false；marker缺席不排除未標記廣告。初始原生position567ms，非黑比例0.999799／156,445色，Flutter 1.0／35,301色。

六次十秒增量10,001／10,010／10,017／10,011／10,012／10,014ms，共60,065ms；各取樣playing=true、buffering=false、來源與owner URI保留。router最新reader requests1／attachments1、HTTP200／pumpFailures0，received及flushed由2,986,192增至66,265,488bytes、開頭TS sync=true。50秒取樣flushPending=true且兩計數差8,185bytes，60秒已相同並pending=false；不可把一次非同步flush尚未完成直接算停頓。這些是HTTP送出端進度，不等同播放器已消費全部bytes。

末尾原生position61,383ms、非黑比例0.998252／272,007色，Flutter 0.999596／30,526色；真實影格仅在記憶體取樣，不保存直播或聊天圖片。beforeMount／afterMount固定原生失敗分類皆空。debug換源build P95=7,686us、15幀逾33.333ms，raster P95=3,964us／無逾門檻幀，不宣稱效能問題修好。

唯一analyze整合測試7.3秒無error／warning、5既有info，未重跑。只補測試／紀錄、未修改正式runtime或登入資料。這是TS單一真實來源60秒續播，不是原生恢復內部重疊、真實fMP4故障或歷史90秒黑畫面全部結案；完整目標持續。

### 換源後播放按鈕恢復與短素材自然結尾

WATCH_SWITCH延伸保留原本10秒暫停來源觀察後，Flutter實際tap控制列再點hitTestable播放圖示；等待playing且非buffering、進度較起點增>300ms，再等待native completed且進度增>500ms。全程核對新URI、兩頁generation、舊opens2及新opens1未被改動，不用直接Player.play代替UI按鈕，也不重open新來源。

Windows36.0秒建置、24秒測試exit0。第三回應pending時nativeOpenPending=false，新來源接手且舊response放行後，兩層影格非黑比例0.948072／0.867950、20,838色；像素取樣暫停位置1,167ms。UI恢復後進度增1,601ms、native completed=true、原生duration2,802ms，sourceRetained=true、舊opens2／新1。短素材自然結尾通過，不冒充10秒續播、長時間播放、所有錄播EOF路由或原生open內部重疊；此頁仍是隔離訪客live fixture掛完整本機短片，未測8秒poll之後的completed重試。

唯一analyze整合測試7.4秒無error／warning、5項既有info，未重跑。只修改整合測試及紀錄，正式播放器／UI／憑證未改；保存的畫面僅公開bear素材。歷史切直播90秒黑畫面仍需真實故障與傳輸診斷對照，完整目標持續。

### 恢復回應等待中切來源的重複預取修復回歸

恢復inflight測試必要dart:async import後，4案inflight／7案router／14案partial／3案init聯合28項重新通過，當前測試不再是前輪缺import的不可編譯狀態。唯一analyze五相關檔6.6秒無error／warning、5項整合fixture既有info，未重跑；未修改正式播放器或UI。

Windows WATCH_SWITCH同程序35.9秒建置、22秒測試exit0：受控殘片與變更前綴後EOF，checkpoint requests2、reader收到／flush各1,317bytes、MP4 init開頭=true。原頁8秒poll重新open，第三次媒體回應gate保持未放行，opens2／completedOpens2，nativeOpenPending=false、mediaResponsePending=true。Flutter實際tap fixture按鈕push第二個正式訪客觀看頁，新頁同Player／controller以本機完整短片解碼；旧State仍mounted。放行舊response後新URI與兩頁generation不變，500ms進度增>150ms，舊opens2／新opens1。

新來源position1,167ms，原生非黑比例0.948072、Flutter中央0.867950／20,838色。像素驗證helper主動pause並未resume，末尾10秒只檢查來源及opens保持，最終position仍1,167ms；不能列為10秒持續播放。這是媒體回應等待中的換源／短解碼回歸，不是native open內部重疊、長播、真實Twitch fMP4或歷史90秒黑畫面結案。控制器固定unclassified_failure／gpu／egl各1保留，非原因證明。只保存公開bear測試素材圖，不保存真實直播／聊天畫面；完整目標持續，下一步補新來源恢復播放與有限素材結尾／更長來源的證據。

### 處理中分段被清單刷新重複預取

第三次分段請求的正式原因已可重現：writer的takePrefetchJob把工作從佇列移除，但分段stream／fallback尚未完成、URL還沒markWritten。此時清單reload重新schedule相同URL，額外抓一次。新增有界本機HTTP對照，暫停第二次fallback回應、讓正式playlistVersion再前進3次；MP4／TS樣式×正常／前綴變更4案，修正前皆Expected2／Actual3失敗。fixture首次漏status模型import導致載入失敗，補齊後才取得4案正式重現。

engine新增claimed URL集合，take時保留處理中狀態，schedule排除claimed；writer於pipe成功或失敗的finally釋放，engine.stop清除。未把claim當作written，不取消既有重抓／前綴驗證、EOF或更改初始化順序。修正後4案及router7／partial14／init3共28項約4秒exit0，未放寬原計數斷言。

Windows同一WATCH_EOF／WATCH_SURFACE故障35.7秒建置、11秒exit0：故障checkpoint requests2／open1、native completed=true、position0；HTTP reader送出1,317bytes、MP4 init開頭=true。原頁8秒poll自動重open後requests3／opens2／generation+1、completed=false／position567ms；新HTTP reader收到及flush各764,465bytes、HTTP200／pumpFailures0／MP4 init=true。原生非黑比例0.952065、Flutter中央0.881385／21,569色，恢復畫面通過。這是已定位的重複預取修復及同故障回歸，非歷史所有90秒黑畫面的根因證明；恢復中切新來源及更多真實格式仍待補。

修掉前輪整合fixture兩項多餘null運算warning及router測試不必要async import。其後誤把新inflight測試必要dart:async import移除，唯一analyze7.6秒回報該檔17／18／19行Completer未定義3error及5項既有info，無warning；28項通過是在誤刪import之前，不代表目前新測試仍可編譯。依每輪限制未循環修analyze，下一輪先恢復必要import並重驗。正式engine／writer及Windows整合編譯與回歸已通過，不改UI、OAuth、GQL、IRC或點數協議；完整目標持續。

### 播放器連線的去敏傳輸診斷

正式stable router新增只讀streamReadDiagnostics：最新GET的上游回應碼、接線次數、收到及flush完成的bytes、flush等待與pump失敗數；HEAD另外計數。只在記憶體保留最新連線開頭8 bytes，輸出固定TS sync／MP4初始化／fragment布林，不輸出內容、網址或憑證。新GET重設每連線數值，舊generation不得回寫新讀者；不改原本response add／flush、重試、EOF或切來源順序。flush完成是HTTP送出端進度，不等同原生實際消費或成功解碼；header分類也不保證完整MP4合法。

新增HTTP診斷7項涵蓋ftyp／moov／moof／styp／TS／未知／不足8 bytes、拆段送header、HEAD不取上游、第二GET重設及舊snapshot獨立；每案核對實際response完整bytes未改。與init HTTP3項聯合10項通過，既有partial fallback14項另通過，共24項。這是本機HTTP證據，不是Windows解碼成功。

首次Windows參數漏PARTIAL_DECODE而執行既有唯讀主流程，35.9秒建置／29秒exit0，儲存登入、公開搜尋、直播卡、唯讀chat及15秒進度通過；不記為故障恢復測試。正確啟用PARTIAL_DECODE／PARTIAL_PROXY／PARTIAL_REJECT／WATCH_EOF／WATCH_SURFACE後，34.8秒建置／1秒exit1：原頁open1次並收到native completed、position0，但故障checkpoint分段請求實際3次而非預期2次，於該斷言停止，未驗證後續重開或恢復畫面。最新HTTP讀者requests1／attachments1、received及flushed各1,317 bytes、status200／pumpFailures0／flushPending=false，開頭MP4 init=true、fragment=false。確認初始化開頭已送到HTTP端，但這不證明分段完整或黑畫面原因。請求時序差異尚未定位，保留失敗，不放寬計數或重跑冒充恢復通過。

整合測試在真實恢復切來源的10秒診斷中接入相同去敏數值；本輪沒有執行該分支，因此仍需真實故障當下的證據。唯一analyze三修改程式7.5秒：無error、2新增warning（整合測試2596多餘?.、2680多餘!）及6info（5既有、1新測試不必要dart:async），未重跑或循環修檢查。只增加診斷／測試與紀錄，不宣稱歷史90秒黑畫面已修，完整目標持續。

### 同一 VOD 回看片頭的黑畫面對照

riotgames匿名VOD自然播放、續播後，以同一Player直接seek回1／5／15秒做診斷，不重新open或解析媒體；每次核對Host網址未變，只輸出時間與像素統計。Windows36.5秒建置、48秒測試exit0：自然574ms／5,362ms兩層全黑，15,422ms原生非黑0.745808、Flutter 1.0；30,387ms原生0.999979、Flutter 1.0，再續播10秒增9,992ms。

播放器暫停回看後，1,008ms與4,996ms原生518,400取樣及Flutter33,048取樣皆全黑、各單一顏色；15,006ms原生非黑0.704377／32,041色，Flutter 0.753177／11,422色。三次均sameSource=true、paused=true，媒體解析請求沒有額外重跑，Authorization仍0。黑畫面在播放器已正常出圖後仍固定出現在相同片頭時間，支持此VOD來源片頭黑場而非一次性起播延遲；這是同一來源、同一解碼器的時間對照，不是獨立解碼器驗證或其他影片結論。

正式播放器未修改，不跳過內容或新增假載入遮罩。早先5秒畫面斷言失敗仍保留，不能把其失敗等同來源持續卡死；歷史clip切直播90秒position=0／buffering的失敗仍未結案。唯一analyze修改整合測試7.2秒，無error／warning、5項既有info，未重跑。診斷僅記憶體取樣、不保存真實影片截圖；直接seek不是拖曳手勢測試。完整目標持續，下一步回到切來源故障及正式代理輸出證據。

### 匿名錄播起播黑畫面的時間取樣

隔離Windows訪客觀看頁增加真實匿名VOD／clip模式，公開頻道資料與媒體解析使用正式API；auth、startup及聊天等維持隔離，不啟App主入口、不讀原帳號。既有watch fixture可選擇注入同一playback API，未提供時仍使用原本禁止播放的替身。搜尋route guard尚缺完整隔離接線，因此本次不是搜尋卡片一路進播放器的驗證。

riotgames VOD首次有界診斷34.7秒建置、9秒測試exit1：原生591ms與Flutter中央取樣皆非黑比例0、單一顏色；自然前進到5,196ms仍全黑，畫面斷言失敗。匿名請求4次、Authorization header 0次；playing=false是擷取前主動暫停，不是自發停播。保留此失敗，不把後續通過改寫為正式修復。

延長同來源自然播放後，36.2秒建置、45秒測試exit0。影片1080p／60fps、audioOnly=false，Host網址與選中variant相同，沒有使用直播DVR代理。624ms與5,362ms的原生及Flutter影格皆全黑；15,439ms原生非黑比例0.754213／31,161色，Flutter 1.0／16,704色；30,421ms原生0.999990／15,319色，Flutter 0.999879／4,214色。全程未跳轉、未重開或換源；30秒擷取後恢復10秒增10,027ms，匿名請求4次、Authorization 0次。此樣本不是持續黑畫面，但仍需回看同一時間段區分來源片頭黑場與起播延遲；不替代歷史clip切直播90秒buffering問題的定位。

同頻道clip對照36.3秒建置、20秒測試exit0：公開候選14筆，選中1080p非audio-only、直接variant。783ms原生非黑0.982934／60,878色、Flutter 0.983811／20,853色；5,200ms原生0.988603、Flutter 0.991074／21,901色，再續播10秒增10,000ms。匿名請求3次、Authorization 0次、訪客chat唯讀。這是直接注入媒體的正式觀看頁短樣本，不是完整搜尋入口、回放聊天或所有頻道證據。

兩種媒體的控制器初始化仍有unclassified_failure／gpu／egl各1次，播放、擷取與卸載分類皆空；不能以此認定GPU是黑畫面原因。原生影格只在記憶體取樣，不保存真實影片或聊天截圖。watch session注入fixture回歸20項通過；唯一analyze兩份修改測試7.7秒，無error／warning、5項既有info，未重跑。正式播放器及UI未修改，完整目標持續。

### 非 Archive 影片不誤走直播 DVR

新增搜尋卡片3案：同樣createdAt為約10分鐘前、length600秒，ARCHIVE應帶initialActiveDvrVideo且不帶普通VOD；HIGHLIGHT／UPLOAD應帶initialVodVideo並保持vodPlaybackOnly。修正前7項匹配／route案例中5通過、近期highlight與upload兩案失敗，選中影片被當成growing而initialVodVideo=null。正式isLikelyGrowingArchive原本只看時間，沒有type限制。

[Twitch官方影片說明](https://dev.twitch.tv/docs/api/videos)區分archive、highlight與upload。模型新增trim／lowercase後只讓archive使用既有估計結束時間窗口；非archive、空／未知類型不推測仍在錄製。不改窗口的負5至20分鐘條件、publishedAt fallback或缺資料行為；此仍是likely heuristic，不保證近期archive真的正在直播。未修改正式UI排版、OAuth、GQL協議或播放器runtime。

修正後home37＋browse21共58項約5秒exit0，卡片實際tap後的Archive DVR入口與Highlight／Upload普通VOD入口皆帶對資料；route仍在真正掛載前移除，不當成解碼。新增模型12項檢查類型／大小寫／空未知／窗口內外／published fallback／缺資料，連guest media3與DVR initialization3共18項exit0，另2項真實網路測試預設skip；本機DVR初始／重連／seek的init順序仍保留。兩批合計76項通過、2skip，不能稱真實網路全通過。

唯一analyze模型＋新模型測試＋home fixture6.5秒No issues found，未重跑。只修改正式video模型、兩份測試與紀錄，未啟真實App或讀帳號；搜尋卡片→完整播放器、真實growing archive與黑畫面仍待驗，完整目標持續。

### 搜尋媒體匹配與晚到剪輯的下一頻道防護

home fixture新增4項媒體結果案例：輸入帶空白的大寫PUBLIC_FIXTURE後標準化為小寫，影片／剪輯標題大小寫匹配保留命中ID且排除不相關title；影片作者、剪輯curator名稱命中時亦保留對應結果。VOD與clip兩案透過正式搜尋頁捲動、確認hitTestable後tap卡片，Navigator新增route，builder回傳正式TwitchWatchRouteGuard，核對channel、同一guest discovery、unknown follow status及selected-vod／selected-clip欄位，完成VOD只有錄影、clip不帶VOD的入口接線。移除route於其頁面真正掛載前，因此不代表目標播放器解碼。

另6案讓第一個舊頻道的clip查詢pending，候選結果包含兩個不同user ID；清除／新關鍵字／離頁 × clip晚到成功／錯誤。放行後影片與clip請求數均不增加，新頁面結果／loading保持，驗證上輪generation防護在clip之後也不續查下一個頻道。未取消原HTTP、未改正式程式。

首次guest搜尋25項中23通過、兩卡片route案失敗：捲動後沒有等layout更新，tap VOD title中心y637超出800×600根畫面，clip亦miss，未push route。補pumpAndSettle／ensureVisible與hitTestable斷言後，home34＋browse21共55項約5秒exit0；不是修正式卡片導頁或UI樣式。所有資料與storage／平台為mock，訪客validate0且Dio授權請求0，不讀原憑證、不啟Native Player或真實App。

唯一analyze只修改fixture6.6秒No issues found，不代表上輪父library既有import info已移除。只改測試與紀錄；搜尋媒體真實資料、直播存檔中分支、多來源上限／重複結果及完整播放器接線仍待補，完整目標持續。

### 搜尋取消後不追加過期媒體查詢

首頁正式guest搜尋fixture補空結果，以及把舊搜尋晚到成功改成真正非空頻道，檢查影片／剪輯查詢數而不只看畫面。修正前三案重現：新關鍵字已有2次媒體查詢，舊結果晚到後變4次；清除與卸載兩案原0次卻各新增2次。原先空舊結果雖不覆蓋UI，沒有走到媒體候選分支，不能證明不續取。

再補影片查詢已pending時，清除／新關鍵字／卸載 × 晚到成功／錯誤6案；修正前全部失敗，舊影片完成後仍多叫1次剪輯。正式searchChannels在頻道結果await後先校驗mounted與search generation；_searchChannelMedia帶入同一generation，在候選迴圈及影片／剪輯await後與錯誤收尾繼續剪輯前再校驗，過期直接返回空bundle，由原最終guard忽略，不追加後續查詢。未取消已送出HTTP，也未改auth／token／GQL協議、UI排版或命名。

修正後home24＋browse21共45項約4秒exit0，涵蓋真實頁面合成輸入／清除／重試、空結果無錯誤、搜尋失敗重試、晚到不續取與不覆蓋新結果、checking／登入缺scope／預設section及瀏覽分類／語言／分頁回歸。隔離服務、prefs與平台mock；訪客沒有token validate、沒有OAuth／Helix授權請求，未啟Windows真實App或讀帳號憑證。

唯一analyze父library twitch_stream_page.dart＋修改fixture6.7秒無error／warning，1既有root4行rendering import info，未重跑或順手清理。只修改兩個正式搜尋part與fixture／紀錄。這是搜尋過期續取修復，不當成播放卡頓或黑畫面根因；真实資料篩選／媒體匹配及完整目標仍待驗證，目標持續。

### 訪客真實直播與 IRC 讀取及離頁清理

GUEST_REMOTE 加 REAL_CHAT 與公開channel參數，本轮zackrawrr使用正式ChatRuntime／BadgeCache及原生IRC WebSocket；recent歷史API不提供、discovery／startup補充資料仍fake。測試IRC子類僅在connect入口確認token=null後轉呼原協議；sendChatMessage入口若意外被呼叫會阻斷並計數，未修改正式IRC或實際發言。所有訊息僅在runtime記憶體／正式頁面使用，輸出只有數量／連線／權限布林，不保存文字、使用者身分、實況截圖或憑證。

第一次34.5秒建置／21秒測試exit1：真實匿名直播、10秒增10,017ms、guest IRC runtime messages17／raw events29／connect1／sendAttempts0／canSend=false皆通過；fixture卻在頁面還mounted時要求disconnect，等待5秒失敗。確認是測試順序錯誤，把檢查移至pumpWidget空頁並卸載後，不改正式清理規則。

修正後34.5秒建置／17秒測試exit0。播放API仍anonymous、3請求／Authorization0；native position383ms非黑0.972253，Flutter中央33,048點非黑0.969075／16,805色。TS／清單200／segment206／4096bytes／無init map，resume後10秒增10,000ms。guest IRC connected=true、runtime messages10／raw events22、connect1、sendAttempts0、pendingOutgoing0、無dual write IRC、canSend=false／isReadOnlyGuest=true；頁面卸載後isConnected=false及sendAttempts0確認通過。這是本機連線狀態解除，不另宣稱server收到close ACK。

chat lifecycle4＋watch injection20同範圍24項約4秒exit0。唯一analyze整合入口6.9秒無error／warning、5既有info（25前綴／34import／2449括號／3262与3291collection），未重跑。audio仍關閉、recent歷史／badge目錄等補充未走真實資料；單一有界guest IRC與TS播放不能替代長播、帳號切換、所有首頁入口、VOD／clip／DVR或fMP4。只改整合fixture与文件，原帳號與正式協議未改，完整目標持續。

### 隔離訪客的真實公開直播播放與畫面

新增 GUEST_REMOTE，不進app.main、不讀原帳號；auth／storage／discovery／chat仍使用既有隔離fixture，只有播放API、runtime、兩層代理、Native Player及VideoController為正式真實流程。新增獨立TwitchApiClient與GqlApi、明確anonymous viewerAuthProvider，逐次檢查該播放client的Authorization header不存在；不修改原憑證或OAuth／播放協議。影片channel使用公開ow_esports，discovery仍fake，因此不是完整公開頻道資料或登入首頁接線測試。

Windows34.3秒建置、16秒測試exit0。正式匿名播放授權／清單請求3次、authorizationRequests0、lastViewerAuthState=anonymous；guest viewerId=null／loadingAuth=false／非離線占位。實際原生position567ms、frame非黑0.999060；Flutter Texture中央33,048點非黑0.998487／16,327色，比例與色數門檻通過。真實直播只在記憶體讀像素、未保存實況或chat截圖，原本本機素材截圖沒有覆寫。

擷取後暫停狀態恢復play，等待playing且不buffering，再10秒position增9,991ms、>7秒斷言通過。清單200／segment206／前綴4096bytes、無init map、格式TS。播放／capture階段分類空；controller階段仍未分類1／GPU1／EGL1，與前輪播放前時點一致，不據此宣稱所有EGL錯誤無害。audio仍停用、chat是mock且唯讀，只證明此單一公共TS源匿名媒體播放與正式觀看頁畫面，不是訪客真實IRC／音訊／長播／fMP4或完整DVR已通過。

同範圍injection20＋cached login11＋auth startup10＋chat lifecycle4＋format5＋native diagnostics8共58項約4秒exit0。唯一analyze僅修改整合入口7.2秒無error／warning、5既有info（22前綴／31import／2373括號／3186與3215collection），未重跑。僅改整合fixture與紀錄，正式程式／使用者登入資料未改；完整目標持續。

### 六個真實頻道的直播格式候選探測

新增 LIVE_FORMAT_SCAN，先沿用真實帳號正常讀取並開剪輯來源，取尚在home route上的公開直播卡前6個不同頻道。用目前仍mounted的正式watch playback API取播放清單，每個頻道只探測前3個非audio畫質，不變更播放授權協議／token。格式helper只保存4096-byte媒體前綴並停止讀取，Range被忽略返回HTTP200仍有界；輸出只有公開channel、variantIndex、status、byte數與格式／map布林，無signed URL、token或原始媒體。

本機5項HTTP測試涵蓋fMP4 box、TS同步、unknown、403及無media，伺服器對媒體皆忽略Range送8192bytes，helper只回報4096bytes；敏感fixture字串不出現在結果。加native diagnostics8项共13項exit0，最後補if括號後13項再通過，未修改正式程式。

Windows34.9秒建置、23秒測試exit0。實際頻道ow_esports、zackrawrr、kaicenat、trymacs、eliasn97、rubius，各3個畫質共18個樣本皆mpegts、hasInitMap=false、清單200、媒體前綴4096bytes。ow_esports variant1返回200，其他17樣本206；所有候選fMP4=0。這是此刻6個頻道的前3畫質前綴格式證據，不代表所有畫質／時段／頻道都沒有fMP4，也不是逐段解碼或播放回歸；scan分支在探測後結束，未執行mini換源。

這轮先證明目前有限候選集沒有可用fMP4，避免用TS播放成功冒充目標格式。原fMP4黑畫面要求保留；完整目標仍可繼續其他待驗功能，不標記blocked或complete。唯一analyze三個修改檔7.0秒無error／warning、5既有整合info（19前綴／28import／2309括號／3122與3151collection），未重跑。僅修改探測helper／新測試／整合入口及紀錄，不改正式runtime、憑證或既定協議。

### 真實剪輯換直播的資料與兩層画面摘要

新增只輸出數字的frame probe，原生screenshot與Flutter最近RepaintBoundary各在記憶體取像素，不保存實況／聊天室圖片。原生frame全區每2px摘要；Flutter只取Texture中央60%寬高，範圍裁切到image邊界，不含周圍聊天／工具列。失敗只輸出固定stage與errorType；native與Flutter各限時2秒。黑像素、門檻、裁切、空採樣與非法RGBA尺寸一項測試加既有7項共8項exit0。只改測試診斷，未改正式播放器。

真實Windows MEDIA_MINI／MINI_RECOVERY_SWITCH／MINI_CLIP_FIRST／OBSERVE_RESTORE_OPEN，保留已登入帳號、唯讀、Flutter合成點擊；34.5秒建置／28秒測試exit0。剪輯原來源、縮小返回與續播後自然恢復並點不同首頁直播卡，新source解碼與owner接手通過。新增frame probe原生position467ms、1920×1080、518,400點非黑0.998225／137,897色；Flutter中央42,042點非黑1.0／27,977色。這輪建立真實換源的兩層像素基線，未保存原始image或signed URL。

公開媒體探測HTTP206／4096bytes、TS同步提示true、無init map／byterange／AES，清單HTTP200、有DATERANGE但無stitched-ad／discontinuity／SCTE35，不能據DATERANGE判廣告。十秒續播與新URI／owner保留通過；native categories切頁前後皆空。恢復pending atClick=true、atMount／atNewOwner=false，native open likewise true／false／false、started=completed=1，因此只有新來源接替，不是恢復或原生open內部重疊。

這次為TS成功樣本，未重現先前fMP4黑畫面，不能算修好；新probe已接到等待期間每10秒狀態觀測與成功基線，實際失敗時仍須同步比對proxy資料／native像素／Flutter像素，不單看時間前進。debug切換build P95=11,800us、14幀逾33.333ms，raster P95=5,676us／0逾門檻，不宣稱零短卡頓。唯一analyze三個修改檔6.9秒無error／warning、5既有整合info（19前綴／28import／2283括號／3096與3125collection），未重跑。只補診斷／測試／紀錄，不改帳號憑證／协议／GPU設定；完整目標持續。

### EGL 訊息在播放前的畫面元件階段出現

GUEST_SURFACE 改為分階段記錄固定分類：controller建立後等待400ms、正式watch播放、原生／Flutter畫面擷取、卸載收尾。診斷helper新增EGL、OpenGL、D3D11、Vulkan四個固定hint，不保留原始文字；新一項URL內容排除測試加既有六項共7項exit0。這輪未重跑完整故障換源流程，改以本機短片直接進正式guest觀看頁隔離階段。

Windows34.7秒建置、測試3秒exit0。controller階段尚未掛載watch或開影片，就收到unclassified_failure1／GPU hint1／EGL hint1；watch_playback與capture分類皆空。影片position367ms、native非黑0.960943、Flutter中央33,048點非黑0.903897／23,459色，安全截圖重新產出並直接檢視確認bear影片可見。cleanup分類亦空，但listener在Host.disposeNow前取消，不能當成完整原生dispose沒有錯誤。

此證據將那筆訊息的接收時點縮到播放前的controller阶段，未包含任何Twitch媒體／廣告請求；後續短片解碼與畫面輸出正常，不能僅據此訊息判GPU為換源黑畫面根因，也不能宣稱EGL所有失敗無害。未取得EGL具體錯誤句型或歷史黑畫面同時的資料／解碼／畫面對照；應回到真實失敗時的分層診斷，不自行改GPU／播放器設定。

唯一analyze三個修改檔6.9秒無error／warning、5項既有整合info（19前綴／28import／2187括號／3000與3029collection），未重跑。只修改診斷helper／測試／紀錄與安全截圖，正式runtime／協議／登入憑證未改。前輪未定位的間歇fixture失敗與真實換源黑畫面仍保留，完整目標持續。

### 原生未分類錯誤的去敏線索與間歇失敗保留

診斷helper新增hardware decode與video output固定句型，以及未分類錯誤的13種固定hint標籤；hint只表示文字涉及的區域，不代表根因。只輸出預設key／計數，不保留原始訊息；hint判讀前移除HTTP網址，避免網址中的audio／codec等字樣誤成線索。新增兩項測試驗證URL去除、正常GPU初始化不算失敗及已知句型不重複落入unclassified；原四項加新兩項共6項exit0。此為測試診斷helper，未改正式runtime。

WATCH_SWITCH第一次加入新分類後，Windows34.9秒建置／約1秒測試exit1；第一來源與native EOF步驟通過，但原debugPrint去敏篩選也隱藏了框架斷言內容，未取得失敗位置／原因，不當成修復完成。之後在EOF檢查點新增requests／opens／completedOpens／native狀態及分類，在受控fixture catch只輸出例外型別與本檔行號，不輸出error文字或stack全文。

補診斷後Windows34.6秒建置／22秒測試exit0。EOF檢查點requests2／opens1／completedOpens1／completed=true／position0；classification為unclassified_failure1、unclassified_hint_gpu1。恢復等待中切換仍old opens2／completed2、nativeOpenPending=false／media pending=true；新來源open1且先解碼，放行舊response後新URI／兩頁generation保留，10秒不重開。position1267ms、native非黑0.963945／Flutter中央33,048點非黑0.911977／22,083色，獨立切換截圖重新產出並檢視可見影片。

這次通過只確認去敏GPU線索與換源有界樣本，未定位第一輪間歇失敗，也無法從文字hint判定GPU是黑畫面原因。後續應針對影片controller初始化／解碼／畫面擷取分階段對照，不以再跑相同全流程成功抹除失敗。唯一analyze三個修改檔6.9秒無error／warning、5既有整合info；補上一輪新增gate收尾括號後已不再出現該info。僅修改診斷／測試／紀錄與安全截圖，沒有改正式程式或登入憑證；完整目標持續。

### Windows 恢復媒體等待中切到新觀看頁

WATCH_SWITCH 在既有殘片→前綴拒絕→EOF流程後，讓第三次segment請求停在本機response gate，等待原頁自動恢復open第二次。用Flutter tester.tap點fixture切換按鈕，透過Navigator.push掛載另一個正式觀看頁；新頁仍fake guest，改播本機原始bear檔案，兩頁共用同一真實原生Player／VideoController，舊State仍mounted。沒有使用系統滑鼠、真實帳號storage或Twitch遠端。

Windows建置34.5秒、測試22秒exit0。切換時old opens2／completedOpens2、nativeOpenPending=false，只有媒體response確實pending=true；這不是原生Player.open Future內部重疊，該要求仍待驗證。新頁在舊response未放行時open1次、Host URI指向新檔案並解碼>500ms；放行後500ms內位置增加>150ms，新URI與兩頁generation保留。再暫停擷取native／Flutter像素後等待10秒，舊opens仍2、新opens仍1，沒有舊頁再重開或蓋回来源；最終position1234ms、上游requests4、原生unclassified_failure1保留未細分。

切換後native非黑0.960836、Texture中央33,048點非黑0.903413／21,612色；截圖直接檢視確認bear影片可見。初版共用截圖檔名，已把本輪切換畫面複製保存為 twitch-guest-switch-surface-fixture.png，後續分支使用獨立輸出路徑，不與EOF畫面混用。調整輸出路徑後，關閉WATCH_SWITCH同範圍EOF回歸：33.8秒建置／11秒測試exit0，opens2／requests3／generation+1、position600ms、native非黑0.950980／Flutter非黑0.878419／22,118色；重新保存EOF截圖。切換路徑改輸出檔名後未重跑，該分支編譯由回歸建置確認，行為證據仍引用第一輪。

唯一analyze整合入口6.8秒無error／warning、6info：5既有（19前綴／28import／2159括號／2958與2987collection）及新gate收尾2340括號info，留下一輪且未重跑。正式程式未改，只補測試／安全截圖／紀錄。這是同頻道不同來源及實際Navigator切頁、晚到媒體資料的短片測試，非跨帳號／真實直播長播／原生open內部重疊或歷史黑畫面結案；完整目標持續。

### Windows 訪客串流故障自動恢復後的實際畫面

WATCH_EOF 加入 WATCH_SURFACE 分支，把正式兩層proxy、原觀看頁8秒poll、原生Player及真正VideoController／Texture接在同一程序。新增session替身只計數open，畫面session由正式Host.acquire／ensureReady建立，low latency profile亦轉呼正式session；Player僅aid=no、不設vo=null。mock guest auth／discovery／chat與本機bear fMP4素材隔離原帳號，未進app.main或呼叫Twitch遠端。

第一預取送10-byte殘片斷線，第二GET前綴變更，被正式proxy拒絕並由router傳遞EOF。確認原生completed=true後不手動loadWatch／reopen；原頁poll同直播ID自動重載一次，opens2／requests3／generationDelta1、completed=false、position567ms。這時暫停並取原生frame及Flutter画面；native非黑0.952065，Texture中央60%寬高每2px取樣33,048點、非黑0.881385／21,569色，比例與色數門檻皆通過。

Windows建置34.0秒、測試11秒exit0；保存 twitch-guest-eof-surface-fixture.png 並直接檢視確認故障後影片可見。分類保留unclassified_failure1未細分，不宣稱原生完全無錯；有限素材且停用音訊，不替代長播／真實Twitch授權或恢復中換源。與上輪本機直接檔案畫面不同，本輪確實串起故障→EOF→正式自動恢復→影片像素输出，仍非歷史所有黑畫面結案。

成功測試後只補新增像素loop的if括號；唯一analyze整合入口6.9秒無error／warning、5既有info（19前綴／28import／2098括號／2825與2854collection），未重跑。僅改整合fixture、截圖與紀錄，不改正式播放器／協議／憑證。恢復中換源與完整矩陣仍待驗證，目標持續。

### Windows 訪客觀看頁的實際影片畫面輸出

新增 GUEST_SURFACE 隔離整合分支，未執行 app.main 或讀取原帳號；mock guest discovery／chat／storage 與既有本機 Chromium bear fMP4 素材接正式 TwitchWatchPage。播放器使用 Player.create 僅 aid=no，不再設 vo=null；經正式 Host.acquire／session.ensureReady 建立原設定的 VideoController，正式影片 surface 與 Flutter Texture 實際掛載。只有清單解析由替身返回本機檔案，不連 Twitch 播放授權或媒體服務，不當成公開串流／廣告／代理流程通過。

第一次 Windows 建置28.5秒exit1：測試依網路文件傳入 screenshot(format: 字串)，與專案已安裝的 ScreenshotFormat 型別不符；改呼叫預設 screenshot()，未修改播放器正式程式。第二次建置34.1秒、測試約2秒exit0。guest=true、loadingAuth=false、未切離線占位；解碼位置567ms後暫停取得同步影像。原生影片frame非黑像素比例0.952065；Flutter RepaintBoundary完整畫面內，Texture中央60%寬高每2px取樣33,048點，非黑比例0.881385、21,569種RGB顏色，通過比例>0.1及顏色>32。非黑定義為任一RGB通道>16。

產出 twitch-guest-surface-fixture.png，直接檢視確認正式播放器中央可見bear影片，不是只看播放時鐘；截圖只有本機公開素材及mock頁面，不含真實帳號或聊天。原生去敏分類保留 unclassified_failure=1，未取得該分類的細分原因，不能宣稱原生完全無錯。此單次短片首幀證據不替代長播、來源切換、proxy EOF恢復或歷史黑畫面結案；音訊停用且聊天為mock，也不宣稱完整訪客功能完成。

唯一analyze整合入口6.7秒無error／warning、5項既有info：watchFixture前綴19行、重複import28行、2004行括號、2727／2756行collection constructor。依規則未重跑或順手清理。僅修改整合fixture、新增安全截圖及紀錄，正式程式／使用者憑證未改；完整目標持續。

### 訪客 VOD 與剪輯載入失敗及離頁收尾

正式 TwitchWatchPage 新增8項隔離案例：VOD／clip × 暫時載入失敗／播放授權拒絕 × 留在頁面／等待中卸載。storage gate 完成前媒體解析請求0次；完成後 guest 仍進對應解析方法1次，不自動開聯合登入頁，不建立 native Player，也不走直播 low latency profile。留頁失敗後 loadingAuth／loadingWatch 與四類 bootstrapping 皆解除，沒有改為直播離線占位；再等20秒不自動重試直播，以正式公開 loadWatch 再載入則只新增對應媒體解析1次，storage仍只讀1次。

等待中卸載後才放行媒體解析失敗，無晚到框架例外；所有案例卸載再等20秒沒有新增mock HTTP或媒體請求。HTTP回應僅fake公開channel資料，逐次確認無Authorization，媒體解析替身完全不連Twitch。這是頁面錯誤與取消流程，不是訪客播放授權成功、可解碼素材或實際影像輸出；重試使用公開方法，不冒充UI重試按鈕。

初版fixture因override欄位推斷為基底型別而編譯失敗，改成明確_RecordedPlayback替身型別後，8案實際斷言通過但結尾debug平台override未在框架invariant前還原，造成8案測試收尾失敗；補當輪結尾還原後取得最終結果。injection20＋cached login11＋auth startup10＋chat lifecycle4共45項約4秒全通過、exit0。唯一analyze只檢查修改fixture，6.6秒No issues found，亦補同一storage fixture先前缺括號的info。正式程式未改；未啟真實App／IRC／native Player、未讀帳號憑證。實際訪客解碼、完整登入入口與間歇黑畫面仍待驗證，完整目標持續。

### 已登入身分的驗證失敗不誤報訪客

新增聯合登入頁隔離測試，以假的有效主帳號先建立 authenticated 共用快照；web／drops 無 token，所有 storage 方法為替身、HTTP interceptor 拒絕外部請求。初始 storage 失敗、登入按鈕後再次 storage 失敗，以及初始／再次驗證失敗均檢查既有身分保留。修正前7項中，驗證失敗案找不到無法確認登入狀態，其他6項通過；正式 _readStatus 原本 catch 所有主帳號驗證例外並設 mainReady=false，把暫時故障誤報尚未登入。

正式頁面移除該吞錯分支，讓暫時驗證例外交給既有 _loadStatus／_login 的錯誤狀態處理；不修改共用 session、OAuth／token 儲存或 UI 排版。最終11項新增測試涵蓋 storage／一般驗證例外／503、按登入後兩種讀取失敗，以及初始與登入中等待後卸載的晚到成功／失敗。暫時失敗仍 authenticated、viewerId42、identityRevision0、token不變；尚未進 OAuth 頁，loading解除／按鈕恢復。真正401／403沿用共用session回傳guest，快照清空但不刪token，確認授權拒絕不被混成暫時錯誤。

新增11＋injection12＋auth startup10＋chat lifecycle4共37項約8秒全通過、exit0；唯一 analyze 僅正式登入頁與新測試，3.8秒 No issues found。文件只補本輪證據，不把其他檔既有info視為已清理。未開真實App、未讀帳號storage、未執行授權或登入／登出寫入；未驗證完整OAuth成功、所有入口或真實網路故障，也不代表間歇黑畫面已修。完整目標持續。

### 儲存登入讀取失敗的公開頁面與登入狀態修復

完整guest觀看頁fixture新增首次讀取失敗後可再讀，以及持續讀取失敗兩案；不讀真實storage。兩案初始錯誤被正式loadAuth處理，loadingAuth／loadingWatch與各bootstrapping解除，公開離線占位及guest chat讀取正常，chat唯讀／不可發言，沒有自動進登入頁。首次fixture曾錯把正常錯誤Snack也要求不存在，調整只有storageFailure允許顯示讀取錯誤後，暫時失敗流程通過，不改正式Snack行為。

持續失敗時，使用者實際tap聊天登入按鈕，聯合登入頁_readStatus讀取失敗卻把_statusText設為尚未登入並要求重新登入。新單案修正前失敗（預期沒有尚未登入，實際找到1）。正式頁面只改失敗狀態為無法確認登入狀態、提示請稍後再試，不再把未取得狀態誤報guest或要求重授權；未改排版、OAuth／token儲存、登入／登出協議或_ready旗標。取消返回觀看頁仍guest／可讀chat／loading解除，chat連線1次；持續失敗auth reads3／web reads1／drops reads0，符合各流程失敗即中斷輔助讀取的實際順序。

injection12＋auth startup10＋chat lifecycle4共26項约9.5秒exit0；唯一analyze6.7秒無error／warning，fixture102:7 curly_braces格式info留下一輪，未重跑。只改登入狀態失敗分支、mock測試與紀錄，不啟App／native Player／OAuth視窗。未驗證真實storage故障或已登入記憶體身分下的讀取失敗，公開播放、其他入口與完整功能仍待補，目標持續。

### 迷你恢復晚到不套用舊位置的可控回歸

確認先前中斷留下的四個mini恢復案例首次仍編譯失敗：fixture錯用const PlayerState；修正為非const後才取得結果。可控fake Player.open真正保持pending，再切換mini entry／關閉mini／換attached session／保持不變，對舊open晚到成功與失敗各測一次，共8項。前三種成功晚到不seek舊30秒，Host新來源URI保留；未切換成功則seek30秒。四種晚到失敗均不seek，throwsA(same(originalError))證明原錯誤物件保留，已完成的新來源身分不被蓋回。

新8項加Host原7項與session state18項共33項约5秒exit0；唯一analyze4.7秒No issues found。之後只補原錯誤identity斷言、33項再通過，未重跑analyze。只修fixture及補測試／紀錄，正式程式未改、未啟App或任何native Player／IRC／storage。此為正式mini recovery與Host在Player介面邊界的可控重疊，不冒充真實libmpv內部併發已验证；完整目標持續。

### zackrawrr 完整 DVR 三次實際拖曳回歸

Windows FULL_DVR／DVR_DRAG／DVR_DRAG_REPEAT完整開啟，CHANNEL_INDEX=2仍實際選到zackrawrr。編譯34.2秒、測試2分17秒exit0，保留登入、不執行帳號寫入；直播與唯讀chat、DVR archive warmed、暫停後45秒續播增45,516 ms通過。媒體段mpegts／HTTP200、無init map，非fMP4樣本。

Flutter實際Slider拖30%→70%→20%，preview目標分別5,589,610／13,051,847／3,731,766 ms；每次新來源與解析目標接近、開始解碼通過。起算前捕捉1／1／2次native位置重設，等待連續前進穩定後觀察10秒；native增10,133／10,117／10,117 ms，display增10,133／10,110／10,112 ms，增量差0／7／5 ms，秒級取樣playing=true／buffering=false／mediaChanged=false。返回live確實解碼，另10秒增10,017 ms；同程序正常結束。

本輪補齊上輪漏開DRAG入口而未執行的手勢分支，不追溯改成上輪已通過。沒有重跑120秒長測或UI暫停跳轉，兩者仍引用上輪證據。native lifecycle取樣unknown，非前景／背景對照；drag debug build P95=5,506 us、5慢幀，raster P95=6,070 us／無逾33.333ms幀，不能宣稱無短卡頓。只更新紀錄，正式／測試程式未改、未跑analyze；其他格式、真實斷線與完整訪客功能仍待補，完整目標持續。

### 代理與恢復修正後 zackrawrr 完整 DVR 長測

Windows FULL_DVR／PAUSED_DVR_SEEK／EXTENDED_DVR，DVR_CHANNEL_INDEX=2實際選到zackrawrr；同一App程序保留既有登入，只用Flutter合成操作與唯讀功能。編譯36.1秒、測試4分21秒exit0，公開搜尋／直播頁／唯讀chat／15秒直播前進、完整DVR archive warmed皆通過。實際DVR媒體段標記mpegts、HTTP200、hasMap=false／compressed=false；不是fMP4格式樣本。

DVR暫停後恢復45秒增45,566 ms。UI暫停→左鍵跳轉→等待後仍paused→UI恢復及10秒續播通過；恢復前snapshot／resolved均9,138,405 ms。1/3與2/3以正式頁面公開跳轉方法各新來源解碼且持續10秒通過，非Slider拖曳。120秒觀察增121,484 ms，十二個10秒取樣均playing=true／buffering=false；返回直播解碼並再10秒增10,000 ms。程序正常結束；首次native lifecycle有unknown／inactive，後段resumed，非持續前景或前背景A/B證據。

本輪命令雖有DVR_DRAG_REPEAT，但沒有DVR_DRAG入口旗標，拖曳分支未執行，已在測試途中回報，不列拖曳通過。extended-dvr debug build P95=5,048 us、12幀逾33.333ms，raster P95=2,837 us／無逾門檻幀；不能把取樣無緩衝当成沒有短停頓或一般卡頓已修。只更新紀錄，正式／測試程式未改、未跑analyze。此為代理／EOF恢復修正後另一具名TS完整DVR與返回live正常流程回歸，不涵蓋真實故障注入、所有格式／廣告或歷史間歇黑畫面，完整目標持續。

### 恢復回應等待中進入新觀看頁不重開舊頁

完整guest觀看頁fixture在same-ID completed恢復後，再設原Player completed=true，讓正式8秒poll的discovery回應卡在Dio gate。用原Navigator.push建立同頻道的另一個正式TwitchWatchPage及獨立mock依賴，等新頁初始化一次後放行旧poll。旧State仍mounted、其Player仍completed=true；放行後旧watch generation／profile requests皆不增加，新頁generation及初始化1次亦保留。Navigator.pop後回到同一旧State，登入取消返回及最後卸載20秒timer清理既有斷言仍通過。

聯合injection10＋auth startup10＋chat lifecycle4共24項约8秒exit0；沒有修改正式程式，驗證前輪post-await top-owner防護，而不是因旧頁已dispose或Player不再completed而略過。唯一analyze6.4秒無error／warning、2項新測試context跨async info，改保留NavigatorState參考後再跑24項通過，依規則不重跑analyze。此為真實Navigator／正式頁面搭配fake Player與傳輸，非原生解碼競態或跨頻道帳號切換。長播／完整DVR與更多訪客功能仍待補，完整目標持續。

### 正式觀看頁自動重試與原生起播同流程通過

WATCH_EOF分支把正式TwitchWatchPage、原8秒recovery timer、正常固定網址router、內層proxy及原生Player接在同一Windows程序。重用既有隔離guest服務／chat，所有discovery請求由interceptor回應且檢查無Authorization，不進app.main或原帳號；只有播放清單解析由fixture返回本機URI，session轉呼正式Host.restoreSharedMedia。Player仍aid=no／vid=auto／vo=null，沒有建立video surface，這是原生影像播放時鐘與正式觀看頁恢復證據，不是可見影片畫面／真實Twitch授權測試。

init等觀看頁開啟一次且原生client掛載後才放行；預取10-byte殘片斷線，重抓前綴變更，正式兩層代理收尾。觀察原生completed=true後不手動呼叫loadWatch／reopen，由正式8秒poll自動重載，同一直播ID保持fixture-live-stream，watch generation增加1，session opens=2、segment requests=3；completed=false、position633 ms且>500 ms斷言通過。Windows初版29.3秒編譯失敗（替身loadLivePlaylist漏可選參數）；補齊介面及避免Player重複dispose後，編譯34.1秒／測試10秒exit0。頁面卸載與原生Host清理正常完成，既有隔離injection／auth／chat24項亦通過。

新增可參數化fixture builder不改正式依賴或storage／token；唯一analyze6.8秒無error／warning、5項info（3既有、2新：watchFixture prefix與1872括號格式），未重跑。只改測試與紀錄，正式程式未改。此單一短素材已串起受控故障→EOF→原頁自動重載→native position前進，不替代長時間續播、所有頻道／格式或歷史間歇黑畫面結案；恢復等待時切頁的專門競態仍待補，完整目標持續。

### 原生拒絕重抓的結束狀態與同網址重開驗證

PARTIAL_DECODE／PARTIAL_PROXY新增PARTIAL_REJECT受控分支，只使用本機素材、正式低延遲proxy與獨立原生Player（aid=no／vid=auto／vo=null）。init等原生client已掛載才放行，第一預取送10-byte殘片並斷線，第二GET改變前綴，正式校驗拒絕後關閉引擎。故障後5秒實測completed=true／position0／playing=false／buffering=false，proxyRunning=false，open無例外、固定失敗分類空；兩次分段請求斷言通過，確認此原生EOF確實提供上輪觀看頁所用completed信號。

同一Player在測試內直接重新open相同proxy網址，第三次GET完整分段，10秒後completed=false／position2,268 ms／playing=true／buffering=true，requests=3及position>500 ms斷言通過。Windows編譯33.9秒、測試15秒exit0。有限素材播完後長連線沒有後續段，所以後期buffering=true不當成連續長播通過。這輪不使用router或正式觀看頁；上輪HTTP已驗router傳遞EOF，但不能把分開測試當成單一完整App自動恢復證據。

唯一整合入口analyze6.8秒無error／warning、3項既有info，前輪新增1763格式info已補括號。僅改整合fixture與紀錄，正式程式未改、不進app.main或讀取帳號。下一步仍需把觀看頁8秒poll重載與原生續播連成同一受控流程，及補恢復等待時切頁的獨立競態；完整矩陣未完成，目標持續。

### 同一直播身分的播放結束恢復修復

完整掛載guest觀看頁的已開台fixture補播放器狀態：paused（completed=false／playing=false）推進正式8秒timer不重載；preferVodReplayChat=true的錄播completed也不重載。回live且completed=true、直播ID與startedAt保持不變再推進8秒，修正前預期profile初始化由1增2，實際仍1；已重現觀看頁只依直播身分變更重載而漏掉播放結束。

正式recovery poll保留原身分變更流程，增加currentPlaybackKind=live且player.state.completed=true時同一身分也loadWatch；暫停不以playing=false當作失敗，錄播結尾不拉回live。discovery等待前擷取watchLoadGeneration，返回後重新核對mounted、版本及top route owner，避免晚到輪詢重開其他路由／新載入。修正後same-ID completed一次初始化重試、paused／recorded各零次；原晚到offline／live與正常8秒poll、guest登入取消／卸載、chat唯讀回歸保留，injection10＋auth startup10＋chat lifecycle4聯合24項约8秒exit0；唯一analyze6.4秒No issues found。

播放器是只提供狀態的fake，profile仍故意失敗，不建立原生Player，不冒充native EOF已映射completed或重試後解碼成功。切頁後的post-await route guard本輪只有既有載入版本案例間接涵蓋，需補專門路由變更競態。只改正式恢復輪詢、fixture與紀錄；不改storage／token／IRC／UI。下一步用受控原生EOF確認completed事件與重載後續播，歷史黑畫面與完整矩陣仍未結案，目標持續。

### 固定網址代理不再隱藏無換源的連線結束

舊讀者故障注入擴到正式TwitchStableHlsProxyRouter：直接內層的前綴變更／過短兩案通過EOF與乾淨重連，但相同流程經正常router.start(upstreamPlaylistUrl)兩案皆等待EOF超過2秒。原因是_proxyStreamLoop在沒有switch時，內層結束後等待80ms再接同一路徑，外層HTTP不結束；新engine初始化可能被接到舊殘片後，內層收尾不足以讓native讀者知道播放流已失效。

正式router改在來源generation與target均未改變時傳遞EOF並關閉外層response，不再無限重接；明確switch仍使用原連線接續新inner。新增控制回歸，原HTTP reader先讀a來源完整18 bytes，router.switchUpstream到b後同一reader讀到b完整18 bytes，未被錯關。五項router／direct收尾与換源測試，加partial14／init HTTP3／replay2共24項约8秒exit0；唯一analyze2.8秒No issues found。

本輪只修改固定網址代理、隔離HTTP測試與紀錄，未啟App／原生Player／帳號；確認EOF到達最外層讀者，不當成原生播放器必然自動重連。觀看頁目前8秒恢復poll依直播身分變更才重載，來源相同時EOF後的App恢復仍需正式頁面事件測試；不能以此輪通過宣稱歷史黑畫面或完整功能已完成。目標持續。

### 不可續接殘片的舊讀者收尾與乾淨重連修復

新增正式proxy本機HTTP讀者兩案：先確認舊client已掛載，再放行init，預取送10-byte殘片後斷線；重抓內容變更／比前綴短時，舊讀者精確收到init＋10-byte前綴，但後續moveNext兩案皆2秒逾時，證明writer雖停止，byte bus與HTTP連線沒有結束，讀者仍等缺失資料。此為可重現的收尾缺陷，不是以測試等待過久推論原生卡頓。

正式writer遇無法安全續接、且當前segment已有輸出bytes的錯誤時stop整個engine，清掉殘片並關閉舊bus／HTTP讀者；下一次GET原路徑建立新engine，重新提供init與完整段。初版無條件stop破壞既有14次init-map HTTP失敗後重試，聯合20通過／1失敗；限定output.bufferedBytes>0後，未輸出媒體bytes的失敗仍保留原writer重試，原init回歸恢復。

最終兩案舊HTTP讀者正常EOF、新連線精確init＋完整段，segment請求依序partial／rejected／fresh共3，無舊殘片混入；拒絕邊界測試同步改驗engine stopped／buffered0。聯合reconnect2＋partial14＋init HTTP3＋replay2共21項约8秒exit0。唯一analyze2.8秒無error／warning、1項新測試72:15格式info，後續已補括號；最終formal條件修正與fixture以測試驗證未再跑analyze。沒有原生Player／App／帳號操作，本輪證明HTTP收尾與重新連線，不冒充App自動重連或真實影片續播。完整目標持續。

### 部分預取續接邊界與拒絕分支回歸

本機正式proxy故障注入擴為14項：MP4區塊／TS樣式位元組各測前綴0／1／7／10／15 bytes後斷線，完整重抓均輸出init＋一份原分段，請求數2；另各測10-byte前綴的重抓內容變更及重抓只有9 bytes。拒絕分支hasWriter=false、lastWrittenSequence=-1、outputDuration=0、bufferedBytes仍10，證明未追加變更／過短資料，也未把失敗分段標成成功。故障注入分兩次socket寫入並flush，重抓以3-byte前段與剩餘段分開flush；TCP可能合併，未直接觀測核心接收chunk數，不宣稱每次都必然跨接收chunk。

初版4個拒絕案例因誤等running=false各8秒逾時；running代表整個engine，writer停止時engine仍可running。改用hasWriter=false後，14項加既有init HTTP／replay5項共19項約8秒exit0；唯一analyze2.7秒No issues found。只修改測試與紀錄，正式程式未改，沒有啟動App或原生Player；樣式位元組不是可解碼TS／MP4驗證。後續需要驗證拒絕後重新啟動／重連是否會把舊殘片留給既有讀者，不以此輪防護通過宣稱所有錯誤恢復已完成。完整目標持續。

### 正式代理部分預取重試拼接修復

PARTIAL_DECODE＋PARTIAL_PROXY把同一份可解碼fMP4拆成init與分段，正式proxy預取、writer、byte bus及HTTP長連線接原生Player；只隔離音訊與畫面輸出，未進app.main或帳號流程。修正前Windows編譯33.5秒／測試20秒exit0（診斷斷言）：完整預取1請求、replay763,158 bytes、position2,268 ms；故意截斷前10 bytes再重抓共2請求，replay763,168 bytes、position0／playing=true／buffering=true。兩組固定原生失敗分類空，證明正式拼接缺陷不必有原生error才會令位置停在零。

正式_pipeSegmentToOutputBuffer保留本次預取送出chunk的參考，fallback GET逐byte核對並略過已送出前綴，只轉送剩餘資料，避免重複MP4 box或TS packet前綴；若前綴不符或重抓資料比前綴短則拒絕拼接。正常成功預取仍立即轉送，不等待完整段下載，未改hash／OAuth／IRC／點數／UI／原生open順序。參考僅保留到本段完成；前綴改變／過短與跨chunk等防護分支尚需下一輪補測，不稱全輸入已驗證。

原合成位元組診斷改成正確輸出回歸，聯合init HTTP／replay6項exit0。Windows同一故障注入修正後編譯35.7秒／測試20秒exit0：完整與截斷重抓兩組replay均763,158 bytes、position均2,268 ms，請求各1／2，錯誤類型none、固定原生分類空。此為明確原因的修復前後對照，不以一次一般直播成功宣稱修復。有限素材在10秒取樣時兩組仍playing=true／buffering=true（長連線沒有後续分段），因此只證實起播0被修復，不是長時間連續播放、真實畫面或歷史90秒黑畫面全部結案。

唯一analyze7.4秒無error／warning、4項info：3項既有，新增整合fixture1763:17 curly_braces格式info保留下一輪；未重跑。僅修改正式proxy、故障注入測試與紀錄。歷史失敗當下未取得部分預取錯誤，不能追溯斷言都是此原因；更多格式／失敗分支與完整矩陣仍待補，目標持續。

### 部分分段殘片造成原生影像播放停在零

PARTIAL_DECODE改用await Player.create後，第一輪Windows編譯35.1秒／測試4秒exit1：完整HTTP素材position=0，未分類原生失敗90次。拆成本機file、正確video/mp4 MIME、代理video/mp2t MIME與damaged四組後，編譯33.9秒／測試16秒exit1；前三者皆0，失敗token主要audio=89，damaged亦0。因此不能把初始基線失敗歸因代理MIME或殘片。

獨立測試Player改為aid=no／vid=auto／vo=null，隔離音訊與畫面輸出，只觀察原生影像播放時鐘；不動正式Player或使用者設定。第三輪編譯35.0秒／測試16秒exit0，file／mp4／intact三組position均2,769 ms，damaged=0，四組open無例外、去敏失敗分類空。這次有完整資料能播放的基線，證實同一份fMP4插入10-byte殘片即可讓此原生影像播放路徑停在0；HTTP MIME差異不足以解釋這個對照。測試只斷言intact>500 ms，damaged=0為實測輸出，不冒充已加反例斷言。

四組有限長度HTTP／檔案都在取樣時playing=false、buffering=false；此為不呈現畫面的原生對照，不等於原直播90秒buffering或真實畫面驗證。先前正式proxy位元組重現已確認殘片來源，但這輪損壞HTTP由測試構造，尚需正式proxy＋可解碼素材＋持續連線驗證，或真實黑畫面當下的部分預取失敗關聯，才可認定歷史黑畫面根因。正式程式未改；唯一analyze7.2秒無error／warning、3項既有info，在後續fixture擴充分組與純影像設定前執行，最終以Windows編譯驗證未重跑。完整目標持續。

### 部分分段損壞的原生解碼對照尚未執行

既有Windows整合測試新增PARTIAL_DECODE獨立分支，不進app.main或存取帳號，以本機HTTP提供同一份完整fMP4及在第一個moof前插入10-byte殘片的版本；兩者均使用正式代理相同的video/mp2t MIME，準備比較播放器進度與固定去敏失敗分類。尚未驗證解碼結果：Windows編譯30.1秒exit1，新增測試誤用Player()，此專案API為await Player.create。唯一analyze6.9秒亦回報1723:26 new_with_undefined_constructor_default error及3項既有info。依每輪檢查限制保留錯誤，不反覆修跑；正式程式未改。下一輪先修測試建構方式，再取得完整資料成功基線與損壞資料對照，不能把這輪視為黑畫面重現或根因證實。

素材來自[Chromium測試檔 bear-1280x720-av_frag.mp4](https://github.com/chromium/chromium/blob/main/media/test/data/bear-1280x720-av_frag.mp4)，本機docs/twitch-decoder-fixture.mp4為764,465 bytes，SHA256為AFFC4CE6C872F9D4160A92A7B959523B3CAC2D171E89177E4CD211E55F756175。此為公开測試素材，與使用者直播內容／憑證無關；格式說明見[Chromium測試資料](https://chromium.googlesource.com/chromium/src/+/refs/tags/103.0.5058.0/media/test/data)。原生實測結果與與既有90秒buffering的因果仍待確認，完整目標持續。

### 部分預取失敗後重抓造成分段資料錯位

新增本機HTTP故障注入，使用正式proxy／writer／prefetch／byte bus與HTTP讀者，不啟動App或原生Player。上游宣告16-byte moof分段，第一個預取請求只傳10 bytes後斷線；init請求等斷線完成才放行，確保writer使用已部分失敗的預取。正式_pipeSegmentToOutputBuffer把已送出的前10 bytes保留，catch後另GET完整16 bytes直接接續，讀者實際收到8-byte init＋10-byte前綴＋16-byte完整分段，共34 bytes。moof宣告長度16，下一區塊邊界落在重抓分段的header內，已確認可重現的結構損壞，不是正常的完整分段重試。

故障注入初版因HttpResponse送出headers後detachSocket失敗，改成先detach再用socket送部分body後destroy；只有修正後才驗證到正式fallback。單案及與init HTTP／replay聯合6項exit0；診斷案例通過表示成功重現壞輸出，不表示修好。唯一analyze3.1秒No issues found。僅新增測試與紀錄，正式程式未改；fixture區塊不是可解碼影片，因此尚不能將此路徑認定為既有90秒黑畫面根因，下一步需解碼端驗證或黑畫面當下對應的部分預取失敗證據。未重跑相同Windows流程，完整目標持續。

### VOD 原生恢復重疊嚴格驗證

Windows MEDIA_MINI／MINI_RECOVERY_SWITCH／OBSERVE_RESTORE_OPEN／REQUIRE_NATIVE_OPEN_OVERLAP，編譯34.0秒、測試31秒exit1。VOD解碼、mini前進、首頁另一直播卡導頁、新來源解碼／owner／十秒前進及來源保留通過，但native atNewOwner=false，嚴格斷言於整合測試934行失敗。atClick／atMount=true、started=completed=1，恢復沒有錯誤；這是未撞到接手重疊條件，不是正式播放失敗，也不能記作重疊通過。

新来源仍為TS，HTTP200／Range206，無特定廣告標記、init map或原生失敗分類；未重現黑畫面。相近自然恢復流程再次未達時點，後續應補可控原生開啟重疊的隔離測試，不只反覆重跑自然時序。未改正式／測試程式、未跑analyze，保留帳號且程序正常結束；完整目標持續。

### 剪輯恢復切換直播與廣告診斷續測

Windows真實唯讀MEDIA_MINI／MINI_CLIP_FIRST／MINI_RECOVERY_SWITCH／OBSERVE_RESTORE_OPEN，編譯34.0秒、測試27秒exit0。剪輯卡導頁與解碼、返回首頁mini解碼／進度、新首頁直播卡導頁、新來源解碼與owner接手、十秒前進與來源保留通過。舊restore native atClick／atMount=true、atNewOwner=false，started=completed=1；pending亦同，errorType=none。這是恢復中掛載及來源替換證據，不是新owner接手時原生open內部重疊。

來源HTTP200／HLS，variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY／SCTE35=false；Range206／4096bytes，TS sync=true、MP4 hint=false，無init map／BYTERANGE／AES128／SAMPLE-AES。原生固定失敗分類beforeMount／afterMount均空。本輪沒有重現黑畫面，不能排除未標記廣告或抹除既有fMP4／90秒buffering失敗。換源debug build P95=13,283 us、10幀逾33.333ms，raster P95=5,734 us、無逾門檻幀，不宣稱效能修好。

僅更新紀錄，正式／測試程式未改、未跑analyze；同一程序正常結束，保留既有登入。間歇黑畫面、native接手時重疊、訪客實際解碼及完整功能矩陣仍待補，目標持續。

### 觀看頁載入防護後剪輯恢復換直播回歸

Windows真實唯讀MEDIA_MINI／MINI_CLIP_FIRST／MINI_RECOVERY_SWITCH／OBSERVE_RESTORE_OPEN，編譯34.3秒、測試28秒exit0。剪輯卡接線／解碼、返回首頁mini解碼與位置前進、實際首頁直播card導頁、新source解碼與owner接手、十秒持續前進及來源保留通過。舊restore native atClick=true、atMount=true、atNewOwner=false，started=completed=1；pending也於Click／Mount為true、新Owner為false，errorType=none。這輪覆蓋頁面掛載時仍在恢復，但新owner接手時恢復已完成，不記作native內部重疊通過。

新來源清單HTTP200／HLS、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY／SCTE35=false；媒體Range206／4096bytes、TS sync=true／MP4 hint=false、無init map／BYTERANGE／AES128／SAMPLE-AES。原生固定失敗分類beforeMount／afterMount均空。DATERANGE不單獨算廣告，此TS成功樣本不排除未標記廣告，也不抹除先前fMP4／90秒黑畫面失敗。

本輪只更新紀錄，正式／測試程式未改、未跑analyze，程序正常結束。換源debug build P95=12,439 us／13慢幀、raster=5,778 us／無慢幀，不宣稱效能修好。這是前兩輪觀看頁載入／晚到防護後的真實來源替換回歸；訪客實際解碼、native接手時重疊與格式切換／間歇黑畫面仍待補，完整目標持續。

### 恢復輪詢晚到回應覆蓋新直播身分修復

完整掛載訪客案例在正式8秒recovery poll讀取stream-2時，用Dio gate延後已擷取的回應；同頻道先正式loadWatch取得stream-3，確認新身分後才放行舊回應。修正前單案失敗：預期fixture-live-stream-3，實際被覆蓋為fixture-live-stream-2。這次未重現額外播放啟動，但已證明晚到輪詢破壞新載入身分，不能只檢查mounted與channelLogin。

正式refreshLiveTimelineStartedAt擷取watchLoadGeneration，await discovery後若載入版本已變就回null，不提交舊stream／startedAt／DVR與timeline狀態。修正後延遲舊回應不改新身分、watch generation或播放初始化次數；前段正常offline→live、相同stream不重載、stream改變才重載等回歸仍通過。injection9＋startup10＋chat4聯合23項約9秒exit0；fixture為匿名mock傳輸與播放初始化失敗，不冒充原生恢復內部重疊或實際影片解碼。

Windows真實唯讀FOLLOWING_ENTRY編譯34.0秒、測試23秒exit0，預設追隨第一張卡／頻道一致／chat連線／解碼與15秒前進通過，程序正常結束。唯一watch page＋injection analyze6.3秒exit1，無error／warning，既有565:11 curly_braces_in_flow_control_structures info，未修lint或重跑。debug live build P95=15,682 us／15慢幀，不宣稱效能修好。未改OAuth儲存、IRC或播放器底層；訪客實際解碼、native恢復重疊與間歇黑畫面仍待补，完整目標持續。

### 初始化完成後直播恢復輪詢仍可重新載入

新增完整訪客頁面隔離案例，初始HTTP200／離線，完成storage與startup後不直接呼叫loadWatch，改變mock清單為開台並推進原8秒recovery timer。第一輪發現fixture-live-stream，watch generation增加1、fake播放初始化嘗試1次；相同stream再推進8秒，generation與初始化次數都不增加。再只更換stream id為fixture-live-stream-2、保留startedAt，下一輪generation再增加1、初始化共2次，證明上輪guard沒有永久阻擋初始化完成後的恢復。

三輪後storage仍只載入1次、各loading與四類bootstrapping解除，原chat runtime保留且連線共1次，guest唯讀／不可發言，沒有聊天室錯誤提示；登入取消返回與卸載20秒清理仍通過。此為正式timer／page pipeline加mock GQL與fake播放失敗，不是實際影片恢復解碼、真實網路恢復或native open重疊。

injection9＋startup10＋chat4聯合23項通過，約9秒exit0；唯一analyze同時檢查正式twitch_live_watch_state.dart及injection測試，6.5秒No issues found、exit0。只擴充測試與紀錄，正式程式本輪未改、未啟動真實App。訪客實際解碼、登入授權成功、native恢復內部重疊與間歇黑畫面仍待補，完整目標持續。

### 登入初始化期間直播恢復輪詢重複啟動修復

新增正式訪客觀看頁已開台fixture：匿名GQL回HTTP200、stream id=fixture-live-stream、createdAt=2026-10-12T00:00:00Z。首次聯合測試重現profile初始化2次；再補storage gate完成前必須0次的斷言，單案明確失敗（預期0、實際1）。背景recovery初次輪詢發現新stream時直接loadWatch，搶在post-frame loadAuth完成前啟動；之後正常startup再啟動一次。不是fixture斷言放寬或未重現的推測。

正式twitch_live_watch_state.dart在恢復輪詢入口略過loadingAuth、watchLoadGeneration=0或loadingWatch，首輪登入解析與播放由原startup負責；不改OAuth儲存、IRC或播放器底層。隔離測試增加初始profile=0；尚未完成storage的兩案請求=0，不再將其當作已發HTTP503證據。完成storage的200離線、503失敗→200重載、200已開台但fake播放器初始化失敗三分支仍完整走正式頁面；新開台案保留stream id／startedAt、只初始化1次，loading解除、訪客chat唯讀、登入取消返回及卸載清理通過。此案例是開台狀態與播放失敗收尾，不是影片解碼成功。

修正後injection8＋startup10＋chat4聯合22項通過，約8秒exit0。Windows真實唯讀FOLLOWING_ENTRY編譯34.2秒、測試24秒exit0：儲存登入解析、預設追隨、首頁第一張直播卡與頻道一致、chat連線、解碼及15秒前進通過，程序正常結束。debug live build P95=14,446 us／14慢幀，仍不宣稱整體效能或間歇黑畫面修好。

本輪唯一injection analyze6.3秒No issues found、exit0，在新增正式guard與前置斷言前執行；最後修改以22項測試和Windows編譯／實機回歸驗證，未再次analyze。完整訪客實際解碼、登入授權成功、恢復中native開啟重疊及黑畫面／廣告切換仍待補，完整目標持續。

### 訪客 HTTP 503 恢復後正式頁面重新載入

完整掛載的503啟動收尾案例，將攔截回應改為200／stream=null後呼叫正式state.loadWatch，沒有重建App或重跑storage。請求數增加、watch generation恰增1，loadingAuth／loadingWatch／loadingPlayer與四類bootstrapping解除，保持guest唯讀與離線占位，profile初始化仍只有前次失敗的1次、auth storage仍只有1次。原chat runtime保留、連線次數仍1，沒有聊天室錯誤提示或自動登入；聊天登入入口取消返回與卸載20秒清理仍通過。這是正式重載方法與mock傳輸配合，不當成重試按鈕、真實網路恢復或已開台解碼。

初版失敗為Dio攔截callback內expect與tester.pump的guard衝突，導致200被包成傳輸錯誤；改expectSync後，另暴露chat fixture缺channelLogin及預期重連2次不符正式同頻道runtime重用。補fixture記錄connect頻道，改驗同runtime、一次連線及無錯誤提示，沒有修改正式重用規則。injection7＋startup10＋chat4聯合21項最終通過，約8秒exit0。唯一injection analyze6.4秒No issues found；在最後chat fixture補齊前執行，最終修改由測試編譯與回歸驗證，沒有再analyze。

本輪只改隔離測試與紀錄，未改正式程式、未啟動真實App、未讀寫憑證或建立原生Player。恢復後回應仍離線，訪客已開台播放、OAuth成功與其他登入入口、native恢復內部重疊及間歇黑畫面仍待補，完整目標持續。

### 訪客觀看頁 HTTP 503 完整啟動收尾

隔離測試將 HTTP503 從直接 resolve 改為 Dio badResponse reject，新增 storage gate 在仍 mounted 時完成的503分支。正式 refreshLiveTimelineStartedAt 收到傳輸失敗後回傳未知狀態，原 startup pipeline 嘗試播放；fake playerSession 的 cache profile 初始化明確失敗並計數，沒有建立原生Player。此案例不是已確認開台的頻道，也不是播放授權／影片解碼成功或真實網路斷線測試。

完整掛載斷言通過：503分支播放初始化嘗試一次、200離線分支零次；loadingAuth／loadingWatch與chat／relationship／engagement／emote bootstrapping解除，落到offline placeholder，fixture guest chat連線一次且不可發言，沒有OAuth錯誤提示或自動掛登入頁。兩分支仍可實際點聊天登入入口、取消返回並保持訪客唯讀。全部傳輸無Authorization；卸載後20秒請求數不增加、無原生Player／例外／殘留timer。不是靠清除真實cookie製造訪客，沒有連IRC或執行帳號寫入。

首次fixture新增计數斷言因介面型別未提供profileRequests而編譯失敗，改為明確fixture cast後7項通過；injection7＋startup10＋chat4聯合21項通過，約8秒exit0。唯一injection檔analyze6.4秒No issues found、exit0。只改docs隔離測試與紀錄，正式程式未改、本輪未啟動真實App。仍待訪客已開台播放／解碼、傳輸恢復重試、授權成功與其他登入入口，完整目標持續。

### ow_esports 連續拖曳後暫停快捷鍵跳轉

Windows FULL_DVR／DVR_DRAG／DVR_DRAG_REPEAT／DVR_CHANNEL_INDEX=0／PAUSED_DVR_SEEK 選到 ow_esports，與前輪具名 trymacs 不同；編譯33.9秒、測試2分38秒exit0，同一程序內完成全部操作。直播／chat讀取、45秒回放增45,542 ms；30%→70%→20%實際Slider手勢解析目標誤差小於2秒，十秒native增10,109／10,106／10,128 ms，display增10,100／10,110／10,126 ms，增量差9／4／2 ms。各秒playing=true、buffering=false、來源不變，分段HTTP200／MPEGTS／hasMap=false。

第三次拖曳後實際點UI暫停，再送左方向鍵跳轉10秒，目標3,479,142 ms、解析3,479,143 ms；playing仍false，等待後原生位置差小於500 ms、控制列距目標小於2秒。再點UI播放，解碼恢復及十秒前進大於7秒斷言通過；返回直播解碼後十秒增10,012 ms。此段是快捷鍵跳轉，不冒充暫停中Slider拖曳。

本輪只保存測試證據，正式與測試程式未改，未跑analyze。debug拖曳build P95=4,998 us／2慢幀、raster=6,195 us／無慢幀。已有trymacs與ow_esports兩個具名TS來源的連續拖曳通過樣本，仍不是所有頻道、逐幀精度、fMP4／廣告切換或間歇黑畫面已修的證明。訪客完整播放與恢復中native開啟重疊仍待補，完整目標持續。

### trymacs 完整 DVR 具名長時間軸拖曳

整合測試增加 DVR_CHANNEL_INDEX，預設仍取第一個符合 growing archive 的候選；指定 index1 選取當下五台 Browse 樣本中的第二個符合者，找不到就明確失敗，不回退冒充通過。此輪公開頻道名稱 trymacs，真實登入唯讀、Flutter 合成手勢，正式程式與協議未改。舊 DVR 輪次沒有記錄頻道名稱，不能由候選順序證明此輪與舊樣本不同，跨頻道覆蓋仍須更多具名樣本。

Windows FULL_DVR／DVR_DRAG／DVR_DRAG_REPEAT／DVR_CHANNEL_INDEX=1 編譯35.7秒、測試2分27秒exit0。45秒回放增45,516 ms，三次30%→70%→20% preview目標39,054,035／91,138,192／26,042,706 ms，解析誤差小於2秒。穩定後十秒native增10,100／10,133／10,117 ms，display增10,105／10,128／10,121 ms，差5／5／4 ms；啟動重設取樣次數0／1／1。各秒playing=true、buffering=false、來源不變，分段HTTP200／MPEGTS／hasMap=false。返回直播解碼後十秒增10,000 ms，程序正常結束。

唯一整合檔analyze7.4秒exit1，無error／warning，三項既有info：19:8 unnecessary_import、2181:34與2210:26 prefer_collection_literals，未重跑。debug拖曳build P95=5,126 us／2慢幀、raster=6,023 us／無慢幀；不宣稱整體效能修好。本輪補具名長時間軸跳轉與續播，不等於逐幀時間精度、fMP4／廣告切換或既有間歇黑畫面驗證，完整目標持續。

### 完整 DVR 同程序連續往返拖曳

Windows 真實唯讀 FULL_DVR／DVR_DRAG／DVR_DRAG_REPEAT 在同一個 App 程序完成 30%→70%→20% 三次 Slider 合成手勢，不使用系統滑鼠、不逐次重開。測試增加可選重複流程，保留新來源穩定前進 gate 與十秒 >7 秒門檻，另要求控制列與原生播放的增量差小於 2 秒；正式播放器、UI、憑證與 Twitch 協議未改。

編譯 33.9 秒、測試 2 分 25 秒 exit0。拖曳前 45 秒回放增 45,529 ms。三次 preview 目標分別 5,067,927／11,836,383／3,384,909 ms，解析誤差 <2 秒；各捕捉一次啟動 clock reset，穩定後十秒 native 增 10,098／10,127／10,115 ms，display 增 10,112／10,132／10,111 ms，增量差 14／5／4 ms。每秒取樣 playing=true、buffering=false 且 URI 不變，分段 HTTP200／MPEGTS、hasMap=false。返回直播解碼後十秒增 10,007 ms，全部斷言通過，程序正常結束。

唯一整合檔 analyze 7.3 秒 exit1，無 error／warning，三項既有 info：19:8 unnecessary_import、2168:34 與 2197:26 prefer_collection_literals；未修 lint 或重跑。debug 拖曳 build P95=4,867 us／4 慢幀，raster P95=6,044 us／無慢幀，不宣稱整體卡頓修好。證據限同一 TS 來源的三次有界拖曳與返回，沒有逐幀影片時間比對，也未覆蓋其他頻道、fMP4、廣告切換及既有間歇黑畫面；完整目標持續。

### 完整 DVR 實際拖曳與新來源時鐘取樣

Windows 真實唯讀 FULL_DVR／DVR_DRAG 使用 Flutter 手勢拖曳 Slider 至約 30%，不是直接呼叫 seek。先前兩輪在目標解析誤差小於 2 秒、playing 且非 buffering 後，十秒進度斷言失敗；其中一輪 native 起點 7,429 ms、終點 9,840 ms，差值僅 2,411 ms。橋接器的 liveDvrBridgeTimelinePosition 是固定 seek 起點，不能拿它是否更新判定控制列停滯。

逐秒診斷輪編譯 34.3 秒、測試 1 分 42 秒 exit1。拖曳前 45 秒回放前進 45,510 ms；拖曳後起算 native=6,313 ms，第一秒降至 801 ms，接著逐秒到 9,896 ms。控制列 display 由第一秒 4,952,071 ms 到第十秒 4,961,160 ms；全部取樣 playing=true／buffering=false、來源未變，分段 HTTP200／MPEGTS。此失敗是把換源後仍會重設的位置當成十秒基準，沒有證明持續卡住或廣告導致黑畫面。

只修整合測試：新來源必須在 playing、非 buffering 且 URI 不變時，連續觀察至少 2 秒並前進至少 1.5 秒；遇到位置倒退超過 250 ms 重新起算，整體 gate 限 60 秒。其後仍要求十秒 native 增量大於 7 秒，另加控制列增量大於 7 秒及來源不變，沒有降低原門檻。正式播放器與 UI 未改。

同範圍回歸編譯 34.0 秒、測試 1 分 54 秒 exit0。45 秒回放增 45,518 ms，30% 拖曳解析目標 5,002,121 ms；捕捉一次啟動 clock reset，穩定基準 native=2,186 ms，十秒後 12,301 ms，增 10,115 ms。控制列逐秒前進、全程取樣非緩衝且來源保留；返回直播解碼後十秒增 10,013 ms。程序正常結束，沒有因等待到期重啟。編譯後只補註解與日誌換行／名稱，不改变斷言與流程。

本輪唯一整合檔 analyze 7.4 秒 exit1，無 error／warning、三項既有 info：19:8 unnecessary_import、2168:34 與 2197:26 prefer_collection_literals。檢查在新增穩定時鐘 gate 前執行，gate 由後續實機測試編譯及執行驗證，未再次 analyze。debug 拖曳 build P95=5,355 us／1 慢幀，不宣稱效能全面修好。證據限單一 TS 來源短拖曳；逐幀時間精度、更多頻道與格式、廣告切換及間歇黑畫面仍需補，完整目標持續。

### 剪輯恢復換直播自然與受控對照

Windows真實唯讀MEDIA_MINI／MINI_CLIP_FIRST／MINI_RECOVERY_SWITCH／OBSERVE_RESTORE_OPEN兩情境均完成，保留既有登入。自然恢復編譯33.9秒、測試30秒exit0：clip解碼／mini前進、另一首頁直播card實際導頁、新source解碼與owner／URI保留、10秒前進通過。native restore atClick=true，但atMount／atNewOwner=false，started=completed=1；pendingAtMount／NewOwner也false，所以只是來源替換，不覆蓋原生恢復內部重疊。

第二情境加CONTROLLED_RECOVERY／REQUIRE_RECOVERY_OVERLAP，編譯33.8秒、測試28秒exit0。舊恢復停在beforeOpen gate，新頁mounted／owner／解碼後才放行，pendingAtClick／Mount／NewOwner皆true；放行後新source保留及10秒前進通過。native atClick／Mount／NewOwner皆false、started=completed=0：舊native開啟沒有開始，不冒充真正native open重疊。兩程序都已正常結束，沒有因觀察等待到期重啟；第二次是刻意不同情境。

两次上游HLS HTTP200、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY／SCTE35=false；Range媒體206／4096bytes、TS sync=true、MP4 hint=false、無init map／BYTERANGE／AES128／SAMPLE-AES。beforeMount／afterMount固定原生失敗分類都空。當下未偵測特定廣告標記，不排除未標記廣告；DATERANGE不單獨算廣告證據，兩個TS成功樣本也不能結案先前fMP4黑畫面或格式切換。

自然換源debug build P95 13194us／11慢幀、受控15806us／13慢幀，raster5841／5715us且無慢幀，不算效能修復。本輪正式程式／測試程式未改，未跑analyze；僅依write-page保存真實執行與診斷證據，不記token／簽名URI／raw native內容。仍須更強native內部重疊及fMP4／廣告切換失敗樣本；完整DVR／訪客live與完整矩陣保留未完成，目標持續。

### 正式訪客聊天登入入口與返回

在完整mounted離線watch案例中實際tap聊天訪客提示的FilledButton登入，正式Navigator導向TwitchLinkedLoginPage並跑原readStatus。斷言主／Web／Drops／client同一供給實例、autoCloseOnComplete=true、畫面顯示尚未登入；未按授權按鈕或開WebView。Navigator返回後原watch仍guest、viewer=null、loadingAuth=false、不可發言與實際唯讀提示、chat connect仍一次，不重建匿名連線。三組auth load計數各3，對應觀看啟動／登入確認／返回重載；輔助getToken覆寫null，readStatus不碰真實儲存或遠端驗證。

首次fixture誤找OutlinedButton造成tap失敗，更正為正式FilledButton後通過，不是UI程式錯誤。上輪5項fixture單行if改區塊。injection6＋startup10＋chat4＋home17＋session35＋following30聯合102項通過，約5秒exit0；唯一injection測試analyze6.4秒No issues found、exit0。正式程式未改、本輪未啟動真實App，不讀寫憑證或觸發Twitch寫入。

此證据涵蓋正式訪客離線watch→聊天登入入口→聯合登入狀態確認→取消返回，未完成真實OAuth／mock授權成功、其他入口或訪客開台解碼。離線啟動／chat與傳輸仍為隔離fixture，不當成真人訊息。依write-page保存修正前測試失敗與範圍限制；訪客live播放、原生恢復重疊、間歇黑畫面／廣告與完整矩陣仍待驗證，目標持續。

### 正式訪客離線觀看頁完成啟動

新增storage gate在mounted期間完成的正式watch案例，HTTP200 user.stream=null觸發原離線分支，使用原playlist runtime與fail-closed播放API／fake PlayerSession，不跳過initState／loadAuth／loadWatch／pipeline。供給chatStartup API回channel7、空badges；fake可監聽chat runtime接上原controller與UI，connect參數accessToken=null、連線恰一次。startup fake首輪缺roomState造成widget例外，补roomState／角色getter後通過，此為fixture補齊，不是正式程式修復。初版測試以201作模式哨兵，改為明確HTTP200與startup bool，不混淆HTTP證據。

正式頁面斷言loadingAuth／loadingWatch及chat／relationship／engagement／emote bootstrapping全部false，offline placeholder=true、channelId=7、guest=true、不可發言；實際訪客唯讀提示文字顯示。卸載後ensure與20秒推進，請求數不增加、無原生Player／例外／timer。injection6＋startup10＋chat4聯合20項通過，補UI提示後injection6再通過。唯一測試檔analyze6.3秒exit1，無error／warning，5項新增fixture单行if格式info（174／180／184／192／360）留下一輪，不再analyze。

本輪正式程式未改、未啟動Windows真實App、未連IRC或讀寫真實憑證。這是完整掛載與離線啟動／guest聊天UI接線證據，不是開台媒體播放或真人聊天讀取；chat為空fixture，未送出訊息／開真實登入／兌換。訪客live播放、登入按鈕導頁／快捷入口與更多權限競態仍待補；原生恢復中換來源與黑畫面／廣告未結案。依write-page保存成功與失敗範圍，完整目標持續。

### 訪客初始頁明確傳輸與離頁請求防護

正式watch初始storage pending掛載案例擴為HTTP200／503兩分支。對供給client的Dio加攔截回應，回傳fixture data.user.stream=null或503，斷言至少實際發送一個請求且沒有Authorization標頭；不靠widget環境的400回應作唯一網路隔離。離頁後完成storage gate、再呼叫ensure、推進20秒，請求數保持離頁前值、無原生Player、無未處理例外或pending timer。503僅測初始timeline讀取失敗的容錯，不等於播放中斷線恢復或重試成功。

injection5＋startup10＋chat4聯合19項通過，exit0。新fixture單行if改成區塊，為docs測試的visibleForTesting API和刻意替換完整依賴field加局部檔案註記，不改正式程式；唯一analyze只檢查injection測試，6.3秒No issues found、exit0。其他檔既有info仍按前輪保留，不稱全專案乾淨。本輪未啟動真實App、未讀寫真實憑證。

定向檢查runWatchStartupPipeline：liveAvailable=false走離線占位並跳過播放啟動；其他分支仍含播放器初始化與延後chat等工作。當前測試auth gate只在卸載後完成，因此尚未涵蓋此完整pipeline，不能把19項稱完整訪客watch／捷徑或解碼完成。下一輪須在仍mounted時完成auth並補offline／player／chat fake依賴；原生恢復中換來源、黑畫面／廣告仍待驗證。依write-page保存回應範圍與限制，完整目標持續。

### 正式訪客初始觀看頁掛載與輪詢釋放修復

新增正式 TwitchWatchPage widget 掛載案例，使用完整 supplied services、記憶體 auth storage gate、fake player session、原 playlist runtime（播放API fail-closed）、mock prefs／Windows platform／connectivity。執行原 initState／build／postFrame直到 auth.loadStoredSession pending；驗 viewer=null、loadingAuth=true，卸載後釋放storage gate，無晚到setState或原生Player。沒有跳過正式watch生命週期，但未完成 loadWatch／chat／解碼，不算完整訪客觀看功能。widget binding阻擋HTTP；初始timeline查詢收到模擬400，未連外、未使用真實token，下一輪應補明確mock傳輸。

初期fixture因import順序、官方emote建構必填参数及型別缺漏編譯失敗，之後補HypeTrain／runtime getter／離頁pause方法，再修platform override需在test body結束前恢復的fixture規則。fixture補齊後正式頁面卸載仍留下8秒週期Timer，stack定位 ensureWatchModeRuntime建立TwitchLiveWatchRecovery，正式dispose未釋放，只等下輪poll遇unmounted才stop；此為可重現生命週期缺漏，不是fixture缺方法。正式live state新增disposeWatchModeRuntime取消／清除Expando，watch.dispose呼叫，ensure對unmounted直接返回，防止離頁後重建。

修正後injection4＋startup10＋chat4聯合18項通過。再加離頁後呼叫ensure並推進20秒的斷言，injection4通過、不留下timer。唯一analyze三檔6.6秒exit1，無error；1warning為docs206 setMockInitialValues的visibleForTesting註記，9info為fixture覆寫field／單行if及watch565既有格式，下一輪處理、不再analyze。正式函式與測試以編譯／widget執行驗證，不把analyze稱乾淨。

Windows FOLLOWING_ENTRY＋LIVE_ROUTES編譯33.9秒、測試57秒exit0：預設追隨第一卡／chat／解碼／15秒、返回原首頁／chat斷開、mini播放／三類拖50px回位、展開fresh chat／owner／左欄12樣本、close暫停、另一首頁卡新upstream／proxy／owner／URI、左欄12樣本及15秒持續解碼均通過，程序正常結束。live-build P95 19742us／23慢幀、restored-live16477us／2慢幀、second-live7044us／4慢幀；不是profile效能或native open重疊／間歇黑畫面结案。未動憑證／協議／UI／播放底層；依write-page保存失敗與範圍。完整訪客启动／捷徑、恢复重疊與廣告切換仍待測，完整目標持續。

### 訪客聊天室連線隔離與重試

正式 chat controller 新增 optional runtimeFactory，watch 的 initialChatRuntimeFactory 原樣交接；未注入仍建立原 read IRC／登入 write IRC、badge cache與recent服務，未改協議。factory只接收 authenticated 布林，token仍按原connect參數使用。完整訪客掛載可因此替换runtime，避免controller直接開真實連線。

既有chat生命週期檔新增訪客成功／連線失敗重試兩案：執行正式 connectChat、共用guest決策、startup補資料、runtime連線參數與釋放；零驗證、accessToken與viewerId為null、不能送出、失敗後connecting清除、重試成功。fail-closed假的Drops／其他服務未被呼叫，runtime fake不開IRC／Player；不是完整widget或真實網路。首次測試因badge fixture構造參數名稱錯誤編譯失敗，其餘13案通過；更正後chat4＋injection3＋startup10聯合17項通過、exit0。唯一analyze6.5秒exit1，無error／warning，3 info：新測試52 curly_braces、既有測試212 unnecessary_underscores、watch565既有curly_braces，留下一輪處理、不重跑。

Windows預設FOLLOWING_ENTRY編譯34.0秒、測試24秒exit0：原儲存登入／追隨第一卡／對應watch／chat連線／解碼／15秒前進均通過，程序正常結束；live-build P95 16781us、19慢幀，raster6343us、0慢幀，不算效能結案。不更動憑證、Twitch協議、UI樣式或播放器底層。依write-page保留初次失敗与覆蓋限制；完整訪客widget、恢復中換來源與黑畫面／廣告切換仍待驗證，目標持續。

### 觀看頁完整依賴注入入口

觀看頁新增 optional initialServices，session factory 採 suppliedServices 或原預設 factory，沿用原 initState／啟動與釋放流程，不跳過功能。提供服務時拒絕與 initialDiscovery 的 authService 或 initialPlayerRuntime 不同實例，防止混用；route 擁有 client／runtime 生命週期。未提供依賴時行為不變。此入口是安全完整訪客掛載的前置工作，不是訪客功能通過。

新 session injection 三案驗證所有 handle 與五組 feature port 保留供給實例、錯帳號／錯 runtime 拒絕，與 startup10 聯合13项通過，約1秒測試進度、exit0。fixture 不掛 widget、不執行服務方法，輔助 auth 僅建構不載入，PlayerSession／runtime 為 fail-closed fake；不代表這組 placeholder 可執行完整 watch。唯一三檔 analyze6.5秒exit1，無error／warning，watch563既有curly_braces info保留。Windows預設FOLLOWING_ENTRY編譯34.1秒、測試23秒exit0，正常登入／預設追隨第一卡／chat／解碼／15秒通過，程序正常結束；live-build P95 16701us、18慢幀，raster6441us、0慢幀，不作效能結案。

定向確認 chat controller connectChat 仍直接建立 TwitchIrcApiService（116／117）並 connect（136）；只有 services 注入尚不能保證完整 fixture 不連外。下一步須隔離 IRC runtime 建立與完整 Player／服務行為，才可掛正式觀看頁測訪客／捷徑。未修改 token儲存、Twitch協議、UI或播放底層；依 write-page 保存範圍限制。完整矩陣、原生恢復重疊與間歇黑畫面仍未完成，目標持續。

### 共用身分更新後觀看登入狀態修復

正式觀看頁共用 session listener 原本只同步 viewer，不同步 loading，且沒有呼叫新 loadAuth。方法隔離接上正式 syncViewerIdentity listener 後重現兩案：其他消費者已 resolve 新身分，舊驗證成功返回 null 時 loading 仍 true；舊一般錯誤則跳 OAuth 提示。修正前10案中2案失敗、8案通過。正式 syncViewerIdentity 依共用 checking 狀態同步 loading；loadAuth 將晚到 null 改採目前 snapshot，並以 resolve 前身分 revision 淘汰舊錯誤提示，保留目前請求失敗的提示與重試。

修正後 startup10＋home17＋session35＋following30 聯合92項通過，約4秒exit0。補強新驗證完成、舊請求仍 pending 時 loading 已 false 的斷言後，startup10再通過。唯一 analyze 三檔6.4秒exit1，無 error／warning，既有 twitch_watch_page.dart:559 curly_braces_in_flow_control_structures info 保留；補斷言後未再 analyze。Windows FOLLOWING_ENTRY 編譯34.7秒、測試23秒exit0：儲存登入、預設追隨第一卡與對應直播、唯讀 chat、解碼及15秒前進通過，程序已正常結束。debug home-build P95 31219us／6慢幀，live-build16964us／14慢幀、raster5985us／0慢幀，不算效能结案。

修復不動憑證儲存、Twitch協議、UI樣式或播放器底層。隔離案例執行正式 startup 與 listener，但不是完整 widget／chat／Player；真實回歸沒有實際登出換帳號，不把正常登入成功當完整身分切換證據。完整訪客 watch、原生恢復中來源切換與間歇黑畫面／廣告仍待測；依 write-page 保存失敗與限制，完整目標持續。

### 觀看登入失敗重試與離頁回應測試

觀看 startup 隔離測試新增六案：目前驗證一般失敗結束 loading 並提示一次，下一次成功可恢復 viewer；無 token 訪客清除舊 viewer 且不驗證；驗證 pending 時模擬登出並啟動新 load，舊成功／錯誤均不提交；模擬 mounted=false 後舊成功／錯誤均不呼叫 setState 或提示。既有兩案保留，startup8＋home17＋session35＋following30 共90項通過，約4秒、exit0。首次編譯因測試誤用不存在的 enum 名稱失敗，其餘82項通過；更正為既有 TwitchViewerStatus 後聯合重跑通過。唯一 analyze 檢查 startup 測試，6.4秒 No issues found、exit0。

本輪只擴測試，正式程式未改。fixture 執行正式 loadAuth extension，但 mounted 為覆寫布林，不是 widget 真正 dispose；登出為記憶體假身分加新 load，不測真實 token 儲存、無新 load 的完整通知接線或完整訪客 watch。未啟動真實 App，未連 IRC／Player、未更動憑證。依 write-page 規則保留失敗、回歸與範圍限制。完整訪客觀看頁、原生恢復中換來源及黑畫面／廣告切換仍待驗證，完整目標持續。

### 觀看登入舊驗證錯誤提示修復

定向檢查觀看startup／session factory：觀看頁共享主auth，但factory仍自建client與輔助Web／Drops服務，chat loader含實際IRC建立；目前不能直接把首頁fixture掛進watch當作完整安全隔離。新增啟動方法隔離fixture，以TwitchWatchPageState子類覆寫依賴getters、mounted／setState／showSnack，執行正式loadAuth extension；不掛widget、不建Player／IRC或存取儲存。此法只證明方法行為，不等於完整訪客觀看頁掛載。

舊成功與舊一般錯誤兩案先跑，成功通過，錯誤案重現：新viewer99已完成，舊StateError仍顯示「OAuth 暫時載入失敗」提示。正式loadAuth以Expando保存每個State的讀取版本，輔助服務載入後、驗證完成後及catch只允許目前版本更新；不改session登入政策、token儲存、IRC協議、UI或播放runtime。修正後兩案均保留新viewer99／new_viewer、loading=false、共用snapshot一致且無舊提示。未把這兩案當成離頁／所有連續帳號／目前請求失敗或401／403完整覆蓋。

startup2＋home17＋session35＋following30聯合84項通過，約4秒exit0；唯一analyze正式startup與新測試6.4秒exit0、No issues found。真實Windows FOLLOWING_ENTRY回歸編譯33.9秒、測試23秒exit0：登入解析／預設追隨第一卡／對應watch、唯讀chat／解碼／15秒前進通過，保留真實帳號與偏好。live debug build P95=15454us、18幀逾33.333ms，raster P95=6100us、0幀逾門檻，不作卡頓或間歇黑畫面結案；測試正常結束、App隨程序關閉。

完整訪客watch掛載仍須隔離service／chat／player依賴，方法fixture不替代該範圍；快捷入口、原生恢復重疊與其餘矩陣保持待測，完整目標持續。

### 訪客瀏覽與搜尋卡片觀看路由交接

新增正式首頁瀏覽與搜尋兩入口，實際Flutter tap可見TwitchStreamCard，由NavigatorObserver取得新MaterialPageRoute，檢查其正式builder產生TwitchWatchRouteGuard：channelLogin=public_fixture、同一discoveryService與訪客auth、initialKnownFollowing=null；瀏覽入口另核對標題与broadcasterId。搜尋入口先實際輸入查詢，完成搜尋後點卡，沒有直接呼叫開頁方法。路由在下一frame掛載觀看頁前removeRoute，返回後原首頁與公開卡仍可用，validation／Helix零請求；未建立原生Player或連真實IRC。

此為正式卡片callback→Navigator→觀看route builder的參數交接，不是觀看頁掛載、聊天室、播放器解碼或真實訪客App完整流程。完整觀看隔離目前只有initialPlayerRuntime入口，需再核對觀看startup與輔助auth／chat服務依賴才能安全覆蓋；不以移除路由冒充播放成功。home17＋session35＋following30聯合82項通過，約4秒exit0；唯一home測試analyze6.5秒exit0、No issues found。正式程式／UI／協議未改，真實帳號與偏好未動，未啟動原生App。

完整訪客watch掛載与播放／快捷入口、原生恢復重疊和其餘功能矩陣仍待驗證，目標保持進行。

### 訪客搜尋重試晚到回應與離頁回歸

完整首頁隔離fixture新增六個搜尋案，皆操作正式toolbar輸入與搜尋頁：首次搜尋fixture失敗顯示錯誤文案且無卡片，實際點搜尋頁OutlinedButton「重新整理」才第二次請求並恢復公開卡；兩個查詢並行，新查詢先完成後舊查詢成功回空清單或拋錯，仍保留新query與公開卡、沒有舊error；清除搜尋後舊成功回應不還原清單，Browse公開卡保持；離頁後舊搜尋成功／失敗不產生setState-after-dispose或未處理例外。訪客各案validation／Helix請求零次，不自動登入，不發真實帳號寫入。

再補前輪首頁初始pending換身分的舊驗證失敗分支：新身分在舊Completer完成前已authenticated／loading=false，舊StateError完成後仍Following與追隨卡。這是固定fixture一般錯誤，不宣稱401／403或所有平台網路競態完成；搜尋回應淘汰也不等同取消原生HTTP請求。未改正式程式、UI或協議。

home15＋session35＋following30聯合80項通過，約4秒exit0；唯一analyze新home測試6.4秒exit0、No issues found。未跑正式library，前輪stream page4:8既有unnecessary_import info保留，不以本輪新測試乾淨宣稱全專案乾淨。未啟動真實App，沿用隔離憑證／prefs／傳輸／平台fixture。完整訪客卡片進watch／快捷入口、更多scope／root錯誤競態與原生恢復重疊仍待補，完整功能矩陣未完成。

### 非空首頁搜尋身分切換與舊驗證等待修復

首頁fixture改為公開及追隨非空卡片；新增訪客從正式toolbar EditableText輸入public_fixture，360ms debounce後正式搜尋頁顯示卡片、零validation／Helix請求，再點清除搜尋返回Browse且公开卡保留。同一正式首頁State的fixture訪客登入轉Following／追隨卡，登入轉訪客回Browse／公開卡且旧追隨卡消失均通過。此為假的身分通知，不呼叫真實登出或登入對話框。七案先通過，正式程式未為卡片／搜尋改UI。

再新增初始驗證pending時換fixture身分的完整首頁案，修正前loadingLoginState仍true而失敗。根因是_loadLoginState的_running gate把新身分讀取排在旧驗證後，子頁通知修復不能解除root等待。正式首頁增加讀取loadId與replacePending協調：身分通知取代等待中的讀取，完成前／提交／catch檢查當前loadId，只有目前讀取能收尾_running／pending與私訊session刷新。一般重複刷新仍按原pending排隊，不改OAuth儲存／刷新實作或Twitch協議。

修正後新身分在舊Completer未完成時已authenticated、loading=false；舊成功完成後仍是正常Following与卡片。home8＋session35＋following30聯合73項通過，約4秒exit0；不把此案當成所有多連續身分／晚到失敗或原生HTTP取消完成。清理前輪新home測試unnecessary_import與curly_braces兩則info；唯一analyze正式stream page library（含part）＋home測試6.7秒exit1，無error／warning，只剩既有stream page4:8 unnecessary_import，不修無關import或反覆analyze。

預設依賴真實Windows FOLLOWING_ENTRY回歸編譯33.9秒、測試23秒exit0：登入解析／預設追隨／第一卡對應watch、唯讀chat／解碼／15秒前進通過，保留帳號與偏好。debug live build P95=15338us、17幀逾33.333ms，raster P95=6255us、0幀逾門檻；仍有慢幀，不做跨輪效能結論。測試正常exit0、App隨程序關閉。完整訪客卡片進watch／快捷入口、搜尋失敗與晚到回應、更完整root帳號競態、原生恢復重疊仍待測，完整矩陣持續。

### 完整首頁隔離啟動與訪客初始狀態修復

正式TwitchStreamPage新增可選的TwitchStreamPageServices依賴組，包含同一apiClient／authService／authApi／discovery及Drops／Web服務，一致性assert與client由page關閉的生命週期契約保留；未傳依賴時仍建立原服務。測試掛載正式首頁，沒有跳過_loadLoginState、正式Browse／Following或背景初始化。主帳號／Drops／Web載入由記憶體fixture覆寫、Dio攔截全部帳號資料傳輸、公開探索requestOverride、SharedPreferences使用mock（關閉假的更新自動檢查）、connectivity與通知平台使用本地fixture，不讀寫真實憑證／帳號。

第一次fixture編譯因loadStoredSession少refreshIfNeeded參數失敗，補對齊介面後guest首頁重現：loadingLoginState已結束且Browse顯示，但共用session.status仍checking。根因是新session固定checking，而沒有token的首頁不呼叫驗證，沒有後續轉guest機會。共用session constructor現依既有記憶體accessToken是否空設定guest／checking；不改讀寫憑證、刷新或協議，不在各頁另加登入政策。修正後首頁guest／有效follows／缺scope／pending validation四案通過；checking時仍Browse與公開讀取，驗證完成才Following；缺scope保持authenticated但Browse且無追隨GET，訪客guest／Browse且無追隨GET。

初版widget平台未安裝通知implementation，正式服務捕捉LateInitializationError；補通知platform fixture／method channel後聯合home4＋session35＋following30共69項通過，約3秒exit0，沒有通知初始化錯誤。公開資料fixture為空清單，證明正式頁面載入／分類接線，不把此案算非空卡片、watch／快捷入口或真實原生通知驗證。唯一analyze stream page library（含part）、session與新home測試6.5秒exit1，無error／warning、3 info：home測試11:8 unnecessary_import、129:9 curly_braces_in_flow_control_structures、既有stream page4:8 unnecessary_import。依規則不修lint／重跑，下一輪清理測試info再檢查。

未注入依賴的真實Windows FOLLOWING_ENTRY回歸，編譯34.0秒、測試23秒exit0：儲存登入解析、預設追隨、第一張卡直入對應watch、唯讀chat／解碼／15秒前進通過，保留真實憑證與偏好。debug live build P95=18100us、23幀逾33.333ms，raster P95=6240us、0幀逾門檻，不算卡頓修好。測試正常结束，App隨程序關閉。完整訪客watch／搜尋／快捷入口、登入切換首頁與原生恢復重疊仍待補，完整目標持續。

### 身分通知修正後真實追隨入口與直播路由回歸

Windows FOLLOWING_ENTRY＋LIVE_ROUTES真實App回歸，編譯34.3秒、測試1分5秒exit0，保留原登入／偏好。首頁儲存登入解析後authenticated且預設Following，不切Browse，實際點第一張追隨卡，觀看頁頻道一致、唯讀聊天室連線、解碼及15秒前進通過。返回原首頁時舊chat斷線，依既有keep-mini=true偏好確認mini解碼與位置前進。影片touch／mouse及footer mouse各拖50px並回位0px，後續播放仍前進、failedSamples=0。

點mini影片展開watch，新聊天室與owner接手通過；左欄12次100ms幾何取樣穩定。再次回首頁實際點mini關閉，播放表面消失且共用播放paused；再從首頁實際點另一可見頻道卡（既有測試標籤稱browse channel，不把此步算追隨第一卡排序），新頻道聊天室、解碼／上游變更、proxy／owner／URI一致及15秒前進通過，左欄同樣12次取樣穩定。本分支未啟用RAIL_SWITCH，不列左欄選台本輪覆蓋。

debug live build P95=18955us、18幀逾33.333ms，raster P95=6329us、0幀逾門檻；restored-live build P95=12654us、2幀逾門檻，second-live build P95=6179us、5幀逾門檻。只保存數值／布林、無憑證與來源URI；不作正式版效能或卡頓结案。唯一analyze前輪兩正式檔與兩頁面測試6.2秒exit0、No issues found。正式程式／測試入口本輪未改，只增加回歸紀錄。

此批補已登入實際首頁卡片→watch→home→mini→另一watch接線，不是完整訪客首頁、真實帳號切換、keep-mini=false或原生恢復open內部重疊。單次路由成功不抹去既有間歇黑畫面／慢幀；完整矩陣仍未完成。測試程序已正常exit0，App隨測試結束關閉，未另重啟。

### 訪客登入與初始驗證切換接線修復

正式Following＋discovery／session隔離測試新增無首頁reloadTick的訪客轉有效身分，以及初始驗證pending時換有效帳號。修正前訪客转登入單案失敗，session停checking、追隨頁仍授權提示；初始pending切換單案pumpAndSettle超時，沒有啟動新身分讀取。兩案根因是頁面監聽只有_loadedViewerAuth存在才處理，尚無成功清單的身分變更被忽略。

共用session新增唯讀identityRevision，讀取既有_generation並同步，身分替換／invalidate才改變，驗證成功不改版本。沒有新增登入政策或修改token儲存、刷新、協議。正式Following監聽先比較版本，變更即清除並重新讀取，不必等待舊驗證或首頁reload；版本不變才維持原已載入清單判斷，避免把自己驗證完成當成另一帳號重新載入。換service時重設觀察版本，既有監聽生命週期保留。

兩案修正後通過：訪客轉登入沿用State、authenticated且讀取／空追隨畫面出現；pending換帳號在舊Completer未完成前就用新viewer99請求，舊成功回應完成後仍viewer99且頁面正常。另新增pending登出案例：舊驗證未完成前guest／授權提示／零請求，晚到成功不能還原帳號；版本單元案例確認驗證完成不變、token替換與invalidate才遞增。假服務補固定版本getter。聯合session35＋following30共65項通過，約3秒exit0；唯一analyze兩正式檔與兩測試6.6秒exit0、No issues found。

本輪只處理共用session至正式追隨子頁的通知接線，未改UI／播放runtime，也未登出真實帳號或啟動原生App。不等同完整首頁啟動分類／watch／快捷入口／登入對話框，完整矩陣與原生恢復重疊、間歇黑畫面仍待完成。

### 追隨身分通知立即清除與監聽生命週期

同service／State的失權案例再加入不改reloadTick分支。修正前有reload兩案通過，無reload的訪客與缺scope帳號两案均失敗，loadedStreams仍保留一張舊身分卡。正式Following頁新增共用viewerSession通知監聽：已有清單身分快照且目前快照變更／失權時，立即透過原refreshStreams(clearExisting:true)清除與重載，不另作token或登入決策。載入中的初始驗證沒有已載入快照，不觸發重複刷新。換discovery service時移除舊監聽、掛新監聽，dispose移除。

四分支修正後通過，未變更reloadTick兩案也清除直播／離線清單、顯示授權提示，資料請求零次、假登入零次；缺scope保持authenticated，訪客保持guest。新增監聽生命週期widget案例確認同State換服務後舊notifier無監聽、新notifier有監聽，離頁後新監聽移除。既有假Discovery補ChangeNotifier介面，只提供本地通知，不存取憑證。聯合session31＋following30共61項通過，約3秒exit0；唯一analyze正式Following與兩測試檔6.5秒exit0、No issues found，涵蓋前輪fake介面補齊。

此回歸涵蓋已有清單的身分通知至正式子頁接線及生命週期；未把初始載入中換身分、訪客轉登入無首頁reload、完整首頁初始分類／watch／快捷入口或真實帳號切換列完成。本輪不啟動原生App、不改UI／OAuth儲存／既定協議。原生播放器恢復重疊、間歇黑畫面與完整功能矩陣仍待驗證，完整目標持續。

### 同一追隨頁失權後清除舊身分資料

新增兩個正式Following頁面＋正式discovery／session隔離案例：先用假的有效帳號載入一張追隨卡，沿用同一service與State，再將記憶體fixture換成訪客或另一個缺scope帳號，透過首頁原有reloadTick訊號重新載入。修正前兩案均失敗，loadedStreams仍保留原卡；refreshStreams保留既有清單，而授權失敗只設paginationError，導致舊身分資料留在頁面。

正式Following頁面記住成功清單對應的共用session snapshot；刷新時若快照已換或不再具讀取權限，先清除直播／離線清單、cursor及舊快照，再走原載入流程。一般同身分刷新仍保留清單，不改session決策、OAuth/token儲存、UI、協議或播放器。兩案修正後確認相同State、清單為空、授權提示顯示、無資料請求／自動登入；缺scope帳號仍authenticated，訪客仍guest。

session檔29項通過。聯合既有Following流程首跑暴露假Discovery缺少cachedAuth介面，已在已確認存活的程序送中斷並得到exit1；補固定記憶體身分快照fixture後聯合58項通過，測試約3秒exit0。涵蓋既有篩選／分頁／刷新／服務替換與晚到回應，不把fake帳號切換當成真實登出；本輪未清除真實憑證或啟動原生App。此回歸是首頁訊號對正式子頁面的接線，不等於完整首頁初始分類、watch／快捷入口驗證，也未證明沒有reloadTick時的即時清除。

唯一analyze正式Following頁、session測試及前輪HTTP格式切換fixture，6.6秒exit0、No issues found；其後假Discovery介面補齊只經編譯／58項執行驗證，未再analyze。下一輪補該fixture靜態檢查，並繼續完整首頁隔離／登入路由與原生恢復重疊。完整目標未完成。

### TS 來源回歸與初始化格式切換

Windows clip→mini→自然恢復→另一直播回歸，編譯35.1秒、測試28秒exit0。原登入解析與追隨首頁通過；本分支仍切Browse搜尋後進clip，不算追隨第一卡直入。clip與mini解碼／位置前進、新直播卡片導頁／owner／URI保留及十秒前進通過。上游清單HTTP200、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY／SCTE35=false；媒體Range回應206／4096bytes、TS sync=true、MP4 hint=false、無init map／BYTERANGE／AES標記。native失敗分類beforeMount／afterMount皆空。這是不同於先前MP4的成功TS樣本，不證明廣告切換成功或排除未標記廣告，更不能把DATERANGE單獨當成廣告證據。

native恢復atClick=true、atMount／atNewOwner=false，開始／完成各1；新owner接手時舊恢復已完成，仍未覆蓋原生open內部重疊。切換debug build P95=18182us、16幀逾33.333ms，raster P95=6572us、0幀逾門檻；當時另有隔離測試／analyzer程序，不作效能對照或卡頓結案。

初始化HTTP fixture三案各補MP4→無map TS→原map MP4：writer完成第7段後新client只收到TS fixture、不帶舊init；第8段切回相同map URL後，新client再收到init＋fragment。仍是非可解碼的本機bytes fixture，經正式代理isolate／parser／writer／bus；不等於真實廣告或原生解碼。0／2／14次map503三案與bus2／open race7／diagnostics4聯合16項通過，修改後約4秒exit0。第一次聯合指令引用不存在的open race檔名導致載入失敗，其餘9項通過；更正為既有twitch_native_open_race_test.dart後16項通過，再擴格式切換後16項通過，未改正式程式。

本輪唯一analyze檢查session頁面測試及四個初始化／競態／診斷測試檔，7.0秒exit0、No issues found，補前輪缺scope頁面靜態檢查。其後新增HTTP格式切換只經格式化與測試編譯執行，未再analyze；下一輪補該檔靜態檢查。完整訪客首頁／路由、真實native open重疊與間歇黑畫面仍待測，目標持續進行。

### 完整 DVR 返回直播門檻與缺追隨權限頁面

完整DVR返回分支由只要求playing與十秒後position增加，補為等待非緩衝且position真正前進；再觀察十秒，要求增量>7秒、playing=true／buffering=false，輸出增量數字。不改正式播放器。相同FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR真實Windows回歸編譯34.2秒、測試4分44秒exit0。直播／唯讀chat、fMP4 DVR、暫停恢復45秒增45633ms、UI暫停跳轉保持暫停／恢復十秒、左右鍵各新generation與目標<2秒／十秒、1/3與2/3方法跳轉各十秒通過；120秒增121649ms、每十秒取樣未緩衝。新增返回解碼斷言通過，後續十秒增10017ms且非緩衝。不是所有頻道／逐幀精度、拖曳或間歇黑畫面結案。

新增Following頁面缺user:read:follows權限的widget測試，正式頁面＋服務配合fake validation／Dio傳輸：已驗證身分仍authenticated、請求零次、不自動登入；點授權按鈕才呼叫fake login一次，fixture換成有權限身分後實際點重新檢查，才有fake讀取、授權提示消失與空追隨畫面。全檔27項通過，案例約1秒exit0；不登出／改動真實帳號、憑證或scope。此為頁面接線，不等於完整App初始首頁分類／watch／快捷入口全部驗證。

唯一analyze在新增頁面測試前執行整合入口6.9秒exit1，無error／warning、3既有info（19:8 unnecessary_import；2168:34／2197:26 prefer_collection_literals）；新docs測試之後只編譯／執行驗證，下一輪補其analyze，不再重跑。extended-dvr debug build P95=12421us、3幀逾33.333ms，raster P95=2915us、0幀逾門檻；同時有隔離頁面測試程序執行，不用本輪作效能對照，其他階段慢幀亦保留。只改測試與紀錄，正式程式／UI／協議未變。

### 初始化下載失敗與完整 DVR 修正後回歸

HTTP接線fixture擴為0／2／14次新map HTTP503失敗三案，實際經正式代理isolate、poller、writer及map載入重試。兩次失敗後恢復與十四次失敗用盡一次重試批次後重新載入皆通過，late client收到新init＋目前fragment；map GET總次數分別2／4／16，失敗回應未當作成功初始化快取。本機3案通過，案例約3秒、程序約9秒exit0，不代表Twitch真實503／斷網已完整覆蓋。唯一analyze正式proxy library與此fixture3.1秒exit0、No issues found。

Windows FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR整合修正後回歸：編譯34.4秒、測試4分44秒exit0，原帳號保留，唯讀chat與直播15秒前進通過。fMP4 init1125bytes先送、完整DVR開始解碼；暫停恢復45秒增45600ms，UI暫停跳轉新generation、目標解析誤差<2秒且保持暫停，UI恢復十秒通過；左／右鍵各產生新stream generation、目標誤差<2秒並持續十秒。1/3與2/3位置以正式方法跳轉，各解碼與十秒進度>7秒通過，非拖曳手勢證據。

120秒回放增121549ms，每十秒取樣playing=true／buffering=false，總增量>90秒斷言通過；返回live狀態及十秒後position增加通過。本分支返回門檻只要求playing与position>起點，沒有明確等待非緩衝／解碼或要求十秒增量>7秒，下一輪須補強，不能等同短回看分支的較強返回門檻。單一樣本有限取樣，不列所有頻道／真實断網／全部停頓或間歇黑畫面完成。

extended-dvr debug build P95=12778us、12幀逾33.333ms，raster P95=3041us、0幀逾門檻；其他階段也有慢幀，不宣稱卡頓解決。本輪只擴fixture與紀錄，未改正式程式、UI、協議、憑證或偏好。完整目標仍需補訪客／登入路由與其他矩陣項目。

### 初始化片段代理 HTTP 接線回歸

新增本機HTTP fixture，以正式TwitchDartHlsLowLatencyProxy隔離執行緒、playlist parser、persistent writer及live bus完整串接。上游map與fragment為小型fixture bytes，不是假裝可解碼影片；沒有Twitch請求／原生Player／憑證存取。等待writer完成第3段，再完成第4段後才建立第一個stream.ts client；讀取前18bytes確認init＋第4段。中斷後第5段重連仍是init＋目前段，同map上游僅GET一次；切map版本再完成第6段，新client收到新init＋第6段，上游map共GET兩次。所有等待以lastWrittenSequence而非固定延遲判定，測試只操控自己的本機fixture代理。

HTTP接線單項通過，與既有bus2／open race7／diagnostics4聯合14項通過，測試約3秒、程序約8秒exit0。唯一analyze正式proxy library（包含writer／bus parts）與兩init測試3.1秒exit0、No issues found，補足前輪正式修正後的靜態檢查。沒有修改正式程式或原生設定；HTTP bytes正確不等於所有影片解碼成功，現有接線涵蓋延後連入／重連／map切換，不包含map下載失敗或中段半包的所有時點。

修正後VOD→mini→自然恢復→另一直播Windows回歸，編譯33.7秒、測試29秒exit0：VOD與mini解碼、新直播實際卡片導頁、解碼／10秒前進>7秒、URI與owner保留通過。beforeMount／afterMount失敗分類均空；來源206／4096bytes、MP4＋init、無AES／BYTERANGE標記。native atClick=true、atMount／atNewOwner=false，開始／完成各1，不能算原生open接手重疊。與前輪clip成功分開保留，不宣稱所有間歇黑畫面結案。切換debug build P95=15403us、14幀逾33.333ms，卡頓仍待驗證。

### 直播晚連入遺失初始化片段修復

整合診斷新增一次上游媒體Range=0至4095探測，不建立額外本機stream.ts客戶端，只輸出HTTP／長度／固定格式布林。首輪編譯36.2秒、測試28秒exit0，206／4096bytes／hasInitMap=true，但原有MP4 box白名單未命中；擴充metadata／padding box及AES／BYTERANGE標記後，4項診斷測試通過。未保存媒體內容、簽名URI或金鑰。

第二輪修正前編譯34.9秒、測試1分46秒exit1，clip→live重現90秒position=0／buffering、idle-active=yes。beforeMount分類空，afterMount為read_failed=2、format_unrecognized=1、unclassified_failure=6，與成功样本空分類不同。上游206／4096bytes、MP4 box=true、hasInitMap=true、hasByteRange／AES128／SAMPLE-AES=false；清單HTTP200／HLS、stitched-ad=false／DATERANGE=true／DISCONTINUITY=false／SCTE35=false。代理輸出增至78秒、owner正確且舊恢復已完成。格式特徵不證明完整片段可解碼，也不等同本機輸出內容。

定位persistent writer每段beginSegment會清空live byte bus replay，但同一map只寫入一次。隔離位元組測試重現：下一段後才建立的client僅收到fragment，沒有前段初始化資料（修正前1案失敗，Expected init＋fragment／Actual fragment）。修正live bus獨立保留初始化bytes，新client在目前段之前收到初始化，已有client只在map更新時接收更新；TS段清除保留map，close釋放。writer載入成功後才記住map，停止後不寫入，其他sink仍按原路徑輸出。不改播放器解碼設定、帳號協議或UI。

兩項bus回歸（晚連入、map更新與TS清除）聯合4項診斷共6通過，程序約4秒exit0。修正後真實clip→live編譯33.9秒、測試28秒exit0，解碼／10秒>7秒／URI及owner保留通過，beforeMount／afterMount分類皆空，同樣MP4＋init來源。單一真實成功不宣稱所有間歇黑畫面已修完；仍須補persistent writer本機HTTP接線、更多晚连入時點／格式與長時間回歸。native接手時open已完成，非內部競態覆蓋。

本輪唯一analyze於格式probe初版三入口7.2秒exit1，無error／warning、3既有info（整合19:8 unnecessary_import；2168:34／2197:26 prefer_collection_literals）。後續metadata診斷與正式writer／bus修正只經單元測試、Windows編譯與真實回歸驗證，未再analyze；下一輪補正式檔analyze。修正後切換debug build P95=14169us、17幀逾33.333ms，卡頓問題不列完成。

### 原生日誌固定失敗分類

新增docs診斷helper，只將原生訊息轉成固定category與次數，不保留或返回原文。分類涵蓋格式辨識、開啟、連線拒絕、HTTP、讀取、moov、無媒體stream、decoder、option、property、EOF與未分類錯誤；不同類型可以同時計數。整合流程分新頁面建立前／後採樣，每10秒及finally都輸出去敏摘要，快速成功也有比較基準；建立時点是Flutter route，不能直接當native新媒體load事件。

去敏helper兩項與開啟競態七項共9項通過，程序約5秒exit0；fixture含假敏感字串，斷言結果無原始URL／secret、計數正確且snapshot不可修改。docs競態測試加入局部檔案測試用途註記，處理上輪visibleForTesting警告。唯一analyze四入口6.9秒exit1，無error／warning，3既有info（整合19:8 unnecessary_import；2133:34／2162:26 prefer_collection_literals）；finally摘要之後僅整合編譯驗證，不再analyze。

Windows clip→mini→自然恢復→新直播兩輪編譯34.5／34.7秒、測試各28秒exit0，新來源解碼、10秒前進>7秒、URI／owner保留通過。首輪快速通過沒有達10秒診斷點，因此補finally摘要；第二輪beforeMount={}／afterMount={}，沒有命中已列失敗類型，native atClick／Mount=true、atNewOwner=false，開始／完成各1，仍非接手時open重疊證據。成功清單HTTP200／HLS、stitched-ad=false／DATERANGE=true／DISCONTINUITY=false／SCTE35=false。第二輪切換debug build P95=13945us、10幀逾33.333ms，仍有慢幀。

本輪只改診斷helper／測試／紀錄，正式播放器開啟行為未變；兩輪成功不能抹去先前90秒黑畫面。下一輪須取得失敗樣本的分類，再核對代理輸出格式與播放器讀取；目前空分類只證明這些成功樣本未收到命中的訊息，不代表所有原生錯誤都已覆蓋。

### 過期開啟完成覆蓋來源狀態修復

新增僅unused debug host可用的隔離Player注入，測試以implements Player的fake控制open future，沒有建立原生Player／video controller、取得媒體或存取憑證。修正前兩案皆失敗：新來源先完成後，舊restore晚完成把currentMediaUri覆蓋回fixture-old；dispose後舊restore晚完成也把null寫回fixture-old。這是正式來源狀態提交的可重現錯誤，不是原生解碼黑畫面根因證明。

PlayerHost的restoreSharedMedia與openOrResume共用開啟request revision，過期完成或播放器已替換不再寫回來源／執行晚到pause；同來源seek後再play也檢查版本。pauseShared／stop／dispose使先前提交失效，stop晚到不清除新來源。沒有序列化或取消原生open，不能宣稱已解決native內部所有交錯。新增7項fake回歸涵蓋先新後舊、dispose、pause、舊／新失敗、同URI復用與播放器替換；與既有18項播放狀態聯合25項通過，案例1秒內、程序約5秒exit0。

唯一analyze正式檔與新測試4.5秒exit1，無error、兩項invalid_use_of_visible_for_testing_member warning（docs測試31:30／143:32，測試放在docs而非標準test路徑）；本輪不反覆修lint或再analyze，下一輪以局部測試用途註記處理。沒有修改OAuth、IRC、GQL、點數payload或UI。

修正後Windows clip→mini→自然恢復→另一直播編譯35.2秒、測試1分46秒exit1：舊剪輯與mini解碼正常，新直播90秒position=0／buffering=true、idle-active=yes，owner正確、URI已變，pendingAtMount／NewOwner=false，recoveryError=none。代理writer=true／clients=1，outputMs由8秒持續到78秒，runtimeError=false；nativeFlags固定error=2／format=3／failed=7，未保存原始日誌。10至90秒的上游清單均HTTP200／HLS、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY=false、SCTE35=false。這次取得黑畫面期間的清單標記，未偵測特定廣告標記，但不排除未標記廣告；代理寫入前進也不證明原生實際讀取／解碼。保留真實回歸失敗，不以25項隔離通過宣稱黑畫面修復；下一步補原生失敗訊息固定分類與代理到播放器的格式／讀取證據。

### 原生恢復開啟時序觀測

PlayerHost新增OBSERVE_RESTORE_OPEN測試旗標，預設關閉；啟用時只在restoreSharedMedia的原生player.open呼叫前計數開始、finally計數完成，公開測試用數字／布林讀取，不記錄URI或插入延遲。整合流程在點擊、頁面建立、首次新owner通知取樣，新增REQUIRE_NATIVE_OPEN_OVERLAP嚴格斷言；不以整個恢復future pending當成原生open pending。

剪輯→mini→自然恢復→另一直播真實回歸：編譯35.0秒、測試29秒exit1。舊剪輯解碼、mini前進、新卡導頁、新直播解碼與10秒增量>7秒、URI／owner保留通過；native-open atClick=true、atMount=true、atNewOwner=false、started=1／completed=1。原生open確實與新頁面建立重疊，但新來源接手時已完成，因此890行的嚴格native重疊斷言失敗，不判正式播放故障，也不列來源接手競態完成。下一步建立可控原生open隔離測試以驗證晚到完成的狀態提交，再對照真實觀測；不得把延長wrapper等待宣稱原生內部仍執行。

唯一analyze兩入口6.9秒exit1，無error／warning、3既有info（整合19:8 unnecessary_import；2121:34／2150:26 prefer_collection_literals）。正式檔僅增加預設關閉的觀測，不修改開啟順序／來源提交／帳號協議；整合測試與紀錄同步更新。成功直播清單HTTP200／HLS、stitched-ad=false／DATERANGE=true，不作黑畫面廣告證據。切換debug build P95=14819us、15幀逾33.333ms，仍不宣稱零卡頓或黑畫面已修。

### 自然恢復與來源接手的重疊限制

移除CONTROLLED_RECOVERY開啟前閘門，保留MEDIA_MINI／MINI_RECOVERY_SWITCH／REQUIRE_RECOVERY_OVERLAP，分別以剪輯與VOD為舊來源。剪輯輪編譯35.2秒、測試31秒exit1；VOD輪編譯35.1秒、測試29秒exit1。兩輪舊來源解碼、迷你播放、新首頁卡導頁、新直播接手與10秒進度增量>7秒均通過，舊恢復沒有回報錯誤，新URI／owner保留。

兩輪pendingAtClick=true、pendingAtMount=true、pendingAtNewOwner=false：新頁面建立與舊恢復重疊，但真正新來源接手前，舊恢復已完成。嚴格重疊斷言於整合入口867行失敗，不能把自然來源替換成功當成原生open內部競態通過；沒有重現正式播放故障。下一步須建立可觀察原生open開始／完成的去敏證據與可控開啟等待測試，不能單純延長恢復future或放寬接手斷言冒充內部重疊。

兩輪新直播清單HTTP200、HLS=true、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY=false、SCTE35=false。成功樣本的一般DATERANGE不作廣告判定，間歇黑畫面當下廣告證據仍未取得。只更新本機測試紀錄，沒有改正式程式、測試入口、偏好、憑證或原生runtime，未跑analyze。切換階段debug build P95剪輯17965us／VOD15770us，各19／16幀逾33.333ms，不宣稱卡頓已解決。

### 無直播回放樣本的前置條件

候選選取改用FollowingPageState.loadedStreams，而非只包含已建立卡片的Widget finder。先檢查十二台的真實流程編譯36.0秒、測試6秒exit1，十二台皆growingArchive=true，仍屬樣本前置條件失敗。取消十二台上限後，本次載入21台，第13台（index=12）growingArchive=false；Flutter scrollUntilVisible捲到匹配卡片並實際點擊，相符直播路由、唯讀聊天室及直播15秒前進通過。這是本次已載入清單，不代表全部追隨分頁。

第二輪編譯35.4秒、測試2分40秒exit0。watch確認hasArchive=false；短回看120秒增121816ms、longestStallSeconds=0、maxLagDriftMs=1，lag約12007ms、slider約0.39965，20秒窗口與比例斷言通過，控制列外框高度／上緣差均0。返回live解碼與10秒增量>7秒／非緩衝通過。單一無archive樣本未重現停滯，不代表所有頻道或間歇黑畫面已修復；外框穩定不證明所有內部字元無抖動。

本輪唯一analyze整合入口6.8秒、exit1，無error／warning、3既有info（19:8 unnecessary_import；2098:34／2127:26 prefer_collection_literals）。正式播放器、UI、協議與憑證未改；候選只輸出數量、index與archive布林。limited-replay build P95=6557us、14幀逾33.333ms，raster P95=8011us、0幀逾門檻；debug樣本不宣稱零卡頓。

整合測試新增NO_ARCHIVE_SAMPLE旗標，跟FOLLOWING_ENTRY／LIMITED_REPLAY搭配：只讀候選的最新回放，排除正在增長的archive，實際點卡進watch後仍須hasUsableLiveDvrArchive=false。短回看觀察新增20秒liveSeekWindowDuration與slider比例接近clamp(1-lag/20000)（容許0.05）的斷言，不用完整archive的全時長比例代替20秒窗口。

首輪候選上限6，編譯37.2秒、測試4秒exit1；六台皆growingArchive=true，於候選前置條件失敗，未點直播或進短回看。上限擴為12後編譯35.1秒、測試5秒exit1，但Widget finder當時只列出六張已建立卡片，仍只檢查同樣六個index；不是十二台皆有回放。此為無合適樣本及測試選取方式限制，不判定正式App壞掉，也不標無VOD／20秒幾何通過。下一輪改用FollowingPageState.loadedStreams作候選清單，再捲到匹配卡片，保留實際入口與無archive断言。

唯一analyze整合入口7.2秒、exit1，無error／warning、3既有info（19:8 unnecessary_import；2080:34／2109:26 prefer_collection_literals）。上限調整後僅第二次編譯驗證，未重跑analyze。只改測試，沒有修改正式播放器、UI、協議、偏好或憑證；沒有記錄私有追隨名稱，只輸出index與archive布林。

### 短回看長測門檻與返回直播解碼

整合測試修正固定>45秒門檻，改為進度增量>設定觀察時長的75%，120秒需>90秒；觀察至少10秒，必須實際取得控制列baseline及lag取樣，防空取樣當穩定。新增每秒進度差<100ms的連續停滯計數，要求最長不超過3次且結束非緩衝；這是秒級取樣，不排除短暫卡頓。返回live不只檢查playing，還需非緩衝且位置前進，再觀察10秒增量>7秒、非緩衝。

FOLLOWING_ENTRY／LIMITED_REPLAY／120秒真實回歸編譯34.4秒、測試2分37秒、exit0。追隨第一卡／直播／chat／短回看解碼通過；120秒增122183ms、longestStallSeconds=0、maxLagDriftMs=0，落差12106ms，控制列高度／上緣差均0。返回直播解碼及10秒持續播放新增斷言均通過。hasArchive=true仍不代表無VOD頻道；20秒窗口幾何、更多頻道與間歇初始黑畫面未覆蓋。

唯一analyze整合入口6.3秒、exit1，無error／warning、3既有info（19:8 unnecessary_import；2046:34／2075:26 prefer_collection_literals），未重跑。limited replay build P95=13748us、30幀逾33.333ms，raster P95=7677us、1幀逾門檻；debug樣本不宣稱零卡頓。只改測試，未動正式播放器、憑證、協議或偏好。

### 追隨第一台短回看兩分鐘觀察

Windows真實App以FOLLOWING_ENTRY／LIMITED_REPLAY／LIMITED_REPLAY_SECONDS=120執行，編譯34.0秒、測試2分27秒、exit0。已登入初始首頁、實際點第一張追隨直播卡、相符直播路由、唯讀聊天室及直播15秒前進通過。hasArchive=true，但runtime確實進入usingLiveBufferReplay並解碼；不能以這個樣本宣稱無VOD頻道已測。

近直播端往前10秒開短回看後，120秒進度增加121733ms；每10秒取樣playing=true／buffering=false，canonical與live edge落差維持12173ms，控制列最大高度差／上緣差均0.0。返回直播狀態通過，但此分支沒有返回後10秒持續解碼斷言。Slider約0.99727至0.99734，此台有完整archive，不將比例当成20秒窗口的幾何證據。沒有重現先前時間漂移／控制列抖動，不判定所有頻道問題修好。

現有整合斷言的總增量門檻固定>45秒，即使觀察延長120秒也未隨時長調整；本次实际增量超過120秒，但下一輪須將門檻按觀察時長比例化，並補無archive與返回直播持續前進的證據。limited replay build P95=7230us／raster P95=7090us，build仍6幀逾33.333ms，debug樣本不排除一般卡頓。本輪未修改正式程式／測試或真實偏好／憑證，未跑analyze。

### 完整 DVR 實際時間軸拖曳

整合測試新增DVR_DRAG旗標，於原45秒恢復播放後，實際找到控制列內可命中的時間軸Slider，送按下／移動／放開事件。要求完整DVR無20秒seek window、比例移到0.1至0.4範圍、放開後新播放來源、解析目標距拖曳預覽<2秒、解碼及10秒增量>7秒／非緩衝；保留最後返回直播10秒要求，不直接呼叫seek取代手勢。

首輪编譯36.0秒、測試1分15秒、exit1，於live初始解碼進度60秒不前進而超時，尚未進入DVR拖曳，不判定拖曳失敗。失敗點補原生數值／布林屬性、proxy狀態與上游清單固定標記的去敏診斷，總逾時各5秒，錯誤只輸出類型並保留原測試失敗；不新增本機串流GET客戶端或改正式播放器。

第二輪編譯34.0秒、測試1分49秒、exit0：live／唯讀chat／DVR解碼、45秒增45566ms通過；实际拖曳比例0.30、預覽目標5055213ms，新來源解析誤差<2秒、解碼／10秒持續與返回直播10秒均通過。初始解碼成功所以未觸發新增失敗診斷，仍缺黑畫面當下的廣告／proxy證據，首輪間歇失敗未定位。此為單一fMP4完整DVR與Flutter合成手勢，不涵蓋VOD／clip／20秒limited replay或所有頻道。

唯一analyze在新增失敗診斷之前執行，7.0秒、exit1，無error／warning、3項既有info：19:8 unnecessary_import、2046:34／2075:26 prefer_collection_literals。新增診斷後以第二輪編譯與整合執行驗證，沒有再跑analyze。正式程式與憑證／偏好未修改。

### 最新完整 DVR 真實回歸

Windows App以FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR執行，編譯34.4秒、測試4分44秒、exit0。保留既有登入且唯讀聊天室連線，直播15秒前進、取得正在增長的回放、DVR解碼皆通過。此樣本初始化分段fMP4、1125bytes；後續分段使用map，沒有記錄播放網址或憑證。

原暫停恢復45秒增加45550ms；實際UI暫停、左鍵建立新來源且保持暫停／位置穩定，snapshot與解析目標均8151439ms，再由UI恢復並持續10秒通過。播放中左右鍵均建立新generation、解析目標誤差<2秒，各持續解碼10秒；1/3與2/3跳轉透過正式方法，各重新解碼並持續10秒，不冒充時間軸拖曳手勢。

120秒長測每10秒取樣playing=true／buffering=false，總進度增加121650ms，超過原90秒增量門檻；返回直播後10秒位置繼續前進，完整測試通過。extended build P95=13363us／raster P95=3050us，build仍8幀超過33.333ms；debug整合樣本不是profile或前背景A/B，不宣稱零卡頓。沒有重現clip→live黑畫面，也未測新的DVR格式、指定多頻道、真實断網或逐幀跳轉精度。本輪正式程式／測試未改，僅更新紀錄，未跑analyze。

### 共用登入狀態通知與晚到驗證

session測試新增3項，使用fake auth公開changeToken發出真實ChangeNotifier通知，不只直接改欄位再讀getter。兩項在驗證等待中模擬登出：listener立即收到guest、snapshot清空，舊驗證晚到成功／401失敗均回傳null，不再通知或改回身分。第三項已驗證first帳號切second時，listener先收到checking與null snapshot，驗證完成才收到authenticated及新snapshot，再登出立即收到guest／null。沒有存取或修改真實token儲存。

session檔26項，與正式聊天面板旗標及聊天離頁生命週期三檔聯合34項通過、2秒、exit0。前輪docs測試的mock偏好用途warning已補局部ignore及測試用途說明，沒有全檔抑制；唯一analyze兩個改動測試入口6.5秒、exit0、No issues found。這仍是服務通知與面板旗標各自的隔離證據，不冒充完整watch路由共用通知、IRC換帳號重連或快捷入口測試；正式程式未改，黑畫面仍未定位。

### 聊天面板登入旗標與不重建狀態切換

既有聊天鍵盤測試擴充checking／guest／authenticated／sending四情境，正式TwitchWatchChatPanel使用同一fake runtime與假送出／登入回呼，故不連真實IRC或發言。刻意保留與旗標矛盾的舊viewer欄位：guest不顯示composer且只有點登入才觸發回呼；checking有停用composer、不叫登入且點送出零回呼；authenticated實際點送出一次；sending顯示等待且不送出。

authenticated案例再以相同runtime／composer更新旗標為checking→guest→authenticated，每步斷言同一TwitchWatchChatPanel State未重建、提示／送出可用性立即更新，checking點送出不增加次數、guest轉入不自動叫登入、再次authenticated能送出。這驗證正式面板接收旗標後的反應，不等於共用session自動通知、完整watch路由、真實登出或快捷入口已驗證。

中途sending使用pumpAndSettle等待無限載入動畫而逾時（11通過、1失敗）；改為250ms有界pump，不改正式動畫／權限邏輯。與登入生命週期、訪客測試聯合12項通過、2秒、exit0。唯一analyze測試檔6.6秒、exit1，無error、1項warning：51:25 invalid_use_of_visible_for_testing_member（docs內測試使用SharedPreferences.setMockInitialValues）；本輪保留警告、不重跑，下一輪依測試用途處理局部註記。正式程式未改，真實憑證與偏好未動。

### 畫質選單不可切換時仍可選

新增正式 QualityButton 與 TwitchQualityOverlayMenu 的6項隔離 widget 測試。修正前5項通過、1項失敗：QualityButton 的 onChanged=null 時，實際展開的非空 PopupMenuItem 仍 enabled=true，選項看似可選卻沒有切換回呼。正式修正僅將非空選項 enabled 與 onChanged 是否存在連動，不更改播放器、畫質來源、儲存偏好或控制列排版。

修正後與既有控制列排版測試聯合19項通過、5秒、exit0。新案例以實際點擊驗證可用選项精確回傳 low 物件、不可用項停用且零回呼、空清單占位停用、overlay 忙碌／已選項不送出、關閉仍可操作，以及240×180窄矮視窗可捲至純音訊並選取且無overflow。既有時間軸點擊／拖曳與毛玻璃測試亦通過；全部為假資料，不建立原生播放器或網路連線。唯一 analyze 正式按鈕與新測試2.9秒、exit0、No issues found。真實直播／VOD／剪輯畫質切換、失敗恢復與偏好保存仍需補整合證據，黑畫面原因未因本修正判定。

### 聊天登入驗證晚到與離頁生命週期

隔離測試重現正式 connectChat 問題：驗證仍等待時釋放控制器，隨後驗證失敗，finally 的 notifyListeners 對已釋放控制器操作，將原 StateError 蓋成 FlutterError。修正前測試 exit1；正式 controller 增加 disposed 防護，於各等待點檢查、離頁後不續建聊天室或通知，清理時也不通知舊頁面。未改 token 儲存、IRC 發送協議或播放器 runtime。

新增兩項測試涵蓋驗證晚到成功／失敗：不呼叫 viewer callback、不建立 runtime、不通知已釋放控制器，失敗保留原 StateError，釋放後再次 connect 無作用。與既有聊天鍵盤／訪客測試聯合10項通過、3秒、exit0；全部使用隔離 auth 與假依賴，不建立真實 IRC。唯一 analyze 正式 controller 與新測試5.6秒、exit1，無 error／warning，1項 info（測試85:33 unnecessary_underscores），未重跑。這不等於所有登入轉換、並行 connect 或黑畫面已修復。

### 訪客與驗證等待中的探索頁面

discovery session 隔離測試新增4項實際頁面案例，使用正式 DiscoveryService／ViewerSession 與 BrowsePage／FollowingPage，只有 token 取得、validation 與 HTTP／匿名 GQL 回應為假資料。訪客與驗證 future 未完成兩種情境，瀏覽頁均完成公開載入、讀到 public_fixture 卡片資料、無登入要求／無 Helix 請求／無登入 callback；不只是空清單成功。追隨頁驗證等待時 checking、無資料請求或登入要求，驗證完成後 authenticated 才讀資料；訪客追隨頁不驗 token、不發資料請求，只有實際點「用 WebView 登入」按鈕才觸發假登入 callback，不開授權視窗。

中途測試誤用不存在的 validating enum 導致編譯失敗，已對照正式 checking 修正。匿名 fixture 從空清單強化為卡片資料時，原服務測試仍期待空清單而失敗，已改為精確 public_fixture 身分斷言；沒有修改正式程式或放寬驗證等待條件。四檔（session、guest mode、guest media、following page）最新聯合回歸59項通過、2項跳過、4秒、exit0；跳過兩項是 TWITCH_GUEST_LIVE_TEST 未開啟的真實匿名 API 測試，不當作成功。session 檔由19增為23项。本輪唯一 analyze 測試入口6.5秒、exit0、No issues found；強化 fixture 之後僅以最新編譯／聯合測試驗證，未重跑 analyze。未登出真實帳號或改 token 儲存，完整 App 初始首頁／直播聊天室／快捷入口矩陣仍待補。

### 私訊收件匣隔離回歸

訊息尾端與歷史同步測試單獨重跑仍在原633行找不到 Scrollable，exit1。假 threads 完整分頁只含 peer 3，而選中對話是 peer 2；正式 sync 完整列舉後 reconcileThreadsSnapshot 移除不在官方清單且未受草稿／晚到訊息保護的舊快取，清空 activePeerId，故無訊息列表。這是捲動測試前提不成立，不更改既定同步清理規則。

僅在 _FakeThreads 新增預設 false 的 includeActivePeer，尾端測試設 true，讓 fake 完整清單包含 peer 2；其餘案例不變。新增選中 peer 與訊息列表存在斷言，原零像素起始、零程式捲動、最新訊息可見、歷史同步保持像素與更新次數全部保留；單項回歸通過。尚未儲存狀態桌面1000×760／手機390×844兩項單獨通過，未修改正式狀態排版。

完整 inbox 測試171項兩次皆通過，各20秒、exit0，不重複累加。包含收件匣分頁、mock 送出／失敗、草稿／帳號隔離、恢復／取消、通知假事件、歷史捲動及多尺寸鍵盤等既有案例；所有資料與平台通道均隔離，未讀寫真實私訊。先前間歇桌面10px溢位及cache清理計時器本輪未重現，保留未定位，不因兩次成功宣稱修復。唯一 analyze 測試入口4.8秒、exit0、No issues found。

### 設定頁背景收件繪製警告與鍵位保存

既有 App 聊天鍵位設定測試重新執行，exit1：框架回報 ListTile 被有背景色的 DecoratedBox 遮住，背景與水波紋可能不可見。測試原本兩種尺寸皆使用預設 Android 模擬，因此警告來源為初始帳號頁的背景收件 SwitchListTile，不是聊天鍵位選單或 Windows 專屬區塊。

背景收件開關增加局部透明 Material，不改排版、顏色、控制器或背景服務。測試明確以 Windows 900×700、Android 320×640 驗證首頁例外為空及背景收件可見性，再切聊天、捲動鍵位選單、選 H，核對正式 controller 與 mock storage 保存。中途平台 override 只在 addTearDown 還原，觸發框架 invariant 失敗；已補 finally 在測試本體結束前還原。最終單一 widget 測試包含兩平台尺寸，全通過、exit0。未建立真實播放器、未操作原生背景開关或實際偏好。唯一 analyze 元件與測試兩入口5.3秒、exit0、No issues found。

### 播放網址首尾空白身分比對

playback session state 原14項測試重新執行，13項通過、1項失敗、exit1。mini.show 接受帶首尾空白的非空 URI 並保留 playback snapshot，但 isActiveMediaUri 只 trim 輸入而未 trim entry，導致同網址被判為不同來源。

正式修正僅讓身分比較兩側都 trim，不覆寫 snapshot、不移除 query 或改播放器 runtime。新增 live／liveDvr／VOD／clip 四項回歸，確認保留相同 snapshot、兩側空白可匹配，generation query 不同／query 缺失／空白／null 不匹配；修正後18項全通過、exit0，測試執行未建立 native Player。本輪唯一 analyze 正式controller與測試入口4.1秒、exit0、No issues found。黑畫面／廣告與原生開片競態仍未判定修復。

### 受控恢復重疊與新直播黑畫面

- 廣告診斷續測兩次：Windows 真實 App 以 MEDIA_MINI／MINI_RECOVERY_SWITCH／CONTROLLED_RECOVERY／REQUIRE_RECOVERY_OVERLAP／MINI_CLIP_FIRST 啟動，編譯34.5／34.8秒、測試28／27秒，皆exit0。剪輯解碼、Home縮小後前進、新首頁直播卡掛載與解碼通過；兩輪 pendingAtClick／pendingAtMount／pendingAtNewOwner 均true，舊恢復在新直播解碼後才放行，來源保持且再10秒前進>7秒，recovery errorType=none。這是兩個受控pre-open重疊成功樣本，沒有重現先前90秒黑畫面，不判定間歇問題修好。
- 兩次成功樣本清單均 HTTP200、HLS=true、variantMayHaveAds=false、stitched-ad=false、DATERANGE=true、DISCONTINUITY=false、SCTE35=false；不能據此排除黑畫面時的廣告，也不把DATERANGE當廣告。沒有新增串流讀取客戶端：正式router的stream端點只保留最新客戶端，額外GET可能中斷原生播放器，故不使用這種探測方式。未更動正式播放行為或測試程式；本輪僅更新紀錄，未執行analyze。
- 廣告假設續測：未加清單探測的本轮編譯34.9秒、測試27秒、exit0；其後加入唯讀 upstream 清單探測，編譯34.2秒、測試27秒、exit0。成功解碼後 HTTP 200、HLS=true，variantMayHaveAds=false，stitched-ad=false、DATERANGE=true、DISCONTINUITY=false、SCTE35=false。這只是成功樣本，DATERANGE 本身不等於廣告，亦不能由 marker 缺席排除未標記廣告。尚未取得黑畫面當下的相同清單證據，不判定廣告為原因。
- 清單探測只輸出狀態與固定標記布林，不保存正文、播放網址或憑證；卡住時每10秒至多一個探測，5秒總逾時，finally等待並關閉獨立client。未修改正式播放器或廣告處理行為。本輪唯一 analyze 6.8秒、exit1，無 error／warning，3 info（19:8 unnecessary_import、2045:34／2074:26 prefer_collection_literals）。
- 後續去敏診斷：clip→另一直播 nix 再次黑畫面，編譯34.5秒、測試1分45秒、exit1。90秒仍 buffering／position=0；proxy 與 inner 持續運作，writer=true、clients=1，playlistVersion 23→260、writtenSequence 7033→7068、outputDuration 8→78秒，runtimeError=false。native log 關鍵字累計 error=2、failed=7，尚不能判定具體错误。代理內部分段輸出前進不等於 native 已收到或成功解碼，下一步檢查快取、影像參數及錯誤分類。
- 補 native 數值／布林屬性白名單及錯誤關鍵字後，同條件第二輪編譯34.4秒、測試27秒、exit0；clip、mini、新直播解碼，放行舊恢復後來源保留、再10秒前進，三個 pending 觀察點皆 true。10秒內已解碼所以未觸發延遲診斷。此為間歇成功，不將黑畫面標記修復，也未更動正式播放邏輯。
- 同條件第三輪編譯34.4秒、測試28秒、exit0，再次通過解碼及放行後10秒前進；未觸發延遲診斷。本輪合計一失敗、兩成功，尚未取得失敗時的新增 native 屬性，因此保留黑畫面待定位。
- 本輪唯一 analyze 整合入口7秒、exit1：無 error／warning，3 info（18:8 unnecessary_import、1957:34／1986:26 prefer_collection_literals）；後補診斷僅由第二輪實際編譯驗證。
- mini recovery 增加可選 beforeOpenForTesting 等待點；等待完成後先檢查 entry／session 是否仍相同，再進入 native open。正常呼叫沒有新增等待；此防護不代表 native open 內部的所有競態已處理。
- 46776：VOD→mini→等待中的舊恢復→另一直播，編譯33.2秒、測試28秒、exit0。pendingAtClick／pendingAtMount／pendingAtNewOwner 全為 true；新來源已解碼後才放行舊恢復，新來源與 proxy upstream 保持一致且再前進10秒。證明受控 pre-open 重疊，非真實 OS 斷網。
- 86544：新增 clip-first 使用相同重疊條件，編譯33.0秒、測試1分46秒、exit1。clip 與 mini 解碼、前進均通過；新直播 mounted 後90秒 playing=true、buffering=true、position=0，miniActive=false、ownerMatches=true、uriChanged=true，使用者同時看到黑畫面。此時舊恢復仍停在 pre-open 等待點，尚未開舊來源，因此不能將本次黑畫面歸因於舊恢復搶回播放。
- 新直播持續緩衝的根因未確認，需區分上游分段、代理輸出與 native 解碼；不因 VOD 前輪通過而標記 clip→live 通過。失敗後測試 finally 放行等待點，失效 entry 防護返回，runner 結束。
- 唯一 analyze 兩入口5.7秒、exit1：無 error／warning，3 info（整合18:8 unnecessary_import、1923:34／1952:26 prefer_collection_literals）。clip-first 追加後以實際編譯驗證，未再次 analyze。

### 新來源接手時清除舊迷你播放器

新watch非reuse來源改在post-frame清除仍相同的舊mini entry，避免建構期通知其他widget；mini recovery完成後確認entry與session仍是原先物件，避免對已失效的來源繼續seek。沒有改底層播放器runtime或登入憑證。

- 修正前兩輪整合皆在selected source門檻逾時（1分46秒／1分45秒、exit1）；去敏狀態每10秒顯示新live playing=true、buffering=false、position前進、ownerMatches=true、uriChanged=true，但miniActive=true。這是舊mini状态未清，不是新live沒有解碼。
- 同步init關閉的中途版本（編譯32.6秒、測試1分45秒、exit1）捕捉建構期setState例外：mini.close通知overlay與其他listener時新watch仍在build，mini虽退出但新source90秒buffering／position0。已改post-frame，原因與中途失敗保留，不宣稱buffering全部原因已排除。
- 最新post-frame回歸編譯32.6秒、測試29秒、exit0：VOD→mini→啟動恢復→點首頁另一live，新watch與原頻道不同、mini退出、新source真實解碼、owner／URI／proxy upstream匹配、10秒前進>7秒，沒有再出現建構期例外。
- pendingAtClick=true、pendingAtMount=false、pendingAtNewOwner=false；因此本輪只證明來源替換，沒有新owner與舊recovery重疊證據。新增TWITCH_READONLY_REQUIRE_RECOVERY_OVERLAP可強制重疊斷言；普通模式會明確輸出unavailable: recovery overlap not reached。測試只完成VOD→live後return，clip→新來源與真正OS斷網仍未驗證。
- 唯一analyze三入口5.8秒、exit1：無error／warning，4 info（整合18:8 unnecessary_import，1901:34／1930:26 prefer_collection_literals，watch549:11 curly_braces）。post-frame追加後未重跑analyze，另有最新整合編譯／執行通過。

### 正式問題修正與回歸

最新直播路由回歸（FOLLOWING_ENTRY／LIVE_ROUTES／RAIL_SWITCH）：編譯32.8秒、執行1分17秒、exit0。影片touch／mouse及footer mouse皆movedPixels=50.00／returnPixels=0.00，failedSamples=0；與修正前影片0px同範圍比較，支持外層統一手勢修正有效。拖動後mini前進、點影片展開fresh watch／chat、Home／close／pause、首頁別台與追隨欄換台、新來源／owner／proxy／chat一致、各15秒持續前進及選中再點不重開皆通過。三窗口各12次側欄位置取樣穩定；屬Flutter合成事件與單一桌面樣本，不宣稱所有平台或實體滑鼠已驗證。

使用者要求測出問題就修，流程改為定位、正式修正、回歸、再繼續。保留原安全界線；既有歷史失敗不刪除，最新修正結果以本段為準。

- browse刷新時阻止新loadMore並清舊loadingMore；舊loadMore每次await及錯誤回應校验refresh generation，不能污染新資料／錯誤。來源替換重讀；分類初始失敗retry改loadGames，語言ListTile補Material。媒體庫分頁ID去重、來源／頻道替換清資料並generation防晚到、矮視窗clamp改合法0下限。更新下載回調、完成後installer及finally皆避開disposed。
- 三檔既有測試共52項全通過兩次；最新4秒、exit0（不重複计數）：browse21、media22、update9。覆蓋先前固定失敗與原有正常路徑，不執行真實installer。
- mini entry新增playOnOpen，watch Home以原生playing傳入；mini初始化以該flag開片，已ready的回前景恢復保留當下playing。影片IgnorePointer避免內層手勢競爭，外層opaque保留整片點擊／pan，沒有改樣式或播放器底層runtime。
- 首次真實PAUSED回歸18秒exit1，VOD暫停保留通過，但發現TwitchWatchRelationshipController was used after being disposed。去敏stack：change_notifier.dart:414:27、twitch_watch_relationship_controller.dart:137:7、twitch_watch_page_relationship.dart:12:7、twitch_watch_page_startup.dart:446:5。具體原因為頁面離開後fetchRelationship future完成仍notifyListeners。新增disposed／generation防護於refresh、toggle、reset；晚到結果不改狀態、快取或callback。8項fake成功／失敗×dispose／reset×query／follow測試6秒全通過。
- 第二次PAUSED回歸19秒exit1，VOD暫停保留及手動play進度通過，測試找不到忽略hit-test的內層AspectRatio；正式外層補opaque，測試改從影片中心tapAt，避免用內層.hitTestable識別已交給外層的事件。
- 最新PAUSED回歸編譯32.8秒、執行34秒、exit0，VOD／clip實際pause→Home→mini保持paused，2秒位移<500ms；手動native play後mini前進3秒、影片中心點擊展開、原片／kind／URI／位置接續、再3秒前進、Home／close／pause完整通過。未測維持paused直接展開，也不以短樣本宣稱所有回前景／網路情境完成。
- 唯一analyze七個入口7秒、exit1，無error／warning，3 info（18:8 unnecessary_import、1886:34／1915:26 prefer_collection_literals，皆整合檔）；後加relationship與opaque修正以編譯／測試驗證，不再analyze。
- 之前中斷的恢復換來源測試僅有runner temporary listener PathNotFoundException與exit1，未取得有效App判定，保留待重驗，不推斷來源搶回故障。

### 後續32999／81264：受控恢復future與close重疊通過

- 新增TWITCH_READONLY_MINI_RECOVERY_CLOSE，與MEDIA_MINI=true執行；沒有開MINI_PAUSED或MINI_RECOVERY的前輪序列，僅新的close競態分支。VOD與clip先真實解碼、Home轉mini、3秒位置前進，記錄原本playing後直接啟動正式recoverAfterNetworkRestored，不await即透過Flutter tap正式close按鈕。捕捉recoveryError只保留類型，並斷言null；未吞掉錯誤算成功。
- 32999編譯37.9秒、執行28秒、exit0，兩媒體pendingAtClick=true，future完成後3秒miniActive=false、playing=false且playableState=null。但此紀錄只在送點击前，測試補強而不以其冒充close生效時仍有競態。
- 加controller listener，在entry被正式close清空的同步notifyListeners內記錄wasPendingAtClose，finally移除listener。81264編譯38.4秒、執行27秒、exit0；VOD與clip皆pendingAtClick=true、pendingAtClose=true、recoveryErrorType=none、miniActive=false、playing=false，playableState=null。close後future完成、再3秒沒有復播；本輪有真正future重疊證據，但沒有精确native內部open／seek進度或任意延遲排序保證。
- 控制入口與真實native重新開片，不切OS網路、未做帳號寫入或改正式runtime／UI／偏好／憑證。此分支continue到下一媒體，沒有再展開；恢復中換來源、真正斷網、disposed間歇例外及clip初始decode逾時仍待定位，不用本輪綠燈覆盖。
- 唯一analyze7.2秒、exit1，無error／warning，3 info（18:8 unnecessary_import；1758:34／1787:26 prefer_collection_literals）。close通知觀察器為其後追加，只有81264編譯／執行驗證，不重跑analyze。

### 後續31644／74584：clip恢復可通過，但有間歇disposed例外

- 使用與29147相同的MEDIA_MINI／MINI_PAUSED／MINI_RECOVERY三旗標，第一輪31644編譯40.1秒、執行31秒、exit1。VOD完整通過；clip此次route source成功解碼，實際UI暫停後Home到mini再次自動playing，與VOD同現行行為。paused mini受控恢復維持暫停，playing mini forceOpen恢復同URI、位置差<10秒、3秒前進皆通過。
- 隨後出現framework exception type=FlutterError flags=disposed phase=mini-clip-entry；當時沒有輸出物件類型／來源行號，不能歸因哪個controller。clip下一段mini位置前進／展開／close未執行，整體仍失敗。29147初始解碼逾時本轮未重現，也不當成已修復。
- 只追加exception handler去敏診斷：從標準used-after-disposed文案擷取類型名，stack僅擷取最多16個dart檔名／行號／欄位，沒有打印原始訊息、URI、私訊或憑證。正式runtime／UI未改。第二輪74584編譯38.6秒、執行36秒、exit0，兩媒體完整通過，無disposed例外，因此尚未取得精確原因。
- 74584新clip證據包括：source與mini真實解碼、paused source縮小自動播放（觀察而非暫停保留通過）、paused recovery不自動play／位移<500ms；playing loss記錄→native pause→正式恢復forceOpen，同來源／位置差<10秒、3秒前進>1秒，後續再3秒mini前進、點mini展開成新watch、原clip／kind／URI／位置接續及3秒前進，Home後close使player不再playing。
- 保留前輪及本輪失敗，不用單次exit0覆蓋間歇disposed或decode逾時。這些是正常網路下控制器受控恢復與native重新開片，不是真OS斷網或通知路由接線；未涵蓋recovery中關閉／換來源競態。
- 本輪唯一analyze8.1秒、exit1，無error／warning；3 info（18:8 unnecessary_import，1693:34／1722:26 prefer_collection_literals）。後加exception診斷未再次analyze，由第二輪實際編譯／執行驗證。

### 後續29147：暫停handoff／受控恢復，clip初始解碼失敗

- Windows三旗標TWITCH_READONLY_MEDIA_MINI／TWITCH_READONLY_MINI_PAUSED／TWITCH_READONLY_MINI_RECOVERY皆true。編譯38.5秒、測試1分55秒、exit1；保留同一App直到90秒decode逾時，不因等待重啟或切斷電腦網路。
- VOD source實際點控制列pause，native playing=false後Home到mini；mini自動playing並解碼。此為現行行為觀察，不當成「保留暫停」需求通過；mini正式openOrResume的play:true與結果相符，未修正式行為。
- VOD mini中native pause→rememberNetworkLoss→recoverAfterNetworkRestored，1秒後仍paused且位置變化<500ms；再play，記錄原本playing→pause→recover，正式forceOpen重開同URI，解碼恢復、位置差<10秒且再3秒前進>1秒。其後mini展開、原片／kind／URI／位置接回、3秒前進與再次Home／close／pause全部通過。
- 這是控制器受控入口與真實native播放／開片證據；沒有製造真實OS斷網、401／503，也沒有測到網路事件廣播的接線或恢復競態。clip route mounted後90秒未達playing && !buffering && position>0，failed: clip mini source decodes；clip暫停、handoff、恢復皆未執行。92522前輪clip通過不追認本輪成功；可能來源／native切換／恢復後殘留狀態原因皆未證實。
- 失敗後僅在測試追加每10秒playerPresent／playing／buffering／positionMs／durationMs去敏診斷，不輸出URL或error原文；尚未再編譯／執行，不當作原因證據。
- 唯一analyze7.6秒、exit1，無error／warning；3 info（18:8 unnecessary_import、1685:34／1714:26 prefer_collection_literals）。後追加診斷未重跑analyze。未改正式功能、帳號憑證或偏好。

### 後續92522：VOD／clip mini 真實完整通過

- 補上twitch_watch_playback_state.dart extension import，執行flutter test integration_test/twitch_readonly_app_test.dart -d windows --dart-define=TWITCH_READONLY_MEDIA_MINI=true --reporter expanded。編譯44.5秒，測試27秒，All tests passed／exit0；同一App依序VOD、clip，沒有帳號寫入、登出、憑證或正式功能修改。
- 既有登入首頁追隨斷言、切公開browse與搜尋選樣本頻道通過。讀20筆VOD選非growing archive、30筆clip選40秒以上；透過正式TwitchWatchRouteGuard直入，未從媒體卡點入，不替代卡片接線證據。
- VOD及clip各自真實source解碼、Home回首頁並dispose舊watch、mini entry保存kind／media URI／原VOD或clip ID；mini不緩衝且playing、3秒位置前進>1秒。點mini影片展開，新watch保留原片ID、mini退出、相同media URI與kind，接回位置與mini末次位置差<10秒，再觀察3秒前進>1秒。第二次Home再close，mini消失且shared player不再playing；兩種類所有斷言皆執行。
- 本輪只有各一個短樣本，沒有暫停handoff、原生斷網、播放到結尾、完整DVR、keep-mini=false或長時間連續播放。FrameTiming有輸出但不以27秒路由樣本宣稱profile效能或卡頓已解決。影片區drag前輪失敗仍待定位。
- 唯一analyze：8.5秒、exit1，無error／warning；3 info（18:8 unnecessary_import；1616:34／1645:26 prefer_collection_literals）。未重跑，整合編譯成功另列為執行證據。

### 後續準備：VOD／clip mini（未執行）

- 新增 TWITCH_READONLY_MEDIA_MINI 與 exerciseMediaMiniRoutes，預計依既有公開搜尋選定頻道，同一App讀20筆VOD／30筆clip，選非growing archive及40秒以上clip。以正式TwitchWatchRouteGuard直入，控制列Home接mini，檢查kind／來源ID／URI、3秒解碼前進、展開接回相同來源、位置差<10秒及再3秒前進、第二次Home後close／pause。未改正式UI／runtime、偏好或憑證；不以直入證明媒體卡接線。
- 本輪唯一analyze有2 error：517:25及560:21 buildPlaybackSnapshot undefined_method。正式方法存在於lib/features/twitch/presentation/pages/watch/twitch_watch_playback_state.dart，整合檔尚未引入該extension；另外2 info為prefer_collection_literals（1615:34、1644:26）。8.6秒、exit1。依每輪限制未反覆修到成功，也未啟動必然編譯失敗的App測試。
- 本段是測試準備與靜態失敗證據，沒有新增真實VOD／clip mini通過項。下一輪補extension import後再編譯／執行，保留前輪影片區拖動兩失敗。

### 後續74797：影片區與資訊列對照

- 擴充同一正式App整合，影片區touch／mouse及資訊列mouse各從可命中目標中心開始；先(-20,-15)、再(-40,-30)，事件timestamp為100／200ms，finally在400ms送up；各段pump100／200ms，up後pump200ms。測試暫存拖動失敗名稱，在完整路由結束才斷言，沒有刪除失敗或把後半通過算成整體成功。
- 編譯54.9秒，實際測試1分23秒、exit1。影片touch位移0.00、mouse位移0.00，放開後距原點0.00；資訊列mouse位移50.00、回位距原點0.00。證據將問題收窄到影片區事件路徑；正式外層GestureDetector的onPanUpdate包住影片與footer，但尚未識別是哪個內層recognizer攔截，也不聲稱已驗原生實體滑鼠。
- 手勢後mini位置再前進3秒、影片點擊展開、fresh watch／fresh chat／same media、返回首頁與close／pause通過。第二頻道metadata／session owner／不同upstream／proxy binding匹配，解碼後15秒前進；追隨欄30個不同候選，點選替換watch、舊chat斷線新chat接上、新來源owner匹配、選中Semantics且再點不重開，再15秒播放皆通過。restored／second／rail三個窗口各12次100ms側欄位置取樣穩定。
- 整體末尾失敗在dragFailures包含video-touch、video-mouse的斷言（當時435行），後半本輪已實際執行，與前兩輪未到後半不同。無帳號寫入、無正式UI／runtime修改。這次沒有開60秒performance flag，不能新增60秒效能結論。
- 本輪唯一analyze無error／warning、2 info：prefer_collection_literals（1452:34／1481:26），12秒、exit1。保持未完成項：keep-mini=false、DVR／VOD／clip原生接回、原生網路恢復、完整頁面登入／訪客及其他矩陣範圍。

- 使用者授權必要檔案範圍；只擴充整合測試與紀錄，不更動正式功能或登入憑證。操作全部是 Flutter 合成事件，未使用系統滑鼠或真實帳號寫入。
- 第一輪 37032：编譯 59.1 秒、測試 1 分 33 秒，exit 1。登入後預設追隨、第一卡對應頻道、聊天連線、15 秒播放通過；60 秒期間點控制列六次，播放前進 62,450 ms，1 秒取樣無停滯／緩衝。live-observation build P95=11,017 us、70 幀 >33.333 ms，最大 81,078 us；raster P95=10,979 us、無 >33.333 ms。debug 單次樣本不是 profile、FPS 或前背景 A/B，不能排除全部卡頓。
- 返回首頁後原 watch 已 dispose、舊 chat 斷線、mini metadata／media identity、解碼與 3 秒位置前進皆通過。新增影片中央 startGesture、moveBy(-40,-30) 後，位移 >10 斷言失敗（當時143行），後續回位／展開／跨頻道未執行。
- 第二輪 79854：補 moveBy(-20,-15) 與100 ms pump，先跨越 Flutter pan slop，再移動(-40,-30)；只重跑追隨／live routes／rail switch，不重跑60秒觀察。編譯53.8秒、測試31秒，exit1；仍在位移斷言失敗（146行）。沒有額外精確位移輸出，不能寫成位移為零；門檻假說尚未證實。下一批須確認影片區 hit-test／pan handler 與 footer 拖動是否不同，再決定是正式互動問題或測試事件路徑。
- 兩輪測試結束皆由 integration runner 結束 App，不操作清 cookie、登出或強制終止既有使用者 App。既有路由整合成功證據保留，但不替代這兩輪未執行的後半流程。
- 唯一 flutter analyze：無 error／warning；2 info，prefer_collection_literals，當時 integration_test/twitch_readonly_app_test.dart:1415:34、1444:26，14.8秒、exit1。之後追加手勢三行未重跑 analyze，僅有整合編譯／執行證據。

## 已驗證

| 項目 | 結果與證據 |
| --- | --- |
| Windows debug 啟動 | 編譯成功；VioClass 視窗正常顯示 |
| 現有 App 登入 | 帳號設定顯示完整登入；不是僅憑瀏覽器 cookie 推測 |
| 登入後預設首頁 | 修正自動導頁後，debug 重啟顯示「追隨中的直播」，清單載入成功 |
| 手動切到瀏覽 | 公開直播、標籤篩選欄及頭像顯示正常 |
| 瀏覽重新整理 | 重新檢查登入與資料後仍留在「探索直播」，未覆蓋手動選擇 |
| ES LCS 直播 | 影片與持續更新的聊天室成功載入 |
| 聊天登入判定 | 觀察時未顯示訪客登入提示；顯示頻道追隨時間限制，未測試送出訊息 |
| 快退快捷鍵 | 左方向鍵觸發快退約 10 秒，影片隨後恢復播放；未出現登入要求 |
| 完整 DVR | KSPKSP 時間軸由約 2:31 拖回約 59:52；較早的影片畫面與 VOD 聊天回放成功載入，並非只驗證 20 秒緩衝；持續播放曾卡住，另見下方修正與驗證限制 |

## 尚待驗證與注意事項

- 此次觀察 ES LCS 時播放控制顯示約 20 秒短回放視窗，不能把它當成已驗證完整場次 DVR。
- debug 出現直接 DVR 來源 HTTP 400 後採短緩衝路徑的紀錄；須區分錄影清單、完整錄影橋接與直接 DVR 來源，不先認定是登入問題。
- 曾出現 media_kit 視訊平台訊息錯誤前綴，輸出被截斷，原因尚未確認；本次只修改已授權的 DVR HTTP 轉送，不修改 media_kit 插件。
- 尚待測試公開錄影／剪輯 UI、另一個有完整 DVR 的頻道、返回直播、搜尋與頻道切換。
- 本機目前有登入；不以清除 cookie／撤銷登入來製造訪客。訪客端先用既有匿名接口與自動測試，實際 UI 未覆蓋部分另列。
- 管理快捷鍵僅檢查原有權限防護，未觸發實際寫入操作。

## DVR 卡住：已重現並修正的本機轉送問題

- 實機 debug 顯示分段 HTTP 200 與 first-byte，之後同一串流 generation/client 出現 `TimeoutException`，不能視為未登入或取得錄影失敗。
- 原本 `_writeSegment` 對本機播放器的 `response.flush()` 設定 1 秒 timeout。播放器暫停讀取或緩衝已滿時，正常的下游背壓也會觸發逾時；錯誤最後導致 HTTP 回放串流關閉。
- 使用者明確授權修正後，移除固定一秒的下游輸出期限，改成可取消的等待。跳轉、重新連線、停止及關閉時取消舊等待，避免舊讀取者占住上游連線。
- `twitch_dvr_backpressure_diagnostic_test.dart` 已從重現問題的診斷測試改成四項回歸測試：慢讀取者超過兩秒後恢復讀取、跳轉、同版本重新連線及停止。前三項驗證完整 16 MiB 分段傳送，停止項驗證限時關閉。
- 四項回歸測試通過；使用 loopback 合成資料，不讀取帳號或播放簽名。不將這些測試當成真實 Twitch／media_kit 長時間播放的證明。
- 直接 DVR 來源 HTTP 400 與 archive health 更新問題是另一路徑的訊號，不以它取代已證實的本機轉送逾時原因。
- 先前 debug 程序正常退出；2026-10-11 接續測試時重新確認該程序已退出且沒有 VioClass 程序，才依目標重新啟動 Flutter debug。

## 不操作滑鼠的接續測試（2026-10-11）

- 依使用者要求，不再操作螢幕、滑鼠或鍵盤；改以 Flutter 自動測試與 debug 紀錄進行。
- 新增真實匿名瀏覽、分頁、頻道搜尋、直播資訊與熱門分類測試。每個請求檢查沒有 `Authorization`，不存取既有 cookie／token。
- 真實搜尋包含 papaplatte；直播資訊以剛取得的公開直播頻道查詢，允許兩次請求間下播，不宣稱它證明影片持續播放。
- UI 搜尋、媒體庫播放、DVR 返回直播及修正後實際長時間播放仍未完成驗證；保留在目標中，不因自動測試通過而標成完成。
- `flutter run -d windows --no-pub` 編譯與同步成功，程序確認仍在執行且 Responding=True；這只證明啟動，不證明頁面載入或播放。未透過螢幕確認本輪 App 畫面。

## 本輪測試

- 訪客模式、匿名公開媒體／頭像真實接口、登入快取及聊天室管理／鍵盤測試共 39 項通過。
- 管理寫入使用假的 API，未對 Twitch 帳號執行管理操作。
- 本輪重跑上述 39 項加 DVR 四項回歸，共 43 項全部通過。
- 補上真實匿名瀏覽／搜尋後，公開媒體測試檔五項全部通過（其中四項與上述重疊）；本輪累計 44 個不同測試通過。

## 靜態檢查

- 前一回合 `flutter analyze --no-pub lib/features/twitch` 結果：0 errors、0 warnings、6 infos。
- 本回合僅執行一次 analyze，包含 Twitch 範圍與本次兩份測試檔：0 errors、0 warnings、10 infos；exit code 1，未重新執行。
- 提示位置：DVR 測試第 99 行、DVR proxy 第 526／534／552 行、OAuth 頁第 381 行、首頁片段第 358 行、觀看頁第 529 行、預測下注頁第 434 行、私訊登入服務第 204 行為缺少大括號；hype train banner 第 2 行為冗餘 import。下一輪僅處理本次相關格式，不順手修改無關檔案。
- 已登入預設追隨修正只涉及首頁導頁，不更改 OAuth/token 儲存。

## 接續：登入驗證競態修正（2026-10-11）

- 新增測試重現：第一個帳號驗證尚未回應，第二個帳號先成功驗證；第一個帳號稍後回傳 401 時，原程式會清掉第二個帳號的快取。修正前該測試失敗（預期保留新 snapshot，實際為 null）。
- 修正 `resolveViewerAuthOrNull`：401／403 僅在請求 token 仍等於目前帳號 token 時清除驗證與追隨 rail 快取；舊帳號請求不再影響新帳號。未改 OAuth/token 儲存。
- 登入狀態測試共七項通過：登出清快取、登出後晚到成功、瀏覽不等待驗證、換帳號後晚到拒絕、換帳號後晚到成功、目前帳號拒絕清快取、503 保留帳號但回報錯誤。全部使用假帳號，不操作真實登入。
- DVR 四項背壓回歸重跑通過；整理本次 DVR 程式與測試缺少大括號的格式。
- 本接續回合 analyze 僅一次：0 errors、0 warnings、6 infos，exit code 1。剩餘提示在 OAuth 頁 381、首頁片段 358、觀看頁 529、預測下注頁 434、私訊登入服務 204（大括號）與 hype train banner 2（冗餘 import），未順手修改無關項目。
- 現有 Flutter debug handle 經確認仍在執行。未操作滑鼠，未把没有新播放紀錄當成播放器正常的證明。
- 全 App 無滑鼠整合測試入口待確認：需讀取範圍外 `lib/main.dart`（啟動與測試掛接方式）及 `pubspec.yaml`（既有 Flutter 測試依賴）。依 AGENTS.md 尚未讀取，先回報取得範圍確認；此項仍未完成。

## 接續：進直播時側欄跳動（2026-10-11）

- 使用者允許讀取所需檔案後，已確認 `lib/main.dart`、`lib/app.dart` 與 `pubspec.yaml`：現有依賴只有 flutter_test，尚未建立全 App 整合測試入口。本次未新增依賴或修改啟動程式。
- 使用者隨後回報進直播時左側欄先收起再出現，優先處理此問題。
- 程式證據：觀看頁用 `authPending = loadingAuth || chatController.connectingChat` 關閉側欄；即使已有經驗證的首頁登入快取，第一幀仍沒有側欄，聊天室連線完成後才加入 60 px 側欄，造成內容位移。
- 修正：僅當首頁快取身分仍與首頁目前 token 相符時，在觀看頁重新驗證期間預留側欄空間；預留不啟動追隨查詢。完成驗證後沿用相同空間；聊天室重新連線不再關閉側欄。真正訪客與全螢幕仍不保留側欄。
- 純 Flutter widget 測試驗證等待／完成期間內容左邊界均為 60 px，等待期間無追隨查詢，真正訪客切回 0 px；側欄共 13 項測試全部通過。只使用測試內的虛擬手勢，不操作系統滑鼠。
- 此測試證明側欄元件的版面與查詢控制，不宣稱已實機重現並驗證完整直播路由。
- 登入狀態目前分散於各功能；此輪僅解耦側欄與聊天室連線判定，未將整套登入邏輯重構為集中式狀態服務。
- 本次 analyze 一次：0 errors、2 warnings、6 infos，exit code 1。warnings 為側欄測試第 84／108 行既有測試段落的冗餘 `!`；infos 為上輪列出的六項格式提示。依限制不反覆修改／analyze，下一輪再處理相關提示。

## 接續：集中式登入狀態（2026-10-11）

- 依使用者「改好」要求新增 `TwitchViewerSession`：每個帳號服務共用一個記憶體身分狀態，集中 checking／guest／authenticated、驗證快取、同時驗證合併與 token 世代防護；不更動 OAuth/token 儲存或刷新邏輯。
- 首頁與 discovery、觀看頁啟動及聊天室接入改用此服務。從首頁進直播時共用原帳號服務，避免新建帳號服務造成登入初始狀態歸零；觀看頁監聽共用身分並同步 viewer 欄位。
- 驗證待完成時不顯示訪客登入判定；401／403 由共用服務判成 guest（即使磁碟仍有 token），暫時性服務錯誤不當成登出，登出／換帳號立即使舊身分失效。
- 觀看頁側欄用共用已驗證身分決定顯示，不再等聊天室連線。聊天室送出入口額外要求共用身分與目前連線的 token 相符，避免登出／換帳號後使用舊連線送出；未改 IRC 協議或特殊訊息 payload。
- 測試新增同時呼叫只驗證一次、跨消費者共用 snapshot、登出即時清身分及被拒 token 的一致訪客判定。連同匿名真實查詢、鍵盤／管理假 API、側欄及 DVR 回歸共 63 項全部通過。
- 本輪 analyze 僅一次：0 errors、0 warnings、6 infos（既有六項格式提示，首頁位置移至 378、觀看頁移至 544），exit code 1；未反覆執行。
- 測試未操作系統滑鼠、未對帳號發言／追隨／訂閱／管理。全 App 無滑鼠整合與實際 DVR 持續播放仍待驗證，不以這些測試標記整個長篇目標完成。

## 接續：補齊入口並啟動（2026-10-11）

- 聊天面板與其 adapter 接收共用狀態的訪客／可發言判定，不再從缺少 viewerId 推測未登入；保留獨立元件的舊建構參數相容性，正式觀看頁明確傳入共用判定。
- 管理功能與快捷鍵的 API 入口新增目前已驗證身分／聊天室連線一致性門檻，避免登出後仍沿用舊 runtime 的 moderator 標記。
- 聯合登入頁的主帳號狀態檢查與 chat-only loader 改用共用驗證；Web GQL／Drops 的獨立權限憑證驗證維持原協議，不誤當成主帳號登入旗標。
- 新增兩項聊天面板測試：驗證中的共用狀態即使本地 viewerId 為空也不顯示訪客提示；共用訪客狀態即使保留舊 viewerId 仍顯示唯讀。連同登入／側欄／訪客／鍵盤管理／DVR，本輪共 60 項通過；未重跑上輪五項公開媒體查詢，故不將其算入本輪。
- 本輪 analyze 一次：0 errors、1 warning、6 infos，exit code 1。warning 在 docs/twitch_watch_chat_keyboard_test.dart:48，是 docs 內測試使用 SharedPreferences 測試方法的 visible-for-testing 提示；下一輪可比照同檔既有測試添加限定說明，未反覆修改／analyze。
- 確認原 App 程序已不存在後，用 Flutter 啟動更新版；未操作系統滑鼠或登入對話框。
- Windows debug 編譯成功（22.9 秒）、同步成功，App 程序仍執行且 Responding=True。未透過螢幕確認頁面，不把啟動成功當成實際 DVR 長時間播放驗證。

## 接續：不占用系統滑鼠的 App 內點擊（2026-10-11）

- 新增 Flutter SDK integration_test 開發依賴及 `integration_test/twitch_readonly_app_test.dart`。只增加六項 SDK 測試傳遞依賴，未升級既有套件。
- 第一版整合測試已通過既有登入、預設追隨、搜尋、直播聊天室與直播播放時間持續前進 15 秒。
- 後續完整 DVR 測試曾在跳轉成功後失敗；當時的 debugPrint 白名單未保留完整例外，因此不能僅憑失敗結果宣稱凍結的最終原因。完整 DVR 暫停恢復／返回直播仍未通過驗證。
- 使用者回報 App 卡頓後檢查本機 Flutter binding 原始碼，確認預設 live-test 畫面政策限制非 pump 畫面更新；改成 fullyLive，避免長等待造成測試畫面停更。這是測試環境修正，不是已證明一般 App 卡頓皆已排除。
- 本次按使用者「送點擊」要求，改成 tester.tap 實際命中瀏覽按鈕、清除搜尋及畫面上可見直播卡片，不只直接呼叫導頁 callback。搜尋透過 Flutter 測試文字輸入；不使用系統滑鼠／桌面座標事件。
- 修正後整合測試成功（29 秒）：三項點擊成功送達、既有帳號驗證、搜尋結果、直播頁、聊天室連線、直播播放時間持續前進 15 秒；退出碼 0。
- 完整 DVR 測試保留為 `TWITCH_READONLY_FULL_DVR=true` 的獨立選項，不將本次點擊測試成功當成 DVR 長測成功。
- 本回合 analyze 僅一次，針對整合測試檔：No issues found，退出碼 0。未重新宣稱整個 Twitch 範圍先前六項 info 已消失。

## 接續：完整功能長期目標第一批（2026-10-11）

- 建立 `twitch-functional-test-matrix.md`，區分真實整合、假的 API、部分覆蓋與待測；長期目標保持進行中。
- 點數授權三項、聯合登入四項、通知政策 17 項，共 24 項模擬測試通過。聯合登入 fixture 原本只有 getValidAccessToken 回傳假 token，補上相符的 accessToken，未改正式登入邏輯或放寬斷言。
- fullyLive 真實整合重現 DVR 卡住：登入、預設追隨、瀏覽／清除搜尋點擊、搜尋、直播路由、聊天室與直播時間前進皆成功；DVR 跳轉後上游 HTTP 200、首批資料已收到，但恢復播放後 45 秒增量 0，playing=true、buffering=true。整合退出碼 1，返回直播部分未執行。
- 補首輪 flush 起訖的去敏診斷，僅保留世代、client、byte 數與耗時；不列網址、憑證或私訊內容。測試新增 DVR 實際解碼／非緩衝門檻，避免在尚未播放時就測暫停。
- 本回合 analyze 僅一次，整合與聯合登入兩份測試 No issues found（7.2 秒），退出碼 0；新增診斷後不再 analyze，不宣稱全 repo 無提示。
- 補診斷後第二次 Windows DVR 整合：HTTP 200，首批 24,637 bytes 的 flush 在 792 ms 完成；等待 60 秒後仍未開始可前進的非緩衝回放，在測試暫停之前即退出碼 1。首輪 flush 未卡住；後續轉送／解碼狀態仍需更細分診斷，未據此宣稱已確定最終原因。
- DVR 本機四項慢速消費者回歸重跑全部通過（8 秒）；本批 28 項模擬／本機回歸通過，兩次真實 DVR 整合失敗。
- 測試後重新開啟一般 Windows debug App：編譯 23.4 秒、同步 118 ms，程序 Responding=True；未把啟動與程序回應當成 DVR 修好或所有功能通過。

## 接續：DVR 資料轉送定位（2026-10-11）

- 開始時重新確認一般 debug session 4453 仍活著；該 handle stdin 已關閉，定向核對本輪啟動的 App PID 25044 後停止該程序以進行整合測試，未因觀察逾時猜測 App 已結束。
- 增加每 10 秒的 bytes／waitingForFlush 診斷，離開 segment 時取消 timer。標準 DVR 實測：262,144 bytes 後持續 waitingForFlush=true，等待 60 秒仍無法開始非緩衝播放，退出碼 1。
- 使用獨立診斷選項省略播放器開檔初始 seek，但沿用同一 DVR 來源；約 250,247 bytes 後同樣等待 flush，60 秒門檻失敗，退出碼 1。不把此對照當成正式 DVR 覆蓋，也未據此修改正式跳轉精度。
- 定向檢查目前鎖定的 media_kit 套件原始碼，確認原生 log 與固定 getProperty 接口；新增測試內數值／布林狀態及警告關鍵字輸出，不印原始 native 訊息、媒體 URL 或憑證。
- 播放完整性 mock 測試 19 項全部通過，其中一項只是服務編譯接線；其餘涵蓋播放授權、匿名 fallback、受限拒絕、帳號隔離與失效競態，不當成播放器真實播放驗證。
- 本回合 analyze 一次：DVR proxy 與整合測試 No issues found（7.2 秒），退出碼 0。其後加入測試內診斷對照／原生狀態紀錄，不再 analyze，交由整合編譯驗證。
- 原生狀態診斷的標準重跑編譯成功：DVR 首批資料後產生 error／failed 類警告，固定 property idle-active=yes 持續出現；資料轉送約 251,271 bytes 後仍等待 flush。原生播放器已閒置，Flutter state.playing=true 的舊旗標不能證明 DVR 開檔成功。解碼開始門檻仍未達成；後續需細分警告來源與開檔失敗類型，未宣稱最終根因已確認。
- 該標準重跑 60 秒解碼門檻失敗，退出碼 1。進一步擴充固定警告關鍵字／來源分類已保存，但尚未跑到此擴充版，不視為新驗證證據。
- 測試後一般 Windows debug App 重新編譯 23.7 秒、同步 126 ms，PID 27936、Responding=True；採可互動 handle 38389 保留給後續測試前正常關閉。長期目標仍進行中。

## 接續：前景對照與媒體格式（2026-10-11）

- 重新核對 handle 38389 活著後透過 q 正常結束 App，退出碼 0；不強制關閉其他程序。
- 原生警告來源細分重跑：ffmpeg error、lavf failed／format／open、cplayer failed／format，DVR 60 秒仍未开始解碼，退出碼 1。指向媒體格式開啟階段，而不是僅 UI 少繪製幀。
- 使用者提出背景假說並同意留在前景對照，之後回報「好像沒差」。該次重跑同樣失敗：HTTP 200、首批資料 format=unknown、ffmpeg error／header、lavf failed／format／open／input；原生 idle-active=yes。binding.lifecycleState 為 null（輸出 unknown），因此不能用此欄位宣稱 OS 前景狀態已由測試確認，前景觀察僅引用使用者回報。
- 定向檢查觀看頁 lifecycle：Windows inactive 不暫停播放器，hidden／paused 只停止時間軸時鐘，恢復路徑明確不重新載入 Windows 播放。此為程式證據，不排除作業系統或原生播放器其他背景影響。
- 增加去敏格式辨識（188-byte TS sync、fMP4 box、gzip、ID3）及 hasMap／compressed 布林診斷，未輸出媒體原始 bytes 或改傳輸行為。首 chunk 片段不足仍可能 unknown，因此 unknown 不單獨證明非 TS。
- 本回合 analyze 一次：DVR proxy 與整合測試 No issues found（7.9 秒），退出碼 0；其後擴充格式診斷不重新 analyze，透過下一次整合編譯驗證。
- 新診斷確認真實分段 hasMap=true、compressed=false。程式檢查發現 parser 保留 EXT-X-MAP，但 sequential pump 完全沒讀取 map；修正為每個 client／seek 都先送初始化來源，同一 map 不重複送、map 變更時先送新初始化再送分段。未更改 Twitch 授權、簽章或 hash。
- 新增 `twitch_dvr_initialization_test.dart` 三項 loopback 合成資料測試：首次、重連、跳轉；每項都驗證 map 在分段之前、同 map 不重複、map 變更重新送、client／seek 不沿用舊初始化狀態。連同原四項背壓測試共七項通過，退出碼 0；只證明資料轉送順序，不冒充原生解碼驗證。
- 修正後第一次真實重跑在直播播放時間 15 秒斷言失敗，尚未執行 DVR；未把此結果算成 DVR 修正失敗。測試補上直播位置先前進的 60 秒有界等待，仍保留開始後 15 秒持續觀察。
- 修正後第二次真實 Windows 完整 DVR 整合通過（1 分 36 秒，退出碼 0）：先送出 fMP4 初始化 1,125 bytes，成功解碼，原生 idle-active=no／paused-for-cache=no，緩衝 100%；暫停 10 秒後恢復，45 秒位置增量 45,516 ms，playing=true、buffering=false，跨多個實際分段；返回直播後觀察 10 秒位置繼續前進。
- 與修正前同類 hasMap 來源 header／format 開啟失敗對照，支持本次卡住由漏送 fMP4 初始化資料造成；並非僅背景幀更新。前景仍只有使用者觀察、binding unknown；不宣稱完成所有 OS 背景組合。
- 本批已修正且驗證一個真實 DVR 流程；重複跳轉、跨頻道、其他媒體格式及長期矩陣尚未完整，目標保持進行中。修正後未再 analyze，七項本機測試與 Windows 整合編譯／執行成功提供本批驗證。
- 測試後一般 debug App 已重開：編譯 24.4 秒、同步 125 ms，PID 38212、Responding=True，互動 handle 58715。未使用系統滑鼠，未更改帳號或 token 儲存。

## 接續：重複跳轉與設定測試（2026-10-11）

- 重新核對 handle 58715 活著，透過 q 正常結束後啟動延伸 DVR 測試；未操作系統滑鼠或真實帳號寫入。
- 新增獨立 extended DVR 選項：原流程通過後依次跳至時間軸 1/3、2/3，各自等待實際位置前進並觀察 10 秒；再觀察 120 秒、要求增量 >90 秒，最後返回直播。仍保留原本暫停恢復與 45 秒斷言；沒有用較短測試取代完整要求。
- 音訊設定十項 mock 與聊天室鍵位五項 widget 測試共 15 項通過，退出碼 0。設定使用假 read/write 或 mocked SharedPreferences，不覆寫使用者偏好；音效使用 fake output，不宣稱已確認原生聽感。
- 本回合 analyze 一次：DVR proxy、整合測試及初始化回歸三檔 No issues found（7.3 秒），退出碼 0。
- 同輪新增整合測試 FrameTiming 記錄：分 home／live／dvr／return-live 取 build 與 raster 中較大耗時，輸出樣本數、95 百分位微秒及 >33.333 ms 數量；僅測試診斷，不修改正式 UI。此增加在 analyze 之後，不重跑 analyze；當時正在執行的延伸 DVR 使用較早編譯版，沒有此輪 frame 證據，須後續重跑。
- 真實延伸 DVR 全部通過（4 分 4 秒、退出碼 0）：原 45 秒恢復增量 45,600 ms；1/3／2/3 兩次跳轉重新取得初始化，各自解碼並觀察 10 秒持續前進；其後 120 秒增量 121,715 ms；返回直播後再觀察 10 秒持續前進。測試未檢驗精確 seek 目標誤差，不把會動當成所有跳轉精度已通過。
- 新增 FrameTiming 後一般 App 點擊整合編譯與執行通過（29 秒、退出碼 0）：首頁、瀏覽／清除／直播卡片合成點擊、搜尋、聊天室及直播前進 15 秒。home 樣本 558 幀、P95 9,399 us、>33.333 ms 9 幀；live 樣本 1,398 幀、P95 27,464 us、>33.333 ms 38 幀。量測為每幀 build/raster 較大值，並非完整呈現延遲或實際 FPS；不能用此 debug／integration 樣本宣稱正式版效能或卡頓皆已排除。
- 確認測試程序已結束、沒有 VioClass 程序後重新開啟一般 debug App：編譯 19.7 秒、同步 111 ms，PID 34492、Responding=True，互動 handle 52413。目標仍進行中。

## 接續：媒體庫、VOD、剪輯與耗時拆分（2026-10-11）

- 開始重新確認 handle 52413 活著，之後以 q 正常結束；未操作系統滑鼠。
- 加入獨立 media library 流程，從首頁搜尋資料建立頻道 sheet，透過 tester.tap 真正點擊 VOD／剪輯卡片及分頁；不建立剪輯、不開私人寫入。
- 首兩輪在 VOD 空清單停下，沒有 API 錯誤，未到播放階段；不是 VOD 播放失敗，也未標通過。發現搜尋首個結果不保證名稱完全相符，測試鎖定確切的公開樣本頻道後清單 20 筆、無錯誤。
- 真實 media library 流程通過（41 秒，退出碼 0）：VOD 開始解碼、10 秒前進 >7 秒、seek 到 30 秒、暫停 3 秒後恢復前進、返回媒體庫；剪輯開始解碼、10 秒前進 >7 秒、返回；關於分頁載入無錯誤。驗證初始模型 ID 與已點擊卡片一致、VOD-only 模式。seek 直接呼叫播放器，不冒充拖曳 UI 驗證；sheet 直接打開，不冒充入口按鈕點擊。
- 新增 build/raster 分開量測：VOD 1,416 幀 P95 build=9,055 us／raster=3,510 us；clip 1,096 幀 P95 build=5,916 us／raster=7,883 us；library 114 幀 P95 build=8,821 us／raster=13,069 us。樣本包含開頁及過渡、Windows debug／integration，不能當成所有頻道或正式版性能證明。
- 內嵌瀏覽器設定四項 mock 測試通過（退出碼 0），不開啟原生登入 WebView；含 Android UA／viewport、iOS desktop mode、Windows 保留原本 UA 與 unrelated settings。未手動讀取任何平台資料夾。
- 本回合 analyze 一次：整合測試 No issues found（6.9 秒），退出碼 0。其後補去敏清單數量及確切樣本選擇，不重新 analyze；真實整合編譯與執行通過。
- 同版一般點擊／直播整合再通過（29 秒、退出碼 0）：live 1,370 幀 P95 build=24,769 us／raster=3,682 us，build >33.333 ms 32 幀、raster 0 幀；home 536 幀 P95 build=6,777 us／raster=7,731 us。這批直播慢幀主要在建構端，下一步應定向查頁面更新／重建；樣本不能單獨判定特定元件、持續 FPS 或正式版根因。
- 測試後一般 Windows debug App 重開：編譯 19.4 秒、同步 113 ms，PID 3312、Responding=True，互動 handle 27984；目標持續進行。

## 接續：媒體搜尋恢復與更新來源（2026-10-11）

- 核對 handle 27984 活著後 q 正常結束。沒有改正式 UI、偏好或播放器 runtime。
- 媒體庫整合新增對 VOD／剪輯搜尋框送入不可能命中的字串、確認空結果圖示、實際點擊清空按鈕，確認搜尋框清空且卡片恢復。保留 VOD／剪輯播放、seek／暫停恢復及返回／關於原流程；全部通過（45 秒、退出碼 0）。
- 定向程式檢查：時間軸 Timer 每 250 ms notifyListeners，觀看頁將該 controller 接到 notifyControllerChanged → setState。加上 preferences／chat／engagement／relationship／playback／timeline／vod-chat 通知計數，僅記錄固定來源名稱及次數，不記訊息內容；頻率與慢幀相關性需實測，還沒有因果 A/B 證明。
- 本回合 analyze 一次：整合測試 No issues found（6.9 秒），退出碼 0。
- 一般直播通知計數整合通過（33 秒、退出碼 0）：preferences 0、chat 7、engagement 6、relationship 2、playback 2、timeline 89、vod-chat 0。時間軸為本樣本最頻繁的已量測整頁更新來源；Timer 的 shouldTick 實際限制為 liveDvr 模式，不能把它說成所有純 live 模式都固定 4 Hz。
- 同次 live 1,728 幀 P95 build=24,471 us／raster=3,725 us；build >33.333 ms 33 幀、raster 0 幀。頻率與程式接線支持優先查時間軸整頁更新，但尚無隔離 A/B，不宣稱單一根因或一般 App 效能已修好。
- 測試後一般 debug App 重開：編譯 19.9 秒、同步 137 ms，PID 40132、Responding=True，互動 handle 14328。長期目標持續進行。

## 接續：分頁局部驗證與卡頓線索（2026-10-11）

- 一般 debug handle 14328 正常結束後進行媒體庫分頁整合。首次測試因載入更多按鈕尚未在可見清單建立而失敗；加入清單內合成捲動後重跑，不操作系統滑鼠。
- 第二次真實測試確認 VOD 載入更多由 20 筆增至 31 筆，原有 ID 前綴保留、沒有重複 ID、載入無錯誤。後續要點擊的第一張卡片已捲出懶載入範圍，title matches=0，因此整體退出碼 1；只有 VOD 分頁局部通過，剪輯分頁及該次後續播放尚未驗證，不能標整體通過。
- 本回合 analyze 一次：整合測試 No issues found（7.0 秒）。後續補捲動不再 analyze，由第二次 Windows 整合編譯成功驗證編譯層級，執行仍有上述測試定位問題。
- 使用者回報留前景「好像沒差」，不以背景狀態解釋所有卡頓。前一輪 timeline 89 次通知與整頁 setState 接線是效能排查線索，尚無隔離 A/B 因果證據。
- 定向檢查發現跳轉按鈕已有局部 AnimatedBuilder，但 TwitchVodPlaybackStrip 目前只訂閱播放器 position／duration／playing 串流、直接讀 timelineController，沒有獨立時間軸監聽。不能直接移除觀看頁全域時間軸 listener，以免進度條更新退化；本輪未修改正式 UI 或播放器行為。下一步需先確認所有時間軸消費端，再設計局部更新與回歸對照。
- 測試後一般 Windows debug App 已重新開啟：編譯 19.1 秒、同步 112 ms，PID 2816、Responding=True，互動 handle 62205；僅確認啟動及程序回應，不宣稱使用者感受到的卡頓已修正。長期目標保持進行中。

## 接續：時間軸局部更新（2026-10-11）

- 重新核對 handle 62205 活著後正常 q 結束，退出碼 0。定向檢查時間軸消費端：快捷跳轉讀 snapshot；底部控制列依 player 串流配置 controller；進度條直接讀 controller，仍需時間軸通知刷新。
- 正式修改限兩檔：觀看頁不再把 timeline 通知接整頁 setState；播放器區域既有 AnimatedBuilder 合併 timeline 監聽，每次重新取得 runtime canonical duration，保留 stableVideoStage child。進度條與按鈕仍依原流程更新，不改畫面樣式、時間軸 runtime、登入或 Twitch 協議。
- 新增 docs/twitch_player_timeline_isolation_test.dart，兩項 live／liveDvr widget 測試通過（退出碼 0）：通知只刷新播放器區域、外層 Builder 不重建、影片 widget 同一實例、替換 controller 解舊監聽、離頁後 timeline/runtime 通知不再刷新。使用 fake runtime 且 player 為 null，只證明更新接線／生命週期，不冒充進度條顯示或真實解碼驗證。
- 修改後一般直播真實整合通過（29 秒，退出碼 0）：登入初始化／預設追隨、瀏覽／搜尋／清除／卡片點擊、唯讀聊天室、實際播放位置前進 15 秒。timeline 仍有 71 次通知，不以減少 controller 時鐘频率規避負載。
- 本批 live 1,526 幀 P95 build=13,267 us／raster=3,916 us；build >33.333 ms 19 幀，raster 0 幀。前批 live P95 build=24,471 us／raster=3,725 us。支持這個方向有改善跡象，但時段／頻道樣本不保證相同，不能當成嚴格因果 A/B、正式版性能或使用者卡頓已全解決。
- analyze 本回合僅一次，三檔退出碼 1（6.6 秒）：新測試第 96 行呼叫 protected notifyListeners 產生 invalid_use_of_visible_for_testing_member／invalid_use_of_protected_member 兩項 warning；播放器區域第 150 行 use_null_aware_elements 一項 info；觀看頁原有第 544 行 curly_braces_in_flow_control_structures 一項 info。沒有 error，但不能宣稱靜態檢查乾淨。遵守每回合不反覆修到成功，下一輪建議以 fake runtime 公開方法封裝通知、採 null-aware element 寫法；既有 unrelated 提示不順手改。
- 在 DVR 長測等待期間，定向確認私訊三檔使用 mock 剪貼簿、假的 history/threads 與記憶體 read/write；執行 selection／recovery／delete lifecycle 共 40 項全部通過（退出碼 0）。含選取跨換行／貼圖、恢復進度／配額／保存失敗／重複游標、換帳號晚到回應、排隊／讀取／已進入保存時取消刪除。未操作真實私訊、剪貼簿或帳號寫入。
- 修改後首次延伸 DVR 測試編譯成功，但在前置直播 60 秒實際位置前進門檻失敗（1 分 17 秒、退出碼 1），尚未到 DVR。不能算 DVR 回歸通過或 DVR 修改失敗；保留完整測試條件再重跑一次。同次 timeline 251 次通知，live P95 build=13,017 us／raster=4,073 us，不以畫面建構較快冒充直播解碼成功。
- 同版第二次完整延伸 DVR 通過（4 分 14 秒、退出碼 0）：直播前進門檻及 15 秒觀察成功；初始化 fMP4 1,125 bytes 先送出，DVR 開始解碼；暫停 10 秒恢復後 45 秒增量 45,549 ms；1/3／2/3 兩次跳轉重新解碼並各觀察 10 秒；其後 120 秒增量 121,500 ms；返回直播後再觀察 10 秒持續前進。此批證明局部更新沒有破壞該樣本長流程，不涵蓋所有頻道／格式或精確 seek 誤差。
- 同次 FrameTiming：live 2,267 幀 P95 build=10,336 us／raster=3,742 us；dvr 16,907 幀 build=6,053 us／raster=3,044 us；return-live 844 幀 build=9,085 us／raster=3,647 us。timeline 925 次通知、vod-chat 609 次通知；保留時間軸頻率及回放聊天室接線，未為通過測試關閉它們。數據為 debug／integration樣本，仍不當成正式版或全畫面零卡頓證明。
- 完整測試退出後一般 Windows debug App 重開：編譯 23.0 秒、同步 106 ms，PID 37940、Responding=True，互動 handle 97415。保留已登入狀態，未操作系統滑鼠；長期目標仍進行中，矩陣未完整通過。

## 接續：媒體分頁後定位與檢查提示（2026-10-11）

- 確認 handle 97415 活著後正常 q 結束，退出碼 0。沿用既有单一 integration_test/twitch_readonly_app_test.dart 授權，不掃描或讀寫其他範圍外檔案。
- 將 fake runtime 的 protected notifyListeners 呼叫封裝在公開測試方法 emitChange；播放器區域採 null-aware collection element，行為不變。未順手改觀看頁既有大括號提示。
- 媒體整合定位改為依 _VodCard.video.id／_ClipCard.clip.id 找指定卡片，分頁停在清單底部時向上合成捲動，待懶載入卡片建立後才點擊。不要用可能重複的標題或因尚未 mount 而失敗的查找取代指定卡片；仍驗證導頁初始模型 ID 一致。
- 加強分頁斷言：原有 ID 前綴保留、總數增加、全部 ID 去重後總數等於清單長度、無 API 錯誤。沒有移除或縮短既有 VOD／剪輯播放與暫停恢復斷言。
- 本回合 analyze 一次，測試隔離檔／播放器區域／整合測試三檔 No issues found（7.6 秒、退出碼 0）。範圍不含觀看頁既有提示，不宣稱全 repo 乾淨。
- 時間軸局部更新兩項 widget 回歸重新通過，退出碼 0；仍只是 fake runtime 接線／生命週期證據。
- 真實 Windows 媒體庫完整整合通過（50 秒、退出碼 0）：VOD 載入更多 20→31、剪輯 30→60，保留前綴且全部 ID 無重複；分頁後找到指定 ID 卡片且各只有一個匹配，合成點擊後初始模型 ID 一致。兩種媒體搜尋空結果／清空恢复、VOD／剪輯各 10 秒前進 >7 秒、VOD seek 30 秒／暫停 3 秒恢復、返回及關於分頁無錯誤均通過。sheet 入口仍直接呼叫，不冒充入口點擊；seek 仍直接呼叫 player，不冒充拖曳。
- 本批 P95 build／raster：library 458 幀 11,125／11,871 us；VOD 1,539 幀 8,529／7,726 us；clip 1,186 幀 5,234／7,376 us。僅 Windows debug／integration 樣本，不推算 FPS 或宣稱全頻道效能已驗證。
- 測試後一般 Windows debug App 重開：編譯 23.3 秒，PID 29252、Responding=True，互動 handle 91004。僅確認啟動，不當成所有功能完成；保留登入與使用者設定。下一批補實際媒體庫入口、跨頻道／路由切換與播放快捷鍵，矩陣和長期目標保持未完成。

## 接續：實際入口與播放快捷鍵（2026-10-11）

- 重新確認 handle 91004 活著後正常 q 結束，退出碼 0；只修改已允許的整合測試與 docs，未改正式 UI／播放器／登入行為。
- 新增獨立 TWITCH_READONLY_MEDIA_CONTROLS 選項，保留原媒體分頁／搜尋／播放流程。在已實際播放的 VOD 中，合成點擊播放器區域喚醒控制列並取得鍵盤焦點，點暫停按鈕、送左右方向鍵，然後點播放按鈕；不呼叫私人 key handler 或使用系統滑鼠／鍵盤。
- 真實 Windows 完整媒體流程通過（1 分 2 秒、退出碼 0）：暫停按鈕讓 playing=false，額外 2 秒觀察位置變化 <500 ms；snapshot.mode=vod 且 canSeek=true；左右方向鍵分別以當下 snapshot.position 減／加 10 秒，等待原生非緩衝位置距目標 <2 秒並保持暫停；播放按鈕恢復後實際位置再前進 >2 秒。此為有界跳轉誤差驗證，不宣稱逐幀精度或所有 DVR／剪輯模式通過。
- 同輪實際點擊 VOD 播放器的 ChannelLibraryButton：正確頻道、共用同一 authService、初始關於分頁；關於／VOD／剪輯各載入且無錯誤；點關閉圖示返回同一 watch state、原 VOD ID 不變，原生位置繼續前進 >2 秒。這次涵蓋 VOD 播放器入口，不把最初從首頁直接開 sheet 或直播入口一併算通過。
- 原有 VOD 20→31／剪輯 30→60 分頁、ID 去重／前綴保留、兩種搜尋清空、VOD／剪輯各 10 秒前進、VOD 30 秒 seek／暫停恢復、返回原媒體庫／關於讀取仍全部通過。
- 本回合 analyze 僅一次，整合測試 No issues found（6.9 秒、退出碼 0）；不宣稱全專案靜態檢查通過。
- 本批 P95 build／raster：VOD 2,293 幀 9,005／7,502 us（包含快捷鍵與巢狀媒體庫開關）；clip 1,127 幀 4,444／7,500 us；library 510 幀 9,405／11,116 us。debug／integration 樣本不等於正式版或全頻道效能。
- 測試後一般 Windows debug App 重開：編譯 19.3 秒、同步 112 ms，PID 39584、Responding=True，互動 handle 28652。未改登入或偏好、未操作系統滑鼠；下一批仍需跨頻道／路由恢復、剪輯／DVR 快捷鍵與焦點防護，長期目標保持進行中。

## 接續：輸入框防護與剪輯快捷鍵（2026-10-11）

- 核對 handle 28652 活著後正常 q 結束，退出碼 0。僅擴充既有已允許整合測試與 docs，不改正式頁面、登入、播放器或 Twitch 協議。
- VOD 暫停後真正點擊 _InlineTimeValue 進入時間 TextField，確認 focusNode.hasFocus；記錄原時間文字／原生位置／controller 位置但不輸出文字。送左右方向鍵、額外觀察 2 秒，要求文字不變、保持焦點及暫停、原生與時間軸位置變化均 <500 ms。再合成點擊影片中心，確認輸入框消失，原 ±10 秒快捷鍵及播放恢復測試繼續執行；不呼叫私人 handler、不讀寫聊天室草稿。
- 剪輯先自然播放到至少 12 秒內部位置，點暫停按鈕、確認 controller.mode=clip；左右方向鍵按當下 snapshot.position 減／加 10 秒，等待非緩衝原生位置距目標 <2 秒並保持暫停；點播放按鈕後原生位置再前進 >2 秒。不用直接 player.seek 冒充剪輯快捷鍵。
- 真實 Windows 完整媒體 controls 整合通過（1 分 8 秒、退出碼 0）：上述時間欄位防護、點外取消編輯、VOD／剪輯快捷鍵與按鈕全部通過；原有分頁／搜尋清空／播放／VOD seek／頻道入口與關閉／返回／關於讀取也保留且通過。焦點證據僅 VOD 時間欄位，不涵蓋聊天室、DVR 或所有編輯框；跳轉僅 <2 秒誤差，不宣稱逐幀精度。
- 本回合 analyze 一次，整合測試 No issues found（6.7 秒、退出碼 0），未重跑。
- 本批 P95 build／raster：VOD 2,462 幀 8,520／7,565 us；clip 1,611 幀 4,523／7,058 us；library 405 幀 9,328／11,609 us。僅 debug／integration 樣本，不推算 FPS 或當成全部卡頓已消失。
- 測試後一般 Windows debug App 重開：編譯 19.0 秒、同步 108 ms，PID 39028、Responding=True，互動 handle 22097；保留登入與偏好、不操作系統滑鼠。跨頻道／路由恢復、DVR 快捷鍵及其他矩陣仍待測，長期目標保持進行中。

## 接續：迷你播放器與跨頻道路由（2026-10-11）

- 核對 handle 22097 活著後正常 q 結束，退出碼 0。新增獨立 TWITCH_READONLY_LIVE_ROUTES 選項，只修改既有整合測試，不改播放器 runtime 或偏好。
- 新流程點觀看頁回首頁，依原 homeKeepsMiniPlayer 設定分支；確認原 watch 已離頁、舊 chat 斷線。若保留迷你播放器，驗證原頻道／播放快照、實際位置前進、點迷你影片展開、同頻道新聊天室、再回首頁點關閉及共享播放器暫停；不更改偏好以強行創造迷你播放器案例。
- 隨後從首頁實際點另一張不同頻道卡片，檢查頁面／runtime／聊天室頻道、共用登入、全域 playback owner 與原生來源一致；每次新 watch mount 後取 12 次 100 ms 側欄 child 的左邊位置，要求差異 <0.5 logical pixels。這只是 1.2 秒有界幾何觀察，不冒充 FPS／所有登入初始化狀態驗證。
- 前兩次整合退出碼 1（43 秒／57 秒），保留失敗：首頁、舊 chat 斷線、迷你持續播放／展開／關閉、重新接回、第二頻道 chat 與解碼門檻、兩次側欄取樣皆已執行；未到第二頻道 15 秒持續觀察。第二次去敏診斷確認 owned present／channelMatches／uriMatches 均 true，只有 sourceChanged=false。
- 定向程式檢查確認 TwitchStableHlsProxyRouter 的本機 URL／port 故意固定，_startProxyForVariant 透過 switchUpstream 更新 router、currentVariant 及 upstreamPlaylistUri。因此「原生本機 URL 必須不同」是測試錯誤判準，不據此修改正式播放器。第三次改驗證 immutable 首次 upstream 與第二次 upstream 不同、runtime 頻道正確、router 上游及 currentVariant URL 同時與 runtime upstream 一致，再保留 owner／原生 URI 接線及第二頻道 15 秒前進 >10 秒；沒有拿掉真實來源切換要求，也不印任何來源 URL。
- 本回合 analyze 僅一次：整合測試 No issues found（7.4 秒、退出碼 0）；其後只補診斷與符合 stable router 契約的斷言，不再 analyze，交由第三次 Windows 編譯／執行驗證。
- 第三次完整路由整合通過（59 秒、退出碼 0）：使用者原偏好 keep-mini=true，迷你分支全部執行；首頁／迷你持續前進／點影片展開／新 watch 同頻道 fresh chat／同本機來源前進／再回首頁點關閉暫停通過；首頁點不同頻道、runtime.channelLogin／chat／owner 一致、新 upstream 不同、router／variant 綁定吻合、第二頻道 15 秒前進 >10 秒通過。前兩次錯誤判準的失敗留存，不算正式 App bug 修復；本輪沒有改正式播放器。
- 迷你展開與第二頻道 mount 各 12 次有界取樣的側欄 child 左邊位置差異 <0.5 logical pixels；不代表驗證中／訪客全矩陣或每個初次開直播過渡均已確認。
- 本批 P95 build／raster：mini 312 幀 5,083／5,560 us；restored-live 428 幀 14,556／4,060 us；second-live 1,524 幀 14,634／3,183 us。控制器通知計數只涵蓋最初 watch，已離頁 controller 不代表後續 watch 更新頻率；不將兩者混用或推算 FPS。
- 測試後一般 Windows debug App 重開：編譯 18.9 秒、同步 107 ms，PID 39056、Responding=True，互動 handle 4364。未更改登入、偏好或播放器，未操作系統滑鼠。下一批補追隨欄直接切換與 DVR 快捷鍵；完整矩陣未完成，長期目標保持進行中。

## 接續：追隨欄直接切換（2026-10-11）

- 開始重新核對舊 handle 4364：已終止、退出碼 0 並報 Lost connection to device；指定舊 PID 39056 已不存在。無法據此確定是手動關窗或程序異常，不猜測；此次非觀察逾時後重啟，也未停止任何其他程序。
- 新增獨立 TWITCH_READONLY_RAIL_SWITCH 選項，延續原真實首頁／迷你／跨頻道路由流程。等追隨欄載入結束後找不同於當前頻道的項目，必要時在 App 內合成捲動，再實際點帶 live-rail key 的 InkWell。若沒有候選，明確 unavailable 並失敗，不能當成通過。
- 本批有 24 個不同候選、載入未失敗；僅記數量／布林，不保存或輸出追隨頻道名稱。實際點擊後確認新 watch／正確頻道、舊 watch 離頁與舊 chat 斷線、新 chat 實例與頻道正確、共用 authService；runtime／router／variant 綁定到不同上游，原生非緩衝解碼且 owner 頻道與原生播放 URI 一致。
- 選中項目的 Semantics.selected=true、onTap=null，實際再點保持同一 watch state，不重新導頁；再觀察 15 秒位置前進 >10 秒。新 route mount 後亦做 12 次 100 ms 側欄 child 左邊位置取樣，差異 <0.5 logical pixels。
- 真實 Windows 完整路由與追隨欄整合通過（1 分 20 秒、退出碼 0）；原首頁跨頻道、迷你展開／關閉及先前兩次幾何取樣仍全部執行並通過。僅此已登入樣本，不涵蓋驗證中／訪客、API 失效、hover 展開或所有格式。
- 本回合 analyze 一次：整合測試 No issues found（7.5 秒、退出碼 0）。沒有修改正式 UI、token、偏好、播放器 runtime 或 Twitch 協議。
- 本批 rail-live 1,652 幀 P95 build=7,254 us／raster=3,475 us，build >33.333 ms 5 幀、raster 0 幀。debug／integration 樣本不等於 profile 或正式版效能，原控制器計數仍只涵蓋第一個 watch，不冒充新頻道頻率。
- 測試後一般 Windows debug App 重開：編譯 19.2 秒、同步 107 ms，PID 35640、Responding=True，互動 handle 89437。一般 App 終端只顯示啟動／編譯／同步等白名單摘要，不轉印來源或私人資料。下一批 DVR 快捷鍵及其他矩陣仍待測，長期目標保持進行中。

## 接續：DVR 按鍵與管理模擬（2026-10-11）

- 重新核對 handle 89437 活著後正常 q 結束，退出碼 0。只擴充既有整合測試與 docs，不改正式功能或偏好。
- 定向檢查完整 DVR 契約：sequential proxy 每次 seek 增加 stream generation，播放 URL 的 v 跟著更新；runtime.liveDvrBridgeTimelinePosition 保存本次解析的 canonical target，而非持續播放時計；near-live localReplayRevision 不適用完整 archive DVR，因此不拿它當本次按鍵證據。
- 新增獨立 TWITCH_READONLY_DVR_CONTROLS 選項，在原暫停 10 秒／恢復跨分段 45 秒後，實際點播放器取得焦點再送左右鍵。每次目標為當下 snapshot.position 減／加 10 秒，要求新 URL v 大於舊版、解析目標差 <2 秒、seek action 已結束、仍使用完整 bridge 且原生 playing／非緩衝／position>0；之後各觀察 10 秒，位置須前進 >7 秒且不緩衝。保留原 1/3／2/3 重複跳轉、120 秒長測及返回直播要求，不縮短替代。
- 本回合 analyze 僅一次：整合測試 No issues found（7.2 秒、退出碼 0）。
- 真實 Windows 完整 DVR controls／extended 整合通過（4 分 27 秒、退出碼 0）：左右鍵新串流與解析目標門檻、各 10 秒持續播放、原暫停恢復／45 秒跨分段、1/3／2/3 重複跳轉全部保留並通過；120 秒觀察原生位置增加 120,433 ms，返回直播後再前進通過。
- 本批 live 1,472 幀 P95 build=14,971 us／raster=3,946 us，DVR 27,232 幀 P95 build=6,055 us／raster=3,318 us；DVR build >33.333 ms 27 幀、raster 3 幀。只代表此 debug／integration 樣本；使用者表示留前景似乎沒差，不能據此宣稱體感卡頓已修好，也不能將 binding lifecycle=unknown 當成 OS 前景證明。一般 App／相同來源的前背景效能對照仍待驗證。
- 測試後一般 Windows debug App 重開：編譯 21.4 秒、同步 126 ms，PID 37264、Responding=True，互動 handle 47635；只用 Flutter 合成操作，不操作系統滑鼠。程序有回應不等於畫面順暢；本批未新增正式功能修正，長期目標仍進行中。
- 定向檢查 AutoMod 設定與封鎖詞測試使用假的 Dio HttpClientAdapter、假的 token／API、widget test，沒有任何真實管理呼叫；兩檔共 16 項通過（退出碼 0）。涵蓋官方 query/body 的 mock 校驗、scope／帳號／頻道與 malformed response 拒絕、取消確認、七類自訂值保留、遠端快照變更防覆寫、失權阻擋、未知保存結果防重送、分頁去重／重複 cursor、讀取失敗與小螢幕大字體。此只算假的 API／頁面證據，不當成所有管理功能或真實操作通過。

## 接續：直播停滯與介面耗時同步觀察（2026-10-11）

- 上輪完整 DVR 真實測試為進展，不是卡頓已解決的證明。重新確認 handle 47635 活著，正常 q 結束退出碼 0，未停止其他程序。
- 僅新增 TWITCH_READONLY_LIVE_PERFORMANCE 測試選項：保留真實儲存登入／瀏覽／搜尋／卡片點擊／唯讀聊天室及原 15 秒播放要求，再額外觀察 60 次 1 秒 pump。同步記 Stopwatch 實際經過、播放增量、最長 pump、position 增量 <100 ms 的取樣數與最長連續次數、緩衝取樣數、build／raster 最大耗時、各 controller 每 10 秒更新次數；全部只輸出去敏數值／固定標籤，不讀寫聊天室草稿或帳號。
- 真實 Windows 整合通過（1 分 33 秒、退出碼 0）。60 秒觀察實際經過 60,435 ms、播放增加 60,433 ms，maxPumpMs=1,022、stalledSamples=0、longestStall=0、bufferingSamples=0；10,585 幀 P95 build=4,792 us／raster=3,624 us，max build=43,982 us／raster=8,607 us，build >33.333 ms 8 幀、raster 0 幀。pump 約一秒包含要求的一秒等待，不是點擊延遲或一秒卡頓。
- 各 10 秒 timeline 更新 40–41 次、engagement 合計 8 次，其他已列 controller 在此 60 秒窗口均為 0。低聊天更新樣本不能驗證高流量聊天效能；1 秒 position 取樣會漏短停頓，非同來源前背景 A/B 或 profile，不推算 FPS。binding lifecycle=unknown 仍不能證明 OS 前景。使用者留前景沒差的回饋保留，卡頓要求仍未排除，未猜測性修改正式 runtime。
- 播放授權／完整性既有測試定向重驗 19 項通過（其中一項只有編譯接線）；Dio request 全由 mock 攔截、validation／proof acquisition 注入假的回應，SharedPreferences 為記憶體 mock。涵蓋一次重試、再次拒絕停止、403 不誤啟 acquisition、普通匿名 fallback／受限拒絕、VOD／clip grants、帳號／client 隔離、過期／pending clear／晚到拒絕；不把這批當真實登入切換或網路恢復完成。
- 本回合 analyze 一次：整合測試 No issues found（7.6 秒、退出碼 0），未再跑第二次。未修改正式功能、登入儲存、協議或偏好。
- 一般 Windows debug App 已重開，編譯 20.6 秒、同步 114 ms，PID 30496、Responding=True、互動 handle 9868。下一批需高流量聊天與實際互動時的效能窗口，以及矩陣其餘路由／錯誤恢復；完整目標保持進行中。

## 接續：播放器操作與 DVR 聊天焦點防護（2026-10-11）

- 核對一般 App handle 9868 活著後正常 q 結束（退出碼 0）。本輪只改既有整合測試及 docs，不修改正式功能、偏好或憑證。
- TWITCH_READONLY_PERFORMANCE_INTERACTIONS 在原 60 秒直播觀察每 10 秒實際點一次 WatchControlsOverlay 並 pump 250 ms，涵蓋控制列顯示時的更新；保留原播放前進／不緩衝要求。新增互動的等待會計入 Stopwatch，不能拿多出的時間當卡頓。
- TWITCH_READONLY_DVR_CHAT_FOCUS 放在完整 DVR 原暫停恢復／45 秒跨分段之後，先確認聊天室輸入可用與實際 EditableText 有焦點，再送左右鍵；觀察 3 秒要求 stream URI／canonical target 不變、無 seek action、原生播放前進 >2 秒／非緩衝；不查看或修改草稿文字，不送 Enter 或點送出。再實際點播放器要求聊天室焦點釋放，接續原完整 DVR 左右鍵跳轉／各 10 秒前進及返回直播測試。
- 本輪 analyze 僅一次：整合測試 No issues found（7.2 秒、退出碼 0）。真實流程 handle 18038 已編譯、進入直播解碼；未提前將新要求記為通過。
- handle 18038 完整流程失敗（2 分 31 秒、退出碼 1）：60 秒六次播放器點擊全部執行、進度約 62,000 ms、實際 62,022 ms、maxPumpMs=1,021、無停滯／緩衝取樣；完整 DVR 解碼／原 45 秒恢復也通過，但在新增 chat focus 前提失敗，未到方向鍵防護／後續返回直播，整體不能計成功。
- 保留診斷重跑 handle 39810 失敗（1 分 28 秒、退出碼 1）：原直播／DVR 解碼／45 秒恢復通過，明確 bars=0、editableCount=0。定向讀取 watch page 與 TwitchVodReplayChatPanel 確認完整 DVR 預設 replay 模式只顯示回放列表，live composer 需透過模式徽章切換；屬測試前提錯誤，不猜成登入或正式功能故障。測試已改實際點模式徽章 replay→live，驗證 composer 與焦點防護後再點 live→replay，原 DVR 方向鍵與返回直播要求保留。診斷／前提修正未再 analyze，接續用真實整合編譯與執行驗證。
- 更正上一節「低聊天更新樣本」推論：TwitchWatchChatMessageArea 直接監聽 chat runtime／emote caches，chat controller 的 0 次通知不是訊息流量。先前耗時／播放數值仍有效，但沒有 runtime 頻率，不能宣稱聊天室低流量或高流量；矩陣已更正，後續需補正確 runtime 計數。
- handle 66369 前提修正後仍失敗（1 分 29 秒、退出碼 1）：實際模式徽章切 replay→live 成功，bars=1，但標準 EditableText finder=0；診斷只列 widget 類型 ExtendedEditableText／_ExtendedEditable，未讀草稿。依既有 TwitchTextField 的套件接線，測試改同時辨識 ExtendedEditableText；未改正式快捷鍵判定，等待真實焦點行為證據。此輪 DVR 45 秒觀察曾記錄 lifecycle resumed／inactive 切換且原生未 cache-pause，但不是完整 OS 前背景效能對照。
- 使用者詢問為何總從瀏覽選頻道：既有整合先斷言已登入首頁 following，再主動切 browse 測搜尋；普通直播點瀏覽可見卡，完整 DVR 從 browse 前五個樣本找 growing archive。這不是預設首頁變成瀏覽，但也不算追隨首頁第一張卡入口已驗證；後續需獨立補該路徑，不以瀏覽替代。
- handle 62622 完整真實流程通過（2 分 4 秒、退出碼 0）：replay→live 聊天模式實際點擊、可用 ExtendedEditableText 實際焦點、左右鍵不改 DVR 來源／目標且三秒播放前進、點播放器釋放焦點、live→replay 恢復全部通過；接續原 DVR 左右鍵各 10 秒播放與返回直播／再前進也通過，原 45 秒暫停恢復要求仍保留。不動草稿或真實送出，也不把前面三次失敗抹掉。
- 本批 DVR 13,297 幀 P95 build=5,291 us／raster=3,468 us，build >33.333 ms 20 幀、raster 0 幀；仍只是 debug／integration 樣本，不代表一般 App 卡頓已排除。沒有正式程式修正。
- docs/twitch_watch_chat_keyboard_test.dart 四項 mock/widget 回歸通過：shared guest/input gate、管理快捷鍵有／無 callable gate、權限失效阻擋、確認期間原訊息消失不送出、取消管理確認與貼圖面板小尺寸；使用記憶體 prefs／假的 runtime，無真實發言或管理寫入。不取代真實聊天室的送出測試。
- 一般 Windows debug App 測試後重開：編譯 20.6 秒、同步 134 ms，PID 27984、Responding=True、互動 handle 75611；未操作系統滑鼠。下一批追隨首頁第一張直播卡入口與正確 runtime 更新頻率仍待測，完整目標進行中。

## 接續：追隨首頁第一張直播卡（2026-10-11）

- 上輪 DVR 模式／焦點新要求取得真實證據，屬進展。核對正常 App handle 75611 活著後 q 正常退出 0。
- 新增 TWITCH_READONLY_FOLLOWING_ENTRY：要求已登入首頁 selectedSection=following，等待實際第一張 TwitchStreamCard 出現且可點擊，記頻道僅供記憶體比較、不輸出名稱，實際 tester.tap 後要求 watch.channelLogin 與卡片一致。此分支不切 browse、不搜尋、不直接 Navigator push，若沒有第一張卡就失敗，不挑其他頻道；與直接取 DVR 樣本的 fullDvr 開關互斥。原瀏覽／搜尋／媒體庫流程完整保留在另一分支，不拿本批替代。
- 在 chat 連線門檻通過後附加目前 chatRuntime 的 Listenable 計數，teardown 解監聽，60 秒每 10 秒去敏輸出批次通知量。不同於 chat controller，此源才是訊息列表直接監聽之一；通知可能含狀態／批次／刪除，不等於逐則訊息數，不讀取或保存訊息內容。
- analyze 一次：整合測試 No issues found（7.3 秒、退出碼 0）。真實 handle 90950 已實際點追隨首頁第一張卡並通過頻道一致斷言，播放／60 秒互動觀察仍待完成。
- 真實流程全部通過（1 分 26 秒、退出碼 0）：首次首頁第一張追隨直播卡實際點擊／頻道一致、共用登入、非訪客唯讀 chat 連線、初始解碼與原 15 秒要求、60 秒六次播放器點擊與持續播放均通過。本批完全未切 browse；初始分類是 following，不改使用者偏好、不直接推路由、不改真實帳號。
- 60 次 1 秒觀察加六次 250 ms 互動等待，Stopwatch=62,201 ms、播放增量=62,200 ms；maxPumpMs=1,038、無停滯／緩衝取樣。runtime 每 10 秒通知 19／20／18／19／17／34（此窗口共 127 次），而 chat controller 各窗口仍為 0，確認上一輪 controller 數不可推論訊息流量；runtime 全場 175 次包括初始 15 秒等時段，不能拿它充作 60 秒頻率。
- 觀察階段 9,520 幀 P95 build=6,410 us／raster=4,033 us、max build=43,593 us／raster=9,903 us，build >33.333 ms 17 幀、raster 0 幀。只證明此 UI 第一張追隨卡／debug 整合樣本未取樣到持續停滯，不推算 FPS，也未宣稱使用者一般 App 卡頓已解決或已達高流量門檻；聊天通知不等於訊息數。
- 測試後一般 Windows debug App 重開：編譯 20.8 秒、同步 112 ms，PID 28704、Responding=True、互動 handle 31295。未改正式功能或操作系統滑鼠，仍有矩陣待測項，完整目標保持進行中。

## 接續：追隨篩選／分頁／刷新競態（2026-10-11）

- 新增 docs/twitch_following_page_flow_test.dart，以 implements TwitchDiscoveryService 的假的服務取代所有頁面使用的 fetch（直播、離線、profile、game artwork），沒有建立真實 API client；SharedPreferences 是記憶體 mock，未動真實追隨或憑證。
- 初次 fixture 編譯因少 attachProfiles 參數失敗，補正服務簽名後保留實際失敗：2 項通過／3 項失敗。語言 ListTile 在有色 DecoratedBox 下觸發 Material 遮蔽 assertion；分類文字 finder 同時命中底層卡片與選單，屬測試選取歧義。兩項 stale pagination 則分別將舊資料插入刷新後清單、將過時失敗寫入新 paginationError，是正式頁面缺少 generation 防護。
- 正式追隨頁修正：refresh 開始清 loadingMore 並標記 _refreshing；refresh 完成／失敗解除標記，loadMore 在刷新／首次載入期間拒絕啟動，保存 _refreshGeneration，fetch／profile await 後及 catch 都拒絕舊 generation。只改本次確認的刷新競態，不改 OAuth、帳號儲存或播放器。
- 語言項目加透明 Material 作為 ListTile 繪製容器，保留原標籤、尺寸、顏色與回呼；不是視覺重設。測試分類改點選單最後一個匹配，避免底層卡片同名歧義。
- 七項 widget/mock 全部通過：語言 en 選項＋遊戲 g2 選項實際點擊、組合後搜尋空結果、不額外抓資料；首次失敗頁面重新整理按鈕恢復；100 筆 prefix 保留、重複 ID 不追加、耗盡不再請求；clearExisting=false／true × 晚到 success／error 四種情境均驗證新清單／cursor／error 不受污染，刷新期間不另發分頁。選單入口呼叫公開 showMenu，分頁呼叫 state.loadMore，不能當成工具列／footer 的真實點擊完成。
- analyze 一次（7.6 秒、退出碼 1）：只有 docs fixture 的 setMockInitialValues 在非標準 test/ 路徑觸發 invalid_use_of_visible_for_testing_member 警告，無正式頁面 analyzer 錯誤。依限制本輪不反覆修／重跑 analyzer；下一輪補此確實僅測試用位置的窄範圍註解，不能關閉正式規則。
- 已確認舊正常 App handle 31295 活著後 q 正常退出 0。修正後真實整合 handle 79779 已從追隨第一張卡進 matching live route，聊天室／長觀察仍待完成，未先記通過。
- 修正後真實追隨入口整合通過（1 分 26 秒、退出碼 0）：第一張卡／matching route、聊天室連線、原 15 秒解碼要求、60 次播放取樣與六次實際點控制列全部通過；實際經過 62,223 ms，播放增量 62,234 ms，無取樣停滯／緩衝。60 秒 runtime 通知 32／31／37／23／17／15，僅批次數；lifecycle=resumed，不當成完整 OS 前背景對照。
- 觀察階段 9,296 幀 P95 build=7,998 us／raster=4,241 us，build >33.333 ms 24 幀、raster 0 幀；home 109 幀 P95 build=43,350 us，包含首次載入，不以直播較快樣本否認首頁耗時。真實回歸未測故意製造網路錯誤、工具列篩選或 footer；此部分保留 mock／待測區分，卡頓要求仍未排除。
- 一般 Windows debug App 重開完成：編譯 24.9 秒、同步 104 ms，PID 23132、Responding=True、互動 handle 83877；未用系統滑鼠。下一批先處理測試檔窄範圍 analyzer 警告，並補離線追隨／刷新失敗／離頁取消等未涵蓋情境，完整目標仍進行中。

## 接續：追隨錯誤恢復與離頁生命週期（2026-10-11）

- 前輪正式競態修正及真實回歸屬進展。本輪定向重讀測試檔，確認正常 App handle 83877 仍活著；本輪不需要停止 App 或改正式程式。
- 在 docs fixture 的 setMockInitialValues 呼叫旁補限定測試用途註解與單行 ignore，只因 fixture 在 docs/ 不被 analyzer 當標準 test/；不關閉全檔規則或修改真實偏好儲存。
- 假的 Discovery 新增可控制 offline／profile 回應，仍無真實 API client 或帳號寫入。本輪新增九項，連原七項共 16 項全部通過（退出碼 0）。
- 兩種離線讀取失敗：有直播卡時保留卡片、無直播時顯示離線也失敗的空狀態；之後 refresh 清除 offlineError。刷新主清單失敗保留原卡、不升級成初次空頁錯誤，下一次刷新成功替換卡片／清錯。分頁失敗保持 100 筆／cursor／hasMore，retry 使用同一 cursor，只追加一次並耗盡。
- 離頁測 refresh／pagination × 晚到 success／error 四種情境：mounted=false、原資料不變、沒有 setState-after-dispose 或未處理例外。只證明忽略晚到結果，不宣稱 HTTP 已取消。另用 profile Completer 把分頁停在第二個 await，先刷新成功再完成舊頭像回應，確認原分頁不插入新清單，覆蓋 generation 的第二檢查點。
- 恢復與分頁測試使用 state 方法，不冒充實際重試 footer／捲動手勢；原首次失敗的頁面重新整理按鈕、語言／分類選項實際點擊仍保留並通過。離線完整清單／分頁、換帳號／權限矩陣與真實篩選仍待測。
- analyze 本輪一次（7.2 秒、退出碼 1）：原 setMockInitialValues 警告已消失，但新測試第 269 行有一項 curly_braces_in_flow_control_structures info（if 缺大括號），無 warning/error；依限制不本輪反覆修到綠／重跑，下輪加大括號。正常 debug App 不需重開：互動 handle 83877 本輪確認活著，PID 23132／Responding=True，維持已開啟。矩陣仍有未驗證要求，完整目標進行中。

## 接續：離線追隨去重與授權提示（2026-10-11）

- 上輪新增九項錯誤恢復／離頁證據，屬進展。本輪先補上測試 if 的大括號，沒有改正式程式。
- 新四項連原 16 項共 20 項 widget/mock 全部通過（退出碼 0）：離線清單按直播 userId／login 分別排除重複，保留真正離線項；頁面 searchText 命中 description，遊戲選項實際點擊後隱藏離線卡，點全部分類恢復，沒有額外 fetch。
- 三種注入的 OAuth 不可用／缺 scope 字樣／授權失效錯誤均顯示 TwitchLoginRequiredView 而非直播格；實際點「用 WebView 登入」只呼叫測試假回呼一次，不開真實登入視窗、不登入／登出。將假資料來源切成成功後，實際點「重新檢查」恢復卡片並清 error。這驗證頁面錯誤分類／按鈕接線，不能當成真正 token 驗證或 service scope gate 已通過。
- 本輪定向檢查既有 discovery session fixture，確認還需要獨立補 service 無 scope 阻擋證據；首頁無 scope 預設分類、帳號切換完整路由與離線多頁清單仍待測，未縮小目標。
- analyze 一次：此測試檔與正式追隨頁 No issues found（7.4 秒、退出碼 0）。正常 debug handle 83877 本輪再次確認活著，PID 23132／Responding=True，維持開啟；僅測試與文件修改不重啟正常 App，不操作系統滑鼠。卡頓與矩陣其餘功能仍未完成，目標進行中。

## 接續：追隨服務權限與驗證競態（2026-10-11）

- 前輪頁面授權提示測試屬進展，本輪補真正 TwitchDiscoveryService.fetchFollowedStreams／fetchFollowedChannels 的 scope 與晚到驗證門檻，不再用錯誤文字代替服務行為。
- docs/twitch_discovery_session_test.dart 注入 Dio onRequest 攔截並回傳固定假的空清單，記 RequestOptions 僅存在測試記憶體。全部既有與新增測試不會出網路；fake session／validation 不改真實 auth 儲存、cookie 或 token，不印私人憑證。
- 新十項（兩種方法各五項）：訪客無驗證／無 transport；有效身分缺 follows scope 維持 authenticated／canReadFollows=false 但無 transport；驗證等待時登出後，即使舊 validation 有完整 scope 也拒絕資料請求；換帳號時只有新 viewerId／Bearer 到達假 transport，舊成功驗證晚到被拒絕且不取代新 cache；有效授權的正向案例核對 GET endpoint／user_id／Bearer，確保不是一律封鎖。所有身分／憑證為 fixture 值。
- 該檔共 19 項通過，連追隨頁 20 項重跑共 39 項全部通過（退出碼 0）。原九項 session 的登出、401／403、503 保留 cache、singleflight 與匿名 browse 不等待驗證也保留。不當成完整頁面換帳號或真實 OAuth 流程完成。
- analyze 本輪一次：兩份測試 No issues found（7.2 秒、退出碼 0）。本輪只改服務測試與 docs，無正式程式變更。正常 debug handle 83877 又確認活著，PID 23132／Responding=True，維持開啟；未操作系統滑鼠。
- 後續仍需離線多頁清單、首頁無 scope 分類與完整路由權限競態；卡頓與其餘功能矩陣保持未完成，長期目標進行中。

## 接續：離線追隨多頁與重試（2026-10-11）

- 前輪服務 scope／身分競態新增真實程式 mock 證據，屬進展。本輪定向重讀追隨頁與服務後確認：服務接受 after，頁面卻只取 channels/followed 第一頁，忽略 cursor，後頁離線頻道永遠未加入。
- 新三項先重現失敗（原 20 項通過／新 3 項失敗，退出碼 1）：多頁樣本只得到 first，缺 last；第二頁失敗／cursor 重複兩情境均只呼叫 [null]，根本沒有到第二頁。不將缺資料當完整清單成功。
- 正式追隨頁補齊 cursor 直到耗盡，保留來源順序並按 ID／login 去重，再依已載入的直播清單排除 live；cursor 重複轉明確失敗，不無限迴圈，不加任意筆數上限冒充完整。每頁 await 前後檢查 mounted／refresh generation，舊頁不繼續讀下一 cursor；不宣稱底層 HTTP 已取消。
- offlineError 接到原 TwitchDiscoveryFooter 的錯誤／重試路徑，若沒有直播分頁錯誤則按原重試按鈕重新 refresh；不新增組件、樣式或重設 UI。中途失敗不把局部離線資料當完整結果，直播卡仍保留；沒有更動 Twitch API payload、OAuth 或真實追隨。
- 新增五項（原三項加離頁／刷新後不再請求下一 cursor）均通過，追隨頁共 25 項，連 session／服務 19 項共 44 項重跑全部通過（退出碼 0）。第二頁失敗及重複 cursor 都實際點原 footer retry 恢復，非只呼叫 state；多頁資料仍為假的 fixture。
- analyze 一次：兩份測試與正式追隨頁 No issues found（8.4 秒、退出碼 0）。確認舊正常 handle 83877 活著後 q 正常退出 0，修正後真實整合 handle 71788 已啟動編譯；未先記真實回歸成功。
- 大量 offline 全讀的耗時、多頁期間換帳號，以及 >100 開台追隨的 live-window／offline 分類仍要獨立測，不能由兩頁 mock 宣稱所有分類正確。長期矩陣其餘需求保持不變。
- 修正後真實 handle 71788 整體失敗（1 分 26 秒、退出碼 1）：追隨第一卡／matching route、chat、原 15 秒播放與六次點控制列、60 秒觀察本身均有 passed 記錄；實際 62,199 ms、播放增量 62,200 ms、無取樣停滯／緩衝，但最後 Some tests failed，且未輸出預期 teardown 幀統計。不能把前段成功當整體通過；去敏 print 原本未保留錯誤類型，原因待定位。
- 只在已允許的整合測試補 FlutterError.onError 去敏診斷：輸出 exception runtimeType、固定 ListTile／overflow／disposed／setState／assertion／timed out 關鍵字旗標與 phase，仍呼叫原 framework handler、teardown 還原，不吞錯誤或輸出完整訊息／stack／URI。此修改在本輪唯一 analyze 後，未重跑 analyze；由接續真實整合編譯驗證，handle 70258 不改斷言重跑。
- 診斷重跑 handle 70258 整體通過（1 分 26 秒、退出碼 0），原追隨入口／chat／15 秒／六次控制列點擊／60 秒持續播放要求都保留，teardown controller／frame 統計也正常完成；沒有去敏 framework exception 記錄。前一次最後失敗原因仍未重現／未確定，不以本次成功抹掉，也未猜測性修正式程式。
- 本批實際觀察 62,299 ms、播放增量 62,300 ms、maxPumpMs=1,076、無取樣停滯／緩衝；runtime 窗口通知 32／33／35／24／20／22。觀察階段 9,013 幀 P95 build=8,898 us／raster=4,187 us，build >33.333 ms 21 幀、raster 0 幀；窗口最大 build=61,784 us／raster=16,133 us。不能用持續播放通過否認單幀慢或一般 App 卡頓；仍非 profile／同頻道 A/B。
- 一般 Windows debug App 重開完成：編譯 24.4 秒、同步 110 ms，PID 28844／Responding=True、互動 handle 75068。下一批需多頁換帳號／大量清單及本輪未重現收尾失敗的後續診斷；矩陣其餘要求仍保持待測，完整目標進行中。

## 接續：資料來源替換與大量離線清單（2026-10-11）

- 前輪離線多頁修正及回歸為進展，但首輪收尾失敗原因仍未定位。本輪定向閱讀 didUpdateWidget 發現只檢查 reloadTick，不檢查 discoveryService 替換；新資料來源可能不重載，舊 follow 清單繼續顯示。
- 新四項先跑，原 25 項加大量清單一項通過，來源替換三項失敗：新 service.calls=[]；失權新來源仍有舊 loadedStreams。25 頁 ×100 筆假資料則已全部收齊 2,500，驗證目前分頁不任意截斷；不把零網路延遲 mock 當實機效能。
- 正式追隨頁只補 discoveryService identity 改變時 refreshStreams(clearExisting:true)，沿用 generation 清除舊直播／離線清單並重載；reloadTick 的原刷新分支不變，不改 token、登入儲存或 UI 選項。來源替換不代表真正 OAuth 主帳號切換，不能替代同一 authService 的路由驗證。
- 原離線第二頁等待時換新來源，晚到成功或錯誤都不再抓舊 third cursor、不污染新直播／offline／error；換成拒絕授權的來源清除舊 follow 卡並顯示登入提示。另核對 25 個 cursor、2,500 筆首尾順序／唯一 ID／無錯誤，沒有實際帳號資料。
- 追隨頁共 29 項，連 session／服務 19 項共 48 項全部通過（退出碼 0）。analyze 本輪一次：這兩份測試、正式追隨頁與已補去敏診斷的整合測試四檔 No issues found（8.0 秒、退出碼 0）。
- 核對正常 handle 75068 活著後 q 正常退出 0。真實回歸 handle 69274 已編譯啟動：following first card＋60 秒互動＋原 home／mini／跨頻道／追隨欄流程，不改原偏好，不先記通過。此真實回歸不會切真實帳號。

## 接續：真實直播路由回歸完整收尾（2026-10-11）

- 前輪定向確認控制列排版後未修改 UI。handle 69274 已不存在，最終輸出未完整保留，故該輪維持整體結果未確認，不由前段斷言推定通過。
- 本輪確認沒有 vioclass 程序後啟動新整合 handle 58150，保留 following-entry／live-performance／performance-interactions／live-routes／rail-switch 全部分支，無真實帳號切換或寫入。Windows 編譯 35.9 秒，已確認登入解析、追隨第一張卡實際點擊與相同頻道 watch、唯讀聊天室連線及原生播放位置開始前進；其餘斷言與收尾待完成。
- 本輪整體通過（2 分 16 秒、退出碼 0），含 teardown 完整統計：原 15 秒直播、60 秒互動、回首頁舊 chat 斷線、迷你影片持續播放／實際點擊展開／fresh chat 與來源、回首頁關閉後暫停、另一首頁卡實際切頻道及 15 秒前進、追隨欄實際切第三頻道／新上游／新 chat／舊 chat 斷線／選中再點不重開及 15 秒前進全部通過。helper 的 browse channel 標籤不代表本輪切到瀏覽，此流程首頁仍為追隨。
- 三個新 watch 的側欄各 12 次 100 ms 幾何取樣穩定。60 秒互動實際經過 62,060 ms、播放增量 62,083 ms、maxPumpMs=1,032，取樣停滯／緩衝均 0；chat runtime 每 10 秒批次通知 34／26／15／18／14／6，不保存訊息內容。
- 觀察階段 10,133 幀，P95 build=5,815 us／raster=3,863 us；build 超過 33.333 ms 共 10 幀、raster 0 幀，最大 build=49,184 us／raster=12,422 us。無去敏 framework exception 記錄；仍非 profile、同頻道 A/B 或一般 App 長時間實測，不以取樣無停滯宣稱使用者卡頓已修好。前輪 69274 結果與更早失敗原因仍不追認為成功。
- 本輪只更新測試證據文件，未修改程式或 UI，未執行 flutter analyze；整合已編譯並完整通過。一般 debug App 已另啟動，待確認視窗與互動 handle。
- 一般 Windows debug App 已開啟：編譯 24.6 秒、同步 111 ms，互動 handle 96802、PID 38048、Responding=True、視窗 VioClass；未操作系統滑鼠。下一批仍需 DVR 暫停時跳轉／拖曳、更多頻道與錯誤恢復，以及完整矩陣其他待測項目，目標未完成。

## 接續：DVR 暫停時跳轉（2026-10-11）

- 前輪直播路由完整通過屬進展。本輪沿用已允許的整合測試檔新增 PAUSED_DVR_SEEK 分支，實際點 DVR 暫停按鈕、方向鍵跳轉，要求新來源及解析目標誤差 <2 秒、播放保持暫停及 3 秒位置偏移 <500 ms，再實際點播放並持續 10 秒前進 >7 秒；非系統滑鼠，沒有帳號寫入。
- 本輪 analyze 僅一次：整合測試 No issues found（6.9 秒、退出碼 0），此時尚未做正式修正。確認一般 App handle 96802 活著後 q 正常退出 0，啟動真實整合 50611。
- 首輪失敗（1 分 29 秒、退出碼 1）：初始 DVR 解碼與原 45 秒恢復前進 45,283 ms 通過，UI 暫停及方向鍵換新來源／目標斷言通過，接著保持 paused 的斷言未通過，framework type=TestFailure。未把初始前進當完整成功；初始原生播放器有去敏 invalid／error 旗標，但後續已成功解碼，不能直接歸因該旗標。
- 定向程式確認 seekLiveDvrBridgePlaybackAt → openLiveDvrBridgeMedia 固定 play:true。只修改此橋接跳轉：await 前記錄目前 playing，傳入 openMedia；保留其他呼叫的預設 true，不補按 pause 來掩蓋錯誤，不改播放傳輸／token／控制列。
- 修正後真實 handle 45583 重跑，保留原 DVR 測試、新增暫停跳轉及原 DVR 左右鍵播放中跳轉，新增 playing／buffering 布林診斷；尚待完整結果。正式修正與新增診斷在本輪唯一 analyze 後，依限制不重跑 analyze，由真實整合編譯及斷言驗證。
- 修正後 45583 整體仍失敗（1 分 52 秒、退出碼 1），不得記完整回歸通過：原 45 秒增量 45,300 ms；新增暫停跳轉回報 playing=false，保持暫停及位置穩定、UI 恢復解碼和 10 秒前進斷言全部通過。但之後原播放中 DVR controls 流程出現 TestFailure，未到返回直播；已保留此未解決結果，後續須補該步驟的去敏定位，不能用新分支通過代替整體通過。

## 使用者追加：置頂留言視覺統一（2026-10-11）

- 使用者要求置頂留言與忠誠列車／下注視覺一致，並明確確認要調整的是留言卡片內 PIN，而非聊天室右上角切換按鈕。
- 僅置頂卡改為下注卡同款深灰紫漸層／18 圓角／白色淡邊框／陰影／半粗名稱與標註字重；PIN 改左側主圖示框 28、圖示 15、10 圓角、相同 accent 填色及邊框、9 間距，頭像移到名稱旁。保留名稱專屬顏色、長按複製、展開收合與連結程式，不改列車／下注行為、權限、payload 或右上角切換按鈕。
- 新五項 widget 測試全部通過（退出碼 0）：240／600 logical pixels ×0.82／1.36 fontScale 的底色／框／字重／PIN 大小與左側位置、展開12行／收合2行無例外；另用假的 Clipboard handler 核對長按複製，沒有改使用者剪貼簿或執行真實帳號寫入。非完整真實三卡同時顯示的視覺驗證。
- 本輪唯一 analyze 已於先前 DVR 測試修改後執行；後續 UI 修改不重跑 analyzer，由上述 widget 編譯／執行及一般 App 編譯檢查，不宣稱 UI 修改已有 analyze 證據。
- 一般 Windows debug App 已重新開啟（編譯 24.6 秒、同步 110 ms）：互動 handle 89787、PID 23644、Responding=True、視窗 VioClass；保留原登入與偏好、不操作系統滑鼠。真實聊天室未強行建立置頂或下注以製造三卡展示，仍需當下有資料的視覺驗證。完整長期目標保持進行中。

## 使用者追加：PIN 下方頭像與完整寬度控制列（2026-10-11）

- 使用者要求頭像放在卡片 PIN 下方，並明確要求修改控制列樣式；先處理新要求，原 DVR controls 失敗仍待定位，沒有追認已修復。
- 置頂左側改 PIN／7×fontScale 間距／頭像垂直排列，名稱不再插入頭像；保留 PIN 28 框／15 圖示與既有卡片風格。測試新增頭像位於 PIN 下方且水平中心一致。
- 控制列改成上方時間標示、中間完整寬度時間軸、下方操作按鈕。compact 不再固定 390／620 寬後整排 FittedBox 縮放，改用實際寬度；極窄畫面僅按鈕列可橫向捲動，保留各功能，不讓按鈕／音量搶走時間軸。控制區高度 128，wide 保留左右分組。
- TwitchVodPlaybackStrip 新增 fullWidthTimeline 版面選項，由控制列三種來源分支使用；預設 false 保留其他入口原布局。將既有 slider 與時間控制組合移到不同列，原拖曳／跳轉／返回直播處理未修改，slider 40 高保留點擊範圍。未改播放器底層、登入、token 或 UI 以外功能。
- 新 layout fixture 使用假的 Player／streams／runtime，四種寬度 240／390／620／1024 的 VOD：時間軸元件寬 >可用寬80%、播放按鈕在時間軸下方、無整排縮放／overflow、實際點時間軸觸發假 seek 均通過。初版 fake seek 少 synchronized 參數編譯失敗，補相符簽名後連置頂五項共九項全部通過（退出碼 0）；無真實媒體或帳號操作，不當成 DVR／live 整合通過。
- 本輪 analyze 一次，三個正式 UI 檔及兩份 widget 測試共五檔 No issues found（6.9 秒、退出碼 0）。確認正常 handle 89787 活著後 q 退出 0，重開一般 App handle 51315，待確認啟動；真實 live／DVR 新排列與原 controls 失敗仍待後續驗證。
- 一般 Windows debug App 開啟完成：編譯 24.2 秒、同步 110 ms，handle 51315、PID 28648、Responding=True、視窗 VioClass。未操作系統滑鼠或更動帳號狀態；完整測試目標保持進行中。

## 使用者追加：框外時間軸貼齊薄控制列（2026-10-11）

- 前輪 UI 實作與九項 widget 證據屬進展。本輪先在既有 DVR controls 加左右獨立 framePhase 與去敏 preflight（mode／canSeek／positionMs／durationMs／playing／數字 stream generation），不輸出頻道或 URI。analyze 唯一一次：整合測試 No issues found（9.8 秒、退出碼 0）。正常 handle 51315 確認活著後 q 退出 0。
- 真實 handle 5309 編譯 37.7 秒後登入／公開搜尋／聊天室／15 秒直播／archive／初始 DVR 解碼通過，但整體於 49 秒失敗（退出碼 1），尚未到原 45 秒恢復及新 preflight，未取得該失敗原因；不當成控制列或暫停修正成功。原先暫停後 controls 失敗也仍待定位。
- 使用者追加要求控制列不要厚框包住時間軸與時間，並指定拖曳條剛好在邊框上方。本輪只改 UI：上層透明布局，時間標示／時間軸不在 glass 面板內；下方操作面板高 48，用 Stack 將時間軸中心對齊面板上緣上方 3 logical pixels，沒有整排縮放，不改拖曳或 DVR handlers。
- 四寬度 240／390／620／1024 fixture 新增唯一面板高度48、時間軸中心距上緣3、strip 不在面板內的斷言；保留 >80%寬度、實際 slider 點擊觸發 fake seek 與無 overflow。連置頂五項共九項全部通過（退出碼 0）。UI 在本輪 analyzer 後追加，依限制不重跑；由 widget 編譯／執行及一般 App 編譯驗證，非真實 DVR 回歸通過。
- 一般 App 已重新啟動，待確認視窗。整體 DVR、卡頓與其餘長期矩陣仍未完成。
- 一般 Windows debug App 已開啟：編譯24.0秒、同步117ms，互動 handle 14128、PID38308、Responding=True、視窗 VioClass。未操作系統滑鼠，保留帳號與偏好。

## 使用者追加：無圓點、上緣直角與低成本漸層（2026-10-11）

- 僅 fullWidthTimeline 時間軸使用 noThumb／noOverlay，保留40高區域及既有點擊／拖曳 handlers；音量與其他入口不變。操作面板上角直角、底角保留圓角。
- 首批四寬度測試通過，本輪 analyze 唯一一次為兩個正式控制 UI 檔及 layout fixture，No issues found（4.8秒、退出碼0）。一般 handle14128 的唯讀 poll 已回 exit0／handle消失，確認已結束，沒有強制關掉其他程序。
- 使用者接著要求漸層或毛玻璃，但不模糊直播背景。定向確認共用 TwitchGlassSurface 存在 legacyPlayerDock 特例，特定黑色／blurSigma0／無陰影組合仍要求 blurSoft，因此控制列不再使用它；不修改共用 glass 行為或其他 sheet。
- dock 改 ClipRRect＋DecoratedBox，垂直半透明灰紫至深黑漸層，淡邊框，沒有 BackdropFilter／ImageFilter 或動態背景採樣。不宣稱零渲染成本或已測出效能提升。
- layout 四項再次全部通過（退出碼0）：無 thumb／overlay、上方直角／底角圓角、gradient／dock 無 BackdropFilter、48高／時間軸貼上緣3像素，以及實際 fake seek 點擊／往左拖曳。首版誤移除 sheet 仍使用的 glass import 導致編譯失敗，已恢復 import 並重跑通過；不改 sheet 的玻璃樣式。
- 漸層追加於本輪唯一 analyze 之後，不重跑；由 widget 編譯與一般 App 編譯驗證。正常 debug handle11461 已啟動，待確認視窗。DVR 整體失敗及完整矩陣保持待追查／待測。
- 一般 Windows debug App 已開啟：編譯25.6秒、同步110ms，handle11461、PID32248、Responding=True、視窗VioClass；保留原帳號與偏好、無系統滑鼠操作。

## 接續：暫停 DVR 時間軸偏到直播末端（2026-10-11）

- 前輪使用者樣式調整有 widget 證據，屬進展。本輪在既有 framework error handler 只抽取整合檔行／欄號，不輸出 stack 或例外原文；再加暫停前／目標／恢復前 canonical snapshot 與 runtime resolved 的毫秒診斷。原 handle11461 確認活著後 q 正常退出0。
- 真實53730失敗（1分45秒、退出碼1）：原45秒、UI暫停／跳轉保持暫停／UI恢復10秒通過；接續左鍵尚未送出，snapshot已為11,479,679ms、duration11,479,717ms，line1746的目標需早於尾端30秒斷言失敗。未降低斷言或改目標避開問題。
- 診斷重跑81103同樣失敗（1分44秒、退出碼1）：暫停前snapshot5,851,976ms／runtime5,806,639ms；跳轉target5,842,245ms／runtime解析相同，但恢復前snapshot已11,674,727ms，接續左鍵preflight位置接近duration，line1755失敗。確認新來源跳轉正確而暫停期間顯示時鐘錯到直播末端。
- 正式timeline controller修正：同一URI的advancing狀態轉換才重建目前位置anchor，來源改變仍由原sync採新canonical target；暫停／緩衝不以native demux clock差值推進canonical anchor，避免paused generation開檔時的時間戳跳動被當成播放。保持播放中壁鐘推進及其他seek接線，不改token、native播放器runtime或樣式。
- 六項局部刷新／四寬度控制列mock通過；本輪analyze唯一一次：timeline controller與整合檔No issues found（7.9秒、退出碼0）。修正後4435真實回歸在live解碼等待逾時（1分16秒、退出碼1，phase=live），未進DVR，不證明修正通過或失敗；原要求不放寬，已用同一流程接續重跑。
- 修正後17945完整通過（2分17秒、退出碼0）：登入／搜尋／唯讀chat／15秒live、DVR初始解碼、暫停恢復45秒增量45,300ms、實際UI暫停及左鍵換新來源保持暫停、UI恢復10秒、播放中左右鍵各新generation／解析目標誤差<2秒／10秒前進、返回直播持續前進全部通過。暫停後snapshot與runtime目標同為6,004,385ms，恢復後左鍵preflight位置6,014,859ms／duration12,009,578ms，未再跳末端。未用新的通過抹去前輪live逾時或49秒未知失敗；本輪沒有extended120秒分支，不宣稱新修正的120秒已重驗。

## 使用者詢問：搜尋結果與浮動工具列重疊（2026-10-11）

- 定向診斷，未修改搜尋UI。root _buildContentColumn 的Stack以Positioned.fill放內容，toolbar另以top8浮在上面；Following／Browse共享TwitchDiscoveryStreamGrid依寬度插70／118高的首個sliver。
- 搜尋分支改用_TwitchChannelSearchPage的CustomScrollView，第一個sliver直接是搜尋結果標題，沒有工具列高度占位，因此初始結果可被Follow切換／篩選蓋住。與登入狀態無關；下一輪需在搜尋分支使用相符響應式留白，含窄畫面雙列及空結果驗證。本輪只回答原因，不將診斷當已修復。
- 一般Windows debug App重開完成：編譯25.6秒、同步117ms，handle9162、PID40408、Responding=True、視窗VioClass；未操作系統滑鼠或帳號寫入。完整矩陣仍有未完成要求，目標持續進行。

## 接續：DVR 時鐘修正後長時間回歸（2026-10-11）

- 前輪真實17945完整回歸通過，屬進展。本輪不修改正式程式或搜尋UI，只在已允許的整合檔新增暫停跳轉後canonical snapshot距目標<2秒的斷言，保留原生位置穩定<500ms及原恢復要求；extended分支獨立framePhase。
- 本輪analyze唯一一次：整合檔No issues found（7.0秒、退出碼0）。確認正常handle9162活著後q退出0，真實長測97188以FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR四分支啟動，保留原45秒、左右跳轉、1/3／2/3各10秒、120秒及返回直播要求；沒有先記通過，不修改憑證或真實帳號寫入。
- 97188整體失敗（2分48秒、退出碼1）：取得45秒進度45,316ms、UI暫停跳轉及新canonical誤差斷言／恢復／左右鍵通過，暫停snapshot與runtime均6,165,295ms；取得repeated seek2持續播放通過，但未取得120秒及返回直播的完整成功或framework原因。不以局部斷言當extended整體成功，仍待定位。

## 使用者追加：搜尋共用主頁模板（2026-10-11）

- 使用者明確要求搜尋與主頁同模板並統一背景，故本輪開始修正，不再只是診斷。從原Discovery grid抽出TwitchDiscoveryScrollSurface，保留原appBackground、scroll cache／physics／controller／key及響應式70／118首sliver；Following／Browse grid與搜尋結果共用該surface。
- 搜尋原獨立RadialGradient移除，載入／結果與空結果均有相同背景及工具列占位。保留分類、卡片、refresh callback及登入／服務流程；空結果改SliverFillRemaining呈現原EmptyState，不新增功能。
- 新六項共享surface widget：600／720／1024寬×結果／空內容，搭實際TwitchStreamHomeToolbar，確認首內容top118／70早於toolbar下緣且背景appBackground；連原追隨29項共35項全部通過（退出碼0）。為模板mock，不當成真實搜尋已驗證。
- 已在既有整合新增SEARCH_LAYOUT_ONLY唯讀分支，真實公開搜尋後檢查搜尋頁使用shared surface與header在toolbar下方，再返回；不代替原完整播放測試，其他分支不啟用該flag。真實handle46874已啟動，待結果。
- 本輪唯一analyze在使用者追加UI之前已執行，依限制不再跑；新增UI及fixture由35項編譯／執行、真實整合與一般App編譯驗證，不宣稱最新版已有analyze證據。
- 真實46874整體通過（7秒、退出碼0，編譯35.7秒）：既有登入解析及實際點瀏覽／輸入公開搜尋，搜尋結果頁shared surface唯一，headerRect.top > toolbarRect.bottom、間距8.0 logical pixels。未測真實空結果／雙列裝置或捲動後置頂，此部分僅六項fixture及待測，沒有帳號寫入。
- 一般Windows debug App已重開：編譯24.3秒、同步110ms，handle81493、PID27828、Responding=True、視窗VioClass；無系統滑鼠操作，保留帳號與偏好。完整矩陣與DVR extended仍未完成。

## 接續：DVR 長測診斷與使用者確認時間標示置中（2026-10-11）

- 確認正常 handle81493 活著後 q 正常退出0，啟動真實四分支 FULL_DVR／PAUSED_DVR_SEEK／DVR_CONTROLS／EXTENDED_DVR，handle52437；保留原45秒／各次跳轉10秒／120秒／返回直播要求。長測診斷由每30秒改每10秒，增加playing／buffering布林；輸出先收取較完整原始批次再白名單去敏，不輸出URI、憑證或私人頻道。
- 本輪唯一analyze：整合檔、shared discovery template、搜尋頁及shared surface fixture四檔 No issues found（8.9秒、退出碼0）。其後使用者確認「目前時間／總時間」置中，依每輪一次限制不追加analyze；新版UI由widget編譯與執行驗證。
- 僅fullWidthTimeline的時間控制群水平置中，保留時間軸貼上邊框、完整寬度、無圓點及所有原操作；其他入口原布局不變。八項widget通過（退出碼0）：240／390／620／1024的VOD及直播時間群中心對齊、無overflow，原面板高度／時間軸位置與實際fake seek點擊／拖曳維持通過。首次新增VOD斷言未考慮寬畫面的inline時間控制而有一項finder失敗，改找實際時間控制群後通過，不是播放失敗。
- 真實52437整體通過（4分44秒、退出碼0）：登入／搜尋／唯讀chat／live、DVR恢復45秒增量45,216ms、UI暫停跳轉保持暫停及canonical目標、恢復10秒、左右鍵換來源各10秒、1/3與2/3跳轉各10秒、120秒增量120,833ms、返回直播10秒前進均通過。長測每10秒取樣playing=true／buffering=false；前輪97188原因未知仍保留，不因這次通過宣稱已定位或所有頻道／格式完成。此次整合編譯在時間UI修改之前，故其播放證據不當成置中後真實視覺證據。
- debug FrameTiming：extended DVR build P95=4,137us、raster P95=3,024us、build逾33.333ms六幀；live build P95=16,703us、逾門檻23幀。不是profile模式、嚴格A/B或所有卡頓排除，不宣稱零卡頓。完整矩陣仍有未驗證要求。
- 最新一般Windows debug App已開啟：編譯24.0秒、同步113ms，handle66413、PID16956、Responding=True、視窗VioClass；包含時間置中修改。未操作系統滑鼠、未更改帳號狀態，完整目標保持進行中。
- 使用者進一步澄清時間要在拖曳條下方，改為時間軸／置中時間／按鈕的垂直排列，控制surface高88、按鈕區仍48，時間獨立保留40上方區域，時間軸仍距surface上緣3。surface先畫、時間strip後畫，避免被背景遮住。八項widget再通過，新增時間位於slider下方且不疊播放圖示；初版76高在620／1024有垂直重疊，已加足留白。沒有再跑analyze。此前App66413已退出0且Lost connection、沒有vioclass程序，需重新啟動最新版。
- 最新一般App重開完成，handle62796、PID36364、Responding=True、視窗VioClass，編譯24.2秒、同步112ms。使用者詢問漸層感不足：定向確認surface只有深灰紫30%至深黑70%透明度漸層，上端不是透明起點且有淡邊框，slider本身為純色；沒有跨時間軸與surface的連續透明淡入。此為程式設定診斷，未直接觀察實際畫面，不修改樣式以代替使用者選擇。

## 使用者追加：時間與操作合成一排（2026-10-11）

- 依使用者截圖澄清，移除獨立時間列，控制surface恢復48高：播放／前後跳轉、時間、音量及其他操作同一水平列；拖曳條仍完整寬度且中心距面板上緣3，保留無圓點、既有漸層及不模糊直播背景。wide以等寬左右區域將時間置中，右側若不足可水平捲動；compact整排可水平捲動，不以縮小時間軸或隱藏功能避開不足。
- TwitchVodPlaybackStrip提供可選timelineLayoutBuilder，把原slider與時間控制交給控制列排版，只有控制列採用；其他入口預設版面不變。沒有更動seek／drag／live回跳callback、runtime、帳號或網路邏輯。
- 八項widget通過（退出碼0）：四寬度保留全寬slider／面板48／貼邊3／fake seek點擊與拖曳，時間與播放圖示同高度、不重疊；1024確認時間水平置中。四項直播時間群測試仍屬strip fixture，非真實直播視覺。首次finder因合成後也找到音量slider而失敗，改以max=1識別時間軸後通過。
- 本輪唯一analyze為兩個正式UI檔與layout fixture，No issues found（5.2秒、退出碼0）。上一輪真實DVR長測通過仍保留，未宣稱此次UI已有新真實DVR回歸或整個矩陣完成。

## 使用者澄清：時間軸紫色向下暈染（2026-10-11）

- 前輪透明至黑色淡入並非使用者要的概念。本輪只處理新樣式要求，不恢復已要求暫停的完整測試目標。控制surface上方使用與slider相同的theme primary、42%透明度，往下過渡深紫再深黑；不採樣或模糊直播背景、不新增動態陰影。保留同排時間／操作、48高與既有中心位置。
- fullWidthTimeline可見軌道由4／5縮為2 logical pixels，仍保留40高的互動區及原點擊／拖曳handlers；其他入口與音量軌道不變。
- 四寬度排版／拖曳與四項直播時間fixture共八項通過，新增軌道2高、漸層上方RGB與slider activeTrack相同及42%透明度斷言。此次唯一analyze三檔No issues found（5.2秒、退出碼0）。尚未開啟新版或取得真實畫面視覺驗證，不宣稱所有功能完成。

## 使用者追加：實際毛玻璃試版（2026-10-11）

- 使用者指出固定漸層不符合拖曳進度，並明確要求可以真正毛玻璃試看。本輪選擇此替代方案，不宣稱實作了進度長度染色：移除固定紫色漸層，ClipRRect內BackdropFilter sigma6，僅控制列48高背景模糊，前景按鈕／時間清晰；半透明深色tint 0x59171420。這是使用者新授權的背景採樣，不再沿用先前「不模糊直播」的限制。
- 八項widget通過：實際BackdropFilter唯一且大小等同clip、沒有gradient、原控制列48／時間同排／時間軸2高與完整寬度／貼上緣3／點擊拖曳seek仍通過。此次唯一analyze兩檔No issues found（5.1秒、退出碼0）。真實背景畫質與效能未取樣，不能宣稱零成本或已消除卡頓；完整測試保持暫停。

## 播放器毛玻璃統一與使用者面板參考

- 播放器専用TwitchPlayerGlassSurface統一sigma6／局部clip及半透明背景，套用共用底列（直播／DVR／VOD／剪輯／全螢幕）、上方chrome按鈕及頻道資訊、離線底列和迷你footer。其他應用glass保留原平台fallback，不改播放器runtime或帳號操作。手機採真正blur，只有平台模擬證據，實機效能仍待驗證。
- 時間軸改先畫於glass後方，2高軌道中心距glass上緣1，避免glass攔截拖曳；初版中心直接貼邊使假seek點擊失敗，保留1像素安全位置後四寬度點擊與拖曳通過。新增像素fixture：紫色條60與200長度在下方相同位置的blue取樣後者較高，证明取樣隨已畫長度改變；僅近上緣暈染，不代表整片染色或真實視覺完工。
- 十二項毛玻璃／平台模擬／操作／像素測試通過，七檔唯一analyze No issues found（7.6秒）；後續追加使用者面板UI不再analyze。
- 使用者允許繼續檢查：控制列、聊天chrome、批次使用者管理與管理sheet四檔共66項mock通過（退出碼0）。不發言／追隨／私訊／執行真實管理；此數量非完整功能完成率。
- 依使用者提供Streamnook個人面板圖，現有profile改76頭像、垂直名稱與handle、簡介、日期／徽章深色分區、下方原私訊／管理操作；sheet maxWidth560、深色背景。只重排已存在資訊，不新增私人備註、暱稱、追隨或訂閱查詢。保留badge預覽、local history／thread及資料失敗重試。原測試的私訊位於名稱右側幾何要求不符合新圖，改驗證徽章在identity下方、私訊在徽章下方後，16項profile測試全部通過。新版profile尚未真實畫面確認。
- 一般App handle46836成功編譯啟動（24.9秒、同步175ms），包含毛玻璃統一；profile修改在其編譯之後，不宣稱該視窗已包含新profile。完整矩陣仍未達完成條件。

## 20秒回看斷流與控制列抖動待重現

- 使用者回報沒有VOD的20秒回看播放後斷流、控制列持續抖動，指定已登入追隨首頁第一張直播卡。新增LIMITED_REPLAY與FOLLOWING_ENTRY唯讀測試分支，要求無完整archive、回看10秒前、觀察60秒並取樣控制列高度及top、返回直播；不得以完整archive長測代替。
- 本輪唯一analyze失敗：integration_test/twitch_readonly_app_test.dart:1354 的Duration?不能指派Duration（invalid_assignment）。真實測試29777編譯失敗，診斷重跑89328同樣編譯失敗，尚未進App，不是使用者斷流重現。依限制不自行修復／重跑analyze；下一輪先處理null門檻，再驗證實際追隨第一卡是否符合limited條件。
- 定向程式觀察：limited經runtime.seekLiveBufferReplay→stable router→sequential live replay，_pipeUrl仍使用flush 1秒timeout。可能將播放器背壓當失敗，尚未取得因果證據、不改runtime。控制列抖動原因亦未證實；目前只新增診斷，沒有宣稱修復。

## 近直播20秒回看實際停滯重現

- 本輪修正測試nullable duration，以非null／大於10秒門檻後才跳轉；不要求無archive而改輸出布林，因有無VOD都會先使用20秒內的liveBuffer路徑。唯一analyze整合檔No issues found（6.7秒、退出碼0），後加截圖編譯驗證、不再analyze。
- 真實60217失敗（1分27秒、退出碼1）：追隨第一卡、hasArchive=false、直播15秒前進、回看10秒前啟動解碼通過；觀察第10秒native增量6050ms，第20秒倒退為1306ms且buffering=true，此後到60秒不再前進。控制列容器maxHeightDelta／maxTopDelta均0，不代表內部進度／字元無抖動。45秒增量要求失敗，返回直播尚未執行。使用者同步指出播一下才卡，不是剛進就卡。
- 補Flutter route RepaintBoundary截圖，真實32200重現：第10秒增量5483ms，第20秒倒退為1380ms且buffering=true，後續停滯；docs/twitch-limited-replay-observation.png已擷取並實際檢视，包括影片與控制列，時間顯示落後20秒，初始設定僅落後10秒。證明回看播放停滯及落後量擴大，尚未定位來源中斷／重接／local intra-segment seek因果。
- 更正早前推測：sequential回看沒有完整20秒影片ring buffer，_timingCache保存PTS/PCR資訊但仍重新GET片段內容；20秒是入口限制，來源為Twitch滑動playlist。若missing sequence早於playlist首項會跳到首項，playlist載入失敗沿用旧snapshot；flush 1秒timeout後可能重送已部分寫出的片段。這些是風險接線，不是本次斷流已證實根因；未修改正式播放器或UI。

## 20秒回看修復與拖曳條時間對齊

- 依使用者授權修復播放器，sequential proxy 與 stable router 移除資料 flush 的一秒期限，正常等待播放器消耗資料，避免部分片段被截斷／重送；保留原關閉與切來源機制。新增本機慢讀測試：16MiB 片段、兩秒不讀後恢復，來源只請求一次且完整接收，通過。
- 真實31372整體通過（1分27秒、退出碼0）：追隨第一卡且 hasArchive=false，回看10秒前後觀察60秒，原生位置每10秒增量10133／20283／30400／41600／53583／65717ms，取樣 playing=true、buffering=false；控制列容器高度／top變化0，返回直播狀態通過。返回後未另測10秒播放增量，亦不代表所有頻道已驗證。
- 使用者追加拖曳條對不上：原播放位置採連續時鐘，而右端點採 playlist 分段更新的時間。時間軸端點改用 controller.displayDurationFor，與播放位置同一時鐘；時間文字保留實際位置，拖曳期間固定視窗端點，避免直播推進改變同一比例的目標。
- 新時間對齊 fixture：20秒範圍內位置600秒／右端610秒對應50%，拖曳期間右端增加至620秒仍保留原595秒目標。連既有排版／毛玻璃／操作與慢讀測試共14項通過（84975、退出碼0）。非真實影片精度證據。
- 本輪唯一 analyze（兩個 proxy、慢讀測試及整合檔）無error，但有一則info：docs/twitch_live_replay_backpressure_test.dart:62 curly_braces_in_flow_control_structures，退出碼1。依限制未自行修lint或重跑；後加的時間軸修改以widget及整合編譯驗證，不宣稱已有最新版analyze。
- 含時間軸修正的真實13343再次整體通過（1分26秒、退出碼0）：追隨第一卡、hasArchive=false、20秒內回看10秒前，60秒增量60833ms，六次取樣皆 playing=true／buffering=false、容器高度／top變化0，返回直播狀態通過。此長測不直接量測影片畫面與時間文字的精確同步，也不替代fixture中的拖曳誤差斷言。

## 使用者追加：拖曳條漂移與突然落後兩分鐘

- 不以先前60秒播放通過當成時間軸修復完成。20191追加純數值診斷：真實60秒內lag維持12362ms、slider約0.38185、native增量60833ms，整體通過；此輪未重現使用者兩分鐘跳動。
- 定向檢查找到兩個舊位置重設分支：同一local replay revision的原生時間倒退／回前景會再套最初的canonical target並可能重做intra seek；播放／緩衝狀態切換會取被舊duration夾住的_position，即使positionFor已隨時鐘前進。兩者皆可在播放兩分鐘後將時間推回最初位置。
- 修正同revision的重綁保留目前canonical position及duration、不重做初始intra seek；新revision仍使用新跳轉目標。狀態切換先取當下running clock，再變更advancing，不使用過期_position重設。僅時間控制器修改，未改傳輸、登入或樣式。
- 新控制器fixture注入時間與播放器讀值：兩分鐘後原生位置倒退、回前景、控制列未重建後切緩衝三種情境，均保留當前位置，另確認新revision仍跳新目標。與既有時間軸／排版共16項通過。第一次fixture因current與Player既有current屬性衝突而編譯失敗，修正測試字段後通過；未改正式Player介面。
- 本輪唯一analyze控制器／新fixture／整合檔No issues found（6.2秒、退出碼0）。其後追加緩衝轉換修正未再次analyze，透過16項widget編譯執行驗證。三分鐘真實7689在追加修正後主動中止，不算失敗重現或成功；以60521重新編譯最新版觀察。
- 最新60521真實三分鐘整體通過（3分27秒、退出碼0）：追隨第一卡且無archive，回看10秒前；18次取樣lag維持12003ms、slider在0.3998～0.39985，180秒native增量182800ms，皆playing=true／buffering=false，新增最大lag漂移<2000ms斷言與返回直播狀態通過。這次正常播放未實際觸發native reset／緩衝，特殊分支修復證據仍為三項fixture；未宣稱已直接重現使用者視窗中的兩分鐘跳動或完整功能測試完成。

## 回看來源長度量測：不預先改本機緩存或UI

- 使用者要求先量剛進頻道可補多少，再決定20秒策略。新增docs/twitch_replay_window_probe.dart與唯讀整合REPLAY_WINDOW分支：排除prefetch、按sequence去重計算完整片段總長，並實際下載當下最舊片段；僅輸出數值、HTTP狀態與錯誤類別，不輸出私人頻道、token、URI或cookie。
- 實際App選用來源：1151第一卡三種畫質，進入／30／60秒共9次皆14段×2秒＝28秒，canonical span32秒包含兩個未計入的prefetch；最舊片段皆HTTP200且有完整內容。22454第二卡三種畫質完整範圍約29.166～29.167秒，94624第三卡三種畫質28秒，皆最舊片段HTTP200。這只是當時來源的量測，不是永久保證或完整20秒解碼回歸。
- 使用者要求5～6頻道且不要逐台重開，13403改成同一App／同一已登入API取得追隨清單六個不同頻道，web/site master各前三個非audio-only畫質，共18次探測（26秒、退出碼0）。匿名樣本0完整範圍8／10／10秒；1為29.166／29.167／29.167秒；2、3、4各三個皆28秒；5為6／8／8秒。18個最舊片段HTTP200且有內容。因此這組web/site來源不能承諾一律20秒；API新解析來源與App既有選源未必相同，短清單是否廣告替代或選源差異仍未驗證，不能以此宣稱該兩台App實際回看只剩此長度。
- 補查目前本機保存：live byte bus在beginSegment清除replay queue，只保留目前片段；sequential回看仍載入上游清單及GET片段，不消費完整20秒本機歷史。未改正式程式、帳號、快取或播放器行為。
- 本輪唯一analyze診斷helper／整合檔無error、1則info（prefer_collection_literals，當時integration_test/twitch_readonly_app_test.dart:1292；退出碼1），未修lint或重跑。後擴充六頻道探測時先有masterUri參數與file/package library重複型別編譯問題，改用正確參數及package import後13403成功；這些編譯失敗不是App卡住。六頻道probe完成不代表完整功能矩陣完成。
- flutter test會在測試結束自動關閉App，已向使用者說明不是再次停播；此後不採逐頻道重啟，正常版將重新開啟並留著。

## 2026-10-12 接續功能測試

### 第六批續測：迷你播放器與播放路由狀態

新增docs/twitch_playback_session_state_test.dart，只讀正式mini controller、playback session controller與route guard／host的相關分支，沒有正式功能修改。

```powershell
flutter test docs/twitch_playback_session_state_test.dart --reporter expanded
```

兩次均14項13通過／1失敗，exit1，測試案例約0秒完成（不包含編譯啟動）。每案setup／teardown確認TwitchMediaKitPlayerHost.playerOrNull=null；未呼叫acquire、未建立原生Player，測試中的媒體URI是fixture字串，不包含token／簽名URL。singleton owner於teardown依序unregister及clear；不改真实App程序或偏好。

- 四種kind通過entry保留：live、liveDvr、vod、clip，包含revision20、header、activeDvrVideo／vodVideo／clip、ratio=.4、preferReplayChat。live不啟用replayChat，其餘依prefer值；沒有實際媒體／回放聊天室解碼。
- 空URI不覆蓋既有entry；close(pausePlayback:false)僅清mini且保留session；close預設true清session。因nativePlayer=null，pauseShared直接return，不能以此聲稱真的暫停了播放。
- inactive查詢null／empty為false；mini有VOD entry但沒有active native session時rememberNetworkLoss／recoverAfterNetworkRestored保持entry且不建立Player。這只是guard，不是網路恢復成功測試。
- 五項route owner測試通過：hidden route的晚到state不取代top；移除hidden不改visible；top pop穿過沒有playable snapshot的owner，還原先前DVR snapshot及ratio/chat偏好；最近restore callback在重複unregister時只呼叫一次；hidden傳入none／空URI不清visible，並驗media URI匹配。
- 唯一失敗：Mini show normalizes media URI for subsequent identity matching。show(revision1, metadata fixture, mediaUri=' fixture-live ')後，isActiveMediaUri('fixture-live')實際false。mini.showPlayback先trim判空，但entry.playback仍保存原mediaUri；比較方法只trim查詢值。此為入口資料正規化的單元問題，正常session controller.setPlayback會trim；未證明真實路由傳入空白，也不把它當直播停頓根因。
- 初版有一項測試名稱不準確，原稱surface transfer但只測null／empty identity；本輪改為Inactive mini rejects null and empty URI identities，沒有新增虛假的surface移交覆蓋。一次擴充patch因format後anchor不合而未套用；未追加該兩個案例，不將未執行工作列為通過。
- 仍待：keep-mini=false的正式偏好／leave接線、mini拖移及原生surface transfer、DVR／VOD／clip的實際位置返回、原生network loss／restore與route guard可見性。目標仍未完成。
- 本輪唯一analyze只檢查新測試：No issues found，8.9秒、exit0；不代表全repo或整體播放器已驗證。

### 第五批續測：分類／語言選單與合成捲動分頁

只擴充docs/twitch_browse_page_flow_test.dart與紀錄，未改正式UI／登入／協議。新增7項範圍定向為4通過／3失敗；整檔21項為15通過／6失敗（6秒、exit1），其中3項沿用前輪已知失敗，不累加不同執行為新的測試覆蓋。

```powershell
flutter test docs/twitch_browse_page_flow_test.dart --name "Filter |Scroll near" --reporter expanded
flutter test docs/twitch_browse_page_flow_test.dart --reporter expanded
```

- _mount新增可選pageKey，僅在選單案例加測試自有AppBar按鈕，呼叫正式state.showGameMenu／showLanguageMenu。fake新增games請求記錄；其他原有案例仍使用同ValueKey與原本無AppBar的fixture。這不是完整首頁工具列／訪客啟動驗證。
- 分類1000／390寬兩項通過：進正式sheet，在正式輸入框搜尋Game A，點選官方卡片，確認selectedGameId=g-a及browse請求game=g-a；再開sheet，點底部TextButton「全部分類」，兩者恢復null且games只讀一次。初版find.text('全部分類')同時命中卡片與底部按鈕造成fixture失敗，改成精確TextButton後通過，沒有改正式UI或關閉警告。
- 分類分頁通過：初始30筆／cursor=next-games；實際tester.drag官方GridView(-30000)觸發載入，mock503保留前綴；點「載入分類失敗，重試」以同cursor成功，重疊game-0去重後共31筆且hasMoreGames=false。requests=[null,next-games,next-games]。不是直接呼叫loadMoreGames冒充捲動。
- 瀏覽捲動通過：初始100筆／cursor=next，tester.drag正式CustomScrollView(-50000)觸發下一頁；mock503保留100筆，點「載入更多失敗，重試」後101筆／cursor耗盡，requests=[null,next,next]。fixture沒有真實HTTP、沒有帳號写入。
- 新固定失敗：Filter game initial failure retry reloads the first page。初始games讀取503，開sheet時又503，共兩次；恢復mock後點可見重試，測試154行期望請求3次，實際仍2次。官方sheet footer的273行呼叫requestMore→browse.loadMoreGames；browse348行發現nextGameCursor=null，設定hasMoreGames=false後直接return。初始失敗沒有游標，必須重載第一頁而非下一頁，正式程式尚未修正；後續Recovered game斷言未執行，不能計通過。
- 語言兩寬度固定失敗：正式sheet輸入zh搜尋、選中文、關閉不改狀態／請求、清全部語言等斷言有執行；最後測試252行takeException收到多則ListTile background color or ink splashes may be invisible（此次一案摘要34則）。ListTile selected/background會被上層帶色DecoratedBox蓋住，與前輪設定頁警告同類。未抑制FlutterError，不把功能斷言先前有過當成整項通過，也不稱其為release崩潰。
- 前輪的browse來源替換與舊分頁晚到成功／失敗三案仍失敗；本輪未修。分類／語言設定之後的實際上游內容、首頁入口、真實帳號路由與播放器流程仍待驗。
- 唯一analyze僅此測試檔：無error／warning、1 info（312:11 curly_braces_in_flow_control_structures），9.9秒、exit1。依限制不重跑，沒有為了消除info額外改正式功能。

### 第四批續測：公開瀏覽頁、舊分頁競態與来源替換

本輪新增 docs/twitch_browse_page_flow_test.dart，擴充 docs/twitch_channel_media_page_test.dart 的 fake label／來源替換案例；只改測試與報告，沒有修改正式登入／UI／播放器。上一輪是具體進度，本輪接續缺漏項而非把相同綠色結果重複累積。

```powershell
flutter test docs/twitch_browse_page_flow_test.dart docs/twitch_channel_media_page_test.dart --reporter expanded
```

最新合併 28 通過、8 失敗（5 秒、exit 1）：browse 11／3、media 17／5。初版 browse 10／1 是中途結果；media 原有三個問題仍重現，不作新增問題計數。

- 正式 TwitchStreamPage 沒有可注入 fake 的入口，initState 直接建立 auth、discovery、帳號通知及播放器等服務。因此本輪不冒充完整首頁／App 訪客隔離；直接掛正式 TwitchBrowsePage，未預期 API 呼叫一律拋錯，僅容許公開 browse、games、profile fixture，登入 callback 計數為零，不接觸原帳號。搜索條件由父層參數提供，不聲稱測過真實首頁搜尋輸入及私人 _TwitchChannelSearchPage。
- browse 11 項通過：1000／390 寬直接顯示公開卡片且無 TwitchLoginRequiredView；實際 model TwitchApiException(statusCode:401／503) 的 fake 失敗可點「重新整理」恢復，沒有要求登入（不是 HTTP transport 整合）；搜尋空结果及搜尋失敗提示不同；初始請求離頁後成功／錯誤皆忽略；新 refresh 完成後舊初始請求的成功／錯誤皆忽略；初始100筆、第二頁含重疊 ID，去重後101筆且無 cursor。
- 新失敗一：Refresh rejects a late old pagination response: error=false。先初始100筆／cursor=next，啟動等待中的 loadMore，refresh 清空並完成 fresh0／fresh1，再完成舊分頁 stale0／stale1。當時測試270行發現畫面資料變成 fresh0／fresh1／stale0／stale1。loadMore 的正式合併位於 twitch_browse_page.dart:300，只有 mounted 防護、沒有 refresh generation 防護。
- 新失敗二：同案例 error=true。新 refresh 已成功後，舊分頁的 TwitchApiException(statusCode:503) 仍寫入 paginationError（正式312行）；當時測試271行期待 null 失敗。前述兩案使用公開 state.refreshStreams／loadMore 控制 future 順序，是完整頁面狀態的競態證據，不是捲動手勢或真實 HTTP 斷線重現。
- 新失敗三：Replacing discovery source reloads the retained browse page。同 ValueKey 保留 state、reloadTick 不變、discoveryService 物件換新後，新來源 requests=[]，仍保留舊資料。didUpdateWidget 正式124～132行只檢查 reloadTick。實際帳號變化是否透過首頁 reloadTick 補刷新未在此案驗證，因此不把來源物件替換直接認定為登入判定根因。
- 新失敗四／五：VOD／clip replaces retained media when discovery source changes。保留相同 TwitchChannelPage state，將來源換成回傳 Fresh media 的 fake，新的 calls=[]，沒有重讀；正式媒體頁無 didUpdateWidget 來源替換處理。測的是同頻道不同 service 物件，不是已登入使用者實際換帳號或跨頻道導航；該更大範圍仍待驗。
- 舊三項媒體失敗（VOD／clip 重疊 ID 與844×260 sheet clamp）仍存在；沒有修正式程式，也沒有改斷言使它通過。其餘媒體17項仍通過，故擴充後是17／5。
- 唯一 analyze：兩份本輪修改測試無 error／warning，1 info（媒體helper open 使用 _Discovery 私有參數型別，89:3 library_private_types_in_public_api），11.3秒、exit1。依規則不再次執行。
- 下一步仍需分類／語言選單、捲動／實際來源身份切換導頁、完整訪客首頁隔離及播放器整合。新增失敗保留可重現測試，完整目標保持未完成。

### 第三批續測：聊天鍵盤／背景與完整媒體庫 mock

本輪只新增媒體頁測試與紀錄，沒有正式程式修改，也沒有真實帳號寫入。

```powershell
flutter test docs/twitch_chat_mention_test.dart docs/twitch_chat_message_keyboard_test.dart docs/twitch_chat_keyboard_storage_test.dart docs/twitch_android_background_test.dart --reporter expanded
flutter test docs/twitch_channel_media_page_test.dart --reporter expanded
```

- 第一組 29 項全部通過，5 秒、exit 0。測試實際合成鍵盤事件，但 callbacks／MethodChannel／SharedPreferences 都隔離；不能代表真實管理或 Android 原生 permission／背景服務成功。
- 新媒體檔第一版 14 項有 12 通過、2 失敗；擴充後最新 20 項有 17 通過、3 失敗（4 秒、exit 1）。只引用最新版，與 29 項合計本批 46 通過、3 失敗，不把中途結果重複加總。
- Fake discovery 以 implements 覆寫 media／about 讀取，其餘 noSuchMethod 一律拋錯；卡片 URL／圖片為空，未點影片播放或外部連結，不建立 client／不接觸登入。測試是真正公開 TwitchChannelPage、原 media sheet 入口、TextField／TabBar／FilledButton 點擊，而非重做假 UI。
- 17 項通過覆蓋 VOD 與 clip 1000、390 寬的命中搜尋／空結果／清空，且不多發 API；首次讀取失敗以可見「重試」重載；第二頁失敗仍保留第一頁、同 cursor 重試後耗盡；等待第二頁時停用按鈕且再次點擊不再請求；離頁後成功或拋錯都不 setState；切換 VOD／片段保留不同搜尋並只讀取各一次。1000×900、390×844 的按鈕開啟／sheet 範圍／點關閉也通過。
- 兩個固定失敗：VOD overlapping page never renders duplicate media IDs、clip overlapping page never renders duplicate media IDs。第一頁 IDs 1／2，第二頁 IDs 2／3，UI 找到兩個 Media item 2（新測試 193 行）。正式 _loadVideos／_loadClips 在 01_channel_media_library_dialog.dart:258／297 直接將新清單 append，未依 ID 去重。這兩個是假資料可重現頁面問題，不是當次真實 API 的重複記錄；原實際樣本無重複不能代表對重疊分頁有保護。
- 第三個固定失敗：Media sheet opens and closes within viewport Size(844.0, 260.0)。點 Open media 時 01_channel_media_library_dialog.dart:23 的 .clamp(360.0, viewport.height) 下界大於上界，拋 Invalid argument(s): 360.0，沒有 TwitchChannelPage 出現。不是搜尋沒資料或 HTTP 失敗；不修正式程式、不降低 test 視窗高度要求。
- 仍缺：媒體卡片導航／播放的全 App mock、不同頻道／來源更換時的資料隔離、真實畫質／拖曳／回放聊天室、對重複 cursor 的頁面策略；本輪通過不當成完整媒體功能完成。
- 本輪唯一 analyze 僅新媒體測試：無 error／warning、1 info（88:3 library_private_types_in_public_api，測試 helper open 的參數使用 _Discovery），10.3 秒、exit 1。依規則不重跑；下一輪可將此測試 helper 改為私有，與正式程式無關。

### 後續續測：訪客實際 API、更新 service、私訊 fixture

下方四批 456／11／2 是首輪原始結果，保留失敗證據；以下是後續狀態，不直接累加重跑案為新的覆蓋數。

- `flutter test docs/twitch_guest_media_test.dart --dart-define=TWITCH_GUEST_LIVE_TEST=true --name "^real " --reporter expanded`：兩個原先跳過的真實 API 案全部通過，4 秒、exit 0。每個請求都檢查沒有 Authorization header，沒有讀取／清除原帳號登入。包含 browse（有 cursor 時第二頁）、搜尋 papaplatte、當下直播、games；公開 VOD userId 233741947／50985620／31239503／43683025、clip 50985620、profile papaplatte／eslcs。這是公開服務證據，不是訪客全頁／VOD 解碼。
- 新增 `docs/twitch_update_service_test.dart`，分別以 `--dart-define=VIOCLASS_VERSION=1.2.3 --dart-define=VIOCLASS_UPDATE_CHANNEL=stable` 及 `beta` 執行：stable 10、beta 12 項全通過。每個 Dio request 都被本地 interceptor resolve／reject；沒有實際 Github 查詢、下載、檔案建立或安裝。
- service 覆蓋數字版本增減／相等／省略 patch／忽略 build metadata，平台 asset 解析，缺 preferred asset 在碰 filesystem 前拒絕、網路失敗重試；beta endpoint／per_page、排除 drafts／空版本、選取最高數字版本、空清單拒絕。沒有把數字版本測試當完整 SemVer：同一數字版本下 beta.1／beta.2／stable 優先順序及其他 prerelease 規則仍未驗證。
- 私訊只改 fixture／斷言。同步錯誤案仍確認 controller 收到 fake 原始錯誤，但 UI 斷言跟隨現有友善文案；後續重試、取消、草稿保留等原有斷言不刪除。通知兩案使用 Windows override、window_manager channel 僅容許 isMaximized／isFullScreen，其他调用立即失敗，確認 api.sent=0。panel 案先 hideToast，再點 InkWell 入口並確認面板重新顯示目標，不誤把 toast 點擊當 panel 通過。
- 中途初版 Windows fixture 忘記在 test body 完成前重設 debug platform，導致框架 debug variable invariant 失敗；通知 icon 中心也可能被 badge 覆蓋，改點真正 InkWell ancestor。沒有關閉 hit-test 警告、沒有改正式 UI，也沒有刪除驗證。最新六個同步／通知案定向重跑 6 通過、exit 0（3 秒）。
- 最新 `flutter test docs/twitch_whisper_inbox_test.dart --reporter expanded`：168 通過、3 失敗，37 秒、exit 1。仍失敗的兩項固定案例是 Production inbox starts at tail without seeking and history sync preserves pixels、Unsaved accepted receipt status stays distinct at Size(1000.0, 760.0)。另 cache cleanup 10 秒 timer 這次在 desktop composer 出現、phone composer 通過，前輪則相反；保留間歇性 fixture 問題，不推論 App timer 洩漏。六個更新案在整檔重跑也通過。
- 此續測主要執行合計 192 通過、3 失敗（168 inbox＋22 service＋2 真實訪客）；六項定向結果不重複計數。前輪設定頁／更新 controller dispose 的失敗沒有修正或重跑，仍有效，整體功能矩陣並未完成。
- 唯一 analyze 檢查本輪兩份修改的 Dart 測試：No issues found（9.2 秒、exit 0）。沒有重跑前輪 controller fixture 的 warning，也不宣稱全 repo 靜態檢查通過。

### 首輪原始紀錄

本輪只補測試與證據，未修改正式功能／UI／憑證。四批不重複計數共 456 通過、11 失敗、2 跳過；定向重跑僅用於確認可重現性，不加入通過總數。未使用系統滑鼠、未重啟正常 App、未執行真實帳號寫入或更新安裝。檢查時未找到前輪 PID 28016，也未找到 vioclass／vio_class 同名程序，不據此聲稱 App 仍在前景或仍正常播放。

### 批次及範圍

| 批次 | 檔案（均在 docs/） | 結果 |
| --- | --- | --- |
| 私訊與聊天活動 | twitch_whisper_inbox_test.dart、twitch_whisper_api_test.dart、twitch_whisper_eventsub_test.dart、twitch_user_role_actions_test.dart、twitch_moderation_api_test.dart、twitch_automod_queue_test.dart、twitch_chat_event_ui_test.dart、twitch_chat_identity_api_test.dart | 256 通過、9 失敗，37 秒、exit 1 |
| 管理與通知 | twitch_moderation_batch_test.dart、twitch_moderation_batch_panel_test.dart、twitch_moderation_user_batch_panel_test.dart、twitch_moderation_message_actions_test.dart、twitch_automod_settings_test.dart、twitch_blocked_terms_test.dart、twitch_notification_expiry_test.dart、twitch_notification_style_test.dart | 103 通過，18 秒、exit 0 |
| 訪客、設定與其他聊天室功能 | twitch_guest_mode_test.dart、twitch_guest_media_test.dart、twitch_login_navigation_errors_test.dart、twitch_app_chat_keyboard_settings_test.dart、twitch_moderation_log_api_test.dart、twitch_moderation_log_controller_test.dart、twitch_moderation_log_panel_test.dart、twitch_moderation_log_eventsub_test.dart、twitch_pinned_chat_management_test.dart、twitch_chat_identity_panel_test.dart、twitch_emote_picker_flow_test.dart | 89 通過、1 失敗、2 跳過，12 秒、exit 1 |
| 新增更新控制器 | twitch_update_controller_test.dart | 8 通過、1 失敗、exit 1；全新 fake service／installer／SharedPreferences，File 僅為路徑物件、不建立檔案 |

### 可重現失敗與分類

私訊定向重跑：

```powershell
flutter test docs/twitch_whisper_inbox_test.dart --name "Production inbox starts|Unsaved accepted receipt status|Inbox failure retry|History failure keeps|private notification opens|Private composer aligns" --reporter expanded
```

結果 4 通過、8 失敗，6 秒、exit 1。以下行號為此次執行時測試檔位置，未修改既有測試或放寬斷言。

- Production inbox starts at tail without seeking and history sync preserves pixels：633 行找不到訊息清單下的 Scrollable。正式 _messageScroll 仍有 whisper-message-list key；尚不能判定是同步／選取 fixture 未到訊息畫面，還是正式路徑問題。原本像素保持及同步後斷言未執行，不計為通過。
- Unsaved accepted receipt status stays distinct at Size(1000.0, 760.0)：1358 行捕捉到 RenderFlex 右側溢出 10 pixels，重跑仍出現；同案手機寬度通過。這是可重現排版問題，尚未定位到精確 Row，不以 fixture 過時排除。
- Inbox failure retry and cancel remain usable，1000×760、390×844、390×260：2612 行期待 fake inbox unavailable，但正式 sheet 現在顯示「對話同步失敗，請稍後再試。」（twitch_whisper_sheet.dart:1187）。三案皆重現；屬錯誤文案斷言落後，後面的重試／取消未執行，不能推論互動通過。
- History failure keeps draft and retry without profile or deletion actions：3109 行期待 fake history unavailable，但正式 sheet 顯示「訊息同步失敗，請稍後再試。」（1472 行）。同樣是舊文案斷言；草稿保留及後續重試仍需以現況重驗。
- private notification opens exact conversation from toast／panel：3435／3432 行找不到 toast／按鈕。這兩案沒有設定平台 override；widget test 預設 Android，而正式 overlay 的 Android 分支刻意直接回傳 child，不顯示 App 內通知。不能據此認定 Windows 通知壞掉，也尚未補上 Windows window_manager mock 重驗點擊。
- Private composer aligns controls and shares vertical categories at Size(390.0, 844.0)：整批一次出現 flutter_cache_manager CacheStore cleanup 10 秒 timer 未清理；定向重跑同案通過。fixture 已嘗試在真實 async 啟動 housekeeping，仍保留間歇性清理問題，不歸因為正式 App timer 洩漏。

設定頁失敗可單獨重現：

```powershell
flutter test docs/twitch_app_chat_keyboard_settings_test.dart --reporter expanded
```

92 行的 takeException 收到 ListTile background color or ink splashes may be invisible。前面的 fake 偏好保存斷言有執行，但整體仍失敗，桌面／手機雙布局測試不能算完整通過。

更新生命週期失敗可單獨重現：

```powershell
flutter test docs/twitch_update_controller_test.dart --reporter expanded
```

Disposed download never dispatches a late installer：下載 future 尚未完成時 dispose，再完成 fake download，installUpdate 的 progress callback／finally 仍 notifyListeners；此次 stack 指向正式 vioclass_update_controller.dart:142，拋 used after being disposed，未正常回傳 false。正常完成、重複呼叫、下載／安裝錯誤重試另 8 項通過。沒有真的啟動 installer，更不能把此結果說成 OS 安裝成功。

### 仍待補

先修正或更新上述可重現問題並補同範圍回歸，再驗完整訪客／切換帳號頁面、VOD／剪輯真實拖曳與畫質、迷你播放器返回狀態、設定頁其餘面板、網路錯誤恢復及 profile 效能。兩個真實訪客 API 案因未開 TWITCH_GUEST_LIVE_TEST 跳過；本輪只有隔離元件／API mock，不新增真實播放或完整頁面完成結論。

本輪唯一 flutter analyze 僅檢查 docs/twitch_update_controller_test.dart：無 error、1 warning（83:23 invalid_use_of_visible_for_testing_member，setMockInitialValues 位於 docs/ 未被 analyzer 視為標準 test 目錄），6 秒、exit 1。依規則不重跑；下一輪可依既有 docs fixture 的方式加入局部測試用途註記。此結果不代表全部測試或 repo 靜態檢查通過。

## 六頻道三輪具名重測：實際App來源與web/site分開

- 使用者授權記錄頻道。1652同一個App程序中固定六台、各重測三轮；每次重新開啟實際watch route取目前選用的來源，另以同一登入解析web/site master比較。六台×三輪×兩種context×三個畫質＝108次，所有最舊片段HTTP200且有完整內容，整合退出碼0（2分51秒）。沒有逐台重開App、沒有帳號寫入；三輪間隔是依序測完六台再開始下一輪，不是固定30秒。
- 台北時間2026-10-11 23:47:38～23:50:19。完整72筆具名結果／108次片段探測存在docs/twitch-replay-window-measurements-2026-10-11.json，包含UTC時間、sourceTag、prefetch數、完整窗口、廣告標記及HTTP／bytes；不保存token、cookie或簽名URI。

| 頻道login | App實選ios-site三輪完整窗口 | web/site第1輪 | 第2輪 | 第3輪 |
| --- | --- | --- | --- | --- |
| sam1268 | 每輪28秒 | 8～10秒，含廣告標記 | 28秒，無廣告標記 | 28秒，無廣告標記 |
| roger9527 | 每輪28秒 | 28秒 | 28秒 | 28秒 |
| mobilmobil | 29.167／29.166／29.167秒 | 29.166～29.167秒 | 29.167秒 | 29.167秒 |
| kspksp | 每輪28秒 | 28秒 | 28秒 | 28秒 |
| never_loses | 每輪28秒 | 28秒 | 28秒 | 28秒 |
| blusewilly_retry | 每輪28秒 | 8～10秒，含廣告標記 | 8秒，含廣告標記 | 8～10秒，含廣告標記 |

- 因而更正解讀：前輪web/site短清單不能直接推論App實際20秒回看不足。這批App實選54次皆無本probe所檢查的廣告標記、完整窗口28～29.167秒；相同sam1268的web/site會隨輪次由短且帶廣告標記切回28秒，確認每次來源狀態可能不同。舊匿名輪次追隨排序不同，不能倒推其全部頻道名稱。
- 此為清單窗口及最舊片段下載證據，不是108次完整影片解碼／任意拖曳，也不是所有頻道永遠至少20秒的保證。建議先維持現有上游回看，不因web/site廣告清單直接新增本機緩存；若未來App fallback改用短來源，应依實際可用範圍處理，尚未實作。
- 本輪只改診斷helper、整合測試與紀錄／報告；正式播放器、UI與帳號邏輯未變。唯一analyze無error、2則prefer_collection_literals info（當時整合檔1389／1418、退出碼1），未修lint／重跑；其後將web探測改用每個仍存活route的API物件，以整合編譯與執行驗證。
