# StreamNook Watch Player v41

## 目的

讓 App 內部 media_kit 與外部 mpv 測試走完全相同的 Dart Proxy URL。

## 改動

- `TwitchPlaylistPlayerRuntime.proxyUrl` 改為 `proxy.streamTsUrl`。
- `proxyMpvUrl` 也使用同一個 `proxy.streamTsUrl`。
- App 內部播放與「複製 Dart Proxy URL / mpv Proxy 指令」都指向同一條：

```text
http://127.0.0.1:<port>/stream.ts
```

## 保留

- media_kit bufferSize 保持預設，不再使用 v39 的小 cache。
- 仍然不是 HLS m3u8 route；`/stream.ts` 進入的是 raw stream handler。
