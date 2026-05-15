# Stage v73：輸入列自製對齊、遊戲篩選圖案縮小、Top Games Cursor 持續讀取

更新時間：2026-05-15 05:30:04

## 本次修正

### 1. 聊天室輸入列真正對齊
- 針對 v72 仍然不齊的問題，原因是 `TextField` / `FilledButton` 內部高度模型不同。
- v73 改成更細的高度控制：
  - 以 `fontSize + MediaQuery.textScaler + verticalInset` 自動計算 `controlHeight`
  - TextField 使用計算出的 `textVerticalPadding`
  - Send 按鈕直接套用同一個 `controlHeight`
- 目標是讓輸入框與 Send 按鈕在視覺高度上更一致。

### 2. 底部 composer 維持同一塊
- 保留 v72 的整合：工具列與輸入列都在同一個底部 dock container 內。
- 輸入列本身不再另外畫背景與 top border，避免看起來被切成兩塊。

### 3. 篩選選單遊戲圖案縮小
- 遊戲分類卡片高度從原本偏高的大卡片縮小：
  - grid item 改用 `mainAxisExtent`
  - 桌面/較寬：166
  - 較窄：154
- 遊戲 box art 圖片請求尺寸從 188x250 改為 136x182。
- 圖片在卡片中置中，保留遊戲名稱在下方。
- 「全部直播」仍保留第一張卡片。

### 4. 遊戲分類 API 持續分頁讀取
- Twitch `Get Top Games` 官方 API 支援 `first` 與 `after` cursor。
- `first` 每頁最大 100。
- 只要 response 的 `pagination.cursor` 還有值，就可以用 `after` 繼續讀下一頁。
- v73 將 `_loadMoreGames()` 調整為：
  - 每次用 `first: 100`
  - 使用目前 `_gameCursor` 作為 `after`
  - append 新遊戲
  - 只有 cursor 消失或 cursor 沒前進時才停止
- 篩選 grid 底部加入狀態 tile：
  - 載入中
  - 讀取失敗 / 點擊重試
  - 已載入全部
- 這代表不是固定讀 80 / 240 筆，而是 cursor 能讀多久就讀多久。

## API 判斷
- 目前可做到「一直讀到 Twitch 不再回傳 cursor 為止」。
- 如果讀不下去，通常不是前端限制，而是：
  - Twitch 已沒有下一頁 cursor
  - token / rate limit / 網路錯誤
  - API 回傳重複 cursor，v73 會停止避免無限迴圈

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/pages/twitch_browse_page.dart`
