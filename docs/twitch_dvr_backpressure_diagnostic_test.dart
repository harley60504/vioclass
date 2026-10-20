// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/services/playback/twitch_live_dvr_bridge_proxy.dart';

// Regression for the observed one-second downstream-flush timeout.
// Loopback-only synthetic bytes; no account, Twitch data or real player.
void main() {
  for (final action in ['resume', 'seek', 'reconnect', 'stop']) {
    test('slow DVR consumer survives backpressure and can $action', () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = 'http://127.0.0.1:${upstream.port}';
      final chunk = Uint8List(64 * 1024);
      final subscription = upstream.listen((request) {
        if (request.uri.path == '/index.m3u8') {
          request.response.headers.contentType = ContentType.text;
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:10\n'
            '#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:10,\n$origin/0.ts\n'
            '#EXTINF:10,\n$origin/1.ts\n#EXTINF:10,\n$origin/2.ts\n',
          );
        } else {
          request.response.contentLength = chunk.length * 256;
          for (var i = 0; i < 256; i++) {
            request.response.add(chunk);
          }
        }
        unawaited(request.response.close().catchError((Object _) {}));
      });
      final proxy = TwitchLiveDvrBridgeProxy();
      Socket? consumer;
      Socket? nextConsumer;
      final oldPrint = debugPrint;
      final firstByte = Completer<void>();
      final segmentDone = Completer<void>();
      final received = Completer<void>();
      final safeLogs = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null &&
            (message.startsWith('[DvrSegment]') ||
                message.startsWith('[DvrSequential] stream error'))) {
          safeLogs.add(message);
          if (message.contains('first-byte') && !firstByte.isCompleted) {
            firstByte.complete();
          }
          if (message.contains('[DvrSegment] done') &&
              message.contains('segment=${action == 'seek' ? 1 : 0}.ts') &&
              !segmentDone.isCompleted) {
            segmentDone.complete();
          }
        }
      };
      try {
        await proxy.open(dvrPlaylistUri: Uri.parse('$origin/index.m3u8'));
        await proxy.seekToPosition(Duration.zero);
        final playback = Uri.parse(proxy.streamTsPlaybackUrl);
        consumer = await Socket.connect(playback.host, playback.port);
        consumer.write(
          'GET ${playback.path}?${playback.query} HTTP/1.1\r\n'
          'Host: ${playback.host}\r\nConnection: close\r\n\r\n',
        );
        await consumer.flush();
        // The same stalled consumer reproduced the original one-second timeout.
        await firstByte.future.timeout(const Duration(seconds: 5));
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(
          safeLogs.where((line) => line.contains('stream error')),
          isEmpty,
        );
        expect(safeLogs.any((line) => line.contains('status=200')), isTrue);
        if (action == 'stop') {
          proxy.stopStreaming();
          await proxy.close().timeout(const Duration(seconds: 2));
        } else {
          Socket readingConsumer = consumer;
          if (action == 'seek' || action == 'reconnect') {
            if (action == 'seek') {
              await proxy.seekToPosition(const Duration(seconds: 10));
            }
            final nextPlayback = Uri.parse(proxy.streamTsPlaybackUrl);
            nextConsumer = await Socket.connect(
              nextPlayback.host,
              nextPlayback.port,
            );
            nextConsumer.write(
              'GET ${nextPlayback.path}?${nextPlayback.query} HTTP/1.1\r\n'
              'Host: ${nextPlayback.host}\r\nConnection: close\r\n\r\n',
            );
            await nextConsumer.flush();
            readingConsumer = nextConsumer;
          }
          var bytes = 0;
          readingConsumer.listen((data) {
            bytes += data.length;
            if (bytes >= chunk.length * 256 && !received.isCompleted) {
              received.complete();
            }
          }, onError: (Object _) {});
          await segmentDone.future.timeout(const Duration(seconds: 6));
          await received.future.timeout(const Duration(seconds: 6));
          expect(
            safeLogs.where((line) => line.contains('TimeoutException')),
            isEmpty,
          );
        }
        oldPrint(
          'DVR regression: paused consumer can $action without one-second cutoff.',
        );
      } finally {
        consumer?.destroy();
        nextConsumer?.destroy();
        await proxy.close();
        await subscription.cancel();
        await upstream.close(force: true);
        debugPrint = oldPrint;
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  }
}
