import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/platform/android_playback/twitch_android_playback_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Media seek uses canonical DVR bounds and rejects obsolete or live requests',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final service = TwitchAndroidPlaybackController.instance;
      final calls = <Map>[];
      final seeks = <Duration>[];
      messenger.setMockMethodCallHandler(
        TwitchAndroidPlaybackController.channel,
        (call) async {
          calls.add(call.arguments as Map);
          return null;
        },
      );
      Future<void> seek(String id, int position) async {
        final done = Completer<void>();
        ServicesBinding.instance.channelBuffers.push(
          TwitchAndroidPlaybackController.channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('seekPlayback', {'id': id, 'position': position}),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      try {
        await service.clearMedia();
        await service.setEnabled(true);
        await service.setMedia(
          const TwitchAndroidMediaState(
            id: 'dvr',
            title: 'DVR',
            artist: 'channel',
            duration: Duration(hours: 2),
            position: Duration(seconds: 7190),
            minimum: Duration(seconds: 7180),
            seekable: true,
          ),
        );
        await service.setActive(true);
        service.onSeekRequested = (target) async {
          seeks.add(target);
        };
        expect((calls.last['media'] as Map)['duration'], 20000);
        expect((calls.last['media'] as Map)['position'], 10000);
        await seek('old-video', 1000);
        expect(seeks, isEmpty);
        await seek('dvr', -1000);
        expect(
          seeks.last,
          const Duration(hours: 2) - const Duration(seconds: 20),
        );
        await seek('dvr', 8000000);
        expect(seeks.last, const Duration(hours: 2));
        await service.setActive(false);
        await seek('dvr', 10000);
        expect(seeks.last, const Duration(milliseconds: 7190000));
        expect(calls.last['active'], true);
        await service.setMedia(
          const TwitchAndroidMediaState(
            id: 'live',
            title: 'Live',
            artist: 'channel',
          ),
        );
        expect((calls.last['media'] as Map)['duration'], 0);
        expect((calls.last['media'] as Map)['seekable'], false);
        await seek('live', 2000);
        expect(seeks, hasLength(3));
        await service.clearMedia();
        await seek('dvr', 7190000);
        expect(seeks, hasLength(3));
      } finally {
        service.onSeekRequested = null;
        await service.clearMedia();
        await service.setEnabled(false);
        messenger.setMockMethodCallHandler(
          TwitchAndroidPlaybackController.channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  test(
    'Playback service starts/stops with playback and coalesces obsolete requests',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <(bool, bool)>[];
      const channel = TwitchAndroidPlaybackController.channel;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map;
            calls.add((args['active'] as bool, args['playing'] as bool));
            return null;
          });
      final service = TwitchAndroidPlaybackController.instance;
      try {
        await service.clearMedia();
        await service.setEnabled(false);
        calls.clear();
        await service.setActive(true);
        expect(calls.last, (false, true));
        calls.clear();
        await service.setEnabled(true);
        await service.setActive(true);
        await service.setActive(false);
        expect(calls, [(true, true), (true, false)]);
        await service.clearMedia();
        expect(calls.last, (false, false));
        await service.setEnabled(false);
        calls.clear();
        final obsolete = service.setActive(true);
        final current = service.setActive(false);
        await Future.wait([obsolete, current]);
        expect(calls, isEmpty);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
