import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';

void main() {
  test(
    'Late live clients need initialization before the current fragment',
    () async {
      final bus = TwitchHlsLiveByteBus(maxReplayBytes: 1024);
      bus.beginSegment();
      bus.setInitializationBytes([1, 2, 3]);
      await bus.addStream(Stream.value([4, 5])); // First fragment.
      bus.beginSegment();
      await bus.addStream(Stream.value([6, 7])); // Later fragment, same map.
      final received = <List<int>>[];
      final done = Completer<void>();
      bus.createClientStream().listen(received.add, onDone: done.complete);
      bus.close();
      await done.future;
      expect(received, [
        [1, 2, 3],
        [6, 7],
      ]);
    },
  );
  test('Current clients receive a changed map once and TS clears it', () async {
    final bus = TwitchHlsLiveByteBus(maxReplayBytes: 1024);
    final received = <List<int>>[];
    final done = Completer<void>();
    bus
        .createClientStream(includeReplay: false)
        .listen(received.add, onDone: done.complete);
    bus.setInitializationBytes([1]);
    await bus.addStream(Stream.value([2]));
    bus.beginSegment();
    bus.setInitializationBytes([3]);
    await bus.addStream(Stream.value([4]));
    bus.beginSegment();
    bus.setInitializationBytes(null);
    await bus.addStream(Stream.value([5]));
    final late = <List<int>>[];
    final lateDone = Completer<void>();
    bus.createClientStream().listen(late.add, onDone: lateDone.complete);
    bus.close();
    await Future.wait([done.future, lateDone.future]);
    expect(received, [
      [1],
      [2],
      [3],
      [4],
      [5],
    ]);
    expect(late, [
      [5],
    ]);
  });
}
