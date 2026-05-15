# StreamNook Watch Player v53

PATCH VERSION: watch_player_area_remove_live_button_v53

## 變更

- 移除時間 / LIVE 區塊的點擊行為。
- 不再呼叫 `player.seek(duration)` 或重新開啟 proxy 來模擬 LIVE。
- 保留進度條手動拖曳。
- 保留時間 / LIVE 狀態顯示：接近尾端時仍可顯示紅色 LIVE；離尾端時顯示 `目前時間 / 總長度`。
- Debug 二級選單、聊天室、全螢幕邏輯不變。

## 原因

raw proxy stream 對 media_kit 來說不一定是真正可 seek live-edge 的媒體；LIVE 按鍵容易造成行為不穩。這版先改成手動拖曳最穩。
