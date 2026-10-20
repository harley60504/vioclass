import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  for (final scenario in [
    'empty-map',
    'empty-map-close',
    'failed-map-recover',
    'failed-map-close',
  ]) {
    test('Initialization failure flow: $scenario', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var version = 1;
      var latest = 3;
      var replacementRequests = 0;
      var firstMapRequests = 0;
      var replacementHealthy = false;
      final initialization = [0, 0, 0, 9, ...'ftyp'.codeUnits];
      List<int> fragment(int sequence) => [
        0,
        0,
        0,
        9,
        ...'moof'.codeUnits,
        sequence,
      ];
      final serving = server.listen((request) async {
        final path = request.uri.path;
        if (path == '/live.m3u8') {
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:1\n'
            '#EXT-X-MEDIA-SEQUENCE:${latest - 2}\n'
            '#EXT-X-MAP:URI="/init$version.mp4"\n',
          );
          for (var sequence = latest - 2; sequence <= latest; sequence++) {
            request.response.write('#EXTINF:1.0,\n/segment$sequence.m4s\n');
          }
        } else if (path == '/init1.mp4') {
          firstMapRequests++;
          if (!scenario.startsWith('empty-map') ||
              (scenario == 'empty-map' && firstMapRequests > 1)) {
            request.response.add([...initialization, 1]);
          } // First empty-map response is HTTP 200 with an empty body.
        } else if (path == '/init2.mp4') {
          replacementRequests++;
          if (replacementHealthy) {
            request.response.add([...initialization, 2]);
          } else {
            request.response.statusCode = HttpStatus.serviceUnavailable;
          }
        } else {
          final sequence = int.parse(
            RegExp(r'\d+').firstMatch(path)!.group(0)!,
          );
          request.response.add(fragment(sequence));
        }
        await request.response.close();
      });
      final proxy = TwitchDartHlsLowLatencyProxy(
        upstreamPlaylistUrl: 'http://127.0.0.1:${server.port}/live.m3u8',
        upstreamHeaders: const {},
        outputFutureSegments: false,
        prefetchSegmentCount: 0,
        startupMode: TwitchHlsStartupMode.latestNormalImmediate,
        minPlaylistReloadDelay: const Duration(milliseconds: 20),
        maxPlaylistReloadDelay: const Duration(milliseconds: 40),
      );
      final client = HttpClient();
      StreamSubscription<List<int>>? reader;
      final bytes = <int>[];
      final ended = Completer<void>();
      Object? readerError;
      Future<void> waitFor(FutureOr<bool> Function() ready) async {
        final clock = Stopwatch()..start();
        while (!await ready()) {
          if (clock.elapsed > const Duration(seconds: 7)) {
            fail('Initialization fixture did not reach required state.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      Future<void> attach() async {
        final response = await (await client.getUrl(
          Uri.parse(proxy.streamTsUrl),
        )).close().timeout(const Duration(seconds: 3));
        expect(response.statusCode, HttpStatus.ok);
        reader = response.listen(
          bytes.addAll,
          onDone: () {
            if (!ended.isCompleted) ended.complete();
          },
          onError: (Object error, StackTrace stack) {
            readerError = error;
            if (!ended.isCompleted) ended.complete();
          },
        );
      }

      try {
        await proxy.start();
        if (scenario == 'empty-map-close') {
          final attaching = attach().catchError((Object error) {
            readerError = error;
            if (!ended.isCompleted) ended.complete();
          });
          await waitFor(
            () async =>
                firstMapRequests >= 3 &&
                (await proxy.requestLiveStatus())?.activeClientCount == 1,
          );
          expect(bytes, isEmpty);
          expect((await proxy.requestLiveStatus())?.lastWrittenSequence, -1);
          await proxy.close();
          await attaching.timeout(const Duration(seconds: 2));
          await ended.future.timeout(const Duration(seconds: 2));
          expect(bytes, isEmpty);
          expect(readerError, anyOf(isNull, isA<HttpException>()));
        } else if (scenario == 'empty-map') {
          await attach();
          await waitFor(() => bytes.length >= 9);
          expect(bytes.take(9), [...initialization, 1]);
          await waitFor(() => bytes.length >= 18);
          expect(bytes.take(18), [...initialization, 1, ...fragment(3)]);
          expect(firstMapRequests, greaterThanOrEqualTo(2));
        } else {
          await waitFor(
            () async =>
                ((await proxy.requestLiveStatus())?.lastWrittenSequence ??
                    -1) >=
                3,
          );
          await attach();
          await waitFor(() => bytes.length >= 18);
          version = 2;
          latest = 4;
          // Exceed one full 14-attempt HTTP retry cycle, without new media.
          await waitFor(() => replacementRequests >= 15);
          expect(bytes, [...initialization, 1, ...fragment(3)]);
          expect(ended.isCompleted, isFalse);
          if (scenario == 'failed-map-close') {
            await proxy.close();
            await ended.future.timeout(const Duration(seconds: 2));
            expect(readerError, anyOf(isNull, isA<HttpException>()));
          } else {
            replacementHealthy = true;
            await waitFor(() => bytes.length >= 36);
            expect(bytes.take(36), [
              ...initialization,
              1,
              ...fragment(3),
              ...initialization,
              2,
              ...fragment(4),
            ]);
            expect(readerError, isNull);
          }
        }
      } finally {
        await reader?.cancel();
        client.close(force: true);
        await proxy.close();
        await server.close(force: true);
        await serving.cancel();
      }
    });
  }
}
