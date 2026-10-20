import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  test(
    'Stopped engine ignores a playlist response that arrives after fatal EOF',
    () async {
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final cut = Completer<void>();
      final fallbackReady = Completer<void>();
      final releaseFallback = Completer<void>();
      final latePollReady = Completer<void>();
      final releasePoll = Completer<void>();
      final unexpectedFetch = Completer<void>();
      var playlistRequests = 0;
      var segmentRequests = 0;
      final fragment = [
        0,
        0,
        0,
        16,
        ...'moof'.codeUnits,
        ...List<int>.filled(8, 1),
      ];
      final serving = upstream.listen((request) async {
        if (request.uri.path == '/live.m3u8') {
          playlistRequests++;
          if (playlistRequests == 2) {
            latePollReady.complete();
            await releasePoll.future;
          }
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:0\n'
            '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:1.0,\n/segment\n',
          );
        } else if (request.uri.path == '/init.mp4') {
          await cut.future;
          request.response.add([0, 0, 0, 8, ...'ftyp'.codeUnits]);
        } else {
          segmentRequests++;
          request.response.contentLength = fragment.length;
          if (segmentRequests == 1) {
            final socket = await request.response.detachSocket();
            socket.add(fragment.take(10).toList());
            await socket.flush();
            socket.destroy();
            cut.complete();
            return;
          }
          if (segmentRequests == 2) {
            fallbackReady.complete();
            await releaseFallback.future;
          } else if (!unexpectedFetch.isCompleted) {
            unexpectedFetch.complete();
          }
          request.response.add(fragment.toList()..[0] ^= 1);
        }
        await request.response.close();
      });
      final proxy = TwitchDartHlsLowLatencyProxy(
        upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/live.m3u8',
        upstreamHeaders: const {},
        outputFutureSegments: false,
        prefetchSegmentCount: 1,
        startupMode: TwitchHlsStartupMode.latestNormalImmediate,
        minPlaylistReloadDelay: const Duration(milliseconds: 20),
        maxPlaylistReloadDelay: const Duration(milliseconds: 40),
      );
      try {
        await proxy.start();
        await fallbackReady.future.timeout(const Duration(seconds: 5));
        await latePollReady.future.timeout(const Duration(seconds: 5));
        releaseFallback.complete();
        final clock = Stopwatch()..start();
        while ((await proxy.requestLiveStatus())?.running != false) {
          if (clock.elapsed > const Duration(seconds: 5)) {
            fail('Fixture did not reach fatal EOF.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(segmentRequests, 2);
        final stoppedVersion =
            (await proxy.requestLiveStatus())!.playlistVersion;
        releasePoll.complete();
        final fetched = await Future.any([
          unexpectedFetch.future.then((_) => true),
          Future<bool>.delayed(const Duration(milliseconds: 300), () => false),
        ]);
        expect(
          fetched,
          isFalse,
          reason: 'Stopped engine must not schedule from a late playlist.',
        );
        expect(segmentRequests, 2);
        expect(
          (await proxy.requestLiveStatus())!.playlistVersion,
          stoppedVersion,
        );
      } finally {
        if (!cut.isCompleted) cut.complete();
        if (!releaseFallback.isCompleted) releaseFallback.complete();
        if (!releasePoll.isCompleted) releasePoll.complete();
        await proxy.close();
        await upstream.close(force: true);
        await serving.cancel();
      }
    },
  );
}
