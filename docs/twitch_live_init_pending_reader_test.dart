import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  for (final scenario in ['initial-map', 'partial-fragment', 'changed-map']) {
    test('New HTTP reader during $scenario receives aligned media', () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gateReached = Completer<void>();
      final release = Completer<void>();
      var latest = 3;
      var version = 1;
      final initialization = [0, 0, 0, 9, ...'ftyp'.codeUnits, 1];
      List<int> fragment(int sequence) => [
        0,
        0,
        0,
        9,
        ...'moof'.codeUnits,
        sequence,
      ];
      final serving = upstream.listen((request) async {
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
        } else if (path.startsWith('/init')) {
          final requestedVersion = int.parse(
            RegExp(r'\d+').firstMatch(path)!.group(0)!,
          );
          if ((scenario == 'initial-map' && requestedVersion == 1) ||
              (scenario == 'changed-map' && requestedVersion == 2)) {
            if (!gateReached.isCompleted) gateReached.complete();
            await release.future;
          }
          request.response.add([...initialization.take(8), requestedVersion]);
        } else {
          final sequence = int.parse(
            RegExp(r'\d+').firstMatch(path)!.group(0)!,
          );
          final bytes = fragment(sequence);
          if (scenario == 'partial-fragment' && sequence == 3) {
            request.response.bufferOutput = false;
            request.response.add(bytes.take(4).toList());
            await request.response.flush();
            if (!gateReached.isCompleted) gateReached.complete();
            await release.future;
            request.response.add(bytes.skip(4).toList());
          } else {
            request.response.add(bytes);
          }
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
      final client = HttpClient();
      Future<void> waitFor(FutureOr<bool> Function() condition) async {
        final clock = Stopwatch()..start();
        while (!await condition()) {
          if (clock.elapsed > const Duration(seconds: 5)) {
            fail('Fixture did not reach required gated state.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      final received = <int>[];
      Future<List<int>> readPrefix() async {
        final request = await client.getUrl(Uri.parse(proxy.streamTsUrl));
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        final iterator = StreamIterator<List<int>>(response);
        try {
          while (received.length < 18 &&
              await iterator.moveNext().timeout(const Duration(seconds: 3))) {
            received.addAll(iterator.current);
          }
        } finally {
          await iterator.cancel();
        }
        return received.take(18).toList();
      }

      try {
        await proxy.start();
        if (scenario == 'changed-map') {
          await waitFor(
            () async =>
                ((await proxy.requestLiveStatus())?.lastWrittenSequence ??
                    -1) >=
                3,
          );
          version = 2;
          latest = 4;
        }
        await gateReached.future.timeout(const Duration(seconds: 5));
        if (scenario == 'partial-fragment') {
          await waitFor(
            () async => (await proxy.requestLiveStatus())?.bufferedBytes == 4,
          );
        }
        final reading = readPrefix();
        // Observe errors immediately, even while waiting for the fixture gate.
        unawaited(
          reading.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        );
        await waitFor(
          () async => (await proxy.requestLiveStatus())?.activeClientCount == 1,
        );
        if (scenario == 'changed-map') {
          // A pending replacement map must not discard the previous playable
          // fragment while leaving its initialization as the only replay.
          expect(await reading, [...initialization, ...fragment(3)]);
          expect(release.isCompleted, isFalse);
          release.complete();
          await waitFor(
            () async =>
                ((await proxy.requestLiveStatus())?.lastWrittenSequence ??
                    -1) >=
                4,
          );
          received.clear();
          expect(await readPrefix(), [
            ...initialization.take(8),
            2,
            ...fragment(4),
          ]);
        } else if (scenario == 'partial-fragment') {
          await waitFor(() => received.length >= 13);
          expect(received, [...initialization, ...fragment(3).take(4)]);
          release.complete();
          expect(await reading, [...initialization, ...fragment(3)]);
        } else {
          expect(received, isEmpty);
          release.complete();
          expect(await reading, [...initialization, ...fragment(3)]);
        }
      } finally {
        if (!release.isCompleted) release.complete();
        client.close(force: true);
        await proxy.close();
        await upstream.close(force: true);
        await serving.cancel();
      }
    });
  }
}
