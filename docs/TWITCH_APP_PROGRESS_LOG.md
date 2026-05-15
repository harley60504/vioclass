# Flutter Twitch App 開發紀錄（持續更新）

## v54 - Responsive Mobile Layout / Sheet Template

- 播放頁改為用螢幕比例判斷 layout，不再只看寬度。
- 手機直向：聊天室在影片下方。
- 手機橫向 / 平板 / 桌面：聊天室在影片右側。
- 聊天室開關狀態加入 SharedPreferences 記憶。
- Following / Browse 首頁側邊欄在窄螢幕改為 icon rail。
- 登入頁改成可捲動，次要登入按鈕收進「更多登入選項」。
- 新增共用 `TwitchResponsiveSheet`，統一貼圖、忠誠點數、下注、訂閱等彈窗行為。
- 新增共用 `TwitchResponsiveLayout`，集中管理手機直向、手機橫向、平板、桌面的 RWD 判斷。

## v53 / v52 - Mobile Overflow / Control Bar 修正摘要

- 修正手機窄螢幕聊天室底部 overflow。
- 修正 controller bar 不自動隱藏與跑出畫面問題。
- 窄螢幕控制列改成較緊湊排版。
- 保留音量記憶與聊天室寬度記憶。

---

## Stage v55 — Responsive Sheet 統一、登入 WebView 精簡、聊天室輸入列折疊

- 強化 `showTwitchResponsiveSheet`：手機直向 bottom sheet、手機橫向 compact centered dialog、統一 maxWidth / maxHeight / keyboard inset。
- 官方 emote ID 確認、賭盤下注、忠誠點數 sheet、登出確認逐步收斂到同一套 responsive sheet 行為。
- 手機內嵌 OAuth WebView 移除過寬工具列，減少橫向小螢幕 overflow 與高度佔用。
- 聊天室輸入列改成可折疊，預設顯示小型 prompt，需要輸入時再展開完整 TextField + Send。
- 手機橫向聊天室寬度降低：一般最小寬度降為 260，橫向模式約佔 34%，限制在 220～310。
- 修正 OAuth WebView 頁面重複 `initialSettings` 的潛在編譯問題。


## Stage v56：手機橫向拖曳與垂直 compact 修正
- 手機橫向保留聊天室拖曳功能。
- 聊天室寬度改用比例限制與比例記憶。
- 移除輸入列折疊邏輯，改為垂直空間不足時自動變扁。
- 壓縮聊天室 header、utility bar、engagement strip、input bar 的高度。
- 目標是降低橫向手機與小鍵盤開啟時的 overflow。


## Stage v57：Sheet 壓縮、橫向滿高、瀏覽篩選二級選單
- 共用 responsive sheet 橫向改成接近滿高。
- 新增共用 sheet header：搜尋 / 重新整理 / 關閉。
- 貼圖 sheet 移除上方大 header，搜尋列併入 header。
- 忠誠點數與下注 sheet header 壓縮。
- 置頂留言與 engagement strip 進一步變矮。
- 瀏覽頁語言與遊戲類型改成共用 sheet 的二級篩選選單。


## Stage v58：瀏覽篩選整理與貼圖 Sheet 風格修正
- 修正瀏覽頁 `_BrowseHeader` 漏傳 required 參數。
- 移除舊 `_GameStrip` 顯示區，避免和二級選單重複。
- 篩選 sheet 內遊戲分類改成 grid / 瀑布流式排列。
- 忠誠點數內部選擇貼圖 overlay 移除 title/subtitle，只留搜尋、重新整理、關閉。
- 一般貼圖 sheet header 改回較接近忠誠點數 sheet 的風格。
- 統一貼圖與忠誠點數 sheet 的主要字級。


## Stage v59：修正瀏覽頁 GameWaterfallSelector Build Error
- 補上 `_GameWaterfallSelector` 與 `_GameFilterTile` class。
- 移除主畫面舊 `_GameStrip` 呼叫，避免瀏覽頁出現兩套遊戲選單。


## Stage v60：聊天室字體設定、Design System 分類、Reward/Grid 本地化
- 新增 design / settings / localization 分類檔案，方便後續維護。
- 新增聊天室字體調整 sheet，支援 slider、預覽、保存。
- 聊天訊息、badge、emote 跟著 fontScale 縮放。
- 忠誠點數 reward 改為 grid/table 顯示並補基礎中文翻譯。
- 瀏覽頁熱門語言增加，遊戲載入數量提高，遊戲 grid 更接近貼圖表格。


## Stage v61：修正聊天室字體設定 Compile Error
- 補齊 `TwitchChatMessageList.compact` 參數。
- 補齊 `TwitchRuntimeMessageTile.compact` 與 metrics compact factor。
- 補齊 `TwitchWatchChatPanel` 的 `_appearanceController`、initState、dispose。
- 字體 slider 調整後可即時刷新聊天室列表。


## Stage v62：修正 v61 Import 與 compact 參數同步錯誤
- 修正聊天室外觀 controller import 字串錯誤。
- 重新整理 `TwitchChatMessageList.compact` 宣告與 constructor。
- 重新整理 `TwitchRuntimeMessageTile.compact` 宣告與 constructor。
- 重新整理 `_ChatMessageVisualMetrics` compact factor。


## Stage v63：修正 LiveMessageDivider compact 未初始化
- 移除 `_LiveMessageDivider` 中誤加的 `final bool compact;`。
- 修正 Windows build 的 final field not initialized error。


## Stage v64：Sheet 搜尋列、Reward Overflow、遊戲分類載入更多、聊天室最小寬度修正
- 移除貼圖 sheet 上方小搜尋欄，保留下方主要搜尋欄。
- 主要搜尋欄高度與字體縮小。
- 忠誠點數 reward grid 高度加大並壓縮 tile 內容，降低 overflow。
- 遊戲分類 selector 加入滾到底載入更多。
- 聊天室最小寬度改為比例限制 + 最大有效最小寬度，桌面可縮更窄。


## Stage v65：修正遊戲分類載入更多分頁
- `fetchTopGames()` 改為支援 `after` cursor。
- 新增 `TwitchGamePageResult`。
- 遊戲分類載入更多改成真正 pagination，不再靠 first 變大。
- 遊戲分類 sheet 依照 `hasMoreGames` 顯示載入更多。


## Stage v66：忠誠點數卡片與篩選選單視覺重整
- 忠誠點數 reward 改成圖片在上、文字在下的 grid card。
- 兌換點數改到右上角 overlay chip。
- 移除內建/自訂/需輸入/需貼圖/需選效果等功能標籤。
- 語言篩選改成可收合，預設只顯示部分常用語言。
- 遊戲分類改成大圖卡片，全部直播也作為第一張卡片。


## Stage v67：修正 Channel Points compact 變數誤用
- 修正 `_StatusChip` / 非 `_CostChip` widget 誤用 `compact` 造成的 build error。
- 保留 `_CostChip` 右上角點數 chip 的 compact 字體。
- 移除 watch page 兩個未使用 local variable。


## Stage v68：徹底修正 StatusBadge compact 殘留
- 修正 `_StatusBadge` 裡殘留 `compact` 造成的 build error。
- `_StatusBadge` 改回固定字體大小與字重。
- `_CostChip` 的 compact 字體邏輯保留。


## Stage v69：遊戲分類無按鈕連續滾動與忠誠點數卡片填滿
- 遊戲分類移除固定 420 高度，改吃篩選 sheet 剩餘高度。
- 移除載入更多卡片，改為滾到底自動載入。
- grid 不足高度時自動補載下一頁。
- 忠誠點數卡片圖片放大、文字加大、卡片比例調整。


## Stage v70：下注可滾動、忠誠點數按鈕數字、Overlay 簡化、輸入列對齊
- 調整聊天室互動區高度，prediction / pinned 同時存在時可滾動避免裁切。
- 聊天室粉紅忠誠點數小按鈕顯示短數字：k / w / b。
- sheet 內忠誠點數與 reward cost 使用完整加逗號數字。
- 忠誠點數 reward 卡片圖片置中並放大，文字區置中。
- 解鎖 / 修改貼圖 overlay 移除 title 和 subtitle，只留搜尋/刷新/關閉。
- 聊天室輸入框與 Send 按鈕高度及上下 padding 對齊。


## Stage v71：忠誠點數 overflow 修正、聊天輸入列外框、Prediction 簡化、自動隱藏重開
- 修正粉紅忠誠點數按鈕的短數字，`9,990` 不再顯示成 `10k`，改為 `9.9k`。
- 聊天輸入框與 Send 按鈕高度抽成固定常數，外框更清楚，字與 icon 置中。
- 忠誠點數 reward card 再加高並壓縮內容，降低 bottom overflow。
- Prediction outcome 卡片只保留點數 / 人數 / 倍率。
- Prediction 自動隱藏後，手動再打開也會重新啟動 auto-hide。


## Stage v72：底部輸入區整合、自動高度、Twitch 貼圖二級分類、Reward Grid 高度穩定化
- 聊天室底部工具列與輸入列整合成同一個 composer dock。
- 輸入框與 Send 按鈕高度改由字體與 textScaler 自動計算。
- TextField 依據 controlHeight 計算垂直 padding，改善文字不置中。
- 忠誠點數 reward grid 改用 mainAxisExtent，降低 bottom overflow。
- Twitch 官方貼圖加入二級分類：我的可用 / 實況主 / 全部共用，避免一次渲染太多貼圖。


## Stage v73：輸入列自製對齊、遊戲篩選圖案縮小、Top Games Cursor 持續讀取
- 輸入框與 Send 按鈕改用同一個自動計算 controlHeight。
- TextField 根據 controlHeight 計算垂直 padding，改善文字對齊。
- 遊戲篩選卡片縮小，box art 請求尺寸降為 136x182。
- Top Games 載入更多改成每頁 100，依照 cursor 持續讀到沒有下一頁。
- 遊戲 grid 底部加入載入 / 錯誤 / 全部載入狀態 tile。


## Stage v74：輸入列自繪對齊、遊戲分類小卡片、官方 API 分頁結論、聊天室拖曳優化
- 聊天輸入框改為自繪外殼 + collapsed TextField。
- Send 按鈕改為 Material/InkWell 自繪膠囊，不再使用 FilledButton。
- 遊戲篩選 sheet 提高高度，遊戲格子縮小並增加欄數。
- 遊戲分類 API 持續使用 official cursor pagination，每頁 100。
- 聊天室拖曳時不再每次 update 排程儲存，改為拖曳結束再保存。
- 聊天室拖曳寬度改用目前 state 寬度加 delta，改善不跟手。


## Stage v75：輸入文字置中重寫與 Top Games 預抓修正
- 輸入框內部從 TextField 改成 EditableText，placeholder 由 Stack 自繪。
- 避免 TextField/InputDecorator hidden padding 造成 placeholder 不置中。
- 初始 Top Games 改為 first: 100。
- 修正預抓呼叫時機，等 _loadingGames=false 後才預抓。
- 預設背景預抓到至少 300 筆或最多 4 頁。


## Stage v76：遊戲分類改為每頁 50，純滾到底載入
- 移除 `_prefetchMoreGames()` 背景預抓。
- 遊戲分類初始與後續分頁都改為每頁 50。
- 滾動載入判斷改用 `position.extentAfter <= 160`。
- 只有使用者實際滾到底附近才載入下一頁。


## Stage v77：修正遊戲分類 Sheet 沒有接上載入後更新
- 找到根因：filter sheet 是獨立 route，parent setState 更新 games 後，已開啟 sheet 不會自動吃到新 games。
- `_loadMoreGames()` 改為回傳 `_GameLoadSnapshot`。
- `_openFilterSheet()` 改用 StatefulBuilder 維護 sheet local state。
- sheet 滾到底載入後，直接把 snapshot 寫回 sheet local state，UI 立即更新。


## Stage v78：修正 GameLoadSnapshot 型別錯誤與輸入實際文字偏高
- 修正 `_GameWaterfallSelector.onLoadMore` 型別，改回 `Future<void> Function()`。
- `_BrowseHeader.onLoadMoreGames` 保持 `Future<_GameLoadSnapshot> Function()`，用於 parent 回傳最新 games snapshot。
- 修正 build error：`Future<void> Function()` 不能傳給 `Future<_GameLoadSnapshot> Function()`。
- 調整 `EditableText` lineHeight 與 top compensation，改善實際輸入文字偏高。


## Stage v79：聊天室輸入同一渲染、遊戲分類搜尋、聊天室複製、播放器資訊標籤
- 聊天室輸入框改回 TextField，同一套 renderer 顯示 hint 與實際輸入。
- 使用 strutStyle + forceStrutHeight + 公式計算 contentPadding 控制置中。
- 遊戲分類 sheet 新增搜尋欄。
- 聊天室訊息支援長按 / 右鍵複製。
- 瀏覽頁進入播放器時傳入遊戲類型與觀看人數。
- 播放器上方標籤列新增實況人數與遊戲類型，遊戲類型可點擊複製。
