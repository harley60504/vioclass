// PATCH VERSION: twitch_player_runtime_ad_aware_selector_v34

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/playback/twitch_playback_service.dart';
import '../../models/playback/twitch_m3u8_variant.dart';
import './twitch_hls_low_latency_proxy.dart';

enum TwitchPlayerProxyOutput {
  /// Proxy 的低延遲連續 stream endpoint：
  /// http://127.0.0.1:{port}/
  stream,

  /// Proxy 重寫後的 HLS playlist endpoint：
  /// http://127.0.0.1:{port}/playlist.m3u8
  playlist,

  /// Proxy 的 TS stream endpoint：
  /// http://127.0.0.1:{port}/stream.ts
  streamTs,
}

class TwitchPlayerRuntime extends ChangeNotifier {
  final TwitchPlaybackService playbackService;
  final void Function(String message)? externalLog;

  TwitchPlayerRuntime({
    required this.playbackService,
    this.externalLog,
  });

  static const Map<String, String> defaultUpstreamHeaders = <String, String>{
    'Accept': 'application/x-mpegURL, application/vnd.apple.mpegurl, */*',
    'Origin': 'https://www.twitch.tv',
    'Referer': 'https://www.twitch.tv/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  TwitchPlaybackResult? _playbackResult;
  TwitchM3u8Variant? _currentVariant;
  TwitchDartHlsLowLatencyProxy? _proxy;

  String _channelLogin = '';
  String? _proxyUrl;
  bool _loading = false;
  bool _startingProxy = false;
  Object? _error;
  TwitchPlayerProxyOutput _proxyOutput = TwitchPlayerProxyOutput.stream;

  final List<String> _logs = <String>[];

  String get channelLogin => _channelLogin;
  TwitchPlaybackResult? get playbackResult => _playbackResult;
  List<TwitchM3u8Variant> get variants => _playbackResult?.variants ?? const <TwitchM3u8Variant>[];
  TwitchM3u8Variant? get currentVariant => _currentVariant;
  TwitchDartHlsLowLatencyProxy? get proxy => _proxy;
  String? get proxyUrl => _proxyUrl;
  bool get loading => _loading;
  bool get startingProxy => _startingProxy;
  bool get busy => loading || startingProxy;
  bool get hasProxyUrl => _proxyUrl != null && _proxyUrl!.isNotEmpty;
  bool get isProxyRunning => _proxy?.isRunning ?? false;
  Object? get error => _error;
  TwitchPlayerProxyOutput get proxyOutput => _proxyOutput;
  List<String> get logs => List<String>.unmodifiable(_logs);

  Future<String?> loadChannel({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    TwitchPlayerProxyOutput output = TwitchPlayerProxyOutput.stream,
  }) async {
    final login = channelLogin.trim().toLowerCase();

    if (login.isEmpty) {
      throw ArgumentError.value(channelLogin, 'channelLogin', 'channelLogin cannot be empty');
    }

    _channelLogin = login;
    _loading = true;
    _error = null;
    _proxyOutput = output;
    _proxyUrl = null;
    notifyListeners();

    try {
      await stopProxy();

      _addLog('Loading playback playlist for $login...');
      final result = await playbackService.getLivePlaylist(channelLogin: login);
      _playbackResult = result;

      _addLog('Loaded ${result.variants.length} variants.');
      final selected = preferredVariant ??
          _findVariantByName(result.variants, preferredVariantName) ??
          selectDefaultVariant(result.variants);

      if (selected == null) {
        throw StateError('No playable Twitch m3u8 variant found.');
      }

      await startProxyForVariant(
        selected,
        output: output,
      );

      return _proxyUrl;
    } catch (e) {
      _error = e;
      _addLog('ERROR: $e');
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> startProxyForVariant(
    TwitchM3u8Variant variant, {
    TwitchPlayerProxyOutput? output,
  }) async {
    _startingProxy = true;
    _error = null;
    _proxyOutput = output ?? _proxyOutput;
    _proxyUrl = null;
    notifyListeners();

    try {
      await stopProxy(notify: false);

      _currentVariant = variant;
      _addLog('Starting HLS proxy: ${variant.displayName}');
      _addLog('Upstream: ${variant.url}');

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
        onLog: _addLog,
      );

      _proxy = proxy;
      await proxy.start();
      await proxy.waitUntilPrewarmed();

      _proxyUrl = _readProxyUrl(proxy, _proxyOutput);
      _addLog('Proxy started: $_proxyUrl');

      return _proxyUrl;
    } catch (e) {
      _error = e;
      _addLog('ERROR: $e');
      await stopProxy(notify: false);
      return null;
    } finally {
      _startingProxy = false;
      notifyListeners();
    }
  }

  Future<void> stopProxy({bool notify = true}) async {
    final proxy = _proxy;
    _proxy = null;
    _proxyUrl = null;

    if (proxy != null) {
      _addLog('Stopping HLS proxy...');
      await proxy.close();
      _addLog('HLS proxy stopped.');
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> disposeRuntime() async {
    await stopProxy(notify: false);
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

    final sorted = preferredPool.toList();
    sorted.sort((a, b) {
      if (a.hasAds != b.hasAds) return a.hasAds ? 1 : -1;

      final heightCompare = b.height.compareTo(a.height);
      if (heightCompare != 0) return heightCompare;

      final fpsCompare = b.fpsRounded.compareTo(a.fpsRounded);
      if (fpsCompare != 0) return fpsCompare;

      final bandwidthCompare = (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
      if (bandwidthCompare != 0) return bandwidthCompare;

      return a.name.compareTo(b.name);
    });

    return sorted.first;
  }

  TwitchM3u8Variant? _findVariantByName(
    List<TwitchM3u8Variant> variants,
    String? name,
  ) {
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) return null;

    for (final variant in variants) {
      if (variant.name == clean || variant.displayName == clean) {
        return variant;
      }
    }

    return null;
  }

  String _readProxyUrl(
    TwitchDartHlsLowLatencyProxy proxy,
    TwitchPlayerProxyOutput output,
  ) {
    switch (output) {
      case TwitchPlayerProxyOutput.stream:
        return proxy.streamUrl;
      case TwitchPlayerProxyOutput.playlist:
        return proxy.playlistUrl;
      case TwitchPlayerProxyOutput.streamTs:
        return proxy.streamTsUrl;
    }
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final line = '[$time] $message';

    _logs.add(line);
    if (_logs.length > 300) {
      _logs.removeRange(0, _logs.length - 300);
    }

    externalLog?.call(line);

    if (hasListeners) {
      scheduleMicrotask(notifyListeners);
    }
  }
}
