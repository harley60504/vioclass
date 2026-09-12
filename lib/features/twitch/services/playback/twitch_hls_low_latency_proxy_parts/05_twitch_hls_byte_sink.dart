part of '../twitch_hls_low_latency_proxy.dart';

abstract class TwitchHlsByteSink {
  int get bufferedBytes;

  Future<void> addStream(Stream<List<int>> stream);

  void close();
}

class _TwitchHlsResponseByteSink implements TwitchHlsByteSink {
  final HttpResponse response;

  _TwitchHlsResponseByteSink(this.response);

  @override
  int get bufferedBytes => 0;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      response.add(chunk);
      await response.flush().timeout(const Duration(seconds: 1));
    }
  }

  @override
  void close() {}
}

class TwitchHlsLiveByteBus implements TwitchHlsByteSink {
  final int maxReplayBytes;

  TwitchHlsLiveByteBus({required this.maxReplayBytes});

  final ListQueue<List<int>> _replayChunks = ListQueue<List<int>>();
  final Set<StreamController<List<int>>> _clients =
      <StreamController<List<int>>>{};

  bool _closed = false;
  int _bufferedBytes = 0;

  @override
  int get bufferedBytes => _bufferedBytes;

  Stream<List<int>> createClientStream({bool includeReplay = true}) {
    late final StreamController<List<int>> controller;

    controller = StreamController<List<int>>(
      sync: true,
      onListen: () {
        if (_closed) {
          controller.close();
          return;
        }

        _clients.add(controller);

        if (includeReplay) {
          for (final chunk in _replayChunks) {
            if (controller.isClosed) break;
            controller.add(chunk);
          }
        }
      },
      onCancel: () {
        _clients.remove(controller);
      },
    );

    return controller.stream;
  }

  void beginSegment() {
    if (_closed) return;
    _replayChunks.clear();
    _bufferedBytes = 0;
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (_closed) return;
      _add(chunk);
    }
  }

  void _add(List<int> chunk) {
    if (_closed || chunk.isEmpty) return;

    // Keep replay and any briefly queued client data byte-packed. A normal
    // fixed-length List<int> stores references and can use many times the
    // segment size while a disconnected loopback client is being cancelled.
    final safeChunk = Uint8List.fromList(chunk);
    _replayChunks.addLast(safeChunk);
    _bufferedBytes += safeChunk.length;

    // Soft segment-aware replay:
    // beginSegment() clears the replay queue at media-segment boundaries, so all
    // chunks here belong to the current segment. Avoid trimming inside the
    // current segment; otherwise a late client can start from a partial H264/TS
    // packet and spam PPS/no-frame decoder warnings before the next keyframe.
    // Keep only an emergency cap for pathological segments.
    final emergencyLimit = math.max(maxReplayBytes * 4, 16 * 1024 * 1024);
    while (_bufferedBytes > emergencyLimit && _replayChunks.length > 1) {
      final removed = _replayChunks.removeFirst();
      _bufferedBytes -= removed.length;
    }

    final disconnected = <StreamController<List<int>>>[];

    for (final client in _clients) {
      if (client.isClosed) {
        disconnected.add(client);
        continue;
      }

      try {
        client.add(safeChunk);
      } catch (_) {
        disconnected.add(client);
      }
    }

    for (final client in disconnected) {
      _clients.remove(client);
    }
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;

    for (final client in List<StreamController<List<int>>>.of(_clients)) {
      try {
        client.close();
      } catch (_) {}
    }

    _clients.clear();
    _replayChunks.clear();
    _bufferedBytes = 0;
  }
}

class TwitchHlsOutputBuffer implements TwitchHlsByteSink {
  final int maxBufferedBytes;

  TwitchHlsOutputBuffer({required this.maxBufferedBytes});

  final StreamController<List<int>> _controller = StreamController<List<int>>(
    sync: true,
  );

  bool _closed = false;
  int _bufferedBytes = 0;

  Stream<List<int>> get stream => _controller.stream;
  @override
  int get bufferedBytes => _bufferedBytes;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      if (_closed) return;

      _bufferedBytes += chunk.length;
      _controller.add(chunk);

      if (_bufferedBytes > maxBufferedBytes) {
        _bufferedBytes = maxBufferedBytes;
      }
    }

    _bufferedBytes = 0;
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;
    _controller.close();
  }
}
