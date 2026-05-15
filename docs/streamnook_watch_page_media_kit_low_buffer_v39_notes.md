# streamnook_watch_page_media_kit_low_buffer_v39

PATCH VERSION: watch_page_media_kit_low_buffer_v39

## Changed

- Sets `PlayerConfiguration.bufferSize` for the watch-page media_kit `Player`.
- Uses a small 128 KB demuxer cache instead of media_kit default 32 MB.
- Intended for raw Dart proxy playback (`http://127.0.0.1:<port>/`) where HLS playlist buffering is already bypassed.

## Why

`media_kit` cannot remove all buffering, because decoder/demuxer queues still need some data, but the native backend exposes `bufferSize` to reduce the demuxer cache size.

## Tuning

Current value:

```dart
static const int _mediaKitLowLatencyBufferSize = 128 * 1024;
```

If playback stutters, try `256 * 1024` or `512 * 1024`.
If delay is still high and playback is stable, try `64 * 1024`.
