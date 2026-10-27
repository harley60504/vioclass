import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/main.dart' as app;
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_playback_session_controller.dart';
import 'package:vioclass/features/twitch/platform/android_playback/twitch_android_playback_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('real live stream resumes after three tablet background cycles', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenBefore = prefs.getString(TwitchAuthService.tokenStorageKey);
    expect(tokenBefore, isNotEmpty);
    await app.main([]);
    Future<void> waitFor(bool Function() ready, String phase) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
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
    expect(
      streams.streams,
      isNotEmpty,
      reason: 'Need an actually live channel',
    );
    final stream = streams.streams.first;
    debugPrint('[TabletLiveTest] CHANNEL ${stream.userLogin}');
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TwitchWatchPage(
            initialChannelLogin: stream.userLogin,
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
          !state.loadingWatch &&
          !state.loadingAuth &&
          state.playerSession.playerOrNull?.state.playing == true &&
          state.playerSession.playerOrNull!.state.position >
              const Duration(seconds: 2),
      'initial real live playback',
    );
    expect(state.showOfflineChannelPlaceholder, isFalse);
    expect(state.authService.isLoggedIn, isTrue);
    await waitFor(
      () => state.playerSession.playerOrNull!.state.playing,
      'playback service activation',
    );
    expect(
      await TwitchAndroidPlaybackController.channel.invokeMethod<bool>(
        'isRunning',
      ),
      isTrue,
    );
    debugPrint('[TabletLiveTest] SERVICE running=true');
    final generation = state.watchLoadGeneration;
    final chat = state.chatController.runtime;
    const cycles = int.fromEnvironment(
      'VIOCLASS_FOREGROUND_TEST_CYCLES',
      defaultValue: 3,
    );
    for (var cycle = 1; cycle <= cycles; cycle++) {
      debugPrint('[TabletLiveTest] READY cycle=$cycle');
      await waitFor(
        () => state.livePlaybackBackgroundedAt != null,
        'background $cycle',
      );
      expect(
        TwitchPlaybackSessionController.instance.playableState,
        isNotNull,
        reason: 'Backgrounding must retain the owned playback session',
      );
      debugPrint(
        '[TabletLiveTest] BACKGROUND cycle=$cycle sessionPreserved=true '
        'playing=${state.playerSession.playerOrNull?.state.playing}',
      );
      await waitFor(
        () => state.livePlaybackBackgroundedAt == null,
        'foreground $cycle',
      );
      final recovery = state.foregroundRecoveryInFlight;
      if (recovery != null) await recovery.timeout(const Duration(seconds: 60));
      await waitFor(
        () =>
            state.playerSession.playerOrNull?.state.playing == true &&
            state.playerSession.playerOrNull?.state.buffering == false,
        'resume playing $cycle',
      );
      final position = state.playerSession.playerOrNull!.state.position;
      await tester.pump(const Duration(seconds: 5));
      final advanced =
          state.playerSession.playerOrNull!.state.position - position;
      expect(advanced, greaterThan(const Duration(seconds: 2)));
      expect(state.watchLoadGeneration, generation);
      expect(state.chatController.runtime, same(chat));
      expect(state.showOfflineChannelPlaceholder, isFalse);
      expect(state.authService.isLoggedIn, isTrue);
      final proxy = await state.watchPorts.player.runtime
          .refreshProxyLiveStatus(notify: false);
      final age = proxy == null
          ? null
          : DateTime.now().difference(proxy.updatedAt).inSeconds;
      debugPrint(
        '[TabletLiveTest] CHECK cycle=$cycle advancedMs=${advanced.inMilliseconds} '
        'chatConnected=${state.chatController.runtime?.connected} '
        'proxyRunning=${proxy?.running} lagSegments=${proxy?.lagSegments} ageSec=$age '
        'positionMs=${state.playerSession.playerOrNull!.state.position.inMilliseconds} '
        'safeLiveMs=${proxy?.safeLivePosition.inMilliseconds}',
      );
      expect(state.chatController.runtime?.connected, isTrue);
      expect(proxy?.running, isTrue);
      expect(age, lessThanOrEqualTo(3));
      debugPrint(
        '[TabletLiveTest] PASS cycle=$cycle playing=true loggedIn=true',
      );
    }
    await prefs.reload();
    expect(
      prefs.getString(TwitchAuthService.tokenStorageKey) == tokenBefore,
      isTrue,
    );
    debugPrint('[TabletLiveTest] COMPLETE loginPreserved=true');
  });
}
