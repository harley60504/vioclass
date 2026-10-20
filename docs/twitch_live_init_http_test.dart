import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  for (final failures in [0, 2, 14]) {
    test(
      'Real proxy init reconnects after $failures map HTTP failures',
      () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var latest = 3;
        var mapVersion = 1;
        var useInitialization = true;
        var mapRequests = 0;
        var mapFailuresRemaining = 0;
        final initialization = <int>[0, 0, 0, 9, ...'ftyp'.codeUnits, 1];
        final client = HttpClient();
        final serving = upstream.listen((request) async {
          final path = request.uri.path;
          if (path == '/live.m3u8') {
            request.response.write(
              '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:${latest - 2}\n',
            );
            if (useInitialization) {
              request.response.write('#EXT-X-MAP:URI="/init$mapVersion.mp4"\n');
            }
            for (var index = latest - 2; index <= latest; index++) {
              final extension = useInitialization ? 'm4s' : 'ts';
              request.response.write(
                '#EXTINF:1.0,\n/segment$index.$extension\n',
              );
            }
          } else if (path.startsWith('/init')) {
            mapRequests++;
            if (mapFailuresRemaining > 0) {
              mapFailuresRemaining--;
              request.response.statusCode = HttpStatus.serviceUnavailable;
              await request.response.close();
              return;
            }
            request.response.add([...initialization.take(8), mapVersion]);
          } else {
            final sequence = int.parse(
              RegExp(r'\d+').firstMatch(path)!.group(0)!,
            );
            request.response.add(
              path.endsWith('.ts')
                  ? [0x47, sequence, ...List<int>.filled(16, 0)]
                  : [0, 0, 0, 9, ...'moof'.codeUnits, sequence],
            );
          }
          await request.response.close();
        });
        final proxy = TwitchDartHlsLowLatencyProxy(
          upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/live.m3u8',
          upstreamHeaders: const {},
          outputFutureSegments: false,
          prefetchSegmentCount: 0,
          startupMode: TwitchHlsStartupMode.latestNormalImmediate,
          minPlaylistReloadDelay: const Duration(milliseconds: 20),
          maxPlaylistReloadDelay: const Duration(milliseconds: 40),
        );
        Future<void> written(int sequence) async {
          final clock = Stopwatch()..start();
          while (clock.elapsed < const Duration(seconds: 8)) {
            final status = await proxy.requestLiveStatus();
            if ((status?.lastWrittenSequence ?? -1) >= sequence) return;
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          fail('Fixture writer did not reach the required segment.');
        }

        Future<List<int>> readPrefix() async {
          final request = await client.getUrl(Uri.parse(proxy.streamTsUrl));
          final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
          expect(response.statusCode, HttpStatus.ok);
          final iterator = StreamIterator<List<int>>(response);
          final bytes = <int>[];
          try {
            while (bytes.length < 18 &&
                await iterator.moveNext().timeout(const Duration(seconds: 5))) {
              bytes.addAll(iterator.current);
            }
          } finally {
            await iterator.cancel();
          }
          return bytes.take(18).toList();
        }

        try {
          await proxy.start();
          await written(3);
          latest = 4;
          await written(
            4,
          ); // Map was first sent before any HTTP reader existed.
          expect(await readPrefix(), [
            ...initialization,
            0,
            0,
            0,
            9,
            ...'moof'.codeUnits,
            4,
          ]);
          latest = 5;
          await written(5);
          expect(await readPrefix(), [
            ...initialization,
            0,
            0,
            0,
            9,
            ...'moof'.codeUnits,
            5,
          ]);
          expect(mapRequests, 1);
          mapVersion = 2;
          mapFailuresRemaining = failures;
          latest = 6;
          await written(6);
          expect(await readPrefix(), [
            ...initialization.take(8),
            2,
            0,
            0,
            0,
            9,
            ...'moof'.codeUnits,
            6,
          ]);
          expect(mapRequests, 2 + failures);
          useInitialization = false;
          latest = 7;
          await written(7);
          expect(await readPrefix(), [0x47, 7, ...List<int>.filled(16, 0)]);
          expect(mapRequests, 2 + failures);

          // Returning to the same map must restore init even if it is cached.
          useInitialization = true;
          latest = 8;
          await written(8);
          expect(await readPrefix(), [
            ...initialization.take(8),
            2,
            0,
            0,
            0,
            9,
            ...'moof'.codeUnits,
            8,
          ]);
        } finally {
          client.close(force: true);
          await proxy.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      },
    );
  }
}
