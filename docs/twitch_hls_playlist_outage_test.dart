import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  test(
    'Playlist socket outage retains the reader and resumes after recovery',
    () async {
      final segments = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final segmentRequests = segments.listen((request) async {
        request.response.add(List<int>.filled(188, 0x47));
        await request.response.close();
      });
      var sequence = 0;
      var outage = false;
      Future<HttpServer> playlistServer(int port) async {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        server.listen((request) async {
          if (outage) {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            await request.response.close();
            return;
          }
          final current = ++sequence;
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:2\n'
            '#EXT-X-MEDIA-SEQUENCE:$current\n#EXTINF:2,\n'
            'http://127.0.0.1:${segments.port}/$current.ts\n',
          );
          await request.response.close();
        });
        return server;
      }

      var playlists = await playlistServer(0);
      final port = playlists.port;
      final logs = <String>[];
      final proxy = TwitchDartHlsLowLatencyProxy(
        upstreamPlaylistUrl: 'http://127.0.0.1:$port/live.m3u8',
        upstreamHeaders: const {},
        outputFutureSegments: false,
        prefetchSegmentCount: 0,
        onLog: logs.add,
      );
      final client = HttpClient();
      StreamSubscription<List<int>>? reader;
      var bytes = 0;
      var closed = false;
      addTearDown(() async {
        await reader?.cancel();
        client.close(force: true);
        await proxy.close();
        await playlists.close(force: true);
        await segmentRequests.cancel();
        await segments.close(force: true);
      });
      await proxy.start();
      final response = await (await client.getUrl(
        Uri.parse(proxy.streamTsUrl),
      )).close();
      reader = response.listen(
        (chunk) => bytes += chunk.length,
        onDone: () => closed = true,
      );
      Future<void> waitFor(bool Function() ready) async {
        final deadline = DateTime.now().add(const Duration(seconds: 8));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(ready(), isTrue);
      }

      await waitFor(() => bytes > 0);
      outage = true;
      await Future<void>.delayed(const Duration(seconds: 10));
      final duringOutage = await proxy.requestLiveStatus();
      expect(
        duringOutage?.running,
        isTrue,
        reason: 'Metadata failure must not close media',
      );
      expect(closed, isFalse);
      final before = bytes;
      outage = false;
      await waitFor(() => bytes > before);
      expect(closed, isFalse);
      expect(logs.any((line) => line.contains('playlist-recovered')), isTrue);
    },
  );
}
