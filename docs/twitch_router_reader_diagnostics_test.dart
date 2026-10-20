import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';

void main() {
  final cases = <String, List<int>>{
    'ftyp': [0, 0, 0, 12, ...'ftyp'.codeUnits, 1, 2, 3, 4],
    'moov': [0, 0, 0, 12, ...'moov'.codeUnits, 1, 2, 3, 4],
    'moof': [0, 0, 0, 12, ...'moof'.codeUnits, 1, 2, 3, 4],
    'styp': [0, 0, 0, 12, ...'styp'.codeUnits, 1, 2, 3, 4],
    'ts': [0x47, ...List<int>.filled(187, 0)],
    'unknown': [1, 2, 3, 4, 5, 6, 7, 8, 9],
    'short': [1, 2, 3],
  };
  for (final entry in cases.entries) {
    test(
      'Native reader diagnostics classify ${entry.key} without altering bytes',
      () async {
        final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var payload = entry.value;
        var upstreamRequests = 0;
        final serving = upstream.listen((request) async {
          upstreamRequests++;
          request.response.bufferOutput = false;
          request.response.add(payload.take(3).toList());
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          request.response.add(payload.skip(3).toList());
          await request.response.close();
        });
        final router = TwitchStableHlsProxyRouter(upstreamHeaders: const {});
        final client = HttpClient();
        Future<List<int>> read() async {
          final response = await (await client.getUrl(
            Uri.parse(router.streamTsUrl),
          )).close();
          expect(response.statusCode, HttpStatus.ok);
          return response
              .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk))
              .timeout(const Duration(seconds: 3));
        }

        try {
          await router.startDirectStream(
            streamUrl: 'http://127.0.0.1:${upstream.port}/fixture',
          );
          final head = await client.openUrl(
            'HEAD',
            Uri.parse(router.streamTsUrl),
          );
          await (await head.close()).drain<void>();
          expect(router.streamReadDiagnostics['requests'], 0);
          expect(router.streamReadDiagnostics['headRequests'], 1);
          expect(upstreamRequests, 0);
          expect(await read(), entry.value);
          final first = router.streamReadDiagnostics;
          expect(first['requests'], 1);
          expect(first['attachments'], 1);
          expect(first['receivedBytes'], entry.value.length);
          expect(first['flushedBytes'], entry.value.length);
          expect(first['upstreamStatus'], HttpStatus.ok);
          expect(first['flushPending'], false);
          expect(first['pumpFailures'], 0);
          expect(first['headerBytes'], entry.value.length.clamp(0, 8));
          expect(first['startsWithTsSync'], entry.key == 'ts');
          expect(
            first['startsWithMp4Init'],
            ['ftyp', 'moov'].contains(entry.key),
          );
          expect(
            first['startsWithMp4Fragment'],
            ['moof', 'styp'].contains(entry.key),
          );
          expect(
            first.values.every((value) => value is int || value is bool),
            true,
          );

          // New native GET resets per-reader counts and classification. A returned
          // snapshot must remain independent from subsequent connections.
          payload = [9, 8, 7];
          expect(await read(), payload);
          final second = router.streamReadDiagnostics;
          expect(second['requests'], 2);
          expect(second['headRequests'], 1);
          expect(second['attachments'], 1);
          expect(second['receivedBytes'], 3);
          expect(second['flushedBytes'], 3);
          expect(second['startsWithTsSync'], false);
          expect(second['startsWithMp4Init'], false);
          expect(second['startsWithMp4Fragment'], false);
          expect(first['requests'], 1);
          expect(first['receivedBytes'], entry.value.length);
        } finally {
          client.close(force: true);
          await router.close();
          await upstream.close(force: true);
          await serving.cancel();
        }
      },
    );
  }
}
