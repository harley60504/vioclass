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
  testWidgets('Auto PiP transition retains playback and the media service', (
    tester,
  ) async {
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
      'live',
    );
    final pip = TwitchAndroidPipController.instance;
    final service = TwitchAndroidPlaybackController.instance;
    final originalBackground =
        prefs.getBool(TwitchAndroidPlaybackController.backgroundEnabledKey) ??
        false;
    var falseBackground = false;
    var confirmed = false;
    void observe() {
      falseBackground |= pip.stoppedOutsidePictureInPicture;
      confirmed |= pip.isInPictureInPictureMode;
      debugPrint(
        '[PipTransitionTest] preparing=${pip.isPreparingPictureInPicture} '
        'pip=${pip.isInPictureInPictureMode} activity=${pip.isActivityStarted} '
        'outside=${pip.stoppedOutsidePictureInPicture}',
      );
    }

    try {
      await service.setEnabled(true);
      await pip.setAutoEnterEnabled(true);
      pip.addListener(observe);
      debugPrint('[PipTransitionTest] READY_HOME');
      await waitFor(() => pip.isInPictureInPictureMode, 'auto PiP');
      await tester.pump(const Duration(seconds: 3));
      expect(state.playerSession.playerOrNull!.state.playing, true);
      expect(
        await TwitchAndroidPlaybackController.channel.invokeMethod<bool>(
          'isRunning',
        ),
        true,
      );
      expect(falseBackground, false);
      expect(confirmed, true);
      debugPrint(
        '[PipTransitionTest] PIP_STABLE service=true falseBackground=false',
      );
      pip.removeListener(observe);
      await waitFor(
        () => !pip.isInPictureInPictureMode && pip.isActivityStarted,
        'expanded',
      );
      await prefs.reload();
      expect(
        prefs.getString(TwitchAuthService.tokenStorageKey) == tokenBefore,
        true,
      );
      debugPrint('[PipTransitionTest] PASS loginPreserved=true');
    } finally {
      pip.removeListener(observe);
      await service.setEnabled(originalBackground);
      await pip.setAutoEnterEnabled(
        prefs.getBool('twitch_player_android_pip_enabled_v1') ?? true,
      );
    }
  });
}
