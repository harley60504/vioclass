// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import '../lib/features/twitch/api/clips/twitch_clip_api_service.dart';
import '../lib/features/twitch/api/playback/twitch_playback_api_service.dart';
import '../lib/features/twitch/presentation/dialogs/twitch_clip_editor_dialog.dart';

class _Clips implements TwitchClipApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No clip API operation allowed');
}

class _Playback implements TwitchPlaybackApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No playback API operation allowed');
}

void main() {
  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    for (final closeFirst in [false, true]) {
      testWidgets(
        'Clip player initialization failure closeFirst=$closeFirst at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final first = Completer<Player>();
          var attempts = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => unawaited(
                      showTwitchClipEditorDialog(
                        context: context,
                        clipApi: _Clips(),
                        playbackApi: _Playback(),
                        vodId: 'fixture-vod',
                        offsetSeconds: 30,
                        channelName: 'Fixture',
                        createPlayer: (_) {
                          attempts++;
                          return attempts == 1
                              ? first.future
                              : Future<Player>.error(
                                  StateError(
                                    'fixture native initialization failure',
                                  ),
                                );
                        },
                      ),
                    ),
                    child: const Text('fixture open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('fixture open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(attempts, 1);
          if (closeFirst) {
            await tester.tap(find.byIcon(Icons.close));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          first.completeError(
            StateError('fixture native initialization failure'),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          if (!closeFirst) {
            expect(find.text('剪輯編輯暫時失敗，請稍後再試。'), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            expect(find.textContaining('fixture native'), findsNothing);
            await tester.tap(find.text('重試'));
            await tester.pump();
            await tester.pump();
            expect(attempts, 2);
            expect(find.text('剪輯編輯暫時失敗，請稍後再試。'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } else {
            expect(find.text('編輯剪輯'), findsNothing);
            expect(find.text('fixture open'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
