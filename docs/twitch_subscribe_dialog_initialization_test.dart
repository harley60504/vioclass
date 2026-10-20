// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/presentation/dialogs/twitch_subscribe_webview_dialog_v1.dart';
import '../lib/features/twitch/presentation/localization/vioclass_localizations.dart';

void main() {
  test('Subscription identity change has an English translation', () {
    expect(
      const VioClassLocalizations(Locale('en')).t('登入狀態已變更，請關閉後重新開啟訂閱頁。'),
      'Your sign-in state changed. Close and reopen the subscribe page.',
    );
  });
  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    for (final scenario in [
      'success',
      'failure',
      'close-pending',
      'logout-pending',
      'switch-pending',
      'switch-visible',
    ]) {
      testWidgets('Subscription preparation $scenario at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final ready = Completer<void>();
        var prepared = 0;
        var pages = 0;
        final session = ValueNotifier<int>(0);
        addTearDown(session.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => unawaited(
                    showTwitchSubscribeWebViewDialogV1(
                      context: context,
                      initialUri: Uri.parse(
                        'https://www.twitch.tv/subs/fixture',
                      ),
                      channelLogin: 'fixture',
                      sessionChanges: session,
                      isCurrentSession: () => session.value == 0,
                      prepareAuthCookies: () {
                        prepared++;
                        return ready.future;
                      },
                      webViewBuilder: (_) {
                        pages++;
                        return const Text('fixture payment placeholder');
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
        expect(prepared, 1);
        expect(pages, 0);
        if (scenario == 'close-pending') {
          await tester.tap(find.byIcon(Icons.close));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        if (scenario.endsWith('-pending') && scenario != 'close-pending') {
          session.value++;
          await tester.pump();
        }
        if (scenario == 'success' ||
            scenario.startsWith('switch-') ||
            scenario == 'logout-pending') {
          ready.complete();
        } else {
          ready.completeError(StateError('fixture private preparation error'));
        }
        await tester.pump();
        if (scenario == 'switch-visible') {
          expect(find.text('fixture payment placeholder'), findsOneWidget);
          session.value++;
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        if (scenario == 'failure') {
          expect(pages, 0);
          expect(find.text('訂閱頁暫時無法開啟，請稍後再試。'), findsOneWidget);
          expect(find.textContaining('fixture private'), findsNothing);
        } else if (scenario == 'success') {
          expect(find.text('fixture payment placeholder'), findsOneWidget);
        } else if (scenario.startsWith('switch-') ||
            scenario == 'logout-pending') {
          expect(pages, scenario == 'switch-visible' ? 1 : 0);
          expect(find.text('fixture payment placeholder'), findsNothing);
          expect(find.text('登入狀態已變更，請關閉後重新開啟訂閱頁。'), findsOneWidget);
        } else {
          expect(pages, 0);
          expect(find.text('fixture open'), findsOneWidget);
        }
        if (scenario != 'close-pending') {
          await tester.tap(find.byIcon(Icons.close));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('fixture open'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
