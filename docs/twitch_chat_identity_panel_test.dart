// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_chat_identity_api_service.dart';
import '../lib/features/twitch/models/special_actions/twitch_viewer_special_message_models.dart';
import '../lib/features/twitch/presentation/sheets/twitch_special_message_sheet.dart';

const _badge = TwitchChatIdentityBadgeStage251(
  id: 'fixture:1',
  setId: 'fixture',
  version: '1',
  title: 'Fixture badge',
);
TwitchViewerSpecialMessagesSnapshotStage251 _snapshot({
  bool selected = false,
  String channel = 'fixture',
}) => TwitchViewerSpecialMessagesSnapshotStage251(
  channelLogin: channel,
  checkedAt: DateTime.utc(2026, 10, 4),
  chatIdentity: TwitchChatIdentityStatusStage251(
    channelLogin: channel,
    badges: [
      TwitchChatIdentityBadgeStage251(
        id: _badge.id,
        setId: _badge.setId,
        version: _badge.version,
        title: _badge.title,
        selected: selected,
      ),
    ],
  ),
);

void main() {
  for (final size in [const Size(320, 640), const Size(844, 290)]) {
    testWidgets(
      'Identity color remains operable with keyboard and enlarged text at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await _openIdentity(
          tester,
          scale: 1.3,
          keyboard: size.height > 300 ? 240 : 100,
          color: (_) async {
            calls++;
            throw const TwitchChatColorException(
              'Fixture authorization missing',
            );
          },
        );
        final scroll = _panelScroll();
        await tester.scrollUntilVisible(
          find.byType(TextField),
          100,
          scrollable: scroll,
        );
        await tester.enterText(find.byType(TextField), '#abcdef');
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('套用 ID 顏色'),
          100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('套用 ID 顏色'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(find.text('Fixture authorization missing'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byType(TextField),
          -100,
          scrollable: scroll,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '#abcdef',
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final result in ['confirmed', 'old', 'null', 'other channel', 'throw']) {
    testWidgets(
      'Manual refresh confirms accepted badge without resubmitting: $result',
      (tester) async {
        var submissions = 0;
        var refreshes = 0;
        await _openIdentity(
          tester,
          color: (_) async {},
          badge: (_) async {
            submissions++;
            return true;
          },
          refresh: () async {
            refreshes++;
            if (refreshes == 1) return _snapshot();
            if (result == 'throw') throw StateError('manual refresh');
            if (result == 'null') return null;
            return _snapshot(
              selected: result != 'old',
              channel: result == 'other channel' ? 'other' : 'fixture',
            );
          },
        );
        final scroll = _panelScroll();
        await tester.scrollUntilVisible(
          find.text('Fixture badge'),
          150,
          scrollable: scroll,
        );
        await tester.tap(find.text('Fixture badge'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('套用徽章'),
          100,
          scrollable: scroll,
        );
        await tester.tap(find.text('套用徽章'));
        await tester.pumpAndSettle();
        expect(submissions, 1);
        expect(refreshes, 1);
        await tester.tap(find.byTooltip('重新整理'));
        await tester.pumpAndSettle();
        expect(submissions, 1);
        expect(refreshes, 2);
        final status = find.text(
          result == 'confirmed' ? '已套用徽章' : '徽章套用已提交；請重新整理確認目前配戴。',
        );
        await tester.scrollUntilVisible(status, -100, scrollable: scroll);
        expect(status, findsOneWidget);
        if (result != 'confirmed') expect(find.text('已套用徽章'), findsNothing);
        if (result == 'throw') {
          expect(
            find.text('徽章套用已提交，但身分重新載入失敗；請重新整理確認，勿直接重複套用。'),
            findsOneWidget,
          );
        }
        await tester.scrollUntilVisible(
          find.text('Fixture badge'),
          100,
          scrollable: scroll,
        );
        expect(find.text('Fixture badge'), findsOneWidget);
        expect(find.text('套用徽章'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final custom in [false, true]) {
    testWidgets('Color preview only submits on apply: custom=$custom', (
      tester,
    ) async {
      final submitted = <String>[];
      final gate = Completer<void>();
      await _openIdentity(
        tester,
        color: (value) {
          submitted.add(value);
          return gate.future;
        },
      );
      final scroll = _panelScroll();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: scroll,
      );
      if (custom) {
        await tester.enterText(find.byType(TextField), '#123');
        await tester.pump();
        expect(find.text('請輸入 # 加上六位色碼'), findsOneWidget);
        expect(_applyButton(tester, '套用 ID 顏色').onPressed, isNull);
        await tester.enterText(find.byType(TextField), '#abcdef');
      } else {
        await tester.scrollUntilVisible(
          find.byTooltip('blue'),
          -100,
          scrollable: scroll,
        );
        await tester.tap(find.byTooltip('blue'));
      }
      await tester.pump();
      final text = tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .text;
      expect(text, custom ? '#abcdef' : '#0000FF');
      expect(
        tester.widget<Text>(find.text('Fixture viewer')).style!.color,
        Color(custom ? 0xFFABCDEF : 0xFF0000FF),
      );
      expect(submitted, isEmpty);
      tester.testTextInput.hide();
      await tester.scrollUntilVisible(
        find.text('套用 ID 顏色'),
        100,
        scrollable: scroll,
      );
      await tester.pump();
      await tester.tap(find.text('套用 ID 顏色'));
      await tester.pump();
      expect(submitted, [custom ? '#abcdef' : 'blue']);
      expect(find.text('ID 顏色已更新；新訊息會使用新顏色。'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ID 顏色已更新；新訊息會使用新顏色。'),
        100,
        scrollable: scroll,
      );
      expect(find.text('ID 顏色已更新；新訊息會使用新顏色。'), findsOneWidget);
      expect(_applyButton(tester, '套用 ID 顏色').onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final operation in ['color', 'badge', 'badge refresh']) {
    for (final failure in [false, true]) {
      testWidgets(
        'Closing pending $operation ignores late completion: failure=$failure',
        (tester) async {
          var colorCalls = 0;
          var badgeCalls = 0;
          var refreshes = 0;
          final colorGate = Completer<void>();
          final badgeGate = Completer<bool>();
          final refreshGate =
              Completer<TwitchViewerSpecialMessagesSnapshotStage251?>();
          await _openIdentity(
            tester,
            color: (_) {
              colorCalls++;
              return colorGate.future;
            },
            badge: (_) {
              badgeCalls++;
              return badgeGate.future;
            },
            refresh: () {
              refreshes++;
              return refreshGate.future;
            },
          );
          final scroll = _panelScroll();
          if (operation != 'color') {
            await tester.scrollUntilVisible(
              find.text('Fixture badge'),
              150,
              scrollable: scroll,
            );
            await tester.tap(find.text('Fixture badge'));
            await tester.pumpAndSettle();
          }
          await tester.scrollUntilVisible(
            find.text(operation == 'color' ? '套用 ID 顏色' : '套用徽章'),
            100,
            scrollable: scroll,
          );
          await tester.tap(
            find.text(operation == 'color' ? '套用 ID 顏色' : '套用徽章'),
          );
          await tester.pump();
          if (operation == 'badge refresh') {
            badgeGate.complete(true);
            await tester.pump();
            expect(refreshes, 1);
          }
          await tester.tap(find.byIcon(Icons.close_rounded));
          await tester.pumpAndSettle();
          expect(find.text('聊天身分與互動'), findsNothing);
          if (operation == 'color') {
            if (failure) {
              colorGate.completeError(StateError('late color'));
            } else {
              colorGate.complete();
            }
          } else if (operation == 'badge') {
            if (failure) {
              badgeGate.completeError(StateError('late badge'));
            } else {
              badgeGate.complete(true);
            }
          } else {
            if (failure) {
              refreshGate.completeError(StateError('late refresh'));
            } else {
              refreshGate.complete(_snapshot(selected: true));
            }
          }
          await tester.pumpAndSettle();
          expect(colorCalls, operation == 'color' ? 1 : 0);
          expect(badgeCalls, operation == 'color' ? 0 : 1);
          expect(refreshes, operation == 'badge refresh' ? 1 : 0);
          expect(find.text('open'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final operation in ['color', 'badge']) {
    testWidgets(
      'Identity operations serialize and retain rejected draft: $operation',
      (tester) async {
        var colorCalls = 0;
        var badgeCalls = 0;
        var refreshes = 0;
        final colorGate = Completer<void>();
        final badgeGate = Completer<bool>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchSpecialMessageSheetStage251(
                    context: context,
                    initialSnapshot: _snapshot(),
                    loading: false,
                    initialColor: '#9146FF',
                    viewerName: 'Fixture viewer',
                    onShareWatchStreak: (_) {},
                    onShareResub: (_) {},
                    onSetColor: (value) {
                      colorCalls++;
                      expect(value, '#9146FF');
                      return colorGate.future;
                    },
                    onSelectBadge: (_) {
                      badgeCalls++;
                      return badgeCalls == 1
                          ? badgeGate.future
                          : Future.value(false);
                    },
                    onRefresh: () async {
                      refreshes++;
                      return _snapshot();
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final scroll = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Fixture badge'),
          150,
          scrollable: scroll,
        );
        await tester.tap(find.text('Fixture badge'));
        await tester.pumpAndSettle();
        expect(colorCalls + badgeCalls, 0);
        final button = find.text(operation == 'badge' ? '套用徽章' : '套用 ID 顏色');
        await tester.scrollUntilVisible(
          button,
          operation == 'badge' ? 100 : -100,
          scrollable: scroll,
        );
        await tester.tap(button);
        await tester.pump();
        expect(colorCalls, operation == 'color' ? 1 : 0);
        expect(badgeCalls, operation == 'badge' ? 1 : 0);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.scrollUntilVisible(
          find.text('套用徽章'),
          100,
          scrollable: scroll,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('套用徽章'),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.scrollUntilVisible(
          find.text('套用 ID 顏色'),
          -100,
          scrollable: scroll,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('套用 ID 顏色'),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNull,
        );
        if (operation == 'color') {
          colorGate.completeError(
            const TwitchChatColorException('Fixture scope required'),
          );
        } else {
          badgeGate.complete(false);
        }
        await tester.pumpAndSettle();
        expect(refreshes, 0);
        expect(
          find.text(
            operation == 'color' ? 'Fixture scope required' : '聊天室身分更新失敗，稍後再試。',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '#9146FF',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        await tester.scrollUntilVisible(
          find.text('套用徽章'),
          100,
          scrollable: scroll,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('套用徽章'),
                  matching: find.byType(FilledButton),
                ),
              )
              .onPressed,
          isNotNull,
        );
        if (operation == 'badge') {
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('套用徽章'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('套用徽章'));
          await tester.pumpAndSettle();
          expect(badgeCalls, 2);
        }
        expect(find.text('已套用徽章'), findsNothing);
        expect(find.text('ID 顏色已更新；新訊息會使用新顏色。'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final result in ['throw', 'null', 'old', 'confirmed', 'other channel']) {
    testWidgets(
      'Badge acceptance and refreshed identity remain separate: $result',
      (tester) async {
        var submissions = 0;
        var refreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchSpecialMessageSheetStage251(
                    context: context,
                    initialSnapshot: _snapshot(),
                    loading: false,
                    onShareWatchStreak: (_) {},
                    onShareResub: (_) {},
                    onSelectBadge: (badge) async {
                      expect(badge.id, _badge.id);
                      submissions++;
                      return true;
                    },
                    onRefresh: () async {
                      refreshes++;
                      if (result == 'throw') {
                        throw StateError('fixture refresh failure');
                      }
                      if (result == 'null') return null;
                      return _snapshot(
                        selected: result != 'old',
                        channel: result == 'other channel'
                            ? 'other'
                            : 'fixture',
                      );
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Fixture badge'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Fixture badge'));
        await tester.pumpAndSettle();
        expect(submissions, 0);
        final apply = find.text('套用徽章');
        await tester.scrollUntilVisible(
          apply,
          100,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(submissions, 1);
        expect(refreshes, 1);
        expect(find.text('套用徽章'), findsNothing);
        final status = find.text(
          result == 'confirmed' ? '已套用徽章' : '徽章套用已提交；請重新整理確認目前配戴。',
        );
        await tester.scrollUntilVisible(
          status,
          -150,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(status, findsOneWidget);
        if (result != 'confirmed') expect(find.text('已套用徽章'), findsNothing);
        if (result == 'throw') {
          expect(
            find.text('徽章套用已提交，但身分重新載入失敗；請重新整理確認，勿直接重複套用。'),
            findsOneWidget,
          );
          expect(find.text('聊天室身分更新失敗，稍後再試。'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

Finder _panelScroll() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;
FilledButton _applyButton(WidgetTester tester, String title) =>
    tester.widget<FilledButton>(
      find.ancestor(of: find.text(title), matching: find.byType(FilledButton)),
    );
Future<void> _openIdentity(
  WidgetTester tester, {
  required Future<void> Function(String) color,
  double scale = 1,
  double keyboard = 0,
  Future<bool> Function(TwitchChatIdentityBadgeStage251)? badge,
  Future<TwitchViewerSpecialMessagesSnapshotStage251?> Function()? refresh,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTwitchSpecialMessageSheetStage251(
              context: context,
              initialSnapshot: _snapshot(),
              loading: false,
              viewerName: 'Fixture viewer',
              initialColor: '#9146FF',
              onSetColor: color,
              onShareWatchStreak: (_) {},
              onShareResub: (_) {},
              onSelectBadge: badge ?? (_) async => false,
              onRefresh: refresh ?? () async => _snapshot(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
