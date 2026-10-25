import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/presentation/watch/controllers/twitch_adaptive_quality_controller.dart';

const high = TwitchM3u8Variant(
  name: '1080p60',
  url: 'fixture-high',
  resolution: '1920x1080',
  frameRate: 60,
);
const mid = TwitchM3u8Variant(
  name: '720p',
  url: 'fixture-mid',
  resolution: '1280x720',
);
const low = TwitchM3u8Variant(
  name: '360p',
  url: 'fixture-low',
  resolution: '640x360',
);
const audio = TwitchM3u8Variant(
  name: 'Audio',
  url: 'fixture-audio',
  isAudioOnly: true,
  bandwidth: 99999999,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // This test fixture intentionally lives outside the standard test folder.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });
  test('Highest ranks video resolution before bitrate and excludes audio', () {
    expect(TwitchAdaptiveQualityController.ranked([audio, low, high, mid]), [
      high,
      mid,
      low,
    ]);
  });
  test(
    'Adaptive levels deduplicate alternate sources of the same rendition',
    () {
      final alternate = high.copyWith(url: 'alternate', hasAds: true);
      expect(
        TwitchAdaptiveQualityController.ranked([alternate, low, high, mid]),
        [high, mid, low],
      );
    },
  );
  test(
    'Auto steps down on sustained buffering and up only after stability',
    () async {
      var time = DateTime.utc(2026, 10, 25);
      var selected = high;
      var buffering = true;
      final changes = <TwitchM3u8Variant>[];
      final controller = TwitchAdaptiveQualityController(
        variants: () => [audio, low, mid, high],
        current: () => selected,
        playing: () => true,
        buffering: () => buffering,
        enabled: () => true,
        now: () => time,
        select: (v) {
          selected = v;
          changes.add(v);
        },
      );
      addTearDown(controller.dispose);
      await controller.setMode(TwitchQualityMode.auto);
      await controller.sample();
      time = time.add(const Duration(seconds: 7));
      await controller.sample();
      expect(selected, mid);
      time = time.add(const Duration(seconds: 7));
      await controller.sample();
      expect(selected, mid, reason: 'Cooldown prevents repeated downgrades');
      buffering = false;
      await controller.sample();
      time = time.add(const Duration(seconds: 61));
      await controller.sample();
      expect(changes, [mid, high]);
    },
  );
  test('Manual, paused and replay-disabled modes do not adapt', () async {
    var selected = high;
    var time = DateTime.utc(2026, 10, 25);
    var playing = false;
    var enabled = true;
    var changes = 0;
    final controller = TwitchAdaptiveQualityController(
      variants: () => [high, low],
      current: () => selected,
      playing: () => playing,
      buffering: () => true,
      enabled: () => enabled,
      now: () => time,
      select: (v) {
        selected = v;
        changes++;
      },
    );
    addTearDown(controller.dispose);
    await controller.setMode(TwitchQualityMode.auto);
    await controller.sample();
    time = time.add(const Duration(minutes: 3));
    await controller.sample();
    expect(changes, 0);
    playing = true;
    enabled = false;
    await controller.sample();
    time = time.add(const Duration(minutes: 3));
    await controller.sample();
    expect(changes, 0);
    enabled = true;
    await controller.chooseManual(low);
    time = time.add(const Duration(minutes: 3));
    await controller.sample();
    expect(changes, 1);
    expect(selected, low);
  });
  test(
    'Pending selection coalesces automatic samples and disposal stops work',
    () async {
      var changes = 0;
      final gate = Completer<void>();
      final controller = TwitchAdaptiveQualityController(
        variants: () => [high, low],
        current: () => low,
        playing: () => true,
        buffering: () => false,
        enabled: () => true,
        select: (_) async {
          changes++;
          await gate.future;
        },
      );
      final pending = controller.setMode(TwitchQualityMode.highest);
      await Future<void>.delayed(Duration.zero);
      await controller.sample();
      expect(changes, 1);
      controller.dispose();
      gate.complete();
      await pending;
      await controller.sample();
      expect(changes, 1);
    },
  );
}
