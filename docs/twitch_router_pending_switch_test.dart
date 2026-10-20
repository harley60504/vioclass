import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  for (final action in ['direct', 'hls', 'close', 'dvrInterrupt']) {
    test(
      'Pending HLS switch cannot overwrite newer state action=$action',
      () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requested = Completer<void>();
        final release = Completer<void>();
        final serving = upstream.listen((request) async {
          if (request.uri.path.endsWith('.m3u8')) {
            if (request.uri.path == '/slow.m3u8' && !requested.isCompleted) {
              requested.complete();
              await release.future;
            }
            final prefix = request.uri.path == '/fast.m3u8' ? 'new' : '';
            request.response.write(
              '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
              '#EXT-X-MAP:URI="/${prefix}init.mp4"\n'
              '#EXTINF:1,\n/${prefix}one.m4s\n#EXTINF:1,\n/${prefix}two.m4s\n',
            );
          } else if (request.uri.path.endsWith('init.mp4')) {
            request.response.add([
              0,
              0,
              0,
              9,
              ...'ftyp'.codeUnits,
              request.uri.path.startsWith('/new') ? 2 : 1,
            ]);
          } else if (request.uri.path.endsWith('.m4s')) {
            request.response.add([
              0,
              0,
              0,
              9,
              ...'moof'.codeUnits,
              request.uri.path.startsWith('/new') ? 2 : 1,
            ]);
          } else {
            request.response.add([4, 5, 6]);
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
        Future<void>? pending;
        try {
          final fastUrl = 'http://127.0.0.1:${upstream.port}/fast.m3u8';
          if (action == 'dvrInterrupt') {
            await router.start(upstreamPlaylistUrl: fastUrl);
          } else {
            await router.startDirectStream(
              streamUrl: 'http://127.0.0.1:${upstream.port}/initial',
            );
          }
          pending = router.switchUpstream(
            'http://127.0.0.1:${upstream.port}/slow.m3u8',
          );
          await requested.future.timeout(const Duration(seconds: 3));
          if (action == 'close') {
            await router.close();
          } else if (action == 'dvrInterrupt') {
            await router.interruptPlaybackStream();
          } else if (action == 'hls') {
            await router.switchUpstream(fastUrl);
          } else {
            await router.switchDirectStream(
              'http://127.0.0.1:${upstream.port}/new',
            );
          }
          release.complete();
          await pending.timeout(const Duration(seconds: 10));
          final keepsHls = action == 'hls' || action == 'dvrInterrupt';
          expect(router.upstreamPlaylistUrl, keepsHls ? fastUrl : null);
          expect(router.hasInnerProxy, keepsHls);
          expect(router.isRunning, action != 'close');
          if (action == 'dvrInterrupt') {
            final health = await (await client.getUrl(
              Uri.parse(router.streamTsUrl).resolve('/health'),
            )).close();
            final text = await health
                .transform(const SystemEncoding().decoder)
                .join();
            expect(text.split('\n'), contains('switching=false'));
          }
          if (action == 'direct') {
            final response = await (await client.getUrl(
              Uri.parse(router.streamTsUrl),
            )).close();
            expect(
              await response
                  .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
                  .timeout(const Duration(seconds: 3)),
              [4, 5, 6],
            );
          } else if (keepsHls) {
            final response = await (await client.getUrl(
              Uri.parse(router.streamTsUrl),
            )).close();
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
                2,
                0,
                0,
                0,
                9,
                ...'moof'.codeUnits,
                2,
              ]);
            } finally {
              await iterator.cancel();
            }
          }
        } finally {
          if (!release.isCompleted) release.complete();
          if (pending != null) await pending;
          client.close(force: true);
          await router.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      },
    );
  }
}
