# Stage v72：底部輸入區整合、自動高度、Twitch 貼圖二級分類、Reward Grid 高度穩定化

更新時間：2026-05-15 05:20:54

## 本次修正重點

### 1. 底部工具列與輸入列合併成同一塊
- 將聊天室底部的忠誠點數 / 貼圖 / 重新整理工具列與輸入列包在同一個 dock container。
- 外層統一背景與上方 border。
- 移除工具列與輸入列各自造成的分隔感，讓底部看起來像同一個 composer 區塊。

### 2. 輸入框與 Send 按鈕高度改成自動計算
- 移除固定高度常數。
- 高度改由：
  - `fontSize`
  - `MediaQuery.textScaler`
  - compact 狀態
  - vertical padding
  自動計算。
- Send 按鈕高度直接跟 `controlHeight` 同步。
- TextField 依照計算出的 `textVerticalPadding` 置中，改善輸入文字偏上/偏下問題。

### 3. 忠誠點數 Reward Grid 改用 `mainAxisExtent`
- 原本用 `childAspectRatio` 會因不同視窗寬度導致高度不穩，容易 bottom overflow。
- 改成 `mainAxisExtent`：
  - 窄畫面：232
  - 中畫面：224
  - 寬畫面：216
- 讓 reward card 高度更可控，降低 overflow。

### 4. Twitch 官方貼圖加入二級分類
- Twitch 官方貼圖不再一次渲染全部分類。
- 新增二級選項：
  - 我的可用
  - 實況主
  - 全部共用
- 只渲染目前選取的分類，避免 Twitch 貼圖太多導致卡頓。
- 保留搜尋功能，搜尋只作用在目前二級分類。

### 5. UI 行為
- Twitch 主分類仍在原本橫向 tab 中。
- 進入 Twitch 分類後，才顯示二級分類 chip。
- `user:read:emotes` 缺失提示仍保留，但縮成最多兩行，減少高度佔用。

## 主要影響檔案
- `lib/features/twitch/presentation/widgets/watch/twitch_watch_chat_panel.dart`
- `lib/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart`
- `lib/features/twitch/presentation/sheets/twitch_channel_points_sheet.dart`
- `lib/features/twitch/presentation/sheets/twitch_emote_picker_sheet.dart`
