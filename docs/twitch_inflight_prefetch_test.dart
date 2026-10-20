import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_hls_proxy_models.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  for (final format in ['mp4', 'ts']) {
    for (final reject in [false, true]) {
      test(
        'Playlist reload does not prefetch claimed $format reject=$reject',
        () async {
          final upstream = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final cut = Completer<void>();
          final fallbackOpened = Completer<void>();
          final releaseFallback = Completer<void>();
          var segmentRequests = 0;
          final fragment = format == 'mp4'
              ? [0, 0, 0, 16, ...'moof'.codeUnits, ...List<int>.filled(8, 1)]
              : [0x47, ...List<int>.filled(187, 1)];
          final serving = upstream.listen((request) async {
            if (request.uri.path == '/live.m3u8') {
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
                '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1.0,\n/segment\n',
              );
            } else if (request.uri.path == '/init.mp4') {
              await cut.future;
              request.response.add([0, 0, 0, 8, ...'ftyp'.codeUnits]);
            } else {
              segmentRequests++;
              request.response.contentLength = fragment.length;
              if (segmentRequests == 1) {
                final socket = await request.response.detachSocket();
                socket.add(fragment.take(10).toList());
                await socket.flush();
                socket.destroy();
                cut.complete();
                return;
              }
              if (segmentRequests == 2) {
                fallbackOpened.complete();
                await releaseFallback.future;
              }
              final body = fragment.toList();
              if (reject && segmentRequests == 2) body[0] ^= 1;
              request.response.add(body);
            }
            await request.response.close();
          });
          final proxy = TwitchDartHlsLowLatencyProxy(
            upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/live.m3u8',
            upstreamHeaders: const {},
            outputFutureSegments: false,
            prefetchSegmentCount: 1,
            startupMode: TwitchHlsStartupMode.latestNormalImmediate,
            minPlaylistReloadDelay: const Duration(milliseconds: 20),
            maxPlaylistReloadDelay: const Duration(milliseconds: 40),
          );
          Future<void> waitStatus(
            bool Function(TwitchHlsLiveStatus?) ready,
          ) async {
            final clock = Stopwatch()..start();
            while (clock.elapsed < const Duration(seconds: 5)) {
              if (ready(await proxy.requestLiveStatus())) return;
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }
            fail('Fixture did not reach the required writer stage.');
          }

          try {
            await proxy.start();
            await fallbackOpened.future.timeout(const Duration(seconds: 5));
            final version = (await proxy.requestLiveStatus())!.playlistVersion;
            await waitStatus(
              (status) => (status?.playlistVersion ?? 0) >= version + 3,
            );
            expect(
              segmentRequests,
              2,
              reason: 'Writer owns the consumed prefetch during fallback.',
            );
            releaseFallback.complete();
            await waitStatus(
              (status) => reject
                  ? status?.running == false
                  : status?.lastWrittenSequence == 0,
            );
            expect(segmentRequests, 2);
          } finally {
            if (!cut.isCompleted) cut.complete();
            if (!releaseFallback.isCompleted) releaseFallback.complete();
            await proxy.close();
            await upstream.close(force: true);
            await serving.cancel();
          }
        },
      );
    }
  }
}
