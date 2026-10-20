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
    ]) {
      final prefixLength = scenario.$1;
      final fallback = scenario.$2;
      final rejected = fallback != 'valid';
      test('Partial $format prefix=$prefixLength fallback=$fallback', () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final cut = Completer<void>();
        final releasePlaylist = Completer<void>();
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
            final replacement = fallback == 'short'
                ? fragment.take(prefixLength - 1).toList()
                : fragment.toList();
            if (fallback == 'changed') replacement[0] ^= 1;
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
                ? (segmentRequests == 2 && status?.hasWriter == false)
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
          expect(segmentRequests, 2);
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
          expect(segmentRequests, 2);
          expect(bytes, [...init, ...fragment]);
        } finally {
          if (!cut.isCompleted) cut.complete();
          if (!releasePlaylist.isCompleted) releasePlaylist.complete();
          client.close(force: true);
          await proxy.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      });
    }
  }
}
