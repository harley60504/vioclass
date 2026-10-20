import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  for (final action in ['timeout', 'replace', 'close']) {
    test(
      'Unresponsive candidate does not seize playback action=$action',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requested = Completer<void>();
        final release = Completer<void>();
        final serving = server.listen((request) async {
          if (request.uri.path == '/pending.m3u8') {
            if (!requested.isCompleted) requested.complete();
            await release.future;
            request.response.write('#EXTM3U\n');
          } else {
            request.response.add(
              request.uri.path == '/new' ? [4, 5, 6] : [1, 2, 3],
            );
          }
          try {
            await request.response.close();
          } catch (_) {}
        });
        final router = TwitchStableHlsProxyRouter(upstreamHeaders: const {});
        final client = HttpClient();
        Object? failure;
        Future<void>? pending;
        try {
          await router.startDirectStream(
            streamUrl: 'http://127.0.0.1:${server.port}/original',
          );
          pending = router
              .switchUpstream('http://127.0.0.1:${server.port}/pending.m3u8')
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace _) {
                  failure = error;
                },
              );
          await requested.future.timeout(const Duration(seconds: 3));
          // Enter the readiness loop after best-effort prewarming, without
          // releasing the HTTP response or injecting a completion signal.
          await Future<void>.delayed(const Duration(seconds: 1));
          if (action == 'replace') {
            await router.switchDirectStream(
              'http://127.0.0.1:${server.port}/new',
            );
          } else if (action == 'close') {
            await router.close();
          }
          await pending.timeout(
            Duration(seconds: action == 'timeout' ? 11 : 2),
          );
          expect(release.isCompleted, isFalse);
          expect(
            failure,
            action == 'timeout' ? isA<TimeoutException>() : isNull,
          );
          expect(router.upstreamPlaylistUrl, isNull);
          expect(router.hasInnerProxy, isFalse);
          expect(router.isRunning, action != 'close');
          if (action != 'close') {
            final response = await (await client.getUrl(
              Uri.parse(router.streamTsUrl),
            )).close();
            expect(
              await response
                  .fold<List<int>>([], (all, chunk) => all..addAll(chunk))
                  .timeout(const Duration(seconds: 3)),
              action == 'replace' ? [4, 5, 6] : [1, 2, 3],
            );
          }
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
