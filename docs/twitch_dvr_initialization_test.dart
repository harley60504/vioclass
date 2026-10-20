// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/services/playback/twitch_live_dvr_bridge_proxy.dart';

// Synthetic loopback transport only; this does not prove native decoding.
void main() {
  for (final action in ['initial', 'reconnect', 'seek']) {
    test('DVR emits initialization before fragments on $action', () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final origin = 'http://127.0.0.1:${upstream.port}';
      final serving = upstream.listen((request) async {
        requests.add(request.uri.path);
        if (request.uri.path == '/index.m3u8') {
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:10\n'
            '#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-MAP:URI="init-a.mp4"\n'
            '#EXTINF:10,\n0.m4s\n#EXTINF:10,\n1.m4s\n'
            '#EXT-X-MAP:URI="init-b.mp4"\n#EXTINF:10,\n2.m4s\n',
          );
        } else {
          request.response.write(
            <String, String>{
              '/init-a.mp4': 'INIT-A;',
              '/init-b.mp4': 'INIT-B;',
              '/0.m4s': 'FRAGMENT-0;',
              '/1.m4s': 'FRAGMENT-1;',
              '/2.m4s': 'FRAGMENT-2;',
            }[request.uri.path],
          );
        }
        await request.response.close();
      });
      final proxy = TwitchLiveDvrBridgeProxy();
      final consumer = HttpClient();
      Future<void> read(String expected) async {
        final request = await consumer.getUrl(
          Uri.parse(proxy.streamTsPlaybackUrl),
        );
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length >= expected.length) break;
        }
        expect(utf8.decode(bytes), expected);
        proxy.stopStreaming();
      }

      try {
        await proxy.open(dvrPlaylistUri: Uri.parse('$origin/index.m3u8'));
        await proxy.seekToPosition(Duration.zero);
        const complete = 'INIT-A;FRAGMENT-0;FRAGMENT-1;INIT-B;FRAGMENT-2;';
        await read(complete);
        expect(requests.where((path) => path == '/init-a.mp4').length, 1);
        expect(requests.where((path) => path == '/init-b.mp4').length, 1);
        if (action == 'reconnect') {
          await read(complete);
          expect(requests.where((path) => path == '/init-a.mp4').length, 2);
          expect(requests.where((path) => path == '/init-b.mp4').length, 2);
        } else if (action == 'seek') {
          await proxy.seekToPosition(const Duration(seconds: 20));
          await read('INIT-B;FRAGMENT-2;');
          expect(requests.where((path) => path == '/init-a.mp4').length, 1);
          expect(requests.where((path) => path == '/init-b.mp4').length, 2);
        }
      } finally {
        consumer.close(force: true);
        await proxy.close();
        await serving.cancel();
        await upstream.close(force: true);
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  }
}
