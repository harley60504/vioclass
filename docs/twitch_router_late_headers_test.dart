import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  for (final newReaderFirst in [false, true]) {
    test(
      'Direct source switch rejects late headers newReaderFirst=$newReaderFirst',
      () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final oldRequested = Completer<void>();
        final releaseOld = Completer<void>();
        final serving = upstream.listen((request) async {
          if (request.uri.path == '/old') {
            oldRequested.complete();
            await releaseOld.future;
            request.response.add([1, 2, 3]);
          } else {
            request.response.add([4, 5, 6]);
          }
          try {
            await request.response.close();
          } catch (_) {
            // Cancellation of the obsolete local response is expected.
          }
        });
        final router = TwitchStableHlsProxyRouter(upstreamHeaders: const {});
        final client = HttpClient();
        Future<List<int>> read() async {
          final response = await (await client.getUrl(
            Uri.parse(router.streamTsUrl),
          )).close();
          return response.fold<List<int>>(
            [],
            (all, chunk) => all..addAll(chunk),
          );
        }

        try {
          await router.startDirectStream(
            streamUrl: 'http://127.0.0.1:${upstream.port}/old',
          );
          final oldRead = read();
          await oldRequested.future.timeout(const Duration(seconds: 3));
          await router.switchDirectStream(
            'http://127.0.0.1:${upstream.port}/new',
          );
          if (newReaderFirst) {
            expect(await read().timeout(const Duration(seconds: 3)), [4, 5, 6]);
          }
          releaseOld.complete();
          expect(await oldRead.timeout(const Duration(seconds: 3)), isEmpty);
          if (!newReaderFirst) {
            expect(await read().timeout(const Duration(seconds: 3)), [4, 5, 6]);
          }
          expect(router.streamReadDiagnostics['receivedBytes'], 3);
          expect(router.streamReadDiagnostics['attachments'], 1);
          expect(router.streamReadDiagnostics['pumpFailures'], 0);
        } finally {
          if (!releaseOld.isCompleted) releaseOld.complete();
          client.close(force: true);
          await router.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      },
    );
  }
}
