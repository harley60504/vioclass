import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/playback/twitch_playback_api_service.dart';
import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/playback/twitch_playback.dart';
import 'twitch_hls_low_latency_proxy.dart' show TwitchHlsStartupMode;
import 'twitch_stable_hls_proxy_router.dart';

class TwitchPlaylistPlayerRuntime extends ChangeNotifier {
  final TwitchPlaybackApiService playbackApi;
  final Dio _dio;

  static const Map<String, String> defaultUpstreamHeaders = <String, String>{
    'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
    'Origin': 'https://www.twitch.tv',
    'Referer': 'https://www.twitch.tv/',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  static const String _qualityKey = 'twitch_watch_v2_preferred_quality';
  static const String _qualityChannelPrefix =
      'twitch_watch_v2_preferred_quality_';
  static const String _legacyQualityKey = 'twitch_fvp_proxy_preferred_quality';
  static const String _legacyQualityChannelPrefix =
      'twitch_fvp_proxy_preferred_quality_';
  static const int _mobileStartupTargetHeight = 720;
  static const int _mobileStartupMaxFps = 60;

  static TwitchStableHlsProxyRouter? _sharedProxy;
  static int _sharedProxyRevision = 0;

  TwitchPlaylistPlayerRuntime({
    required this.playbackApi,
    Dio? dio,
  }) : _dio = dio ??
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
  bool _loading = false;
  bool _switchingQuality = false;
  Object? _error;
  String _masterPlaylistText = '';
  List<TwitchM3u8Variant> _variants = const <TwitchM3u8Variant>[];
  TwitchM3u8Variant? _currentVariant;
  String _adAwareStatus = '';
  String? _lastPreferredQualityName;

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

  /// Stable playback URL for media_kit.
  ///
  /// The outer HLS router keeps this local URL stable while quality switching
  /// swaps only the router's inner upstream playlist. The player should open
  /// this URL once and stay attached; quality changes should not recreate
  /// Player / VideoController or call Player.open with a different local URL.
  String? get stableProxyPlaybackUrl {
    final router = _proxy ?? _sharedProxy;
    if (router == null || !router.isRunning) return null;
    return router.streamTsUrl;
  }

  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
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
          ? _findVariantByName(merged, wantedQuality) ??
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

      _currentVariant = selected;
      _upstreamPlaylistUri = Uri.tryParse(selected.url) ?? base.masterUri;
      _playlistUri = await _startProxyForVariant(selected);
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

  Future<Uri?> _startProxyForVariant(TwitchM3u8Variant variant) async {
    final upstreamUri = Uri.tryParse(variant.url);
    if (upstreamUri == null) {
      throw StateError('Invalid variant URL: ${variant.url}');
    }

    var router = _sharedProxy;
    final previousUpstream = router?.upstreamPlaylistUrl;
    if (router == null || !router.isRunning) {
      router = TwitchStableHlsProxyRouter(
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
      _sharedProxy = router;
      _proxy = router;
      await router.start(upstreamPlaylistUrl: variant.url);
      _sharedProxyRevision++;
    } else {
      _proxy = router;
      await router.switchUpstream(variant.url);
      if (previousUpstream != variant.url) {
        _sharedProxyRevision++;
      }
    }

    await router.waitUntilPrewarmed();

    // Keep the player-facing URL stable. Quality/source switching happens
    // inside TwitchStableHlsProxyRouter.switchUpstream(). This avoids forcing
    // media_kit to reopen a new local URL and keeps the VideoController surface
    // attached.
    _proxyUrl = router.streamTsUrl;
    _proxyMpvUrl = _proxyUrl;
    _proxyLiveStatus = null;
    return Uri.tryParse(_proxyUrl!) ?? upstreamUri;
  }

  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({bool notify = true}) async {
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

  Future<void> _stopProxy({bool notify = true, bool closeShared = true}) async {
    final router = _proxy ?? _sharedProxy;
    _proxy = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _proxyLiveStatus = null;

    if (closeShared && router != null) {
      if (identical(_sharedProxy, router)) _sharedProxy = null;
      await router.close();
    }

    if (notify) notifyListeners();
  }

  Future<String?> _loadPreferredQualityName(String login) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('$_qualityChannelPrefix$login') ??
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
          base.copyWith(url: clean.url, hasAds: false, sourceTag: clean.sourceTag),
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
            v.height <= _mobileStartupTargetHeight &&
            (fps == 0 || fps <= _mobileStartupMaxFps);
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

  TwitchM3u8Variant? _findVariantByName(
    List<TwitchM3u8Variant> variants,
    String? name,
  ) {
    final target = name?.trim();
    if (target == null || target.isEmpty) return null;
    final matches = variants
        .where((v) => v.name == target || v.displayName == target)
        .toList();
    return matches.isEmpty ? null : _sortVariants(matches).first;
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
