part of '../twitch_hls_low_latency_proxy.dart';

class _TwitchDartHlsLowLatencyProxyCore {
  final String upstreamPlaylistUrl;
  final Map<String, String> upstreamHeaders;
  final int edgeSegmentCount;
  final int prefetchSegmentCount;
  final bool outputFutureSegments;
  final int futureOutputSegmentCount;
  final void Function(String message)? onLog;
  final bool verboseLogging;
  final Duration minPlaylistReloadDelay;
  final Duration maxPlaylistReloadDelay;
  final bool dropBehindLiveEdge;
  final int startupEdgeSegmentCount;
  final bool startupRequirePrefetchedFirstSegment;
  final bool startupSkipCurrentLatestSegment;
  final Duration startupPrefetchWaitTimeout;
  final Duration startupFutureReadyWaitTimeout;
  final Duration idleKeepAliveDuration;
  final TwitchHlsStartupMode startupMode;
  final DateTime? timelineOrigin;

  _TwitchDartHlsLowLatencyProxyCore({
    required this.upstreamPlaylistUrl,
    required this.upstreamHeaders,
    this.edgeSegmentCount = 1,
    this.prefetchSegmentCount = 3,
    this.outputFutureSegments = true,
    this.futureOutputSegmentCount = 1,
    this.onLog,
    this.verboseLogging = false,
    this.minPlaylistReloadDelay = const Duration(milliseconds: 30),
    this.maxPlaylistReloadDelay = const Duration(milliseconds: 180),
    this.dropBehindLiveEdge = true,
    this.startupEdgeSegmentCount = 1,
    this.startupRequirePrefetchedFirstSegment = false,
    this.startupSkipCurrentLatestSegment = false,
    this.startupPrefetchWaitTimeout = const Duration(milliseconds: 1400),
    this.startupFutureReadyWaitTimeout = const Duration(milliseconds: 140),
    this.idleKeepAliveDuration = const Duration(seconds: 3),
    this.startupMode = TwitchHlsStartupMode.streamlinkLiveEdge,
    this.timelineOrigin,
  });

  final HttpClient httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 12)
    ..maxConnectionsPerHost = 32
    ..autoUncompress = false;

  final Expando<_TwitchHlsPrefetchRuntimeState> _prefetchRuntimeStates =
      Expando<_TwitchHlsPrefetchRuntimeState>(
        'twitch_hls_prefetch_runtime_state',
      );

  final LinkedHashMap<String, List<int>> _initMapBytesCache =
      LinkedHashMap<String, List<int>>();

  HttpServer? server;
  int? port;
  _TwitchHlsLowLatencyEngine? _prewarmEngine;

  bool get isRunning => server != null && port != null;

  String get playlistUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/playlist.m3u8';
  }

  String get streamUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/';
  }

  String get streamTsUrl {
    final p = port;
    if (p == null) throw StateError('Proxy has not started.');
    return 'http://127.0.0.1:$p/stream.ts';
  }

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    port = server!.port;

    unawaited(_serve(server!));

    final engine = _TwitchHlsLowLatencyEngine(
      owner: this,
      playlistUrl: upstreamPlaylistUrl,
    );

    _prewarmEngine = engine;
    engine.startPrewarm();

    unawaited(
      engine.waitUntilReady(timeout: const Duration(milliseconds: 900)),
    );
  }

  Future<void> waitUntilPrewarmed({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final engine = _prewarmEngine;
    if (engine == null || engine.isStopped) return;
    await engine.waitUntilReady(timeout: timeout);
  }

  Future<void> reconnectAtSegmentBoundary({required Duration timeout}) async {
    final previous = _prewarmEngine;
    if (previous == null || previous.isStopped) return;

    final deadline = DateTime.now().add(timeout);
    final lastWrittenSequence = await previous.stopWriterAtSegmentBoundary(
      timeout: timeout,
    );
    final replayItems = previous.snapshotRecentReplayItems();
    previous.stop();

    if (server == null) return;
    final next = _TwitchHlsLowLatencyEngine(
      owner: this,
      playlistUrl: upstreamPlaylistUrl,
      startupAfterSequence: lastWrittenSequence,
    );
    next.rememberAvailableReplayItems(replayItems);
    _prewarmEngine = next;
    next.startPrewarm();
    final remaining = deadline.difference(DateTime.now());
    await next.waitUntilReady(
      timeout: remaining > Duration.zero ? remaining : Duration.zero,
    );
  }

  TwitchHlsLiveStatus liveStatus() {
    final engine = _prewarmEngine;
    if (engine == null || engine.isStopped) {
      return TwitchHlsLiveStatus.stopped();
    }
    return engine.liveStatus();
  }

  Future<void> close() async {
    final currentServer = server;
    final currentEngine = _prewarmEngine;

    _prewarmEngine = null;
    server = null;
    port = null;

    await currentEngine?.disconnectClients();
    currentEngine?.stop();
    httpClient.close(force: true);
    await currentServer?.close(force: true);
  }

  void log(String message) {}

  void timeLog(
    String event, [
    Map<String, Object?> fields = const <String, Object?>{},
  ]) {}

  _TwitchHlsPrefetchRuntimeState _prefetchState(
    TwitchHlsSegmentPrefetchJob job,
  ) {
    final existing = _prefetchRuntimeStates[job];
    if (existing != null) return existing;

    final created = _TwitchHlsPrefetchRuntimeState();
    _prefetchRuntimeStates[job] = created;
    return created;
  }

  _TwitchHlsPrefetchRuntimeState? prefetchStateForJob(
    TwitchHlsSegmentPrefetchJob? job,
  ) {
    if (job == null) return null;
    return _prefetchRuntimeStates[job];
  }

  Future<void> _serve(HttpServer httpServer) async {
    await for (final request in httpServer) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/' || path == '/stream' || path == '/stream.ts') {
        await _handleStream(request, upstreamPlaylistUrl);
      } else if (path == '/live-replay.ts') {
        await _handleLiveReplay(request, _readReplayDuration(request));
      } else if (path == '/playlist.m3u8') {
        await _handlePlaylist(request, upstreamPlaylistUrl);
      } else if (path == '/hls.m3u8') {
        final upstream = _readUrlQuery(request);
        if (upstream == null) {
          await _badRequest(request, 'Missing playlist url');
        } else {
          await _handlePlaylist(request, upstream);
        }
      } else if (path.startsWith('/segment')) {
        final upstream = _readUrlQuery(request);
        if (upstream == null) {
          await _badRequest(request, 'Missing segment url');
        } else {
          await _handleSegment(request, upstream);
        }
      } else if (path == '/health' || path == '/debug') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          'ok\n'
          'playlist=$playlistUrl\n'
          'stream=$streamUrl\n'
          'stream_ts=$streamTsUrl\n'
          'upstream=$upstreamPlaylistUrl\n'
          'live_edge=$edgeSegmentCount\n'
          'startup_edge=$startupEdgeSegmentCount\n'
          'startup_require_prefetch=$startupRequirePrefetchedFirstSegment\n'
          'startup_skip_current_latest=$startupSkipCurrentLatestSegment\n'
          'startup_prefetch_timeout_ms=${startupPrefetchWaitTimeout.inMilliseconds}\n'
          'startup_future_ready_wait_ms=${startupFutureReadyWaitTimeout.inMilliseconds}\n'
          'startup_mode=${startupMode.name}\n'
          'prefetch=$prefetchSegmentCount\n'
          'prefetch_max=$_maxActivePrefetchJobs\n'
          'output_future_segments=$outputFutureSegments\n'
          'future_output_count=$futureOutputSegmentCount\n'
          'reload=${minPlaylistReloadDelay.inMilliseconds}-${maxPlaylistReloadDelay.inMilliseconds}ms\n'
          'dropBehindLiveEdge=$dropBehindLiveEdge\n'
          'idle_keep_alive_ms=${idleKeepAliveDuration.inMilliseconds}\n'
          'isolate=true\n',
        );
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not found: $path');
        await request.response.close();
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.text;
        request.response.write(e.toString());
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleStream(HttpRequest request, String url) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamlinkLikeHeaders(request.response);
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    _applyStreamlinkLikeHeaders(request.response);
    request.response.bufferOutput = false;

    final engine = _takePrewarmedEngine(url);
    engine.startPrewarm();

    try {
      await engine.pipeClientToResponse(request.response);
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      if (server != null && identical(_prewarmEngine, engine)) {
        engine.scheduleIdleStop();
      } else if (!identical(_prewarmEngine, engine)) {
        engine.stop();
      }
    }
  }

  Future<void> _handleLiveReplay(HttpRequest request, Duration fromLive) async {
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      _applyStreamlinkLikeHeaders(request.response);
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    _applyStreamlinkLikeHeaders(request.response);
    request.response.bufferOutput = false;

    final engine = _takePrewarmedEngine(upstreamPlaylistUrl);
    engine.startPrewarm();

    try {
      await engine.pipeReplayToResponse(
        response: request.response,
        fromLive: fromLive,
      );
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      if (server != null && identical(_prewarmEngine, engine)) {
        engine.scheduleIdleStop();
      } else if (!identical(_prewarmEngine, engine)) {
        engine.stop();
      }
    }
  }

  _TwitchHlsLowLatencyEngine _takePrewarmedEngine(String url) {
    final engine = _prewarmEngine;

    if (engine != null && !engine.isStopped && engine.playlistUrl == url) {
      engine.cancelIdleStop();
      return engine;
    }

    engine?.stop();

    final fresh = _TwitchHlsLowLatencyEngine(owner: this, playlistUrl: url);

    _prewarmEngine = fresh;
    fresh.startPrewarm();

    return fresh;
  }

  void _applyStreamlinkLikeHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.serverHeader, 'Streamlink');
    response.headers.contentType = ContentType('video', 'mp2t');
    response.headers.chunkedTransferEncoding = true;
  }

  Future<void> _pipeEngineOutputToResponse({
    required HttpResponse response,
    required StreamIterator<List<int>> iterator,
  }) async {
    var flushedFirstChunk = false;
    var bytesSinceFlush = 0;
    var lastFlushAt = DateTime.now();

    while (await iterator.moveNext()) {
      final chunk = iterator.current;
      response.add(chunk);
      bytesSinceFlush += chunk.length;

      final now = DateTime.now();
      final shouldFlush =
          !flushedFirstChunk ||
          bytesSinceFlush >= 16 * 1024 ||
          now.difference(lastFlushAt) >= const Duration(milliseconds: 15);

      if (shouldFlush) {
        await response.flush().timeout(const Duration(seconds: 1));
        flushedFirstChunk = true;
        bytesSinceFlush = 0;
        lastFlushAt = now;
      }
    }

    if (bytesSinceFlush > 0) {
      await response.flush().timeout(const Duration(seconds: 1));
    }
  }

  String? _readUrlQuery(HttpRequest request) {
    final raw = request.uri.queryParameters['u'];
    if (raw == null || raw.isEmpty) return null;
    return _decodeUrl(raw);
  }

  Duration _readReplayDuration(HttpRequest request) {
    final raw = int.tryParse(request.uri.queryParameters['seconds'] ?? '');
    return Duration(seconds: (raw ?? 10).clamp(1, 20).toInt());
  }

  Future<void> _badRequest(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.headers.contentType = ContentType.text;
    request.response.write(message);
    await request.response.close();
  }

  Duration _strictReloadDelay(Duration targetDelay, Duration elapsed) {
    final remaining = targetDelay - elapsed;
    if (remaining <= minPlaylistReloadDelay) return minPlaylistReloadDelay;
    if (remaining >= maxPlaylistReloadDelay) return maxPlaylistReloadDelay;
    return remaining;
  }

  int get _maxActivePrefetchJobs {
    return math.max(prefetchSegmentCount + 2, 6);
  }

  Future<TwitchParsedMediaPlaylist> _loadMediaPlaylist(String url) async {
    final upstreamResponse = await _openSuccessfulUpstream(
      method: 'GET',
      url: url,
      range: null,
      retryLiveSegment: true,
      label: 'playlist',
    );

    final bytes = await _readAll(upstreamResponse);
    final playlistText = utf8.decode(bytes, allowMalformed: true);
    return _parseMediaPlaylist(playlistText, playlistUrl: url);
  }

  TwitchParsedMediaPlaylist _parseMediaPlaylist(
    String playlistText, {
    required String playlistUrl,
  }) {
    return TwitchHlsPlaylistParser.parse(
      playlistText,
      playlistUrl: playlistUrl,
    );
  }

  void _schedulePrefetches({
    required List<TwitchHlsSegmentItem> items,
    required Set<String> servedUrls,
    required LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> prefetches,
  }) {
    if (prefetchSegmentCount <= 0) return;

    final maxPrefetchJobs = _maxActivePrefetchJobs;
    _trimPrefetchJobs(prefetches, maxPrefetchJobs);

    var added = 0;

    for (final item in items) {
      if (added >= prefetchSegmentCount) break;
      if (prefetches.length >= maxPrefetchJobs) break;
      if (servedUrls.contains(item.url) || prefetches.containsKey(item.url)) {
        continue;
      }

      final job = TwitchHlsSegmentPrefetchJob(item);
      final state = _prefetchState(job);
      state.requestStartedAt = DateTime.now();

      prefetches[item.url] = job;
      added++;

      unawaited(_runPrefetchJob(job));
    }

    _trimPrefetchJobs(prefetches, maxPrefetchJobs);
  }

  void _trimPrefetchJobs(
    LinkedHashMap<String, TwitchHlsSegmentPrefetchJob> prefetches,
    int maxPrefetchJobs,
  ) {
    while (prefetches.length > maxPrefetchJobs) {
      String? removeKey;

      for (final entry in prefetches.entries) {
        if (!entry.value.item.isPrefetch) {
          removeKey = entry.key;
          break;
        }
      }

      removeKey ??= prefetches.keys.first;

      final removed = prefetches.remove(removeKey);
      removed?.cancel();
    }
  }

  Future<void> _runPrefetchJob(TwitchHlsSegmentPrefetchJob job) async {
    if (job.cancelled) return;

    final state = _prefetchState(job);
    state.requestStartedAt ??= DateTime.now();

    try {
      final upstreamResponse = await _openSuccessfulUpstream(
        method: 'GET',
        url: job.item.url,
        range: null,
        retryLiveSegment: true,
        label: 'prefetch',
      );

      state.responseOpenedAt = DateTime.now();

      await for (final chunk in upstreamResponse) {
        if (job.cancelled) break;

        state.bytesReceived += chunk.length;
        state.firstChunkAt ??= DateTime.now();

        if (!job.controller.isClosed) {
          job.controller.add(chunk);
        }
      }

      if (!job.controller.isClosed) {
        await job.controller.close();
      }

      if (!job.completed.isCompleted) {
        job.completed.complete();
      }
    } catch (e, stackTrace) {
      if (job.cancelled) return;

      state.failed = true;
      job.error = e;
      job.stackTrace = stackTrace;

      if (!job.controller.isClosed) {
        job.controller.addError(e, stackTrace);
        await job.controller.close();
      }

      if (!job.completed.isCompleted) {
        job.completed.complete();
      }
    }
  }

  Future<void> _pipeSegmentToOutputBuffer({
    required TwitchHlsByteSink output,
    required TwitchHlsSegmentItem item,
    TwitchHlsSegmentPrefetchJob? prefetchJob,
  }) async {
    final job = prefetchJob;

    if (job != null) {
      try {
        await output.addStream(job.controller.stream);
        return;
      } catch (_) {}
    }

    final upstreamResponse = await _openSuccessfulUpstream(
      method: 'GET',
      url: item.url,
      range: null,
      retryLiveSegment: true,
      label: 'segment',
    );

    await output.addStream(upstreamResponse);
  }

  Future<HttpClientResponse> _openSuccessfulUpstream({
    required String method,
    required String url,
    String? range,
    bool retryLiveSegment = false,
    String label = '',
  }) async {
    final maxAttempts = retryLiveSegment ? 14 : 3;
    var delay = retryLiveSegment
        ? const Duration(milliseconds: 35)
        : const Duration(milliseconds: 100);
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final upstreamResponse = await _openRawUpstream(
          method: method,
          url: url,
          range: range,
        );

        final status = upstreamResponse.statusCode;
        if ((status >= 200 && status < 300) ||
            status == HttpStatus.partialContent) {
          return upstreamResponse;
        }

        await _discardUpstreamResponse(upstreamResponse);
        lastError = HttpException('Upstream HTTP $status for $label');

        if (!retryLiveSegment || attempt >= maxAttempts) {
          throw lastError;
        }
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;

        if (!retryLiveSegment || attempt >= maxAttempts) {
          Error.throwWithStackTrace(e, stackTrace);
        }
      }

      await Future<void>.delayed(delay);

      final nextMs = math
          .min(
            (delay.inMilliseconds * 1.45).round() + 20,
            retryLiveSegment ? 260 : 520,
          )
          .toInt();

      delay = Duration(milliseconds: nextMs);
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Unknown upstream error for $label'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  Future<void> _discardUpstreamResponse(HttpClientResponse response) async {
    try {
      await for (final _ in response) {}
    } catch (_) {}
  }

  Future<HttpClientResponse> _openRawUpstream({
    required String method,
    required String url,
    String? range,
  }) async {
    final uri = Uri.parse(url);
    final upstreamRequest = await httpClient.openUrl(method, uri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;

    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isEmpty || value.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;

      upstreamRequest.headers.set(key, value);
    }

    if (range != null && range.trim().isNotEmpty) {
      upstreamRequest.headers.set(HttpHeaders.rangeHeader, range.trim());
    }

    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.endsWith('.m3u8') || lowerPath.contains('.m3u8')) {
      upstreamRequest.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      upstreamRequest.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    }

    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    upstreamRequest.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    return upstreamRequest.close();
  }

  Future<void> _handlePlaylist(HttpRequest request, String url) async {
    final upstreamResponse = await _openUpstream(
      method: 'GET',
      url: url,
      incomingRequest: request,
      forwardRange: false,
    );

    final bytes = await _readAll(upstreamResponse);
    final playlistText = utf8.decode(bytes, allowMalformed: true);
    final rewritten = _rewritePlaylistCompat(playlistText, playlistUrl: url);
    final rewrittenBytes = utf8.encode(rewritten);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
      charset: 'utf-8',
    );
    request.response.headers.set(
      HttpHeaders.cacheControlHeader,
      'no-store, no-cache, must-revalidate',
    );
    request.response.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
    request.response.headers.set(
      HttpHeaders.accessControlAllowOriginHeader,
      '*',
    );
    request.response.headers.contentLength = rewrittenBytes.length;

    if (request.method != 'HEAD') {
      request.response.add(rewrittenBytes);
    }

    await request.response.close();
  }

  Future<void> _handleSegment(HttpRequest request, String url) async {
    final upstreamResponse = await _openUpstream(
      method: request.method == 'HEAD' ? 'HEAD' : 'GET',
      url: url,
      incomingRequest: request,
      forwardRange: true,
    );

    request.response.statusCode = upstreamResponse.statusCode;

    _copySelectedResponseHeaders(
      upstreamResponse,
      request.response,
      fallbackUrl: url,
    );

    request.response.headers.set(
      HttpHeaders.accessControlAllowOriginHeader,
      '*',
    );

    if (request.method != 'HEAD') {
      await upstreamResponse.pipe(request.response);
    } else {
      await request.response.close();
    }
  }

  Future<HttpClientResponse> _openUpstream({
    required String method,
    required String url,
    required HttpRequest incomingRequest,
    required bool forwardRange,
  }) async {
    final uri = Uri.parse(url);
    final upstreamRequest = await httpClient.openUrl(method, uri);
    upstreamRequest.followRedirects = true;
    upstreamRequest.maxRedirects = 5;

    for (final entry in upstreamHeaders.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isEmpty || value.isEmpty) continue;
      if (key.toLowerCase() == HttpHeaders.hostHeader) continue;

      upstreamRequest.headers.set(key, value);
    }

    final incomingUserAgent = incomingRequest.headers.value(
      HttpHeaders.userAgentHeader,
    );
    if (incomingUserAgent != null && incomingUserAgent.trim().isNotEmpty) {
      upstreamRequest.headers.set(
        HttpHeaders.userAgentHeader,
        incomingUserAgent.trim(),
      );
    }

    if (forwardRange) {
      final range = incomingRequest.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.trim().isNotEmpty) {
        upstreamRequest.headers.set(HttpHeaders.rangeHeader, range.trim());
      }
    }

    upstreamRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    upstreamRequest.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

    return upstreamRequest.close();
  }

  Future<List<int>> _readAll(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);

    await for (final chunk in stream) {
      bytes.add(chunk);
    }

    return bytes.takeBytes();
  }

  Future<List<int>> _loadInitMapBytes(String url) async {
    final cached = _initMapBytesCache.remove(url);
    if (cached != null) {
      // Refresh LRU order.
      _initMapBytesCache[url] = cached;
      return cached;
    }

    final response = await _openSuccessfulUpstream(
      method: 'GET',
      url: url,
      range: null,
      retryLiveSegment: true,
      label: 'init map',
    );

    final bytes = List<int>.unmodifiable(await _readAll(response));
    _initMapBytesCache[url] = bytes;

    while (_initMapBytesCache.length > 8) {
      _initMapBytesCache.remove(_initMapBytesCache.keys.first);
    }

    return bytes;
  }

  void _copySelectedResponseHeaders(
    HttpClientResponse upstreamResponse,
    HttpResponse localResponse, {
    required String fallbackUrl,
  }) {
    final passthroughHeaders = <String>{
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.lastModifiedHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.cacheControlHeader,
    };

    upstreamResponse.headers.forEach((name, values) {
      final lower = name.toLowerCase();

      if (!passthroughHeaders.contains(lower)) return;
      if (values.isEmpty) return;

      localResponse.headers.set(name, values);
    });

    localResponse.headers.contentType = _guessSegmentContentType(
      upstreamResponse.headers.value(HttpHeaders.contentTypeHeader),
      fallbackUrl,
    );

    localResponse.headers.set(
      HttpHeaders.cacheControlHeader,
      'public, max-age=10',
    );
  }

  ContentType _guessSegmentContentType(
    String? upstreamContentType,
    String url,
  ) {
    final lowerType = (upstreamContentType ?? '').toLowerCase();

    if (lowerType.contains('mp2t')) return ContentType('video', 'mp2t');
    if (lowerType.contains('mp4')) return ContentType('video', 'mp4');

    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();

    if (path.endsWith('.ts')) return ContentType('video', 'mp2t');

    if (path.endsWith('.m4s') ||
        path.endsWith('.mp4') ||
        path.contains('.mp4')) {
      return ContentType('video', 'mp4');
    }

    if (path.endsWith('.aac')) return ContentType('audio', 'aac');

    return ContentType('video', 'mp4');
  }

  String _rewritePlaylistCompat(
    String playlistText, {
    required String playlistUrl,
  }) {
    final upstreamBase = Uri.parse(playlistUrl);
    final output = StringBuffer();

    var skipNextUriLineForLowLatencyTag = false;

    for (final rawLine in playlistText.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        output.writeln();
        continue;
      }

      if (_isLowLatencyOnlyTag(line)) {
        skipNextUriLineForLowLatencyTag =
            line.startsWith('#EXT-X-TWITCH-PREFETCH') ||
            line.startsWith('#EXT-X-PREFETCH');
        continue;
      }

      if (skipNextUriLineForLowLatencyTag && !line.startsWith('#')) {
        skipNextUriLineForLowLatencyTag = false;
        continue;
      }

      skipNextUriLineForLowLatencyTag = false;

      if (line.startsWith('#')) {
        output.writeln(_rewriteTagUris(line, upstreamBase));
        continue;
      }

      final absoluteUrl = upstreamBase.resolve(line).toString();

      if (_looksLikePlaylistUrl(absoluteUrl)) {
        output.writeln(_proxyPlaylistUrl(absoluteUrl));
      } else {
        output.writeln(_proxySegmentUrl(absoluteUrl));
      }
    }

    return output.toString();
  }

  bool _isLowLatencyOnlyTag(String line) {
    return line.startsWith('#EXT-X-PART') ||
        line.startsWith('#EXT-X-PRELOAD-HINT') ||
        line.startsWith('#EXT-X-RENDITION-REPORT') ||
        line.startsWith('#EXT-X-SERVER-CONTROL') ||
        line.startsWith('#EXT-X-TWITCH-PREFETCH') ||
        line.startsWith('#EXT-X-PREFETCH');
  }

  String _rewriteTagUris(String line, Uri upstreamBase) {
    return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
      final rawUri = match.group(1) ?? '';
      if (rawUri.isEmpty) return match.group(0) ?? '';

      final absoluteUrl = upstreamBase.resolve(rawUri).toString();

      if (_looksLikePlaylistUrl(absoluteUrl)) {
        return 'URI="${_proxyPlaylistUrl(absoluteUrl)}"';
      }

      return 'URI="${_proxySegmentUrl(absoluteUrl)}"';
    });
  }

  bool _looksLikePlaylistUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.contains('.m3u8/');
  }

  String _proxyPlaylistUrl(String absoluteUrl) {
    return 'http://127.0.0.1:$port/hls.m3u8?u=${_encodeUrl(absoluteUrl)}';
  }

  String _proxySegmentUrl(String absoluteUrl) {
    final path = Uri.tryParse(absoluteUrl)?.path.toLowerCase() ?? '';

    final ext = path.endsWith('.ts')
        ? 'ts'
        : path.endsWith('.aac')
        ? 'aac'
        : 'm4s';

    return 'http://127.0.0.1:$port/segment.$ext?u=${_encodeUrl(absoluteUrl)}';
  }

  String _encodeUrl(String value) {
    return Uri.encodeComponent(base64Url.encode(utf8.encode(value)));
  }

  String _decodeUrl(String value) {
    return utf8.decode(base64Url.decode(Uri.decodeComponent(value)));
  }
}
