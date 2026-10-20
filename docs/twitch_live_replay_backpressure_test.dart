// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/services/playback/twitch_sequential_live_replay_proxy.dart';

void main() {
  test(
    'near-live replay does not restart a partial segment for a slow reader',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = 'http://127.0.0.1:${upstream.port}';
      final requested = Completer<void>();
      var segmentRequests = 0;
      final chunk = Uint8List(64 * 1024);
      final subscription = upstream.listen((request) {
        if (request.uri.path == '/index.m3u8') {
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:20\n'
            '#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:20,\n$origin/0.ts\n',
          );
        } else {
          segmentRequests++;
          if (!requested.isCompleted) requested.complete();
          request.response.contentLength = chunk.length * 256;
          for (var i = 0; i < 256; i++) {
            request.response.add(chunk);
          }
        }
        unawaited(request.response.close().catchError((Object _) {}));
      });
      final logs = <String>[];
      final replay = TwitchSequentialLiveReplayProxy(
        upstreamPlaylistUrl: '$origin/index.m3u8',
        upstreamHeaders: const {},
        onLog: logs.add,
      );
      Socket? consumer;
      try {
        await replay.start();
        final uri = Uri.parse(
          replay.streamUrlForCanonicalTarget(canonicalTarget: Duration.zero),
        );
        consumer = await Socket.connect(uri.host, uri.port);
        consumer.write(
          'GET ${uri.path}?${uri.query} HTTP/1.1\r\nHost: ${uri.host}\r\nConnection: close\r\n\r\n',
        );
        await consumer.flush();
        await requested.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(
          segmentRequests,
          1,
          reason: 'Backpressure must not refetch and duplicate partial bytes.',
        );
        final received = Completer<void>();
        var bytes = 0;
        consumer.listen((data) {
          bytes += data.length;
          if (bytes >= chunk.length * 256 && !received.isCompleted) {
            received.complete();
          }
        }, onError: (Object _) {});
        await received.future.timeout(const Duration(seconds: 8));
        expect(segmentRequests, 1);
        expect(logs.where((line) => line.contains('stream error')), isEmpty);
      } finally {
        consumer?.destroy();
        await replay.close().timeout(const Duration(seconds: 3));
        await subscription.cancel();
        await upstream.close(force: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
