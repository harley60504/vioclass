# streamnook_responsive_vertical_compact_v56_notes

更新時間：2026-05-15 02:36:32

## Stage v56：手機橫向拖曳與垂直空間壓縮修正

### 修改目標
- 手機橫向聊天室拖曳功能不能被拔掉。
- 聊天室寬度限制改成「比例限制」，所有平台一致使用比例邏輯。
- 聊天室輸入列不再折疊，改為在垂直空間不足時自動變扁。
- 針對手機橫向與小鍵盤彈出時的上下高度不足問題，降低 header、utility bar、input bar、engagement strip 的垂直佔用。
- 減少手機橫向時因高度太窄造成的 overflow。

### 主要修改檔案
- `features/twitch/presentation/pages/twitch_watch_page.dart`
- `features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`

### 具體變更

#### 1. 聊天室寬度拖曳
- 手機橫向不再隱藏拖曳把手。
- 拖曳功能在桌面、平板、手機橫向都可用。
- 聊天室寬度新增 ratio 儲存：
  - `twitch_watch_v3_chat_panel_ratio`
- 舊版 pixel width 仍保留作為 fallback。
- 寬度限制改為 viewport ratio：
  - 最小約 22%
  - 最大約 48%
- 避免手機橫向聊天室固定佔掉半個畫面。

#### 2. 聊天室輸入列
- 移除上一版的折疊輸入列邏輯。
- 改成在手機橫向、低高度、小鍵盤開啟時自動進入 compact input。
- compact input 變更：
  - 輸入框高度降低
  - 垂直 padding 降低
  - Send 按鈕改成 icon-only
  - hint text 縮短
  - 字體略縮小
- 目標是保留輸入功能，但降低它對上下高度的佔用。

#### 3. 聊天室面板垂直壓縮
- 手機橫向或高度不足時：
  - Header 高度降低
  - Utility bar 高度降低
  - Prediction / pinned engagement strip 最大高度降低
  - Chat message list 優先保留可視空間
- 小鍵盤開啟時也套用 compact layout。

### 後續待觀察
- 手機橫向下 prediction 卡片是否還需要再做一層 ultra compact card。
- 登入頁與所有文字輸入彈窗在小鍵盤開啟時是否仍有 overflow。
- 共用 `TwitchResponsiveSheet` 的內容區是否需要強制包 `SingleChildScrollView`。
