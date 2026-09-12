part of '../twitch_playlist_player_runtime.dart';

extension _TwitchPlaylistPlayerRuntimeQualityOps
    on TwitchPlaylistPlayerRuntime {
  Future<Uri?> _startProxyForVariant(
    TwitchM3u8Variant variant, {
    bool probeDvr = true,
  }) async {
    final overrideDvrUri = probeDvr ? _liveDvrPlaylistOverride : null;
    final dvrCandidate = overrideDvrUri == null
        ? probeDvr
              ? await _probeDvrVariant(variant)
              : variant
        : variant.copyWith(
            url: overrideDvrUri.toString(),
            sourceTag: variant.sourceTag.isEmpty
                ? 'dvr-override'
                : '${variant.sourceTag}+dvr-override',
          );
    final hasDvrArchive =
        dvrCandidate.sourceTag.contains('+dvr') ||
        dvrCandidate.sourceTag == 'dvr' ||
        dvrCandidate.sourceTag == 'dvr-override';

    debugPrint(
      '[DvrSequential] variant=${variant.name} '
      'source=${variant.sourceTag} archive=$hasDvrArchive '
      'override=${overrideDvrUri != null} live=${variant.url}',
    );

    final liveUpstreamUri = Uri.tryParse(variant.url);
    if (liveUpstreamUri == null) {
      throw StateError('Invalid variant URL: ${variant.url}');
    }

    if (variant.url.trim().isNotEmpty) {
      _lastLiveUpstreamPlaylistUrl = variant.url;
      unawaited(_refreshCanonicalLiveTimingBestEffort());
    }

    var dvrWarmed = false;
    Uri? warmedDvrUri;
    if (hasDvrArchive) {
      final dvrUri = Uri.tryParse(dvrCandidate.url);
      if (dvrUri != null) {
        dvrWarmed = await warmLiveDvrBridge(dvrPlaylistUri: dvrUri);
        if (dvrWarmed) warmedDvrUri = dvrUri;
      }
    }

    // LIVE and archive DVR are deliberately separate transports. The stable
    // router always follows the selected LIVE media playlist. The DVR proxy is
    // only warmed here and is opened directly when the timeline seeks backward.
    var router = TwitchPlaylistPlayerRuntime._sharedProxy;
    if (router == null || !router.isRunning) {
      router = _createStableRouter();
      TwitchPlaylistPlayerRuntime._sharedProxy = router;
      _proxy = router;
      await router.start(upstreamPlaylistUrl: variant.url);
    } else {
      _proxy = router;
      await router.switchUpstream(variant.url);
    }

    await router.waitUntilPrewarmed();
    unawaited(_refreshCanonicalLiveTimingBestEffort());

    _currentVariant = variant;
    _upstreamPlaylistUri = liveUpstreamUri;
    _usingDvrPlaylist = false;
    _usingExternalVodPlayback = false;
    _usingLiveDvrReplay = false;
    this._clearLiveBufferReplay();
    _proxyUrl = _routerStreamTsPlaybackUrl(router);
    _proxyMpvUrl = _proxyUrl;
    _proxyLiveStatus = null;
    if (dvrWarmed) {
      _adAwareStatus = '${_adAwareStatus.trim()} dvr=warm'.trim();
      this._beginDvrHealthMonitoring(
        archiveUri: warmedDvrUri,
        initiallyHealthy: true,
      );
    } else if (_dvrProbeEnabled && !variant.isAudioOnly) {
      this._beginDvrHealthMonitoring(initiallyHealthy: false);
    } else {
      this._stopDvrHealthMonitoring();
    }
    debugPrint(
      '[DvrSequential] live player=$_proxyUrl '
      'dvrWarm=$dvrWarmed upstream=${router.upstreamPlaylistUrl}',
    );
    return Uri.tryParse(_proxyUrl!) ?? liveUpstreamUri;
  }

  String _routerStreamTsPlaybackUrl(TwitchStableHlsProxyRouter router) {
    return router.streamTsUrl;
  }

  TwitchStableHlsProxyRouter _createStableRouter() {
    return TwitchStableHlsProxyRouter(
      upstreamHeaders: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
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
    final dvrUri = await this._resolveDvrPlaylistUri(variant);
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
          headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
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

  void _debugDvr(String message) {
    if (!kDebugMode) return;
    debugPrint('[TwitchDvrDirect] $message');
  }

  List<TwitchM3u8Variant> _sortVariants(List<TwitchM3u8Variant> variants) {
    final list = variants.toList();
    list.sort((a, b) => this._sortScore(b).compareTo(this._sortScore(a)));
    return list;
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
    if (exactMatches.isNotEmpty) return this._sortVariants(exactMatches).first;

    final normalizedTarget = this._normalizeQualityPreference(target);
    if (normalizedTarget.isEmpty) return null;

    if (normalizedTarget == 'source' || normalizedTarget == 'chunked') {
      final source = variants.where(this._isSourceLikeVariant).toList();
      if (source.isNotEmpty) return this._sortVariants(source).first;
    }

    final keyMatches = variants.where((v) {
      return this._normalizeQualityPreference(v.adAwareQualityKey) ==
              normalizedTarget ||
          this._normalizeQualityPreference(v.name) == normalizedTarget ||
          this._normalizeQualityPreference(v.displayName) == normalizedTarget ||
          this._normalizeQualityPreference(v.videoGroupId ?? '') ==
              normalizedTarget;
    }).toList();
    return keyMatches.isEmpty ? null : this._sortVariants(keyMatches).first;
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
    return matches.isEmpty ? null : this._sortVariants(matches).first;
  }
}
