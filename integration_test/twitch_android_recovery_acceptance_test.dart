import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_hls_proxy_models.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'package:vioclass/features/twitch/services/watch/twitch_watch_services.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:media_kit/media_kit.dart';
import '../docs/twitch_watch_session_injection_test.dart' as fixture;
import 'twitch_tablet_live_foreground_test.dart' as real_live;

class _UnusedApi implements TwitchPlaybackApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected external playback API');
}

class _Runtime extends TwitchPlaylistPlayerRuntime {
  _Runtime(this.url, {required super.playbackApi});
  final String url;
  int reconnects = 0;
  bool observe = false;
  TwitchHlsLiveStatus? firstStatus;
  int? firstAgeMs;
  int observedReads = 0;
  @override
  String get channelLogin => 'fixture';
  @override
  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    bool probeDvr = true,
  }) => startProxyForVariant(
    TwitchM3u8Variant(name: 'source', url: url, isAudioOnly: true),
  );
  @override
  Future<Uri?> prepareLowLatencyLiveFromWarmUpstream({
    bool forceProxyReconnect = false,
  }) {
    if (forceProxyReconnect) reconnects++;
    return super.prepareLowLatencyLiveFromWarmUpstream(
      forceProxyReconnect: forceProxyReconnect,
    );
  }

  @override
  Future<TwitchHlsLiveStatus?> refreshProxyLiveStatus({
    bool notify = true,
  }) async {
    final status = await super.refreshProxyLiveStatus(notify: notify);
    if (observe) {
      observedReads++;
      if (firstStatus == null && status != null) {
        firstStatus = status;
        firstAgeMs = DateTime.now().difference(status.updatedAt).inMilliseconds;
      }
    }
    return status;
  }
}

class _Discovery extends TwitchDiscoveryService {
  _Discovery(TwitchWatchServices services)
    : super(
        client: services.apiClient,
        authService: services.authService,
        authApi: services.authApi,
      );
  @override
  Future<TwitchLiveStream?> fetchLiveStream({required String login}) async =>
      TwitchLiveStream(
        id: 'fixture-live-stream',
        userId: '7',
        userLogin: 'fixture',
        userName: 'Fixture',
        gameId: '',
        gameName: '',
        title: 'Controlled upstream recovery',
        viewerCount: 1,
        startedAt: DateTime.utc(2026, 10, 12),
        language: 'zh',
        thumbnailUrl: '',
        tags: const [],
        isMature: false,
      );
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.resume);
  final VoidCallback resume;
  bool armed = false;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (armed && state == AppLifecycleState.resumed) {
      armed = false;
      resume();
    }
  }
}

void main() {
  if (!const bool.fromEnvironment('VIOCLASS_SKIP_REAL_LIVE')) {
    real_live.main();
  } else {
    final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  }
  testWidgets(
    'Android retains a real producer recovering within the confirmation window',
    (tester) async {
      Future<void> waitFor(bool Function() ready, String phase) async {
        final deadline = DateTime.now().add(const Duration(seconds: 50));
        while (!ready() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready(), isTrue, reason: phase);
      }

      await TwitchMediaKitPlayerHost.disposeNow();
      final session = TwitchMediaKitPlayerHost.acquire();
      await session.ensureReady();
      final player = session.player;
      const mediaPath = String.fromEnvironment('VIOCLASS_RECOVERY_TEST_MEDIA');
      expect(mediaPath, isNotEmpty);
      final media = await File(mediaPath).readAsBytes();
      await player.open(Media(mediaPath), play: false);
      await waitFor(
        () => player.state.duration > Duration.zero,
        'fixture duration',
      );
      final segmentSeconds = player.state.duration.inMilliseconds / 1000;
      final bytes = ByteData.sublistView(media);
      var split = 0;
      while (String.fromCharCodes(media.sublist(split + 4, split + 8)) !=
          'moof') {
        split += bytes.getUint32(split);
      }
      final init = media.sublist(0, split), fragment = media.sublist(split);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final clock = Stopwatch()..start();
      int? frozenSequence;
      int sequence() =>
          frozenSequence ??
          (clock.elapsedMilliseconds / (segmentSeconds * 1000)).floor();
      final serving = server.listen((request) async {
        if (request.uri.path.endsWith('.m3u8')) {
          final current = sequence();
          request.response.write(
            '#EXTM3U\n#EXT-X-TARGETDURATION:${segmentSeconds.ceil()}\n'
            '#EXT-X-MEDIA-SEQUENCE:$current\n#EXT-X-DISCONTINUITY-SEQUENCE:$current\n'
            '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:$segmentSeconds,\n/$current.m4s\n',
          );
        } else {
          request.response.add(
            request.uri.path == '/init.mp4' ? init : fragment,
          );
        }
        await request.response.close();
      });
      final api = _UnusedApi();
      final runtime = _Runtime(
        'http://127.0.0.1:${server.port}/live.m3u8',
        playbackApi: api,
      );
      final services = fixture.isolatedWatchPlaybackServices(
        session: session,
        runtime: runtime,
        playbackApi: api,
      );
      final observer = _ResumeObserver(() {
        runtime.observe = true;
        Timer(const Duration(milliseconds: 650), () {
          frozenSequence = null;
        });
      });
      WidgetsBinding.instance.addObserver(observer);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: TwitchWatchPage(
              initialChannelLogin: 'fixture',
              initialServices: services,
              initialDiscoveryService: _Discovery(services),
              initialChatRuntimeFactory: fixture.isolatedWatchChatRuntime,
            ),
          ),
        );
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        await waitFor(
          () =>
              player.state.playing &&
              player.state.position > const Duration(seconds: 2),
          'controlled decoding',
        );
        expect(
          int.tryParse(player.getProperty('video-params/h')) ?? 0,
          greaterThan(0),
        );
        final original = runtime.proxy;
        frozenSequence = sequence();
        observer.armed = true;
        debugPrint('[GraceDeviceTest] READY holdSeconds=12');
        await waitFor(
          () => state.livePlaybackBackgroundedAt != null,
          'controlled background',
        );
        await waitFor(
          () => state.livePlaybackBackgroundedAt == null,
          'controlled foreground',
        );
        await state.foregroundRecoveryInFlight;
        await waitFor(
          () => player.state.playing && !player.state.buffering,
          'controlled recovery',
        );
        expect(runtime.firstStatus?.running, isTrue);
        expect(runtime.firstStatus?.hasWriter, isTrue);
        expect(runtime.firstAgeMs, greaterThan(10000));
        expect(runtime.observedReads, greaterThan(1));
        expect(runtime.reconnects, 0);
        expect(runtime.proxy, same(original));
        final recovered = await runtime.refreshProxyLiveStatus(notify: false);
        expect(
          DateTime.now().difference(recovered!.updatedAt).inSeconds,
          lessThanOrEqualTo(2),
        );
        debugPrint(
          '[GraceDeviceTest] PRODUCER preserved=true staleAgeMs=${runtime.firstAgeMs} reads=${runtime.observedReads} upstreamReconnects=0',
        );
        await waitFor(
          () =>
              player.state.position > Duration.zero &&
              (int.tryParse(player.getProperty('video-params/h')) ?? 0) > 0,
          'reopened fixture reader decoded',
        );
        final before = player.state.position;
        await tester.pump(const Duration(seconds: 3));
        expect(player.state.position, greaterThan(before));
        debugPrint(
          '[GraceDeviceTest] PASS staleAgeMs=${runtime.firstAgeMs} reads=${runtime.observedReads} upstreamReconnects=0 decoded=true',
        );
      } finally {
        WidgetsBinding.instance.removeObserver(observer);
        await tester.pumpWidget(const SizedBox());
        runtime.clear();
        await TwitchMediaKitPlayerHost.disposeNow();
        await serving.cancel();
        await server.close(force: true);
      }
    },
  );
}
