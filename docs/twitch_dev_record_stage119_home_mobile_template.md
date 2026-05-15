# Stage 119 - Home Mobile Template

## 目標

將 Twitch 首頁加入手機 / 窄比例模板，讓主導覽列可以在窄螢幕時移到底部，並讓上方搜尋列在空間不足時自動拆成兩行，避免 sidebar 與 toolbar 在手機、窄視窗、直向平板上造成 overflow。

## 修改檔案

```text
lib/features/twitch/presentation/pages/twitch_stream_page.dart
```

## 主要變更

1. 首頁改用 `TwitchResponsiveLayout.fromConstraints()` 判斷版面。
2. 判定條件同時考慮寬度與長寬比：
   - phone portrait
   - width < 700
   - width < 880 且 aspectRatio < 1.15
3. 符合手機 / 窄直向條件時：
   - 左側 sidebar 移到底部 bottom navigation
   - 上方 toolbar 拆成兩行
   - 第一行：搜尋框 + 帳號按鈕
   - 第二行：登入狀態 + 分類 / 語言 / 重新整理按鈕
4. 桌面與寬螢幕仍保留左側 sidebar。
5. 中間尺寸 / 窄比例視窗會使用兩行 toolbar，但仍保留側邊欄。

## 保留功能

- 追隨 / 瀏覽切換
- 搜尋
- 遊戲分類
- 語言篩選
- 重新整理
- 帳號登入 / 登出 / 重新檢查登入狀態
- Stage 106 登入狀態 load guard

## 備註

這一版只調整首頁 shell layout，不改 Following / Browse 內部資料載入與 grid 邏輯。
