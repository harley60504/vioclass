# Stage 141 - Proxy Live Status Debug

## 目的

讓 Dart HLS proxy 回報目前 live edge / safe live position 狀態，方便 debug LIVE 按鈕為什麼會被拉回。

## 修改內容

### 1. HLS model

修改：

- `lib/features/twitch/models/playback/twitch_hls_proxy_models.dart`

新增：

- `TwitchHlsLiveStatus`

狀態包含：

- `latestPlayableSequence`
- `lastWrittenSequence`
- `lagSegments`
- `outputDuration`
- `safeLivePosition`
- `liveBackoff`
- `bufferedBytes`
- `hasFutureSegment`
- `activeClientCount`

### 2. HLS proxy

透過 apply script 修改：

- `lib/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart`

新增：

- proxy isolate `liveStatus` command
- `TwitchDartHlsLowLatencyProxy.requestLiveStatus()`
- `_TwitchHlsLowLatencyEngine.liveStatus()`
- `_TwitchHlsPersistentWriter.liveStatus()`
- writer 輸出時間累積

### 3. Player runtime

透過 apply script 修改：

- `lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart`

新增：

- `proxyLiveStatus`
- `refreshProxyLiveStatus()`

### 4. LIVE strip debug

修改：

- `lib/features/twitch/presentation/widgets/watch/player/twitch_live_playback_strip.dart`

新增：

- 每秒輪詢 `playerRuntime.refreshProxyLiveStatus()`
- 時間 tooltip 顯示 proxy debug 狀態

## 使用方式

從專案根目錄執行：

```powershell
python tools/apply_stage141_proxy_live_status.py
```

如果 Windows 沒有 `python`，可以試：

```powershell
py -3 tools/apply_stage141_proxy_live_status.py
```

接著：

```powershell
flutter analyze
flutter run
```

## Debug 方式

播放直播後，把滑鼠移到時間文字上，tooltip 會多出 proxy 狀態：

```text
proxy safe=00:10 / out=00:12 · backoff=900ms · seq=123/124 · lag=1 · future=yes · buffer=512KB
```

重點看：

- `safe`：proxy 認為比較安全的 live position
- `out`：proxy 已經輸出的累積時間
- `seq`：已寫出 segment / 最新可播 segment
- `lag`：proxy writer 和 live edge 差幾個 segment
- `future`：目前 playlist 是否含 future / prefetch segment

## 注意

Stage 141 先以 debug 為主，還沒有把 LIVE 按鈕改成使用 `safeLivePosition` seek。
確認數據合理後，下一步 Stage 142 再讓 LIVE 按鈕使用 proxy safe live time。
