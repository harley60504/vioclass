// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_route_guard.dart';
import 'package:vioclass/features/twitch/presentation/watch/controllers/twitch_watch_preferences_controller.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_player_quality_button.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';
import '../docs/twitch_native_log_diagnostics.dart';
import '../docs/twitch_watch_session_injection_test.dart' as fixture;

class _LocalClipApi implements TwitchPlaybackApiService {
  _LocalClipApi(this.variants);
  final List<TwitchM3u8Variant> variants;
  int resolves = 0;
  final unexpected = <String>[];
  @override
  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) async {
    expect(clipSlug, 'fixture-local-av');
    resolves++;
    return TwitchClipPlaybackResult(
      playbackUri: Uri.parse(variants.first.url),
      variants: variants,
      selectedVariant: variants.first,
      durationSeconds: 30,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpected.add(invocation.memberName.toString());
    throw StateError('Unexpected playback API operation');
  }
}

// Exercise the proven live-watch composition using local variants only.
// This is not a Twitch playlist/proxy or recorded startup verification.
class _LocalLiveVariantsRuntime extends TwitchPlaylistPlayerRuntime {
  _LocalLiveVariantsRuntime(this.localVariants, TwitchPlaybackApiService api)
    : selected = localVariants.first,
      super(playbackApi: api);
  final List<TwitchM3u8Variant> localVariants;
  TwitchM3u8Variant selected;
  int loads = 0;
  @override
  String get channelLogin => 'fixture';
  @override
  List<TwitchM3u8Variant> get variants => List.unmodifiable(localVariants);
  @override
  TwitchM3u8Variant get currentVariant => selected;
  @override
  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    bool probeDvr = true,
  }) async {
    expect(channelLogin, 'fixture');
    loads++;
    return Uri.parse(selected.url);
  }

  @override
  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) async {
    expect(localVariants, contains(variant));
    selected = variant;
    return Uri.parse(variant.url);
  }
}

class _LocalLiveDiscovery extends TwitchDiscoveryService {
  _LocalLiveDiscovery(TwitchWatchServices services)
    : super(
        client: services.apiClient,
        authService: services.authService,
        authApi: services.authApi,
      );
  @override
  Future<TwitchLiveStream?> fetchLiveStream({required String login}) async {
    expect(login, 'fixture');
    return TwitchLiveStream(
      id: 'local-av-live',
      userId: '7',
      userLogin: 'fixture',
      userName: 'Fixture',
      gameId: '',
      gameName: '',
      title: 'Local AV fixture',
      viewerCount: 1,
      startedAt: DateTime.utc(2026, 10, 12),
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
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), true, reason: phase);
  debugPrint('[LocalAV] passed $phase');
}

void main() {
  const liveMode = bool.fromEnvironment('VIOCLASS_LOCAL_AV_LIVE_MODE');
  if (!enableWatchPlayer) {
    throw StateError('The isolated AV test requires watch playback enabled');
  }
  const root = String.fromEnvironment('VIOCLASS_LOCAL_AV_FIXTURE_ROOT');
  if (root.isEmpty) {
    throw StateError('An explicit isolated media directory is required');
  }
  final variants = [
    for (final size in ['640x360', '320x180'])
      TwitchM3u8Variant(
        name: size,
        url: File('$root/$size.mkv').uri.toString(),
        resolution: size,
        sourceTag: 'local-fixture',
      ),
  ];
  for (final variant in variants) {
    if (!File.fromUri(Uri.parse(variant.url)).existsSync()) {
      throw StateError('Local AV fixture is missing');
    }
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Isolated watch decodes audio and changes real video resolution', (
    tester,
  ) async {
    final previousPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message?.startsWith('[LocalAV]') == true) {
        previousPrint(message, wrapWidth: wrapWidth);
      }
    };
    addTearDown(() => debugPrint = previousPrint);
    SharedPreferences.setMockInitialValues({
      TwitchWatchPreferencesController.playerVolumePreferenceKey: 20.0,
      TwitchWatchPreferencesController.playerMutedPreferenceKey: false,
    });
    MediaKit.ensureInitialized();
    final player = await Player.create(
      configuration: const PlayerConfiguration(options: {'aid': 'auto'}),
    );
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
    final session = TwitchMediaKitPlayerHost.acquire();
    final api = _LocalClipApi(variants);
    final localLiveRuntime = liveMode
        ? _LocalLiveVariantsRuntime(variants, api)
        : null;
    final runtime =
        localLiveRuntime ?? TwitchPlaylistPlayerRuntime(playbackApi: api);
    final services = fixture.isolatedWatchPlaybackServices(
      session: session,
      runtime: runtime,
      playbackApi: api,
    );
    final diagnostics = TwitchNativeLogDiagnostics();
    final logs = player.stream.log.listen(
      (log) => diagnostics.record(log.text),
    );
    double number(String name) =>
        double.tryParse(player.getProperty(name)) ?? -1;
    String phase = 'initial';
    try {
      await player.setVolume(20);
      await session.ensureReady();
      await tester.pumpWidget(
        MaterialApp(
          home: TwitchWatchRouteGuard(
            initialChannelLogin: 'fixture',
            initialServices: services,
            initialDiscoveryService: liveMode
                ? _LocalLiveDiscovery(services)
                : null,
            initialClip: liveMode
                ? null
                : TwitchChannelClip.fromHelixJson({
                    'id': 'fixture-local-av',
                    'broadcaster_id': '7',
                    'broadcaster_name': 'Fixture',
                    'title': 'Local AV fixture',
                    'duration': 30,
                    'vod_offset': -1,
                  }),
            initialChatRuntimeFactory: fixture.isolatedWatchChatRuntime,
          ),
        ),
      );
      await _wait(
        tester,
        () => liveMode ? localLiveRuntime!.loads > 0 : api.resolves > 0,
        liveMode
            ? 'live loader reaches local source'
            : 'clip loader reaches isolated API',
        timeout: const Duration(seconds: 10),
      );
      await _wait(
        tester,
        () =>
            number('video-params/h') == 360 &&
            player.state.position.inMilliseconds > 500,
        'initial 360p video decoding',
        timeout: const Duration(seconds: 45),
      );
      final state = tester.state<TwitchWatchPageState>(
        find.byType(TwitchWatchPage),
      );
      expect(state.viewerId, isNull);
      expect(api.resolves, liveMode ? 0 : 1);
      phase = 'audio';
      await _wait(
        tester,
        () =>
            number('audio-params/samplerate') == 48000 &&
            number('audio-out-params/samplerate') > 0 &&
            number('audio-pts') > 0,
        'audio decoding and output pipeline',
      );
      final audioStart = number('audio-pts');
      await tester.pump(const Duration(seconds: 2));
      expect(number('audio-pts') - audioStart, greaterThan(1));
      expect((number('volume') - 20).abs(), lessThan(1));
      debugPrint(
        '[LocalAV] audio inputHz=${number('audio-params/samplerate')} outputHz=${number('audio-out-params/samplerate')} advanced=true',
      );
      for (final variant in [variants.last, variants.first]) {
        phase = 'quality-${variant.name}';
        final position = player.state.position;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(
          location: tester.getCenter(find.byType(QualityButton).first),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(QualityButton).hitTestable().first);
        await mouse.removePointer();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(variant.name).hitTestable().last);
        await tester.pump();
        await _wait(
          tester,
          () =>
              (liveMode
                      ? localLiveRuntime!.currentVariant.url
                      : state.currentVodQualityVariant?.url) ==
                  variant.url &&
              TwitchMediaKitPlayerHost.currentMediaUri == variant.url &&
              number('video-params/h') == variant.height &&
              player.state.playing,
          'real watch quality ${variant.name}',
        );
        expect(number('video-params/w'), variant.name == '320x180' ? 320 : 640);
        if (!liveMode) {
          expect(
            player.state.position.inMilliseconds,
            greaterThanOrEqualTo(position.inMilliseconds - 2000),
          );
        }
        final resumed = player.state.position;
        await tester.pump(const Duration(seconds: 2));
        expect(
          player.state.position - resumed,
          greaterThan(const Duration(seconds: 1)),
        );
        expect(number('audio-out-params/samplerate'), greaterThan(0));
      }
      expect(diagnostics.snapshot['audio_decode_failed'] ?? 0, 0);
      expect(diagnostics.snapshot['audio_output_failed'] ?? 0, 0);
      expect(api.unexpected, isEmpty);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[LocalAV] complete liveMode=$liveMode audio=true qualitySwitches=2 unexpectedAPI=${api.unexpected.length} categories=${diagnostics.snapshot}',
      );
    } catch (error) {
      final watches = find.byType(TwitchWatchPage).evaluate();
      final state = watches.isEmpty
          ? null
          : tester.state<TwitchWatchPageState>(find.byType(TwitchWatchPage));
      debugPrint(
        '[LocalAV] startup resolves=${api.resolves} unexpected=${api.unexpected} mounted=${state != null} generation=${state?.watchLoadGeneration} loadingAuth=${state?.loadingAuth} loadingWatch=${state?.loadingWatch} offlinePlaceholder=${state?.showOfflineChannelPlaceholder} hasPlayerError=${state?.playerError != null}',
      );
      debugPrint(
        '[LocalAV] failed phase=$phase type=${error.runtimeType} height=${number('video-params/h')} inputHz=${number('audio-params/samplerate')} outputHz=${number('audio-out-params/samplerate')} audioPts=${number('audio-pts')} categories=${diagnostics.snapshot}',
      );
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      await logs.cancel();
      await TwitchMediaKitPlayerHost.disposeNow();
      services.apiClient.close(force: true);
    }
  });
}
