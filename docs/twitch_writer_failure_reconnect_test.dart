import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  test('Explicit upstream switch retains the stable reader', () async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serving = upstream.listen((request) async {
      final second = request.uri.path.startsWith('/b/');
      if (request.uri.path.endsWith('.m3u8')) {
        request.response.write(
          '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
          '#EXTINF:1.0,\n/${second ? 'b' : 'a'}/segment.ts\n',
        );
      } else {
        request.response.add([
          0x47,
          second ? 2 : 1,
          ...List<int>.filled(16, 0),
        ]);
      }
      await request.response.close();
    });
    final router = TwitchStableHlsProxyRouter(
      upstreamHeaders: const {},
      outputFutureSegments: false,
      prefetchSegmentCount: 0,
      startupMode: TwitchHlsStartupMode.latestNormalImmediate,
    );
    final client = HttpClient();
    StreamIterator<List<int>>? reader;
    try {
      await router.start(
        upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/a/live.m3u8',
      );
      final response = await (await client.getUrl(
        Uri.parse(router.streamTsUrl),
      )).close();
      reader = StreamIterator(response);
      expect(
        await reader.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(reader.current, [0x47, 1, ...List<int>.filled(16, 0)]);
      await router.switchUpstream(
        'http://127.0.0.1:${upstream.port}/b/live.m3u8',
      );
      expect(
        await reader.moveNext().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      expect(reader.current, [0x47, 2, ...List<int>.filled(16, 0)]);
    } finally {
      client.close(force: true);
      await reader?.cancel();
      await router.close();
      await upstream.close(force: true);
      await serving.cancel();
    }
  });
  for (final routed in [false, true]) {
    for (final short in [false, true]) {
      test(
        'Rejected retry ends old reader and reconnects cleanly short=$short routed=$routed',
        () async {
          final upstream = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final releaseInit = Completer<void>();
          final releaseReload = Completer<void>();
          final init = [0, 0, 0, 8, ...'ftyp'.codeUnits];
          final fragment = [
            0,
            0,
            0,
            16,
            ...'moof'.codeUnits,
            ...List<int>.filled(8, 1),
          ];
          var playlists = 0;
          var segments = 0;
          final serving = upstream.listen((request) async {
            if (request.uri.path == '/live.m3u8') {
              if (++playlists > 1) await releaseReload.future;
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
                '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1.0,\n/segment.m4s\n',
              );
            } else if (request.uri.path == '/init.mp4') {
              await releaseInit.future;
              request.response.add(init);
            } else {
              segments++;
              if (segments == 1) {
                request.response.contentLength = fragment.length;
                final socket = await request.response.detachSocket();
                socket.add(fragment.take(10).toList());
                await socket.flush();
                socket.destroy();
                return;
              }
              final body = segments == 2
                  ? (short
                        ? fragment.take(9).toList()
                        : (fragment.toList()..[0] = 1))
                  : fragment;
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
          );
          final client = HttpClient();
          final router = routed
              ? TwitchStableHlsProxyRouter(
                  upstreamHeaders: const {},
                  outputFutureSegments: false,
                  prefetchSegmentCount: 1,
                  startupMode: TwitchHlsStartupMode.latestNormalImmediate,
                )
              : null;
          final upstreamUrl = 'http://127.0.0.1:${upstream.port}/live.m3u8';
          StreamIterator<List<int>>? oldReader;
          try {
            if (router != null) {
              await router.start(upstreamPlaylistUrl: upstreamUrl);
            } else {
              await proxy.start();
            }
            final streamUrl = router?.streamTsUrl ?? proxy.streamTsUrl;
            final pending = (await client.getUrl(Uri.parse(streamUrl))).close();
            final clock = Stopwatch()..start();
            while ((await (router?.requestLiveStatus() ??
                        proxy.requestLiveStatus()))
                    ?.activeClientCount !=
                1) {
              if (clock.elapsed > const Duration(seconds: 3)) {
                fail('Reader did not attach.');
              }
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
            releaseInit.complete();
            oldReader = StreamIterator(
              await pending.timeout(const Duration(seconds: 3)),
            );
            final oldBytes = <int>[];
            while (oldBytes.length < init.length + 10 &&
                await oldReader.moveNext()) {
              oldBytes.addAll(oldReader.current);
            }
            expect(oldBytes, [...init, ...fragment.take(10)]);
            expect(
              await oldReader.moveNext().timeout(const Duration(seconds: 2)),
              isFalse,
              reason:
                  'A reader with an unrecoverable partial segment must not wait forever.',
            );
            expect(segments, 2);
            releaseReload.complete();
            final response = await (await client.getUrl(
              Uri.parse(streamUrl),
            )).close().timeout(const Duration(seconds: 3));
            final fresh = StreamIterator<List<int>>(response);
            final freshBytes = <int>[];
            try {
              while (freshBytes.length < init.length + fragment.length &&
                  await fresh.moveNext().timeout(const Duration(seconds: 3))) {
                freshBytes.addAll(fresh.current);
              }
            } finally {
              await fresh.cancel();
            }
            expect(freshBytes, [...init, ...fragment]);
            expect(segments, 3);
          } finally {
            if (!releaseInit.isCompleted) releaseInit.complete();
            if (!releaseReload.isCompleted) releaseReload.complete();
            client.close(force: true);
            await oldReader?.cancel();
            await router?.close();
            await proxy.close();
            await upstream.close(force: true);
            await serving.cancel();
          }
        },
      );
    }
  }
}
