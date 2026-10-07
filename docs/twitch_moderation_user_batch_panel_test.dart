// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_target_policy.dart';
import '../lib/features/twitch/presentation/sheets/twitch_moderation_user_batch_sheet.dart';

TwitchChatRuntimeMessage _message(String id, String user) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'fixture',
    userLogin: 'fixture',
    displayName: 'Fixture $user',
    message: 'Message $id',
    tags: {'id': id, 'user-id': user, 'room-id': '20'},
  );
  return TwitchChatRuntimeMessage(
    source: raw,
    resolvedBadges: const [],
    receivedAt: DateTime.utc(2026),
    fragments: const [],
    segments: const [],
    metadata: TwitchChatMessageMetadata.fromMessage(raw),
  );
}

class _Api extends TwitchModerationApiService {
  final actions = <String>[];
  Future<void> Function()? response;
  _Api()
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
      );
  @override
  Future<void> warn(String userId, {required String reason}) async {
    actions.add('warn:$userId:$reason');
    await response?.call();
  }

  @override
  Future<void> ban(String userId, {int? seconds, String reason = ''}) async {
    actions.add('timeout:$userId:$seconds:$reason');
    await response?.call();
  }
}

Future<void> _visible(WidgetTester tester, Finder finder, double delta) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
}

void main() {
  late _Api api;
  var permitted = true;
  var targetAllowed = true;
  setUp(() {
    api = _Api();
    permitted = true;
    targetAllowed = true;
  });
  tearDown(() => api.client.close());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTwitchModerationUserBatchSheet(
                context: context,
                api: api,
                messages: [
                  _message('a', '30'),
                  _message('b', '30'),
                  _message('c', '40'),
                  _message('owner', '20'),
                ],
                channelName: 'fixture',
                canModerate: () => permitted,
                canManageTarget: (_) => targetAllowed,
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

  Future<void> confirmTimeout(WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('警告'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('禁言').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, ' fixture timeout ');
    await tester.enterText(find.byType(TextField).last, '60');
    await _visible(tester, find.text('預覽使用者'), 100);
    await tester.tap(find.text('預覽使用者'));
    await tester.pumpAndSettle();
    await _visible(tester, find.text('繼續確認'), -100);
    await tester.tap(find.text('繼續確認'));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    expect(find.textContaining('@fixture\n禁言 · 2'), findsOneWidget);
    await tester.tap(find.text('確認送出'));
    await tester.pump();
  }

  testWidgets('Timeout sends fixed duration and reason once per user', (
    tester,
  ) async {
    await confirmTimeout(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.actions, [
      'timeout:30:60:fixture timeout',
      'timeout:40:60:fixture timeout',
    ]);
    expect(find.text('批次處理結束'), findsOneWidget);
    expect(find.text('繼續確認'), findsNothing);
    expect(find.text('返回設定'), findsNothing);
    await _visible(tester, find.text('Fixture 40'), 100);
    expect(find.textContaining('已提交；以 Twitch 狀態為準'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final close in [false, true]) {
    for (final lateFailure in [false, true]) {
      testWidgets(
        'In-flight timeout stops remaining users: close=$close lateFailure=$lateFailure',
        (tester) async {
          final gate = Completer<void>();
          api.response = () => gate.future;
          await confirmTimeout(tester);
          await tester.pumpAndSettle();
          expect(api.actions, ['timeout:30:60:fixture timeout']);
          await tester.tap(
            close ? find.byIcon(Icons.close_rounded) : find.text('停止後續操作'),
          );
          await tester.pumpAndSettle();
          if (lateFailure) {
            gate.completeError(StateError('fixture uncertain response'));
          } else {
            gate.complete();
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(api.actions, ['timeout:30:60:fixture timeout']);
          expect(
            close ? find.text('open') : find.text('已停止後續操作'),
            findsOneWidget,
          );
          if (!close) {
            await _visible(tester, find.text('Fixture 30'), 100);
            expect(
              find.textContaining(
                lateFailure ? '結果不明；請先核對，勿直接重送' : '已提交；以 Twitch 狀態為準',
              ),
              findsOneWidget,
            );
            await _visible(tester, find.text('Fixture 40'), 100);
            expect(find.textContaining('User ID: 40\n未送出'), findsOneWidget);
            expect(find.text('繼續確認'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('Permission revoked after first timeout prevents the second', (
    tester,
  ) async {
    final gate = Completer<void>();
    api.response = () => gate.future;
    await confirmTimeout(tester);
    expect(api.actions, ['timeout:30:60:fixture timeout']);
    permitted = false;
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.actions, ['timeout:30:60:fixture timeout']);
    expect(find.text('管理身分或頻道已變更，未送出剩餘操作。'), findsOneWidget);
    expect(find.text('批次已停止'), findsOneWidget);
    expect(find.text('繼續確認'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final rejected in [true, false]) {
    testWidgets(
      'Timeout response stops batch without replay: rejected=$rejected',
      (tester) async {
        final gate = Completer<void>();
        api.response = () => gate.future;
        await confirmTimeout(tester);
        expect(api.actions, ['timeout:30:60:fixture timeout']);
        gate.completeError(
          rejected
              ? const TwitchModerationException('fixture Twitch refusal')
              : StateError('fixture network outcome unknown'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(api.actions, ['timeout:30:60:fixture timeout']);
        expect(find.text('批次已停止'), findsOneWidget);
        if (rejected) {
          expect(find.text('fixture Twitch refusal'), findsOneWidget);
        }
        await _visible(tester, find.text('Fixture 30'), 100);
        expect(
          find.textContaining(
            rejected ? 'User ID: 30\n未接受' : '結果不明；請先核對，勿直接重送',
          ),
          findsOneWidget,
        );
        await _visible(tester, find.text('Fixture 40'), 100);
        expect(find.textContaining('User ID: 40\n未送出'), findsOneWidget);
        expect(find.text('繼續確認'), findsNothing);
        expect(find.text('返回設定'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test(
    'Visible role gate refuses absent or contradictory protected user hints',
    () {
      final messages = [_message('a', '30'), _message('b', '30')];
      bool check(String user) =>
          TwitchModerationTargetPolicy.canManageVisibleUser(
            messages,
            user,
            broadcasterId: '20',
            moderatorId: '10',
          );
      expect(check('30'), isTrue);
      expect(check('40'), isFalse);
      messages.last.source.tags['badges'] = 'moderator/1';
      expect(check('30'), isFalse);
    },
  );
  testWidgets(
    'Warning form deduplicates preview, cancel preserves reason and confirmed users send once',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('預覽使用者'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await tester.enterText(find.byType(TextField), 'fixture reason');
      await _visible(tester, find.text('預覽使用者'), 100);
      await tester.tap(find.text('預覽使用者'));
      await tester.pumpAndSettle();
      expect(find.text('警告 · 預覽 2 · 排除或重複 2'), findsOneWidget);
      await tester.tap(find.text('繼續確認'));
      await tester.pumpAndSettle();
      expect(find.textContaining('@fixture\n警告 · 2'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await tester.tap(find.text('繼續確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認送出'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.actions, ['warn:30:fixture reason', 'warn:40:fixture reason']);
      expect(find.text('繼續確認'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Timeout form at narrow phone validates seconds and rechecks target before write',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.tap(find.text('警告'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('禁言').last);
      await tester.pumpAndSettle();
      await _visible(tester, find.byType(TextField).last, 100);
      await tester.enterText(find.byType(TextField).last, '0');
      await _visible(tester, find.text('預覽使用者'), 100);
      await tester.tap(find.text('預覽使用者'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await _visible(tester, find.byType(TextField).last, -100);
      await tester.enterText(find.byType(TextField).last, '60');
      await _visible(tester, find.text('預覽使用者'), 100);
      await tester.tap(find.text('預覽使用者'));
      await tester.pumpAndSettle();
      await _visible(tester, find.text('繼續確認'), -100);
      await tester.tap(find.text('繼續確認'));
      await tester.pumpAndSettle();
      expect(find.textContaining('60 秒'), findsWidgets);
      targetAllowed = false;
      await tester.tap(find.text('確認送出'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      expect(find.text('對象身分已變更或無法確認，已停止後續操作。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
