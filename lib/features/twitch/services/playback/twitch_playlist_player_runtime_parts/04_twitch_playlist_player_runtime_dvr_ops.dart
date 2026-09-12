part of '../twitch_playlist_player_runtime.dart';

extension _TwitchPlaylistPlayerRuntimeDvrOps on TwitchPlaylistPlayerRuntime {
  void _beginDvrHealthMonitoring({
    Uri? archiveUri,
    required bool initiallyHealthy,
  }) {
    _dvrHealthTimer?.cancel();
    _dvrHealthGeneration++;
    _dvrConsecutiveFailures = 0;
    _lastDvrHealthCheck = null;
    _latestDvrSequence = null;
    if (archiveUri != null) _dvrArchiveUri = archiveUri;
    if (initiallyHealthy) {
      _dvrHealthState = TwitchDvrHealthState.healthy;
      _lastDvrHealthyAt = DateTime.now().toUtc();
      _latestDvrDuration =
          TwitchPlaylistPlayerRuntime._sharedBridgeProxy?.latestDuration;
    } else {
      _dvrArchiveUri = null;
      _latestDvrDuration = null;
      _dvrHealthState = TwitchDvrHealthState.unavailable;
    }
    this._scheduleDvrHealthCheck(
      initiallyHealthy
          ? TwitchPlaylistPlayerRuntime._dvrHealthyCheckInterval
          : TwitchPlaylistPlayerRuntime._dvrUnavailableRetryInterval,
      _dvrHealthGeneration,
    );
    this._notifyListenersAfterFrame();
  }

  void _scheduleDvrHealthCheck(Duration delay, int generation) {
    _dvrHealthTimer?.cancel();
    if (_disposed || generation != _dvrHealthGeneration) return;
    final variant = _currentVariant;
    if (variant == null || variant.isAudioOnly || _usingExternalVodPlayback) {
      return;
    }
    _dvrHealthTimer = Timer(
      delay,
      () => unawaited(this._runDvrHealthCheck(generation)),
    );
  }

  Future<void> _runDvrHealthCheck(int generation) async {
    if (_disposed ||
        generation != _dvrHealthGeneration ||
        _dvrHealthCheckRunning ||
        _usingExternalVodPlayback) {
      return;
    }
    final variant = _currentVariant;
    if (variant == null || variant.isAudioOnly) return;

    _dvrHealthCheckRunning = true;
    final stateBeforeCheck = _dvrHealthState;
    _lastDvrHealthCheck = DateTime.now().toUtc();
    var nextDelay = TwitchPlaylistPlayerRuntime._dvrHealthyCheckInterval;
    try {
      final bridge = TwitchPlaylistPlayerRuntime._sharedBridgeProxy;
      if (bridge == null || !bridge.isRunning || _dvrArchiveUri == null) {
        await this._recoverDvrArchive(variant, generation);
      } else {
        final health = await bridge.probeArchiveHealth();
        if (generation != _dvrHealthGeneration || _disposed) return;
        _dvrArchiveUri = health.playlistUri;
        _latestDvrDuration = health.indexedDuration;
        _latestDvrSequence = health.latestSequence;
        if (health.advanced) {
          _dvrConsecutiveFailures = 0;
          _dvrHealthState = TwitchDvrHealthState.healthy;
          _lastDvrHealthyAt = DateTime.now().toUtc();
          _debugDvr(
            'health healthy sequence=${health.latestSequence} '
            'duration=${health.indexedDuration.inSeconds}s',
          );
        } else {
          await this._recordDvrHealthFailure(
            variant,
            generation,
            reason: 'archive did not advance',
          );
        }
      }
    } catch (error) {
      if (generation == _dvrHealthGeneration && !_disposed) {
        await this._recordDvrHealthFailure(
          variant,
          generation,
          reason: error.toString(),
        );
      }
    } finally {
      _dvrHealthCheckRunning = false;
      if (generation == _dvrHealthGeneration && !_disposed) {
        if (_dvrHealthState == TwitchDvrHealthState.unavailable) {
          nextDelay = TwitchPlaylistPlayerRuntime._dvrUnavailableRetryInterval;
        }
        this._scheduleDvrHealthCheck(nextDelay, generation);
        if (_dvrHealthState != stateBeforeCheck) {
          this._notifyListenersAfterFrame();
        }
      }
    }
  }

  Future<void> _recordDvrHealthFailure(
    TwitchM3u8Variant variant,
    int generation, {
    required String reason,
  }) async {
    _dvrConsecutiveFailures++;
    _dvrHealthState = TwitchDvrHealthState.stale;
    _debugDvr('health stale failures=$_dvrConsecutiveFailures reason=$reason');
    if (_dvrConsecutiveFailures <
        TwitchPlaylistPlayerRuntime._dvrFailuresBeforeRecovery)
      return;
    if (_usingLiveDvrReplay) {
      _debugDvr('health recovery deferred while DVR replay is active');
      return;
    }
    await this._recoverDvrArchive(variant, generation);
  }

  Future<void> _recoverDvrArchive(
    TwitchM3u8Variant variant,
    int generation,
  ) async {
    if (generation != _dvrHealthGeneration || _disposed) return;
    _dvrHealthState = _dvrArchiveUri == null
        ? TwitchDvrHealthState.probing
        : TwitchDvrHealthState.recovering;
    _debugDvr('health ${_dvrHealthState.name} variant=${variant.name}');

    final resolvedUri = await this._resolveDvrPlaylistUri(variant);
    if (generation != _dvrHealthGeneration || _disposed) return;
    if (resolvedUri == null) {
      this._recordDvrUnavailable(scheduleRetry: false);
      return;
    }

    final replacement = TwitchLiveDvrBridgeProxy();
    TwitchLiveDvrBridgeProxy? previous;
    try {
      await replacement.open(dvrPlaylistUri: resolvedUri);
      if (generation != _dvrHealthGeneration || _disposed) {
        await replacement.close();
        return;
      }
      previous = TwitchPlaylistPlayerRuntime._sharedBridgeProxy;
      TwitchPlaylistPlayerRuntime._sharedBridgeProxy = replacement;
      if (!_usingLiveDvrReplay &&
          (_bridgeProxy == null || identical(_bridgeProxy, previous))) {
        _bridgeProxy = replacement;
      }
      this._recordDvrHealthy(
        resolvedUri,
        duration: replacement.latestDuration,
        scheduleNextCheck: false,
      );
      _debugDvr(
        'health recovered archive=$resolvedUri '
        'duration=${replacement.latestDuration?.inSeconds ?? 0}s',
      );
    } catch (error) {
      await replacement.close();
      this._recordDvrUnavailable(scheduleRetry: false);
      _debugDvr('health recovery failed: $error');
      return;
    }
    if (previous != null && !identical(previous, replacement)) {
      try {
        await previous.close();
      } catch (error) {
        _debugDvr('retired DVR bridge close failed: $error');
      }
    }
  }

  void _recordDvrHealthy(
    Uri playlistUri, {
    Duration? duration,
    required bool scheduleNextCheck,
  }) {
    _dvrArchiveUri = playlistUri;
    _latestDvrDuration = duration;
    _dvrConsecutiveFailures = 0;
    _dvrHealthState = TwitchDvrHealthState.healthy;
    _lastDvrHealthyAt = DateTime.now().toUtc();
    if (scheduleNextCheck) {
      _dvrHealthGeneration++;
      this._scheduleDvrHealthCheck(
        TwitchPlaylistPlayerRuntime._dvrHealthyCheckInterval,
        _dvrHealthGeneration,
      );
      this._notifyListenersAfterFrame();
    }
  }

  void _recordDvrUnavailable({required bool scheduleRetry}) {
    _dvrArchiveUri = null;
    _latestDvrDuration = null;
    _latestDvrSequence = null;
    _dvrConsecutiveFailures = 0;
    _dvrHealthState = TwitchDvrHealthState.unavailable;
    if (scheduleRetry) {
      _dvrHealthGeneration++;
      this._scheduleDvrHealthCheck(
        TwitchPlaylistPlayerRuntime._dvrUnavailableRetryInterval,
        _dvrHealthGeneration,
      );
      this._notifyListenersAfterFrame();
    }
  }

  void _stopDvrHealthMonitoring() {
    _dvrHealthTimer?.cancel();
    _dvrHealthTimer = null;
    _dvrHealthGeneration++;
    _dvrHealthCheckRunning = false;
    _dvrHealthState = TwitchDvrHealthState.inactive;
    _lastDvrHealthCheck = null;
    _lastDvrHealthyAt = null;
    _dvrConsecutiveFailures = 0;
    _dvrArchiveUri = null;
    _latestDvrDuration = null;
    _latestDvrSequence = null;
  }

  Future<Uri?> _resolveDvrPlaylistUri(TwitchM3u8Variant variant) async {
    final direct = this._buildDvrPlaylistUri(variant.url);
    if (direct != null) return direct;

    try {
      _debugDvr('resolve media playlist ${variant.name}: ${variant.url}');
      final response = await _dio.getUri<String>(
        Uri.parse(variant.url),
        options: Options(
          responseType: ResponseType.plain,
          headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final statusCode = response.statusCode ?? 0;
      final text = response.data ?? '';
      _debugDvr(
        'media playlist ${variant.name}: status=$statusCode real=${response.realUri}',
      );
      if (statusCode >= 400 || !text.contains('#EXTM3U')) return null;

      final fromRealUri = this._buildDvrPlaylistUri(
        response.realUri.toString(),
      );
      if (fromRealUri != null) return fromRealUri;

      return await this._buildDvrPlaylistUriFromMediaPlaylist(
        playlistUri: response.realUri,
        playlistText: text,
      );
    } catch (error) {
      _debugDvr('resolve media playlist error ${variant.name}: $error');
      return null;
    }
  }

  Future<Uri?> _buildDvrPlaylistUriFromMediaPlaylist({
    required Uri playlistUri,
    required String playlistText,
  }) async {
    for (final rawLine in playlistText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final segmentUri = playlistUri.resolve(line);
      _debugDvr('first segment candidate: $segmentUri');
      final fromFinalSegment = await this._buildDvrPlaylistUriFromFinalSegment(
        segmentUri,
      );
      if (fromFinalSegment != null) return fromFinalSegment;

      final fromSegment = _buildDvrPlaylistUriFromSegment(segmentUri);
      if (fromSegment != null) return fromSegment;
    }
    return null;
  }

  Future<Uri?> _buildDvrPlaylistUriFromFinalSegment(Uri segmentUri) async {
    final headResult = await this._resolveSegmentFinalUri(
      segmentUri,
      method: 'HEAD',
    );
    final fromHead =
        headResult == null || this._isTwitchHlsSegmentProxy(headResult)
        ? null
        : _buildDvrPlaylistUriFromSegment(headResult);
    if (fromHead != null) return fromHead;

    final rangeResult = await this._resolveSegmentFinalUri(
      segmentUri,
      method: 'GET',
      rangeProbe: true,
    );
    return rangeResult == null || this._isTwitchHlsSegmentProxy(rangeResult)
        ? null
        : _buildDvrPlaylistUriFromSegment(rangeResult);
  }

  Uri? _buildDvrPlaylistUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final last = segments.last.toLowerCase();
    if (last == 'index-dvr.m3u8') return uri;
    if (last != 'index.m3u8' && last != 'playlist.m3u8') return null;

    final nextSegments = <String>[
      ...segments.take(segments.length - 1),
      'index-dvr.m3u8',
    ];
    return uri.replace(pathSegments: nextSegments);
  }
}

extension _TwitchPlaylistPlayerRuntimeProxyOps on TwitchPlaylistPlayerRuntime {
  bool _isTwitchHlsSegmentProxy(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('.hls.ttvnw.net') &&
        uri.pathSegments.contains('segment');
  }

  Future<void> _stopProxy({bool notify = true, bool closeShared = true}) async {
    this._stopDvrHealthMonitoring();
    final router = _proxy ?? TwitchPlaylistPlayerRuntime._sharedProxy;
    final bridge =
        _bridgeProxy ?? TwitchPlaylistPlayerRuntime._sharedBridgeProxy;
    _proxy = null;
    _bridgeProxy = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _proxyLiveStatus = null;
    _usingLiveDvrReplay = false;
    this._clearLiveBufferReplay();

    if (closeShared && router != null) {
      if (identical(TwitchPlaylistPlayerRuntime._sharedProxy, router))
        TwitchPlaylistPlayerRuntime._sharedProxy = null;
      await router.close();
    }
    if (closeShared && bridge != null) {
      if (identical(TwitchPlaylistPlayerRuntime._sharedBridgeProxy, bridge))
        TwitchPlaylistPlayerRuntime._sharedBridgeProxy = null;
      await bridge.close();
    }

    if (notify) _notifyPartListeners();
  }

  Future<String?> _loadPreferredQualityName(String login) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value =
          prefs.getString(
            '${TwitchPlaylistPlayerRuntime._qualityChannelPrefix}$login',
          ) ??
          prefs.getString(TwitchPlaylistPlayerRuntime._qualityKey) ??
          prefs.getString(
            '${TwitchPlaylistPlayerRuntime._legacyQualityChannelPrefix}$login',
          ) ??
          prefs.getString(TwitchPlaylistPlayerRuntime._legacyQualityKey);
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePreferredQualityName(
    String login,
    TwitchM3u8Variant variant,
  ) async {
    final name = variant.name.trim();
    if (login.trim().isEmpty || name.isEmpty) return;
    _lastPreferredQualityName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TwitchPlaylistPlayerRuntime._qualityKey, name);
      await prefs.setString(
        '${TwitchPlaylistPlayerRuntime._qualityChannelPrefix}${login.trim().toLowerCase()}',
        name,
      );
    } catch (_) {}
  }

  Future<_PlaybackCandidate?> _loadCandidate(
    String login, {
    required String platform,
    required String playerType,
    required String sourceTag,
    required bool defaultHasAds,
  }) async {
    try {
      final token = await playbackApi.getLivePlaybackAccessToken(
        channelLogin: login,
        platform: platform,
        playerType: playerType,
      );
      final masterUri = playbackApi.buildLivePlaylistUri(
        channelLogin: login,
        accessToken: token,
      );
      final response = await _dio.getUri<String>(
        masterUri,
        options: Options(
          responseType: ResponseType.plain,
          headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final text = response.data ?? '';
      if ((response.statusCode ?? 0) >= 400 || text.trim().isEmpty) {
        return null;
      }
      final variants = TwitchM3u8Parser.parseMasterPlaylist(
        text,
        masterUri: masterUri,
        defaultHasAds: defaultHasAds,
        sourceTag: sourceTag,
      );
      if (variants.isEmpty) return null;
      return _PlaybackCandidate(
        sourceTag: sourceTag,
        masterUri: masterUri,
        masterPlaylistText: text,
        token: token,
        variants: variants,
      );
    } catch (_) {
      return null;
    }
  }

  List<TwitchM3u8Variant> _mergeAdAwareVariants({
    required List<TwitchM3u8Variant> baseVariants,
    required List<_PlaybackCandidate> cleanCandidates,
  }) {
    if (baseVariants.isEmpty) {
      for (final c in cleanCandidates) {
        if (c.variants.isNotEmpty) return c.variants;
      }
      return const <TwitchM3u8Variant>[];
    }

    final cleanByKey = <String, TwitchM3u8Variant>{};
    for (final c in cleanCandidates) {
      for (final v in c.variants) {
        final old = cleanByKey[v.adAwareQualityKey];
        if (old == null || this._sortScore(v) > this._sortScore(old)) {
          cleanByKey[v.adAwareQualityKey] = v;
        }
      }
    }

    final merged = <TwitchM3u8Variant>[];
    final used = <String>{};
    for (final base in baseVariants) {
      final clean = cleanByKey[base.adAwareQualityKey];
      if (clean == null) {
        merged.add(
          base.copyWith(
            hasAds: true,
            sourceTag: base.sourceTag.isEmpty ? 'web-site' : base.sourceTag,
          ),
        );
      } else {
        used.add(clean.url);
        merged.add(
          base.copyWith(
            url: clean.url,
            hasAds: false,
            sourceTag: clean.sourceTag,
          ),
        );
      }
    }
    for (final clean in cleanByKey.values) {
      if (!used.contains(clean.url) && !merged.any((v) => v.url == clean.url)) {
        merged.add(clean.copyWith(hasAds: false));
      }
    }
    return this._sortVariants(merged);
  }

  void _clearLiveBufferReplay() {
    _usingLiveBufferReplay = false;
    _liveBufferReplayCanonicalTarget = null;
    TwitchCanonicalPlaybackClockRegistry.clearLocalReplayAnchor();
  }
}

extension _TwitchPlaylistPlayerRuntimeCoreOps on TwitchPlaylistPlayerRuntime {
  Future<Uri?> _resolveSegmentFinalUri(
    Uri segmentUri, {
    required String method,
    bool rangeProbe = false,
  }) async {
    try {
      final headers = <String, String>{
        ...TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
      };
      if (rangeProbe) headers['Range'] = 'bytes=0-0';

      final response = await _dio.requestUri<List<int>>(
        segmentUri,
        options: Options(
          method: method,
          responseType: ResponseType.bytes,
          headers: headers,
          receiveTimeout: const Duration(seconds: 6),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      _debugDvr(
        'segment $method: status=${response.statusCode} real=${response.realUri}',
      );
      if ((response.statusCode ?? 0) >= 400) return null;
      return response.realUri;
    } catch (error) {
      _debugDvr('segment $method error: $error');
      return null;
    }
  }

  Uri? _buildDvrPlaylistUriFromSegment(Uri segmentUri) {
    final segments = segmentUri.pathSegments;
    if (segments.length < 3) return null;
    final last = segments.last.toLowerCase();
    if (!last.endsWith('.ts') && !last.endsWith('.mp4')) return null;

    final base = segments.take(segments.length - 2).toList();
    return segmentUri.replace(
      pathSegments: <String>[...base, 'chunked', 'index-dvr.m3u8'],
      query: '',
    );
  }

  String _formatSeconds(Duration? value) {
    if (value == null) return '-';
    return (value.inMicroseconds / Duration.microsecondsPerSecond)
        .toStringAsFixed(3);
  }

  void _notifyListenersAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_partHasListeners) return;
      _notifyPartListeners();
    });
  }

  int _sortScore(TwitchM3u8Variant v) {
    var score = 0;
    if (!v.hasAds) score += 100000000;
    if (!v.isAudioOnly) score += 10000000;
    score += v.height * 10000;
    score += v.fpsRounded * 100;
    score += (v.bandwidth ?? 0) ~/ 1000;
    return score;
  }
}

extension _TwitchPlaylistPlayerRuntimeTimelineOps
    on TwitchPlaylistPlayerRuntime {
  void _clearCanonicalLiveTiming() {
    _canonicalLiveElapsed = null;
    _canonicalLiveTotal = null;
    _canonicalTimelineOrigin = null;
    _canonicalTimingObservedAt = null;
  }
}
