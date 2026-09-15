part of '../twitch_hls_low_latency_proxy.dart';

class _TwitchHlsLowLatencyEngine {
  final _TwitchDartHlsLowLatencyProxyCore owner;
  final String playlistUrl;
  final int startupAfterSequence;

  _TwitchHlsLowLatencyEngine({
    required this.owner,
    required this.playlistUrl,
    this.startupAfterSequence = -1,
  });

  final Set<int> _writtenSequences = <int>{};
  final Set<String> _writtenUrls = <String>{};

  final LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> _prefetches =
      LinkedHashMap<String, TwitchHlsSegmentPrefetchJob>();

  final TwitchHlsLiveByteBus _liveBus = TwitchHlsLiveByteBus(
    // Keep a full current media segment available for late/reconnecting clients.
    // The byte value is treated as a soft limit; TwitchHlsLiveByteBus avoids
    // trimming inside the current segment unless an emergency hard limit is hit.
    maxReplayBytes: 4 * 1024 * 1024,
  );
  final LinkedHashMap<String, TwitchHlsSegmentItem> _recentWrittenItemHistory =
      LinkedHashMap<String, TwitchHlsSegmentItem>();

  bool _stopped = false;
  bool _pollerStarted = false;
  int _activeClientCount = 0;
  final Set<StreamIterator<List<int>>> _clientIterators =
      <StreamIterator<List<int>>>{};

  final Completer<void> _firstSnapshotReady = Completer<void>();

  String? _lastPlaylistSignature;
  int _unchangedPlaylistReloadStreak = 0;

  int _latestPlayableSequence = -1;
  int _playlistVersion = 0;

  List<TwitchHlsSegmentItem> _lastNormalItems = const <TwitchHlsSegmentItem>[];
  List<TwitchHlsSegmentItem> _lastOutputCandidates =
      const <TwitchHlsSegmentItem>[];

  Completer<void>? _playlistUpdateWaiter;
  Timer? _idleStopTimer;
  _TwitchHlsPersistentWriter? _writer;

  bool get isStopped => _stopped;
  bool get hasFirstStartupSegment => _firstSnapshotReady.isCompleted;

  int get _maxOutputBacklogSegments {
    final futureAllowance = owner.outputFutureSegments
        ? math.max(owner.futureOutputSegmentCount, 0)
        : 0;

    return math.max(owner.edgeSegmentCount + futureAllowance, 1);
  }

  void startPrewarm() {
    if (_stopped) return;

    if (!_pollerStarted) {
      _pollerStarted = true;
      unawaited(_runPlaylistPoller());
    }

    _ensurePersistentWriterStarted();
  }

  void _ensurePersistentWriterStarted() {
    if (_stopped) return;

    final existing = _writer;
    if (existing != null && !existing.isStopped) return;

    final writer = _TwitchHlsPersistentWriter(
      engine: this,
      output: _liveBus,
      startupAfterSequence: startupAfterSequence,
    );

    _writer = writer;
    unawaited(writer.start());
  }

  Future<void> waitUntilReady({required Duration timeout}) async {
    if (_firstSnapshotReady.isCompleted) return;

    try {
      await _firstSnapshotReady.future.timeout(timeout);
    } catch (_) {}
  }

  void cancelIdleStop() {
    _idleStopTimer?.cancel();
    _idleStopTimer = null;
  }

  void scheduleIdleStop() {
    if (_stopped) return;
    if (_activeClientCount > 0) return;

    _idleStopTimer?.cancel();
    _idleStopTimer = Timer(owner.idleKeepAliveDuration, () {
      if (_activeClientCount <= 0) {
        stop();
      }
    });
  }

  void stop() {
    if (_stopped) return;

    _stopped = true;

    _idleStopTimer?.cancel();
    _idleStopTimer = null;

    _writer?.stop();
    _writer = null;
    _liveBus.close();

    if (!_firstSnapshotReady.isCompleted) {
      _firstSnapshotReady.complete();
    }

    for (final job in _prefetches.values) {
      job.cancel();
    }

    _prefetches.clear();

    final waiter = _playlistUpdateWaiter;
    _playlistUpdateWaiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<int> stopWriterAtSegmentBoundary({required Duration timeout}) async {
    final writer = _writer;
    if (writer == null) return startupAfterSequence;
    try {
      return await writer.stopAtSegmentBoundary().timeout(timeout);
    } catch (_) {
      writer.stop();
      return writer.lastWrittenSequence;
    }
  }

  List<TwitchHlsSegmentItem> snapshotRecentReplayItems() =>
      List<TwitchHlsSegmentItem>.of(_recentWrittenItemHistory.values);

  Future<void> disconnectClients() async {
    final iterators = List<StreamIterator<List<int>>>.of(_clientIterators);
    _clientIterators.clear();

    for (final iterator in iterators) {
      try {
        await iterator.cancel();
      } catch (_) {}
    }
  }

  Future<void> pipeClientToResponse(HttpResponse response) async {
    cancelIdleStop();
    startPrewarm();
    _ensurePersistentWriterStarted();

    final iterator = StreamIterator<List<int>>(
      _liveBus.createClientStream(includeReplay: true),
    );
    _clientIterators.add(iterator);
    _activeClientCount++;

    try {
      await owner._pipeEngineOutputToResponse(
        response: response,
        iterator: iterator,
      );
    } catch (_) {
      // Silent by design.
    } finally {
      _clientIterators.remove(iterator);
      try {
        await iterator.cancel();
      } catch (_) {}
      _activeClientCount = math.max(0, _activeClientCount - 1);

      try {
        await response.close();
      } catch (_) {}

      if (_activeClientCount <= 0) {
        scheduleIdleStop();
      }
    }
  }

  Future<void> pipeReplayToResponse({
    required HttpResponse response,
    required Duration fromLive,
  }) async {
    cancelIdleStop();
    startPrewarm();
    _ensurePersistentWriterStarted();

    final iterator = StreamIterator<List<int>>(
      _liveBus.createClientStream(includeReplay: false),
    );
    _clientIterators.add(iterator);
    _activeClientCount++;

    try {
      await waitForSnapshot(timeout: const Duration(milliseconds: 900));
      final replayItems = _recentReplayItems(fromLive);
      final sink = _TwitchHlsResponseByteSink(response);

      for (final item in replayItems) {
        if (_stopped || owner.server == null) return;
        await owner._pipeSegmentToOutputBuffer(output: sink, item: item);
      }

      await owner._pipeEngineOutputToResponse(
        response: response,
        iterator: iterator,
      );
    } catch (_) {
      // Silent by design.
    } finally {
      _clientIterators.remove(iterator);
      try {
        await iterator.cancel();
      } catch (_) {}
      _activeClientCount = math.max(0, _activeClientCount - 1);

      try {
        await response.close();
      } catch (_) {}

      if (_activeClientCount <= 0) {
        scheduleIdleStop();
      }
    }
  }

  List<TwitchHlsSegmentItem> _recentReplayItems(Duration fromLive) {
    final items =
        _recentWrittenItemHistory.values
            .where((item) => item.duration.inMilliseconds > 0)
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (items.isEmpty) return const <TwitchHlsSegmentItem>[];

    final target = fromLive <= Duration.zero
        ? const Duration(seconds: 1)
        : fromLive;
    var total = Duration.zero;
    var start = items.length - 1;

    for (var i = items.length - 1; i >= 0; i--) {
      total += items[i].duration;
      start = i;
      if (total >= target) break;
    }

    return items.sublist(start);
  }

  void rememberWrittenItem(TwitchHlsSegmentItem item) {
    if (item.duration.inMilliseconds <= 0) return;
    _recentWrittenItemHistory['${item.sequence}'] = item;
    _trimRecentWrittenItemHistory();
  }

  void rememberAvailableReplayItems(Iterable<TwitchHlsSegmentItem> items) {
    for (final item in items) {
      if (item.isPrefetch || item.duration.inMilliseconds <= 0) continue;
      _recentWrittenItemHistory['${item.sequence}'] = item;
    }
    _trimRecentWrittenItemHistory();
  }

  void _trimRecentWrittenItemHistory() {
    var total = Duration.zero;
    for (final item in _recentWrittenItemHistory.values.toList().reversed) {
      total += item.duration;
    }

    while (_recentWrittenItemHistory.length > 1) {
      final firstKey = _recentWrittenItemHistory.keys.first;
      final first = _recentWrittenItemHistory[firstKey];
      if (first == null || total - first.duration < _liveReplayCacheDuration) {
        break;
      }
      final removed = _recentWrittenItemHistory.remove(firstKey);
      if (removed == null) break;
      total -= removed.duration;
    }
  }

  Future<void> _runPlaylistPoller() async {
    try {
      while (!_stopped && owner.server != null) {
        final loopStartedAt = DateTime.now();
        final media = await owner._loadMediaPlaylist(playlistUrl);
        final allItems = media.items;
        final playlistChanged = _updatePlaylistChangeState(allItems);

        if (allItems.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        final normalItems = allItems.where((item) => !item.isPrefetch).toList();
        final futureItems = allItems.where((item) => item.isPrefetch).toList();

        if (normalItems.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        // Seed the replay ring from the normal segments already present when
        // the channel is opened. Later playlist polls replace matching
        // sequences and append new live segments without recording replay
        // output back into the ring.
        rememberAvailableReplayItems(normalItems);

        final outputFutureItems = owner.outputFutureSegments
            ? futureItems
                  .take(math.max(owner.futureOutputSegmentCount, 0))
                  .toList()
            : const <TwitchHlsSegmentItem>[];

        final outputCandidates = _buildOutputCandidates(
          normalItems: normalItems,
          futureItems: outputFutureItems,
        );

        if (outputCandidates.isEmpty) {
          await _delayForNextPlaylist(
            media,
            loopStartedAt,
            playlistChanged: playlistChanged,
          );
          continue;
        }

        _lastNormalItems = normalItems;
        _lastOutputCandidates = outputCandidates;
        _latestPlayableSequence = outputCandidates.last.sequence;
        _playlistVersion++;

        final normalTailCount = math.min(2, owner.prefetchSegmentCount);
        final normalPrefetchStart = normalItems.length > normalTailCount
            ? normalItems.length - normalTailCount
            : 0;

        owner._schedulePrefetches(
          items: <TwitchHlsSegmentItem>[
            ...futureItems,
            ...normalItems.skip(normalPrefetchStart),
          ],
          servedUrls: _writtenUrls,
          prefetches: _prefetches,
        );

        if (!_firstSnapshotReady.isCompleted) {
          _firstSnapshotReady.complete();
        }

        _notifyPlaylistUpdated();
        _ensurePersistentWriterStarted();

        await _delayForNextPlaylist(
          media,
          loopStartedAt,
          playlistChanged: playlistChanged,
        );
      }
    } catch (_) {
      // Silent by design.
    } finally {
      stop();
    }
  }

  bool _updatePlaylistChangeState(List<TwitchHlsSegmentItem> items) {
    final signature = _playlistSignature(items);
    final changed = signature != _lastPlaylistSignature;

    if (changed) {
      _lastPlaylistSignature = signature;
      _unchangedPlaylistReloadStreak = 0;
    } else {
      _unchangedPlaylistReloadStreak = math.min(
        _unchangedPlaylistReloadStreak + 1,
        8,
      );
    }

    return changed;
  }

  String _playlistSignature(List<TwitchHlsSegmentItem> items) {
    if (items.isEmpty) return 'empty';

    final tail = items.length > 8 ? items.sublist(items.length - 8) : items;
    return tail
        .map(
          (item) => '${item.sequence}:${item.isPrefetch ? 1 : 0}:${item.url}',
        )
        .join('|');
  }

  Future<void> _delayForNextPlaylist(
    TwitchParsedMediaPlaylist media,
    DateTime loopStartedAt, {
    required bool playlistChanged,
  }) async {
    final elapsed = DateTime.now().difference(loopStartedAt);
    var wait = owner._strictReloadDelay(media.reloadDelay, elapsed);

    // Streamlink-style stability: if the playlist did not move, back off instead
    // of hammering the endpoint every 30ms. Twitch low-latency playlists are
    // still kept responsive by using a small cap when prefetch/future segments
    // exist, and a larger cap for normal-only playlists.
    if (!playlistChanged && _unchangedPlaylistReloadStreak > 0) {
      final hasFutureItems = media.items.any((item) => item.isPrefetch);
      final maxUnchangedDelayMs = hasFutureItems ? 240 : 520;
      final multiplier = math.min(
        1 << math.min(_unchangedPlaylistReloadStreak, 4),
        12,
      );
      final backedOffMs = math.min(
        wait.inMilliseconds * multiplier,
        maxUnchangedDelayMs,
      );
      wait = Duration(milliseconds: math.max(backedOffMs, wait.inMilliseconds));
    }

    await Future<void>.delayed(wait);
  }

  void _notifyPlaylistUpdated() {
    final waiter = _playlistUpdateWaiter;
    _playlistUpdateWaiter = null;

    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  Future<void> waitForPlaylistUpdate({
    Duration timeout = const Duration(milliseconds: 250),
  }) async {
    if (_stopped) return;

    final waiter = Completer<void>();
    _playlistUpdateWaiter = waiter;

    try {
      await waiter.future.timeout(timeout);
    } catch (_) {}
  }

  Future<void> waitForSnapshot({
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    if (_lastOutputCandidates.isNotEmpty && _lastNormalItems.isNotEmpty) {
      return;
    }

    try {
      await _firstSnapshotReady.future.timeout(timeout);
    } catch (_) {}
  }

  List<TwitchHlsSegmentItem> snapshotNormalItems() {
    return List<TwitchHlsSegmentItem>.of(_lastNormalItems);
  }

  List<TwitchHlsSegmentItem> snapshotOutputCandidates() {
    return List<TwitchHlsSegmentItem>.of(_lastOutputCandidates);
  }

  TwitchHlsSegmentPrefetchJob? takePrefetchJob(String url) {
    return _prefetches.remove(url);
  }

  TwitchHlsSegmentPrefetchJob? peekPrefetchJob(String url) {
    return _prefetches[url];
  }

  _TwitchHlsPrefetchRuntimeState? prefetchStateForItem(
    TwitchHlsSegmentItem item,
  ) {
    return owner.prefetchStateForJob(_prefetches[item.url]);
  }

  void markWritten(TwitchHlsSegmentItem item) {
    _writtenUrls.add(item.url);
    _writtenSequences.add(item.sequence);

    _pruneWrittenHistory(item);
  }

  void _pruneWrittenHistory(TwitchHlsSegmentItem item) {
    if (_writtenSequences.length > 320) {
      final minKeep = item.sequence - 180;
      _writtenSequences.removeWhere((value) => value < minKeep);
    }

    if (_lastNormalItems.isNotEmpty && _writtenUrls.length > 260) {
      final recentUrls = _lastNormalItems.map((item) => item.url).toSet();
      _writtenUrls.removeWhere((value) => !recentUrls.contains(value));
    }

    while (_writtenUrls.length > 320) {
      _writtenUrls.remove(_writtenUrls.first);
    }
  }

  void markSkipped(TwitchHlsSegmentItem item) {
    _writtenUrls.add(item.url);
    _writtenSequences.add(item.sequence);
    _pruneWrittenHistory(item);

    final removed = _prefetches.remove(item.url);
    removed?.cancel();
  }

  int latestPlayableSequence() {
    return _latestPlayableSequence;
  }

  int playlistVersion() {
    return _playlistVersion;
  }

  int maxOutputBacklogSegments() {
    return _maxOutputBacklogSegments;
  }

  TwitchHlsLiveStatus liveStatus() {
    final writer = _writer;
    if (writer != null && !writer.isStopped) {
      return writer.liveStatus();
    }

    final hasFutureSegment = _lastOutputCandidates.any(
      (item) => item.isPrefetch,
    );

    return TwitchHlsLiveStatus(
      running: !_stopped,
      hasWriter: false,
      hasFutureSegment: hasFutureSegment,
      playlistVersion: _playlistVersion,
      activeClientCount: _activeClientCount,
      latestPlayableSequence: _latestPlayableSequence,
      lastWrittenSequence: -1,
      bufferedBytes: _liveBus.bufferedBytes,
      lastWrittenWasPrefetch: false,
      outputDuration: Duration.zero,
      safeLivePosition: Duration.zero,
      liveBackoff: Duration.zero,
      updatedAt: DateTime.now(),
    );
  }

  List<TwitchHlsSegmentItem> _buildOutputCandidates({
    required List<TwitchHlsSegmentItem> normalItems,
    required List<TwitchHlsSegmentItem> futureItems,
  }) {
    final output = <TwitchHlsSegmentItem>[];
    final seenUrls = <String>{};
    final seenSequences = <int>{};

    void addItem(TwitchHlsSegmentItem item) {
      final url = item.url.trim();

      if (url.isNotEmpty && !seenUrls.add(url)) return;

      final seq = item.sequence;
      if (!seenSequences.add(seq)) return;

      output.add(item);
    }

    for (final item in normalItems) {
      addItem(item);
    }

    for (final item in futureItems) {
      addItem(item);
    }

    output.sort((a, b) => a.sequence.compareTo(b.sequence));
    return output;
  }
}
