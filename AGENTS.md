# AGENTS.md

## 基本規則

- 回覆使用繁體中文。
- 不要自動掃描整個 repo。
- 不要讀取或修改以下資料夾：
  - build/
  - .dart_tool/
  - windows/
  - android/
  - ios/
  - macos/
  - linux/
  - web/

## 預設工作範圍

除非任務明確指定，優先只處理：

- lib/features/twitch/
- docs/

如果需要讀取或修改範圍外的檔案，先停止並回報：
1. 需要讀取的檔案路徑
2. 原因
3. 是否真的必要

## 任務限制

- 每次只做使用者要求的任務。
- 不要順手重構無關檔案。
- 不要順手改 UI。
- 不要順手改命名。
- 不要順手刪檔。
- 不要新增 stage249、stage250、stage252、stage254 類型命名。
- 大量改名時必須照順序：
  1. 先搜尋引用
  2. 改 import / class name
  3. 確認 analyzer 不再引用舊檔
  4. 最後才刪舊檔

## Flutter / Twitch 專案限制

- 不要改 Twitch GQL persisted query hash。
- 不要改 OAuth/token 儲存邏輯。
- 不要改 IRC 發送協議。
- 不要改 Channel Points payload。
- 不要改播放器底層 runtime 行為，除非任務明確指定。
- 修改後最多只跑一次 flutter analyze。
- 如果 analyze 還有錯，列出錯誤與下一輪建議，不要自行反覆 loop 修到成功。

## 輸出格式

每次完成後只回報：

1. Changed files
2. What changed
3. flutter analyze 結果
4. 下一輪建議
