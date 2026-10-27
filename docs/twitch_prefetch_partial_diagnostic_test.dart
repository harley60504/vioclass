import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

// Structural transport diagnosis only: these boxes are not decodable media.
void main() {
  for (final format in ['mp4', 'ts', 'real-mp4']) {
    for (final scenario in [
      (0, 'valid'),
      (1, 'valid'),
      (7, 'valid'),
      (10, 'valid'),
      (15, 'valid'),
      (10, 'changed'),
      (10, 'short'),
      (10, 'unavailable'),
      (10, 'interrupted'),
      (10, 'recovered'),
      (10, 'recovered-twice'),
      (10, 'changed-after-interrupt'),
      (10, 'short-after-interrupt'),
      if (format == 'mp4') (10, 'stalled'),
    ]) {
      final prefixLength = scenario.$1;
      final fallback = scenario.$2;
      final rejected = ![
        'valid',
        'recovered',
        'recovered-twice',
        'stalled',
      ].contains(fallback);
      final expectedRequests = switch (fallback) {
        'unavailable' => 15,
        'interrupted' || 'recovered-twice' => 4,
        'recovered' ||
        'stalled' ||
        'changed-after-interrupt' ||
        'short-after-interrupt' => 3,
        _ => 2,
      };
      test('Partial $format prefix=$prefixLength fallback=$fallback', () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final cut = Completer<void>();
        final releasePlaylist = Completer<void>();
        final releaseStalled = Completer<void>();
        var playlistRequests = 0;
        var init = [0, 0, 0, 8, ...'ftyp'.codeUnits];
        var fragment = format == 'ts'
            ? [0x47, ...List<int>.generate(563, (i) => i % 256)]
            : [0, 0, 0, 16, ...'moof'.codeUnits, ...List<int>.filled(8, 1)];
        if (format == 'real-mp4') {
          final media = await File(
            'docs/twitch-decoder-fixture.mp4',
          ).readAsBytes();
          var offset = 0;
          while (String.fromCharCodes(media.sublist(offset + 4, offset + 8)) !=
              'moof') {
            offset +=
                (media[offset] << 24) |
                (media[offset + 1] << 16) |
                (media[offset + 2] << 8) |
                media[offset + 3];
          }
          init = media.sublist(0, offset);
          fragment = media.sublist(offset);
        }
        var segmentRequests = 0;
        final serving = upstream.listen((request) async {
          if (request.uri.path == '/live.m3u8') {
            playlistRequests++;
            if (playlistRequests > 1) await releasePlaylist.future;
            request.response.write(
              '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
              '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1.0,\n/segment.m4s\n',
            );
          } else if (request.uri.path == '/init.mp4') {
            await cut.future;
            request.response.add(init);
          } else {
            segmentRequests++;
            if (segmentRequests == 1) {
              request.response.contentLength = fragment.length;
              final socket = await request.response.detachSocket();
              final split = prefixLength ~/ 2;
              socket.add(fragment.take(split).toList());
              await socket.flush();
              await Future<void>.delayed(const Duration(milliseconds: 10));
              socket.add(
                fragment.skip(split).take(prefixLength - split).toList(),
              );
              await socket.flush();
              socket.destroy();
              cut.complete();
              return;
            }
            if (fallback == 'unavailable') {
              request.response.statusCode = HttpStatus.serviceUnavailable;
              await request.response.close();
              return;
            }
            if (fallback == 'interrupted' ||
                (fallback != 'valid' &&
                    fallback != 'changed' &&
                    fallback != 'short' &&
                    segmentRequests == 2) ||
                (fallback == 'recovered-twice' && segmentRequests == 3)) {
              request.response.contentLength = fragment.length;
              final socket = await request.response.detachSocket();
              socket.add(
                fragment
                    .take(prefixLength + (segmentRequests == 3 ? 4 : 2))
                    .toList(),
              );
              await socket.flush();
              if (fallback == 'stalled') await releaseStalled.future;
              socket.destroy();
              return;
            }
            final replacement =
                fallback == 'short' || fallback == 'short-after-interrupt'
                ? fragment
                      .take(
                        fallback == 'short'
                            ? prefixLength - 1
                            : prefixLength + 1,
                      )
                      .toList()
                : fragment.toList();
            if (fallback == 'changed') replacement[0] ^= 1;
            if (fallback == 'changed-after-interrupt') {
              replacement[prefixLength + 1] ^= 1;
            }
            request.response.contentLength = replacement.length;
            // Exercise retry reads whose write boundaries differ from prefetch.
            request.response.add(replacement.take(3).toList());
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 10));
            request.response.add(replacement.skip(3).toList());
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
        try {
          await proxy.start();
          final clock = Stopwatch()..start();
          while (true) {
            final status = await proxy.requestLiveStatus();
            if (rejected
                ? (segmentRequests == expectedRequests &&
                      status?.hasWriter == false)
                : status?.lastWrittenSequence == 0) {
              if (rejected) {
                expect(status?.lastWrittenSequence, -1);
                expect(status?.outputDuration, Duration.zero);
                expect(status?.bufferedBytes, 0);
                expect(status?.running, isFalse);
              }
              break;
            }
            if (clock.elapsed > const Duration(seconds: 8)) {
              fail('Fixture writer did not finish fallback.');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          expect(segmentRequests, expectedRequests);
          if (rejected) return;
          final response = await (await client.getUrl(
            Uri.parse(proxy.streamTsUrl),
          )).close().timeout(const Duration(seconds: 5));
          final iterator = StreamIterator<List<int>>(response);
          final bytes = <int>[];
          try {
            while (bytes.length < init.length + fragment.length &&
                await iterator.moveNext().timeout(const Duration(seconds: 5))) {
              bytes.addAll(iterator.current);
            }
          } finally {
            await iterator.cancel();
          }
          expect(segmentRequests, expectedRequests);
          expect(bytes, [...init, ...fragment]);
        } finally {
          if (!cut.isCompleted) cut.complete();
          if (!releasePlaylist.isCompleted) releasePlaylist.complete();
          if (!releaseStalled.isCompleted) releaseStalled.complete();
          client.close(force: true);
          await proxy.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      });
    }
  }
}
