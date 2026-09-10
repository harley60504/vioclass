import 'dart:async';
import 'dart:io';

import '../../models/playback/twitch_hls_proxy_models.dart';
import 'twitch_hls_low_latency_proxy.dart';

/// Stable local URL wrapper for Twitch HLS playback.
///
/// The outer URL and port stay stable. Quality/channel switching swaps the
/// inner low-latency proxy. For `/stream.ts`, this router keeps the client HTTP
/// response open and re-attaches it to the new inner stream after the inner
/// upstream changes, so media_kit does not need Player.open() on every switch.
class TwitchStableHlsProxyRouter {
  final Map<String, String> upstreamHeaders;
  final int edgeSegmentCount;
  final int prefetchSegmentCount;
  final bool outputFutureSegments;
  final int futureOutputSegmentCount;
  final bool dropBehindLiveEdge;
  final int startupEdgeSegmentCount;
  final bool startupRequirePrefetchedFirstSegment;
  final bool startupSkipCurrentLatestSegment;
  final TwitchHlsStartupMode startupMode;
  final bool verboseLogging;

  TwitchStableHlsProxyRouter({
    required this.upstreamHeaders,
    this.edgeSegmentCount = 1,
    this.prefetchSegmentCount = 1,
    this.outputFutureSegments = true,
    this.futureOutputSegmentCount = 1,
    this.dropBehindLiveEdge = true,
    this.startupEdgeSegmentCount = 1,
    this.startupRequirePrefetchedFirstSegment = false,
    this.startupSkipCurrentLatestSegment = false,
    this.startupMode = TwitchHlsStartupMode.streamlinkLiveEdge,
    this.verboseLogging = false,
  });

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 4)
    ..idleTimeout = const Duration(seconds: 8)
    ..autoUncompress = false;

  HttpServer? _server;
  TwitchDartHlsLowLatencyProxy? _inner;
  String? _upstreamPlaylistUrl;
  Uri? _directStreamUri;
  bool _starting = false;
  bool _switching = false;
  int _switchGeneration = 0;
  int _switchRequestGeneration = 0;
  int _directStreamGeneration = 0;
  int _streamClientGeneration = 0;
  int _streamUpstreamAttachCount = 0;
  int _streamUpstreamRetryCount = 0;
  int _streamBytesForwarded = 0;
  int _streamPatHandoffCount = 0;
  int _streamPacketHandoffCount = 0;
  int _streamBoundaryTimeoutCount = 0;
  String? _lastStreamTarget;
  String? _lastStreamError;
  String? _lastSwitchError;
  StreamIterator<List<int>>? _activeUpstreamIterator;
  Completer<void>? _streamHandoffCompleter;
  DateTime? _streamHandoffRequestedAt;

  int? get port => _server?.port;

  bool get isRunning => _server != null;

  bool get hasInnerProxy => _inner != null && (_inner?.isRunning ?? false);

  String? get upstreamPlaylistUrl => _upstreamPlaylistUrl;

  String get playlistUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/playlist.m3u8';
  }

  String get streamUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/';
  }

  String get streamTsUrl {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    return 'http://127.0.0.1:$p/stream.ts';
  }

  String liveReplayUrl({required Duration fromLive}) {
    final p = port;
    if (p == null) throw StateError('Stable HLS proxy router has not started.');
    final seconds = fromLive.inSeconds.clamp(1, 20).toInt();
    return 'http://127.0.0.1:$p/live-replay.ts?seconds=$seconds';
  }

  Future<void> startDirectStream({required String streamUrl}) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_server == null) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _server = server;
        unawaited(_serve(server));
      }
      await switchDirectStream(streamUrl);
    } finally {
      _starting = false;
    }
  }

  Future<void> start({required String upstreamPlaylistUrl}) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_server == null) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _server = server;
        unawaited(_serve(server));
      }
      await switchUpstream(upstreamPlaylistUrl);
    } finally {
      _starting = false;
    }
  }

  Future<void> switchUpstream(
    String upstreamPlaylistUrl, {
    bool forceReconnect = false,
  }) async {
    final safeUrl = upstreamPlaylistUrl.trim();
    if (safeUrl.isEmpty) {
      throw ArgumentError.value(
        upstreamPlaylistUrl,
        'upstreamPlaylistUrl',
        'cannot be empty',
      );
    }

    final requestGeneration = ++_switchRequestGeneration;

    if (_inner != null &&
        _inner!.isRunning &&
        _directStreamUri == null &&
        _upstreamPlaylistUrl == safeUrl) {
      if (forceReconnect) {
        _switching = true;
        try {
          await _inner!.reconnectAtSegmentBoundary();
          if (requestGeneration != _switchRequestGeneration) return;
          _lastSwitchError = null;
          _switchGeneration++;
        } catch (error) {
          if (requestGeneration != _switchRequestGeneration) return;
          _lastSwitchError = error.toString();
          rethrow;
        } finally {
          if (requestGeneration == _switchRequestGeneration) {
            _switching = false;
            _switchGeneration++;
          }
        }
      } else {
        // This can intentionally cancel an older in-flight switch and keep the
        // currently active source.
        _switching = false;
        _lastSwitchError = null;
        _switchGeneration++;
      }
      return;
    }

    _switching = true;
    _switchGeneration++;

    final previous = _inner;
    final next = TwitchDartHlsLowLatencyProxy(
      upstreamPlaylistUrl: safeUrl,
      upstreamHeaders: upstreamHeaders,
      edgeSegmentCount: edgeSegmentCount,
      prefetchSegmentCount: prefetchSegmentCount,
      outputFutureSegments: outputFutureSegments,
      futureOutputSegmentCount: futureOutputSegmentCount,
      dropBehindLiveEdge: dropBehindLiveEdge,
      startupEdgeSegmentCount: startupEdgeSegmentCount,
      startupRequirePrefetchedFirstSegment:
          startupRequirePrefetchedFirstSegment,
      startupSkipCurrentLatestSegment: startupSkipCurrentLatestSegment,
      startupMode: startupMode,
      verboseLogging: verboseLogging,
    );
    var committed = false;

    try {
      // Make-before-break: keep the current stream alive while the replacement
      // proxy starts and reaches the configured live edge.
      await next.start();
      await next.waitUntilPrewarmed();

      // A newer quality/channel/direct-stream request supersedes this warm-up.
      // Never allow an older asynchronous switch to overwrite the latest one.
      if (requestGeneration != _switchRequestGeneration || _server == null) {
        await _closeInnerQuietly(next);
        return;
      }

      _inner = next;
      _directStreamUri = null;
      _upstreamPlaylistUrl = safeUrl;
      _lastSwitchError = null;
      _switchGeneration++;
      committed = true;

      // For HLS -> HLS quality/source changes, let the active stream pump end
      // the old transport stream at a decoder-safe MPEG-TS boundary. Prefer a
      // PAT boundary (normally seen near a segment/program boundary), then fall
      // back to a complete 188-byte TS packet after a short grace period.
      if (previous != null) {
        await _handoffActiveUpstreamAtSafeBoundary();
      } else {
        // Direct-stream -> HLS has no retired inner proxy to drain.
        await _interruptActiveUpstream();
      }
      await _closeInnerQuietly(previous);
    } catch (error) {
      if (!committed) {
        await _closeInnerQuietly(next);
      }
      if (requestGeneration != _switchRequestGeneration) return;
      _lastSwitchError = error.toString();
      rethrow;
    } finally {
      if (requestGeneration == _switchRequestGeneration) {
        _switching = false;
        _switchGeneration++;
      }
    }
  }

  Future<void> switchDirectStream(String streamUrl) async {
    final safeUrl = streamUrl.trim();
    final directUri = Uri.tryParse(safeUrl);
    if (directUri == null || safeUrl.isEmpty) {
      throw ArgumentError.value(streamUrl, 'streamUrl', 'cannot be empty');
    }

    if (_directStreamUri == directUri && _server != null) {
      return;
    }

    // Invalidate any HLS proxy that is still prewarming.
    final requestGeneration = ++_switchRequestGeneration;
    _switching = true;
    final previous = _inner;
    _inner = null;
    _directStreamUri = directUri;
    _upstreamPlaylistUrl = null;
    _directStreamGeneration++;
    _switchGeneration++;
    _lastSwitchError = null;

    try {
      await _interruptActiveUpstream();
      await _closeInnerQuietly(previous);
    } catch (error) {
      if (requestGeneration == _switchRequestGeneration) {
        _lastSwitchError = error.toString();
      }
      rethrow;
    } finally {
      if (requestGeneration == _switchRequestGeneration) {
        _switching = false;
        _switchGeneration++;
      }
    }
  }

  Future<void> switchLiveReplayStream({required Duration fromLive}) async {
    final inner = _inner;
    if (inner == null || !inner.isRunning) {
      throw StateError('Inner proxy not ready');
    }
    final replayUri = Uri.parse(liveReplayUrl(fromLive: fromLive));
    final requestGeneration = ++_switchRequestGeneration;
    _switching = true;
    _directStreamUri = replayUri;
    _directStreamGeneration++;
    _switchGeneration++;
    _lastSwitchError = null;
    try {
      await _interruptActiveUpstream();
    } catch (error) {
      if (requestGeneration == _switchRequestGeneration) {
        _lastSwitchError = error.toString();
      }
      rethrow;
    } finally {
      if (requestGeneration == _switchRequestGeneration) {
        _switching = false;
        _switchGeneration++;
      }
    }
  }

  Future<void> waitUntilPrewarmed({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    await _inner?.waitUntilPrewarmed(timeout: timeout);
  }

  Future<TwitchHlsLiveStatus?> requestLiveStatus({
    Duration timeout = const Duration(milliseconds: 280),
  }) async {
    return _inner?.requestLiveStatus(timeout: timeout);
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _switchRequestGeneration++;
    _switchGeneration++;

    final inner = _inner;
    _inner = null;
    _upstreamPlaylistUrl = null;
    _directStreamUri = null;
    _directStreamGeneration++;
    _completePendingHandoff();
    await _interruptActiveUpstream();

    await inner?.close();
    await server?.close(force: true);
    _client.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/health' || path == '/debug') {
        await _handleHealth(request);
        return;
      }

      final inner = _inner;
      if ((inner == null || !inner.isRunning) && _directStreamUri == null) {
        request.response.statusCode = _switching
            ? HttpStatus.serviceUnavailable
            : HttpStatus.badGateway;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          _switching ? 'Switching upstream' : 'Inner proxy not ready',
        );
        await request.response.close();
        return;
      }

      if (path == '/' || path == '/stream' || path == '/stream.ts') {
        await _proxyStreamLoop(request);
        return;
      }

      if (path == '/live-replay.ts') {
        if (inner == null || !inner.isRunning) {
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Inner proxy not ready');
          await request.response.close();
          return;
        }
        await _proxyToInner(
          request,
          Uri.parse(
            inner.liveReplayUrl(fromLive: _readReplayDuration(request)),
          ),
        );
        return;
      }

      if (path == '/playlist.m3u8') {
        if (inner == null || !inner.isRunning) {
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Inner proxy not ready');
          await request.response.close();
          return;
        }
        await _proxyToInner(request, Uri.parse(inner.playlistUrl));
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found: $path');
      await request.response.close();
    } catch (error) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.text;
        request.response.write(error.toString());
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.text;
    request.response.write(
      'ok\n'
      'stable_port=$port\n'
      'playlist=$playlistUrl\n'
      'stream=$streamUrl\n'
      'stream_ts=$streamTsUrl\n'
      'upstream=$_upstreamPlaylistUrl\n'
      'direct=$_directStreamUri\n'
      'inner_running=${_inner?.isRunning ?? false}\n'
      'inner_stream=${_inner?.streamTsUrl}\n'
      'switching=$_switching\n'
      'switch_generation=$_switchGeneration\n'
      'switch_request_generation=$_switchRequestGeneration\n'
      'stream_client_generation=$_streamClientGeneration\n'
      'stream_upstream_attach_count=$_streamUpstreamAttachCount\n'
      'stream_upstream_retry_count=$_streamUpstreamRetryCount\n'
      'stream_bytes_forwarded=$_streamBytesForwarded\n'
      'stream_pat_handoff_count=$_streamPatHandoffCount\n'
      'stream_packet_handoff_count=$_streamPacketHandoffCount\n'
      'stream_boundary_timeout_count=$_streamBoundaryTimeoutCount\n'
      'stream_handoff_pending=${_streamHandoffCompleter != null}\n'
      'last_stream_target=$_lastStreamTarget\n'
      'last_stream_error=$_lastStreamError\n'
      'last_switch_error=$_lastSwitchError\n',
    );
    await request.response.close();
  }

  Future<void> _proxyStreamLoop(HttpRequest request) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamHeaders(request.response);
      await request.response.close();
      return;
    }

    // media_kit may open the same stable stream URL again before Windows has
    // reported the previous socket as closed. Keep only the newest stream pump
    // so stale local clients cannot multiply loopback traffic indefinitely.
    final streamClientGeneration = ++_streamClientGeneration;
    _completePendingHandoff();
    await _interruptActiveUpstream();

    final response = request.response;
    response.statusCode = HttpStatus.ok;
    _applyStreamHeaders(response);
    response.bufferOutput = false;

    var lastAttachedInnerStreamUrl = '';
    var lastGeneration = -1;
    var lastDirectStreamGeneration = -1;
    var downstreamClosed = false;

    try {
      while (_server != null &&
          streamClientGeneration == _streamClientGeneration &&
          !downstreamClosed) {
        final target = await _waitForReadyStreamTarget(
          lastGeneration: lastGeneration,
        );
        if (target == null ||
            streamClientGeneration != _streamClientGeneration) {
          break;
        }

        final directMode = _directStreamUri != null;
        lastAttachedInnerStreamUrl = target.toString();
        lastGeneration = _switchGeneration;
        lastDirectStreamGeneration = _directStreamGeneration;
        _lastStreamTarget = lastAttachedInnerStreamUrl;

        try {
          final upstreamRequest = await _client.openUrl('GET', target);
          upstreamRequest.followRedirects = true;
          upstreamRequest.maxRedirects = 4;
          final upstreamResponse = await upstreamRequest.close();
          if (upstreamResponse.statusCode < HttpStatus.ok ||
              upstreamResponse.statusCode >= HttpStatus.multipleChoices) {
            await upstreamResponse.drain();
            throw HttpException(
              'Upstream stream returned HTTP ${upstreamResponse.statusCode}',
              uri: target,
            );
          }
          _streamUpstreamAttachCount++;
          _lastStreamError = null;

          final iterator = StreamIterator<List<int>>(upstreamResponse);
          final tsAligner = directMode ? null : _MpegTsPacketAligner();
          _activeUpstreamIterator = iterator;
          var handoffTriggered = false;
          var flushedFirstPacket = false;
          var bytesSinceFlush = 0;
          var lastFlushAt = DateTime.now();
          try {
            while (await iterator.moveNext()) {
              final chunk = iterator.current;
              if (_server == null ||
                  streamClientGeneration != _streamClientGeneration) {
                break;
              }

              if (directMode) {
                try {
                  response.add(chunk);
                  await response.flush().timeout(const Duration(seconds: 1));
                  _streamBytesForwarded += chunk.length;
                } catch (error) {
                  _lastStreamError = 'downstream: $error';
                  downstreamClosed = true;
                  break;
                }
                continue;
              }

              // Inner HLS streams are MPEG-TS. Re-packetize to fixed 188-byte
              // packets so a router handoff can never expose half a TS packet
              // to libmpv/FFmpeg even when HttpClient delivers arbitrary chunks.
              for (final packet in tsAligner!.add(chunk)) {
                final handoffKind = _handoffKindBeforePacket(
                  packet: packet,
                  attachedTarget: lastAttachedInnerStreamUrl,
                );
                if (handoffKind != _StreamHandoffKind.none) {
                  // Flush any complete packets already queued for this source,
                  // then leave the detected/current packet for the new inner
                  // stream instead of mixing programs across the handoff.
                  if (bytesSinceFlush > 0) {
                    try {
                      await response.flush().timeout(
                        const Duration(seconds: 1),
                      );
                      bytesSinceFlush = 0;
                      lastFlushAt = DateTime.now();
                    } catch (error) {
                      _lastStreamError = 'downstream: $error';
                      downstreamClosed = true;
                      break;
                    }
                  }
                  handoffTriggered = true;
                  if (handoffKind == _StreamHandoffKind.pat) {
                    _streamPatHandoffCount++;
                  } else {
                    _streamPacketHandoffCount++;
                  }
                  _completePendingHandoff();
                  break;
                }

                try {
                  response.add(packet);
                  _streamBytesForwarded += packet.length;
                  bytesSinceFlush += packet.length;

                  final now = DateTime.now();
                  final shouldFlush =
                      !flushedFirstPacket ||
                      bytesSinceFlush >= 16 * 1024 ||
                      now.difference(lastFlushAt) >=
                          const Duration(milliseconds: 15);

                  if (shouldFlush) {
                    await response.flush().timeout(
                      const Duration(seconds: 1),
                    );
                    flushedFirstPacket = true;
                    bytesSinceFlush = 0;
                    lastFlushAt = now;
                  }
                } catch (error) {
                  _lastStreamError = 'downstream: $error';
                  downstreamClosed = true;
                  break;
                }
              }

              if (handoffTriggered || downstreamClosed) break;
            }

            if (!directMode && !downstreamClosed && bytesSinceFlush > 0) {
              try {
                await response.flush().timeout(const Duration(seconds: 1));
              } catch (error) {
                _lastStreamError = 'downstream: $error';
                downstreamClosed = true;
              }
            }
          } finally {
            if (identical(_activeUpstreamIterator, iterator)) {
              _activeUpstreamIterator = null;
            }
            try {
              await iterator.cancel();
            } catch (_) {}
          }
        } catch (error) {
          _lastStreamError = 'upstream: $error';

          if (_server == null ||
              downstreamClosed ||
              streamClientGeneration != _streamClientGeneration) {
            break;
          }

          // Keep the stable /stream.ts response alive across transient inner
          // proxy/CDN failures. The next loop re-resolves the current target,
          // which also picks up a quality/channel switch that completed while
          // this request was failing.
          _streamUpstreamRetryCount++;
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }

        if (downstreamClosed) break;

        if (directMode &&
            lastDirectStreamGeneration != _directStreamGeneration) {
          break;
        }

        // If the same inner stream simply ended without a router switch, do not
        // spin aggressively. Give the inner proxy a moment to expose fresh data.
        if (lastGeneration == _switchGeneration &&
            lastAttachedInnerStreamUrl == _currentStreamTargetLabel()) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
      }
    } finally {
      _completePendingHandoff();
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _handoffActiveUpstreamAtSafeBoundary() async {
    if (_activeUpstreamIterator == null) return;

    final previous = _streamHandoffCompleter;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }

    final completer = Completer<void>();
    _streamHandoffCompleter = completer;
    _streamHandoffRequestedAt = DateTime.now();

    try {
      // Normal path completes from _proxyStreamLoop at a PAT or complete packet
      // boundary. Timeout only protects channel-offline/stalled upstream cases.
      await completer.future.timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      _streamBoundaryTimeoutCount++;
      await _interruptActiveUpstream();
    } finally {
      if (identical(_streamHandoffCompleter, completer)) {
        _streamHandoffCompleter = null;
        _streamHandoffRequestedAt = null;
      }
    }
  }

  _StreamHandoffKind _handoffKindBeforePacket({
    required List<int> packet,
    required String attachedTarget,
  }) {
    final completer = _streamHandoffCompleter;
    if (completer == null || completer.isCompleted) {
      return _StreamHandoffKind.none;
    }
    if (attachedTarget == _currentStreamTargetLabel()) {
      return _StreamHandoffKind.none;
    }

    // Prefer beginning of a new PAT/program table, which is commonly emitted at
    // or near an HLS TS segment boundary. Do not wait indefinitely: after the
    // short grace period, any complete 188-byte packet boundary is still much
    // safer than cancelling an arbitrary HttpClient byte chunk.
    if (_isPatStartPacket(packet)) return _StreamHandoffKind.pat;

    final requestedAt = _streamHandoffRequestedAt;
    if (requestedAt == null ||
        DateTime.now().difference(requestedAt) >=
            const Duration(milliseconds: 450)) {
      return _StreamHandoffKind.packet;
    }
    return _StreamHandoffKind.none;
  }

  bool _isPatStartPacket(List<int> packet) {
    if (packet.length != _MpegTsPacketAligner.packetSize) return false;
    if (packet[0] != 0x47) return false;

    final payloadUnitStart = (packet[1] & 0x40) != 0;
    final pid = ((packet[1] & 0x1f) << 8) | packet[2];
    return payloadUnitStart && pid == 0;
  }

  void _completePendingHandoff() {
    final completer = _streamHandoffCompleter;
    _streamHandoffCompleter = null;
    _streamHandoffRequestedAt = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _interruptActiveUpstream() async {
    final iterator = _activeUpstreamIterator;
    _activeUpstreamIterator = null;
    if (iterator == null) return;
    try {
      await iterator.cancel();
    } catch (_) {}
  }

  Future<void> _closeInnerQuietly(
    TwitchDartHlsLowLatencyProxy? inner,
  ) async {
    if (inner == null) return;
    try {
      await inner.close();
    } catch (_) {
      // Closing the retired inner proxy must not roll back a replacement that
      // is already prewarmed and serving the stable player connection.
    }
  }

  void _applyStreamHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  }

  Duration _readReplayDuration(HttpRequest request) {
    final raw = int.tryParse(request.uri.queryParameters['seconds'] ?? '');
    return Duration(seconds: (raw ?? 10).clamp(1, 20).toInt());
  }

  Future<Uri?> _waitForReadyStreamTarget({
    required int lastGeneration,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (_server != null && DateTime.now().isBefore(deadline)) {
      final directStreamUri = _directStreamUri;
      if (directStreamUri != null && _switchGeneration != lastGeneration) {
        return directStreamUri;
      }
      if (directStreamUri != null && !_switching) {
        return directStreamUri;
      }
      final inner = _inner;
      if (inner != null &&
          inner.isRunning &&
          _switchGeneration != lastGeneration) {
        return Uri.parse(inner.streamTsUrl);
      }
      if (inner != null && inner.isRunning && !_switching) {
        return Uri.parse(inner.streamTsUrl);
      }
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }

    final directStreamUri = _directStreamUri;
    if (directStreamUri != null) return directStreamUri;
    return _inner != null && _inner!.isRunning
        ? Uri.parse(_inner!.streamTsUrl)
        : null;
  }

  String _currentStreamTargetLabel() {
    final directStreamUri = _directStreamUri;
    if (directStreamUri != null) return directStreamUri.toString();
    return _inner?.streamTsUrl ?? '';
  }

  Future<void> _proxyToInner(HttpRequest request, Uri target) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final upstreamRequest = await _client.openUrl(request.method, target);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 4;

    final upstreamResponse = await upstreamRequest.close();
    request.response.statusCode = upstreamResponse.statusCode;
    request.response.bufferOutput = false;
    request.response.headers.chunkedTransferEncoding = true;

    final contentType = upstreamResponse.headers.contentType;
    if (contentType != null) {
      request.response.headers.contentType = contentType;
    }

    await request.response.addStream(upstreamResponse);
    await request.response.close();
  }
}

enum _StreamHandoffKind { none, pat, packet }

/// Reassembles arbitrary HttpClient chunks into decoder-safe MPEG-TS packets.
///
/// Twitch HLS transport-stream payloads use 188-byte packets. Network chunk
/// boundaries are unrelated to TS packet boundaries, so forwarding the raw
/// chunks and cancelling between them can leave FFmpeg with a truncated packet.
class _MpegTsPacketAligner {
  static const int packetSize = 188;

  final List<int> _buffer = <int>[];

  Iterable<List<int>> add(List<int> chunk) sync* {
    if (chunk.isEmpty) return;
    _buffer.addAll(chunk);

    while (_buffer.length >= packetSize) {
      final syncIndex = _findSyncOffset();
      if (syncIndex < 0) {
        // Preserve a possible partial packet tail while bounding memory if the
        // upstream unexpectedly returns non-TS data.
        final keep = packetSize - 1;
        if (_buffer.length > keep) {
          _buffer.removeRange(0, _buffer.length - keep);
        }
        return;
      }

      if (syncIndex > 0) {
        _buffer.removeRange(0, syncIndex);
        if (_buffer.length < packetSize) return;
      }

      // If another complete packet is already buffered, require its sync byte
      // too. This rejects a stray 0x47 found inside payload bytes.
      if (_buffer.length >= packetSize * 2 && _buffer[packetSize] != 0x47) {
        _buffer.removeAt(0);
        continue;
      }

      final packet = List<int>.of(_buffer.getRange(0, packetSize));
      _buffer.removeRange(0, packetSize);
      yield packet;
    }
  }

  int _findSyncOffset() {
    for (var i = 0; i < _buffer.length; i++) {
      if (_buffer[i] != 0x47) continue;
      final next = i + packetSize;
      if (next >= _buffer.length || _buffer[next] == 0x47) {
        return i;
      }
    }
    return -1;
  }
}
