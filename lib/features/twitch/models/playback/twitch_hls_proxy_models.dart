import 'dart:async';

class TwitchHlsSegmentItem {
  final String url;
  final String? mapUrl;
  final String label;
  final int sequence;
  final bool isPrefetch;
  final Duration duration;
  final DateTime? programDateTime;

  const TwitchHlsSegmentItem({
    required this.url,
    required this.mapUrl,
    required this.label,
    required this.sequence,
    this.isPrefetch = false,
    this.duration = const Duration(seconds: 2),
    this.programDateTime,
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
  final Duration? twitchElapsed;
  final Duration? twitchTotal;
  final DateTime? timelineOrigin;
  final DateTime? timingObservedAt;

  const TwitchParsedMediaPlaylist({
    required this.items,
    required this.reloadDelay,
    required this.normalCount,
    required this.futureCount,
    required this.mediaSequence,
    this.targetDuration = const Duration(seconds: 2),
    this.hasEndList = false,
    this.twitchElapsed,
    this.twitchTotal,
    this.timelineOrigin,
    this.timingObservedAt,
  });
}

class TwitchHlsLiveStatus {
  final bool running;
  final bool hasWriter;
  final bool hasFutureSegment;
  final int playlistVersion;
  final int activeClientCount;
  final int latestPlayableSequence;
  final int lastWrittenSequence;
  final int bufferedBytes;
  final bool lastWrittenWasPrefetch;
  final Duration outputDuration;
  final Duration safeLivePosition;
  final Duration liveBackoff;
  final DateTime updatedAt;
  final Duration? twitchElapsed;
  final Duration? twitchTotal;
  final DateTime? timelineOrigin;
  final DateTime? timingObservedAt;

  const TwitchHlsLiveStatus({
    required this.running,
    required this.hasWriter,
    required this.hasFutureSegment,
    required this.playlistVersion,
    required this.activeClientCount,
    required this.latestPlayableSequence,
    required this.lastWrittenSequence,
    required this.bufferedBytes,
    required this.lastWrittenWasPrefetch,
    required this.outputDuration,
    required this.safeLivePosition,
    required this.liveBackoff,
    required this.updatedAt,
    this.twitchElapsed,
    this.twitchTotal,
    this.timelineOrigin,
    this.timingObservedAt,
  });

  int get lagSegments {
    if (latestPlayableSequence < 0 || lastWrittenSequence < 0) return 0;
    return latestPlayableSequence - lastWrittenSequence;
  }

  bool get hasOutput => outputDuration.inMilliseconds > 0;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'running': running,
      'hasWriter': hasWriter,
      'hasFutureSegment': hasFutureSegment,
      'playlistVersion': playlistVersion,
      'activeClientCount': activeClientCount,
      'latestPlayableSequence': latestPlayableSequence,
      'lastWrittenSequence': lastWrittenSequence,
      'lagSegments': lagSegments,
      'bufferedBytes': bufferedBytes,
      'lastWrittenWasPrefetch': lastWrittenWasPrefetch,
      'outputDurationMs': outputDuration.inMilliseconds,
      'safeLivePositionMs': safeLivePosition.inMilliseconds,
      'liveBackoffMs': liveBackoff.inMilliseconds,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'twitchElapsedUs': twitchElapsed?.inMicroseconds,
      'twitchTotalUs': twitchTotal?.inMicroseconds,
      'timelineOriginMs': timelineOrigin?.millisecondsSinceEpoch,
      'timingObservedAtMs': timingObservedAt?.millisecondsSinceEpoch,
    };
  }

  factory TwitchHlsLiveStatus.fromJson(Map<String, Object?> json) {
    int readInt(String key, [int fallback = 0]) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int? readNullableInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value.toString());
    }

    bool readBool(String key, [bool fallback = false]) {
      final value = json[key];
      if (value is bool) return value;
      final text = value?.toString().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
      return fallback;
    }

    Duration readDuration(String key) {
      return Duration(milliseconds: readInt(key));
    }

    final updatedAtMs = readInt(
      'updatedAtMs',
      DateTime.now().millisecondsSinceEpoch,
    );
    final twitchElapsedUs = readNullableInt('twitchElapsedUs');
    final twitchTotalUs = readNullableInt('twitchTotalUs');
    final timelineOriginMs = readNullableInt('timelineOriginMs');
    final timingObservedAtMs = readNullableInt('timingObservedAtMs');

    return TwitchHlsLiveStatus(
      running: readBool('running'),
      hasWriter: readBool('hasWriter'),
      hasFutureSegment: readBool('hasFutureSegment'),
      playlistVersion: readInt('playlistVersion'),
      activeClientCount: readInt('activeClientCount'),
      latestPlayableSequence: readInt('latestPlayableSequence', -1),
      lastWrittenSequence: readInt('lastWrittenSequence', -1),
      bufferedBytes: readInt('bufferedBytes'),
      lastWrittenWasPrefetch: readBool('lastWrittenWasPrefetch'),
      outputDuration: readDuration('outputDurationMs'),
      safeLivePosition: readDuration('safeLivePositionMs'),
      liveBackoff: readDuration('liveBackoffMs'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      twitchElapsed: twitchElapsedUs == null
          ? null
          : Duration(microseconds: twitchElapsedUs),
      twitchTotal: twitchTotalUs == null
          ? null
          : Duration(microseconds: twitchTotalUs),
      timelineOrigin: timelineOriginMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timelineOriginMs, isUtc: true),
      timingObservedAt: timingObservedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              timingObservedAtMs,
              isUtc: true,
            ),
    );
  }

  static TwitchHlsLiveStatus stopped() {
    return TwitchHlsLiveStatus(
      running: false,
      hasWriter: false,
      hasFutureSegment: false,
      playlistVersion: 0,
      activeClientCount: 0,
      latestPlayableSequence: -1,
      lastWrittenSequence: -1,
      bufferedBytes: 0,
      lastWrittenWasPrefetch: false,
      outputDuration: Duration.zero,
      safeLivePosition: Duration.zero,
      liveBackoff: Duration.zero,
      updatedAt: DateTime.now(),
    );
  }
}
