import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/main.dart' as app;
import 'package:vioclass/features/twitch/services/auth/twitch_auth_service.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('tablet offline page survives three real background cycles', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(TwitchAuthService.tokenStorageKey);
    expect(storedToken, isNotEmpty, reason: 'Existing login must be retained');
    await app.main([]);
    Future<void> waitFor(bool Function() ready, String phase) async {
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(ready(), isTrue, reason: phase);
    }

    await waitFor(() => find.byType(Navigator).evaluate().isNotEmpty, 'home');
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    TwitchWatchPageState? offline;
    for (final login in ['ninja', 'twitch']) {
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchPage(initialChannelLogin: login),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      await waitFor(
        () => !state.loadingWatch && !state.loadingAuth,
        'watch startup',
      );
      if (state.showOfflineChannelPlaceholder) {
        offline = state;
        break;
      }
      navigator.pop();
      await tester.pump(const Duration(seconds: 1));
    }
    expect(offline, isNotNull, reason: 'A real offline channel is required');
    final state = offline!;
    expect(state.authService.isLoggedIn, isTrue);
    final generation = state.watchLoadGeneration;
    final chat = state.chatController.runtime;
    for (var cycle = 1; cycle <= 3; cycle++) {
      debugPrint('[TabletOfflineTest] READY cycle=$cycle');
      await waitFor(
        () => state.livePlaybackBackgroundedAt != null,
        'background $cycle',
      );
      await waitFor(
        () => state.livePlaybackBackgroundedAt == null,
        'foreground $cycle',
      );
      final recovery = state.foregroundRecoveryInFlight;
      if (recovery != null) await recovery;
      await tester.pump(const Duration(seconds: 2));
      expect(state.watchLoadGeneration, generation);
      expect(state.chatController.runtime, same(chat));
      expect(state.showOfflineChannelPlaceholder, isTrue);
      expect(state.authService.isLoggedIn, isTrue);
      debugPrint(
        '[TabletOfflineTest] PASS cycle=$cycle unchanged=true loggedIn=true',
      );
    }
    await prefs.reload();
    expect(
      prefs.getString(TwitchAuthService.tokenStorageKey) == storedToken,
      isTrue,
      reason: 'Stored login must remain unchanged',
    );
    debugPrint('[TabletOfflineTest] COMPLETE loginPreserved=true');
  });
}
