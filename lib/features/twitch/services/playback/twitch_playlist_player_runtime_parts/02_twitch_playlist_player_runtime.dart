part of '../twitch_playlist_player_runtime.dart';

class TwitchPlaylistPlayerRuntime extends ChangeNotifier {
  final TwitchPlaybackApiService playbackApi;
  final Dio _dio;
  bool _disposed = false;

  static const Map<String, String> defaultUpstreamHeaders = <String, String>{
    'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
    'Origin': 'https://www.twitch.tv',
    'Referer': 'https://www.twitch.tv/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static const String _qualityKey = 'twitch_watch_v2_preferred_quality';
  static const String _qualityChannelPrefix =
      'twitch_watch_v2_preferred_quality_';
  static const String _legacyQualityKey = 'twitch_fvp_proxy_preferred_quality';
  static const String _legacyQualityChannelPrefix =
      'twitch_fvp_proxy_preferred_quality_';

  static const int _firstRunMobileFallbackHeight = 1080;
  static const int _firstRunMobileFallbackMaxFps = 60;
  static const Duration _dvrHealthyCheckInterval = Duration(seconds: 12);
  static const Duration _dvrUnavailableRetryInterval = Duration(seconds: 45);
  static const int _dvrFailuresBeforeRecovery = 3;
  static TwitchStableHlsProxyRouter? _sharedProxy;
  static TwitchLiveDvrBridgeProxy? _sharedBridgeProxy;
  static int _sharedBridgeSeekRequestId = 0;

  TwitchPlaylistPlayerRuntime({required this.playbackApi, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
            ),
          );

  String _channelLogin = '';
  Uri? _masterPlaylistUri;
  Uri? _playlistUri;
  Uri? _upstreamPlaylistUri;
  String? _proxyUrl;
  String? _proxyMpvUrl;
  TwitchHlsLiveStatus? _proxyLiveStatus;
  TwitchStableHlsProxyRouter? _proxy;
  TwitchLiveDvrBridgeProxy? _bridgeProxy;
  bool _loading = false;
  bool _switchingQuality = false;
  Object? _error;
  String _masterPlaylistText = '';
  List<TwitchM3u8Variant> _variants = const <TwitchM3u8Variant>[];
  TwitchM3u8Variant? _currentVariant;
  String _adAwareStatus = '';
  String? _lastPreferredQualityName;
  final bool _dvrProbeEnabled = true;
  bool _usingDvrPlaylist = false;
  bool _usingExternalVodPlayback = false;
  bool _usingLiveDvrReplay = false;
  bool _usingLiveBufferReplay = false;
  Duration? _liveBufferReplayCanonicalTarget;
  Uri? _liveDvrPlaylistOverride;
  String? _lastLiveUpstreamPlaylistUrl;
  Duration? _canonicalLiveElapsed;
  Duration? _canonicalLiveTotal;
  DateTime? _canonicalTimelineOrigin;
  DateTime? _canonicalTimingObservedAt;
  Timer? _dvrHealthTimer;
  bool _dvrHealthCheckRunning = false;
  int _dvrHealthGeneration = 0;
  TwitchDvrHealthState _dvrHealthState = TwitchDvrHealthState.inactive;
  DateTime? _lastDvrHealthCheck;
  DateTime? _lastDvrHealthyAt;
  int _dvrConsecutiveFailures = 0;
  Uri? _dvrArchiveUri;
  Duration? _latestDvrDuration;
  int? _latestDvrSequence;

  String get channelLogin => _channelLogin;
  Uri? get masterPlaylistUri => _masterPlaylistUri;
  Uri? get playlistUri => _playlistUri;
  Uri? get upstreamPlaylistUri => _upstreamPlaylistUri;
  String? get proxyUrl => _proxyUrl;
  String? get proxyMpvUrl => _proxyMpvUrl ?? _proxyUrl;
  TwitchHlsLiveStatus? get proxyLiveStatus => _proxyLiveStatus;
  bool get hasProxyUrl => _proxyUrl != null && _proxyUrl!.trim().isNotEmpty;
  TwitchStableHlsProxyRouter? get proxy => _proxy ?? _sharedProxy;
  bool get loading => _loading;
  bool get switchingQuality => _switchingQuality;
  bool get busy => _loading || _switchingQuality;
  Object? get error => _error;
  bool get hasPlaylist => _playlistUri != null;
  String get masterPlaylistText => _masterPlaylistText;
  List<TwitchM3u8Variant> get variants =>
      List<TwitchM3u8Variant>.unmodifiable(_variants);
  TwitchM3u8Variant? get currentVariant => _currentVariant;
  String get adAwareStatus => _adAwareStatus;
  String? get lastPreferredQualityName => _lastPreferredQualityName;
  bool get dvrProbeEnabled => _dvrProbeEnabled;
  bool get usingDvrPlaylist => _usingDvrPlaylist;
  bool get usingLiveDvrBridge =>
      _usingLiveDvrReplay && (_bridgeProxy?.isRunning ?? false);
  bool get usingLiveBufferReplay => _usingLiveBufferReplay;
  bool get hasLiveReplayBuffer {
    final router = _proxy ?? _sharedProxy;
    return !_usingExternalVodPlayback &&
        router != null &&
        router.isRunning &&
        router.hasInnerProxy;
  }

  bool get usingLiveTimelineReplay =>
      usingLiveDvrBridge || _usingLiveBufferReplay;
  bool get liveDvrBridgeAtLiveEdge =>
      (_bridgeProxy ?? _sharedBridgeProxy)?.isLiveMode ?? false;
  Duration? get liveDvrBridgeTimelinePosition {
    final bridgePosition = usingLiveDvrBridge
        ? _bridgeProxy?.timelinePosition
        : null;
    if (bridgePosition != null) return bridgePosition;
    if (!_usingLiveBufferReplay) return null;
    return _liveBufferReplayCanonicalTarget;
  }

  Duration? get liveDvrBridgeDuration =>
      (_bridgeProxy ?? _sharedBridgeProxy)?.latestDuration;
  bool get usingExternalVodPlayback => _usingExternalVodPlayback;
  bool get hasWarmLiveDvrBridge => _sharedBridgeProxy?.isRunning ?? false;
  TwitchDvrHealthState get dvrHealthState => _dvrHealthState;
  DateTime? get lastDvrHealthCheck => _lastDvrHealthCheck;
  DateTime? get lastDvrHealthyAt => _lastDvrHealthyAt;
  int get dvrConsecutiveFailures => _dvrConsecutiveFailures;
  Uri? get dvrArchiveUri => _dvrArchiveUri;
  Duration? get latestDvrDuration => _latestDvrDuration;
  Duration? get canonicalLiveTotal => _canonicalLiveTotal;
  Duration? get canonicalLiveElapsed => _canonicalLiveElapsed;
  DateTime? get canonicalTimelineOrigin => _canonicalTimelineOrigin;

  Duration? get canonicalLiveTimelineDuration {
    final total = _canonicalLiveTotal;
    final observedAt = _canonicalTimingObservedAt;
    if (total == null || observedAt == null) return total;
    final elapsed = DateTime.now().toUtc().difference(observedAt);
    return elapsed.isNegative ? total : total + elapsed;
  }

  void setLiveDvrPlaylistOverride(Uri? playlistUri) {
    _liveDvrPlaylistOverride = playlistUri;
  }

  Future<bool> warmLiveDvrBridge({required Uri dvrPlaylistUri}) async {
    try {
      var bridge = _sharedBridgeProxy;
      if (bridge == null || !bridge.isRunning) {
        bridge = TwitchLiveDvrBridgeProxy();
        _sharedBridgeProxy = bridge;
      }
      await bridge.open(dvrPlaylistUri: dvrPlaylistUri);
      _bridgeProxy = bridge;
      this._recordDvrHealthy(
        dvrPlaylistUri,
        duration: bridge.latestDuration,
        scheduleNextCheck: _currentVariant != null,
      );
      debugPrint('[DvrSequential] warmed archive=$dvrPlaylistUri');
      return true;
    } catch (error) {
      final bridge = _sharedBridgeProxy;
      _sharedBridgeProxy = null;
      if (identical(_bridgeProxy, bridge)) _bridgeProxy = null;
      await bridge?.close();
      this._recordDvrUnavailable(scheduleRetry: _currentVariant != null);
      debugPrint('[DvrSequential] warm failed: $error');
      return false;
    }
  }

  Future<Uri?> prepareLowLatencyLiveFromWarmUpstream({
    bool forceProxyReconnect = false,
  }) async {
    (_bridgeProxy ?? _sharedBridgeProxy)?.stopStreaming();
    _liveDvrPlaylistOverride = null;
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = false;
    _usingLiveDvrReplay = false;
    this._clearLiveBufferReplay();
    _bridgeProxy = null;

    final router = _proxy ?? _sharedProxy;
    final upstream = _lastLiveUpstreamPlaylistUrl;
    if (router == null ||
        !router.isRunning ||
        upstream == null ||
        upstream.trim().isEmpty) {
      return null;
    }

    debugPrint('[DvrSequential] return live upstream=$upstream');
    await router.switchUpstream(upstream, forceReconnect: forceProxyReconnect);
    await router.waitUntilPrewarmed();
    unawaited(_refreshCanonicalLiveTimingBestEffort());

    _proxy = router;
    _proxyUrl = _routerStreamTsPlaybackUrl(router);
    _proxyMpvUrl = _proxyUrl;
    _proxyLiveStatus = null;
    notifyListeners();
    return Uri.parse(_proxyUrl!);
  }

  String? get stableProxyPlaybackUrl {
    if (_usingExternalVodPlayback) return null;
    final router = _proxy ?? _sharedProxy;
    if (router == null || !router.isRunning) return null;
    return _routerStreamTsPlaybackUrl(router);
  }

  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    bool probeDvr = true,
  }) async {
    final login = channelLogin.trim().toLowerCase();
    if (login.isEmpty) {
      throw ArgumentError.value(
        channelLogin,
        'channelLogin',
        'channelLogin cannot be empty',
      );
    }

    this._stopDvrHealthMonitoring();
    _channelLogin = login;
    _loading = true;
    _switchingQuality = false;
    _error = null;
    _masterPlaylistUri = null;
    _masterPlaylistText = '';
    _variants = const <TwitchM3u8Variant>[];
    _currentVariant = null;
    _adAwareStatus = 'probing playback sources...';
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = false;
    _usingLiveDvrReplay = false;
    this._clearLiveBufferReplay();
    this._clearCanonicalLiveTiming();
    notifyListeners();

    try {
      final storedQuality = await _loadPreferredQualityName(login);
      final wantedQuality = preferredVariantName?.trim().isNotEmpty == true
          ? preferredVariantName!.trim()
          : storedQuality;
      _lastPreferredQualityName = wantedQuality;

      final candidates = await Future.wait<_PlaybackCandidate?>([
        _loadCandidate(
          login,
          platform: 'web',
          playerType: 'site',
          sourceTag: 'web-site',
          defaultHasAds: true,
        ),
        _loadCandidate(
          login,
          platform: 'android',
          playerType: 'autoplay',
          sourceTag: 'android-autoplay',
          defaultHasAds: false,
        ),
        _loadCandidate(
          login,
          platform: 'ios',
          playerType: 'site',
          sourceTag: 'ios-site',
          defaultHasAds: false,
        ),
      ]);

      final web = candidates
          .whereType<_PlaybackCandidate>()
          .where((c) => c.sourceTag == 'web-site')
          .firstOrNull;
      final android = candidates
          .whereType<_PlaybackCandidate>()
          .where((c) => c.sourceTag == 'android-autoplay')
          .firstOrNull;
      final ios = candidates
          .whereType<_PlaybackCandidate>()
          .where((c) => c.sourceTag == 'ios-site')
          .firstOrNull;
      final base = web ?? android ?? ios;
      if (base == null) {
        throw StateError('Twitch master playlist 載入失敗：所有 playback source 都失敗。');
      }

      final merged = _mergeAdAwareVariants(
        baseVariants: base.variants,
        cleanCandidates: [?android, ?ios],
      );

      _masterPlaylistUri = base.masterUri;
      _masterPlaylistText = base.masterPlaylistText;
      _variants = merged;
      _adAwareStatus =
          'web=${web?.variants.length ?? 0}, '
          'android=${android?.variants.length ?? 0}, '
          'ios=${ios?.variants.length ?? 0}, '
          'clean=${merged.where((v) => !v.hasAds).length}';

      final selected = preferredVariant == null
          ? this._findVariantBySavedPreference(merged, wantedQuality) ??
                selectDefaultVariant(
                  merged,
                  allowMobileStartupSafeQuality: wantedQuality == null,
                )
          : this._findMatchingMergedVariant(merged, preferredVariant) ??
                preferredVariant;

      if (selected == null) {
        _playlistUri = base.masterUri;
        _upstreamPlaylistUri = base.masterUri;
        return base.masterUri;
      }

      final variantToOpen = selected;
      _currentVariant = variantToOpen;
      _upstreamPlaylistUri = Uri.tryParse(variantToOpen.url) ?? base.masterUri;
      _playlistUri = await this._startProxyForVariant(
        variantToOpen,
        probeDvr: probeDvr,
      );
      return _playlistUri;
    } catch (e) {
      _error = e;
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) async {
    this._stopDvrHealthMonitoring();
    _switchingQuality = true;
    _error = null;
    notifyListeners();

    try {
      _currentVariant = variant;
      _upstreamPlaylistUri = Uri.tryParse(variant.url);
      _playlistUri = await this._startProxyForVariant(variant, probeDvr: false);
      await _savePreferredQualityName(_channelLogin, variant);
      return _playlistUri;
    } catch (e) {
      _error = e;
      return null;
    } finally {
      _switchingQuality = false;
      notifyListeners();
    }
  }

  void markExternalVodPlayback({required String channelLogin}) {
    this._stopDvrHealthMonitoring();
    _channelLogin = channelLogin.trim().toLowerCase();
    _loading = false;
    _switchingQuality = false;
    _error = null;
    _masterPlaylistUri = null;
    _upstreamPlaylistUri = null;
    _playlistUri = null;
    _masterPlaylistText = '';
    _variants = const <TwitchM3u8Variant>[];
    _currentVariant = null;
    _adAwareStatus = 'vod-fallback';
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = true;
    _usingLiveDvrReplay = false;
    this._clearLiveBufferReplay();
    _liveDvrPlaylistOverride = null;
    notifyListeners();
  }

  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({
    bool notify = true,
  }) async {
    final router = _proxy ?? _sharedProxy;
    if (router == null || !router.isRunning) {
      if (_proxyLiveStatus != null) {
        _proxyLiveStatus = null;
        if (notify) notifyListeners();
      }
      return null;
    }

    _proxy = router;
    final status = await router.requestLiveStatus();
    if (status != null) {
      _proxyLiveStatus = status;
      if (notify) notifyListeners();
    }
    return status;
  }

  Future<void> refreshCanonicalLiveTiming() async {
    await _refreshCanonicalLiveTimingBestEffort();
  }

  Future<void> _refreshCanonicalLiveTimingBestEffort() async {
    final rawUrl = _lastLiveUpstreamPlaylistUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;
    try {
      final response = await _dio.getUri<String>(
        Uri.parse(rawUrl),
        options: Options(
          responseType: ResponseType.plain,
          headers: defaultUpstreamHeaders,
          receiveTimeout: const Duration(seconds: 4),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final text = response.data ?? '';
      if ((response.statusCode ?? 0) >= 400 || !text.contains('#EXTM3U')) {
        return;
      }
      final media = TwitchHlsPlaylistParser.parse(
        text,
        playlistUrl: response.realUri.toString(),
      );
      final total = media.twitchTotal;
      if (total == null) return;
      _canonicalLiveElapsed = media.twitchElapsed;
      _canonicalLiveTotal = total;
      _canonicalTimelineOrigin = media.timelineOrigin;
      _canonicalTimingObservedAt =
          media.timingObservedAt ?? DateTime.now().toUtc();
      debugPrint(
        '[CanonicalTimeline] elapsed=${_formatSeconds(media.twitchElapsed)} '
        'total=${_formatSeconds(total)} '
        'origin=${media.timelineOrigin?.toUtc().toIso8601String() ?? '-'}',
      );
    } catch (error) {
      debugPrint('[CanonicalTimeline] refresh failed: $error');
    }
  }

  Duration _canonicalizeDvrPosition(Duration fallbackPosition, DateTime? _) {
    // The UI/controller already owns the absolute HLS canonical target. Do not
    // reinterpret it through a possibly older live-total snapshot here.
    return fallbackPosition.isNegative ? Duration.zero : fallbackPosition;
  }

  Future<({String playbackUrl, Duration startPosition})?>
  seekLiveDvrBridgePosition(
    Duration position, {
    DateTime? targetProgramDateTime,
  }) async {
    final requestId = ++_sharedBridgeSeekRequestId;
    final bridge = _bridgeProxy ?? _sharedBridgeProxy;
    if (bridge == null || !bridge.isRunning) {
      debugPrint('[DvrSequential] seek ignored: proxy not running');
      return null;
    }

    // Refresh timing in parallel for future seeks, but preserve this seek's
    // already-selected absolute canonical position exactly.
    unawaited(_refreshCanonicalLiveTimingBestEffort());
    final canonicalPosition = _canonicalizeDvrPosition(
      position,
      targetProgramDateTime,
    );
    debugPrint(
      '[DvrSequential] runtime seek position=${_formatSeconds(position)}s '
      'canonical=${_formatSeconds(canonicalPosition)}s '
      'programTime=${targetProgramDateTime?.toUtc().toIso8601String() ?? '-'}',
    );
    final startPosition = await bridge.seekToPosition(
      canonicalPosition,
      targetProgramDateTime: targetProgramDateTime,
    );

    if (requestId != _sharedBridgeSeekRequestId) {
      debugPrint('[DvrSequential] stale seek ignored request=$requestId');
      return null;
    }

    final playbackUrl = bridge.streamTsPlaybackUrl;
    _bridgeProxy = bridge;
    _usingDvrPlaylist = true;
    _usingExternalVodPlayback = false;
    _usingLiveDvrReplay = true;
    this._clearLiveBufferReplay();
    _liveDvrPlaylistOverride = null;
    debugPrint('[DvrSequential] direct TS seek player=$playbackUrl');
    this._notifyListenersAfterFrame();
    return (playbackUrl: playbackUrl, startPosition: startPosition);
  }

  Future<String?> seekLiveBufferReplay({
    Duration? canonicalTarget,
    Duration? fromLive,
    required Duration timelineDuration,
  }) async {
    final router = _proxy ?? _sharedProxy;
    if (router == null || !router.isRunning) {
      debugPrint('[LiveBufferReplay] seek ignored: live router not running');
      return null;
    }

    final requestedTarget =
        canonicalTarget ??
        (fromLive == null
            ? null
            : Duration(
                microseconds:
                    (timelineDuration.inMicroseconds - fromLive.inMicroseconds)
                        .clamp(0, timelineDuration.inMicroseconds)
                        .toInt(),
              ));
    if (requestedTarget == null) {
      debugPrint('[LiveBufferReplay] seek ignored: target missing');
      return null;
    }

    final safeTarget = Duration(
      microseconds: requestedTarget.inMicroseconds
          .clamp(0, timelineDuration.inMicroseconds)
          .toInt(),
    );
    final safeFromLive = Duration(
      microseconds:
          (timelineDuration.inMicroseconds - safeTarget.inMicroseconds)
              .clamp(0, const Duration(seconds: 20).inMicroseconds)
              .toInt(),
    );
    await router.switchLiveReplayStream(canonicalTarget: safeTarget);
    final playbackUrl = _routerStreamTsPlaybackUrl(router);

    _proxy = router;
    _proxyUrl = playbackUrl;
    _proxyMpvUrl = playbackUrl;
    _proxyLiveStatus = null;
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = false;
    _usingLiveDvrReplay = false;
    _usingLiveBufferReplay = true;
    _liveBufferReplayCanonicalTarget = safeTarget;
    _bridgeProxy = null;
    _liveDvrPlaylistOverride = null;
    debugPrint(
      '[LiveBufferReplay] route target=${_formatSeconds(safeTarget)}s '
      'fromLive=${_formatSeconds(safeFromLive)}s player=$playbackUrl',
    );
    this._notifyListenersAfterFrame();
    return playbackUrl;
  }

  TwitchM3u8Variant? selectDefaultVariant(
    List<TwitchM3u8Variant> variants, {
    bool allowMobileStartupSafeQuality = true,
  }) {
    if (variants.isEmpty) return null;
    final videos = variants.where((v) => !v.isAudioOnly).toList();
    final pool = videos.isNotEmpty ? videos : variants.toList();

    if (allowMobileStartupSafeQuality && _prefersMobileStartupSafeQuality) {
      final safe = pool.where((v) {
        final fps = v.fpsRounded;
        return v.height > 0 &&
            v.height <= _firstRunMobileFallbackHeight &&
            (fps == 0 || fps <= _firstRunMobileFallbackMaxFps);
      }).toList();
      if (safe.isNotEmpty) return this._sortVariants(safe).first;
    }

    final source = pool.where(this._isSourceLikeVariant).firstOrNull;
    if (source != null) return source;
    return this._sortVariants(pool).first;
  }

  bool get _prefersMobileStartupSafeQuality {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  void clear() {
    unawaited(this._stopProxy(notify: false, closeShared: true));
    _channelLogin = '';
    _masterPlaylistUri = null;
    _playlistUri = null;
    _upstreamPlaylistUri = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _proxyLiveStatus = null;
    _loading = false;
    _switchingQuality = false;
    _error = null;
    _masterPlaylistText = '';
    _variants = const <TwitchM3u8Variant>[];
    _currentVariant = null;
    _adAwareStatus = '';
    this._clearLiveBufferReplay();
    this._clearCanonicalLiveTiming();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dio.close(force: true);
    unawaited(this._stopProxy(notify: false, closeShared: false));
    super.dispose();
  }

  Map<String, dynamic> toJson() {
    final router = _proxy ?? _sharedProxy;
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'loading': loading,
      'switchingQuality': switchingQuality,
      'hasPlaylist': hasPlaylist,
      'adAwareStatus': adAwareStatus,
      'dvrHealthState': dvrHealthState.name,
      'lastDvrHealthCheck': lastDvrHealthCheck?.toIso8601String(),
      'lastDvrHealthyAt': lastDvrHealthyAt?.toIso8601String(),
      'dvrConsecutiveFailures': dvrConsecutiveFailures,
      'dvrArchiveUri': dvrArchiveUri?.toString(),
      'latestDvrDurationSeconds': latestDvrDuration?.inSeconds,
      'latestDvrSequence': _latestDvrSequence,
      'lastPreferredQualityName': lastPreferredQualityName,
      'masterPlaylistUriPreview': masterPlaylistUri?.toString(),
      'playlistUriPreview': playlistUri?.toString(),
      'variantCount': variants.length,
      'currentVariant': currentVariant?.toString(),
      'upstreamPlaylistUri': upstreamPlaylistUri?.toString(),
      'proxyUrl': proxyUrl,
      'proxyMpvUrl': proxyMpvUrl,
      'stableProxyPlaybackUrl': stableProxyPlaybackUrl,
      'proxyStreamUrl': router?.streamUrl,
      'proxyLiveStatus': proxyLiveStatus?.toJson(),
      'proxyRunning': router?.isRunning ?? false,
      'proxyStablePort': router?.port,
      'proxyStableUpstream': router?.upstreamPlaylistUrl,
      'canonicalElapsedSeconds': this._formatSeconds(_canonicalLiveElapsed),
      'canonicalTotalSeconds': this._formatSeconds(_canonicalLiveTotal),
      'canonicalTimelineOrigin': _canonicalTimelineOrigin?.toIso8601String(),
      'canonicalTimingObservedAt': _canonicalTimingObservedAt
          ?.toIso8601String(),
      'error': error?.toString(),
    };
  }

  void _notifyPartListeners() => notifyListeners();
  bool get _partHasListeners => hasListeners;
}
