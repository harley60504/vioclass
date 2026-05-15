import 'dart:async';

class TwitchHlsSegmentItem {
  final String url;
  final String? mapUrl;
  final String label;
  final int sequence;
  final bool isPrefetch;
  final Duration duration;

  const TwitchHlsSegmentItem({
    required this.url,
    required this.mapUrl,
    required this.label,
    required this.sequence,
    this.isPrefetch = false,
    this.duration = const Duration(seconds: 2),
  });
}

class TwitchHlsSegmentPrefetchJob {
  final TwitchHlsSegmentItem item;
  final StreamController<List<int>> controller = StreamController<List<int>>();
  final Completer<void> completed = Completer<void>();
  Object? error;
  StackTrace? stackTrace;
  bool cancelled = false;

  TwitchHlsSegmentPrefetchJob(this.item);

  void cancel() {
    cancelled = true;
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

class TwitchParsedMediaPlaylist {
  final List<TwitchHlsSegmentItem> items;
  final Duration reloadDelay;
  final int normalCount;
  final int futureCount;
  final int mediaSequence;
  final Duration targetDuration;
  final bool hasEndList;

  const TwitchParsedMediaPlaylist({
    required this.items,
    required this.reloadDelay,
    required this.normalCount,
    required this.futureCount,
    required this.mediaSequence,
    this.targetDuration = const Duration(seconds: 2),
    this.hasEndList = false,
  });
}
