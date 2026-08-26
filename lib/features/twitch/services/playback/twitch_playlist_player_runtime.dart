import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/playback/twitch_playback_api_service.dart';
import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/playback/twitch_playback.dart';
import 'twitch_hls_low_latency_proxy.dart' show TwitchHlsStartupMode;
import 'twitch_live_dvr_bridge_proxy.dart';
import 'twitch_stable_hls_proxy_router.dart';

class TwitchPlaylistPlayerRuntime extends ChangeNotifier {
  final TwitchPlaybackApiService playbackApi;
  final Dio _dio;

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

  // First-run fallback only. User-selected quality always wins through
  // _loadPreferredQualityName(). This keeps WatchPage behavior client-like:
  // users decide their default quality, while the app only picks a reasonable
  // startup quality when no preference exists yet.
  static const int _firstRunMobileFallbackHeight = 1080;
  static const int _firstRunMobileFallbackMaxFps = 60;
  static const bool _directDvrPlaybackEnabled = bool.fromEnvironment(
    'TWITCH_DVR_DIRECT_PLAYBACK',
    defaultValue: false,
  );
  static const bool _forceDvrDirectPlaybackEnabled = bool.fromEnvironment(
    'TWITCH_FORCE_DVR_DIRECT_PLAYBACK',
    defaultValue: false,
  );

  static TwitchStableHlsProxyRouter? _sharedProxy;
  static TwitchLiveDvrBridgeProxy? _sharedBridgeProxy;
  static int _sharedProxyRevision = 0;
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
  Uri? _liveDvrPlaylistOverride;
  String? _lastLiveUpstreamPlaylistUrl;

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
  bool get usingLiveDvrBridge => _bridgeProxy?.isRunning ?? false;
  bool get liveDvrBridgeAtLiveEdge =>
      (_bridgeProxy ?? _sharedBridgeProxy)?.isLiveMode ?? false;
  double? get liveDvrBridgeTimelineRatio =>
      (_bridgeProxy ?? _sharedBridgeProxy)?.timelineRatio;
  Duration? get liveDvrBridgeDuration => _bridgeProxy?.latestDuration;
  bool get usingExternalVodPlayback => _usingExternalVodPlayback;
  bool get hasWarmLiveDvrBridge => _sharedBridgeProxy?.isRunning ?? false;

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
      debugPrint('[LiveDvrBridge] warmed dvr=$dvrPlaylistUri');
      return true;
    } catch (error) {
      final bridge = _sharedBridgeProxy;
      _sharedBridgeProxy = null;
      if (identical(_bridgeProxy, bridge)) _bridgeProxy = null;
      await bridge?.close();
      debugPrint('[LiveDvrBridge] warm failed: $error');
      return false;
    }
  }

  Future<Uri?> prepareLowLatencyLiveFromWarmUpstream() async {
    _liveDvrPlaylistOverride = null;
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = false;
    _bridgeProxy = null;

    final router = _proxy ?? _sharedProxy;
    final upstream = _lastLiveUpstreamPlaylistUrl;
    if (router == null ||
        !router.isRunning ||
        upstream == null ||
        upstream.trim().isEmpty) {
      return null;
    }

    debugPrint('[LiveDvrBridge] prewarm low-latency live upstream=$upstream');
    await router.switchUpstream(upstream);
    await router.waitUntilPrewarmed();

    _proxy = router;
    _proxyUrl = router.streamTsUrl;
    _proxyMpvUrl = _proxyUrl;
    _proxyLiveStatus = null;
    _sharedProxyRevision++;
    notifyListeners();
    return Uri.parse(router.streamTsUrl);
  }

  /// Stable playback URL for media_kit.
  ///
  /// The outer HLS router keeps this local URL stable while quality switching
  /// swaps only the router's inner upstream playlist. The player should open
  /// this URL once and stay attached; quality changes should not recreate
  /// Player / VideoController or call Player.open with a different local URL.
  String? get stableProxyPlaybackUrl {
    if (_usingDvrPlaylist && _proxyUrl?.trim().isNotEmpty == true) {
      return _proxyUrl;
    }
    if (usingLiveDvrBridge && _proxyUrl?.trim().isNotEmpty == true) {
      return _proxyUrl;
    }
    final router = _proxy ?? _sharedProxy;
    if (router == null || !router.isRunning) return null;
    return router.streamTsUrl;
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
          ? _findVariantBySavedPreference(merged, wantedQuality) ??
                selectDefaultVariant(
                  merged,
                  allowMobileStartupSafeQuality: wantedQuality == null,
                )
          : _findMatchingMergedVariant(merged, preferredVariant) ??
                preferredVariant;

      if (selected == null) {
        _playlistUri = base.masterUri;
        _upstreamPlaylistUri = base.masterUri;
        return base.masterUri;
      }

      final playbackVariant = _forceDvrDirectPlaybackEnabled
          ? await _findFirstDvrVariant(
              _orderedDvrProbeVariants(
                selected: selected,
                web: web,
                merged: merged,
              ),
            )
          : selected;
      if (_forceDvrDirectPlaybackEnabled && playbackVariant == null) {
        throw StateError('DVR direct 測試失敗：所有候選畫質都找不到可用的 index-dvr.m3u8。');
      }

      final variantToOpen = playbackVariant ?? selected;
      _currentVariant = variantToOpen;
      _upstreamPlaylistUri = Uri.tryParse(variantToOpen.url) ?? base.masterUri;
      _playlistUri = await _startProxyForVariant(
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
    _switchingQuality = true;
    _error = null;
    notifyListeners();

    try {
      _currentVariant = variant;
      _upstreamPlaylistUri = Uri.tryParse(variant.url);
      _playlistUri = await _startProxyForVariant(variant);
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
    _channelLogin = channelLogin.trim().toLowerCase();
    _loading = false;
    _switchingQuality = false;
    _error = null;
    _masterPlaylistUri = null;
    _playlistUri = null;
    _upstreamPlaylistUri = null;
    _masterPlaylistText = '';
    _variants = const <TwitchM3u8Variant>[];
    _currentVariant = null;
    _adAwareStatus = 'vod-fallback';
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = true;
    _liveDvrPlaylistOverride = null;
    notifyListeners();
  }

  Future<Uri?> _startProxyForVariant(
    TwitchM3u8Variant variant, {
    bool probeDvr = true,
  }) async {
    final overrideDvrUri = probeDvr ? _liveDvrPlaylistOverride : null;
    final probedVariant = overrideDvrUri == null
        ? probeDvr
              ? await _probeDvrVariant(variant)
              : variant
        : variant.copyWith(
            url: overrideDvrUri.toString(),
            sourceTag: variant.sourceTag.isEmpty
                ? 'dvr-override'
                : '${variant.sourceTag}+dvr-override',
          );
    final useDvrPlaylist =
        probedVariant.sourceTag.contains('+dvr') ||
        probedVariant.sourceTag == 'dvr' ||
        probedVariant.sourceTag == 'dvr-override';
    debugPrint(
      '[LiveDvrBridge] variant=${variant.name} '
      'source=${variant.sourceTag} useDvr=$useDvrPlaylist '
      'override=${overrideDvrUri != null} url=${variant.url}',
    );
    if (variant.url.trim().isNotEmpty) {
      _lastLiveUpstreamPlaylistUrl = variant.url;
    }
    final upstreamUri = Uri.tryParse(probedVariant.url);
    if (upstreamUri == null) {
      throw StateError('Invalid variant URL: ${probedVariant.url}');
    }
    if (_forceDvrDirectPlaybackEnabled && !useDvrPlaylist) {
      throw StateError('DVR direct 測試失敗：找不到可用的 index-dvr.m3u8。');
    }
    if (useDvrPlaylist &&
        (_directDvrPlaybackEnabled || _forceDvrDirectPlaybackEnabled)) {
      await _stopProxy(notify: false, closeShared: true);
      _currentVariant = probedVariant;
      _upstreamPlaylistUri = upstreamUri;
      _usingDvrPlaylist = true;
      _proxyUrl = probedVariant.url;
      _proxyMpvUrl = _proxyUrl;
      _proxyLiveStatus = null;
      _adAwareStatus = '${_adAwareStatus.trim()} dvr=direct'.trim();
      return upstreamUri;
    }

    if (useDvrPlaylist && !_forceDvrDirectPlaybackEnabled) {
      var bridge = _sharedBridgeProxy;
      if (bridge == null || !bridge.isRunning) {
        bridge = TwitchLiveDvrBridgeProxy();
        _sharedBridgeProxy = bridge;
      }
      try {
        await bridge.open(dvrPlaylistUri: upstreamUri);
      } catch (_) {
        if (identical(_sharedBridgeProxy, bridge)) _sharedBridgeProxy = null;
        if (identical(_bridgeProxy, bridge)) _bridgeProxy = null;
        await bridge.close();
        bridge = TwitchLiveDvrBridgeProxy();
        _sharedBridgeProxy = bridge;
        await bridge.open(dvrPlaylistUri: upstreamUri);
      }
      debugPrint(
        '[LiveDvrBridge] started dvr=$upstreamUri '
        'playlist=${bridge.playlistPlaybackUrl}',
      );
      final bridgePlaylistUrl = bridge.playlistPlaybackUrl;
      var router = _sharedProxy;
      final previousUpstream = router?.upstreamPlaylistUrl;
      if (router == null || !router.isRunning) {
        router = _createStableRouter();
        _sharedProxy = router;
        await router.start(upstreamPlaylistUrl: bridgePlaylistUrl);
        _sharedProxyRevision++;
      } else {
        await router.switchUpstream(bridgePlaylistUrl);
        if (previousUpstream != bridgePlaylistUrl) {
          _sharedProxyRevision++;
        }
      }
      await router.waitUntilPrewarmed();

      _proxy = router;
      _bridgeProxy = bridge;
      _currentVariant = probedVariant;
      _upstreamPlaylistUri = upstreamUri;
      _usingDvrPlaylist = true;
      _usingExternalVodPlayback = false;
      _proxyUrl = router.streamTsUrl;
      _proxyMpvUrl = _proxyUrl;
      _proxyLiveStatus = null;
      _adAwareStatus = '${_adAwareStatus.trim()} dvr=bridge'.trim();
      debugPrint(
        '[LiveDvrBridge] routed player=${router.streamTsUrl} '
        'upstream=${router.upstreamPlaylistUrl}',
      );
      return Uri.parse(router.streamTsUrl);
    }

    debugPrint('[LiveDvrBridge] fallback live proxy useDvr=$useDvrPlaylist');
    _bridgeProxy = null;

    var router = _sharedProxy;
    final previousUpstream = router?.upstreamPlaylistUrl;
    if (router == null || !router.isRunning) {
      router = _createStableRouter();
      _sharedProxy = router;
      _proxy = router;
      await router.start(upstreamPlaylistUrl: probedVariant.url);
      _sharedProxyRevision++;
    } else {
      _proxy = router;
      await router.switchUpstream(probedVariant.url);
      if (previousUpstream != probedVariant.url) {
        _sharedProxyRevision++;
      }
    }

    await router.waitUntilPrewarmed();

    // Keep the player-facing URL stable. Quality/source switching happens
    // inside TwitchStableHlsProxyRouter.switchUpstream(). This avoids forcing
    // media_kit to reopen a new local URL and keeps the VideoController surface
    // attached.
    _usingDvrPlaylist = useDvrPlaylist;
    _currentVariant = probedVariant;
    _proxyUrl = useDvrPlaylist ? router.playlistUrl : router.streamTsUrl;
    _proxyMpvUrl = _proxyUrl;
    _proxyLiveStatus = null;
    return Uri.tryParse(_proxyUrl!) ?? upstreamUri;
  }

  TwitchStableHlsProxyRouter _createStableRouter() {
    return TwitchStableHlsProxyRouter(
      upstreamHeaders: defaultUpstreamHeaders,
      edgeSegmentCount: 1,
      prefetchSegmentCount: 3,
      outputFutureSegments: true,
      futureOutputSegmentCount: 1,
      dropBehindLiveEdge: true,
      startupEdgeSegmentCount: 1,
      startupRequirePrefetchedFirstSegment: false,
      startupSkipCurrentLatestSegment: false,
      startupMode: TwitchHlsStartupMode.streamlinkLiveEdge,
      verboseLogging: false,
    );
  }

  Future<TwitchM3u8Variant> _probeDvrVariant(TwitchM3u8Variant variant) async {
    if (!_dvrProbeEnabled || variant.isAudioOnly) return variant;
    final dvrUri = await _resolveDvrPlaylistUri(variant);
    if (dvrUri == null) {
      _debugDvr(
        'skip ${variant.name}: cannot derive DVR URL from ${variant.url}',
      );
      return variant;
    }

    try {
      _debugDvr('probe ${variant.name} ${variant.sourceTag}: $dvrUri');
      final response = await _dio.getUri<String>(
        dvrUri,
        options: Options(
          responseType: ResponseType.plain,
          headers: defaultUpstreamHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final text = response.data ?? '';
      if ((response.statusCode ?? 0) >= 400 || !text.contains('#EXTM3U')) {
        _debugDvr(
          'fail ${variant.name}: status=${response.statusCode}, '
          'extm3u=${text.contains('#EXTM3U')}',
        );
        return variant;
      }
      if (!text.contains('#EXTINF')) {
        _debugDvr('fail ${variant.name}: playlist has no EXTINF');
        return variant;
      }

      _debugDvr('ok ${variant.name}: $dvrUri');
      _adAwareStatus = '${_adAwareStatus.trim()} dvr=ok'.trim();
      return variant.copyWith(
        url: dvrUri.toString(),
        sourceTag: variant.sourceTag.isEmpty
            ? 'dvr'
            : '${variant.sourceTag}+dvr',
      );
    } catch (error) {
      _debugDvr('error ${variant.name}: $error');
      return variant;
    }
  }

  Future<TwitchM3u8Variant?> _findFirstDvrVariant(
    List<TwitchM3u8Variant> variants,
  ) async {
    for (final variant in variants) {
      final probed = await _probeDvrVariant(variant);
      if (probed.sourceTag.contains('+dvr') || probed.sourceTag == 'dvr') {
        return probed;
      }
    }
    return null;
  }

  List<TwitchM3u8Variant> _orderedDvrProbeVariants({
    required TwitchM3u8Variant selected,
    required _PlaybackCandidate? web,
    required List<TwitchM3u8Variant> merged,
  }) {
    final ordered = <TwitchM3u8Variant>[];
    final seen = <String>{};

    void add(TwitchM3u8Variant variant) {
      if (variant.isAudioOnly) return;
      if (!seen.add(variant.url)) return;
      ordered.add(variant);
    }

    add(selected);
    for (final variant in _sortVariants(
      (web?.variants ?? const <TwitchM3u8Variant>[])
          .where(_isSourceLikeVariant)
          .toList(),
    )) {
      add(variant);
    }
    for (final variant in _sortVariants(web?.variants ?? const [])) {
      add(variant);
    }
    for (final variant in _sortVariants(merged)) {
      add(variant);
    }
    return ordered;
  }

  void _debugDvr(String message) {
    if (!_forceDvrDirectPlaybackEnabled) return;
    debugPrint('[TwitchDvrDirect] $message');
  }

  Future<Uri?> _resolveDvrPlaylistUri(TwitchM3u8Variant variant) async {
    final direct = _buildDvrPlaylistUri(variant.url);
    if (direct != null) return direct;

    try {
      _debugDvr('resolve media playlist ${variant.name}: ${variant.url}');
      final response = await _dio.getUri<String>(
        Uri.parse(variant.url),
        options: Options(
          responseType: ResponseType.plain,
          headers: defaultUpstreamHeaders,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final statusCode = response.statusCode ?? 0;
      final text = response.data ?? '';
      _debugDvr(
        'media playlist ${variant.name}: status=$statusCode real=${response.realUri}',
      );
      if (statusCode >= 400 || !text.contains('#EXTM3U')) return null;

      final fromRealUri = _buildDvrPlaylistUri(response.realUri.toString());
      if (fromRealUri != null) return fromRealUri;

      return await _buildDvrPlaylistUriFromMediaPlaylist(
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
      final fromFinalSegment = await _buildDvrPlaylistUriFromFinalSegment(
        segmentUri,
      );
      if (fromFinalSegment != null) return fromFinalSegment;

      final fromSegment = _buildDvrPlaylistUriFromSegment(segmentUri);
      if (fromSegment != null) return fromSegment;
    }
    return null;
  }

  Future<Uri?> _buildDvrPlaylistUriFromFinalSegment(Uri segmentUri) async {
    final headResult = await _resolveSegmentFinalUri(
      segmentUri,
      method: 'HEAD',
    );
    final fromHead = headResult == null || _isTwitchHlsSegmentProxy(headResult)
        ? null
        : _buildDvrPlaylistUriFromSegment(headResult);
    if (fromHead != null) return fromHead;

    final rangeResult = await _resolveSegmentFinalUri(
      segmentUri,
      method: 'GET',
      rangeProbe: true,
    );
    return rangeResult == null || _isTwitchHlsSegmentProxy(rangeResult)
        ? null
        : _buildDvrPlaylistUriFromSegment(rangeResult);
  }

  bool _isTwitchHlsSegmentProxy(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('.hls.ttvnw.net') &&
        uri.pathSegments.contains('segment');
  }

  Future<Uri?> _resolveSegmentFinalUri(
    Uri segmentUri, {
    required String method,
    bool rangeProbe = false,
  }) async {
    try {
      final headers = <String, String>{...defaultUpstreamHeaders};
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

  Future<String?> seekLiveDvrBridgeRatio(double ratio) async {
    final requestId = ++_sharedBridgeSeekRequestId;
    final bridge = _bridgeProxy ?? _sharedBridgeProxy;
    if (bridge == null || !bridge.isRunning) {
      debugPrint('[LiveDvrBridge] seek ignored: bridge not running');
      return null;
    }
    debugPrint('[LiveDvrBridge] runtime seek ratio=$ratio');
    bridge.seekToRatio(ratio);

    if (requestId != _sharedBridgeSeekRequestId) {
      debugPrint('[LiveDvrBridge] stale seek ignored request=$requestId');
      return null;
    }

    final playbackUrl = bridge.streamTsPlaybackUrl;
    _bridgeProxy = bridge;
    _proxyUrl = playbackUrl;
    _proxyMpvUrl = playbackUrl;
    _usingDvrPlaylist = true;
    _usingExternalVodPlayback = false;
    _liveDvrPlaylistOverride = null;
    debugPrint('[LiveDvrBridge] stream seek player=$playbackUrl');
    notifyListeners();
    return playbackUrl;
  }

  Future<void> _stopProxy({bool notify = true, bool closeShared = true}) async {
    final router = _proxy ?? _sharedProxy;
    final bridge = _bridgeProxy ?? _sharedBridgeProxy;
    _proxy = null;
    _bridgeProxy = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _proxyLiveStatus = null;

    if (closeShared && router != null) {
      if (identical(_sharedProxy, router)) _sharedProxy = null;
      await router.close();
    }
    if (closeShared && bridge != null) {
      if (identical(_sharedBridgeProxy, bridge)) _sharedBridgeProxy = null;
      await bridge.close();
    }

    if (notify) notifyListeners();
  }

  Future<String?> _loadPreferredQualityName(String login) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value =
          prefs.getString('$_qualityChannelPrefix$login') ??
          prefs.getString(_qualityKey) ??
          prefs.getString('$_legacyQualityChannelPrefix$login') ??
          prefs.getString(_legacyQualityKey);
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
      // Save both global and channel-scoped preference. Channel-scoped wins on
      // that channel; global is the user's app-wide default for new channels.
      await prefs.setString(_qualityKey, name);
      await prefs.setString(
        '$_qualityChannelPrefix${login.trim().toLowerCase()}',
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
          headers: defaultUpstreamHeaders,
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
        if (old == null || _sortScore(v) > _sortScore(old)) {
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
    return _sortVariants(merged);
  }

  List<TwitchM3u8Variant> _sortVariants(List<TwitchM3u8Variant> variants) {
    final list = variants.toList();
    list.sort((a, b) => _sortScore(b).compareTo(_sortScore(a)));
    return list;
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
      if (safe.isNotEmpty) return _sortVariants(safe).first;
    }

    final source = pool.where(_isSourceLikeVariant).firstOrNull;
    if (source != null) return source;
    return _sortVariants(pool).first;
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

  bool _isSourceLikeVariant(TwitchM3u8Variant variant) {
    final text = '${variant.name} ${variant.videoGroupId ?? ''}'.toLowerCase();
    return text.contains('source') || text.contains('chunked');
  }

  TwitchM3u8Variant? _findVariantBySavedPreference(
    List<TwitchM3u8Variant> variants,
    String? preference,
  ) {
    final target = preference?.trim();
    if (target == null || target.isEmpty) return null;

    final exactMatches = variants
        .where((v) => v.name == target || v.displayName == target)
        .toList();
    if (exactMatches.isNotEmpty) return _sortVariants(exactMatches).first;

    final normalizedTarget = _normalizeQualityPreference(target);
    if (normalizedTarget.isEmpty) return null;

    if (normalizedTarget == 'source' || normalizedTarget == 'chunked') {
      final source = variants.where(_isSourceLikeVariant).toList();
      if (source.isNotEmpty) return _sortVariants(source).first;
    }

    final keyMatches = variants.where((v) {
      return _normalizeQualityPreference(v.adAwareQualityKey) ==
              normalizedTarget ||
          _normalizeQualityPreference(v.name) == normalizedTarget ||
          _normalizeQualityPreference(v.displayName) == normalizedTarget ||
          _normalizeQualityPreference(v.videoGroupId ?? '') == normalizedTarget;
    }).toList();
    return keyMatches.isEmpty ? null : _sortVariants(keyMatches).first;
  }

  String _normalizeQualityPreference(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return '';
    if (text.contains('source')) return 'source';
    if (text.contains('chunked')) return 'chunked';
    if (text.contains('audio')) return 'audio_only';
    return text
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  TwitchM3u8Variant? _findMatchingMergedVariant(
    List<TwitchM3u8Variant> variants,
    TwitchM3u8Variant preferred,
  ) {
    final matches = variants
        .where((v) => v.adAwareQualityKey == preferred.adAwareQualityKey)
        .toList();
    return matches.isEmpty ? null : _sortVariants(matches).first;
  }

  void clear() {
    unawaited(_stopProxy(notify: false, closeShared: true));
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
    notifyListeners();
  }

  @override
  void dispose() {
    _dio.close(force: true);
    unawaited(_stopProxy(notify: false, closeShared: false));
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
      'proxySourceRevision': _sharedProxyRevision,
      'error': error?.toString(),
    };
  }
}

class _PlaybackCandidate {
  final String sourceTag;
  final Uri masterUri;
  final String masterPlaylistText;
  final TwitchPlaybackAccessToken token;
  final List<TwitchM3u8Variant> variants;

  const _PlaybackCandidate({
    required this.sourceTag,
    required this.masterUri,
    required this.masterPlaylistText,
    required this.token,
    required this.variants,
  });
}
