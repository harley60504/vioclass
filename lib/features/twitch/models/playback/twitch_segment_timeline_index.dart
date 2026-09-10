import 'twitch_hls_proxy_models.dart';

/// One immutable segment on the canonical Twitch media timeline.
///
/// [canonicalStart] and [canonicalEnd] are stream-relative media positions, not
/// player-relative positions. The range is [canonicalStart, canonicalEnd).
class TwitchSegmentTimelineEntry {
  final int index;
  final TwitchHlsSegmentItem item;
  final Duration canonicalStart;
  final Duration canonicalEnd;

  const TwitchSegmentTimelineEntry({
    required this.index,
    required this.item,
    required this.canonicalStart,
    required this.canonicalEnd,
  });

  int get sequence => item.sequence;
  Duration get duration => item.duration;
  DateTime? get programDateTime => item.programDateTime?.toUtc();

  bool contains(Duration position) {
    return position >= canonicalStart && position < canonicalEnd;
  }
}

/// Result of resolving a canonical media target to one HLS segment.
class TwitchSegmentTimelineSeek {
  final TwitchSegmentTimelineEntry entry;
  final Duration canonicalPosition;
  final Duration offset;

  const TwitchSegmentTimelineSeek({
    required this.entry,
    required this.canonicalPosition,
    required this.offset,
  });

  int get index => entry.index;
  int get sequence => entry.sequence;
}

/// Immutable index shared by live, local replay and DVR seek logic.
///
/// HLS is treated only as a source of media segments. Every segment is mapped
/// onto one canonical stream-relative clock so different transports can resolve
/// the same target without maintaining independent timeline geometry.
class TwitchSegmentTimelineIndex {
  final List<TwitchSegmentTimelineEntry> entries;
  final Duration canonicalStart;
  final Duration canonicalEnd;
  final DateTime? timelineOrigin;
  final Duration? twitchElapsed;
  final Duration? twitchTotal;

  const TwitchSegmentTimelineIndex._({
    required this.entries,
    required this.canonicalStart,
    required this.canonicalEnd,
    required this.timelineOrigin,
    required this.twitchElapsed,
    required this.twitchTotal,
  });

  factory TwitchSegmentTimelineIndex.fromSegments(
    Iterable<TwitchHlsSegmentItem> segments, {
    Duration canonicalStart = Duration.zero,
    DateTime? timelineOrigin,
    Duration? twitchElapsed,
    Duration? twitchTotal,
  }) {
    final normalItems = segments
        .where((item) => !item.isPrefetch)
        .toList(growable: false);

    if (normalItems.isEmpty) {
      return TwitchSegmentTimelineIndex._(
        entries: const <TwitchSegmentTimelineEntry>[],
        canonicalStart: canonicalStart,
        canonicalEnd: canonicalStart,
        timelineOrigin: timelineOrigin?.toUtc(),
        twitchElapsed: twitchElapsed,
        twitchTotal: twitchTotal,
      );
    }

    final result = <TwitchSegmentTimelineEntry>[];
    var cursorUs = canonicalStart.inMicroseconds;
    for (var i = 0; i < normalItems.length; i++) {
      final item = normalItems[i];
      final durationUs = item.duration.inMicroseconds > 0
          ? item.duration.inMicroseconds
          : 1;
      final start = Duration(microseconds: cursorUs);
      cursorUs += durationUs;
      final end = Duration(microseconds: cursorUs);
      result.add(
        TwitchSegmentTimelineEntry(
          index: i,
          item: item,
          canonicalStart: start,
          canonicalEnd: end,
        ),
      );
    }

    return TwitchSegmentTimelineIndex._(
      entries: List<TwitchSegmentTimelineEntry>.unmodifiable(result),
      canonicalStart: canonicalStart,
      canonicalEnd: Duration(microseconds: cursorUs),
      timelineOrigin: timelineOrigin?.toUtc(),
      twitchElapsed: twitchElapsed,
      twitchTotal: twitchTotal,
    );
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  Duration get indexedDuration {
    final us = canonicalEnd.inMicroseconds - canonicalStart.inMicroseconds;
    return Duration(microseconds: us > 0 ? us : 0);
  }

  TwitchSegmentTimelineEntry? entryAt(int index) {
    if (index < 0 || index >= entries.length) return null;
    return entries[index];
  }

  TwitchSegmentTimelineEntry? entryForSequence(int sequence) {
    if (entries.isEmpty) return null;
    var low = 0;
    var high = entries.length - 1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final current = entries[mid].sequence;
      if (current == sequence) return entries[mid];
      if (current < sequence) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (low >= entries.length) return null;
    return entries[low];
  }

  TwitchSegmentTimelineSeek? resolveCanonical(Duration requestedPosition) {
    if (entries.isEmpty) return null;

    final first = entries.first;
    final last = entries.last;
    final minUs = first.canonicalStart.inMicroseconds;
    final maxUs = last.canonicalEnd.inMicroseconds > minUs
        ? last.canonicalEnd.inMicroseconds - 1
        : minUs;
    final targetUs = requestedPosition.inMicroseconds.clamp(minUs, maxUs).toInt();

    var low = 0;
    var high = entries.length - 1;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final entry = entries[mid];
      if (targetUs < entry.canonicalStart.inMicroseconds) {
        high = mid - 1;
      } else if (targetUs >= entry.canonicalEnd.inMicroseconds) {
        low = mid + 1;
      } else {
        return _seekForEntry(entry, targetUs);
      }
    }

    final fallback = entries[low.clamp(0, entries.length - 1).toInt()];
    return _seekForEntry(fallback, targetUs);
  }

  TwitchSegmentTimelineSeek? resolveProgramDateTime(DateTime requestedTime) {
    if (entries.isEmpty) return null;
    final target = requestedTime.toUtc();

    TwitchSegmentTimelineEntry? firstTimed;
    TwitchSegmentTimelineEntry? lastTimed;
    for (final entry in entries) {
      final start = entry.programDateTime;
      if (start == null) continue;
      firstTimed ??= entry;
      lastTimed = entry;
      final end = start.add(entry.duration);
      if (target.isBefore(start)) {
        return TwitchSegmentTimelineSeek(
          entry: entry,
          canonicalPosition: entry.canonicalStart,
          offset: Duration.zero,
        );
      }
      if (target.isBefore(end)) {
        final rawOffsetUs = target.difference(start).inMicroseconds;
        final maxOffsetUs = entry.duration.inMicroseconds > 0
            ? entry.duration.inMicroseconds - 1
            : 0;
        final offsetUs = rawOffsetUs.clamp(0, maxOffsetUs).toInt();
        return TwitchSegmentTimelineSeek(
          entry: entry,
          canonicalPosition: entry.canonicalStart +
              Duration(microseconds: offsetUs),
          offset: Duration(microseconds: offsetUs),
        );
      }
    }

    if (firstTimed == null) return null;
    final firstStart = firstTimed.programDateTime!;
    if (target.isBefore(firstStart)) {
      return TwitchSegmentTimelineSeek(
        entry: firstTimed,
        canonicalPosition: firstTimed.canonicalStart,
        offset: Duration.zero,
      );
    }

    final entry = lastTimed!;
    final maxOffsetUs = entry.duration.inMicroseconds > 0
        ? entry.duration.inMicroseconds - 1
        : 0;
    return TwitchSegmentTimelineSeek(
      entry: entry,
      canonicalPosition:
          entry.canonicalStart + Duration(microseconds: maxOffsetUs),
      offset: Duration(microseconds: maxOffsetUs),
    );
  }

  Duration durationBeforeIndex(int index) {
    if (entries.isEmpty || index <= 0) return Duration.zero;
    final safe = index.clamp(0, entries.length).toInt();
    if (safe == entries.length) return indexedDuration;
    return entries[safe].canonicalStart - canonicalStart;
  }

  Duration durationBetweenIndexes(int startIndex, int endIndex) {
    if (entries.isEmpty || endIndex <= startIndex) return Duration.zero;
    final start = startIndex.clamp(0, entries.length).toInt();
    final end = endIndex.clamp(start, entries.length).toInt();
    if (start == end) return Duration.zero;
    final startUs = start == entries.length
        ? canonicalEnd.inMicroseconds
        : entries[start].canonicalStart.inMicroseconds;
    final endUs = end == entries.length
        ? canonicalEnd.inMicroseconds
        : entries[end].canonicalStart.inMicroseconds;
    return Duration(microseconds: endUs - startUs);
  }

  Duration? canonicalPositionForProgramDateTime(DateTime value) {
    final origin = timelineOrigin;
    if (origin == null) return null;
    final delta = value.toUtc().difference(origin);
    if (delta.isNegative) return Duration.zero;
    return delta;
  }

  DateTime? programDateTimeForCanonicalPosition(Duration position) {
    final origin = timelineOrigin;
    if (origin == null) return null;
    return origin.add(position);
  }

  TwitchSegmentTimelineSeek _seekForEntry(
    TwitchSegmentTimelineEntry entry,
    int canonicalTargetUs,
  ) {
    final offsetUs = canonicalTargetUs - entry.canonicalStart.inMicroseconds;
    return TwitchSegmentTimelineSeek(
      entry: entry,
      canonicalPosition: Duration(microseconds: canonicalTargetUs),
      offset: Duration(microseconds: offsetUs > 0 ? offsetUs : 0),
    );
  }
}
