import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vioclass/features/twitch/api/clips/twitch_clip_api_service.dart';
import 'package:vioclass/features/twitch/api/playback/twitch_playback_api_service.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_m3u8_variant.dart';
import 'package:vioclass/features/twitch/presentation/dialogs/twitch_clip_editor_dialog.dart';
import '../docs/twitch_native_log_diagnostics.dart';

class _Clips implements TwitchClipApiService {
  _Clips(this.previewUri);
  final String previewUri;
  int begins = 0;
  int creates = 0;
  int waits = 0;
  @override
  Future<TwitchClipEditSession> beginClipEdit({
    String? vodId,
    String? broadcastId,
    required double offsetSeconds,
  }) async {
    expect(vodId, 'fixture-vod');
    expect(offsetSeconds, 30);
    begins++;
    return TwitchClipEditSession(
      rawMediaId: 'fixture-raw',
      durationSeconds: 30,
      previewUrl: previewUri,
    );
  }

  @override
  Future<TwitchCreateClipResult> finalizeClip({
    required String rawMediaId,
    required double startSeconds,
    required double durationSeconds,
    required String title,
  }) async {
    expect(rawMediaId, 'fixture-raw');
    expect(startSeconds, 0);
    expect(durationSeconds, 30);
    expect(title, 'Fixture local clip');
    creates++;
    return const TwitchCreateClipResult(id: 'fixture-created', editUrl: '');
  }

  @override
  Future<TwitchClipRenderStatus> waitForClipRenderReady({
    required String clipSlug,
  }) async {
    expect(clipSlug, 'fixture-created');
    waits++;
    return const TwitchClipRenderStatus(ready: true, thumbnailUrl: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected isolated clip operation');
}

class _Playback implements TwitchPlaybackApiService {
  _Playback(this.uri);
  final String uri;
  int resolves = 0;
  @override
  Future<TwitchClipPlaybackResult> resolveClipPlayback({
    required String clipSlug,
    String preferredQuality = 'source',
  }) async {
    expect(clipSlug, 'fixture-created');
    resolves++;
    final variant = TwitchM3u8Variant(
      name: '360p',
      resolution: '640x360',
      url: uri,
      sourceTag: 'local-fixture',
    );
    return TwitchClipPlaybackResult(
      playbackUri: Uri.parse(uri),
      variants: [variant],
      selectedVariant: variant,
      durationSeconds: 30,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected isolated playback operation');
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), true, reason: reason);
}

void main() {
  const root = String.fromEnvironment('VIOCLASS_LOCAL_AV_FIXTURE_ROOT');
  if (root.isEmpty) {
    throw StateError('An explicit local media directory is required');
  }
  final input = File('$root/320x180.mkv');
  final output = File('$root/640x360.mkv');
  if (!input.existsSync() || !output.existsSync()) {
    throw StateError('Local clip fixtures are missing');
  }
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Local clip editor creates preview and disposes both native players', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final clips = _Clips(input.uri.toString());
    final playback = _Playback(output.uri.toString());
    Player? editing;
    Player? created;
    StreamSubscription<PlayerLog>? logs;
    final diagnostics = TwitchNativeLogDiagnostics();
    var returns = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showTwitchClipEditorDialog(
                    context: context,
                    clipApi: clips,
                    playbackApi: playback,
                    vodId: 'fixture-vod',
                    offsetSeconds: 30,
                    channelName: 'Fixture',
                    createPlayer: (configuration) async {
                      final player = await Player.create(
                        configuration: configuration,
                      );
                      await player.setVolume(0);
                      logs = player.stream.log.listen(
                        (event) => diagnostics.record(event.text),
                      );
                      editing = player;
                      return player;
                    },
                  );
                  returns++;
                },
                child: const Text('fixture clip editor open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fixture clip editor open'));
      await _wait(
        tester,
        () =>
            editing != null &&
            clips.begins == 1 &&
            editing!.getProperty('video-params/h') == '180' &&
            find.byType(Video).evaluate().isNotEmpty,
        'editing preview decodes the local 180p source',
      );
      await tester.enterText(find.byType(EditableText), 'Fixture local clip');
      await tester.tap(find.text('建立片段').hitTestable());
      await _wait(
        tester,
        () => find.text('片段已建立').evaluate().isNotEmpty,
        'fake creation reaches native preview',
      );
      created = tester.widget<Video>(find.byType(Video)).controller.player;
      await created.setVolume(0);
      expect(created, isNot(same(editing)));
      expect(editing!.disposed, true);
      await _wait(
        tester,
        () =>
            created!.getProperty('video-params/h') == '360' &&
            created.state.playing &&
            created.state.position.inMilliseconds > 500,
        'new native preview decodes and plays 360p',
      );
      final start = created.state.position;
      await tester.pump(const Duration(seconds: 2));
      expect(
        created.state.position - start,
        greaterThan(const Duration(seconds: 1)),
      );
      expect(find.byType(Texture), findsWidgets);
      expect(clips.begins, 1);
      expect(clips.creates, 1);
      expect(clips.waits, 1);
      expect(playback.resolves, 1);
      await tester.tap(find.text('關閉').hitTestable());
      await _wait(
        tester,
        () =>
            created!.disposed &&
            returns == 1 &&
            find.byType(Video).evaluate().isEmpty,
        'closing returns to the parent and disposes the preview player',
      );
      expect(find.text('fixture clip editor open'), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[LocalClipEditor] complete nativeHeights=180,360 editDisposed=true previewDisposed=true fakeCreates=1 playbackAdvanced=true',
      );
    } catch (error) {
      debugPrint(
        '[LocalClipEditor] failed type=${error.runtimeType} begins=${clips.begins} creates=${clips.creates} '
        'hasPlayer=${editing != null} hasVideo=${find.byType(Video).evaluate().isNotEmpty} '
        'hasSource=${editing != null && !editing!.disposed && editing!.getProperty('path').isNotEmpty} '
        'height=${editing != null && !editing!.disposed ? editing!.getProperty('video-params/h') : '-'} '
        'playing=${editing?.state.playing} buffering=${editing?.state.buffering} categories=${diagnostics.snapshot}',
      );
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox());
      await logs?.cancel();
      for (final player in [editing, created]) {
        if (player != null && !player.disposed) await player.dispose();
      }
    }
  });
}
