// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_moderation_shortcut.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_target_policy.dart';
import '../lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart';
import '../lib/features/twitch/presentation/sheets/twitch_moderation_batch_sheet.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_moderation_message_actions.dart';

TwitchChatRuntimeMessage _message({
  Map<String, String> tags = const {},
  TwitchChatMessageSource source = TwitchChatMessageSource.liveIrc,
}) {
  final raw = TwitchChatMessage(
    raw: '',
    command: 'PRIVMSG',
    channel: 'test',
    userLogin: 'peer',
    displayName: 'Peer',
    message: 'fake message',
    source: source,
    tags: {'id': 'official-message', 'user-id': '30', 'room-id': '20', ...tags},
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
  bool fail = false;
  _Api()
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
      );
  @override
  Future<void> deleteMessages({String? messageId}) async {
    if (fail) throw const TwitchModerationException('fake failure');
    actions.add('delete:$messageId');
  }

  @override
  Future<void> warn(String userId, {required String reason}) async =>
      actions.add('warn:$userId:$reason');
  @override
  Future<void> ban(String userId, {int? seconds, String reason = ''}) async =>
      actions.add('ban:$userId:$seconds:$reason');
  @override
  Future<void> unban(String userId) async => actions.add('unban:$userId');
}

void main() {
  late _Api api;
  var permission = true;
  setUp(() {
    api = _Api();
    permission = true;
  });
  tearDown(() => api.client.close());
  for (final action in TwitchChatModerationShortcut.values) {
    testWidgets(
      'Shortcut ${action.name} confirms before exactly one fake write',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTwitchModerationShortcut(
                    context: context,
                    api: api,
                    message: _message(),
                    channelName: 'test',
                    canModerate: () => permission,
                    action: action,
                  ),
                  child: const Text('shortcut'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('shortcut'));
        await tester.pumpAndSettle();
        expect(find.text('確認管理操作'), findsOneWidget);
        expect(api.actions, isEmpty);
        if (action == TwitchChatModerationShortcut.warn) {
          await tester.enterText(find.byType(TextFormField), 'fixture reason');
        }
        await tester.tap(find.text('確認'));
        await tester.pumpAndSettle();
        expect(api.actions, [
          switch (action) {
            TwitchChatModerationShortcut.delete => 'delete:official-message',
            TwitchChatModerationShortcut.timeout => 'ban:30:600:',
            TwitchChatModerationShortcut.warn => 'warn:30:fixture reason',
            TwitchChatModerationShortcut.ban => 'ban:30:null:',
            TwitchChatModerationShortcut.unban => 'unban:30',
          },
        ]);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Shortcut permission revoked during confirmation writes nothing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTwitchModerationShortcut(
                  context: context,
                  api: api,
                  message: _message(),
                  channelName: 'test',
                  canModerate: () => permission,
                  action: TwitchChatModerationShortcut.delete,
                ),
                child: const Text('shortcut'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('shortcut'));
      await tester.pumpAndSettle();
      permission = false;
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      expect(find.text('管理身分或頻道已變更，未送出操作。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
  test(
    'policy excludes shared origin, protected users and synthetic delete IDs',
    () {
      bool manage(TwitchChatRuntimeMessage message) =>
          TwitchModerationTargetPolicy.canManageUser(
            message,
            broadcasterId: '20',
            moderatorId: '10',
          );
      expect(manage(_message()), true);
      for (final tags in [
        {'source-room-id': '99'},
        {'room-id': '99'},
        {'user-id': '20'},
        {'user-id': '10'},
        {'user-id': ''},
        {'badges': 'moderator/1'},
        {'mod': '1'},
      ]) {
        expect(manage(_message(tags: tags)), false);
      }
      expect(
        TwitchModerationTargetPolicy.canDelete(
          _message(tags: {'id': ''}),
          '20',
        ),
        false,
      );
      expect(
        TwitchModerationTargetPolicy.canDelete(
          _message(source: TwitchChatMessageSource.localEcho),
          '20',
        ),
        false,
      );
      expect(
        TwitchModerationTargetPolicy.canDelete(
          _message(tags: {'source-room-id': '99'}),
          '20',
        ),
        false,
      );
      expect(
        TwitchModerationTargetPolicy.canDelete(
          _message(tags: {'user-id': '10'}),
          '20',
        ),
        true,
      );
    },
  );
  Future<void> open(
    WidgetTester tester, {
    bool withActions = true,
    bool withBatch = false,
  }) async {
    final message = _message();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTwitchChatMessageContextSheet(
                context: context,
                selectedMessage: message,
                messages: [message],
                messageActionBuilder: !withActions
                    ? null
                    : (context, item) => TwitchModerationMessageActions(
                        api: api,
                        message: item,
                        channelName: 'test',
                        canModerate: () => permission,
                        onOpenBatch: !withBatch
                            ? null
                            : () => showTwitchModerationBatchSheet(
                                context: context,
                                api: api,
                                messages: [message],
                                channelName: 'test',
                                canModerate: () => permission,
                                initialMessageId: message.source.tags['id'],
                              ),
                      ),
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

  Future<void> choose(WidgetTester tester, String action) async {
    await tester.tap(find.text('管理這則訊息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Message context opens batch selection without immediately deleting',
    (tester) async {
      await open(tester, withBatch: true);
      await choose(tester, '批次選取訊息');
      final checkbox = find.byKey(const ValueKey('batch-select-0'));
      expect(checkbox, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      expect(api.actions, isEmpty);
      expect(find.text('預覽刪除'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('ordinary viewer retains reply context without mod controls', (
    tester,
  ) async {
    await open(tester, withActions: false);
    expect(find.textContaining('回覆串'), findsOneWidget);
    expect(find.text('管理這則訊息'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'delete requires confirmation and preserves original thread card',
    (tester) async {
      await open(tester);
      await choose(tester, '刪除訊息');
      expect(api.actions, isEmpty);
      expect(find.textContaining('@test\nPeer'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.actions, isEmpty);
      await choose(tester, '刪除訊息');
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.actions, ['delete:official-message']);
      expect(find.textContaining('回覆串'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('warning validates reason and emits only one confirmed action', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, '警告');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    expect(find.text('警告需要有效對象與 1–500 字的原因。'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'test reason');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.actions, ['warn:30:test reason']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('role loss while confirm is open cannot send a stale action', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, '刪除訊息');
    permission = false;
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    expect(find.text('管理身分或頻道已變更，未送出操作。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile custom timeout validates and sends selected duration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    await choose(tester, '自訂禁言時間');
    await tester.enterText(find.byType(TextFormField).first, '0');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, '120');
    await tester.enterText(find.byType(TextFormField).last, 'test timeout');
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.actions, ['ban:30:120:test timeout']);
    expect(tester.takeException(), isNull);
  });
}
