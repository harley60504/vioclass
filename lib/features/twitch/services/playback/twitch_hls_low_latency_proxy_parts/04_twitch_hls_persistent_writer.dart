part of '../twitch_hls_low_latency_proxy.dart';

class _TwitchHlsPersistentWriter {
  final _TwitchHlsLowLatencyEngine engine;
  final TwitchHlsByteSink output;

  bool _stopped = false;
  bool _started = false;

  int _lastWrittenSequence;
  int? _startupInitialLatestSequence;
  String? _lastMapUrl;
  Duration _writtenOutputDuration = Duration.zero;
  Duration _lastWrittenDuration = Duration.zero;
  bool _lastWrittenWasPrefetch = false;
  DateTime? _lastWrittenAt;

  final Set<int> _sessionWrittenSequences = <int>{};
  final Set<String> _sessionWrittenUrls = <String>{};

  bool _writingItem = false;
  Completer<int>? _stopAtBoundaryCompleter;

  _TwitchHlsPersistentWriter({
    required this.engine,
    required this.output,
    int startupAfterSequence = -1,
  }) : _lastWrittenSequence = startupAfterSequence;

  bool get isStopped => _stopped;
  int get lastWrittenSequence => _lastWrittenSequence;

  Future<void> start() async {
    if (_started || _stopped) return;
    _started = true;

    try {
      await engine.waitForSnapshot();

      final startup = await _selectStartupItem();
      if (startup == null) return;

      await _writeItemAtBoundary(startup);

      while (!_stopped && !engine.isStopped && engine.owner.server != null) {
        final next = _selectNextItem();

        if (next == null) {
          await engine.waitForPlaylistUpdate();
          continue;
        }

        await _writeItemAtBoundary(next);
      }
    } catch (_) {
      // Silent by design.
    } finally {
      stop();
    }
  }

  void stop() {
    if (_stopped) return;
    _stopped = true;
    final completer = _stopAtBoundaryCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(_lastWrittenSequence);
    }
  }

  Future<int> stopAtSegmentBoundary() {
    if (_stopped) return Future<int>.value(_lastWrittenSequence);
    final existing = _stopAtBoundaryCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<int>();
    _stopAtBoundaryCompleter = completer;
    if (!_writingItem) stop();
    return completer.future;
  }

  Future<void> _writeItemAtBoundary(TwitchHlsSegmentItem item) async {
    _writingItem = true;
    try {
      await _writeItem(item);
    } finally {
      _writingItem = false;
    }
    if (_stopAtBoundaryCompleter != null) stop();
  }

  TwitchHlsLiveStatus liveStatus() {
    final latestPlayable = engine.latestPlayableSequence();
    final backoff = _liveBackoff(_lastWrittenDuration);
    final safeLivePosition = _writtenOutputDuration > backoff
        ? _writtenOutputDuration - backoff
        : Duration.zero;
    final hasFutureSegment = engine._lastOutputCandidates.any(
      (item) => item.isPrefetch,
    );

    return TwitchHlsLiveStatus(
      running: !engine.isStopped && !_stopped,
      hasWriter: true,
      hasFutureSegment: hasFutureSegment,
      playlistVersion: engine.playlistVersion(),
      activeClientCount: engine._activeClientCount,
      latestPlayableSequence: latestPlayable,
      lastWrittenSequence: _lastWrittenSequence,
      bufferedBytes: engine._liveBus.bufferedBytes,
      lastWrittenWasPrefetch: _lastWrittenWasPrefetch,
      outputDuration: _writtenOutputDuration,
      safeLivePosition: safeLivePosition,
      liveBackoff: backoff,
      updatedAt: _lastWrittenAt ?? DateTime.now(),
    );
  }

  Duration _liveBackoff(Duration lastSegmentDuration) {
    final segmentMs = lastSegmentDuration.inMilliseconds;
    if (segmentMs <= 0) return const Duration(milliseconds: 900);

    final backoffMs = (segmentMs * 0.45).round().clamp(700, 1800).toInt();

    return Duration(milliseconds: backoffMs);
  }

  Future<TwitchHlsSegmentItem?> _selectStartupItem() async {
    final normalItems = engine.snapshotNormalItems();
    final outputCandidates = engine.snapshotOutputCandidates();

    if (normalItems.isEmpty || outputCandidates.isEmpty) return null;

    _startupInitialLatestSequence ??= normalItems.last.sequence;

    switch (engine.owner.startupMode) {
      case TwitchHlsStartupMode.latestNormalImmediate:
        return _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.nextNormalFresh:
        return _nextNormalFreshStartup();

      case TwitchHlsStartupMode.firstFutureIfAvailable:
        return _firstFutureStartup(normalItems, outputCandidates) ??
            _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.firstReadyFutureIfAvailable:
        return await _firstReadyFutureStartup(normalItems, outputCandidates) ??
            _latestNormalStartup(normalItems);

      case TwitchHlsStartupMode.stableFreshEdge:
        return _stableFreshEdgeStartup(
          initialNormalItems: normalItems,
          initialOutputCandidates: outputCandidates,
        );

      case TwitchHlsStartupMode.streamlinkLiveEdge:
        return _streamlinkLiveEdgeStartup();
    }
  }

  TwitchHlsSegmentItem? _latestNormalStartup(
    List<TwitchHlsSegmentItem> normalItems,
  ) {
    if (normalItems.isEmpty) return null;

    final startSequence = _edgeStartSequence(normalItems);

    final candidates = _candidatesFromPool(
      pool: normalItems,
      startSequence: startSequence,
    );

    if (candidates.isEmpty) return null;
    return candidates.last;
  }

  Future<TwitchHlsSegmentItem?> _nextNormalFreshStartup() async {
    final targetSequence = (_startupInitialLatestSequence ?? -1) + 1;
    final deadline = DateTime.now().add(const Duration(milliseconds: 900));

    while (!_stopped && DateTime.now().isBefore(deadline)) {
      final normalItems = engine.snapshotNormalItems();

      final candidates = _candidatesFromPool(
        pool: normalItems,
        startSequence: targetSequence,
      );

      if (candidates.isNotEmpty) {
        return candidates.first;
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 120),
      );
    }

    final normalItems = engine.snapshotNormalItems();
    return _latestNormalStartup(normalItems);
  }

  TwitchHlsSegmentItem? _firstFutureStartup(
    List<TwitchHlsSegmentItem> normalItems,
    List<TwitchHlsSegmentItem> outputCandidates,
  ) {
    final futureCandidates = _futureStartupCandidates(
      normalItems: normalItems,
      outputCandidates: outputCandidates,
    );

    if (futureCandidates.isEmpty) return null;
    return futureCandidates.first;
  }

  Future<TwitchHlsSegmentItem?> _firstReadyFutureStartup(
    List<TwitchHlsSegmentItem> normalItems,
    List<TwitchHlsSegmentItem> outputCandidates,
  ) async {
    var candidates = _futureStartupCandidates(
      normalItems: normalItems,
      outputCandidates: outputCandidates,
    );

    if (candidates.isEmpty) return null;

    var hot = _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: true,
      allowResponseOpened: false,
    );

    if (hot != null) return hot;

    var opened = _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: false,
      allowResponseOpened: true,
    );

    final timeout = engine.owner.startupFutureReadyWaitTimeout;

    if (timeout > Duration.zero) {
      final deadline = DateTime.now().add(timeout);

      while (!_stopped && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));

        candidates = _futureStartupCandidates(
          normalItems: engine.snapshotNormalItems(),
          outputCandidates: engine.snapshotOutputCandidates(),
        );

        hot = _findFutureWithPrefetchState(
          candidates: candidates,
          requireFirstChunk: true,
          allowResponseOpened: false,
        );

        if (hot != null) return hot;

        opened ??= _findFutureWithPrefetchState(
          candidates: candidates,
          requireFirstChunk: false,
          allowResponseOpened: true,
        );
      }
    }

    opened ??= _findFutureWithPrefetchState(
      candidates: candidates,
      requireFirstChunk: false,
      allowResponseOpened: true,
    );

    return opened;
  }

  Future<TwitchHlsSegmentItem?> _stableFreshEdgeStartup({
    required List<TwitchHlsSegmentItem> initialNormalItems,
    required List<TwitchHlsSegmentItem> initialOutputCandidates,
  }) async {
    if (initialNormalItems.isEmpty || initialOutputCandidates.isEmpty) {
      return _latestNormalStartup(initialNormalItems);
    }

    final initialLatestNormalSequence = initialNormalItems.last.sequence;

    final maxWait = engine.owner.startupPrefetchWaitTimeout > Duration.zero
        ? engine.owner.startupPrefetchWaitTimeout
        : const Duration(milliseconds: 1200);

    final deadline = DateTime.now().add(maxWait);

    TwitchHlsSegmentItem? bestOpenedFuture;

    while (!_stopped &&
        !engine.isStopped &&
        DateTime.now().isBefore(deadline)) {
      final normalItems = engine.snapshotNormalItems();
      final outputCandidates = engine.snapshotOutputCandidates();

      if (normalItems.isNotEmpty && outputCandidates.isNotEmpty) {
        final futureCandidates = _futureStartupCandidates(
          normalItems: normalItems,
          outputCandidates: outputCandidates,
        );

        final hotFuture = _findFutureWithPrefetchState(
          candidates: futureCandidates,
          requireFirstChunk: true,
          allowResponseOpened: false,
        );

        if (hotFuture != null) {
          return hotFuture;
        }

        bestOpenedFuture ??= _findFutureWithPrefetchState(
          candidates: futureCandidates,
          requireFirstChunk: false,
          allowResponseOpened: true,
        );

        final freshNormalCandidates = _candidatesFromPool(
          pool: normalItems,
          startSequence: initialLatestNormalSequence + 1,
        );

        if (freshNormalCandidates.isNotEmpty) {
          return bestOpenedFuture ?? freshNormalCandidates.first;
        }
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 80),
      );
    }

    final latestNormalItems = engine.snapshotNormalItems();
    final latestOutputCandidates = engine.snapshotOutputCandidates();

    if (latestNormalItems.isNotEmpty && latestOutputCandidates.isNotEmpty) {
      final futureCandidates = _futureStartupCandidates(
        normalItems: latestNormalItems,
        outputCandidates: latestOutputCandidates,
      );

      final hotFuture = _findFutureWithPrefetchState(
        candidates: futureCandidates,
        requireFirstChunk: true,
        allowResponseOpened: false,
      );

      if (hotFuture != null) return hotFuture;

      bestOpenedFuture ??= _findFutureWithPrefetchState(
        candidates: futureCandidates,
        requireFirstChunk: false,
        allowResponseOpened: true,
      );

      if (bestOpenedFuture != null) return bestOpenedFuture;

      final freshNormalCandidates = _candidatesFromPool(
        pool: latestNormalItems,
        startSequence: initialLatestNormalSequence + 1,
      );

      if (freshNormalCandidates.isNotEmpty) {
        return freshNormalCandidates.first;
      }

      return _latestNormalStartup(latestNormalItems);
    }

    return _latestNormalStartup(initialNormalItems);
  }

  Future<TwitchHlsSegmentItem?> _streamlinkLiveEdgeStartup() async {
    final maxWait = engine.owner.startupPrefetchWaitTimeout > Duration.zero
        ? engine.owner.startupPrefetchWaitTimeout
        : const Duration(milliseconds: 1400);

    final deadline = DateTime.now().add(maxWait);

    TwitchHlsSegmentItem? bestFallback;

    while (!_stopped &&
        !engine.isStopped &&
        DateTime.now().isBefore(deadline)) {
      final outputCandidates = engine.snapshotOutputCandidates();

      final selected = _streamlinkLiveEdgeCandidate(outputCandidates);

      if (selected != null) {
        if (selected.isPrefetch) {
          // Streamlink-like:
          // 選到 prefetch/future 就直接拿它，不要求 firstChunk。
          // 真正等待發生在 _writeItem() 裡的 active prefetch stream / direct GET。
          return selected;
        }

        bestFallback = selected;

        // 如果 live_edge > 1，選到 normal 是合理行為。
        // 如果 live_edge == 1 但目前還沒有 future，就多等一點看 future 會不會出現。
        if (!engine.owner.outputFutureSegments ||
            engine.owner.edgeSegmentCount > 1) {
          return selected;
        }
      }

      await engine.waitForPlaylistUpdate(
        timeout: const Duration(milliseconds: 80),
      );
    }

    return bestFallback ?? _latestNormalStartup(engine.snapshotNormalItems());
  }

  TwitchHlsSegmentItem? _streamlinkLiveEdgeCandidate(
    List<TwitchHlsSegmentItem> outputCandidates,
  ) {
    final pool =
        outputCandidates
            .where(
              (item) =>
                  !_sessionWrittenUrls.contains(item.url) &&
                  !_sessionWrittenSequences.contains(item.sequence) &&
                  item.sequence > _lastWrittenSequence,
            )
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));

    if (pool.isEmpty) return null;

    final liveEdge = math.max(engine.owner.edgeSegmentCount, 1);
    final index = math.max(pool.length - liveEdge, 0);

    return pool[index];
  }

  List<TwitchHlsSegmentItem> _futureStartupCandidates({
    required List<TwitchHlsSegmentItem> normalItems,
    required List<TwitchHlsSegmentItem> outputCandidates,
  }) {
    if (normalItems.isEmpty) return const <TwitchHlsSegmentItem>[];

    final latestNormalSequence = normalItems.last.sequence;

    final futurePool = outputCandidates
        .where((item) => item.sequence > latestNormalSequence)
        .toList();

    return _candidatesFromPool(
      pool: futurePool,
      startSequence: latestNormalSequence + 1,
    );
  }

  TwitchHlsSegmentItem? _findFutureWithPrefetchState({
    required List<TwitchHlsSegmentItem> candidates,
    required bool requireFirstChunk,
    required bool allowResponseOpened,
  }) {
    for (final item in candidates) {
      final state = engine.prefetchStateForItem(item);
      final job = engine.peekPrefetchJob(item.url);

      if (job == null || job.cancelled) continue;
      if (state == null || state.failed) continue;

      if (requireFirstChunk) {
        if (state.hasFirstChunk) return item;
        continue;
      }

      if (allowResponseOpened && state.responseOpened) {
        return item;
      }
    }

    return null;
  }

  TwitchHlsSegmentItem? _selectNextItem() {
    final outputCandidates = engine.snapshotOutputCandidates();
    if (outputCandidates.isEmpty) return null;

    final latestPlayable = engine.latestPlayableSequence();
    final maxBacklog = engine.maxOutputBacklogSegments();
    final minSequenceToKeep = latestPlayable - maxBacklog + 1;

    final candidates = outputCandidates.where((item) {
      if (_sessionWrittenUrls.contains(item.url)) return false;
      if (_sessionWrittenSequences.contains(item.sequence)) return false;
      if (item.sequence <= _lastWrittenSequence) return false;

      if (engine.owner.dropBehindLiveEdge &&
          item.sequence < minSequenceToKeep) {
        engine.markSkipped(item);
        return false;
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => a.sequence.compareTo(b.sequence));

    if (engine.owner.dropBehindLiveEdge && _lastWrittenSequence >= 0) {
      final lagSegments = latestPlayable - _lastWrittenSequence;
      if (lagSegments > maxBacklog + 1) {
        final liveEdge = math.max(engine.owner.edgeSegmentCount, 1);
        final catchupStartSequence = latestPlayable - liveEdge + 1;

        final catchupCandidates = candidates
            .where((item) => item.sequence >= catchupStartSequence)
            .toList();

        if (catchupCandidates.isNotEmpty) {
          for (final item in candidates) {
            if (item.sequence < catchupStartSequence) {
              engine.markSkipped(item);
            }
          }

          catchupCandidates.sort((a, b) => a.sequence.compareTo(b.sequence));
          return catchupCandidates.first;
        }
      }
    }

    return candidates.first;
  }

  int _edgeStartSequence(List<TwitchHlsSegmentItem> pool) {
    final safeStartupEdgeSegmentCount = math
        .max(
          engine.owner.startupEdgeSegmentCount,
          engine.owner.edgeSegmentCount,
        )
        .clamp(1, pool.length)
        .toInt();

    final startAt = pool.length > safeStartupEdgeSegmentCount
        ? pool.length - safeStartupEdgeSegmentCount
        : 0;

    return pool[startAt].sequence;
  }

  List<TwitchHlsSegmentItem> _candidatesFromPool({
    required List<TwitchHlsSegmentItem> pool,
    required int startSequence,
  }) {
    return pool
        .where(
          (item) =>
              item.sequence >= startSequence &&
              !_sessionWrittenUrls.contains(item.url) &&
              !_sessionWrittenSequences.contains(item.sequence) &&
              item.sequence > _lastWrittenSequence,
        )
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  Future<void> _writeItem(TwitchHlsSegmentItem item) async {
    if (_stopped) return;

    if (engine.owner.dropBehindLiveEdge) {
      final latestPlayable = engine.latestPlayableSequence();
      final maxBacklog = engine.maxOutputBacklogSegments();
      final minSequenceToKeep = latestPlayable - maxBacklog + 1;

      if (item.sequence < minSequenceToKeep) {
        engine.markSkipped(item);
        return;
      }
    }

    final liveOutput = output;
    if (liveOutput is TwitchHlsLiveByteBus) {
      // Keep replay aligned to a media-segment boundary.
      // If media_kit reconnects while the writer is already running, it gets
      // the current segment from its beginning instead of arbitrary old bytes.
      liveOutput.beginSegment();
    }

    if (item.mapUrl != null && item.mapUrl != _lastMapUrl) {
      _lastMapUrl = item.mapUrl;

      final mapBytes = await engine.owner._loadInitMapBytes(item.mapUrl!);
      await output.addStream(Stream<List<int>>.value(mapBytes));
    }

    final prefetchJob = engine.takePrefetchJob(item.url);

    await engine.owner._pipeSegmentToOutputBuffer(
      output: output,
      item: item,
      prefetchJob: prefetchJob,
    );

    _sessionWrittenUrls.add(item.url);
    _sessionWrittenSequences.add(item.sequence);

    if (_sessionWrittenSequences.length > 320) {
      final minKeep = item.sequence - 180;
      _sessionWrittenSequences.removeWhere((value) => value < minKeep);
    }
    while (_sessionWrittenUrls.length > 320) {
      _sessionWrittenUrls.remove(_sessionWrittenUrls.first);
    }

    if (item.sequence > _lastWrittenSequence) {
      _lastWrittenSequence = item.sequence;
    }

    engine.markWritten(item);

    _writtenOutputDuration += item.duration;
    _lastWrittenDuration = item.duration;
    _lastWrittenWasPrefetch = item.isPrefetch;
    _lastWrittenAt = DateTime.now();
    engine.rememberWrittenItem(item);
  }
}
