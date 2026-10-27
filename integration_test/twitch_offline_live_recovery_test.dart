// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_hls_proxy_models.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_playback_state.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_watch_controls_overlay.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_watch_playback_kind.dart';
import 'package:vioclass/features/twitch/presentation/watch/controllers/twitch_watch_preferences_controller.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';

import '../docs/twitch_watch_session_injection_test.dart' as fixture;

class _UnusedApi implements TwitchPlaybackApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected external playback request');
}

class _RecoveryRuntime extends TwitchPlaylistPlayerRuntime {
  _RecoveryRuntime(this.media, TwitchPlaybackApiService api)
    : super(playbackApi: api);

  final Uri media;
  int loads = 0;
  int liveResets = 0;
  int upstreamReconnects = 0;
  bool freshUpstream = false;

  @override
  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({
    bool notify = true,
  }) async {
    if (!freshUpstream) return null;
    return TwitchHlsLiveStatus.fromJson({
      'running': true,
      'hasWriter': true,
      'outputDurationMs': 30000,
      'latestPlayableSequence': 50,
      'lastWrittenSequence': 50,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<Uri?> prepareLowLatencyLiveFromWarmUpstream({
    bool forceProxyReconnect = false,
  }) async {
    debugPrint(
      '[ForegroundTest] prepare forceProxyReconnect=$forceProxyReconnect',
    );
    if (forceProxyReconnect) upstreamReconnects++;
    liveResets++;
    return media;
  }

  @override
  String get channelLogin => 'fixture';

  @override
  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    bool probeDvr = true,
  }) async {
    expectSync(channelLogin, 'fixture');
    loads++;
    if (loads == 1) throw StateError('Controlled first-open failure');
    return media;
  }
}

class _Discovery extends TwitchDiscoveryService {
  _Discovery(TwitchWatchServices services)
    : super(
        client: services.apiClient,
        authService: services.authService,
        authApi: services.authApi,
      );

  bool live = false;
  int reads = 0;

  @override
  Future<TwitchLiveStream?> fetchLiveStream({required String login}) async {
    expectSync(login, 'fixture');
    reads++;
    if (!live) return null;
    return TwitchLiveStream(
      id: 'controlled-live-stream',
      userId: '7',
      userLogin: 'fixture',
      userName: 'Fixture',
      gameId: '',
      gameName: '',
      title: 'Offline to live recovery test',
      viewerCount: 1,
      startedAt: DateTime.utc(2026, 10, 21),
      language: 'zh',
      thumbnailUrl: '',
      tags: const [],
      isMature: false,
    );
  }
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String phase, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: phase);
  debugPrint('[OfflineLive] passed $phase');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Windows offline to live retries and keeps decoded playback', (
    tester,
  ) async {
    expect(
      const bool.fromEnvironment('TWITCH_READONLY_OBSERVE_RESTORE_OPEN'),
      isTrue,
      reason:
          'Run with --dart-define=TWITCH_READONLY_OBSERVE_RESTORE_OPEN=true',
    );
    const path = String.fromEnvironment('VIOCLASS_RECOVERY_TEST_MEDIA');
    final media = File(path);
    expect(path, isNotEmpty);
    expect(media.existsSync(), isTrue);
    SharedPreferences.setMockInitialValues({
      TwitchWatchPreferencesController.playerVolumePreferenceKey: 0.0,
      TwitchWatchPreferencesController.playerMutedPreferenceKey: true,
    });
    MediaKit.ensureInitialized();
    final player = await Player.create();
    TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
    final session = TwitchMediaKitPlayerHost.acquire();
    final api = _UnusedApi();
    final runtime = _RecoveryRuntime(media.uri, api);
    final services = fixture.isolatedWatchPlaybackServices(
      session: session,
      runtime: runtime,
      playbackApi: api,
    );
    final discovery = _Discovery(services);
    try {
      await player.setVolume(0);
      player.setProperty('loop-file', 'inf');
      await session.ensureReady();
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchWatchPage(
            initialChannelLogin: 'fixture',
            initialServices: services,
            initialDiscoveryService: discovery,
            initialChatRuntimeFactory: fixture.isolatedWatchChatRuntime,
          ),
        ),
      );
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      await _wait(
        tester,
        () => !state.loadingAuth && state.showOfflineChannelPlaceholder,
        'initial offline artwork',
      );
      expect(runtime.loads, 0);
      discovery.live = true;
      await _wait(tester, () => runtime.loads == 1, 'first open attempted');
      await _wait(
        tester,
        () => !state.loadingPlayer && state.showOfflineChannelPlaceholder,
        'failed open retains offline artwork',
      );
      await _wait(
        tester,
        () => runtime.loads == 2 && !state.showOfflineChannelPlaceholder,
        'same stream retried and player shown',
      );
      await _wait(
        tester,
        () =>
            player.state.playing &&
            player.state.position.inMilliseconds > 500 &&
            (int.tryParse(player.getProperty('video-params/h')) ?? 0) > 0,
        'native video decoding',
      );
      final reads = discovery.reads;
      await _wait(
        tester,
        () => discovery.reads >= reads + 2,
        'two further live status polls',
      );
      expect(runtime.loads, 2);
      expect(state.showOfflineChannelPlaceholder, isFalse);
      expect(state.liveTimelineStreamId, 'controlled-live-stream');
      expect(player.state.playing, isTrue);
      expect(state.playerError, isNull);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[OfflineLive] complete loads=2 stablePolls=2 nativeVideo=true',
      );
      final opensBeforeResume = TwitchMediaKitPlayerHost.restoreOpenStarted;
      try {
        state.didChangeAppLifecycleState(AppLifecycleState.inactive);
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(
          runtime.liveResets,
          0,
          reason: 'Focus changes are not background',
        );
        await state.recoverWatchAfterForeground();
        expect(
          runtime.liveResets,
          0,
          reason: 'Ordinary reconciliation keeps playback',
        );
        var resets = 0;
        for (final platform in [
          TargetPlatform.windows,
          TargetPlatform.android,
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          state.didChangeAppLifecycleState(AppLifecycleState.hidden);
          state.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await state.foregroundRecoveryInFlight;
          resets++;
          expect(
            runtime.liveResets,
            resets,
            reason: 'LIVE resets on $platform',
          );
          await _wait(
            tester,
            () =>
                player.state.playing &&
                player.state.position.inMilliseconds > 500,
            'decoded playback after $platform foreground reset',
          );
        }
        expect(
          TwitchMediaKitPlayerHost.restoreOpenStarted,
          opensBeforeResume + 2,
        );
        runtime.freshUpstream = true;
        await player.seek(Duration.zero);
        await player.play();
        await tester.pump(const Duration(milliseconds: 100));
        state.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump(const Duration(milliseconds: 1500));
        state.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await state.foregroundRecoveryInFlight;
        debugPrint(
          '[ForegroundTest] healthy resets=${runtime.liveResets} upstream=${runtime.upstreamReconnects} opens=${TwitchMediaKitPlayerHost.restoreOpenStarted} baseline=$opensBeforeResume',
        );
        expect(
          runtime.liveResets,
          inInclusiveRange(2, 3),
          reason:
              'Current upstream is retained even if the local reader needs reset',
        );
        final warmReaderResets = runtime.liveResets - 2;
        expect(
          TwitchMediaKitPlayerHost.restoreOpenStarted,
          opensBeforeResume + 2 + warmReaderResets,
        );
        expect(runtime.upstreamReconnects, 2);
        runtime.freshUpstream = false;
        await player.pause();
        await tester.pump(const Duration(milliseconds: 200));
        final pointer = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await pointer.addPointer(
          location: tester.getCenter(find.byType(WatchControlsOverlay)),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byTooltip('播放').hitTestable());
        await _wait(
          tester,
          () =>
              runtime.liveResets == 3 + warmReaderResets &&
              player.state.playing &&
              !state.liveTimelineActionInFlight,
          'paused LIVE restarts at the edge',
        );
        expect(
          TwitchMediaKitPlayerHost.restoreOpenStarted,
          opensBeforeResume + 3 + warmReaderResets,
        );
        await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('播放器設定'));
        await _wait(
          tester,
          () => find
              .byKey(const ValueKey('player-settings-drawer'))
              .evaluate()
              .isNotEmpty,
          'player settings drawer',
        );
        final close = find.descendant(
          of: find.byKey(const ValueKey('player-settings-drawer')),
          matching: find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip == '關閉',
          ),
        );
        tester.widget<IconButton>(close).onPressed!();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byIcon(Icons.tune_rounded).hitTestable());
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('播放速度'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('1.5×').last);
        await _wait(
          tester,
          () => player.state.rate == 1.5,
          'native playback speed 1.5x',
        );
        expect(double.parse(player.getProperty('speed')), closeTo(1.5, .01));
        await tester.pump(const Duration(milliseconds: 300));
        await player.setRate(1);
        await pointer.removePointer();
        state.markOwnedPlayback(
          kind: TwitchWatchPlaybackKind.liveDvr,
          mediaUri: media.uri.toString(),
        );
        final dvrPosition = player.state.position;
        await state.recoverWatchAfterForeground(shouldProbeLiveRecovery: true);
        expect(
          runtime.liveResets,
          3 + warmReaderResets,
          reason: 'DVR keeps its viewing position',
        );
        expect(
          TwitchMediaKitPlayerHost.restoreOpenStarted,
          opensBeforeResume + 3 + warmReaderResets,
        );
        expect(player.state.position, greaterThanOrEqualTo(dvrPosition));
        runtime.freshUpstream = true;
        state.markOwnedPlayback(
          kind: TwitchWatchPlaybackKind.live,
          mediaUri: media.uri.toString(),
        );
        await state.recoverWatchAfterForeground(shouldProbeLiveRecovery: true);
        expect(
          runtime.liveResets,
          4 + warmReaderResets,
          reason: 'A lagging reader is replaced locally',
        );
        expect(
          runtime.upstreamReconnects,
          3,
          reason: 'A current upstream is not reconnected',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      await _wait(
        tester,
        () =>
            player.state.playing && player.state.position.inMilliseconds > 500,
        'native playback after Android foreground edge reset',
      );
      await tester.pumpWidget(const SizedBox());
      final readsAfterUnmount = discovery.reads;
      final deadline = DateTime.now().add(const Duration(seconds: 9));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(discovery.reads, readsAfterUnmount);
      expect(runtime.loads, 2);
      debugPrint('[OfflineLive] passed no requests after unmount');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      await TwitchMediaKitPlayerHost.disposeNow();
      services.apiClient.close(force: true);
    }
  });
}
