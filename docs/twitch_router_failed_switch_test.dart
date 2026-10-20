import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  for (final eventuallySucceeds in [false, true]) {
    test(
      'HTTP startup waits for retry result succeeds=$eventuallySucceeds',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var failedRequests = 0;
        var unavailableResponses = 0;
        final serving = server.listen((request) async {
          if (request.uri.path == '/failed.m3u8') {
            failedRequests++;
            if (eventuallySucceeds && failedRequests > 6) {
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1,\n/one.m4s\n#EXTINF:1,\n/two.m4s\n',
              );
            } else {
              unavailableResponses++;
              request.response.statusCode = HttpStatus.serviceUnavailable;
            }
          } else if (request.uri.path == '/init.mp4') {
            request.response.add([0, 0, 0, 9, ...'ftyp'.codeUnits, 7]);
          } else if (request.uri.path.endsWith('.m4s')) {
            request.response.add([0, 0, 0, 9, ...'moof'.codeUnits, 7]);
          } else {
            request.response.add([1, 2, 3]);
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
        Object? failure;
        try {
          await router.startDirectStream(
            streamUrl: 'http://127.0.0.1:${server.port}/original',
          );
          try {
            await router
                .switchUpstream('http://127.0.0.1:${server.port}/failed.m3u8')
                .timeout(const Duration(seconds: 8));
          } catch (error) {
            failure = error;
          }
          expect(unavailableResponses, eventuallySucceeds ? 6 : 14);
          // Once a valid playlist is published, normal refreshes may already
          // have occurred. They are not additional failed startup attempts.
          expect(
            failedRequests,
            eventuallySucceeds ? greaterThanOrEqualTo(7) : 14,
          );
          expect(failure, eventuallySucceeds ? isNull : isA<StateError>());
          expect(
            router.upstreamPlaylistUrl,
            eventuallySucceeds
                ? 'http://127.0.0.1:${server.port}/failed.m3u8'
                : null,
          );
          expect(router.hasInnerProxy, eventuallySucceeds);
          final response = await (await client.getUrl(
            Uri.parse(router.streamTsUrl),
          )).close();
          if (eventuallySucceeds) {
            final iterator = StreamIterator<List<int>>(response);
            final bytes = <int>[];
            try {
              while (bytes.length < 18 &&
                  await iterator.moveNext().timeout(
                    const Duration(seconds: 3),
                  )) {
                bytes.addAll(iterator.current);
              }
              expect(bytes.take(18), [
                0,
                0,
                0,
                9,
                ...'ftyp'.codeUnits,
                7,
                0,
                0,
                0,
                9,
                ...'moof'.codeUnits,
                7,
              ]);
            } finally {
              await iterator.cancel();
            }
          } else {
            expect(
              await response
                  .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
                  .timeout(const Duration(seconds: 3)),
              [1, 2, 3],
            );
          }
        } finally {
          client.close(force: true);
          await router.close();
          await server.close(force: true);
          await serving.cancel();
        }
      },
    );
  }
  for (final originalHls in [false, true]) {
    for (final superseded in [false, true]) {
      test(
        'Failed playlist preserves usable source originalHls=$originalHls superseded=$superseded',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final requested = Completer<void>();
          final release = Completer<void>();
          final serving = server.listen((request) async {
            if (request.uri.path == '/broken.m3u8') {
              if (!requested.isCompleted) requested.complete();
              await release.future;
              // A real HTTP response with a malformed segment URI, not a forced
              // exception injected into the router.
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXTINF:1,\nhttp://[invalid\n',
              );
            } else if (request.uri.path == '/good.m3u8') {
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1,\n/one.m4s\n#EXTINF:1,\n/two.m4s\n',
              );
            } else if (request.uri.path == '/init.mp4') {
              request.response.add([0, 0, 0, 9, ...'ftyp'.codeUnits, 7]);
            } else if (request.uri.path.endsWith('.m4s')) {
              request.response.add([0, 0, 0, 9, ...'moof'.codeUnits, 7]);
            } else {
              request.response.add(
                request.uri.path == '/new' ? [4, 5, 6] : [1, 2, 3],
              );
            }
            try {
              await request.response.close();
            } catch (_) {}
          });
          final router = TwitchStableHlsProxyRouter(
            upstreamHeaders: const {},
            outputFutureSegments: false,
            prefetchSegmentCount: 0,
            startupMode: TwitchHlsStartupMode.latestNormalImmediate,
          );
          final client = HttpClient();
          Object? failure;
          Future<void>? pending;
          try {
            final originalUrl = 'http://127.0.0.1:${server.port}/good.m3u8';
            if (originalHls) {
              await router.start(upstreamPlaylistUrl: originalUrl);
            } else {
              await router.startDirectStream(
                streamUrl: 'http://127.0.0.1:${server.port}/original',
              );
            }
            pending = router
                .switchUpstream('http://127.0.0.1:${server.port}/broken.m3u8')
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace _) {
                    failure = error;
                  },
                );
            await requested.future.timeout(const Duration(seconds: 3));
            if (superseded) {
              await router.switchDirectStream(
                'http://127.0.0.1:${server.port}/new',
              );
            }
            release.complete();
            await pending.timeout(const Duration(seconds: 3));
            final restoredHls = originalHls && !superseded;
            expect(
              router.upstreamPlaylistUrl,
              restoredHls ? originalUrl : null,
            );
            expect(router.hasInnerProxy, restoredHls);
            final response = await (await client.getUrl(
              Uri.parse(router.streamTsUrl),
            )).close();
            expect(response.statusCode, HttpStatus.ok);
            if (restoredHls) {
              final iterator = StreamIterator<List<int>>(response);
              final bytes = <int>[];
              try {
                while (bytes.length < 18 &&
                    await iterator.moveNext().timeout(
                      const Duration(seconds: 3),
                    )) {
                  bytes.addAll(iterator.current);
                }
                expect(bytes.take(18), [
                  0,
                  0,
                  0,
                  9,
                  ...'ftyp'.codeUnits,
                  7,
                  0,
                  0,
                  0,
                  9,
                  ...'moof'.codeUnits,
                  7,
                ]);
                expect((await router.requestLiveStatus())?.running, isTrue);
              } finally {
                await iterator.cancel();
              }
            } else {
              expect(
                await response
                    .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
                    .timeout(const Duration(seconds: 3)),
                superseded ? [4, 5, 6] : [1, 2, 3],
              );
            }
            expect(failure, superseded ? isNull : isA<StateError>());
          } finally {
            if (!release.isCompleted) release.complete();
            if (pending != null) await pending;
            client.close(force: true);
            await router.close();
            await server.close(force: true);
            await serving.cancel();
          }
        },
      );
    }
  }
}
