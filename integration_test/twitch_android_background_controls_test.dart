import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/main.dart' as app;
import 'package:vioclass/features/twitch/platform/android_pip/twitch_android_pip_controller.dart';
import 'package:vioclass/features/twitch/platform/android_playback/twitch_android_playback_controller.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'Android PiP, optional background playback and system media controls',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final tokenBefore = prefs.getString(TwitchAuthService.tokenStorageKey);
      expect(tokenBefore, isNotEmpty);
      await app.main([]);
      Future<void> waitFor(bool Function() ready, String phase) async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: phase);
      }

      await waitFor(() => find.byType(Navigator).evaluate().isNotEmpty, 'home');
      final services = TwitchWatchServices.create();
      await services.authService.loadStoredSession(refreshIfNeeded: false);
      final discovery = TwitchDiscoveryService(
        client: services.apiClient,
        authService: services.authService,
        authApi: services.authApi,
      );
      final streams = await discovery.fetchBrowseStreams(
        language: 'zh',
        first: 5,
      );
      expect(streams.streams, isNotEmpty);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchPage(
              initialChannelLogin: streams.streams.first.userLogin,
              initialServices: services,
              initialDiscoveryService: discovery,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      await waitFor(
        () =>
            state.playerSession.playerOrNull?.state.playing == true &&
            state.playerSession.playerOrNull!.state.position >
                const Duration(seconds: 2),
        'live playback',
      );
      final service = TwitchAndroidPlaybackController.instance;
      final pip = TwitchAndroidPipController.instance;
      final originalBackground =
          prefs.getBool(TwitchAndroidPlaybackController.backgroundEnabledKey) ??
          false;
      try {
        await service.setEnabled(false);
        expect(await pip.enterPictureInPicture(), isTrue);
        await waitFor(() => pip.isInPictureInPictureMode, 'PiP entered');
        expect(state.playerSession.playerOrNull!.state.playing, isTrue);
        debugPrint('[BgControlsTest] PIP_ENTERED playing=true');
        await waitFor(() => !pip.isInPictureInPictureMode, 'PiP expanded');

        await pip.setAutoEnterEnabled(false);
        debugPrint('[BgControlsTest] PAUSE_READY');
        await waitFor(
          () => state.livePlaybackBackgroundedAt != null,
          'non-PiP background',
        );
        await waitFor(
          () => !state.playerSession.playerOrNull!.state.playing,
          'default background pause',
        );
        expect(
          await TwitchAndroidPlaybackController.channel.invokeMethod<bool>(
            'isRunning',
          ),
          isFalse,
        );
        debugPrint('[BgControlsTest] PAUSED default=true notification=false');
        await waitFor(
          () => state.livePlaybackBackgroundedAt == null,
          'foreground returned',
        );
        await waitFor(
          () => state.playerSession.playerOrNull!.state.playing,
          'foreground playback recovered',
        );

        await service.setEnabled(true);
        await pip.setAutoEnterEnabled(false);
        debugPrint('[BgControlsTest] BACKGROUND_READY');
        await waitFor(
          () => state.livePlaybackBackgroundedAt != null,
          'enabled background',
        );
        await tester.pump(const Duration(seconds: 3));
        expect(state.playerSession.playerOrNull!.state.playing, isTrue);
        debugPrint('[BgControlsTest] MEDIA_PAUSE_READY');
        await waitFor(
          () =>
              service.pausedFromControls &&
              !state.playerSession.playerOrNull!.state.playing,
          'system pause',
        );
        expect(
          await TwitchAndroidPlaybackController.channel.invokeMethod<bool>(
            'isRunning',
          ),
          isTrue,
        );
        debugPrint('[BgControlsTest] MEDIA_PLAY_READY pausedNotification=true');
        await waitFor(
          () =>
              !service.pausedFromControls &&
              state.playerSession.playerOrNull!.state.playing,
          'system play',
        );
        final before = state.playerSession.playerOrNull!.state.position;
        await tester.pump(const Duration(seconds: 3));
        expect(
          state.playerSession.playerOrNull!.state.position,
          greaterThan(before),
        );
        debugPrint('[BgControlsTest] MEDIA_STOP_READY');
        await waitFor(
          () =>
              service.pausedFromControls &&
              !state.playerSession.playerOrNull!.state.playing,
          'system stop',
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          await TwitchAndroidPlaybackController.channel.invokeMethod<bool>(
            'isRunning',
          ),
          isFalse,
        );
        await prefs.reload();
        expect(
          prefs.getString(TwitchAuthService.tokenStorageKey) == tokenBefore,
          isTrue,
        );
        debugPrint(
          '[BgControlsTest] PASS pip=true defaultPause=true mediaControls=true loginPreserved=true',
        );
      } finally {
        await service.setEnabled(originalBackground);
        await pip.setAutoEnterEnabled(
          prefs.getBool('twitch_player_android_pip_enabled_v1') ?? true,
        );
      }
    },
  );
}
