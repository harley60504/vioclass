import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'twitch_replay_window_probe.dart';

void main() {
  for (final format in [
    'fmp4',
    'mpegts',
    'unknown',
    'http-failure',
    'no-media',
  ]) {
    test('Format probe is bounded and sanitized $format', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var mediaRequests = 0;
      final serving = server.listen((request) async {
        if (request.uri.path == '/playlist') {
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:2\n'
            '${format == 'fmp4' ? '#EXT-X-MAP:URI="/SECRET-init"\n' : ''}'
            '${format == 'no-media' ? '' : '#EXTINF:2,\n/media?token=SECRET\n'}',
          );
        } else {
          mediaRequests++;
          expect(request.headers.value('Range'), 'bytes=0-4095');
          request.response.statusCode = format == 'http-failure' ? 403 : 200;
          final bytes = List<int>.filled(8192, 0);
          if (format == 'fmp4') bytes.setRange(4, 8, 'moof'.codeUnits);
          if (format == 'mpegts') bytes[0] = bytes[188] = bytes[376] = 0x47;
          request.response.add(bytes);
        }
        await request.response.close();
      });
      try {
        final result = await probeLiveVariantFormat(
          Uri.parse('http://127.0.0.1:${server.port}/playlist'),
        );
        expect(result['format'], format);
        expect(mediaRequests, format == 'no-media' ? 0 : 1);
        if (format != 'no-media') expect(result['bytes'], 4096);
        expect(result.toString(), isNot(contains('SECRET')));
        expect(result.toString(), isNot(contains('127.0.0.1')));
      } finally {
        await server.close(force: true);
        await serving.cancel();
      }
    });
  }
}
