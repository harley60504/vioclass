import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui'
    show FrameTiming, PointerDeviceKind, ImageByteFormat, instantiateImageCodec;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_viewer_auth.dart';
import 'package:vioclass/features/twitch/api/core/twitch_api_client.dart';
import 'package:vioclass/features/twitch/api/core/twitch_gql_api_service.dart';
import 'package:vioclass/features/twitch/api/chat/twitch_irc_api_service.dart';
import 'package:vioclass/features/twitch/services/chat/twitch_chat_runtime.dart';
import 'package:vioclass/features/twitch/services/chat/twitch_badge_cache_service.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_guest_discovery_service.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_stable_hls_proxy_router.dart';
import '../docs/twitch_watch_session_injection_test.dart' as watch_fixture;
import 'package:vioclass/main.dart' as app;
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_following_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_stream_home_models.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_page.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_stream_header_metadata.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_watch_route_guard.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_channel_page.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_live_watch_playback.dart';
import 'package:vioclass/features/twitch/presentation/pages/watch/twitch_watch_playback_state.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_stream_card.dart';
import 'package:vioclass/features/twitch/presentation/widgets/discovery/twitch_discovery_stream_template.dart';
import 'package:vioclass/features/twitch/presentation/widgets/chat/twitch_chat_input_bar.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/chat/twitch_vod_replay_chat_panel.dart';
import 'package:vioclass/features/twitch/presentation/widgets/home/twitch_stream_home_toolbar.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_watch_controls_overlay.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_media_kit_video_surface.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_vod_playback_strip.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_watch_top_buttons.dart';
import 'package:vioclass/features/twitch/presentation/pages/twitch_linked_login_page.dart';
import 'package:vioclass/features/twitch/presentation/widgets/watch/player/twitch_player_quality_button.dart';
import 'package:window_manager/window_manager.dart';
import 'package:vioclass/features/twitch/services/window/twitch_fullscreen_controller.dart';
import 'package:vioclass/features/twitch/presentation/widgets/home/twitch_followed_live_rail.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_controller.dart';
import 'package:vioclass/features/twitch/presentation/mini_player/twitch_mini_player_overlay.dart';
import 'package:vioclass/features/twitch/presentation/watch/twitch_playback_session_controller.dart';
import 'package:vioclass/features/twitch/services/auth/twitch_viewer_session.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_playlist_player_runtime.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_discovery_service.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_media_kit_player_host.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';
import '../docs/twitch_replay_window_probe.dart';
import '../docs/twitch_native_log_diagnostics.dart';
import '../docs/twitch_fragment_timestamp_fixture.dart';

class _NoRemotePlayback implements TwitchPlaybackApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Read transport is unchanged; accidental test writes fail before IRC send.
class _ReadonlyGuestIrc extends TwitchIrcApiService {
  int connects = 0;
  int sendAttempts = 0;
  @override
  Future<void> connect({
    required String channelLogin,
    String? accessToken,
    String nick = 'justinfan12345',
  }) {
    expectSync(accessToken, isNull);
    connects++;
    return super.connect(
      channelLogin: channelLogin,
      accessToken: null,
      nick: nick,
    );
  }

  @override
  Future<void> sendChatMessage({
    required String message,
    String? channelLogin,
  }) async {
    sendAttempts++;
    throw StateError('Readonly guest test forbids chat writes');
  }
}

class _LocalWatchRuntime extends TwitchPlaylistPlayerRuntime {
  _LocalWatchRuntime(this.uri) : super(playbackApi: _NoRemotePlayback());
  final Uri uri;
  @override
  Future<Uri?> loadLivePlaylist({
    required String channelLogin,
    TwitchM3u8Variant? preferredVariant,
    String? preferredVariantName,
    bool probeDvr = true,
  }) async => uri;
}

class _LocalQualityRuntime extends _LocalWatchRuntime {
  _LocalQualityRuntime(super.uri);
  List<TwitchM3u8Variant> localChoices = const [];
  TwitchM3u8Variant? selected;
  int switches = 0;
  @override
  List<TwitchM3u8Variant> get variants => List.unmodifiable(localChoices);
  @override
  TwitchM3u8Variant? get currentVariant => selected;
  @override
  Future<Uri?> startProxyForVariant(TwitchM3u8Variant variant) async {
    expect(localChoices, contains(variant));
    switches++;
    selected = variant;
    notifyListeners();
    return Uri.parse(variant.url);
  }
}

class _LocalRecordedQualityApi implements TwitchPlaybackApiService {
  _LocalRecordedQualityApi(this.choices);
  final List<TwitchM3u8Variant> choices;
  int resolves = 0;
  @override
  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) async {
    expect(clipSlug, 'local-quality-clip');
    resolves++;
    return TwitchClipPlaybackResult(
      playbackUri: Uri.parse(choices.last.url),
      variants: choices,
      selectedVariant: choices.last,
      durationSeconds: 30,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected local recorded playback API call');
}

class _LocalWatchSession implements TwitchMediaKitPlayerSession {
  _LocalWatchSession(this.player, {this.surfaceSession});
  final TwitchMediaKitPlayerSession? surfaceSession;
  @override
  final Player player;
  int opens = 0;
  int completedOpens = 0;
  void Function()? onOpenStarted;
  @override
  Player? get playerOrNull => player;
  @override
  Future<void> useLowLatencyHlsProfile() async {
    await surfaceSession?.useLowLatencyHlsProfile();
  }

  @override
  Future<void> ensureReady() async {
    await surfaceSession?.ensureReady();
  }

  @override
  Future<void> pauseCurrent() => player.pause();
  @override
  Future<void> stopCurrent() => player.stop();
  @override
  void release() => surfaceSession?.release();
  @override
  Future<void> openOrResume({
    required String uri,
    bool play = true,
    bool forceOpen = false,
    Duration? startPosition,
  }) async {
    opens++;
    onOpenStarted?.call();
    try {
      await TwitchMediaKitPlayerHost.restoreSharedMedia(
        uri: uri,
        play: play,
        forceOpen: forceOpen,
      );
    } finally {
      completedOpens++;
    }
    if (startPosition != null) await player.seek(startPosition);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #videoControllerOrNull) {
      return surfaceSession?.videoControllerOrNull;
    }
    return super.noSuchMethod(invocation);
  }
}

Future<void> _verifyRecoveredWatchPixels(
  WidgetTester tester,
  Player player,
  GlobalKey boundaryKey, {
  bool switchedSource = false,
}) async {
  await player.pause();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(TwitchMediaKitVideoSurface), findsOneWidget);
  final screenshot = await player.screenshot();
  expect(screenshot, isNotNull);
  final codec = await instantiateImageCodec(screenshot!);
  final nativeImage = (await codec.getNextFrame()).image;
  final nativePixels = await nativeImage.toByteData(
    format: ImageByteFormat.rawRgba,
  );
  var nativeNonBlack = 0;
  for (var i = 0; i < nativePixels!.lengthInBytes; i += 4) {
    if (nativePixels.getUint8(i) > 16 ||
        nativePixels.getUint8(i + 1) > 16 ||
        nativePixels.getUint8(i + 2) > 16) {
      nativeNonBlack++;
    }
  }
  final nativeFraction =
      nativeNonBlack / (nativeImage.width * nativeImage.height);
  nativeImage.dispose();
  codec.dispose();
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final pixels = await image.toByteData(format: ImageByteFormat.rawRgba);
  final texture = tester.getRect(find.byType(Texture).first);
  final sample = Rect.fromCenter(
    center: texture.center - boundary.localToGlobal(Offset.zero),
    width: texture.width * .6,
    height: texture.height * .6,
  );
  var nonBlack = 0;
  var total = 0;
  final colors = <int>{};
  for (var y = sample.top.ceil(); y < sample.bottom.floor(); y += 2) {
    for (var x = sample.left.ceil(); x < sample.right.floor(); x += 2) {
      final offset = (y * image.width + x) * 4;
      final r = pixels!.getUint8(offset);
      final g = pixels.getUint8(offset + 1);
      final b = pixels.getUint8(offset + 2);
      if (r > 16 || g > 16 || b > 16) {
        nonBlack++;
      }
      colors.add((r << 16) | (g << 8) | b);
      total++;
    }
  }
  final png = await image.toByteData(format: ImageByteFormat.png);
  await io.File(
    switchedSource
        ? 'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-guest-switch-surface-fixture.png'
        : 'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-guest-eof-surface-fixture.png',
  ).writeAsBytes(png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes));
  image.dispose();
  debugPrint(
    '[ReadonlyTest] recovered guest surface positionMs=${player.state.position.inMilliseconds} nativeNonBlack=$nativeFraction surfaceNonBlack=${nonBlack / total} colors=${colors.length} samples=$total',
  );
  expect(nativeFraction, greaterThan(.1));
  expect(total, greaterThan(100));
  expect(nonBlack / total, greaterThan(.1));
  expect(colors.length, greaterThan(32));
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() ready,
  String label, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      debugPrint('[ReadonlyTest] failed: $label');
      fail('Timed out: $label');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  debugPrint('[ReadonlyTest] passed: $label');
}

// Never saves actual account/video/chat pixels; outputs aggregate numbers only.
Future<void> _probeReadonlyVideoFrames(
  WidgetTester tester,
  TwitchWatchPageState state, {
  void Function(Map<String, Object?> summary)? onNativeSummary,
  void Function(Map<String, num> summary)? onFlutterSummary,
  Future<Uint8List?> Function()? captureNativeForTesting,
}) async {
  var stage = 'native_capture';
  Map<String, num>? nativeCenter;
  var nativeWidth = 0;
  var nativeHeight = 0;
  var nativePositionMs = 0;
  final player = state.playerSession.playerOrNull;
  if (player == null) return;
  try {
    final encoded =
        await (captureNativeForTesting?.call() ?? player.screenshot()).timeout(
          const Duration(seconds: 2),
        );
    if (encoded == null) {
      debugPrint('[ReadonlyTest] frame probe nativeAvailable=false');
    } else {
      stage = 'native_pixels';
      final codec = await instantiateImageCodec(encoded);
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final pixels = await image.toByteData(
            format: ImageByteFormat.rawRgba,
          );
          final summary = twitchFramePixelSummary(
            rgba: pixels!.buffer.asUint8List(
              pixels.offsetInBytes,
              pixels.lengthInBytes,
            ),
            width: image.width,
            height: image.height,
          );
          nativeCenter = twitchCentralFramePixelSummary(
            rgba: pixels.buffer.asUint8List(
              pixels.offsetInBytes,
              pixels.lengthInBytes,
            ),
            width: image.width,
            height: image.height,
          );
          nativeWidth = image.width;
          nativeHeight = image.height;
          nativePositionMs = player.state.position.inMilliseconds;
          debugPrint(
            '[ReadonlyTest] frame probe layer=native positionMs=${player.state.position.inMilliseconds} width=${image.width} height=${image.height} summary=$summary',
          );
          onNativeSummary?.call(summary);
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
  } catch (error) {
    debugPrint(
      '[ReadonlyTest] frame probe stage=$stage errorType=${error.runtimeType}',
    );
  }
  // Native capture can be unavailable before decoding. Still inspect the
  // Flutter surface independently rather than losing both layers of evidence.
  try {
    stage = 'flutter_boundary';
    final surfaces = find.byType(TwitchMediaKitVideoSurface);
    final textures = find.byType(Texture);
    if (surfaces.evaluate().isEmpty || textures.evaluate().isEmpty) {
      debugPrint('[ReadonlyTest] frame probe flutterAvailable=false');
      return;
    }
    final boundary = tester
        .element(surfaces.first)
        .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
    if (boundary == null) {
      debugPrint('[ReadonlyTest] frame probe flutterBoundaryAvailable=false');
      return;
    }
    stage = 'flutter_capture';
    final image = await boundary
        .toImage(pixelRatio: 1)
        .timeout(const Duration(seconds: 2));
    try {
      stage = 'flutter_pixels';
      final pixels = await image.toByteData(format: ImageByteFormat.rawRgba);
      final texture = tester.getRect(textures.first);
      final sample = Rect.fromCenter(
        center: texture.center - boundary.localToGlobal(Offset.zero),
        width: texture.width * .6,
        height: texture.height * .6,
      );
      final summary = twitchFramePixelSummary(
        rgba: pixels!.buffer.asUint8List(
          pixels.offsetInBytes,
          pixels.lengthInBytes,
        ),
        width: image.width,
        height: image.height,
        left: sample.left.ceil(),
        top: sample.top.ceil(),
        right: sample.right.floor(),
        bottom: sample.bottom.floor(),
      );
      debugPrint('[ReadonlyTest] frame probe layer=flutter summary=$summary');
      onFlutterSummary?.call(summary);
      final relativeAspectError = texture.width > 0 && texture.height > 0
          ? ((nativeWidth / nativeHeight) / (texture.width / texture.height) -
                    1)
                .abs()
          : double.infinity;
      if (nativeCenter != null) {
        debugPrint(
          '[ReadonlyTest] matched central frame probe native=$nativeCenter flutter=$summary aspectMatches=${relativeAspectError < .02} positionDeltaMs=${player.state.position.inMilliseconds - nativePositionMs} paused=${!player.state.playing}',
        );
      }
    } finally {
      image.dispose();
    }
  } catch (error) {
    debugPrint(
      '[ReadonlyTest] frame probe stage=$stage errorType=${error.runtimeType}',
    );
  }
}

Future<void> _exerciseEmptyInitializationNative(
  WidgetTester tester,
  List<int> mediaBytes,
  int fragmentOffset, {
  bool replaceInitialization = false,
  bool reopenDuringInitialization = false,
  bool resetFragmentTimestamps = false,
}) async {
  expect(!reopenDuringInitialization || replaceInitialization, isTrue);
  expect(!resetFragmentTimestamps || replaceInitialization, isTrue);
  const resetCount = int.fromEnvironment(
    'TWITCH_READONLY_INIT_RESET_COUNT',
    defaultValue: 1,
  );
  expect(resetCount, inInclusiveRange(1, 24));
  expect(resetCount == 1 || resetFragmentTimestamps, isTrue);
  final upstream = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
  final validMapRelease = Completer<void>();
  var mapRequests = 0;
  var fragmentRequests = 0;
  var replacementSequence = 0;
  List<int>? baseAudioBytes;
  var baseAudioRequests = 0;
  final shiftedFragment = replaceInitialization
      ? twitchShiftFixtureFragment(
          initialization: mediaBytes.sublist(0, fragmentOffset),
          fragment: mediaBytes.sublist(fragmentOffset),
          seconds: resetFragmentTimestamps ? 0 : 3,
        )
      : null;
  final serving = upstream.listen((request) async {
    if (request.uri.path == '/base-control.mp4') {
      baseAudioRequests++;
      final bytes = baseAudioBytes!;
      final range = RegExp(
        r'^bytes=(\d+)-(\d*)$',
      ).firstMatch(request.headers.value(io.HttpHeaders.rangeHeader) ?? '');
      final start = range == null ? 0 : int.parse(range.group(1)!);
      final end = range == null || range.group(2)!.isEmpty
          ? bytes.length - 1
          : int.parse(range.group(2)!);
      if (start > end || end >= bytes.length) {
        request.response.statusCode = 416;
      } else {
        request.response.headers.contentType = io.ContentType('video', 'mp4');
        request.response.headers.set('Accept-Ranges', 'bytes');
        if (range != null) {
          request.response.statusCode = 206;
          request.response.headers.set(
            'Content-Range',
            'bytes $start-$end/${bytes.length}',
          );
        }
        request.response.contentLength = end - start + 1;
        if (request.method != 'HEAD') {
          request.response.add(bytes.sublist(start, end + 1));
        }
      }
    } else if (request.uri.path == '/live.m3u8') {
      final sequence = replacementSequence;
      request.response.write(
        '#EXTM3U\n#EXT-X-TARGETDURATION:3\n#EXT-X-MEDIA-SEQUENCE:$sequence\n'
        '${resetFragmentTimestamps ? '#EXT-X-DISCONTINUITY-SEQUENCE:${sequence == 0 ? 0 : sequence - 1}\n' : ''}'
        '${sequence > 0 && resetFragmentTimestamps ? '#EXT-X-DISCONTINUITY\n' : ''}'
        '#EXT-X-MAP:URI="/init$sequence.mp4"\n#EXTINF:2.769,\n/segment$sequence.m4s\n',
      );
    } else if (request.uri.path.startsWith('/init')) {
      mapRequests++;
      if (replaceInitialization || mapRequests > 1) {
        if (!replaceInitialization || request.uri.path == '/init1.mp4') {
          await validMapRelease.future;
        }
        request.response.add(mediaBytes.sublist(0, fragmentOffset));
        if (request.uri.path != '/init0.mp4') {
          // Different map bytes/URI, same codec configuration for this fixture.
          request.response.add([0, 0, 0, 12, ...'free'.codeUnits, 1, 2, 3, 4]);
        }
      }
    } else {
      fragmentRequests++;
      request.response.add(
        request.uri.path != '/segment0.m4s'
            ? shiftedFragment!
            : mediaBytes.sublist(fragmentOffset),
      );
    }
    await request.response.close();
  });
  final router = TwitchStableHlsProxyRouter(
    upstreamHeaders: const {},
    outputFutureSegments: false,
    prefetchSegmentCount: 0,
    startupMode: TwitchHlsStartupMode.latestNormalImmediate,
  );
  const enableAudio = bool.fromEnvironment('TWITCH_READONLY_INIT_NATIVE_AUDIO');
  const audioFileControl = bool.fromEnvironment(
    'TWITCH_READONLY_INIT_AUDIO_FILE_CONTROL',
  );
  const baseAudioControl = bool.fromEnvironment(
    'TWITCH_READONLY_INIT_AUDIO_BASE_CONTROL',
  );
  expect(!baseAudioControl || audioFileControl, isTrue);
  expect(!audioFileControl || enableAudio, isTrue);
  final player = await Player.create(
    configuration: PlayerConfiguration(
      options: enableAudio
          ? const {
              'aid': 'auto',
              'volume': '0',
              'mute': 'yes',
              'video-sync': 'audio',
            }
          : const {'aid': 'no'},
    ),
  );
  void verifyMutedAudio() {
    if (!enableAudio) return;
    final properties = twitchNativePlaybackProperties(player.getProperty);
    expect(
      int.tryParse(properties['audio-params/samplerate'] ?? ''),
      greaterThan(0),
    );
    expect(
      int.tryParse(properties['audio-out-params/samplerate'] ?? ''),
      greaterThan(0),
    );
    expect(properties['mute'], 'yes');
    final avsync = double.tryParse(properties['avsync'] ?? '');
    expect(
      avsync,
      isNotNull,
      reason: 'Missing sync property is not zero drift.',
    );
    expect(avsync!.abs(), lessThan(.25));
    debugPrint(
      '[ReadonlyTest] muted native audio positionMs=${player.state.position.inMilliseconds} properties=$properties',
    );
  }

  final diagnostics = TwitchNativeLogDiagnostics();
  final logs = player.stream.log.listen((log) => diagnostics.record(log.text));
  TwitchMediaKitPlayerSession? surfaceSession;
  try {
    if (baseAudioControl) {
      final downloadClient = io.HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await downloadClient.getUrl(
          Uri.parse(
            'https://raw.githubusercontent.com/chromium/chromium/main/media/test/data/bear-1280x720.mp4',
          ),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        expect(response.statusCode, 200);
        final bytes = <int>[];
        await for (final chunk in response.timeout(
          const Duration(seconds: 8),
        )) {
          if (bytes.length + chunk.length > 8 * 1024 * 1024) {
            throw StateError('Public fixture exceeds memory limit');
          }
          bytes.addAll(chunk);
        }
        baseAudioBytes = bytes;
        debugPrint(
          '[ReadonlyTest] public base audio fixture bytes=${bytes.length}',
        );
      } finally {
        downloadClient.close(force: true);
      }
    }
    if (!audioFileControl) {
      await router.start(
        upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/live.m3u8',
      );
    }
    expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
    // ignore: invalid_use_of_visible_for_testing_member
    TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
    SharedPreferences.setMockInitialValues({});
    surfaceSession = TwitchMediaKitPlayerHost.acquire();
    await surfaceSession.ensureReady();
    final session = _LocalWatchSession(player, surfaceSession: surfaceSession);
    final services = watch_fixture.isolatedWatchPlaybackServices(
      session: session,
      runtime: _LocalWatchRuntime(
        baseAudioControl
            ? Uri.parse('http://127.0.0.1:${upstream.port}/base-control.mp4')
            : audioFileControl
            ? Uri.file(
                'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-decoder-fixture.mp4',
              )
            : Uri.parse(router.streamTsUrl),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        child: MaterialApp(
          home: TwitchWatchPage(
            initialChannelLogin: 'fixture',
            initialServices: services,
            initialChatRuntimeFactory: watch_fixture.isolatedWatchChatRuntime,
          ),
        ),
      ),
    );
    await waitFor(
      tester,
      () =>
          session.opens == 1 &&
          (audioFileControl || mapRequests >= (replaceInitialization ? 1 : 2)),
      'initialization test native open starts',
    );
    if (audioFileControl) {
      final directClock = Stopwatch()..start();
      var nextDirectLog = 2;
      await waitFor(tester, () {
        if (directClock.elapsed.inSeconds >= nextDirectLog) {
          nextDirectLog += 10;
          debugPrint(
            '[ReadonlyTest] direct audio file seconds=${directClock.elapsed.inSeconds} positionMs=${player.state.position.inMilliseconds} properties=${twitchNativePlaybackProperties(player.getProperty)} categories=${diagnostics.snapshot}',
          );
        }
        return player.state.position.inMilliseconds > 500 &&
            !player.state.buffering;
      }, 'direct audio fixture decodes without proxy');
      verifyMutedAudio();
      expect(router.streamReadDiagnostics['requests'], 0);
      expect(mapRequests, 0);
      expect(fragmentRequests, 0);
      debugPrint(
        '[ReadonlyTest] direct audio file control passed base=$baseAudioControl bytes=${baseAudioBytes?.length ?? 0} requests=$baseAudioRequests opens=${session.opens}',
      );
      return;
    }
    final clock = Stopwatch()..start();
    while ((await router.requestLiveStatus())?.activeClientCount != 1) {
      if (clock.elapsed > const Duration(seconds: 5)) {
        fail('Native empty-map reader did not attach.');
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
    if (replaceInitialization) {
      final firstDecodeClock = Stopwatch()..start();
      var nextFirstDecodeLog = 2;
      await waitFor(tester, () {
        if (enableAudio &&
            firstDecodeClock.elapsed.inSeconds >= nextFirstDecodeLog) {
          nextFirstDecodeLog += 10;
          debugPrint(
            '[ReadonlyTest] first audio decode seconds=${firstDecodeClock.elapsed.inSeconds} positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} properties=${twitchNativePlaybackProperties(player.getProperty)} transport=${router.streamReadDiagnostics} categories=${diagnostics.snapshot}',
          );
        }
        return player.state.playing &&
            !player.state.buffering &&
            player.state.position.inMilliseconds > 500;
      }, 'first map decodes before initialization replacement');
      replacementSequence = 1;
      await waitFor(
        tester,
        () => mapRequests >= 2,
        'replacement initialization waits before second fragment',
      );
      expect(fragmentRequests, 1);
      expect(
        (await router.requestLiveStatus())?.bufferedBytes,
        mediaBytes.length - fragmentOffset,
      );
      if (reopenDuringInitialization) {
        await session.openOrResume(uri: router.streamTsUrl, forceOpen: true);
        await waitFor(
          tester,
          () =>
              router.streamReadDiagnostics['requests'] == 2 &&
              player.state.playing &&
              !player.state.buffering &&
              player.state.position.inMilliseconds > 500,
          'native reopens old complete replay while replacement map is pending',
        );
        expect(validMapRelease.isCompleted, isFalse);
        expect(fragmentRequests, 1);
        expect(mapRequests, 2);
        expect(session.opens, 2);
        expect(router.streamReadDiagnostics['startsWithMp4Init'], isTrue);
        debugPrint(
          '[ReadonlyTest] pending map native reopened positionMs=${player.state.position.inMilliseconds} opens=${session.opens} transport=${router.streamReadDiagnostics}',
        );
      }
    } else {
      expect(fragmentRequests, 0);
      expect(player.state.position, Duration.zero);
    }
    validMapRelease.complete();
    final decodeAfterMapClock = Stopwatch()..start();
    var nextMapLog = 2;
    await waitFor(tester, () {
      if (resetFragmentTimestamps &&
          decodeAfterMapClock.elapsed.inSeconds >= nextMapLog) {
        nextMapLog += 2;
        debugPrint(
          '[ReadonlyTest] reset timestamp native seconds=${decodeAfterMapClock.elapsed.inSeconds} positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} mapRequests=$mapRequests fragmentRequests=$fragmentRequests properties=${twitchNativePlaybackProperties(player.getProperty)} transport=${router.streamReadDiagnostics} categories=${diagnostics.snapshot}',
        );
      }
      return player.state.playing &&
          !player.state.buffering &&
          player.state.position.inMilliseconds >
              (replaceInitialization ? 3500 : 500);
    }, 'same native open decodes after initialization change');
    verifyMutedAudio();
    for (var sequence = 2; sequence <= resetCount; sequence++) {
      replacementSequence = sequence;
      await waitFor(
        tester,
        () =>
            player.state.playing &&
            !player.state.buffering &&
            player.state.position.inMilliseconds > sequence * 2769 + 500,
        'native advances across reset boundary $sequence',
      );
      expect(session.opens, reopenDuringInitialization ? 2 : 1);
      expect(mapRequests, sequence + 1);
      expect(fragmentRequests, sequence + 1);
      verifyMutedAudio();
      debugPrint(
        '[ReadonlyTest] repeated native reset sequence=$sequence positionMs=${player.state.position.inMilliseconds} buffering=${player.state.buffering} transport=${router.streamReadDiagnostics}',
      );
    }
    expect(session.opens, reopenDuringInitialization ? 2 : 1);
    await player.pause();
    await tester.pump(const Duration(milliseconds: 100));
    final state = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    num? nonBlack;
    await _probeReadonlyVideoFrames(
      tester,
      state,
      onNativeSummary: (summary) =>
          nonBlack = summary['nonBlackFraction'] as num?,
    );
    expect(nonBlack, greaterThan(.1));
    expect(fragmentRequests, replaceInitialization ? resetCount + 1 : 1);
    debugPrint(
      '[ReadonlyTest] initialization native replacement=$replaceInitialization mapRequests=$mapRequests fragmentRequests=$fragmentRequests opens=${session.opens} positionMs=${player.state.position.inMilliseconds} nonBlack=$nonBlack properties=${twitchNativePlaybackProperties(player.getProperty)} transport=${router.streamReadDiagnostics} categories=${diagnostics.snapshot}',
    );
    await player.play();
    // The live proxy intentionally keeps HTTP open for future segments; a
    // finite media body does not imply EOF on this persistent stream.
    final resumedPosition = player.state.position;
    await waitFor(
      tester,
      () =>
          !player.state.buffering &&
          player.state.position >
              resumedPosition + const Duration(milliseconds: 400),
      'empty-map recovered source advances after UI capture pause',
    );
    expect(session.opens, reopenDuringInitialization ? 2 : 1);
  } finally {
    if (enableAudio) {
      debugPrint(
        '[ReadonlyTest] audio fixture final positionMs=${player.state.position.inMilliseconds} properties=${twitchNativePlaybackProperties(player.getProperty)} transport=${router.streamReadDiagnostics} categories=${diagnostics.snapshot}',
      );
    }
    if (!validMapRelease.isCompleted) validMapRelease.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    surfaceSession?.release();
    await logs.cancel();
    await TwitchMediaKitPlayerHost.disposeNow();
    await router.close();
    await upstream.close(force: true);
    await serving.cancel();
  }
}

Future<void> exerciseLiveRoutes(
  WidgetTester tester,
  TwitchWatchPageState firstWatch,
  TwitchDiscoveryService discovery,
  bool keepMini,
  void Function(String) phase,
) async {
  final firstLogin = firstWatch.channelLogin;
  final firstChat = firstWatch.chatRuntime;
  final firstMedia = TwitchMediaKitPlayerHost.currentMediaUri;
  final firstUpstream =
      firstWatch.watchPorts.player.runtime.upstreamPlaylistUri;
  expect(firstMedia?.isNotEmpty, isTrue);
  expect(firstUpstream != null, isTrue);
  expect(firstChat?.channelLogin == firstLogin, isTrue);
  final mini = TwitchMiniPlayerController.instance;
  final dragFailures = <String>[];
  Future<void> goHome() async {
    final overlay = find.byType(WatchControlsOverlay);
    await tester.tap(overlay);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.home_rounded))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () =>
          find.byType(TwitchWatchPage).evaluate().isEmpty &&
          find.byType(TwitchStreamPage).evaluate().isNotEmpty,
      'home button returns to original home route',
    );
    expect(mini.isActive, keepMini);
  }

  Future<void> sampleRail(String label) async {
    final offsets = <double>[];
    for (var sample = 0; sample < 12; sample++) {
      final rail = find.descendant(
        of: find.byType(TwitchWatchPage),
        matching: find.byType(TwitchFollowedLiveRailShell),
      );
      expect(rail, findsOneWidget);
      final widget = tester.widget<TwitchFollowedLiveRailShell>(rail);
      offsets.add(tester.getTopLeft(find.byWidget(widget.child)).dx);
      await tester.pump(const Duration(milliseconds: 100));
    }
    final sorted = offsets.toList()..sort();
    expect(sorted.last - sorted.first, lessThan(0.5));
    debugPrint(
      '[ReadonlyTest] passed: $label rail child offset stable samples=${offsets.length}',
    );
  }

  phase('mini');
  await goHome();
  expect(firstWatch.mounted, isFalse);
  await waitFor(
    tester,
    () => firstChat?.connected == false,
    'departed channel chat disconnects',
  );
  if (keepMini) {
    expect(mini.entry?.metadata.channelLogin == firstLogin, isTrue);
    expect(mini.entry?.mediaUri == firstMedia, isTrue);
    await waitFor(
      tester,
      () =>
          TwitchMediaKitPlayerHost.playerOrNull?.state.playing == true &&
          TwitchMediaKitPlayerHost.playerOrNull?.state.buffering == false,
      'mini player has active decoded playback',
    );
    final beforeMini = TwitchMediaKitPlayerHost.playerOrNull!.state.position;
    await tester.pump(const Duration(seconds: 3));
    expect(
      TwitchMediaKitPlayerHost.playerOrNull!.state.position - beforeMini,
      greaterThan(const Duration(seconds: 1)),
    );
    debugPrint('[ReadonlyTest] passed: mini player position advances');
    final miniVideo = find.descendant(
      of: find.byType(TwitchMiniPlayerOverlay),
      matching: find.byType(AspectRatio),
    );
    expect(miniVideo, findsOneWidget);
    Future<void> sampleMiniDrag(
      String label,
      Finder target,
      PointerDeviceKind kind,
    ) async {
      final origin = tester.getRect(miniVideo);
      final gesture = await tester.startGesture(
        tester.getCenter(target),
        kind: kind,
      );
      double distance = 0;
      try {
        await gesture.moveBy(
          const Offset(-20, -15),
          timeStamp: const Duration(milliseconds: 100),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveBy(
          const Offset(-40, -30),
          timeStamp: const Duration(milliseconds: 200),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final moved = tester.getRect(miniVideo);
        distance = (moved.topLeft - origin.topLeft).distance;
        if (distance <= 10 || moved.left < 0 || moved.top < 0) {
          dragFailures.add(label);
        }
        expect(mini.entry?.mediaUri, firstMedia);
      } finally {
        await gesture.up(timeStamp: const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 200));
      }
      final returnDistance =
          (tester.getRect(miniVideo).topLeft - origin.topLeft).distance;
      if (returnDistance >= 0.5) dragFailures.add('$label-return');
      debugPrint(
        '[ReadonlyTest] mini drag target=$label movedPixels=${distance.toStringAsFixed(2)} returnPixels=${returnDistance.toStringAsFixed(2)}',
      );
    }

    await sampleMiniDrag('video-touch', miniVideo, PointerDeviceKind.touch);
    await sampleMiniDrag('video-mouse', miniVideo, PointerDeviceKind.mouse);
    final miniTitle = find
        .descendant(
          of: find.byType(TwitchMiniPlayerOverlay),
          matching: find.text(firstLogin),
        )
        .hitTestable();
    expect(miniTitle, findsOneWidget);
    await sampleMiniDrag('footer-mouse', miniTitle, PointerDeviceKind.mouse);
    final afterDrag = TwitchMediaKitPlayerHost.playerOrNull!.state.position;
    await tester.pump(const Duration(seconds: 3));
    expect(
      TwitchMediaKitPlayerHost.playerOrNull!.state.position - afterDrag,
      greaterThan(const Duration(seconds: 1)),
    );
    debugPrint(
      '[ReadonlyTest] passed: mini playback advances after drag samples; failedSamples=${dragFailures.length}',
    );
    await tester.tapAt(tester.getCenter(miniVideo));
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      'mini video click expands watch route',
    );
    phase('restored-live');
    final restored = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    expect(restored.channelLogin == firstLogin, isTrue);
    expect(identical(restored, firstWatch), isFalse);
    expect(identical(restored.authService, discovery.authService), isTrue);
    await sampleRail('restored route');
    await waitFor(
      tester,
      () =>
          !mini.isActive &&
          restored.chatRuntime?.connected == true &&
          restored.chatRuntime?.channelLogin == firstLogin,
      'restored route owns playback and fresh channel chat',
      timeout: const Duration(seconds: 70),
    );
    expect(identical(restored.chatRuntime, firstChat), isFalse);
    expect(TwitchMediaKitPlayerHost.currentMediaUri == firstMedia, isTrue);
    final beforeRestore = restored.playerSession.player.state.position;
    await tester.pump(const Duration(seconds: 3));
    expect(
      restored.playerSession.player.state.position - beforeRestore,
      greaterThan(const Duration(seconds: 1)),
    );
    await goHome();
    expect(restored.mounted, isFalse);
    await tester.tap(
      find
          .descendant(
            of: find.byType(TwitchMiniPlayerOverlay),
            matching: find.byIcon(Icons.close_rounded),
          )
          .hitTestable(),
    );
    await waitFor(
      tester,
      () => !mini.isActive,
      'mini close button removes playback surface',
    );
  } else {
    debugPrint('[ReadonlyTest] unavailable: mini expand preference disabled');
  }
  await waitFor(
    tester,
    () => TwitchMediaKitPlayerHost.playerOrNull?.state.playing != true,
    'closed home playback is paused',
  );
  phase('home');
  final alternative = find
      .byWidgetPredicate(
        (widget) =>
            widget is TwitchStreamCard &&
            widget.stream.channelLogin != firstLogin,
      )
      .hitTestable();
  await waitFor(
    tester,
    () => alternative.evaluate().isNotEmpty,
    'another visible browse channel is available',
  );
  final secondStream = tester
      .widget<TwitchStreamCard>(alternative.first)
      .stream;
  await tester.tap(alternative.first);
  await waitFor(
    tester,
    () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
    'second channel card opens watch route',
  );
  phase('second-live');
  final second = tester.state<TwitchWatchPageState>(
    find.byType(TwitchWatchPage),
  );
  expect(second.channelLogin == secondStream.channelLogin, isTrue);
  expect(second.channelLogin != firstLogin, isTrue);
  expect(identical(second.authService, discovery.authService), isTrue);
  await sampleRail('second channel');
  await waitFor(
    tester,
    () =>
        second.chatRuntime?.connected == true &&
        second.chatRuntime?.channelLogin == secondStream.channelLogin,
    'second channel chat connects to selected channel',
    timeout: const Duration(seconds: 70),
  );
  expect(identical(second.chatRuntime, firstChat), isFalse);
  expect(second.chatController.isReadOnlyGuest, isFalse);
  await waitFor(
    tester,
    () =>
        second.playerSession.playerOrNull?.state.playing == true &&
        second.playerSession.playerOrNull?.state.buffering == false &&
        second.playerSession.playerOrNull!.state.position > Duration.zero,
    'second channel decoded playback starts',
    timeout: const Duration(seconds: 90),
  );
  final owned = TwitchPlaybackSessionController.instance.playableState;
  final secondRuntime = second.watchPorts.player.runtime;
  final upstream = secondRuntime.upstreamPlaylistUri;
  final upstreamChanged = upstream != null && upstream != firstUpstream;
  final proxyMatches =
      secondRuntime.proxy?.upstreamPlaylistUrl == upstream?.toString();
  debugPrint(
    '[ReadonlyTest] second ownership present=${owned != null} channelMatches=${owned?.metadata.channelLogin == secondStream.channelLogin} uriMatches=${owned?.mediaUri == TwitchMediaKitPlayerHost.currentMediaUri} upstreamChanged=$upstreamChanged proxyMatches=$proxyMatches',
  );
  expect(owned?.metadata.channelLogin == secondStream.channelLogin, isTrue);
  expect(owned?.mediaUri == TwitchMediaKitPlayerHost.currentMediaUri, isTrue);
  // The stable router deliberately retains its loopback URL across channels.
  // Verify the changed upstream and its actual router/variant binding instead.
  expect(upstreamChanged, isTrue);
  expect(proxyMatches, isTrue);
  expect(secondRuntime.channelLogin == secondStream.channelLogin, isTrue);
  expect(secondRuntime.currentVariant?.url == upstream?.toString(), isTrue);
  final beforeSecond = second.playerSession.player.state.position;
  await tester.pump(const Duration(seconds: 15));
  expect(
    second.playerSession.player.state.position - beforeSecond,
    greaterThan(const Duration(seconds: 10)),
  );
  debugPrint('[ReadonlyTest] passed: second channel advances for 15 seconds');
  const railSwitch = bool.fromEnvironment('TWITCH_READONLY_RAIL_SWITCH');
  if (railSwitch) {
    final rail = find.descendant(
      of: find.byType(TwitchWatchPage),
      matching: find.byType(TwitchFollowedLiveRailShell),
    );
    expect(tester.widget<TwitchFollowedLiveRailShell>(rail).enabled, isTrue);
    final dynamic railState = tester.state(rail);
    await waitFor(
      tester,
      () => railState.loading == false,
      'followed rail finishes loading before selection',
    );
    final candidates = (railState.streams as List<TwitchLiveStream>)
        .where((stream) => stream.channelLogin != second.channelLogin)
        .toList();
    debugPrint(
      '[ReadonlyTest] followed rail candidates=${candidates.length} failed=${railState.failed}',
    );
    if (candidates.isEmpty) {
      debugPrint(
        '[ReadonlyTest] unavailable: no different followed live channel',
      );
      fail('A different followed live channel is required for rail coverage.');
    }
    final target = candidates.first;
    final targetKey = ValueKey('live-rail-${target.userId}');
    final targetEntry = find.descendant(
      of: rail,
      matching: find.byKey(targetKey),
    );
    await tester.scrollUntilVisible(
      targetEntry,
      200,
      scrollable: find
          .descendant(of: rail, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 60,
    );
    final previousChat = second.chatRuntime;
    final previousUpstream = secondRuntime.upstreamPlaylistUri;
    await tester.tap(targetEntry.hitTestable());
    await waitFor(tester, () {
      final route = find.byType(TwitchWatchPage);
      if (route.evaluate().length != 1) return false;
      final state = tester.state<TwitchWatchPageState>(route);
      return !identical(state, second) &&
          state.channelLogin == target.channelLogin;
    }, 'followed rail click replaces watch with selected channel');
    phase('rail-live');
    final selected = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    expect(second.mounted, isFalse);
    expect(identical(selected.authService, discovery.authService), isTrue);
    await sampleRail('rail-selected channel');
    await waitFor(
      tester,
      () =>
          previousChat?.connected == false &&
          selected.chatRuntime?.connected == true &&
          selected.chatRuntime?.channelLogin == target.channelLogin,
      'rail-selected channel has fresh chat and old chat disconnects',
      timeout: const Duration(seconds: 70),
    );
    expect(identical(selected.chatRuntime, previousChat), isFalse);
    expect(selected.chatController.isReadOnlyGuest, isFalse);
    final runtime = selected.watchPorts.player.runtime;
    await waitFor(
      tester,
      () =>
          runtime.channelLogin == target.channelLogin &&
          runtime.upstreamPlaylistUri != null &&
          runtime.upstreamPlaylistUri != previousUpstream &&
          runtime.proxy?.upstreamPlaylistUrl ==
              runtime.upstreamPlaylistUri?.toString() &&
          runtime.currentVariant?.url ==
              runtime.upstreamPlaylistUri?.toString() &&
          selected.playerSession.playerOrNull?.state.playing == true &&
          selected.playerSession.playerOrNull?.state.buffering == false &&
          selected.playerSession.playerOrNull!.state.position > Duration.zero,
      'rail-selected channel binds new upstream and decoded playback',
      timeout: const Duration(seconds: 90),
    );
    final owner = TwitchPlaybackSessionController.instance.playableState;
    expect(owner?.metadata.channelLogin == target.channelLogin, isTrue);
    expect(owner?.mediaUri == TwitchMediaKitPlayerHost.currentMediaUri, isTrue);
    final selectedEntry = find.byKey(targetKey);
    expect(selectedEntry, findsOneWidget);
    expect(tester.widget<InkWell>(selectedEntry).onTap, isNull);
    final semantics = tester.widget<Semantics>(
      find.ancestor(of: selectedEntry, matching: find.byType(Semantics)).first,
    );
    expect(semantics.properties.selected, isTrue);
    await tester.tap(selectedEntry.hitTestable());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.state(find.byType(TwitchWatchPage)), same(selected));
    debugPrint(
      '[ReadonlyTest] passed: selected rail entry is marked and does not reopen route',
    );
    final beforeRail = selected.playerSession.player.state.position;
    await tester.pump(const Duration(seconds: 15));
    expect(
      selected.playerSession.player.state.position - beforeRail,
      greaterThan(const Duration(seconds: 10)),
    );
    debugPrint(
      '[ReadonlyTest] passed: rail-selected channel advances for 15 seconds',
    );
  }
  expect(dragFailures, isEmpty, reason: 'Mini drag failures: $dragFailures');
}

Future<void> exerciseMediaMiniRoutes(
  WidgetTester tester,
  TwitchDiscoveryService discovery,
  TwitchFollowedChannel channel,
  void Function(String) phase,
) async {
  final videos = await discovery.fetchChannelVideos(
    userId: channel.broadcasterId,
    first: 20,
  );
  final clips = await discovery.fetchChannelClips(
    broadcasterId: channel.broadcasterId,
    first: 30,
  );
  final completed = videos.videos.where((v) => !v.isLikelyGrowingArchive);
  final longClips = clips.clips.where((c) => c.duration >= 40);
  expect(completed, isNotEmpty);
  expect(longClips, isNotEmpty);
  final video = completed.first;
  final clip = longClips.first;
  final mini = TwitchMiniPlayerController.instance;

  Future<void> goHome(String label) async {
    final overlay = find.byType(WatchControlsOverlay);
    await tester.tap(overlay);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.home_rounded))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isEmpty,
      '$label returns to home',
    );
    expect(find.byType(TwitchStreamPage), findsOneWidget);
    expect(mini.isActive, isTrue);
  }

  const clipFirst = bool.fromEnvironment('TWITCH_READONLY_MINI_CLIP_FIRST');
  for (final isVod in (clipFirst ? [false, true] : [true, false])) {
    final label = isVod ? 'VOD' : 'clip';
    phase('mini-$label-entry');
    // Direct production route isolates mini handoff, not media-card wiring.
    unawaited(
      Navigator.of(tester.element(find.byType(TwitchStreamPage))).push<void>(
        MaterialPageRoute(
          builder: (_) => TwitchWatchRouteGuard(
            initialChannelLogin: channel.channelLogin,
            initialDiscoveryService: discovery,
            initialVodVideo: isVod ? video : null,
            initialClip: isVod ? null : clip,
            initialVodPlaybackOnly: isVod,
          ),
        ),
      ),
    );
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      '$label mini source route mounted',
    );
    final source = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    final decodeClock = Stopwatch()..start();
    var nextDecodeLog = 10;
    await waitFor(
      tester,
      () {
        final state = source.playerSession.playerOrNull?.state;
        if (decodeClock.elapsed.inSeconds >= nextDecodeLog) {
          nextDecodeLog += 10;
          debugPrint(
            '[ReadonlyTest] $label mini source decode seconds=${decodeClock.elapsed.inSeconds} playerPresent=${state != null} playing=${state?.playing} buffering=${state?.buffering} positionMs=${state?.position.inMilliseconds} durationMs=${state?.duration.inMilliseconds}',
          );
        }
        return state != null &&
            state.playing &&
            !state.buffering &&
            state.position > Duration.zero;
      },
      '$label mini source decodes',
      timeout: const Duration(seconds: 90),
    );
    final uri = TwitchMediaKitPlayerHost.currentMediaUri;
    final kind = source.buildPlaybackSnapshot()!.kind;
    if (const bool.fromEnvironment('TWITCH_READONLY_LIVE_FORMAT_SCAN')) {
      final candidates = <String>{
        for (final element
            in find.byType(TwitchStreamCard, skipOffstage: false).evaluate())
          (element.widget as TwitchStreamCard).stream.channelLogin,
      }.where((login) => login != channel.channelLogin).take(6).toList();
      expect(candidates, isNotEmpty);
      var fmp4Channels = 0;
      for (final login in candidates) {
        var hasFmp4 = false;
        for (final profile in const [
          (platform: 'web', playerType: 'site', source: 'web-site'),
          (
            platform: 'android',
            playerType: 'autoplay',
            source: 'android-autoplay',
          ),
          (platform: 'ios', playerType: 'site', source: 'ios-site'),
        ]) {
          final formats = await probeChannelLiveFormats(
            source.watchServices.playbackApi,
            login,
            platform: profile.platform,
            playerType: profile.playerType,
          );
          final sourceHasFmp4 = formats.any(
            (entry) => entry['format'] == 'fmp4',
          );
          hasFmp4 = hasFmp4 || sourceHasFmp4;
          debugPrint(
            '[ReadonlyTest] live format sample channel=$login source=${profile.source} variants=$formats hasFmp4=$sourceHasFmp4',
          );
        }
        if (hasFmp4) {
          fmp4Channels++;
        }
      }
      debugPrint(
        '[ReadonlyTest] live format scan channels=${candidates.length} fmp4Channels=$fmp4Channels',
      );
      return;
    }
    const pausedHandoff = bool.fromEnvironment('TWITCH_READONLY_MINI_PAUSED');
    if (pausedHandoff) {
      final overlay = find.byType(WatchControlsOverlay);
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find
            .descendant(of: overlay, matching: find.byIcon(Icons.pause))
            .hitTestable(),
      );
      await waitFor(
        tester,
        () => !source.playerSession.player.state.playing,
        '$label source paused by UI before handoff',
      );
    }
    await goHome(label);
    expect(source.mounted, isFalse);
    expect(mini.entry?.kind, kind);
    expect(mini.entry?.mediaUri, uri);
    expect(mini.entry?.resumeVodVideo?.id, isVod ? video.id : null);
    expect(mini.entry?.resumeClip?.id, isVod ? null : clip.id);
    if (pausedHandoff) {
      await tester.pump(const Duration(seconds: 2));
      expect(TwitchMediaKitPlayerHost.playerOrNull!.state.playing, isFalse);
      expect(mini.entry?.playOnOpen, isFalse);
      final pausedMiniPosition =
          TwitchMediaKitPlayerHost.playerOrNull!.state.position;
      await tester.pump(const Duration(seconds: 2));
      expect(
        (TwitchMediaKitPlayerHost.playerOrNull!.state.position -
                pausedMiniPosition)
            .inMilliseconds
            .abs(),
        lessThan(500),
      );
      debugPrint(
        '[ReadonlyTest] passed: $label paused source stays paused in mini',
      );
      await TwitchMediaKitPlayerHost.playerOrNull!.play();
    }
    await waitFor(tester, () {
      final state = TwitchMediaKitPlayerHost.playerOrNull?.state;
      return state != null && state.playing && !state.buffering;
    }, '$label mini decoded playback');
    const recovery = bool.fromEnvironment('TWITCH_READONLY_MINI_RECOVERY');
    if (recovery) {
      final player = TwitchMediaKitPlayerHost.playerOrNull!;
      await player.pause();
      mini.rememberNetworkLoss();
      final pausedPosition = player.state.position;
      await mini.recoverAfterNetworkRestored();
      await tester.pump(const Duration(seconds: 1));
      expect(player.state.playing, isFalse);
      expect(
        (player.state.position - pausedPosition).inMilliseconds.abs(),
        lessThan(500),
      );
      debugPrint(
        '[ReadonlyTest] passed: $label controlled recovery leaves paused mini paused',
      );
      await player.play();
      await waitFor(
        tester,
        () => player.state.playing && !player.state.buffering,
        '$label mini resumes before controlled loss',
      );
      mini.rememberNetworkLoss();
      await player.pause();
      final lossPosition = player.state.position;
      await mini.recoverAfterNetworkRestored();
      await waitFor(
        tester,
        () => player.state.playing && !player.state.buffering,
        '$label controlled recovery reopens decoded source',
        timeout: const Duration(seconds: 90),
      );
      expect(mini.entry?.mediaUri, uri);
      expect(TwitchMediaKitPlayerHost.currentMediaUri, uri);
      expect(
        (player.state.position - lossPosition).inMilliseconds.abs(),
        lessThan(10000),
      );
      final recoveredPosition = player.state.position;
      await tester.pump(const Duration(seconds: 3));
      expect(
        player.state.position - recoveredPosition,
        greaterThan(const Duration(seconds: 1)),
      );
      debugPrint(
        '[ReadonlyTest] passed: $label controlled recovery preserves source and advances',
      );
    }
    final before = TwitchMediaKitPlayerHost.playerOrNull!.state.position;
    await tester.pump(const Duration(seconds: 3));
    final after = TwitchMediaKitPlayerHost.playerOrNull!.state.position;
    expect(after - before, greaterThan(const Duration(seconds: 1)));
    debugPrint('[ReadonlyTest] passed: $label mini position advances');
    const switchDuringRecovery = bool.fromEnvironment(
      'TWITCH_READONLY_MINI_RECOVERY_SWITCH',
    );
    if (switchDuringRecovery) {
      var switchChannel = const String.fromEnvironment(
        'TWITCH_READONLY_RECOVERY_CHANNEL',
      );
      if (const bool.fromEnvironment('TWITCH_READONLY_FIND_FMP4')) {
        expect(switchChannel, isEmpty);
        final candidates = (await discovery.fetchFollowedLiveRailStreams())
            .where((stream) => stream.channelLogin != channel.channelLogin)
            .take(6)
            .toList();
        // Preflight uses public playback access, not the selected watch source.
        // REQUIRE_FMP4 below independently checks the actual App transport.
        final probeApi = TwitchPlaybackApiService(
          gql: TwitchGqlApiService(client: discovery.client),
        );
        debugPrint(
          '[ReadonlyTest] fMP4 preflight candidates=${candidates.length} context=anonymous-ios-site',
        );
        for (final candidate in candidates) {
          final formats = await tester.runAsync(
            () => probeChannelLiveFormats(
              probeApi,
              candidate.channelLogin,
              platform: 'ios',
            ),
          );
          debugPrint(
            '[ReadonlyTest] fMP4 preflight channel=${candidate.channelLogin} results=$formats',
          );
          if (formats?.any(
                (result) =>
                    result['format'] == 'fmp4' && result['hasInitMap'] == true,
              ) ==
              true) {
            switchChannel = candidate.channelLogin;
            break;
          }
        }
        expect(
          switchChannel,
          isNotEmpty,
          reason: 'No fMP4 source found within six currently-live samples.',
        );
      }
      if (switchChannel.isNotEmpty) {
        expect(switchChannel, matches(RegExp(r'^[a-z0-9_]+$')));
        await tester.enterText(
          find.descendant(
            of: find.byType(TwitchStreamHomeToolbar),
            matching: find.byType(TextField),
          ),
          switchChannel,
        );
        await tester.pump(const Duration(seconds: 1));
        final dynamic targetHome = tester.state(find.byType(TwitchStreamPage));
        await waitFor(
          tester,
          () => targetHome.loadingChannelSearch == false,
          'named recovery target search settled',
        );
        final bool liveMatch = targetHome.searchedLiveStreams.any(
          (dynamic stream) => stream.channelLogin == switchChannel,
        );
        final bool offlineMatch = targetHome.searchedOfflineChannels.any(
          (dynamic channel) => channel.channelLogin == switchChannel,
        );
        debugPrint(
          '[ReadonlyTest] named recovery search channel=$switchChannel liveMatch=$liveMatch offlineMatch=$offlineMatch error=${targetHome.channelSearchError != null}',
        );
        expect(
          liveMatch,
          isTrue,
          reason: 'The requested source must currently be live.',
        );
        await waitFor(
          tester,
          () => find
              .byWidgetPredicate(
                (widget) =>
                    widget is TwitchStreamCard &&
                    widget.stream.channelLogin == switchChannel,
              )
              .hitTestable()
              .evaluate()
              .isNotEmpty,
          'named recovery target live card visible',
        );
      }
      final cards = find
          .byWidgetPredicate(
            (widget) =>
                widget is TwitchStreamCard &&
                widget.stream.channelLogin != channel.channelLogin &&
                (switchChannel.isEmpty ||
                    widget.stream.channelLogin == switchChannel),
          )
          .hitTestable();
      expect(cards.evaluate(), isNotEmpty);
      final target = tester.widget<TwitchStreamCard>(cards.first).stream;
      mini.rememberNetworkLoss();
      var recoveryFinished = false;
      Object? recoveryError;
      bool? pendingAtNewOwner;
      bool? nativeOpenAtNewOwner;
      final restoreStartedBefore = TwitchMediaKitPlayerHost.restoreOpenStarted;
      final restoreCompletedBefore =
          TwitchMediaKitPlayerHost.restoreOpenCompleted;
      final owners = TwitchPlaybackSessionController.instance;
      final recoveryClock = Stopwatch()..start();
      int? newOwnerElapsedMs;
      void recordOwner() {
        if (owners.playableState?.metadata.channelLogin ==
            target.channelLogin) {
          pendingAtNewOwner ??= !recoveryFinished;
          nativeOpenAtNewOwner ??= TwitchMediaKitPlayerHost.restoreOpenPending;
          newOwnerElapsedMs ??= recoveryClock.elapsedMilliseconds;
        }
      }

      owners.addListener(recordOwner);
      const controlledRecovery = bool.fromEnvironment(
        'TWITCH_READONLY_CONTROLLED_RECOVERY',
      );
      final recoveryGate = controlledRecovery ? Completer<void>() : null;
      final pending = mini
          .recoverAfterNetworkRestored(
            beforeOpenForTesting: recoveryGate?.future,
          )
          .then<void>(
            (_) => recoveryFinished = true,
            onError: (Object error, StackTrace stack) {
              recoveryError = error;
              recoveryFinished = true;
            },
          );
      final pendingAtClick = !recoveryFinished;
      final nativeOpenAtClick = TwitchMediaKitPlayerHost.restoreOpenPending;
      Future<void>? playlistProbe;
      Future<void>? frameProbe;
      final playlistProbeClient = Dio();
      var segmentProbed = false;
      bool? selectedHasInitMap;
      Future<void> probePlaylist(TwitchPlaylistPlayerRuntime runtime) async {
        final upstream = runtime.upstreamPlaylistUri;
        if (upstream == null) return;
        try {
          final response = await playlistProbeClient
              .getUri<String>(
                upstream,
                options: Options(
                  responseType: ResponseType.plain,
                  headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
                  receiveTimeout: const Duration(seconds: 4),
                  sendTimeout: const Duration(seconds: 4),
                  validateStatus: (_) => true,
                ),
              )
              .timeout(const Duration(seconds: 5));
          final text = response.data ?? '';
          if (response.statusCode == 200 && text.contains('#EXTM3U')) {
            selectedHasInitMap = text.contains('#EXT-X-MAP:');
          }
          final markers = <String, bool>{
            for (final marker in [
              'stitched-ad',
              '#EXT-X-DATERANGE',
              '#EXT-X-DISCONTINUITY',
              'SCTE35',
            ])
              marker: text.toLowerCase().contains(marker.toLowerCase()),
          };
          debugPrint(
            '[ReadonlyTest] playlist probe status=${response.statusCode} hls=${text.contains('#EXTM3U')} variantMayHaveAds=${runtime.currentVariant?.hasAds} markers=$markers',
          );
          if (!segmentProbed &&
              response.statusCode == 200 &&
              text.contains('#EXTM3U')) {
            final mediaLines = text
                .split('\n')
                .map((line) => line.trim())
                .where((line) => line.isNotEmpty && !line.startsWith('#'))
                .toList();
            if (mediaLines.isNotEmpty) {
              segmentProbed = true;
              final segment = await playlistProbeClient
                  .getUri<ResponseBody>(
                    upstream.resolve(mediaLines.last),
                    options: Options(
                      responseType: ResponseType.stream,
                      headers: {
                        ...TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
                        'Range': 'bytes=0-4095',
                      },
                      receiveTimeout: const Duration(seconds: 4),
                      sendTimeout: const Duration(seconds: 4),
                      validateStatus: (_) => true,
                    ),
                  )
                  .timeout(const Duration(seconds: 5));
              final body = segment.data;
              final bytes = body == null
                  ? <int>[]
                  : await twitchReadMediaPrefix(
                      body.stream.timeout(const Duration(seconds: 4)),
                    );
              debugPrint(
                '[ReadonlyTest] upstream media probe status=${segment.statusCode} bytes=${bytes.length} hasInitMap=${text.contains('#EXT-X-MAP:')} hasByteRange=${text.contains('#EXT-X-BYTERANGE:')} hasAes128=${text.contains('METHOD=AES-128')} hasSampleAes=${text.contains('METHOD=SAMPLE-AES')} hints=${twitchMediaHeaderHints(bytes)}',
              );
            }
          }
        } catch (error) {
          debugPrint(
            '[ReadonlyTest] playlist probe errorType=${error.runtimeType}',
          );
        }
      }

      final nativeFlags = <String, int>{};
      final beforeMountDiagnostics = TwitchNativeLogDiagnostics();
      final afterMountDiagnostics = TwitchNativeLogDiagnostics();
      var selectedRouteMounted = false;
      final nativeLogs = TwitchMediaKitPlayerHost.playerOrNull!.stream.log
          .listen((log) {
            (selectedRouteMounted
                    ? afterMountDiagnostics
                    : beforeMountDiagnostics)
                .record(log.text);
            for (final flag in twitchNativeLogFlags(log.text)) {
              nativeFlags.update(flag, (count) => count + 1, ifAbsent: () => 1);
            }
          });
      phase('mini-$label-recovery-switch');
      try {
        await tester.tap(cards.first);
        await waitFor(
          tester,
          () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
          'recovery switch opens selected home card',
        );
        final selected = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(selected.channelLogin, target.channelLogin);
        selectedRouteMounted = true;
        final pendingAtMount = !recoveryFinished;
        final nativeOpenAtMount = TwitchMediaKitPlayerHost.restoreOpenPending;
        if (recoveryGate == null) {
          await pending.timeout(const Duration(seconds: 90));
        }
        final switchClock = Stopwatch()..start();
        var nextSwitchLog = 10;
        await waitFor(
          tester,
          () {
            final state = selected.playerSession.playerOrNull?.state;
            if (switchClock.elapsed.inSeconds >= nextSwitchLog) {
              nextSwitchLog += 10;
              final runtime = selected.watchPorts.player.runtime;
              playlistProbe ??= probePlaylist(
                runtime,
              ).whenComplete(() => playlistProbe = null);
              frameProbe ??= _probeReadonlyVideoFrames(
                tester,
                selected,
              ).whenComplete(() => frameProbe = null);
              final proxyStatus = runtime.proxyLiveStatus;
              debugPrint(
                '[ReadonlyTest] native reader transport=${runtime.proxy?.streamReadDiagnostics}',
              );
              unawaited(runtime.refreshProxyLiveStatus(notify: false));
              final nativeProperties = twitchNativePlaybackProperties(
                selected.playerSession.player.getProperty,
              );
              debugPrint(
                '[ReadonlyTest] switch native properties=$nativeProperties',
              );
              debugPrint(
                '[ReadonlyTest] switch native categories beforeMount=${beforeMountDiagnostics.snapshot} afterMount=${afterMountDiagnostics.snapshot}',
              );
              debugPrint(
                '[ReadonlyTest] switch diagnostics channel=${target.channelLogin} proxyRunning=${runtime.proxy?.isRunning} innerRunning=${runtime.proxy?.hasInnerProxy} writer=${proxyStatus?.hasWriter} clients=${proxyStatus?.activeClientCount} playlistVersion=${proxyStatus?.playlistVersion} latestSequence=${proxyStatus?.latestPlayableSequence} writtenSequence=${proxyStatus?.lastWrittenSequence} outputMs=${proxyStatus?.outputDuration.inMilliseconds} bufferedBytes=${proxyStatus?.bufferedBytes} runtimeError=${runtime.error != null} nativeFlags=$nativeFlags',
              );
              debugPrint(
                '[ReadonlyTest] switch state seconds=${switchClock.elapsed.inSeconds} miniActive=${mini.isActive} playerPresent=${state != null} playing=${state?.playing} buffering=${state?.buffering} positionMs=${state?.position.inMilliseconds} ownerMatches=${owners.playableState?.metadata.channelLogin == target.channelLogin} uriChanged=${TwitchMediaKitPlayerHost.currentMediaUri != uri} pendingAtMount=$pendingAtMount pendingAtNewOwner=$pendingAtNewOwner errorType=${recoveryError?.runtimeType ?? 'none'}',
              );
            }
            return !mini.isActive &&
                state != null &&
                state.playing &&
                !state.buffering &&
                state.position > Duration.zero &&
                owners.playableState?.metadata.channelLogin ==
                    target.channelLogin;
          },
          'recovery switch selected source decodes and owns playback',
          timeout: const Duration(seconds: 90),
        );
        final selectedUri = TwitchMediaKitPlayerHost.currentMediaUri;
        await _probeReadonlyVideoFrames(tester, selected);
        const verifyFrameFailures = bool.fromEnvironment(
          'TWITCH_READONLY_FRAME_PROBE_FAILURES',
        );
        if (verifyFrameFailures) {
          var nativeSamples = 0;
          var flutterSamples = 0;
          for (final throwsCapture in [false, true]) {
            await _probeReadonlyVideoFrames(
              tester,
              selected,
              captureNativeForTesting: () async {
                if (throwsCapture) throw StateError('fixture capture failure');
                return null;
              },
              onNativeSummary: (_) => nativeSamples++,
              onFlutterSummary: (summary) {
                expect(summary['samples'], greaterThan(0));
                flutterSamples++;
              },
            );
          }
          expect(nativeSamples, 0);
          expect(flutterSamples, 2);
          debugPrint(
            '[ReadonlyTest] independent frame probes nativeSamples=$nativeSamples flutterSamples=$flutterSamples',
          );
        }
        if (recoveryGate != null) {
          expect(recoveryFinished, isFalse);
          recoveryGate.complete();
          await pending.timeout(const Duration(seconds: 90));
          debugPrint(
            '[ReadonlyTest] passed: held pre-open recovery released after new source decoded',
          );
        }
        final runtime = selected.watchPorts.player.runtime;
        await probePlaylist(runtime);
        if (const bool.fromEnvironment('TWITCH_READONLY_REQUIRE_FMP4')) {
          expect(
            selectedHasInitMap,
            isTrue,
            reason: 'This run must use the fMP4 path, not a TS success sample.',
          );
          expect(
            runtime.proxy?.streamReadDiagnostics['startsWithMp4Init'],
            isTrue,
          );
        }
        expect(selectedUri, isNot(uri));
        expect(runtime.channelLogin, target.channelLogin);
        expect(runtime.upstreamPlaylistUri, isNotNull);
        expect(
          runtime.proxy?.upstreamPlaylistUrl,
          runtime.upstreamPlaylistUri?.toString(),
        );
        const switchObservationSeconds = int.fromEnvironment(
          'TWITCH_READONLY_SWITCH_OBSERVATION_SECONDS',
          defaultValue: 10,
        );
        expect(switchObservationSeconds, inInclusiveRange(10, 120));
        expect(switchObservationSeconds % 10, 0);
        debugPrint(
          '[ReadonlyTest] decoded switch transport=${runtime.proxy?.streamReadDiagnostics}',
        );
        for (
          var seconds = 10;
          seconds <= switchObservationSeconds;
          seconds += 10
        ) {
          final position = selected.playerSession.player.state.position;
          await tester.pump(const Duration(seconds: 10));
          final playback = selected.playerSession.player.state;
          final delta = (playback.position - position).inMilliseconds;
          debugPrint(
            '[ReadonlyTest] switch continuation seconds=$seconds channel=${target.channelLogin} deltaMs=$delta playing=${playback.playing} buffering=${playback.buffering} sourceRetained=${TwitchMediaKitPlayerHost.currentMediaUri == selectedUri} transport=${runtime.proxy?.streamReadDiagnostics}',
          );
          expect(delta, greaterThan(7000));
          expect(playback.playing, isTrue);
          expect(playback.buffering, isFalse);
          expect(owners.playableState?.mediaUri, selectedUri);
          expect(TwitchMediaKitPlayerHost.currentMediaUri, selectedUri);
        }
        await _probeReadonlyVideoFrames(tester, selected);
        expect(recoveryError, isNull);
        debugPrint(
          '[ReadonlyTest] recovery native-open atClick=$nativeOpenAtClick atMount=$nativeOpenAtMount atNewOwner=$nativeOpenAtNewOwner started=${TwitchMediaKitPlayerHost.restoreOpenStarted - restoreStartedBefore} completed=${TwitchMediaKitPlayerHost.restoreOpenCompleted - restoreCompletedBefore} lastCompletedOpenUs=${TwitchMediaKitPlayerHost.lastCompletedRestoreOpenElapsedUs} newOwnerElapsedMs=$newOwnerElapsedMs',
        );
        debugPrint(
          '[ReadonlyTest] recovery switch pendingAtClick=$pendingAtClick pendingAtMount=$pendingAtMount pendingAtNewOwner=$pendingAtNewOwner sourceRetained=true advances=true errorType=${recoveryError?.runtimeType ?? 'none'}',
        );
        const requireOverlap = bool.fromEnvironment(
          'TWITCH_READONLY_REQUIRE_RECOVERY_OVERLAP',
        );
        if (pendingAtMount != true || pendingAtNewOwner != true) {
          debugPrint(
            '[ReadonlyTest] unavailable: recovery overlap not reached; source replacement only',
          );
        }
        if (requireOverlap) {
          expect(
            pendingAtMount,
            isTrue,
            reason: 'New route must mount before old recovery completes.',
          );
          expect(
            pendingAtNewOwner,
            isTrue,
            reason: 'New source ownership must overlap the old recovery.',
          );
        }
        if (const bool.fromEnvironment(
          'TWITCH_READONLY_REQUIRE_NATIVE_OPEN_OVERLAP',
        )) {
          expect(
            const bool.fromEnvironment('TWITCH_READONLY_OBSERVE_RESTORE_OPEN'),
            isTrue,
          );
          expect(
            nativeOpenAtNewOwner,
            isTrue,
            reason: 'Native restore open itself must overlap new ownership.',
          );
        }
      } finally {
        debugPrint(
          '[ReadonlyTest] switch native final categories beforeMount=${beforeMountDiagnostics.snapshot} afterMount=${afterMountDiagnostics.snapshot}',
        );
        await playlistProbe;
        await frameProbe;
        playlistProbeClient.close(force: true);
        await nativeLogs.cancel();
        if (recoveryGate != null && !recoveryGate.isCompleted) {
          recoveryGate.complete();
        }
        await pending.timeout(const Duration(seconds: 90));
        owners.removeListener(recordOwner);
      }
      return;
    }
    const closeDuringRecovery = bool.fromEnvironment(
      'TWITCH_READONLY_MINI_RECOVERY_CLOSE',
    );
    if (closeDuringRecovery) {
      phase('mini-$label-recovery-close');
      mini.rememberNetworkLoss();
      var recoveryFinished = false;
      Object? recoveryError;
      final pendingRecovery = mini.recoverAfterNetworkRestored().then<void>(
        (_) => recoveryFinished = true,
        onError: (Object error, StackTrace stack) {
          recoveryError = error;
          recoveryFinished = true;
        },
      );
      final closeButton = find
          .descendant(
            of: find.byType(TwitchMiniPlayerOverlay),
            matching: find.byIcon(Icons.close_rounded),
          )
          .hitTestable();
      final wasPendingAtClick = !recoveryFinished;
      bool? wasPendingAtClose;
      void recordClose() {
        if (!mini.isActive) wasPendingAtClose ??= !recoveryFinished;
      }

      mini.addListener(recordClose);
      try {
        await tester.tap(closeButton);
        await waitFor(
          tester,
          () => !mini.isActive,
          '$label closes during controlled recovery',
        );
      } finally {
        mini.removeListener(recordClose);
      }
      await pendingRecovery.timeout(const Duration(seconds: 90));
      await tester.pump(const Duration(seconds: 3));
      final playing = TwitchMediaKitPlayerHost.playerOrNull?.state.playing;
      debugPrint(
        '[ReadonlyTest] recovery close media=$label pendingAtClick=$wasPendingAtClick pendingAtClose=$wasPendingAtClose recoveryErrorType=${recoveryError?.runtimeType ?? 'none'} miniActive=${mini.isActive} playing=$playing',
      );
      expect(
        wasPendingAtClick,
        isTrue,
        reason: 'Close must overlap the recovery future for race coverage.',
      );
      expect(
        wasPendingAtClose,
        isTrue,
        reason: 'Recovery must still be pending when close takes effect.',
      );
      expect(recoveryError, isNull);
      expect(mini.isActive, isFalse);
      expect(
        playing,
        isNot(true),
        reason: 'Late recovery must not resume a closed mini player.',
      );
      expect(TwitchPlaybackSessionController.instance.playableState, isNull);
      continue;
    }
    final surface = find.descendant(
      of: find.byType(TwitchMiniPlayerOverlay),
      matching: find.byType(AspectRatio),
    );
    expect(surface, findsOneWidget);
    await tester.tapAt(tester.getCenter(surface));
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      '$label mini expands',
    );
    phase('mini-$label-restored');
    final restored = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    expect(identical(restored, source), isFalse);
    expect(restored.widget.initialVodVideo?.id, isVod ? video.id : null);
    expect(restored.widget.initialClip?.id, isVod ? null : clip.id);
    await waitFor(tester, () {
      final state = restored.playerSession.playerOrNull?.state;
      return !mini.isActive &&
          state != null &&
          state.playing &&
          !state.buffering;
    }, '$label restored owns decoded playback');
    expect(TwitchMediaKitPlayerHost.currentMediaUri, uri);
    expect(restored.buildPlaybackSnapshot()?.kind, kind);
    final resumed = restored.playerSession.player.state.position;
    expect((resumed - after).inMilliseconds.abs(), lessThan(10000));
    await tester.pump(const Duration(seconds: 3));
    expect(
      restored.playerSession.player.state.position - resumed,
      greaterThan(const Duration(seconds: 1)),
    );
    debugPrint(
      '[ReadonlyTest] passed: $label restored position continuity and progress',
    );
    await goHome('restored $label');
    await tester.tap(
      find
          .descendant(
            of: find.byType(TwitchMiniPlayerOverlay),
            matching: find.byIcon(Icons.close_rounded),
          )
          .hitTestable(),
    );
    await waitFor(
      tester,
      () =>
          !mini.isActive &&
          TwitchMediaKitPlayerHost.playerOrNull?.state.playing != true,
      '$label mini close pauses shared player',
    );
  }
}

Future<void> exerciseMediaLibrary(
  WidgetTester tester,
  TwitchDiscoveryService discovery,
  TwitchFollowedChannel channel,
  void Function(String) phase,
) async {
  phase('library');
  unawaited(
    showTwitchChannelSheet(
      context: tester.element(find.byType(TwitchStreamPage)),
      discoveryService: discovery,
      channel: channel,
      initialTabIndex: 2,
    ),
  );
  await waitFor(
    tester,
    () => find.byType(TwitchChannelPage).evaluate().isNotEmpty,
    'channel media library mounted',
  );
  final dynamic library = tester.state(find.byType(TwitchChannelPage));
  await waitFor(
    tester,
    () => library.videosLoaded == true && library.loadingFirstPage == false,
    'VOD library loaded',
  );
  debugPrint(
    '[ReadonlyTest] VOD library count=${library.videos.length} hasError=${library.errorText != null}',
  );
  expect(library.errorText, isNull);
  final videos = (library.videos as List<TwitchChannelVideo>)
      .where((video) => !video.isLikelyGrowingArchive)
      .toList();
  expect(
    videos,
    isNotEmpty,
    reason:
        'Completed VOD is required; growing DVR does not substitute for VOD coverage.',
  );
  final video = videos.first;
  Future<void> exerciseSearch(
    TextEditingController controller,
    String label,
  ) async {
    await tester.pump(const Duration(milliseconds: 500));
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && identical(widget.controller, controller),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'codex-no-media-match-20261011-unlikely');
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find
          .descendant(
            of: find.byType(TwitchChannelPage),
            matching: find.byIcon(Icons.search_off_rounded),
          )
          .hitTestable(),
      findsOneWidget,
    );
    final clear = find
        .descendant(
          of: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_CenteredAction',
          ),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        )
        .hitTestable();
    expect(clear, findsOneWidget);
    await tester.tap(clear);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.text, isEmpty);
    expect(
      find
          .descendant(
            of: find.byType(TwitchChannelPage),
            matching: find.byIcon(Icons.search_off_rounded),
          )
          .hitTestable(),
      findsNothing,
    );
    debugPrint(
      '[ReadonlyTest] passed: $label empty search and clear restores cards',
    );
  }

  await exerciseSearch(library.vodSearchController, 'VOD');
  Future<void> exercisePagination(String label) async {
    final isVod = label == 'VOD';
    final cursor = isVod ? library.nextCursor : library.clipsNextCursor;
    if (cursor == null) {
      debugPrint('[ReadonlyTest] unavailable: $label pagination has no cursor');
      return;
    }
    List<String> ids() => isVod
        ? (library.videos as List<TwitchChannelVideo>)
              .map((item) => item.id)
              .toList()
        : (library.clips as List<TwitchChannelClip>)
              .map((item) => item.id)
              .toList();
    final before = ids();
    await tester.pump(const Duration(milliseconds: 500));
    final tab = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == (isVod ? '_VodTab' : '_ClipTab'),
    );
    final icon = find.descendant(
      of: tab,
      matching: find.byIcon(Icons.expand_more_rounded),
    );
    debugPrint(
      '[ReadonlyTest] $label pagination footer matches=${icon.evaluate().length}',
    );
    await tester.scrollUntilVisible(
      icon,
      400,
      scrollable: find
          .descendant(of: tab, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 60,
    );
    final button = find
        .ancestor(
          of: icon,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button.hitTestable());
    await waitFor(
      tester,
      () =>
          (isVod ? library.loadingMore : library.loadingMoreClips) == false &&
          ids().length > before.length,
      '$label load-more appends results',
    );
    final after = ids();
    expect(after.take(before.length).toList(), before);
    expect(after.toSet().length, after.length);
    expect(after.toSet().length, greaterThan(before.toSet().length));
    expect(isVod ? library.errorText : library.clipsErrorText, isNull);
    debugPrint(
      '[ReadonlyTest] passed: $label pagination before=${before.length} after=${after.length} preserves prefix',
    );
  }

  await exercisePagination('VOD');
  Future<void> tapMedia(String id, {required bool isVod}) async {
    await tester.pump(const Duration(milliseconds: 500));
    final tab = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString() == (isVod ? '_VodTab' : '_ClipTab'),
    );
    final media = find.descendant(
      of: tab,
      matching: find.byWidgetPredicate((widget) {
        if (widget.runtimeType.toString() !=
            (isVod ? '_VodCard' : '_ClipCard')) {
          return false;
        }
        final dynamic card = widget;
        return (isVod ? card.video.id : card.clip.id) == id;
      }),
    );
    // Pagination leaves the lazy grid at its footer. Scroll the intended ID
    // back into the tree before looking up its tap target; titles can repeat.
    await tester.scrollUntilVisible(
      media,
      -400,
      scrollable: find
          .descendant(of: tab, matching: find.byType(Scrollable))
          .first,
      maxScrolls: 60,
    );
    debugPrint('[ReadonlyTest] media ID matches=${media.evaluate().length}');
    expect(media, findsOneWidget);
    final card = find
        .descendant(of: media, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(card.hitTestable());
  }

  Future<TwitchWatchPageState> watchMedia(String label) async {
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      '$label route mounted',
    );
    final state = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    await waitFor(
      tester,
      () =>
          state.playerSession.playerOrNull != null &&
          !state.playerSession.player.state.buffering &&
          state.playerSession.player.state.position > Duration.zero &&
          state.playerSession.player.state.playing,
      '$label decoded playback starts',
      timeout: const Duration(seconds: 90),
    );
    final before = state.playerSession.player.state.position;
    for (var second = 0; second < 10; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      state.playerSession.player.state.position - before,
      greaterThan(const Duration(seconds: 7)),
    );
    debugPrint(
      '[ReadonlyTest] passed: $label playback advances for 10 seconds',
    );
    return state;
  }

  phase('vod');
  await tapMedia(video.id, isVod: true);
  final vod = await watchMedia('VOD');
  expect(vod.widget.initialVodVideo?.id, video.id);
  expect(vod.widget.initialVodPlaybackOnly, isTrue);
  await vod.playerSession.player.seek(const Duration(seconds: 30));
  await waitFor(
    tester,
    () =>
        vod.playerSession.player.state.position >=
            const Duration(seconds: 29) &&
        !vod.playerSession.player.state.buffering,
    'VOD seeks to 30 seconds',
  );
  await vod.playerSession.player.pause();
  await tester.pump(const Duration(seconds: 3));
  final paused = vod.playerSession.player.state.position;
  await vod.playerSession.player.play();
  await waitFor(
    tester,
    () =>
        vod.playerSession.player.state.position >
        paused + const Duration(seconds: 2),
    'VOD resumes after pause',
  );
  const mediaControls = bool.fromEnvironment('TWITCH_READONLY_MEDIA_CONTROLS');
  if (mediaControls) {
    final overlay = find.byType(WatchControlsOverlay);
    Future<void> wakeControls() async {
      // App-local tap wakes the fading chrome and requests its keyboard focus.
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 250));
    }

    await wakeControls();
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.pause))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () => !vod.playerSession.player.state.playing,
      'VOD pause button pauses playback',
    );
    await tester.pump(const Duration(milliseconds: 500));
    final pausedPosition = vod.playerSession.player.state.position;
    await tester.pump(const Duration(seconds: 2));
    expect(
      (vod.playerSession.player.state.position - pausedPosition).inMilliseconds
          .abs(),
      lessThan(500),
    );
    expect(vod.playbackTimelineController.snapshot.mode.name, 'vod');
    final inlineTime = find.descendant(
      of: overlay,
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_InlineTimeValue',
      ),
    );
    debugPrint(
      '[ReadonlyTest] VOD inline time fields=${inlineTime.evaluate().length}',
    );
    expect(inlineTime.hitTestable(), findsOneWidget);
    await tester.tap(inlineTime.hitTestable());
    await tester.pump(const Duration(milliseconds: 250));
    final timeField = find.descendant(
      of: inlineTime,
      matching: find.byType(TextField),
    );
    expect(timeField, findsOneWidget);
    final editableTime = tester.widget<TextField>(timeField);
    expect(editableTime.focusNode?.hasFocus, isTrue);
    final originalTimeText = editableTime.controller!.text;
    final positionWhileEditing = vod.playerSession.player.state.position;
    final timelineWhileEditing =
        vod.playbackTimelineController.snapshot.position;
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(editableTime.focusNode?.hasFocus, isTrue);
    expect(editableTime.controller!.text, originalTimeText);
    expect(vod.playerSession.player.state.playing, isFalse);
    expect(
      (vod.playerSession.player.state.position - positionWhileEditing)
          .inMilliseconds
          .abs(),
      lessThan(500),
    );
    expect(
      (vod.playbackTimelineController.snapshot.position - timelineWhileEditing)
          .inMilliseconds
          .abs(),
      lessThan(500),
    );
    debugPrint('[ReadonlyTest] passed: time field arrows do not seek VOD');
    await wakeControls();
    expect(timeField, findsNothing);
    debugPrint('[ReadonlyTest] passed: tapping player leaves time editing');
    for (final backwards in [true, false]) {
      await wakeControls();
      final snapshot = vod.playbackTimelineController.snapshot;
      expect(snapshot.canSeek, isTrue);
      final target =
          snapshot.position + Duration(seconds: backwards ? -10 : 10);
      expect(target, greaterThan(Duration.zero));
      expect(target, lessThan(snapshot.duration!));
      await tester.sendKeyEvent(
        backwards
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowRight,
      );
      await waitFor(
        tester,
        () =>
            !vod.playerSession.player.state.buffering &&
            (vod.playerSession.player.state.position - target).inMilliseconds
                    .abs() <
                2000,
        backwards
            ? 'VOD left shortcut seeks back 10 seconds'
            : 'VOD right shortcut seeks forward 10 seconds',
      );
      expect(vod.playerSession.player.state.playing, isFalse);
    }
    await wakeControls();
    final resumePosition = vod.playerSession.player.state.position;
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.play_arrow))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () =>
          vod.playerSession.player.state.playing &&
          !vod.playerSession.player.state.buffering &&
          vod.playerSession.player.state.position >
              resumePosition + const Duration(seconds: 2),
      'VOD play button resumes decoded playback',
    );

    await wakeControls();
    await tester.tap(find.byType(ChannelLibraryButton).hitTestable());
    await waitFor(
      tester,
      () => find.byType(TwitchChannelPage).evaluate().isNotEmpty,
      'channel library opens through player button',
    );
    final entryPage = tester.widget<TwitchChannelPage>(
      find.byType(TwitchChannelPage),
    );
    expect(entryPage.channel.channelLogin, vod.channelLogin);
    expect(
      identical(entryPage.discoveryService.authService, vod.authService),
      isTrue,
    );
    final dynamic entryState = tester.state(find.byType(TwitchChannelPage));
    expect(entryState.tabController.index, 0);
    await waitFor(
      tester,
      () =>
          entryState.panelsLoaded == true && entryState.loadingPanels == false,
      'player-opened channel about loads',
    );
    expect(entryState.panelsErrorText, isNull);
    await tester.tap(
      find.descendant(
        of: find.byType(TwitchChannelPage),
        matching: find.byIcon(Icons.video_library_rounded),
      ),
    );
    await waitFor(
      tester,
      () =>
          entryState.videosLoaded == true &&
          entryState.loadingFirstPage == false,
      'player-opened VOD tab loads',
    );
    expect(entryState.errorText, isNull);
    await tester.tap(
      find.descendant(
        of: find.byType(TwitchChannelPage),
        matching: find.byIcon(Icons.movie_filter_rounded),
      ),
    );
    await waitFor(
      tester,
      () =>
          entryState.clipsLoaded == true &&
          entryState.loadingClipsFirstPage == false,
      'player-opened clip tab loads',
    );
    expect(entryState.clipsErrorText, isNull);
    await tester.tap(
      find
          .descendant(
            of: find.byType(TwitchChannelPage),
            matching: find.byIcon(Icons.close_rounded),
          )
          .hitTestable(),
    );
    await waitFor(
      tester,
      () => find.byType(TwitchChannelPage).evaluate().isEmpty,
      'player-opened channel library closes',
    );
    expect(tester.state(find.byType(TwitchWatchPage)), same(vod));
    expect(vod.widget.initialVodVideo?.id, video.id);
    final afterClose = vod.playerSession.player.state.position;
    await waitFor(
      tester,
      () =>
          vod.playerSession.player.state.position >
          afterClose + const Duration(seconds: 2),
      'original VOD continues after channel library closes',
    );
  }
  Navigator.of(tester.element(find.byType(TwitchWatchPage))).pop();
  await waitFor(
    tester,
    () => find.byType(TwitchWatchPage).evaluate().isEmpty,
    'VOD returns to library',
  );
  phase('library');
  await tester.tap(
    find.descendant(
      of: find.byType(TwitchChannelPage),
      matching: find.byIcon(Icons.movie_filter_rounded),
    ),
  );
  await waitFor(
    tester,
    () => library.clipsLoaded == true && library.loadingClipsFirstPage == false,
    'clip library loaded',
  );
  expect(library.clipsErrorText, isNull);
  final clips = (library.clips as List<TwitchChannelClip>)
      .where((clip) => clip.duration >= 20)
      .toList();
  expect(
    clips,
    isNotEmpty,
    reason: 'A clip long enough for sustained playback is required.',
  );
  await exerciseSearch(library.clipSearchController, 'clip');
  await exercisePagination('clip');
  phase('clip');
  await tapMedia(clips.first.id, isVod: false);
  final clip = await watchMedia('clip');
  expect(clip.widget.initialClip?.id, clips.first.id);
  if (mediaControls) {
    await waitFor(
      tester,
      () =>
          clip.playerSession.player.state.position >=
              const Duration(seconds: 12) &&
          clip.playerSession.player.state.playing &&
          !clip.playerSession.player.state.buffering,
      'clip reaches interior position for shortcut test',
    );
    final overlay = find.byType(WatchControlsOverlay);
    Future<void> wakeClipControls() async {
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 250));
    }

    await wakeClipControls();
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.pause))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () => !clip.playerSession.player.state.playing,
      'clip pause button pauses playback',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(clip.playbackTimelineController.snapshot.mode.name, 'clip');
    for (final backwards in [true, false]) {
      await wakeClipControls();
      final snapshot = clip.playbackTimelineController.snapshot;
      expect(snapshot.canSeek, isTrue);
      final target =
          snapshot.position + Duration(seconds: backwards ? -10 : 10);
      expect(target, greaterThan(Duration.zero));
      expect(target, lessThan(snapshot.duration!));
      await tester.sendKeyEvent(
        backwards
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowRight,
      );
      await waitFor(
        tester,
        () =>
            !clip.playerSession.player.state.buffering &&
            (clip.playerSession.player.state.position - target).inMilliseconds
                    .abs() <
                2000,
        backwards
            ? 'clip left shortcut seeks back 10 seconds'
            : 'clip right shortcut seeks forward 10 seconds',
      );
      expect(clip.playerSession.player.state.playing, isFalse);
    }
    await wakeClipControls();
    final resumePosition = clip.playerSession.player.state.position;
    await tester.tap(
      find
          .descendant(of: overlay, matching: find.byIcon(Icons.play_arrow))
          .hitTestable(),
    );
    await waitFor(
      tester,
      () =>
          clip.playerSession.player.state.playing &&
          !clip.playerSession.player.state.buffering &&
          clip.playerSession.player.state.position >
              resumePosition + const Duration(seconds: 2),
      'clip play button resumes decoded playback',
    );
  }
  Navigator.of(tester.element(find.byType(TwitchWatchPage))).pop();
  await waitFor(
    tester,
    () => find.byType(TwitchWatchPage).evaluate().isEmpty,
    'clip returns to library',
  );
  phase('library');
  await tester.tap(
    find.descendant(
      of: find.byType(TwitchChannelPage),
      matching: find.byIcon(Icons.info_outline_rounded),
    ),
  );
  await waitFor(
    tester,
    () => library.panelsLoaded == true && library.loadingPanels == false,
    'channel about loaded',
  );
  expect(library.panelsErrorText, isNull);
  debugPrint('[ReadonlyTest] passed: channel VOD, clip and about tabs');
}

Future<void> exerciseIsolatedNativeControls(
  WidgetTester tester,
  Player player,
) async {
  final state = tester.state<TwitchWatchPageState>(
    find.byType(TwitchWatchPage),
  );
  expect(state.viewerId, isNull);
  double nativeVolume() => double.tryParse(player.getProperty('volume')) ?? -1;
  Finder muteButton() =>
      find.byTooltip(state.isMuted ? '取消靜音' : '靜音').hitTestable().first;
  final volumeControl = find
      .ancestor(of: muteButton(), matching: find.byType(Row))
      .first;
  final slider = find.descendant(
    of: volumeControl,
    matching: find.byType(Slider),
  );
  expect(slider, findsOneWidget);
  await tester.ensureVisible(slider);
  final rect = tester.getRect(slider);
  await tester.tapAt(Offset(rect.left + rect.width * 0.35, rect.center.dy));
  await tester.pump();
  debugPrint(
    '[ReadonlyTest] native controls volume ui=${state.volume} stream=${player.state.volume} property=${player.getProperty('volume')} muted=${state.isMuted} durationMs=${player.state.duration.inMilliseconds} sliderWidth=${rect.width}',
  );
  await waitFor(
    tester,
    () =>
        state.volume > 0 &&
        state.volume < 80 &&
        (nativeVolume() - state.volume).abs() < 1,
    'isolated UI volume reaches native player',
    timeout: const Duration(seconds: 10),
  );
  final volume = state.volume;
  await tester.tap(muteButton());
  await waitFor(
    tester,
    () => state.isMuted && nativeVolume().abs() < 0.01,
    'isolated UI mute reaches native player',
    timeout: const Duration(seconds: 10),
  );
  await tester.pump();
  await tester.tap(muteButton());
  await waitFor(
    tester,
    () => !state.isMuted && (nativeVolume() - volume).abs() < 1,
    'isolated UI unmute restores volume',
    timeout: const Duration(seconds: 10),
  );
  expect(await windowManager.isFullScreen(), false);
  try {
    await tester.tap(find.byIcon(Icons.fullscreen).hitTestable().first);
    await waitFor(
      tester,
      () => state.fullscreenMode,
      'isolated UI enters fullscreen',
      timeout: const Duration(seconds: 10),
    );
    await tester.pump();
    expect(await windowManager.isFullScreen(), true);
    await tester.tap(find.byIcon(Icons.fullscreen_exit).hitTestable().first);
    await waitFor(
      tester,
      () => !state.fullscreenMode,
      'isolated UI exits fullscreen',
      timeout: const Duration(seconds: 10),
    );
    expect(await windowManager.isFullScreen(), false);
    // This local fixture is only 2.8 seconds long; restart for the observation.
    await player.seek(Duration.zero);
    await player.play();
    final position = player.state.position;
    await tester.pump(const Duration(seconds: 3));
    expect(
      player.state.position - position,
      greaterThan(const Duration(seconds: 1)),
    );
  } finally {
    await TwitchFullscreenController.exitFullscreen();
  }
  // Leave a freshly decoded frame for the existing native/Flutter pixel checks.
  await player.seek(Duration.zero);
  await player.play();
  await waitFor(
    tester,
    () => player.state.position.inMilliseconds > 300 && player.state.playing,
    'local fixture restarts for pixel verification',
    timeout: const Duration(seconds: 5),
  );
}

void validateIsolatedNativeControlFlags({
  required bool enabled,
  required bool localGuestSurface,
  required bool remote,
  required bool guestHomeMedia,
}) {
  if (enabled && (!localGuestSurface || remote || guestHomeMedia)) {
    throw StateError(
      'Native controls require only the isolated local guest surface',
    );
  }
}

void main() {
  if (const bool.fromEnvironment('TWITCH_READONLY_QUALITY_PAUSED') &&
      !const bool.fromEnvironment('TWITCH_READONLY_NATIVE_QUALITY')) {
    throw StateError(
      'Paused quality requires the isolated live quality branch',
    );
  }
  validateIsolatedNativeControlFlags(
    enabled:
        const bool.fromEnvironment('TWITCH_READONLY_NATIVE_CONTROLS') ||
        const bool.fromEnvironment('TWITCH_READONLY_GUEST_CLIP_ENTRY') ||
        const bool.fromEnvironment('TWITCH_READONLY_NATIVE_AUDIO') ||
        const bool.fromEnvironment('TWITCH_READONLY_NATIVE_QUALITY') ||
        const bool.fromEnvironment('TWITCH_READONLY_RECORDED_QUALITY'),
    localGuestSurface: const bool.fromEnvironment(
      'TWITCH_READONLY_GUEST_SURFACE',
    ),
    remote: const bool.fromEnvironment('TWITCH_READONLY_GUEST_REMOTE'),
    guestHomeMedia: const bool.fromEnvironment(
      'TWITCH_READONLY_GUEST_HOME_MEDIA',
    ),
  );
  if (const bool.fromEnvironment('TWITCH_READONLY_NATIVE_AUDIO') ||
      const bool.fromEnvironment('TWITCH_READONLY_NATIVE_QUALITY') ||
      const bool.fromEnvironment('TWITCH_READONLY_RECORDED_QUALITY')) {
    const root = String.fromEnvironment('VIOCLASS_LOCAL_AV_FIXTURE_ROOT');
    final sizes =
        const bool.fromEnvironment('TWITCH_READONLY_NATIVE_QUALITY') ||
            const bool.fromEnvironment('TWITCH_READONLY_RECORDED_QUALITY')
        ? ['640x360', '320x180']
        : ['640x360'];
    for (final size in sizes) {
      if (root.isEmpty || !io.File('$root/$size.mkv').existsSync()) {
        throw StateError(
          'Native AV checks require explicit existing local fixtures',
        );
      }
    }
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // The default live-test policy only paints requested frames. Long network
  // and playback waits would otherwise make the real app look frozen.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // Do not print account identities, signed media URLs or private chat data.
  final previousPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message?.startsWith('[ReadonlyTest]') == true) {
      previousPrint(message, wrapWidth: wrapWidth);
    } else if (message?.startsWith('[DvrSegment]') == true) {
      final fields = RegExp(
        r'(?:generation|client|status|bytes|totalMs|ms)=\d+|(?:waitingForFlush|hasMap|compressed)=(?:true|false)|format=(?:mpegts|fmp4|gzip|id3|unknown)',
      ).allMatches(message!).map((match) => match.group(0)).join(' ');
      final stage = message.contains('first-byte')
          ? 'first-byte'
          : message.contains(' progress ')
          ? 'progress'
          : message.contains('flush-start')
          ? 'flush-start'
          : message.contains('flush-done')
          ? 'flush-done'
          : message.contains(' done ')
          ? 'done'
          : 'request';
      previousPrint('[ReadonlyTest] segment $stage $fields');
    } else if (message?.startsWith('[DvrSequential] stream error') == true) {
      previousPrint(
        '[ReadonlyTest] stream failure: ${message!.contains('TimeoutException') ? 'timeout' : 'other'}',
      );
    }
  };

  if (const bool.fromEnvironment('TWITCH_READONLY_GUEST_HOME_MEDIA')) {
    testWidgets('guest home search card opens real anonymous recorded media', (
      tester,
    ) async {
      MediaKit.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'vioclass_auto_check_updates_v1': false,
      });
      const channel = String.fromEnvironment(
        'TWITCH_READONLY_GUEST_CHANNEL',
        defaultValue: 'riotgames',
      );
      const kind = String.fromEnvironment(
        'TWITCH_READONLY_GUEST_HOME_KIND',
        defaultValue: 'clip',
      );
      expect(kind, isIn(['clip', 'vod']));
      final fixture = watch_fixture.IsolatedRecordedRouteFixture();
      final seed = fixture.createServices();
      final remoteClient = TwitchApiClient();
      var requests = 0;
      var authorizationRequests = 0;
      final requestGuard = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          final authorized = options.headers.keys.any(
            (key) => key.toLowerCase() == 'authorization',
          );
          if (authorized) authorizationRequests++;
          expectSync(authorized, isFalse);
          handler.next(options);
        },
      );
      remoteClient.dio.interceptors.add(requestGuard);
      final playbackClients = <TwitchApiClient>[];
      final watchClients = <TwitchApiClient>[];
      final discovery = TwitchDiscoveryService(
        client: seed.apiClient,
        authService: fixture.authService,
        authApi: seed.authApi,
        guestDiscoveryService: TwitchGuestDiscoveryService(
          client: remoteClient,
        ),
      );
      final player = await Player.create(
        configuration: const PlayerConfiguration(options: {'aid': 'no'}),
      );
      // ignore: invalid_use_of_visible_for_testing_member
      TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
      final session = TwitchMediaKitPlayerHost.acquire();
      var watchBundles = 0;
      String? selectedChannelLogin;
      try {
        await session.ensureReady();
        await tester.pumpWidget(
          MaterialApp(
            home: TwitchStreamPage(
              services: TwitchStreamPageServices(
                apiClient: seed.apiClient,
                authService: fixture.authService,
                authApi: seed.authApi,
                dropsAuthService: seed.dropsAuthService,
                webGqlAuthService: seed.webGqlAuthService,
                discoveryService: discovery,
                watchServicesFactory: () {
                  watchBundles++;
                  final playbackClient = TwitchApiClient();
                  playbackClient.dio.interceptors.add(requestGuard);
                  playbackClients.add(playbackClient);
                  final api = TwitchPlaybackApiService(
                    gql: TwitchGqlApiService(client: playbackClient),
                    viewerAuthProvider: () async =>
                        const TwitchPlaybackViewerAuthResolution.anonymous(),
                  );
                  final services = fixture.createPlaybackServices(
                    session: TwitchMediaKitPlayerHost.acquire(),
                    runtime: TwitchPlaylistPlayerRuntime(playbackApi: api),
                    playbackApi: api,
                    channelLogin: selectedChannelLogin ?? channel,
                  );
                  watchClients.add(services.apiClient);
                  return services;
                },
                watchChatRuntimeFactory: watch_fixture.isolatedWatchChatRuntime,
              ),
            ),
          ),
        );
        await waitFor(
          tester,
          () => find.byType(TwitchStreamHomeToolbar).evaluate().isNotEmpty,
          'isolated guest home toolbar mounted',
        );
        await tester.enterText(
          find.descendant(
            of: find.byType(TwitchStreamHomeToolbar),
            matching: find.byType(EditableText),
          ),
          channel,
        );
        await waitFor(
          tester,
          () {
            final dynamic home = tester.state(find.byType(TwitchStreamPage));
            return home.searchText == channel &&
                !home.loadingChannelSearch &&
                (kind == 'vod'
                    ? home.searchedVideos.isNotEmpty
                    : home.searchedClips.isNotEmpty);
          },
          'anonymous public search loads recorded media cards',
          timeout: const Duration(seconds: 30),
        );
        final dynamic home = tester.state(find.byType(TwitchStreamPage));
        final results = List<dynamic>.from(
          (kind == 'vod' ? home.searchedVideos : home.searchedClips)
              as Iterable,
        );
        final candidates = results
            .where(
              (dynamic result) => kind == 'clip'
                  ? (result.clip as TwitchChannelClip).duration >= 20
                  : (result.video as TwitchChannelVideo).parsedDuration !=
                            null &&
                        (result.video as TwitchChannelVideo).parsedDuration! >=
                            const Duration(seconds: 60) &&
                        !(result.video as TwitchChannelVideo)
                            .isLikelyGrowingArchive,
            )
            .toList();
        debugPrint(
          '[ReadonlyTest] guest home public query=$channel kind=$kind results=${results.length} eligible=${candidates.length} watchBundles=$watchBundles',
        );
        expect(candidates, isNotEmpty);
        final selectedId = kind == 'clip'
            ? (candidates.first.clip as TwitchChannelClip).id
            : (candidates.first.video as TwitchChannelVideo).id;
        selectedChannelLogin = candidates.first.channel.channelLogin as String;
        await waitFor(
          tester,
          () => find.byType(CustomScrollView).evaluate().isNotEmpty,
          'public search result scroll view rendered',
        );
        final card = find.byWidgetPredicate((widget) {
          if (widget.runtimeType.toString() !=
              (kind == 'vod' ? '_SearchVodCard' : '_SearchClipCard')) {
            return false;
          }
          final dynamic candidate = widget;
          return (kind == 'clip'
                      ? candidate.result.clip.id
                      : candidate.result.video.id) ==
                  selectedId &&
              candidate.result.channel.channelLogin == selectedChannelLogin;
        });
        const reopen = bool.fromEnvironment(
          'TWITCH_READONLY_GUEST_HOME_REOPEN',
        );
        for (var attempt = 0; attempt < (reopen ? 2 : 1); attempt++) {
          await tester.scrollUntilVisible(
            card,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.ensureVisible(card.first);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(card.hitTestable().first);
          await waitFor(
            tester,
            () {
              if (find.byType(TwitchWatchPage).evaluate().isEmpty) return false;
              final state = tester.state<TwitchWatchPageState>(
                find.byType(TwitchWatchPage),
              );
              return state.watchPorts.player.runtime.usingExternalVodPlayback &&
                  state.watchPorts.player.runtime.channelLogin ==
                      selectedChannelLogin &&
                  player.state.position.inMilliseconds > 300 &&
                  player.state.playing &&
                  !player.state.buffering;
            },
            'actual guest search recorded card decodes native video',
            timeout: const Duration(seconds: 30),
          );
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          expect(find.byType(TwitchWatchRouteGuard), findsOneWidget);
          final page = tester.widget<TwitchWatchPage>(
            find.byType(TwitchWatchPage),
          );
          expect(
            kind == 'clip' ? page.initialClip?.id : page.initialVodVideo?.id,
            selectedId,
          );
          expect(state.viewerId, isNull);
          expect(state.channelLogin, selectedChannelLogin);
          expect(state.loadingAuth, isFalse);
          expect(state.chatController.isReadOnlyGuest, isTrue);
          expect(state.watchServices.authService, same(fixture.authService));
          expect(watchBundles, attempt + 1);
          await _probeReadonlyVideoFrames(tester, state);
          final before = player.state.position;
          await tester.pump(const Duration(seconds: 10));
          final delta = (player.state.position - before).inMilliseconds;
          expect(delta, greaterThan(7000));
          expect(player.state.buffering, isFalse);
          expect(authorizationRequests, 0);
          await _probeReadonlyVideoFrames(tester, state);
          if (kind == 'vod') {
            await waitFor(
              tester,
              () => player.state.position.inSeconds >= 30,
              'same guest home VOD reaches thirty seconds without seeking',
              timeout: const Duration(seconds: 30),
            );
            await _probeReadonlyVideoFrames(tester, state);
          }
          debugPrint(
            '[ReadonlyTest] guest home recorded query=$channel channel=$selectedChannelLogin kind=$kind attempt=$attempt deltaMs=$delta requests=$requests authorizationRequests=$authorizationRequests watchBundles=$watchBundles',
          );
          if (reopen && attempt == 0) {
            await tester.tap(find.byType(WatchControlsOverlay));
            await tester.pump(const Duration(milliseconds: 250));
            await tester.tap(
              find.byIcon(Icons.arrow_back_rounded).hitTestable().first,
            );
            await waitFor(
              tester,
              () =>
                  find.byType(TwitchWatchPage).evaluate().isEmpty &&
                  find.byType(TwitchStreamHomeToolbar).evaluate().isNotEmpty,
              'guest actual back button returns to search home',
            );
            // Close the test-owned playback API client as well as the page-owned
            // mock account client; the next card must create a new bundle.
            playbackClients.first.close(force: true);
            await tester.pump(const Duration(milliseconds: 300));
          }
        }
        if (reopen) {
          expect(watchClients[0], isNot(same(watchClients[1])));
          expect(playbackClients[0], isNot(same(playbackClients[1])));
          debugPrint(
            '[ReadonlyTest] guest home reopened freshWatchClient=true freshPlaybackClient=true authorizationRequests=$authorizationRequests',
          );
        }
      } catch (error, stack) {
        final line =
            RegExp(
              r'twitch_readonly_app_test\.dart:(\d+)',
            ).firstMatch(stack.toString())?.group(1) ??
            'unknown';
        debugPrint(
          '[ReadonlyTest] guest home failure type=${error.runtimeType} sourceLine=$line requests=$requests authorizationRequests=$authorizationRequests watchBundles=$watchBundles',
        );
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
        session.release();
        await TwitchMediaKitPlayerHost.disposeNow();
        fixture.close();
        for (final client in playbackClients) {
          client.close(force: true);
        }
        remoteClient.close(force: true);
      }
    });
    return;
  }

  if (const bool.fromEnvironment('TWITCH_READONLY_GUEST_SURFACE') ||
      const bool.fromEnvironment('TWITCH_READONLY_GUEST_REMOTE')) {
    testWidgets('isolated guest watch outputs video pixels on Windows', (
      tester,
    ) async {
      MediaKit.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      const remote = bool.fromEnvironment('TWITCH_READONLY_GUEST_REMOTE');
      const nativeControls = bool.fromEnvironment(
        'TWITCH_READONLY_NATIVE_CONTROLS',
      );
      const guestClipEntry = bool.fromEnvironment(
        'TWITCH_READONLY_GUEST_CLIP_ENTRY',
      );
      const nativeAudio = bool.fromEnvironment('TWITCH_READONLY_NATIVE_AUDIO');
      const recordedQuality = bool.fromEnvironment(
        'TWITCH_READONLY_RECORDED_QUALITY',
      );
      const pausedQuality = bool.fromEnvironment(
        'TWITCH_READONLY_QUALITY_PAUSED',
      );
      const nativeQuality =
          bool.fromEnvironment('TWITCH_READONLY_NATIVE_QUALITY') ||
          recordedQuality;
      if (nativeControls || guestClipEntry || nativeAudio || nativeQuality) {
        expect(
          remote,
          false,
          reason: 'Native controls must use the isolated local fixture',
        );
      }
      const remoteKind = String.fromEnvironment(
        'TWITCH_READONLY_GUEST_MEDIA',
        defaultValue: 'live',
      );
      const guestReplay = bool.fromEnvironment('TWITCH_READONLY_GUEST_REPLAY');
      const guestArchive = bool.fromEnvironment(
        'TWITCH_READONLY_GUEST_ARCHIVE',
      );
      if (guestReplay || guestArchive) {
        expect(remote, isTrue);
        expect(remoteKind, 'live');
      }
      if (guestArchive) expect(guestReplay, isFalse);
      const remoteChannel = String.fromEnvironment(
        'TWITCH_READONLY_GUEST_CHANNEL',
        defaultValue: 'ow_esports',
      );
      const realGuestChat = bool.fromEnvironment(
        'TWITCH_READONLY_GUEST_REAL_CHAT',
      );
      if (realGuestChat) expect(remote, isTrue);
      if (remoteKind != 'live') {
        expect(remote, isTrue);
        expect(realGuestChat, isFalse);
        expect(['vod', 'clip'], contains(remoteKind));
      }
      final guestIrc = realGuestChat ? _ReadonlyGuestIrc() : null;
      final guestChat = realGuestChat
          ? TwitchChatRuntime(
              ircApi: guestIrc!,
              badgeCache: TwitchBadgeCacheService(),
            )
          : null;
      final remoteClient = remote ? TwitchApiClient() : null;
      var remoteRequests = 0;
      var authorizationRequests = 0;
      remoteClient?.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            remoteRequests++;
            final hasAuthorization = options.headers.keys.any(
              (key) => key.toLowerCase() == 'authorization',
            );
            if (hasAuthorization) authorizationRequests++;
            expectSync(hasAuthorization, isFalse);
            handler.next(options);
          },
        ),
      );
      final remoteApi = remote
          ? TwitchPlaybackApiService(
              gql: TwitchGqlApiService(client: remoteClient!),
              viewerAuthProvider: () async =>
                  const TwitchPlaybackViewerAuthResolution.anonymous(),
            )
          : null;
      final player = await Player.create(
        configuration: const PlayerConfiguration(options: {'aid': 'no'}),
      );
      expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
      // ignore: invalid_use_of_visible_for_testing_member
      TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
      final session = TwitchMediaKitPlayerHost.acquire();
      final diagnostics = TwitchNativeLogDiagnostics();
      var diagnosticPhase = 'controller';
      final phaseDiagnostics = <String, TwitchNativeLogDiagnostics>{
        for (final phase in [
          'controller',
          'watch_playback',
          'capture',
          'cleanup',
        ])
          phase: TwitchNativeLogDiagnostics(),
      };
      final logs = player.stream.log.listen((log) {
        diagnostics.record(log.text);
        phaseDiagnostics[diagnosticPhase]!.record(log.text);
      });
      final boundaryKey = GlobalKey();
      try {
        await session.ensureReady();
        await tester.pump(const Duration(milliseconds: 400));
        debugPrint(
          '[ReadonlyTest] surface phase=controller categories=${phaseDiagnostics[diagnosticPhase]!.snapshot}',
        );
        diagnosticPhase = 'watch_playback';
        TwitchChannelVideo? selectedVod;
        TwitchChannelClip? selectedClip;
        TwitchLiveStream? selectedGuestLive;
        TwitchChannelVideo? selectedGuestArchive;
        if (guestReplay || guestArchive) {
          final discovery = TwitchGuestDiscoveryService(client: remoteClient!);
          selectedGuestLive = await discovery.fetchLiveStream(
            login: remoteChannel,
          );
          expect(selectedGuestLive, isNotNull);
          expect(selectedGuestLive!.startedAt, isNotNull);
          if (guestArchive) {
            final videos = await discovery.fetchChannelVideos(
              userId: selectedGuestLive.userId,
              first: 20,
            );
            final liveStartedAt = selectedGuestLive.startedAt!;
            final candidates = videos.videos.where((video) {
              final created = video.createdAt ?? video.publishedAt;
              return video.type.trim().toLowerCase() == 'archive' &&
                  video.isLikelyGrowingArchive &&
                  created != null &&
                  created.difference(liveStartedAt).inSeconds.abs() <= 120;
            }).toList();
            debugPrint(
              '[ReadonlyTest] guest archive channel=$remoteChannel publicVideos=${videos.videos.length} matchingLiveArchives=${candidates.length}',
            );
            expect(
              candidates,
              isNotEmpty,
              reason:
                  'Public archive must match actual live start, not an older VOD.',
            );
            selectedGuestArchive = candidates.first;
          }
        }
        if (remote && remoteKind != 'live') {
          final discovery = TwitchGuestDiscoveryService(client: remoteClient!);
          final found = await discovery.searchChannels(query: remoteChannel);
          final ids = [
            ...found.liveStreams
                .where((stream) => stream.channelLogin == remoteChannel)
                .map((stream) => stream.userId),
            ...found.offlineChannels
                .where((channel) => channel.channelLogin == remoteChannel)
                .map((channel) => channel.broadcasterId),
          ];
          expect(ids, isNotEmpty);
          if (remoteKind == 'vod') {
            final page = await discovery.fetchChannelVideos(
              userId: ids.first,
              first: 20,
            );
            final candidates = page.videos
                .where(
                  (video) =>
                      !video.isLikelyGrowingArchive &&
                      (video.parsedDuration?.inSeconds ?? 0) > 30,
                )
                .toList();
            debugPrint(
              '[ReadonlyTest] anonymous media metadata kind=vod channel=$remoteChannel candidates=${candidates.length}',
            );
            expect(candidates, isNotEmpty);
            selectedVod = candidates.first;
          } else {
            final page = await discovery.fetchChannelClips(
              broadcasterId: ids.first,
              first: 20,
            );
            final candidates = page.clips
                .where((clip) => clip.duration > 20)
                .toList();
            debugPrint(
              '[ReadonlyTest] anonymous media metadata kind=clip channel=$remoteChannel candidates=${candidates.length}',
            );
            expect(candidates, isNotEmpty);
            selectedClip = candidates.first;
          }
        }
        const localRoot = String.fromEnvironment(
          'VIOCLASS_LOCAL_AV_FIXTURE_ROOT',
        );
        final recordedApi = recordedQuality
            ? _LocalRecordedQualityApi([
                for (final size in ['320x180', '640x360'])
                  TwitchM3u8Variant(
                    name: size == '320x180' ? '180p' : '360p',
                    resolution: size,
                    url: io.File('$localRoot/$size.mkv').uri.toString(),
                    sourceTag: 'local-fixture',
                  ),
              ])
            : null;
        if (recordedQuality) {
          selectedClip = TwitchChannelClip.fromHelixJson({
            'id': 'local-quality-clip',
            'broadcaster_id': '7',
            'broadcaster_name': 'Fixture',
            'title': 'Local recorded quality',
            'duration': 30,
            'vod_offset': -1,
          });
        }
        final localUri = io.File(
          'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-decoder-fixture.mp4',
        ).uri;
        final TwitchPlaylistPlayerRuntime runtime = remote
            ? TwitchPlaylistPlayerRuntime(playbackApi: remoteApi!)
            : nativeQuality
            ? _LocalQualityRuntime(localUri)
            : _LocalWatchRuntime(localUri);
        final services = watch_fixture.isolatedWatchPlaybackServices(
          session: session,
          runtime: runtime,
          playbackApi: recordedApi ?? remoteApi,
          liveStream: selectedGuestLive,
        );
        var clipEntryWrites = 0;
        if (guestClipEntry) {
          services.apiClient.dio.interceptors.insert(
            0,
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (options.method != 'GET' &&
                    (!options.path.contains('gql') ||
                        options.data.toString().contains('mutation'))) {
                  clipEntryWrites++;
                }
                handler.next(options);
              },
            ),
          );
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: TwitchWatchRouteGuard(
                initialMetadata: selectedGuestLive == null
                    ? const TwitchStreamHeaderMetadata.empty()
                    : TwitchStreamHeaderMetadata.fromLiveStream(
                        selectedGuestLive,
                      ),
                initialChannelLogin: remote ? remoteChannel : 'fixture',
                initialActiveDvrVideo: selectedGuestArchive,
                initialVodVideo: selectedVod,
                initialClip: selectedClip,
                initialVodPlaybackOnly: remoteKind == 'vod',
                initialServices: services,
                initialChatRuntimeFactory: realGuestChat
                    ? ({required authenticated}) {
                        expectSync(authenticated, isFalse);
                        return guestChat!;
                      }
                    : watch_fixture.isolatedWatchChatRuntime,
              ),
            ),
          ),
        );
        await waitFor(
          tester,
          () =>
              player.state.position.inMilliseconds > 300 &&
              find.byType(TwitchMediaKitVideoSurface).evaluate().length == 1 &&
              find.byType(Texture).evaluate().isNotEmpty,
          'guest native decode and Flutter texture mounted',
          timeout: const Duration(seconds: 45),
        );
        if (nativeControls) {
          await exerciseIsolatedNativeControls(tester, player);
        }
        if (nativeQuality) {
          const root = String.fromEnvironment('VIOCLASS_LOCAL_AV_FIXTURE_ROOT');
          final qualityRuntime = runtime as _LocalQualityRuntime;
          final choices =
              recordedApi?.choices ??
              [
                for (final size in ['320x180', '640x360'])
                  TwitchM3u8Variant(
                    name: size == '320x180' ? '180p' : '360p',
                    resolution: size,
                    url: io.File('$root/$size.mkv').uri.toString(),
                    sourceTag: 'local-fixture',
                  ),
              ];
          qualityRuntime.localChoices = choices;
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          state.notifyControllerChanged();
          await tester.pump();
          double number(String name) =>
              double.tryParse(player.getProperty(name)) ?? -1;
          if (recordedQuality) {
            await waitFor(
              tester,
              () => player.state.position.inSeconds >= 5,
              'recorded source reaches five seconds',
              timeout: const Duration(seconds: 10),
            );
            expect(recordedApi!.resolves, 1);
          }
          for (final variant in choices) {
            final button = find.byType(QualityButton).first;
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: tester.getCenter(button));
            await tester.pump(const Duration(milliseconds: 200));
            final pausedSwitch =
                (recordedQuality || pausedQuality) &&
                identical(variant, choices.last);
            if (pausedSwitch) {
              await tester.tap(find.byIcon(Icons.pause).hitTestable().first);
              await waitFor(
                tester,
                () => !player.state.playing,
                'pause before recorded quality switch',
                timeout: const Duration(seconds: 3),
              );
              await tester.pump(const Duration(milliseconds: 200));
            }
            final previousPosition = player.state.position;
            await tester.tap(button.hitTestable());
            await mouse.removePointer();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text(variant.displayName).hitTestable().last);
            await waitFor(
              tester,
              () =>
                  (recordedQuality
                      ? state.currentVodQualityVariant == variant
                      : qualityRuntime.currentVariant == variant) &&
                  TwitchMediaKitPlayerHost.currentMediaUri == variant.url &&
                  number('video-params/h') == variant.height &&
                  player.state.playing == !pausedSwitch,
              'quality UI changes native resolution ${variant.name}',
              timeout: const Duration(seconds: 10),
            );
            expect(number('video-params/w'), variant.height == 180 ? 320 : 640);
            if (recordedQuality) {
              expect(
                player.state.position.inMilliseconds,
                greaterThanOrEqualTo(previousPosition.inMilliseconds - 1000),
              );
            }
            final before = player.state.position;
            await tester.pump(const Duration(seconds: 2));
            if (pausedSwitch) {
              expect(
                (player.state.position - before).inMilliseconds.abs(),
                lessThan(500),
              );
              await mouse.addPointer(location: tester.getCenter(button));
              await tester.pump(const Duration(milliseconds: 200));
              await tester.tap(
                find.byIcon(Icons.play_arrow).hitTestable().first,
              );
              await mouse.removePointer();
              await tester.pump(const Duration(seconds: 2));
              expect(
                player.state.position - before,
                greaterThan(const Duration(seconds: 1)),
              );
            } else {
              expect(
                player.state.position - before,
                greaterThan(const Duration(seconds: 1)),
              );
            }
            expect(
              tester
                  .widget<QualityButton>(find.byType(QualityButton).first)
                  .currentVariant,
              variant,
            );
          }
          expect(qualityRuntime.switches, recordedQuality ? 0 : 2);
          if (recordedQuality) expect(recordedApi!.resolves, 1);
          expect(state.viewerId, isNull);
          expect(remoteRequests, 0);
          expect(tester.takeException(), isNull);
          debugPrint(
            '[ReadonlyTest] native quality complete recorded=$recordedQuality UISelections=2 heights=180,360 widths=320,640 playbackAdvanced=true requests=0',
          );
          return;
        }
        if (nativeAudio) {
          const root = String.fromEnvironment('VIOCLASS_LOCAL_AV_FIXTURE_ROOT');
          final source = io.File('$root/640x360.mkv').uri.toString();
          // The initial known video runs aid=no. Enable audio only when opening
          // the explicit PCM fixture, not the older fragmented AAC fixture.
          await player.stop();
          player.setProperty('aid', 'auto');
          await player.setVolume(20);
          await TwitchMediaKitPlayerHost.restoreSharedMedia(
            uri: source,
            play: true,
            forceOpen: true,
          );
          double number(String name) =>
              double.tryParse(player.getProperty(name)) ?? -1;
          await waitFor(
            tester,
            () =>
                number('video-params/h') == 360 &&
                number('audio-params/samplerate') == 48000 &&
                number('audio-out-params/samplerate') > 0 &&
                number('audio-pts') > .3,
            'local PCM audio decoding and native output',
            timeout: const Duration(seconds: 10),
          );
          final before = number('audio-pts');
          await tester.pump(const Duration(seconds: 2));
          expect(number('audio-pts') - before, greaterThan(1));
          expect((number('volume') - 20).abs(), lessThan(1));
          expect(TwitchMediaKitPlayerHost.currentMediaUri, source);
          expect(diagnostics.snapshot['audio_decode_failed'] ?? 0, 0);
          expect(diagnostics.snapshot['audio_output_failed'] ?? 0, 0);
          expect(remoteRequests, 0);
          expect(tester.takeException(), isNull);
          debugPrint(
            '[ReadonlyTest] native audio complete inputHz=${number('audio-params/samplerate')} outputHz=${number('audio-out-params/samplerate')} clockAdvanced=true requests=0 categories=${diagnostics.snapshot}',
          );
          return;
        }
        if (guestClipEntry) {
          final state = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          final media = TwitchMediaKitPlayerHost.currentMediaUri;
          expect(state.viewerId, isNull);
          expect(state.showOfflineChannelPlaceholder, false);
          expect(media, isNotNull);
          final clip = find.byType(CreateClipButton).first;
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: tester.getCenter(clip));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.widget<CreateClipButton>(clip).onPressed, isNotNull);
          await tester.tap(clip.hitTestable());
          await mouse.removePointer();
          await waitFor(
            tester,
            () => find.byType(TwitchLinkedLoginPage).evaluate().length == 1,
            'guest live clip button opens isolated login',
            timeout: const Duration(seconds: 5),
          );
          final loginPage = tester.widget<TwitchLinkedLoginPage>(
            find.byType(TwitchLinkedLoginPage),
          );
          expect(loginPage.mainAuthService, same(services.authService));
          expect(loginPage.webGqlAuthService, same(services.webGqlAuthService));
          expect(loginPage.dropsAuthService, same(services.dropsAuthService));
          Navigator.of(
            tester.element(find.byType(TwitchLinkedLoginPage)),
          ).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(TwitchLinkedLoginPage), findsNothing);
          expect(state.mounted, true);
          expect(state.channelLogin, 'fixture');
          expect(state.viewerId, isNull);
          expect(TwitchMediaKitPlayerHost.currentMediaUri, media);
          expect(clipEntryWrites, 0);
          expect(remoteRequests, 0);
          expect(tester.takeException(), isNull);
          debugPrint(
            '[ReadonlyTest] guest live clip entry complete isolatedLogin=true writes=0 remoteRequests=0',
          );
          return;
        }
        if (remote && remoteKind != 'live') {
          final initialState = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          await _probeReadonlyVideoFrames(tester, initialState);
          await waitFor(
            tester,
            () => player.state.position.inSeconds >= 5,
            'recorded guest reaches five seconds without seeking',
            timeout: const Duration(seconds: 15),
          );
          final variant = initialState.currentVodQualityVariant;
          debugPrint(
            '[ReadonlyTest] recorded source vod=${selectedVod != null} clip=${selectedClip != null} audioOnly=${variant?.isAudioOnly} height=${variant?.height} fps=${variant?.fpsRounded} directVariant=${variant != null && TwitchMediaKitPlayerHost.currentMediaUri == variant.url}',
          );
          if (remoteKind == 'vod') {
            for (final seconds in [5, 15, 30]) {
              await waitFor(
                tester,
                () => player.state.position.inSeconds >= seconds,
                'same guest VOD reaches $seconds seconds without seeking',
                timeout: const Duration(seconds: 20),
              );
              await _probeReadonlyVideoFrames(tester, initialState);
            }
          }
        }
        if (remote && remoteKind == 'live') {
          final initialState = tester.state<TwitchWatchPageState>(
            find.byType(TwitchWatchPage),
          );
          await _probeReadonlyVideoFrames(tester, initialState);
          await waitFor(
            tester,
            () => player.state.position.inSeconds >= 5,
            'same guest live reaches five seconds before visual assertion',
            timeout: const Duration(seconds: 15),
          );
          await _probeReadonlyVideoFrames(tester, initialState);
        }
        await player.pause();
        await tester.pump(const Duration(milliseconds: 300));
        final state = tester.state<TwitchWatchPageState>(
          find.byType(TwitchWatchPage),
        );
        expect(state.viewerId, isNull);
        expect(state.loadingAuth, isFalse);
        expect(state.showOfflineChannelPlaceholder, isFalse);
        debugPrint(
          '[ReadonlyTest] surface phase=watch_playback categories=${phaseDiagnostics[diagnosticPhase]!.snapshot}',
        );
        diagnosticPhase = 'capture';
        if (remote) await _probeReadonlyVideoFrames(tester, state);
        final decoderPng = await player.screenshot();
        expect(decoderPng, isNotNull);
        final codec = await instantiateImageCodec(decoderPng!);
        final nativeImage = (await codec.getNextFrame()).image;
        final nativePixels = await nativeImage.toByteData(
          format: ImageByteFormat.rawRgba,
        );
        var nativeNonBlack = 0;
        for (var i = 0; i < nativePixels!.lengthInBytes; i += 4) {
          if (nativePixels.getUint8(i) > 16 ||
              nativePixels.getUint8(i + 1) > 16 ||
              nativePixels.getUint8(i + 2) > 16) {
            nativeNonBlack++;
          }
        }
        final nativeFraction =
            nativeNonBlack / (nativeImage.width * nativeImage.height);
        nativeImage.dispose();
        codec.dispose();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final pixels = await image.toByteData(format: ImageByteFormat.rawRgba);
        final texture = tester.getRect(find.byType(Texture).first);
        final origin = boundary.localToGlobal(Offset.zero);
        final sample = Rect.fromCenter(
          center: texture.center - origin,
          width: texture.width * .6,
          height: texture.height * .6,
        );
        var nonBlack = 0;
        var total = 0;
        final colors = <int>{};
        for (var y = sample.top.ceil(); y < sample.bottom.floor(); y += 2) {
          for (var x = sample.left.ceil(); x < sample.right.floor(); x += 2) {
            final offset = (y * image.width + x) * 4;
            final r = pixels!.getUint8(offset);
            final g = pixels.getUint8(offset + 1);
            final b = pixels.getUint8(offset + 2);
            if (r > 16 || g > 16 || b > 16) nonBlack++;
            colors.add((r << 16) | (g << 8) | b);
            total++;
          }
        }
        if (!remote) {
          final png = await image.toByteData(format: ImageByteFormat.png);
          await io.File(
            'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-guest-surface-fixture.png',
          ).writeAsBytes(
            png!.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          );
        }
        image.dispose();
        debugPrint(
          '[ReadonlyTest] guest surface positionMs=${player.state.position.inMilliseconds} nativeNonBlack=$nativeFraction surfaceNonBlack=${nonBlack / total} colors=${colors.length} samples=$total guest=${state.viewerId == null} categories=${diagnostics.snapshot}',
        );
        expect(nativeFraction, greaterThan(.1));
        expect(total, greaterThan(100));
        expect(nonBlack / total, greaterThan(.1));
        expect(colors.length, greaterThan(32));
        if (remote) {
          expect(
            remoteApi!.lastViewerAuthState,
            TwitchPlaybackViewerAuthState.anonymous,
          );
          expect(remoteRequests, greaterThan(0));
          expect(authorizationRequests, 0);
          expect(state.chatController.isReadOnlyGuest, isTrue);
          Map<String, Object?> format;
          if (remoteKind == 'live') {
            final upstream = runtime.upstreamPlaylistUri;
            expect(upstream, isNotNull);
            format = await probeLiveVariantFormat(upstream!);
          } else {
            format = {
              'recorded': true,
              'vod': selectedVod != null,
              'clip': selectedClip != null,
            };
          }
          await player.play();
          await waitFor(
            tester,
            () => player.state.playing && !player.state.buffering,
            'anonymous guest resumes actual public live',
          );
          final before = player.state.position;
          await tester.pump(const Duration(seconds: 10));
          final delta = (player.state.position - before).inMilliseconds;
          expect(delta, greaterThan(7000));
          debugPrint(
            '[ReadonlyTest] remote guest kind=$remoteKind channel=$remoteChannel anonymous=${remoteApi.lastViewerAuthState == TwitchPlaybackViewerAuthState.anonymous} requests=$remoteRequests authorizationRequests=$authorizationRequests advancesMs=$delta format=$format',
          );
          if (guestReplay || guestArchive) {
            Future<void> settleGuestClock(String phase) async {
              Duration? previous;
              Duration? baseline;
              DateTime? since;
              var resets = 0;
              await waitFor(
                tester,
                () {
                  final playback = player.state;
                  if (!playback.playing ||
                      playback.buffering ||
                      state.liveTimelineActionInFlight) {
                    baseline = null;
                    since = null;
                    return false;
                  }
                  if (previous != null && playback.position < previous!) {
                    resets++;
                    baseline = null;
                    since = null;
                  }
                  previous = playback.position;
                  baseline ??= playback.position;
                  since ??= DateTime.now();
                  return DateTime.now().difference(since!) >=
                          const Duration(seconds: 2) &&
                      playback.position - baseline! >=
                          const Duration(seconds: 1);
                },
                'guest $phase clock settles and advances',
                timeout: const Duration(seconds: 45),
              );
              debugPrint(
                '[ReadonlyTest] guest clock phase=$phase startupResets=$resets positionMs=${player.state.position.inMilliseconds}',
              );
            }

            expect(state.liveTimelineStartedAt, selectedGuestLive!.startedAt);
            if (guestArchive) {
              await waitFor(
                tester,
                () => state.hasUsableLiveDvrArchive,
                'guest anonymous matching archive warms formal DVR',
                timeout: const Duration(seconds: 45),
              );
            } else {
              expect(state.hasUsableLiveDvrArchive, isFalse);
            }
            final overlay = find.byType(WatchControlsOverlay);
            await tester.tap(overlay);
            await tester.pump(const Duration(milliseconds: 250));
            final strip = find.descendant(
              of: overlay,
              matching: find.byType(TwitchVodPlaybackStrip),
            );
            expect(strip, findsOneWidget);
            expect(
              tester
                  .widget<TwitchVodPlaybackStrip>(strip)
                  .liveSeekWindowDuration,
              guestArchive ? isNull : const Duration(seconds: 20),
            );
            final slider = find
                .descendant(
                  of: strip,
                  matching: find.byWidgetPredicate(
                    (widget) => widget is Slider && widget.max == 1,
                  ),
                )
                .hitTestable();
            expect(slider, findsOneWidget);
            expect(tester.widget<Slider>(slider).onChangeEnd, isNotNull);
            final rect = tester.getRect(slider);
            final gesture = await tester.startGesture(rect.center);
            Duration? archiveTarget;
            try {
              await gesture.moveBy(Offset(rect.width * .3, 0));
              await tester.pump(const Duration(milliseconds: 200));
              expect(tester.widget<Slider>(slider).value, closeTo(.8, .05));
              archiveTarget =
                  state.playbackTimelineController.snapshot.position;
            } finally {
              await gesture.up();
            }
            await waitFor(
              tester,
              () =>
                  (guestArchive
                      ? runtime.usingLiveDvrBridge
                      : runtime.usingLiveBufferReplay) &&
                  player.state.playing &&
                  !player.state.buffering &&
                  player.state.position.inMilliseconds > 300,
              'guest actual timeline drag opens decoded replay',
              timeout: const Duration(seconds: 45),
            );
            await settleGuestClock('replay');
            if (guestArchive) {
              expect(runtime.liveDvrBridgeTimelinePosition, isNotNull);
              expect(
                (runtime.liveDvrBridgeTimelinePosition! - archiveTarget)
                    .inMilliseconds
                    .abs(),
                lessThan(2000),
              );
            }
            final replayPosition = player.state.position;
            const replaySeconds = int.fromEnvironment(
              'TWITCH_READONLY_GUEST_REPLAY_SECONDS',
              defaultValue: 10,
            );
            expect(replaySeconds, inInclusiveRange(10, 120));
            expect(replaySeconds % 10, 0);
            int? initialLag;
            var maxLagDrift = 0;
            for (var seconds = 10; seconds <= replaySeconds; seconds += 10) {
              final previous = player.state.position;
              await tester.pump(const Duration(seconds: 10));
              final step = (player.state.position - previous).inMilliseconds;
              final clock = state.playbackTimelineController;
              final duration = state.currentLiveTimelineDuration();
              expect(duration, isNotNull);
              final edge = clock.displayDurationFor(duration!);
              final lag = (edge - clock.positionFor(edge)).inMilliseconds;
              initialLag ??= lag;
              final drift = (lag - initialLag).abs();
              if (drift > maxLagDrift) maxLagDrift = drift;
              debugPrint(
                '[ReadonlyTest] guest replay step seconds=$seconds deltaMs=$step lagMs=$lag maxLagDriftMs=$maxLagDrift playing=${player.state.playing} buffering=${player.state.buffering} archive=$guestArchive replay=${runtime.usingLiveTimelineReplay}',
              );
              expect(step, greaterThan(7000));
              expect(player.state.playing, isTrue);
              expect(player.state.buffering, isFalse);
              expect(
                guestArchive
                    ? runtime.usingLiveDvrBridge
                    : runtime.usingLiveBufferReplay,
                isTrue,
              );
            }
            final replayDelta =
                (player.state.position - replayPosition).inMilliseconds;
            debugPrint(
              '[ReadonlyTest] guest replay baselineMs=${replayPosition.inMilliseconds} endMs=${player.state.position.inMilliseconds} deltaMs=$replayDelta',
            );
            expect(replayDelta, greaterThan(7000));
            expect(player.state.buffering, isFalse);
            expect(maxLagDrift, lessThan(2000));
            await _probeReadonlyVideoFrames(tester, state);
            if (const bool.fromEnvironment(
              'TWITCH_READONLY_GUEST_ARCHIVE_PAUSED',
            )) {
              expect(guestArchive, isTrue);
              await tester.tap(overlay);
              await tester.pump(const Duration(milliseconds: 250));
              await tester.tap(
                find
                    .descendant(of: overlay, matching: find.byIcon(Icons.pause))
                    .hitTestable(),
              );
              await waitFor(
                tester,
                () => !player.state.playing,
                'guest Archive UI pause stops playback',
              );
              final oldUri = TwitchMediaKitPlayerHost.currentMediaUri;
              final pausedRect = tester.getRect(slider);
              final pausedDrag = await tester.startGesture(pausedRect.center);
              late Duration pausedTarget;
              try {
                await pausedDrag.moveBy(Offset(-pausedRect.width * .2, 0));
                await tester.pump(const Duration(milliseconds: 200));
                expect(tester.widget<Slider>(slider).value, closeTo(.3, .05));
                pausedTarget =
                    state.playbackTimelineController.snapshot.position;
              } finally {
                await pausedDrag.up();
              }
              await waitFor(
                tester,
                () {
                  final resolved = runtime.liveDvrBridgeTimelinePosition;
                  return TwitchMediaKitPlayerHost.currentMediaUri != oldUri &&
                      resolved != null &&
                      (resolved - pausedTarget).inMilliseconds.abs() < 2000 &&
                      !state.liveTimelineActionInFlight &&
                      !player.state.playing &&
                      !player.state.buffering;
                },
                'guest paused Archive drag resolves without starting playback',
                timeout: const Duration(seconds: 45),
              );
              final pausedPosition = player.state.position;
              await tester.pump(const Duration(seconds: 2));
              expect(player.state.playing, isFalse);
              expect(
                (player.state.position - pausedPosition).inMilliseconds.abs(),
                lessThan(500),
              );
              expect(
                (state.playbackTimelineController.snapshot.position -
                        pausedTarget)
                    .inMilliseconds
                    .abs(),
                lessThan(2000),
              );
              await tester.tap(overlay);
              await tester.pump(const Duration(milliseconds: 250));
              await tester.tap(
                find
                    .descendant(
                      of: overlay,
                      matching: find.byIcon(Icons.play_arrow),
                    )
                    .hitTestable(),
              );
              await settleGuestClock('paused-archive-resumed');
              final resumedPosition = player.state.position;
              await tester.pump(const Duration(seconds: 10));
              final resumedDelta =
                  (player.state.position - resumedPosition).inMilliseconds;
              expect(resumedDelta, greaterThan(7000));
              expect(runtime.usingLiveDvrBridge, isTrue);
              expect(player.state.buffering, isFalse);
              debugPrint(
                '[ReadonlyTest] guest paused Archive channel=$remoteChannel targetMs=${pausedTarget.inMilliseconds} held=true resumedDeltaMs=$resumedDelta',
              );
            }
            await tester.tap(overlay);
            await tester.pump(const Duration(milliseconds: 250));
            final returnLive = find
                .descendant(
                  of: strip,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget.runtimeType.toString() == '_LiveStatusButton',
                  ),
                )
                .hitTestable();
            expect(returnLive, findsOneWidget);
            final returnGesture = find.descendant(
              of: returnLive,
              matching: find.byType(GestureDetector),
            );
            expect(
              tester.widget<GestureDetector>(returnGesture).onTap,
              isNotNull,
            );
            await tester.tap(returnLive);
            await waitFor(
              tester,
              () =>
                  !runtime.usingLiveBufferReplay &&
                  !runtime.usingLiveDvrBridge &&
                  player.state.playing &&
                  !player.state.buffering &&
                  player.state.position.inMilliseconds > 300,
              'guest returns to decoded actual live',
              timeout: const Duration(seconds: 45),
            );
            await settleGuestClock('returned-live');
            final livePosition = player.state.position;
            await tester.pump(const Duration(seconds: 10));
            final liveDelta =
                (player.state.position - livePosition).inMilliseconds;
            expect(liveDelta, greaterThan(7000));
            expect(authorizationRequests, 0);
            expect(state.chatController.isReadOnlyGuest, isTrue);
            debugPrint(
              '[ReadonlyTest] guest timeline channel=$remoteChannel replayDeltaMs=$replayDelta liveDeltaMs=$liveDelta anonymous=true authorizationRequests=$authorizationRequests',
            );
          }
          if (remoteKind == 'vod') {
            final originalUri = TwitchMediaKitPlayerHost.currentMediaUri;
            await player.pause();
            for (final seconds in [1, 5, 15]) {
              final target = Duration(seconds: seconds);
              await player.seek(target);
              await waitFor(
                tester,
                () =>
                    !player.state.buffering &&
                    (player.state.position - target).inMilliseconds.abs() < 500,
                'same VOD diagnostic seek reaches $seconds seconds',
                timeout: const Duration(seconds: 15),
              );
              await tester.pump(const Duration(milliseconds: 500));
              Map<String, Object?>? sample;
              await _probeReadonlyVideoFrames(
                tester,
                state,
                onNativeSummary: (summary) => sample = summary,
              );
              expect(sample, isNotNull);
              expect(TwitchMediaKitPlayerHost.currentMediaUri, originalUri);
              debugPrint(
                '[ReadonlyTest] recorded repeat targetSeconds=$seconds positionMs=${player.state.position.inMilliseconds} sameSource=${TwitchMediaKitPlayerHost.currentMediaUri == originalUri} paused=${!player.state.playing} nativeSummary=$sample',
              );
            }
          }
          if (realGuestChat) {
            await waitFor(
              tester,
              () => guestChat!.connected && guestChat.messages.isNotEmpty,
              'anonymous guest IRC receives actual public messages',
              timeout: const Duration(seconds: 45),
            );
            expect(state.chatController.canSendForCurrentViewer, isFalse);
            expect(state.chatController.isReadOnlyGuest, isTrue);
            expect(guestChat!.usingDualIrcMode, isFalse);
            expect(guestChat.pendingOutgoingCount, 0);
            expect(guestIrc!.connects, 1);
            expect(guestIrc.sendAttempts, 0);
            debugPrint(
              '[ReadonlyTest] remote guest chat channel=$remoteChannel connected=${guestChat.connected} messages=${guestChat.messages.length} rawEvents=${guestChat.rawEventCount} connects=${guestIrc.connects} sendAttempts=${guestIrc.sendAttempts} canSend=${state.chatController.canSendForCurrentViewer} guest=${state.chatController.isReadOnlyGuest}',
            );
          }
        }
        await tester.pump(const Duration(milliseconds: 200));
        debugPrint(
          '[ReadonlyTest] surface phase=capture categories=${phaseDiagnostics[diagnosticPhase]!.snapshot}',
        );
      } catch (error, stack) {
        final sourceLine =
            RegExp(
              r'twitch_readonly_app_test\.dart:(\d+)',
            ).firstMatch(stack.toString())?.group(1) ??
            'unknown';
        debugPrint(
          '[ReadonlyTest] guest surface failure remote=$remote sourceLine=$sourceLine errorType=${error.runtimeType} requests=$remoteRequests authorizationRequests=$authorizationRequests positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} categories=${diagnostics.snapshot}',
        );
        rethrow;
      } finally {
        diagnosticPhase = 'cleanup';
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 200));
        if (realGuestChat) {
          await waitFor(
            tester,
            () => !guestIrc!.isConnected,
            'guest IRC disconnects on watch disposal',
            timeout: const Duration(seconds: 5),
          );
          expect(guestIrc!.sendAttempts, 0);
        }
        session.release();
        await logs.cancel();
        await TwitchMediaKitPlayerHost.disposeNow();
        remoteClient?.close(force: true);
        debugPrint(
          '[ReadonlyTest] surface phase=cleanup categories=${phaseDiagnostics[diagnosticPhase]!.snapshot}',
        );
      }
    });
    return;
  }

  if (const bool.fromEnvironment('TWITCH_READONLY_PARTIAL_DECODE')) {
    testWidgets('local fragmented MP4 partial retry decoder diagnosis', (
      tester,
    ) async {
      MediaKit.ensureInitialized();
      final rawBytes = await io.File(
        'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-decoder-fixture.mp4',
      ).readAsBytes();
      final bytes =
          const bool.fromEnvironment('TWITCH_READONLY_FIXTURE_MOOF_RELATIVE')
          ? twitchMoofRelativeFixture(rawBytes)
          : rawBytes;
      var offset = 0;
      while (offset + 8 <= bytes.length) {
        final size =
            (bytes[offset] << 24) |
            (bytes[offset + 1] << 16) |
            (bytes[offset + 2] << 8) |
            bytes[offset + 3];
        final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
        if (type == 'moof') break;
        expect(size, greaterThanOrEqualTo(8));
        offset += size;
      }
      expect(offset + 10, lessThan(bytes.length));
      expect(ascii.decode(bytes.sublist(offset + 4, offset + 8)), 'moof');
      if (const bool.fromEnvironment('TWITCH_READONLY_EMPTY_INIT_NATIVE') ||
          const bool.fromEnvironment('TWITCH_READONLY_REPLACE_INIT_NATIVE')) {
        await _exerciseEmptyInitializationNative(
          tester,
          bytes,
          offset,
          replaceInitialization: const bool.fromEnvironment(
            'TWITCH_READONLY_REPLACE_INIT_NATIVE',
          ),
          reopenDuringInitialization: const bool.fromEnvironment(
            'TWITCH_READONLY_REOPEN_PENDING_INIT_NATIVE',
          ),
          resetFragmentTimestamps: const bool.fromEnvironment(
            'TWITCH_READONLY_RESET_INIT_TIMESTAMPS',
          ),
        );
        return;
      }
      if (const bool.fromEnvironment('TWITCH_READONLY_PARTIAL_PROXY')) {
        const rejectRetry = bool.fromEnvironment(
          'TWITCH_READONLY_PARTIAL_REJECT',
        );
        const watchRecovery = bool.fromEnvironment('TWITCH_READONLY_WATCH_EOF');
        const watchSurface = bool.fromEnvironment(
          'TWITCH_READONLY_WATCH_SURFACE',
        );
        const switchDuringRecovery = bool.fromEnvironment(
          'TWITCH_READONLY_WATCH_SWITCH',
        );
        const switchDuringNativeOpen = bool.fromEnvironment(
          'TWITCH_READONLY_WATCH_OPEN_SWITCH',
        );
        if (watchSurface) expect(watchRecovery, isTrue);
        if (switchDuringRecovery) expect(watchSurface, isTrue);
        if (switchDuringNativeOpen) expect(switchDuringRecovery, isTrue);
        for (final partial in rejectRetry ? [true] : [false, true]) {
          final upstream = await io.HttpServer.bind(
            io.InternetAddress.loopbackIPv4,
            0,
          );
          final prefetched = Completer<void>();
          final readerReady = Completer<void>();
          final recoveryResponseReady = Completer<void>();
          final recoveryResponseRelease = Completer<void>();
          var requests = 0;
          final fragment = bytes.sublist(offset);
          final serving = upstream.listen((request) async {
            if (request.uri.path == '/live.m3u8') {
              request.response.write(
                '#EXTM3U\n#EXT-X-TARGETDURATION:3\n#EXT-X-MEDIA-SEQUENCE:0\n'
                '#EXT-X-MAP:URI="/init.mp4"\n#EXTINF:2.769,\n/segment.m4s\n',
              );
            } else if (request.uri.path == '/init.mp4') {
              await prefetched.future;
              if (rejectRetry) await readerReady.future;
              request.response.add(bytes.sublist(0, offset));
            } else {
              requests++;
              if (switchDuringRecovery && requests == 3) {
                recoveryResponseReady.complete();
                await recoveryResponseRelease.future;
              }
              request.response.contentLength = fragment.length;
              if (partial && requests == 1) {
                final socket = await request.response.detachSocket();
                socket.add(fragment.take(10).toList());
                await socket.flush();
                socket.destroy();
                prefetched.complete();
                return;
              }
              final body = rejectRetry && requests == 2
                  ? (fragment.toList()..[0] ^= 1)
                  : fragment;
              request.response.add(body);
              if (!prefetched.isCompleted) prefetched.complete();
            }
            await request.response.close();
          });
          final proxy = TwitchDartHlsLowLatencyProxy(
            upstreamPlaylistUrl: 'http://127.0.0.1:${upstream.port}/live.m3u8',
            upstreamHeaders: const {},
            outputFutureSegments: false,
            prefetchSegmentCount: 1,
            startupMode: TwitchHlsStartupMode.latestNormalImmediate,
          );
          final player = await Player.create(
            configuration: const PlayerConfiguration(
              options: watchSurface
                  ? {'aid': 'no'}
                  : {'aid': 'no', 'vid': 'auto', 'vo': 'null'},
            ),
          );
          final diagnostics = TwitchNativeLogDiagnostics();
          final router = watchRecovery
              ? TwitchStableHlsProxyRouter(
                  upstreamHeaders: const {},
                  outputFutureSegments: false,
                  prefetchSegmentCount: 1,
                  startupMode: TwitchHlsStartupMode.latestNormalImmediate,
                )
              : null;
          final logs = player.stream.log.listen(
            (log) => diagnostics.record(log.text),
          );
          TwitchMediaKitPlayerSession? surfaceSession;
          TwitchMediaKitPlayerSession? nextSurfaceSession;
          try {
            if (router != null) {
              await router.start(
                upstreamPlaylistUrl:
                    'http://127.0.0.1:${upstream.port}/live.m3u8',
              );
              expect(rejectRetry, isTrue);
              expect(TwitchMediaKitPlayerHost.playerOrNull, isNull);
              // ignore: invalid_use_of_visible_for_testing_member
              TwitchMediaKitPlayerHost.installIsolatedPlayerForTesting(player);
              SharedPreferences.setMockInitialValues({});
              if (watchSurface) {
                surfaceSession = TwitchMediaKitPlayerHost.acquire();
                await surfaceSession.ensureReady();
              }
              final boundaryKey = GlobalKey();
              final session = _LocalWatchSession(
                player,
                surfaceSession: surfaceSession,
              );
              final runtime = _LocalWatchRuntime(Uri.parse(router.streamTsUrl));
              final services = watch_fixture.isolatedWatchPlaybackServices(
                session: session,
                runtime: runtime,
              );
              _LocalWatchSession? nextSession;
              bool? oldNativePendingAtNextOpen;
              int? oldCompletedAtNextOpen;
              final nextUri = io.File(
                'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-decoder-fixture.mp4',
              ).uri;
              await tester.pumpWidget(
                RepaintBoundary(
                  key: boundaryKey,
                  child: MaterialApp(
                    home: Builder(
                      builder: (context) => Stack(
                        children: [
                          TwitchWatchPage(
                            initialChannelLogin: 'fixture',
                            initialServices: services,
                            initialChatRuntimeFactory:
                                watch_fixture.isolatedWatchChatRuntime,
                          ),
                          if (switchDuringRecovery)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: ElevatedButton(
                                key: const ValueKey('fixture-switch-watch'),
                                onPressed: () {
                                  nextSurfaceSession =
                                      TwitchMediaKitPlayerHost.acquire();
                                  nextSession = _LocalWatchSession(
                                    player,
                                    surfaceSession: nextSurfaceSession,
                                  );
                                  nextSession!.onOpenStarted = () {
                                    oldNativePendingAtNextOpen ??=
                                        session.opens > session.completedOpens;
                                    oldCompletedAtNextOpen ??=
                                        session.completedOpens;
                                  };
                                  final nextServices = watch_fixture
                                      .isolatedWatchPlaybackServices(
                                        session: nextSession!,
                                        runtime: _LocalWatchRuntime(nextUri),
                                      );
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => TwitchWatchPage(
                                        initialChannelLogin: 'fixture',
                                        initialServices: nextServices,
                                        initialChatRuntimeFactory: watch_fixture
                                            .isolatedWatchChatRuntime,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('測試切換來源'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await waitFor(
                tester,
                () => session.opens == 1,
                'controlled watch opens first source',
              );
              final attached = Stopwatch()..start();
              while ((await router.requestLiveStatus())?.activeClientCount !=
                  1) {
                if (attached.elapsed > const Duration(seconds: 5)) {
                  fail('Watch reader did not attach.');
                }
                await tester.pump(const Duration(milliseconds: 50));
              }
              readerReady.complete();
              await waitFor(
                tester,
                () => player.state.completed,
                'controlled watch receives native EOF',
                timeout: const Duration(seconds: 5),
              );
              final state = tester.state<TwitchWatchPageState>(
                find.byType(TwitchWatchPage),
              );
              final generation = state.watchLoadGeneration;
              debugPrint(
                '[ReadonlyTest] fault checkpoint requests=$requests opens=${session.opens} completedOpens=${session.completedOpens} nativeCompleted=${player.state.completed} positionMs=${player.state.position.inMilliseconds} recoveryResponsePending=${recoveryResponseReady.isCompleted && !recoveryResponseRelease.isCompleted} categories=${diagnostics.snapshot}',
              );
              debugPrint(
                '[ReadonlyTest] fault native reader transport=${router.streamReadDiagnostics}',
              );
              debugPrint(
                '[ReadonlyTest] fault native cache=${twitchNativePlaybackProperties(player.getProperty)}',
              );
              expect(requests, 2);
              if (switchDuringRecovery) {
                if (switchDuringNativeOpen) {
                  final openingStarted = Completer<void>();
                  session.onOpenStarted = () {
                    if (session.opens == 2 && !openingStarted.isCompleted) {
                      openingStarted.complete();
                    }
                  };
                  await openingStarted.future.timeout(
                    const Duration(seconds: 20),
                  );
                  session.onOpenStarted = null;
                } else {
                  await waitFor(
                    tester,
                    () =>
                        recoveryResponseReady.isCompleted && session.opens == 2,
                    'old recovery waits for gated media response',
                    timeout: const Duration(seconds: 20),
                  );
                }
                final oldGeneration = state.watchLoadGeneration;
                final nativeOpenPending =
                    session.opens > session.completedOpens;
                bool? nativePendingAtNextOwner;
                final owners = TwitchPlaybackSessionController.instance;
                void recordNextOwner() {
                  if (owners.playableState?.mediaUri == nextUri.toString()) {
                    nativePendingAtNextOwner ??=
                        session.opens > session.completedOpens;
                  }
                }

                owners.addListener(recordNextOwner);
                addTearDown(() => owners.removeListener(recordNextOwner));
                if (switchDuringNativeOpen) expect(nativeOpenPending, isTrue);
                debugPrint(
                  '[ReadonlyTest] switch recovery oldOpens=${session.opens} oldCompletedOpens=${session.completedOpens} nativeOpenPending=$nativeOpenPending mediaResponsePending=${!recoveryResponseRelease.isCompleted}',
                );
                await tester.tap(
                  find.byKey(const ValueKey('fixture-switch-watch')),
                );
                await tester.pump();
                await waitFor(
                  tester,
                  () =>
                      nextSession?.opens == 1 &&
                      TwitchMediaKitPlayerHost.currentMediaUri ==
                          nextUri.toString() &&
                      player.state.position.inMilliseconds > 500 &&
                      !player.state.completed,
                  'new watch owns and decodes while old response is pending',
                  timeout: const Duration(seconds: 15),
                );
                final nextState = tester.state<TwitchWatchPageState>(
                  find.byType(TwitchWatchPage),
                );
                debugPrint(
                  '[ReadonlyTest] controlled native-open overlap atClick=$nativeOpenPending atNextOpen=$oldNativePendingAtNextOpen oldCompletedAtNextOpen=$oldCompletedAtNextOpen atNewOwner=$nativePendingAtNextOwner strict=$switchDuringNativeOpen',
                );
                if (switchDuringNativeOpen) {
                  expect(
                    nativePendingAtNextOwner,
                    isTrue,
                    reason:
                        'New ownership must overlap the actual old native open.',
                  );
                }
                expect(nextState, isNot(same(state)));
                expect(state.mounted, isTrue);
                final nextGeneration = nextState.watchLoadGeneration;
                final beforeRelease = player.state.position.inMilliseconds;
                recoveryResponseRelease.complete();
                await tester.pump(const Duration(milliseconds: 500));
                expect(
                  TwitchMediaKitPlayerHost.currentMediaUri,
                  nextUri.toString(),
                );
                expect(
                  player.state.position.inMilliseconds,
                  greaterThan(beforeRelease + 150),
                );
                expect(state.watchLoadGeneration, oldGeneration);
                expect(nextState.watchLoadGeneration, nextGeneration);
                expect(session.opens, 2);
                expect(nextSession!.opens, 1);
                await _verifyRecoveredWatchPixels(
                  tester,
                  player,
                  boundaryKey,
                  switchedSource: true,
                );
                await tester.pump(const Duration(seconds: 10));
                expect(
                  TwitchMediaKitPlayerHost.currentMediaUri,
                  nextUri.toString(),
                );
                expect(session.opens, 2);
                expect(nextSession!.opens, 1);
                debugPrint(
                  '[ReadonlyTest] switched recovery oldMounted=${state.mounted} oldOpens=${session.opens} newOpens=${nextSession!.opens} positionMs=${player.state.position.inMilliseconds} nativeOpenPendingAtSwitch=$nativeOpenPending requests=$requests categories=${diagnostics.snapshot}',
                );
                expect(player.state.playing, isFalse);
                final resumePosition = player.state.position;
                final overlay = find.byType(WatchControlsOverlay);
                await tester.tap(overlay);
                await tester.pump(const Duration(milliseconds: 250));
                await tester.tap(
                  find
                      .descendant(
                        of: overlay,
                        matching: find.byIcon(Icons.play_arrow),
                      )
                      .hitTestable(),
                );
                await waitFor(
                  tester,
                  () =>
                      player.state.playing &&
                      !player.state.buffering &&
                      player.state.position >
                          resumePosition + const Duration(milliseconds: 300),
                  'new source play button resumes after old recovery release',
                  timeout: const Duration(seconds: 5),
                );
                await waitFor(
                  tester,
                  () =>
                      player.state.completed &&
                      player.state.position >
                          resumePosition + const Duration(milliseconds: 500),
                  'new finite source reaches natural EOF',
                  timeout: const Duration(seconds: 5),
                );
                expect(
                  TwitchMediaKitPlayerHost.currentMediaUri,
                  nextUri.toString(),
                );
                expect(state.watchLoadGeneration, oldGeneration);
                expect(nextState.watchLoadGeneration, nextGeneration);
                expect(session.opens, 2);
                expect(nextSession!.opens, 1);
                debugPrint(
                  '[ReadonlyTest] switched source resume EOF deltaMs=${(player.state.position - resumePosition).inMilliseconds} completed=${player.state.completed} durationMs=${player.state.duration.inMilliseconds} oldOpens=${session.opens} newOpens=${nextSession!.opens} sourceRetained=${TwitchMediaKitPlayerHost.currentMediaUri == nextUri.toString()}',
                );
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pump(const Duration(seconds: 1));
                continue;
              }
              await waitFor(
                tester,
                () =>
                    session.opens == 2 &&
                    !player.state.completed &&
                    player.state.position.inMilliseconds > 500,
                'original watch recovery poll reopens and decodes',
                timeout: const Duration(seconds: 20),
              );
              expect(state.watchLoadGeneration, generation + 1);
              expect(state.liveTimelineStreamId, 'fixture-live-stream');
              expect(requests, 3);
              final readerDiagnostics = router.streamReadDiagnostics;
              debugPrint(
                '[ReadonlyTest] recovered native cache=${twitchNativePlaybackProperties(player.getProperty)}',
              );
              debugPrint(
                '[ReadonlyTest] recovered native reader transport=$readerDiagnostics',
              );
              expect(readerDiagnostics['startsWithMp4Init'], isTrue);
              expect(readerDiagnostics['receivedBytes'] as int, greaterThan(0));
              expect(readerDiagnostics['flushedBytes'] as int, greaterThan(0));
              debugPrint(
                '[ReadonlyTest] controlled watch EOF opens=${session.opens} requests=$requests generationDelta=${state.watchLoadGeneration - generation} positionMs=${player.state.position.inMilliseconds} completed=${player.state.completed} guest=${state.viewerId == null} categories=${diagnostics.snapshot}',
              );
              if (watchSurface) {
                await _verifyRecoveredWatchPixels(tester, player, boundaryKey);
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 1));
              continue;
            }
            await proxy.start();
            if (rejectRetry) {
              Object? openError;
              final opening = player
                  .open(Media(proxy.streamTsUrl))
                  .then<void>(
                    (_) {},
                    onError: (Object error, StackTrace stack) {
                      openError = error;
                    },
                  );
              final attached = Stopwatch()..start();
              while ((await proxy.requestLiveStatus())?.activeClientCount !=
                  1) {
                if (attached.elapsed > const Duration(seconds: 5)) {
                  fail('Native reader did not attach before fault release.');
                }
                await tester.pump(const Duration(milliseconds: 50));
              }
              readerReady.complete();
              await opening.timeout(const Duration(seconds: 15));
              await tester.pump(const Duration(seconds: 5));
              final ended = player.state.completed;
              final failedStatus = await proxy.requestLiveStatus();
              debugPrint(
                '[ReadonlyTest] native EOF completed=$ended positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} proxyRunning=${failedStatus?.running} errorType=${openError?.runtimeType ?? 'none'} categories=${diagnostics.snapshot}',
              );
              expect(requests, 2);
              expect(failedStatus?.running, isFalse);
              await player
                  .open(Media(proxy.streamTsUrl))
                  .timeout(const Duration(seconds: 15));
              await tester.pump(const Duration(seconds: 10));
              debugPrint(
                '[ReadonlyTest] native EOF reopen completed=${player.state.completed} positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} requests=$requests',
              );
              expect(requests, 3);
              expect(player.state.position.inMilliseconds, greaterThan(500));
              expect(
                ended,
                isTrue,
                reason:
                    'Watch recovery currently relies on the native completed flag.',
              );
              continue;
            }
            final clock = Stopwatch()..start();
            while ((await proxy.requestLiveStatus())?.lastWrittenSequence !=
                0) {
              if (clock.elapsed > const Duration(seconds: 8)) {
                fail('Proxy fixture writer timed out.');
              }
              await tester.pump(const Duration(milliseconds: 50));
            }
            final status = await proxy.requestLiveStatus();
            expect(requests, partial ? 2 : 1);
            expect(status?.bufferedBytes, fragment.length);
            Object? openError;
            try {
              await player
                  .open(Media(proxy.streamTsUrl))
                  .timeout(const Duration(seconds: 15));
            } catch (error) {
              openError = error;
            }
            await tester.pump(const Duration(seconds: 10));
            debugPrint(
              '[ReadonlyTest] partial proxy partial=$partial requests=$requests replayBytes=${status?.bufferedBytes} positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} errorType=${openError?.runtimeType ?? 'none'} categories=${diagnostics.snapshot}',
            );
            expect(openError, isNull);
            expect(player.state.position.inMilliseconds, greaterThan(500));
          } catch (error, stack) {
            final line =
                RegExp(
                  r'twitch_readonly_app_test\.dart:(\d+)',
                ).firstMatch(stack.toString())?.group(1) ??
                'unknown';
            debugPrint(
              '[ReadonlyTest] controlled fixture failure type=${error.runtimeType} sourceLine=$line requests=$requests completed=${player.state.completed} positionMs=${player.state.position.inMilliseconds} categories=${diagnostics.snapshot}',
            );
            rethrow;
          } finally {
            if (!prefetched.isCompleted) prefetched.complete();
            if (!readerReady.isCompleted) readerReady.complete();
            if (!recoveryResponseRelease.isCompleted) {
              recoveryResponseRelease.complete();
            }
            await logs.cancel();
            if (watchRecovery) {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(milliseconds: 200));
              surfaceSession?.release();
              nextSurfaceSession?.release();
              await TwitchMediaKitPlayerHost.disposeNow();
            } else {
              await player.dispose();
            }
            await router?.close();
            await proxy.close();
            await upstream.close(force: true);
            await serving.cancel();
          }
        }
        return;
      }
      final damaged = <int>[
        ...bytes.take(offset),
        ...bytes.skip(offset).take(10),
        ...bytes.skip(offset),
      ];
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      final serving = server.listen((request) async {
        final body = request.uri.path == '/damaged' ? damaged : bytes;
        request.response.headers.contentType = io.ContentType(
          'video',
          request.uri.path == '/mp4' ? 'mp4' : 'mp2t',
        );
        request.response.add(body);
        await request.response.close();
      });
      try {
        final positions = <String, int>{};
        for (final variant in ['file', 'mp4', 'intact', 'damaged']) {
          final player = await Player.create(
            configuration: const PlayerConfiguration(
              options: {'aid': 'no', 'vid': 'auto', 'vo': 'null'},
            ),
          );
          final diagnostics = TwitchNativeLogDiagnostics();
          final failureTokens = <String, int>{};
          final logs = player.stream.log.listen((log) {
            diagnostics.record(log.text);
            final lower = log.text.toLowerCase();
            if (lower.contains('error') || lower.contains('failed')) {
              for (final token in [
                'video',
                'audio',
                'codec',
                'decoder',
                'device',
                'gpu',
                'd3d11',
                'wasapi',
                'packet',
                'sample',
                'header',
                'moof',
                'mdat',
                'offset',
                'seek',
                'invalid',
                'unsupported',
                'output',
              ]) {
                if (lower.contains(token)) {
                  failureTokens.update(
                    token,
                    (value) => value + 1,
                    ifAbsent: () => 1,
                  );
                }
              }
            }
          });
          Object? openError;
          try {
            await player
                .open(
                  Media(
                    variant == 'file'
                        ? 'C:/Users/Harley/Documents/Codex/vioclass/docs/twitch-decoder-fixture.mp4'
                        : 'http://127.0.0.1:${server.port}/$variant',
                  ),
                )
                .timeout(const Duration(seconds: 15));
          } catch (error) {
            openError = error;
          }
          await tester.pump(const Duration(seconds: 4));
          positions[variant] = player.state.position.inMilliseconds;
          debugPrint(
            '[ReadonlyTest] partial decoder variant=$variant positionMs=${player.state.position.inMilliseconds} playing=${player.state.playing} buffering=${player.state.buffering} errorType=${openError?.runtimeType ?? 'none'} categories=${diagnostics.snapshot} failureTokens=$failureTokens',
          );
          try {} finally {
            await logs.cancel();
            await player.dispose();
          }
        }
        expect(
          positions['intact'],
          greaterThan(500),
          reason:
              'Intact HTTP baseline must play before interpreting damaged media.',
        );
      } finally {
        await server.close(force: true);
        await serving.cancel();
      }
    });
    return;
  }

  testWidgets('real Windows session: home, browse, search and live read-only', (
    tester,
  ) async {
    var framePhase = 'home';
    final frameSamples = <String, List<int>>{};
    void recordFrames(List<FrameTiming> timings) {
      final samples = frameSamples.putIfAbsent(framePhase, () => <int>[]);
      final builds = frameSamples.putIfAbsent(
        '$framePhase-build',
        () => <int>[],
      );
      final rasters = frameSamples.putIfAbsent(
        '$framePhase-raster',
        () => <int>[],
      );
      for (final timing in timings) {
        if (samples.length >= 50000) break;
        final build = timing.buildDuration.inMicroseconds;
        final raster = timing.rasterDuration.inMicroseconds;
        samples.add(build > raster ? build : raster);
        builds.add(build);
        rasters.add(raster);
      }
    }

    binding.addTimingsCallback(recordFrames);
    addTearDown(() {
      binding.removeTimingsCallback(recordFrames);
      for (final entry in frameSamples.entries) {
        final samples = entry.value..sort();
        if (samples.isEmpty) continue;
        final p95 = samples[((samples.length - 1) * .95).round()];
        final slow = samples.where((value) => value > 33333).length;
        debugPrint(
          '[ReadonlyTest] frame phase=${entry.key} count=${samples.length} p95Us=$p95 over33ms=$slow',
        );
      }
    });
    await app.main([]);
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exception.toString();
      final flags = <String>[
        for (final keyword in [
          'ListTile',
          'overflow',
          'disposed',
          'setState',
          'assertion',
          'timed out',
        ])
          if (message.toLowerCase().contains(keyword.toLowerCase())) keyword,
      ];
      debugPrint(
        '[ReadonlyTest] framework exception type=${details.exception.runtimeType} flags=${flags.join(',')} phase=$framePhase',
      );
      final disposedType = RegExp(
        r'([A-Za-z_][A-Za-z0-9_]*) was used after being disposed',
      ).firstMatch(message);
      if (disposedType != null) {
        debugPrint(
          '[ReadonlyTest] disposed object type=${disposedType.group(1)} phase=$framePhase',
        );
      }
      final safeFrames = RegExp(r'([A-Za-z_][A-Za-z0-9_]*\.dart):(\d+):(\d+)')
          .allMatches(details.stack?.toString() ?? '')
          .take(16)
          .map(
            (match) => '${match.group(1)}:${match.group(2)}:${match.group(3)}',
          )
          .join(',');
      debugPrint('[ReadonlyTest] exception source locations=$safeFrames');
      final location = RegExp(
        r'twitch_readonly_app_test\.dart:(\d+):(\d+)',
      ).firstMatch(details.stack?.toString() ?? '');
      if (location != null) {
        debugPrint(
          '[ReadonlyTest] failure location line=${location.group(1)} column=${location.group(2)} phase=$framePhase',
        );
      }
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    await waitFor(
      tester,
      () => find.byType(TwitchStreamPage).evaluate().isNotEmpty,
      'home mounted',
    );
    final dynamic home = tester.state(find.byType(TwitchStreamPage));
    await waitFor(
      tester,
      () => home.loadingLoginState == false,
      'saved session resolved',
    );
    final TwitchDiscoveryService discovery = home.discoveryService;
    expect(
      discovery.viewerSession.status,
      TwitchViewerStatus.authenticated,
      reason:
          'This run requires the existing logged-in session; never log in or out.',
    );
    var toolbar = tester.widget<TwitchStreamHomeToolbar>(
      find.byType(TwitchStreamHomeToolbar),
    );
    if (discovery.cachedAuth?.canReadFollows == true) {
      expect(toolbar.selectedSection, TwitchHomeSection.following);
    }
    debugPrint('[ReadonlyTest] passed: authenticated initial home');
    const fullDvr = bool.fromEnvironment('TWITCH_READONLY_FULL_DVR');
    const followingEntry = bool.fromEnvironment(
      'TWITCH_READONLY_FOLLOWING_ENTRY',
    );
    String? expectedFollowingLogin;
    final sampledWindowLogins = <String>[];
    if (followingEntry) {
      expect(
        fullDvr,
        isFalse,
        reason:
            'Following entry must use the real home card route, not a direct DVR route.',
      );
      expect(toolbar.selectedSection, TwitchHomeSection.following);
      await waitFor(
        tester,
        () => find.byType(TwitchStreamCard).evaluate().isNotEmpty,
        'following home first stream card loaded',
      );
      const sampledCardIndex = int.fromEnvironment(
        'TWITCH_READONLY_WINDOW_CARD_INDEX',
        defaultValue: 0,
      );
      expect(sampledCardIndex, greaterThanOrEqualTo(0));
      expect(
        sampledCardIndex,
        lessThan(find.byType(TwitchStreamCard).evaluate().length),
      );
      var firstCard = find.byType(TwitchStreamCard).at(sampledCardIndex);
      const noArchiveSample = bool.fromEnvironment(
        'TWITCH_READONLY_NO_ARCHIVE_SAMPLE',
      );
      if (noArchiveSample) {
        Finder? candidate;
        final following = tester.state<TwitchFollowingPageState>(
          find.byType(TwitchFollowingPage),
        );
        final streams = following.loadedStreams.toList();
        debugPrint(
          '[ReadonlyTest] no-archive loaded candidates=${streams.length}',
        );
        for (var index = 0; index < streams.length; index++) {
          final stream = streams[index];
          final videos = await discovery
              .fetchChannelVideos(userId: stream.userId, first: 1)
              .timeout(const Duration(seconds: 10));
          final growing = videos.videos.any(
            (video) => video.isLikelyGrowingArchive,
          );
          debugPrint(
            '[ReadonlyTest] no-archive candidate index=$index growingArchive=$growing',
          );
          if (!growing) {
            candidate = find.byWidgetPredicate(
              (widget) =>
                  widget is TwitchStreamCard &&
                  widget.stream.channelLogin == stream.channelLogin,
            );
            break;
          }
        }
        expect(
          candidate,
          isNotNull,
          reason:
              'No non-growing-archive sample in loaded following streams; coverage unavailable.',
        );
        firstCard = candidate!;
        final followingScroll = find.descendant(
          of: find.byType(TwitchFollowingPage),
          matching: find.byType(Scrollable),
        );
        expect(followingScroll, findsOneWidget);
        await tester.scrollUntilVisible(
          firstCard,
          300,
          scrollable: followingScroll,
          maxScrolls: 20,
        );
        await tester.pump();
      }
      const windowChannels = int.fromEnvironment(
        'TWITCH_READONLY_WINDOW_CHANNELS',
        defaultValue: 1,
      );
      if (windowChannels > 1) {
        final following = tester.state<TwitchFollowingPageState>(
          find.byType(TwitchFollowingPage),
        );
        sampledWindowLogins.addAll(
          following.loadedStreams
              .map((stream) => stream.channelLogin)
              .toSet()
              .take(windowChannels),
        );
        expect(sampledWindowLogins.length, greaterThanOrEqualTo(5));
      }
      if (sampledCardIndex > 0) {
        expect(
          const bool.fromEnvironment('TWITCH_READONLY_REPLAY_WINDOW'),
          isTrue,
        );
        await tester.ensureVisible(firstCard);
        await tester.pump();
        debugPrint(
          '[ReadonlyTest] replay window sampledCardIndex=$sampledCardIndex',
        );
      }
      expect(firstCard.hitTestable(), findsOneWidget);
      expectedFollowingLogin = tester
          .widget<TwitchStreamCard>(firstCard)
          .stream
          .channelLogin;
      expect(expectedFollowingLogin.isNotEmpty, isTrue);
      await tester.tap(firstCard);
      debugPrint(
        '[ReadonlyTest] click delivered: following home first stream card',
      );
    } else {
      await tester.tap(
        find.widgetWithIcon(
          TwitchStreamHomeToolbarIconButton,
          Icons.explore_rounded,
        ),
      );
      debugPrint('[ReadonlyTest] click delivered: browse');
      await tester.pump(const Duration(seconds: 1));
      toolbar = tester.widget<TwitchStreamHomeToolbar>(
        find.byType(TwitchStreamHomeToolbar),
      );
      expect(toolbar.selectedSection, TwitchHomeSection.browse);
      // Flutter changes the widget's text; it does not move the system mouse.
      await tester.enterText(
        find.descendant(
          of: find.byType(TwitchStreamHomeToolbar),
          matching: find.byType(TextField),
        ),
        'papaplatte',
      );
      await waitFor(
        tester,
        () =>
            home.loadingChannelSearch == false &&
            (home.searchedLiveStreams.isNotEmpty ||
                home.searchedOfflineChannels.isNotEmpty),
        'public channel search results',
      );
      expect(home.channelSearchError == null, isTrue);
      const searchLayoutOnly = bool.fromEnvironment(
        'TWITCH_READONLY_SEARCH_LAYOUT_ONLY',
      );
      if (searchLayoutOnly) {
        await tester.pump(const Duration(milliseconds: 400));
        final searchPage = find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_TwitchChannelSearchPage',
        );
        expect(searchPage, findsOneWidget);
        expect(
          find.descendant(
            of: searchPage,
            matching: find.byType(TwitchDiscoveryScrollSurface),
          ),
          findsOneWidget,
        );
        final header = find
            .descendant(
              of: searchPage,
              matching: find.byType(TwitchDiscoverySectionHeader),
            )
            .first;
        final toolbarRect = tester.getRect(
          find.byType(TwitchStreamHomeToolbar),
        );
        final headerRect = tester.getRect(header);
        expect(headerRect.top, greaterThan(toolbarRect.bottom));
        debugPrint(
          '[ReadonlyTest] passed: real search uses shared surface and clears floating toolbar gap=${(headerRect.top - toolbarRect.bottom).toStringAsFixed(1)}',
        );
        return;
      }
      final TwitchFollowedChannel mediaChannel;
      final exactLive = home.searchedLiveStreams
          .where(
            (TwitchLiveStream stream) => stream.channelLogin == 'papaplatte',
          )
          .toList();
      final exactOffline = home.searchedOfflineChannels
          .where(
            (TwitchFollowedChannel channel) =>
                channel.channelLogin == 'papaplatte',
          )
          .toList();
      if (exactLive.isNotEmpty) {
        final TwitchLiveStream stream = exactLive.first;
        mediaChannel = TwitchFollowedChannel(
          broadcasterId: stream.userId,
          broadcasterLogin: stream.channelLogin,
          broadcasterName: stream.displayName,
          followedAt: null,
          profileImageUrl: stream.profileImageUrl,
        );
      } else {
        expect(
          exactOffline,
          isNotEmpty,
          reason:
              'The exact searched sample channel is required, not a similarly named channel.',
        );
        mediaChannel = exactOffline.first;
      }
      toolbar = tester.widget<TwitchStreamHomeToolbar>(
        find.byType(TwitchStreamHomeToolbar),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(TwitchStreamHomeToolbar),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      debugPrint('[ReadonlyTest] click delivered: clear search');
      const mediaLibrary = bool.fromEnvironment(
        'TWITCH_READONLY_MEDIA_LIBRARY',
      );
      const mediaMini = bool.fromEnvironment('TWITCH_READONLY_MEDIA_MINI');
      if (mediaMini) {
        expect(home.playerSettingsController.homeKeepsMiniPlayer, isTrue);
        await exerciseMediaMiniRoutes(
          tester,
          discovery,
          mediaChannel,
          (phase) => framePhase = phase,
        );
        return;
      }
      if (mediaLibrary) {
        await exerciseMediaLibrary(
          tester,
          discovery,
          mediaChannel,
          (phase) => framePhase = phase,
        );
        return;
      }
      await tester.pump(const Duration(seconds: 1));
      if (!fullDvr) {
        await waitFor(
          tester,
          () =>
              find.byType(TwitchStreamCard).hitTestable().evaluate().isNotEmpty,
          'visible browse stream card',
        );
        await tester.tap(find.byType(TwitchStreamCard).hitTestable().first);
        debugPrint('[ReadonlyTest] click delivered: visible live card');
      } else {
        final livePage = await discovery.fetchBrowseStreams(first: 5);
        expect(livePage.streams.isNotEmpty, isTrue);
        var live = livePage.streams.first;
        TwitchChannelVideo? activeArchive;
        const archiveSampleIndex = int.fromEnvironment(
          'TWITCH_READONLY_DVR_CHANNEL_INDEX',
          defaultValue: 0,
        );
        expect(archiveSampleIndex, greaterThanOrEqualTo(0));
        var eligibleArchiveIndex = 0;
        for (final candidate in livePage.streams) {
          final videos = await discovery.fetchChannelVideos(
            userId: candidate.userId,
            first: 1,
          );
          if (videos.videos.isNotEmpty &&
              videos.videos.first.isLikelyGrowingArchive) {
            if (eligibleArchiveIndex == archiveSampleIndex) {
              live = candidate;
              activeArchive = videos.videos.first;
              break;
            }
            eligibleArchiveIndex++;
          }
        }
        expect(
          activeArchive != null,
          isTrue,
          reason:
              'Requested growing archive sample unavailable; full DVR coverage is unavailable, not passed.',
        );
        debugPrint(
          '[ReadonlyTest] DVR selected channel=${live.channelLogin} '
          'eligibleIndex=$archiveSampleIndex',
        );
        final context = tester.element(find.byType(TwitchStreamPage));
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => TwitchWatchPage(
                initialChannelLogin: live.channelLogin,
                initialStreamTitle: live.title,
                initialDiscoveryService: discovery,
                initialActiveDvrVideo: activeArchive,
              ),
            ),
          ),
        );
      }
    }
    await waitFor(
      tester,
      () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
      'live route mounted',
    );
    final watch = tester.state<TwitchWatchPageState>(
      find.byType(TwitchWatchPage),
    );
    if (followingEntry) {
      expect(watch.channelLogin, expectedFollowingLogin);
      debugPrint(
        '[ReadonlyTest] passed: following first card opens matching live route',
      );
    }
    framePhase = 'live';
    const windowProbe = bool.fromEnvironment('TWITCH_READONLY_REPLAY_WINDOW');
    if (windowProbe) {
      await waitFor(
        tester,
        () =>
            watch.watchPorts.player.runtime.upstreamPlaylistUri != null &&
            watch.watchPorts.player.runtime.variants.isNotEmpty,
        'replay window source ready',
      );
      final runtime = watch.watchPorts.player.runtime;
      if (sampledWindowLogins.isNotEmpty) {
        const rounds = int.fromEnvironment(
          'TWITCH_READONLY_WINDOW_ROUNDS',
          defaultValue: 1,
        );
        const compareApp = bool.fromEnvironment(
          'TWITCH_READONLY_WINDOW_COMPARE_APP',
        );
        const recordNames = bool.fromEnvironment(
          'TWITCH_READONLY_WINDOW_RECORD_NAMES',
        );
        for (var round = 0; round < rounds; round++) {
          for (var sample = 0; sample < sampledWindowLogins.length; sample++) {
            final login = sampledWindowLogins[sample];
            final identity = recordNames ? login : 'sample-$sample';
            var sampledApi = runtime.playbackApi;
            if (compareApp) {
              if (!(round == 0 && sample == 0 && watch.channelLogin == login)) {
                if (find.byType(TwitchWatchPage).evaluate().isNotEmpty) {
                  Navigator.of(
                    tester.element(find.byType(TwitchWatchPage)),
                  ).pop();
                  await waitFor(
                    tester,
                    () => find.byType(TwitchWatchPage).evaluate().isEmpty,
                    'window previous route closed',
                  );
                }
                unawaited(
                  Navigator.of(
                    tester.element(find.byType(TwitchStreamPage)),
                  ).push<void>(
                    MaterialPageRoute(
                      builder: (_) => TwitchWatchPage(
                        initialChannelLogin: login,
                        initialDiscoveryService: discovery,
                      ),
                    ),
                  ),
                );
                await waitFor(
                  tester,
                  () => find.byType(TwitchWatchPage).evaluate().isNotEmpty,
                  'window sampled route mounted',
                );
              }
              final active = tester.state<TwitchWatchPageState>(
                find.byType(TwitchWatchPage),
              );
              await waitFor(
                tester,
                () =>
                    active.channelLogin == login &&
                    active.watchPorts.player.runtime.upstreamPlaylistUri !=
                        null &&
                    active.watchPorts.player.runtime.currentVariant != null,
                'window actual app source ready',
              );
              final selected = active.watchPorts.player.runtime;
              sampledApi = selected.playbackApi;
              final current = selected.currentVariant!;
              final candidates = <Uri>{
                selected.upstreamPlaylistUri!,
                ...selected.variants
                    .where(
                      (variant) =>
                          !variant.isAudioOnly &&
                          variant.sourceTag == current.sourceTag,
                    )
                    .map((variant) => Uri.parse(variant.url)),
              }.take(3).toList();
              for (var quality = 0; quality < candidates.length; quality++) {
                final result = await tester.runAsync(
                  () => probeReplayWindow(candidates[quality]),
                );
                debugPrint(
                  '[ReadonlyTest] replay window record=${jsonEncode({'channel': identity, 'round': round + 1, 'timeUtc': DateTime.now().toUtc().toIso8601String(), 'context': 'app-selected', 'sourceTag': current.sourceTag, 'qualitySample': quality, 'result': result})}',
                );
              }
            }
            final results = await tester.runAsync(
              () => probeChannelReplayWindows(sampledApi, login),
            );
            debugPrint(
              '[ReadonlyTest] replay window record=${jsonEncode({'channel': identity, 'round': round + 1, 'timeUtc': DateTime.now().toUtc().toIso8601String(), 'context': 'web-site', 'results': results})}',
            );
          }
        }
        return;
      }
      final candidates = <Uri>{
        runtime.upstreamPlaylistUri!,
        ...runtime.variants
            .where((variant) => !variant.isAudioOnly)
            .map((variant) => Uri.parse(variant.url)),
      }.take(3).toList();
      final clock = Stopwatch()..start();
      const entryOnly = bool.fromEnvironment(
        'TWITCH_READONLY_WINDOW_ENTRY_ONLY',
      );
      for (final phase in entryOnly ? [0] : [0, 30, 60]) {
        while (clock.elapsed < Duration(seconds: phase)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        for (var sample = 0; sample < candidates.length; sample++) {
          final result = await tester.runAsync(
            () => probeReplayWindow(candidates[sample]),
          );
          debugPrint(
            '[ReadonlyTest] replay window phase=$phase qualitySample=$sample observedMs=${clock.elapsedMilliseconds} result=${jsonEncode(result)}',
          );
        }
      }
      return;
    }
    final sources = <String, Listenable>{
      'preferences': watch.preferencesController,
      'chat': watch.chatController,
      'engagement': watch.engagementController,
      'relationship': watch.relationshipController,
      'playback': watch.playbackController,
      'timeline': watch.playbackTimelineController,
      'vod-chat': watch.vodReplayController,
    };
    final sourceCounts = <String, int>{};
    final callbacks = <String, VoidCallback>{};
    for (final entry in sources.entries) {
      callbacks[entry.key] = () => sourceCounts.update(
        entry.key,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      entry.value.addListener(callbacks[entry.key]!);
    }
    addTearDown(() {
      for (final entry in sources.entries) {
        entry.value.removeListener(callbacks[entry.key]!);
        debugPrint(
          '[ReadonlyTest] controller source=${entry.key} notifications=${sourceCounts[entry.key] ?? 0}',
        );
      }
    });
    expect(identical(watch.authService, discovery.authService), isTrue);
    await waitFor(
      tester,
      () => watch.chatRuntime?.connected == true,
      'live read-only chat connected',
      timeout: const Duration(seconds: 70),
    );
    expect(watch.chatController.isReadOnlyGuest, isFalse);
    final activeChatRuntime = watch.chatRuntime!;
    sources['chat-runtime'] = activeChatRuntime;
    callbacks['chat-runtime'] = () => sourceCounts.update(
      'chat-runtime',
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    activeChatRuntime.addListener(callbacks['chat-runtime']!);
    await waitFor(
      tester,
      () => watch.playerSession.playerOrNull?.state.playing == true,
      'real live player playing',
      timeout: const Duration(seconds: 70),
    );
    final before = watch.playerSession.player.state.position;
    try {
      await waitFor(
        tester,
        () => watch.playerSession.player.state.position > before,
        'live decoding position advances before observation',
        timeout: const Duration(seconds: 60),
      );
    } catch (_) {
      final runtime = watch.watchPorts.player.runtime;
      final state = watch.playerSession.player.state;
      final properties = <String, String>{};
      for (final name in [
        'paused-for-cache',
        'demuxer-cache-duration',
        'cache-buffering-state',
        'eof-reached',
        'idle-active',
        'video-params/w',
        'audio-params/samplerate',
      ]) {
        try {
          final value = watch.playerSession.player.getProperty(name);
          if (RegExp(r'^(?:yes|no|-?\d+(?:\.\d+)?)$').hasMatch(value)) {
            properties[name] = value;
          }
        } catch (_) {}
      }
      debugPrint(
        '[ReadonlyTest] initial live failure playing=${state.playing} buffering=${state.buffering} positionMs=${state.position.inMilliseconds} proxyRunning=${runtime.proxy?.isRunning} innerRunning=${runtime.proxy?.hasInnerProxy} properties=$properties',
      );
      final diagnosticClient = Dio();
      try {
        final status = await runtime
            .refreshProxyLiveStatus(notify: false)
            .timeout(const Duration(seconds: 5));
        debugPrint(
          '[ReadonlyTest] initial live proxy writer=${status?.hasWriter} clients=${status?.activeClientCount} writtenSequence=${status?.lastWrittenSequence} outputMs=${status?.outputDuration.inMilliseconds} runtimeError=${runtime.error != null}',
        );
        final upstream = runtime.upstreamPlaylistUri;
        if (upstream != null) {
          final response = await diagnosticClient
              .getUri<String>(
                upstream,
                options: Options(
                  responseType: ResponseType.plain,
                  headers: TwitchPlaylistPlayerRuntime.defaultUpstreamHeaders,
                  receiveTimeout: const Duration(seconds: 4),
                  sendTimeout: const Duration(seconds: 4),
                  validateStatus: (_) => true,
                ),
              )
              .timeout(const Duration(seconds: 5));
          final body = (response.data ?? '').toLowerCase();
          final markers = <String, bool>{
            for (final marker in [
              'stitched-ad',
              '#ext-x-daterange',
              '#ext-x-discontinuity',
              'scte35',
            ])
              marker: body.contains(marker),
          };
          debugPrint(
            '[ReadonlyTest] initial live playlist status=${response.statusCode} hls=${body.contains('#extm3u')} variantMayHaveAds=${runtime.currentVariant?.hasAds} markers=$markers',
          );
        }
      } catch (error) {
        debugPrint(
          '[ReadonlyTest] initial live diagnostic errorType=${error.runtimeType}',
        );
      } finally {
        diagnosticClient.close(force: true);
      }
      rethrow;
    }
    final liveObservationBefore = watch.playerSession.player.state.position;
    await tester.pump(const Duration(seconds: 15));
    expect(
      watch.playerSession.player.state.position,
      greaterThan(liveObservationBefore),
    );
    debugPrint('[ReadonlyTest] passed: live position advances for 15 seconds');
    const limitedReplay = bool.fromEnvironment(
      'TWITCH_READONLY_LIMITED_REPLAY',
    );
    if (limitedReplay) {
      expect(followingEntry, isTrue);
      const noArchiveSample = bool.fromEnvironment(
        'TWITCH_READONLY_NO_ARCHIVE_SAMPLE',
      );
      if (noArchiveSample) {
        expect(
          watch.hasUsableLiveDvrArchive,
          isFalse,
          reason: 'The selected sample must really lack a usable live archive.',
        );
      }
      debugPrint(
        '[ReadonlyTest] limited replay hasArchive=${watch.hasUsableLiveDvrArchive}',
      );
      final duration = watch.currentLiveTimelineDuration();
      expect(duration, isNotNull);
      expect(duration, greaterThan(const Duration(seconds: 10)));
      await watch.openActiveDvrReplayAt(
        duration! - const Duration(seconds: 10),
      );
      await waitFor(
        tester,
        () => watch.watchPorts.player.runtime.usingLiveBufferReplay,
        'limited replay route active',
      );
      await waitFor(
        tester,
        () =>
            !watch.playerSession.player.state.buffering &&
            watch.playerSession.player.state.position > Duration.zero,
        'limited replay starts decoding',
        timeout: const Duration(seconds: 60),
      );
      framePhase = 'limited-replay';
      final initial = watch.playerSession.player.state.position;
      final controls = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'WatchBottomControlBar',
      );
      final overlay = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'WatchControlsOverlay',
      );
      var maxHeightDelta = 0.0;
      var maxTopDelta = 0.0;
      const observationSeconds = int.fromEnvironment(
        'TWITCH_READONLY_LIMITED_REPLAY_SECONDS',
        defaultValue: 60,
      );
      expect(observationSeconds, greaterThanOrEqualTo(10));
      var previousReplayPosition = initial;
      var consecutiveReplayStalls = 0;
      var longestReplayStall = 0;
      int? initialLagMs;
      var maxLagDriftMs = 0;
      Rect? baseline;
      for (var second = 1; second <= observationSeconds; second++) {
        if (second % 2 == 1 && overlay.evaluate().isNotEmpty) {
          await tester.tapAt(tester.getRect(overlay.first).center);
        }
        await tester.pump(const Duration(seconds: 1));
        final replayState = watch.playerSession.player.state;
        if ((replayState.position - previousReplayPosition).inMilliseconds <
            100) {
          consecutiveReplayStalls++;
          if (consecutiveReplayStalls > longestReplayStall) {
            longestReplayStall = consecutiveReplayStalls;
          }
        } else {
          consecutiveReplayStalls = 0;
        }
        previousReplayPosition = replayState.position;
        if (controls.evaluate().isNotEmpty) {
          final rect = tester.getRect(controls.first);
          baseline ??= rect;
          final h = (rect.height - baseline.height).abs();
          final y = (rect.top - baseline.top).abs();
          if (h > maxHeightDelta) maxHeightDelta = h;
          if (y > maxTopDelta) maxTopDelta = y;
        }
        if (second % 10 == 0) {
          final rawEdge = watch.currentLiveTimelineDuration() ?? Duration.zero;
          final clock = watch.playbackTimelineController;
          final edge = clock.displayDurationFor(rawEdge);
          final canonical = clock.positionFor(edge);
          final lagMs = (edge - canonical).inMilliseconds;
          initialLagMs ??= lagMs;
          final driftMs = (lagMs - initialLagMs).abs();
          if (driftMs > maxLagDriftMs) maxLagDriftMs = driftMs;
          final timelineSlider = find.descendant(
            of: controls,
            matching: find.byWidgetPredicate(
              (widget) => widget is Slider && widget.max == 1,
            ),
          );
          final value = timelineSlider.evaluate().isEmpty
              ? -1.0
              : tester.widget<Slider>(timelineSlider.first).value;
          if (noArchiveSample) {
            final strips = find.descendant(
              of: controls,
              matching: find.byType(TwitchVodPlaybackStrip),
            );
            expect(strips, findsOneWidget);
            expect(
              tester
                  .widget<TwitchVodPlaybackStrip>(strips)
                  .liveSeekWindowDuration,
              const Duration(seconds: 20),
            );
            expect(
              value,
              closeTo((1 - lagMs / 20000).clamp(0.0, 1.0), .05),
              reason:
                  'No-archive slider must map the 20-second window, not total uptime.',
            );
          }
          debugPrint(
            '[ReadonlyTest] limited clock second=$second rawEdgeMs=${rawEdge.inMilliseconds} edgeMs=${edge.inMilliseconds} positionMs=${canonical.inMilliseconds} lagMs=${(edge - canonical).inMilliseconds} slider=$value',
          );
          debugPrint(
            '[ReadonlyTest] limited replay second=$second progressMs=${(watch.playerSession.player.state.position - initial).inMilliseconds} playing=${watch.playerSession.player.state.playing} buffering=${watch.playerSession.player.state.buffering} maxHeightDelta=$maxHeightDelta maxTopDelta=$maxTopDelta',
          );
        }
      }
      expect(
        watch.playerSession.player.state.position - initial,
        greaterThan(Duration(milliseconds: observationSeconds * 750)),
        reason: 'Replay progress must scale with the configured observation.',
      );
      expect(
        baseline,
        isNotNull,
        reason: 'Controls geometry must actually be sampled.',
      );
      expect(
        initialLagMs,
        isNotNull,
        reason: 'Replay lag must actually be sampled.',
      );
      expect(longestReplayStall, lessThanOrEqualTo(3));
      expect(watch.playerSession.player.state.buffering, isFalse);
      debugPrint(
        '[ReadonlyTest] limited replay longestStallSeconds=$longestReplayStall maxLagDriftMs=$maxLagDriftMs',
      );
      expect(maxHeightDelta, lessThan(0.5));
      expect(maxTopDelta, lessThan(0.5));
      expect(
        maxLagDriftMs,
        lessThan(2000),
        reason:
            'Continuous near-live playback must not reset to its old target.',
      );
      await watch.returnToLivePlayback();
      await waitFor(
        tester,
        () =>
            !watch.watchPorts.player.runtime.usingLiveBufferReplay &&
            watch.playerSession.player.state.playing,
        'limited replay returns live',
      );
      final returnedBefore = watch.playerSession.player.state.position;
      await waitFor(
        tester,
        () =>
            !watch.playerSession.player.state.buffering &&
            watch.playerSession.player.state.position > returnedBefore,
        'limited replay returned live decodes',
        timeout: const Duration(seconds: 60),
      );
      final returnedDecoded = watch.playerSession.player.state.position;
      await tester.pump(const Duration(seconds: 10));
      expect(
        watch.playerSession.player.state.position - returnedDecoded,
        greaterThan(const Duration(seconds: 7)),
      );
      expect(watch.playerSession.player.state.buffering, isFalse);
      debugPrint(
        '[ReadonlyTest] passed: limited replay returned live sustains 10 seconds',
      );
      return;
    }
    const livePerformance = bool.fromEnvironment(
      'TWITCH_READONLY_LIVE_PERFORMANCE',
    );
    if (livePerformance) {
      framePhase = 'live-observation';
      final observationClock = Stopwatch()..start();
      final observationPosition = watch.playerSession.player.state.position;
      var previousPosition = observationPosition;
      var maxPumpMs = 0;
      var stalledSamples = 0;
      var consecutiveStalls = 0;
      var longestStall = 0;
      var bufferingSamples = 0;
      final previousCounts = Map<String, int>.of(sourceCounts);
      for (var second = 1; second <= 60; second++) {
        final pumpClock = Stopwatch()..start();
        await tester.pump(const Duration(seconds: 1));
        pumpClock.stop();
        if (pumpClock.elapsedMilliseconds > maxPumpMs) {
          maxPumpMs = pumpClock.elapsedMilliseconds;
        }
        final state = watch.playerSession.player.state;
        final advanceMs = (state.position - previousPosition).inMilliseconds;
        if (advanceMs < 100) {
          stalledSamples++;
          consecutiveStalls++;
          if (consecutiveStalls > longestStall) {
            longestStall = consecutiveStalls;
          }
        } else {
          consecutiveStalls = 0;
        }
        if (state.buffering) bufferingSamples++;
        previousPosition = state.position;
        if (second % 10 == 0) {
          const performanceInteractions = bool.fromEnvironment(
            'TWITCH_READONLY_PERFORMANCE_INTERACTIONS',
          );
          if (performanceInteractions) {
            await tester.tap(find.byType(WatchControlsOverlay));
            await tester.pump(const Duration(milliseconds: 250));
            expect(find.byType(WatchControlsOverlay), findsOneWidget);
            debugPrint(
              '[ReadonlyTest] passed: live observation overlay click second=$second',
            );
          }
          final builds = frameSamples['live-observation-build'] ?? <int>[];
          final rasters = frameSamples['live-observation-raster'] ?? <int>[];
          int maximum(List<int> samples) => samples.fold<int>(
            0,
            (largest, sample) => sample > largest ? sample : largest,
          );
          debugPrint(
            '[ReadonlyTest] live observation second=$second elapsedMs=${observationClock.elapsedMilliseconds} progressMs=${(state.position - observationPosition).inMilliseconds} maxPumpMs=$maxPumpMs stalledSamples=$stalledSamples longestStall=$longestStall bufferingSamples=$bufferingSamples playing=${state.playing} lifecycle=${binding.lifecycleState?.name ?? 'unknown'} frames=${builds.length} maxBuildUs=${maximum(builds)} maxRasterUs=${maximum(rasters)}',
          );
          for (final source in sources.keys) {
            final count = sourceCounts[source] ?? 0;
            debugPrint(
              '[ReadonlyTest] live observation source=$source tenSecondNotifications=${count - (previousCounts[source] ?? 0)}',
            );
            previousCounts[source] = count;
          }
        }
      }
      observationClock.stop();
      expect(
        watch.playerSession.player.state.position - observationPosition,
        greaterThan(const Duration(seconds: 45)),
        reason: 'Live playback must advance through the full 60 second sample.',
      );
      expect(watch.playerSession.player.state.buffering, isFalse);
      debugPrint(
        '[ReadonlyTest] passed: live 60 second performance observation',
      );
    }
    const liveRoutes = bool.fromEnvironment('TWITCH_READONLY_LIVE_ROUTES');
    if (liveRoutes) {
      await exerciseLiveRoutes(
        tester,
        watch,
        discovery,
        home.playerSettingsController.homeKeepsMiniPlayer as bool,
        (phase) => framePhase = phase,
      );
      return;
    }
    if (!fullDvr) return;
    await waitFor(
      tester,
      () => watch.hasUsableLiveDvrArchive,
      'full DVR archive warmed',
      timeout: const Duration(seconds: 90),
    );
    final duration = watch.currentLiveTimelineDuration();
    expect(duration != null && duration.inMinutes > 2, isTrue);
    final nativeLogs = watch.playerSession.player.stream.log.listen((log) {
      final flags = <String>[
        for (final word in [
          'seek',
          'demux',
          'cache',
          'error',
          'failed',
          'http',
          'timestamp',
          'codec',
          'audio',
          'video',
          'decoder',
          'filter',
          'option',
          'property',
          'format',
          'unrecognized',
          'connection',
          'invalid',
          'stream',
          'render',
          'load',
          'open',
          'device',
          'shader',
          'network',
          'header',
          'protocol',
          'input',
          'output',
          'moov',
          'mpeg',
          'eof',
        ])
          if (log.text.toLowerCase().contains(word)) word,
      ];
      if (flags.isNotEmpty) {
        final source =
            const ['cplayer', 'ffmpeg', 'demux', 'vo', 'ao', 'stream', 'lavf']
                .where(
                  (word) =>
                      log.prefix == word || log.prefix.startsWith('$word/'),
                )
                .join(',');
        debugPrint(
          '[ReadonlyTest] native log source=${source.isEmpty ? 'other' : source} flags=${flags.join(',')}',
        );
      }
    });
    final nativeProgress = Timer.periodic(const Duration(seconds: 10), (_) {
      final player = watch.playerSession.player;
      final values = <String>[];
      for (final name in [
        'paused-for-cache',
        'seeking',
        'demuxer-cache-duration',
        'cache-buffering-state',
        'eof-reached',
        'idle-active',
      ]) {
        try {
          final value = player.getProperty(name);
          if (RegExp(r'^(?:yes|no|-?\d+(?:\.\d+)?)$').hasMatch(value)) {
            values.add('$name=$value');
          }
        } catch (_) {
          values.add('$name=unavailable');
        }
      }
      debugPrint(
        '[ReadonlyTest] native progress lifecycle=${WidgetsBinding.instance.lifecycleState?.name ?? 'unknown'} ${values.join(' ')}',
      );
    });
    addTearDown(() async {
      nativeProgress.cancel();
      await nativeLogs.cancel();
    });
    framePhase = 'dvr';
    await watch.openActiveDvrReplayAt(
      Duration(milliseconds: duration!.inMilliseconds ~/ 2),
    );
    const diagnoseWithoutInitialSeek = bool.fromEnvironment(
      'TWITCH_DVR_DIAGNOSE_WITHOUT_INITIAL_SEEK',
    );
    if (diagnoseWithoutInitialSeek) {
      debugPrint(
        '[ReadonlyTest] diagnostic only: reopen DVR without initial seek',
      );
      await watch.playbackController.openMedia(
        uri: TwitchMediaKitPlayerHost.currentMediaUri!,
        play: true,
        forceOpen: true,
      );
    }
    await waitFor(
      tester,
      () =>
          watch.watchPorts.player.runtime.usingLiveTimelineReplay &&
          watch.playerSession.player.state.playing,
      'DVR seek entered replay',
      timeout: const Duration(seconds: 60),
    );
    await waitFor(
      tester,
      () =>
          !watch.playerSession.player.state.buffering &&
          watch.playerSession.player.state.position > Duration.zero,
      'DVR decoded playback starts before pause',
      timeout: const Duration(seconds: 60),
    );
    await watch.playerSession.player.pause();
    await tester.pump(const Duration(seconds: 10));
    final replayBefore = watch.playerSession.player.state.position;
    await watch.playerSession.player.play();
    for (var second = 1; second <= 45; second++) {
      await tester.pump(const Duration(seconds: 1));
      if (second % 15 == 0) {
        final state = watch.playerSession.player.state;
        debugPrint(
          '[ReadonlyTest] replay second=$second '
          'progressMs=${(state.position - replayBefore).inMilliseconds} '
          'playing=${state.playing} buffering=${state.buffering}',
        );
      }
    }
    debugPrint(
      '[ReadonlyTest] DVR progress ms: ${(watch.playerSession.player.state.position - replayBefore).inMilliseconds}',
    );
    expect(
      watch.playerSession.player.state.position - replayBefore,
      greaterThan(const Duration(seconds: 25)),
      reason:
          'DVR must continue across multiple segments after pause, not merely load one frame.',
    );
    debugPrint(
      '[ReadonlyTest] passed: DVR resumes and advances across 45 seconds',
    );
    const dragDvr = bool.fromEnvironment('TWITCH_READONLY_DVR_DRAG');
    if (dragDvr) {
      framePhase = 'dvr-drag';
      const repeatDrag = bool.fromEnvironment(
        'TWITCH_READONLY_DVR_DRAG_REPEAT',
      );
      final dragOffsets = repeatDrag ? [-.2, .2, -.3] : [-.2];
      for (var attempt = 0; attempt < dragOffsets.length; attempt++) {
        debugPrint('[ReadonlyTest] DVR drag attempt=${attempt + 1}');
        final overlay = find.byType(WatchControlsOverlay);
        await tester.tap(overlay);
        await tester.pump(const Duration(milliseconds: 250));
        final strip = find.descendant(
          of: overlay,
          matching: find.byType(TwitchVodPlaybackStrip),
        );
        expect(strip, findsOneWidget);
        expect(
          tester.widget<TwitchVodPlaybackStrip>(strip).liveSeekWindowDuration,
          isNull,
        );
        final slider = find
            .descendant(
              of: strip,
              matching: find.byWidgetPredicate(
                (widget) => widget is Slider && widget.max == 1,
              ),
            )
            .hitTestable();
        expect(slider, findsOneWidget);
        expect(tester.widget<Slider>(slider).onChangeEnd, isNotNull);
        final source = TwitchMediaKitPlayerHost.currentMediaUri;
        final rect = tester.getRect(slider);
        final gesture = await tester.startGesture(rect.center);
        Duration target;
        try {
          await gesture.moveBy(Offset(rect.width * dragOffsets[attempt], 0));
          await tester.pump(const Duration(milliseconds: 200));
          final ratio = tester.widget<Slider>(slider).value;
          expect(ratio, closeTo(.5 + dragOffsets[attempt], .05));
          target = watch.playbackTimelineController.snapshot.position;
          debugPrint(
            '[ReadonlyTest] DVR drag preview ratio=$ratio targetMs=${target.inMilliseconds}',
          );
        } finally {
          await gesture.up();
        }
        await waitFor(
          tester,
          () {
            final resolved =
                watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
            return TwitchMediaKitPlayerHost.currentMediaUri != source &&
                resolved != null &&
                (resolved - target).inMilliseconds.abs() < 2000 &&
                !watch.liveTimelineActionInFlight;
          },
          'DVR actual drag resolves a new stream near preview',
          timeout: const Duration(seconds: 90),
        );
        await waitFor(
          tester,
          () =>
              watch.playerSession.player.state.playing &&
              !watch.playerSession.player.state.buffering &&
              watch.playerSession.player.state.position > Duration.zero,
          'DVR actual drag decodes',
          timeout: const Duration(seconds: 60),
        );
        // URI publication and playing=true can precede the native clock reset.
        // Require progress on the settled clock before capturing its baseline;
        // the following ten-second gate still rejects stalls and later resets.
        final resolvedDragMedia = TwitchMediaKitPlayerHost.currentMediaUri;
        Duration? stableDragPosition;
        Duration? previousDragPosition;
        DateTime? stableDragSince;
        var dragClockResets = 0;
        await waitFor(
          tester,
          () {
            final state = watch.playerSession.player.state;
            if (!state.playing ||
                state.buffering ||
                TwitchMediaKitPlayerHost.currentMediaUri != resolvedDragMedia) {
              stableDragPosition = null;
              previousDragPosition = null;
              stableDragSince = null;
              return false;
            }
            final previous = previousDragPosition;
            if (previous != null &&
                state.position + const Duration(milliseconds: 250) < previous) {
              dragClockResets++;
              stableDragPosition = null;
              stableDragSince = null;
            }
            previousDragPosition = state.position;
            stableDragPosition ??= state.position;
            stableDragSince ??= DateTime.now();
            return DateTime.now().difference(stableDragSince!) >=
                    const Duration(seconds: 2) &&
                state.position - stableDragPosition! >=
                    const Duration(milliseconds: 1500);
          },
          'DVR actual drag new media clock advances before observation',
          timeout: const Duration(seconds: 60),
        );
        debugPrint(
          '[ReadonlyTest] DVR drag startup clock resets=$dragClockResets',
        );
        final before = watch.playerSession.player.state.position;
        final displayBefore =
            watch.playbackTimelineController.snapshot.position;
        final dragMediaBefore = TwitchMediaKitPlayerHost.currentMediaUri;
        final dragCanonicalBefore =
            watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
        debugPrint(
          '[ReadonlyTest] DVR drag observation start '
          'nativeMs=${before.inMilliseconds} '
          'seekTargetMs=${dragCanonicalBefore?.inMilliseconds} '
          'displayMs=${displayBefore.inMilliseconds} '
          'playing=${watch.playerSession.player.state.playing} '
          'buffering=${watch.playerSession.player.state.buffering}',
        );
        for (var second = 1; second <= 10; second++) {
          await tester.pump(const Duration(seconds: 1));
          final dragState = watch.playerSession.player.state;
          debugPrint(
            '[ReadonlyTest] DVR drag sample second=$second '
            'nativeMs=${dragState.position.inMilliseconds} '
            'deltaMs=${(dragState.position - before).inMilliseconds} '
            'displayMs=${watch.playbackTimelineController.snapshot.position.inMilliseconds} '
            'playing=${dragState.playing} buffering=${dragState.buffering} '
            'mediaChanged=${TwitchMediaKitPlayerHost.currentMediaUri != dragMediaBefore}',
          );
        }
        expect(
          watch.playerSession.player.state.position - before,
          greaterThan(const Duration(seconds: 7)),
        );
        expect(watch.playerSession.player.state.buffering, isFalse);
        expect(
          watch.playbackTimelineController.snapshot.position - displayBefore,
          greaterThan(const Duration(seconds: 7)),
        );
        expect(TwitchMediaKitPlayerHost.currentMediaUri, dragMediaBefore);
        final nativeAdvance =
            watch.playerSession.player.state.position - before;
        final displayAdvance =
            watch.playbackTimelineController.snapshot.position - displayBefore;
        expect(
          (displayAdvance - nativeAdvance).inMilliseconds.abs(),
          lessThan(2000),
          reason:
              'The displayed timeline must track decoded media progression.',
        );
        debugPrint(
          '[ReadonlyTest] passed: DVR actual drag sustains playback for 10 seconds',
        );
      }
    }
    const dvrControls = bool.fromEnvironment('TWITCH_READONLY_DVR_CONTROLS');
    const pausedDvrSeek = bool.fromEnvironment(
      'TWITCH_READONLY_PAUSED_DVR_SEEK',
    );
    if (pausedDvrSeek) {
      debugPrint(
        '[ReadonlyTest] paused DVR before pause snapshotMs=${watch.playbackTimelineController.snapshot.position.inMilliseconds} resolvedMs=${watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition?.inMilliseconds} durationMs=${watch.playbackTimelineController.snapshot.duration?.inMilliseconds}',
      );
      final overlay = find.byType(WatchControlsOverlay);
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find.descendant(of: overlay, matching: find.byIcon(Icons.pause)).first,
      );
      await waitFor(
        tester,
        () => !watch.playerSession.player.state.playing,
        'DVR UI pause stops playback before seek',
      );
      final snapshot = watch.playbackTimelineController.snapshot;
      expect(snapshot.canSeek, isTrue);
      final target = snapshot.position - const Duration(seconds: 10);
      debugPrint(
        '[ReadonlyTest] paused DVR targetMs=${target.inMilliseconds} resolvedMs=${watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition?.inMilliseconds}',
      );
      final source = TwitchMediaKitPlayerHost.currentMediaUri;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await waitFor(
        tester,
        () {
          final resolved =
              watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
          return TwitchMediaKitPlayerHost.currentMediaUri != source &&
              resolved != null &&
              (resolved - target).inMilliseconds.abs() < 2000 &&
              !watch.liveTimelineActionInFlight;
        },
        'paused DVR shortcut resolves a new stream near target',
        timeout: const Duration(seconds: 90),
      );
      debugPrint(
        '[ReadonlyTest] paused DVR seek playing=${watch.playerSession.player.state.playing} buffering=${watch.playerSession.player.state.buffering}',
      );
      expect(
        watch.playerSession.player.state.playing,
        isFalse,
        reason: 'Seeking a paused DVR must not automatically resume playback.',
      );
      await tester.pump(const Duration(seconds: 1));
      final held = watch.playerSession.player.state.position;
      await tester.pump(const Duration(seconds: 3));
      expect(watch.playerSession.player.state.playing, isFalse);
      expect(
        (watch.playerSession.player.state.position - held).inMilliseconds.abs(),
        lessThan(500),
      );
      expect(
        (watch.playbackTimelineController.snapshot.position - target)
            .inMilliseconds
            .abs(),
        lessThan(2000),
        reason:
            'Paused canonical timeline must stay near the resolved seek, not drift to live.',
      );
      debugPrint('[ReadonlyTest] passed: paused DVR seek preserves pause');
      debugPrint(
        '[ReadonlyTest] paused DVR before resume snapshotMs=${watch.playbackTimelineController.snapshot.position.inMilliseconds} resolvedMs=${watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition?.inMilliseconds}',
      );
      await tester.tap(overlay);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find
            .descendant(of: overlay, matching: find.byIcon(Icons.play_arrow))
            .first,
      );
      await waitFor(
        tester,
        () =>
            watch.playerSession.player.state.playing &&
            !watch.playerSession.player.state.buffering &&
            watch.playerSession.player.state.position > held,
        'paused DVR seek resumes decoded playback through UI',
        timeout: const Duration(seconds: 60),
      );
      final resumed = watch.playerSession.player.state.position;
      await tester.pump(const Duration(seconds: 10));
      expect(
        watch.playerSession.player.state.position - resumed,
        greaterThan(const Duration(seconds: 7)),
      );
      debugPrint(
        '[ReadonlyTest] passed: paused DVR seek sustains resumed playback',
      );
    }
    const dvrChatFocus = bool.fromEnvironment('TWITCH_READONLY_DVR_CHAT_FOCUS');
    if (dvrChatFocus) {
      final replayPanel = find.byType(TwitchVodReplayChatPanel);
      final badge = find.descendant(
        of: replayPanel,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ChatModeBadge',
        ),
      );
      expect(replayPanel, findsOneWidget);
      expect(badge, findsOneWidget);
      final dynamic initialBadge = tester.widget(badge);
      expect(initialBadge.mode, TwitchVodReplayChatMode.replay);
      await tester.tap(
        find.descendant(of: badge, matching: find.byType(InkWell)),
      );
      await waitFor(
        tester,
        () => find.byType(TwitchChatInputBar).evaluate().length == 1,
        'DVR chat badge switches replay to live composer',
      );
      final dynamic liveBadge = tester.widget(badge);
      expect(liveBadge.mode, TwitchVodReplayChatMode.live);
      final input = find.descendant(
        of: find.byType(TwitchChatInputBar),
        matching: find.byWidgetPredicate(
          (widget) => widget is EditableText || widget is ExtendedEditableText,
        ),
      );
      final bars = find.byType(TwitchChatInputBar);
      final editableTypes = find
          .descendant(
            of: bars,
            matching: find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString().contains('Editable'),
            ),
          )
          .evaluate()
          .map((element) => element.widget.runtimeType.toString())
          .toSet()
          .join(',');
      debugPrint(
        '[ReadonlyTest] chat focus diagnostic bars=${bars.evaluate().length} editableCount=${input.evaluate().length} editableTypes=$editableTypes',
      );
      expect(input, findsOneWidget);
      debugPrint(
        '[ReadonlyTest] chat focus diagnostic enabled=${tester.widget<TwitchChatInputBar>(bars).enabled}',
      );
      expect(
        tester
            .widget<TwitchChatInputBar>(find.byType(TwitchChatInputBar))
            .enabled,
        isTrue,
        reason:
            'Disabled input cannot prove focused editable shortcut protection.',
      );
      await tester.tap(input);
      await tester.pump(const Duration(milliseconds: 250));
      final dynamic editable = tester.widget(input);
      debugPrint(
        '[ReadonlyTest] chat focus diagnostic focused=${editable.focusNode.hasFocus}',
      );
      expect(editable.focusNode.hasFocus, isTrue);
      final source = TwitchMediaKitPlayerHost.currentMediaUri;
      final target =
          watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
      final before = watch.playerSession.player.state.position;
      expect(watch.playbackTimelineController.snapshot.canSeek, isTrue);
      expect(watch.watchPorts.player.runtime.usingLiveDvrBridge, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      for (var second = 0; second < 3; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(editable.focusNode.hasFocus, isTrue);
      expect(TwitchMediaKitPlayerHost.currentMediaUri, source);
      expect(
        watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition,
        target,
      );
      expect(watch.liveTimelineActionInFlight, isFalse);
      expect(watch.playerSession.player.state.playing, isTrue);
      expect(watch.playerSession.player.state.buffering, isFalse);
      expect(
        watch.playerSession.player.state.position - before,
        greaterThan(const Duration(seconds: 2)),
      );
      debugPrint(
        '[ReadonlyTest] passed: chat focus blocks DVR arrow seek while replay advances',
      );
      await tester.tap(find.byType(WatchControlsOverlay));
      await tester.pump(const Duration(milliseconds: 250));
      expect(editable.focusNode.hasFocus, isFalse);
      debugPrint('[ReadonlyTest] passed: player click releases chat focus');
      await tester.tap(
        find.descendant(of: badge, matching: find.byType(InkWell)),
      );
      await waitFor(
        tester,
        () => find.byType(TwitchChatInputBar).evaluate().isEmpty,
        'DVR chat badge restores replay without composer',
      );
      final dynamic restoredBadge = tester.widget(badge);
      expect(restoredBadge.mode, TwitchVodReplayChatMode.replay);
    }
    if (dvrControls) {
      final overlay = find.byType(WatchControlsOverlay);
      int? streamGeneration() => int.tryParse(
        Uri.tryParse(
              TwitchMediaKitPlayerHost.currentMediaUri ?? '',
            )?.queryParameters['v'] ??
            '',
      );
      for (final backwards in [true, false]) {
        framePhase = backwards ? 'dvr-controls-left' : 'dvr-controls-right';
        await tester.tap(overlay);
        await tester.pump(const Duration(milliseconds: 250));
        final snapshot = watch.playbackTimelineController.snapshot;
        debugPrint(
          '[ReadonlyTest] DVR controls preflight backwards=$backwards mode=${snapshot.mode.name} canSeek=${snapshot.canSeek} positionMs=${snapshot.position.inMilliseconds} durationMs=${snapshot.duration?.inMilliseconds} playing=${watch.playerSession.player.state.playing} streamGeneration=${streamGeneration()}',
        );
        expect(snapshot.mode.name, 'liveDvr');
        expect(snapshot.canSeek, isTrue);
        final target =
            snapshot.position + Duration(seconds: backwards ? -10 : 10);
        expect(target, greaterThan(Duration.zero));
        expect(
          target,
          lessThan(snapshot.duration! - const Duration(seconds: 30)),
        );
        final previousGeneration = streamGeneration();
        expect(previousGeneration, isNotNull);
        await tester.sendKeyEvent(
          backwards
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight,
        );
        await waitFor(
          tester,
          () {
            final generation = streamGeneration();
            final resolved =
                watch.watchPorts.player.runtime.liveDvrBridgeTimelinePosition;
            return generation != null &&
                generation > previousGeneration! &&
                resolved != null &&
                (resolved - target).inMilliseconds.abs() < 2000 &&
                !watch.liveTimelineActionInFlight &&
                watch.watchPorts.player.runtime.usingLiveDvrBridge &&
                watch.playerSession.player.state.playing &&
                !watch.playerSession.player.state.buffering &&
                watch.playerSession.player.state.position > Duration.zero;
          },
          backwards
              ? 'DVR left shortcut opens new stream near target'
              : 'DVR right shortcut opens new stream near target',
          timeout: const Duration(seconds: 90),
        );
        final observed = watch.playerSession.player.state.position;
        for (var second = 0; second < 10; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(
          watch.playerSession.player.state.position - observed,
          greaterThan(const Duration(seconds: 7)),
        );
        expect(watch.playerSession.player.state.buffering, isFalse);
        debugPrint(
          '[ReadonlyTest] passed: DVR shortcut sustains decoded playback for 10 seconds',
        );
      }
    }
    const extendedDvr = bool.fromEnvironment('TWITCH_READONLY_EXTENDED_DVR');
    if (extendedDvr) {
      framePhase = 'extended-dvr';
      for (final numerator in [1, 2]) {
        await watch.openActiveDvrReplayAt(
          Duration(milliseconds: duration.inMilliseconds * numerator ~/ 3),
        );
        await tester.pump(const Duration(seconds: 1));
        final seekBefore = watch.playerSession.player.state.position;
        await waitFor(
          tester,
          () =>
              !watch.playerSession.player.state.buffering &&
              watch.playerSession.player.state.position >
                  seekBefore + const Duration(seconds: 2),
          'repeated DVR seek $numerator decodes and advances',
          timeout: const Duration(seconds: 60),
        );
        final observedBefore = watch.playerSession.player.state.position;
        for (var second = 0; second < 10; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(
          watch.playerSession.player.state.position - observedBefore,
          greaterThan(const Duration(seconds: 7)),
          reason:
              'Every repeat seek must sustain playback, not reuse a stale playing flag.',
        );
        debugPrint(
          '[ReadonlyTest] passed: repeated seek $numerator sustains playback',
        );
      }
      final longBefore = watch.playerSession.player.state.position;
      for (var second = 1; second <= 120; second++) {
        await tester.pump(const Duration(seconds: 1));
        if (second % 10 == 0) {
          debugPrint(
            '[ReadonlyTest] extended replay second=$second progressMs=${(watch.playerSession.player.state.position - longBefore).inMilliseconds} playing=${watch.playerSession.player.state.playing} buffering=${watch.playerSession.player.state.buffering}',
          );
        }
      }
      expect(
        watch.playerSession.player.state.position - longBefore,
        greaterThan(const Duration(seconds: 90)),
      );
      debugPrint('[ReadonlyTest] passed: DVR sustains 120 second observation');
    }
    framePhase = 'return-live';
    await watch.returnToLivePlayback();
    await waitFor(
      tester,
      () =>
          !watch.watchPorts.player.runtime.usingLiveTimelineReplay &&
          watch.playerSession.player.state.playing,
      'DVR returns to live',
      timeout: const Duration(seconds: 60),
    );
    final returnedBefore = watch.playerSession.player.state.position;
    await waitFor(
      tester,
      () =>
          !watch.playerSession.player.state.buffering &&
          watch.playerSession.player.state.position > returnedBefore,
      'DVR returned live decodes',
      timeout: const Duration(seconds: 60),
    );
    final liveBefore = watch.playerSession.player.state.position;
    await tester.pump(const Duration(seconds: 10));
    final returnedProgress =
        watch.playerSession.player.state.position - liveBefore;
    expect(returnedProgress, greaterThan(const Duration(seconds: 7)));
    expect(watch.playerSession.player.state.playing, isTrue);
    expect(watch.playerSession.player.state.buffering, isFalse);
    debugPrint(
      '[ReadonlyTest] passed: returned live sustains 10 seconds progressMs=${returnedProgress.inMilliseconds}',
    );
    // Never call send, follow, subscribe, moderation, points or clip creation.
  }, timeout: const Timeout(Duration(minutes: 8)));
}
