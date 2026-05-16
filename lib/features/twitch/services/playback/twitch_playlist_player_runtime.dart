// PATCH VERSION: twitch_playlist_player_runtime_same_proxy_route_v41

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../api/playback/twitch_playback_api_service.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import '../../models/playback/twitch_hls_proxy_models.dart';
import '../../models/playback/twitch_playback.dart';
import 'twitch_hls_low_latency_proxy.dart';

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
  TwitchDartHlsLowLatencyProxy? _proxy;
  bool _loading = false;
  bool _switchingQuality = false;
  Object? _error;
  String _masterPlaylistText = '';
  List<TwitchM3u8Variant> _variants = const <TwitchM3u8Variant>[];
  TwitchM3u8Variant? _currentVariant;
  String _adAwareStatus = '';

  String get channelLogin => _channelLogin;
  Uri? get masterPlaylistUri => _masterPlaylistUri;
  Uri? get playlistUri => _playlistUri;
  Uri? get upstreamPlaylistUri => _upstreamPlaylistUri;
  String? get proxyUrl => _proxyUrl;
  String? get proxyMpvUrl => _proxyMpvUrl ?? _proxyUrl;
  TwitchHlsLiveStatus? get proxyLiveStatus => _proxyLiveStatus;
  bool get hasProxyUrl => _proxyUrl != null && _proxyUrl!.trim().isNotEmpty;
  TwitchDartHlsLowLatencyProxy? get proxy => _proxy;
  bool get loading => _loading;
  bool get switchingQuality => _switchingQuality;
  bool get busy => _loading || _switchingQuality;
  Object? get error => _error;
  bool get hasPlaylist => _playlistUri != null;
  String get masterPlaylistText => _masterPlaylistText;
  List<TwitchM3u8Variant> get variants => List<TwitchM3u8Variant>.unmodifiable(_variants);
  TwitchM3u8Variant? get currentVariant => _currentVariant;
  String get adAwareStatus => _adAwareStatus;

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
    await _stopProxy(notify: false);
    _playlistUri = null;
    _upstreamPlaylistUri = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _masterPlaylistText = '';
    _variants = const <TwitchM3u8Variant>[];
    _currentVariant = null;
    _adAwareStatus = 'probing playback sources...';
    notifyListeners();

    try {
      final candidates = await Future.wait<_PlaybackCandidate?>(
        <Future<_PlaybackCandidate?>>[
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
        ],
      );

      final webCandidate = candidates.firstWhere(
        (candidate) => candidate?.sourceTag == 'web-site',
        orElse: () => null,
      );
      final androidCandidate = candidates.firstWhere(
        (candidate) => candidate?.sourceTag == 'android-autoplay',
        orElse: () => null,
      );
      final iosCandidate = candidates.firstWhere(
        (candidate) => candidate?.sourceTag == 'ios-site',
        orElse: () => null,
      );

      final baseCandidate = webCandidate ?? androidCandidate ?? iosCandidate;
      if (baseCandidate == null) {
        throw StateError('Twitch master playlist 載入失敗：所有 playback source 都失敗。');
      }

      final mergedVariants = _mergeAdAwareVariants(
        baseVariants: baseCandidate.variants,
        cleanCandidates: <_PlaybackCandidate>[
          if (androidCandidate != null) androidCandidate,
          if (iosCandidate != null) iosCandidate,
        ],
      );

      _masterPlaylistUri = baseCandidate.masterUri;
      _masterPlaylistText = baseCandidate.masterPlaylistText;
      _variants = mergedVariants;
      _adAwareStatus = _buildAdAwareStatus(
        webCandidate: webCandidate,
        androidCandidate: androidCandidate,
        iosCandidate: iosCandidate,
        mergedVariants: mergedVariants,
      );

      final selected = preferredVariant == null
          ? _findVariantByName(mergedVariants, preferredVariantName) ??
              selectDefaultVariant(mergedVariants)
          : _findMatchingMergedVariant(mergedVariants, preferredVariant) ?? preferredVariant;

      if (selected == null) {
        // Fallback：至少回 master playlist，避免播放器完全不能播。
        _playlistUri = baseCandidate.masterUri;
        return baseCandidate.masterUri;
      }

      _currentVariant = selected;
      _upstreamPlaylistUri = Uri.tryParse(selected.url) ?? baseCandidate.masterUri;
      _playlistUri = await _startProxyForVariant(selected);

      return _playlistUri;
    } catch (e) {
      _error = e;
      _playlistUri = null;
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
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
          headers: const <String, String>{
            'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
            'Origin': 'https://www.twitch.tv',
            'Referer': 'https://www.twitch.tv/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;
      final text = response.data ?? '';
      if (status >= 400 || text.trim().isEmpty) {
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
      for (final candidate in cleanCandidates) {
        if (candidate.variants.isNotEmpty) return candidate.variants;
      }
      return const <TwitchM3u8Variant>[];
    }

    final cleanByQuality = <String, TwitchM3u8Variant>{};
    for (final candidate in cleanCandidates) {
      for (final variant in candidate.variants) {
        final key = variant.adAwareQualityKey;
        final existing = cleanByQuality[key];
        if (existing == null || _preferCleanCandidate(variant, existing) < 0) {
          cleanByQuality[key] = variant;
        }
      }
    }

    final merged = <TwitchM3u8Variant>[];
    final usedCleanUrls = <String>{};

    for (final base in baseVariants) {
      final clean = cleanByQuality[base.adAwareQualityKey];
      if (clean != null) {
        usedCleanUrls.add(clean.url);
        merged.add(
          base.copyWith(
            url: clean.url,
            hasAds: false,
            sourceTag: clean.sourceTag,
          ),
        );
      } else {
        merged.add(
          base.copyWith(
            hasAds: true,
            sourceTag: base.sourceTag.isEmpty ? 'web-site' : base.sourceTag,
          ),
        );
      }
    }

    // If the Android/iOS context exposes extra variants not present in the web
    // master playlist, keep them as fallback options.
    for (final clean in cleanByQuality.values) {
      if (usedCleanUrls.contains(clean.url)) continue;
      if (merged.any((variant) => variant.url == clean.url)) continue;
      merged.add(clean.copyWith(hasAds: false));
    }

    return _sortVariants(merged);
  }

  int _preferCleanCandidate(TwitchM3u8Variant a, TwitchM3u8Variant b) {
    // Prefer Android autoplay first because this mirrors the CRX no-ads path.
    final aAndroid = a.sourceTag == 'android-autoplay';
    final bAndroid = b.sourceTag == 'android-autoplay';
    if (aAndroid != bAndroid) return aAndroid ? -1 : 1;

    final heightCompare = b.height.compareTo(a.height);
    if (heightCompare != 0) return heightCompare;

    final fpsCompare = b.fpsRounded.compareTo(a.fpsRounded);
    if (fpsCompare != 0) return fpsCompare;

    return 0;
  }

  List<TwitchM3u8Variant> _sortVariants(List<TwitchM3u8Variant> input) {
    final output = input.toList();
    output.sort((a, b) {
      if (a.hasAds != b.hasAds) return a.hasAds ? 1 : -1;

      final aVideo = !a.isAudioOnly;
      final bVideo = !b.isAudioOnly;
      if (aVideo != bVideo) return aVideo ? -1 : 1;

      final heightCompare = b.height.compareTo(a.height);
      if (heightCompare != 0) return heightCompare;

      final fpsCompare = b.fpsRounded.compareTo(a.fpsRounded);
      if (fpsCompare != 0) return fpsCompare;

      final bandwidthCompare = (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
      if (bandwidthCompare != 0) return bandwidthCompare;

      return a.name.compareTo(b.name);
    });
    return output;
  }

  String _buildAdAwareStatus({
    required _PlaybackCandidate? webCandidate,
    required _PlaybackCandidate? androidCandidate,
    required _PlaybackCandidate? iosCandidate,
    required List<TwitchM3u8Variant> mergedVariants,
  }) {
    final cleanCount = mergedVariants.where((variant) => !variant.hasAds).length;
    final adCount = mergedVariants.length - cleanCount;
    return 'web=${webCandidate?.variants.length ?? 0}, '
        'android=${androidCandidate?.variants.length ?? 0}, '
        'ios=${iosCandidate?.variants.length ?? 0}, '
        'clean=$cleanCount, fallback=$adCount';
  }

  /// 切換畫質時重建 Dart HLS proxy，並回傳本機 proxy URL。
  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) async {
    _switchingQuality = true;
    _error = null;
    notifyListeners();

    try {
      _currentVariant = variant;
      _upstreamPlaylistUri = Uri.tryParse(variant.url);
      _playlistUri = await _startProxyForVariant(variant);
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
    await _stopProxy(notify: false);

    final upstreamUri = Uri.tryParse(variant.url);
    if (upstreamUri == null) {
      throw StateError('Invalid variant URL: ${variant.url}');
    }

    final proxy = TwitchDartHlsLowLatencyProxy(
      upstreamPlaylistUrl: variant.url,
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

    _proxy = proxy;
    await proxy.start();
    await proxy.waitUntilPrewarmed();

    // v41: 內部 media_kit 與外部 mpv 使用完全相同的 Dart raw proxy route。
    // /stream.ts 與 / 都會進同一個 _handleStream engine，但統一使用 /stream.ts
    // 可以避免比較時一邊是 root、一邊是 stream.ts 造成判讀混亂。
    // 這不是 m3u8，低延遲策略仍由 Dart proxy 自己決定 live edge / future segment。
    _proxyUrl = proxy.streamTsUrl;
    _proxyMpvUrl = proxy.streamTsUrl;
    _proxyLiveStatus = null;
    return Uri.tryParse(_proxyUrl!) ?? upstreamUri;
  }

  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({
    bool notify = true,
  }) async {
    final proxy = _proxy;
    if (proxy == null || !proxy.isRunning) {
      if (_proxyLiveStatus != null) {
        _proxyLiveStatus = null;
        if (notify) notifyListeners();
      }
      return null;
    }

    final status = await proxy.requestLiveStatus();
    if (status != null) {
      _proxyLiveStatus = status;
      if (notify) notifyListeners();
    }
    return status;
  }

  Future<void> _stopProxy({bool notify = true}) async {
    final proxy = _proxy;
    _proxy = null;
    _proxyUrl = null;
    _proxyMpvUrl = null;
    _proxyLiveStatus = null;

    if (proxy != null) {
      await proxy.close();
    }

    if (notify) {
      notifyListeners();
    }
  }

  TwitchM3u8Variant? selectDefaultVariant(List<TwitchM3u8Variant> variants) {
    if (variants.isEmpty) return null;

    final videoVariants = variants.where((variant) => !variant.isAudioOnly).toList();
    final cleanVideoVariants = videoVariants.where((variant) => !variant.hasAds).toList();
    final cleanVariants = variants.where((variant) => !variant.hasAds).toList();

    final preferredPool = cleanVideoVariants.isNotEmpty
        ? cleanVideoVariants
        : videoVariants.isNotEmpty
            ? videoVariants
            : cleanVariants.isNotEmpty
                ? cleanVariants
                : variants.toList();

    TwitchM3u8Variant? source;
    for (final variant in preferredPool) {
      final text = '${variant.name} ${variant.videoGroupId ?? ''}'.toLowerCase();
      if (text.contains('source') || text.contains('chunked')) {
        source = variant;
        break;
      }
    }

    if (source != null) return source;

    final sorted = _sortVariants(preferredPool);
    return sorted.first;
  }

  TwitchM3u8Variant? _findVariantByName(
    List<TwitchM3u8Variant> variants,
    String? name,
  ) {
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) return null;

    final exact = variants.where(
      (variant) => variant.name == clean || variant.displayName == clean,
    );
    if (exact.isEmpty) return null;

    final sorted = _sortVariants(exact.toList());
    return sorted.first;
  }

  TwitchM3u8Variant? _findMatchingMergedVariant(
    List<TwitchM3u8Variant> variants,
    TwitchM3u8Variant preferred,
  ) {
    final matches = variants
        .where((variant) => variant.adAwareQualityKey == preferred.adAwareQualityKey)
        .toList();
    if (matches.isEmpty) return null;
    return _sortVariants(matches).first;
  }

  void clear() {
    unawaited(_stopProxy(notify: false));
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
    // Best effort: dispose cannot await. Runtime callers should call clear/stop by recreating page.
    unawaited(_stopProxy(notify: false));
    super.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'channelLogin': channelLogin,
      'loading': loading,
      'switchingQuality': switchingQuality,
      'hasPlaylist': hasPlaylist,
      'adAwareStatus': adAwareStatus,
      'masterPlaylistUriPreview': masterPlaylistUri?.toString().replaceFirst(
            RegExp(r'token=[^&]+'),
            'token=<hidden>',
          ),
      'playlistUriPreview': playlistUri?.toString().replaceFirst(
            RegExp(r'token=[^&]+'),
            'token=<hidden>',
          ),
      'variantCount': variants.length,
      'currentVariant': currentVariant?.toString(),
      'upstreamPlaylistUri': upstreamPlaylistUri?.toString(),
      'proxyUrl': proxyUrl,
      'proxyMpvUrl': proxyMpvUrl,
      'proxyStreamUrl': proxy?.streamUrl,
      'proxyLiveStatus': proxyLiveStatus?.toJson(),
      'proxyRunning': proxy?.isRunning ?? false,
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
