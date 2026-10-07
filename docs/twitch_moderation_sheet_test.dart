// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_automod_settings.dart';
import '../lib/features/twitch/presentation/sheets/twitch_automod_settings_sheet.dart';
import '../lib/features/twitch/presentation/sheets/twitch_moderation_sheet.dart';
import '../lib/features/twitch/services/chat/twitch_chat_runtime.dart';

class _Api extends TwitchModerationApiService {
  int automodReads = 0;
  final updates = <Map<String, dynamic>>[];
  final warnings = <String>[];
  final userActions = <String>[];
  final values = <String, dynamic>{
    'slow_mode': false,
    'slow_mode_wait_time': null,
    'follower_mode': false,
    'follower_mode_duration': null,
  };
  _Api()
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
      );
  @override
  Future<Map<String, dynamic>> settings({Map<String, dynamic>? changes}) async {
    if (changes != null) {
      updates.add(changes);
      values.addAll(changes);
    }
    return Map.from(values);
  }

  @override
  Future<void> warn(String userId, {required String reason}) async =>
      warnings.add('$userId:$reason');
  @override
  Future<void> ban(String userId, {int? seconds, String reason = ''}) async =>
      userActions.add('ban:$userId:$seconds:$reason');
  @override
  Future<void> unban(String userId) async => userActions.add('unban:$userId');
  @override
  Future<TwitchAutomodSettings> automodSettings({
    Map<String, int>? changes,
  }) async {
    automodReads++;
    return TwitchAutomodSettings(
      overallLevel: 2,
      levels: {for (final key in TwitchAutomodSettings.categories.keys) key: 1},
    );
  }
}

class _Runtime extends ChangeNotifier implements TwitchChatRuntime {
  bool targetModerator = false;
  bool targetVisible = true;
  @override
  List<TwitchChatRuntimeMessage> get messages {
    if (!targetVisible) return [];
    final source = TwitchChatMessage(
      raw: '',
      command: 'PRIVMSG',
      channel: 'test',
      userLogin: 'peer',
      displayName: 'Peer',
      message: 'fake test message',
      tags: {
        'id': 'fake-message',
        'user-id': '30',
        if (targetModerator) 'badges': 'moderator/1',
      },
    );
    return [
      TwitchChatRuntimeMessage(
        source: source,
        resolvedBadges: const [],
        receivedAt: DateTime.utc(2026),
        fragments: const [],
        segments: const [],
        metadata: TwitchChatMessageMetadata.fromMessage(source),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Api api;
  late _Runtime runtime;
  var permission = true;
  setUp(() {
    api = _Api();
    runtime = _Runtime();
    permission = true;
  });
  tearDown(() {
    api.client.close();
    runtime.dispose();
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTwitchModerationSheet(
                context: context,
                api: api,
                runtime: runtime,
                canModerate: () => permission,
                channelName: 'test_channel',
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

  for (final action in ['禁言 10 分鐘', '自訂禁言時間', '封鎖', '解除封鎖／禁言']) {
    for (final outcome in ['success', 'cancel', 'promoted', 'missing']) {
      testWidgets('User action confirmation: $action / $outcome', (
        tester,
      ) async {
        await open(tester);
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(TextField),
          150,
          scrollable: scrollable,
        );
        await tester.enterText(find.byType(TextField), 'fixture reason');
        await tester.scrollUntilVisible(
          find.text('Peer'),
          150,
          scrollable: scrollable,
        );
        final tile = find.ancestor(
          of: find.text('Peer'),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        if (action == '自訂禁言時間') {
          await tester.enterText(find.byType(TextFormField), '90');
          await tester.tap(find.text('繼續'));
          await tester.pumpAndSettle();
          expect(find.textContaining('90 秒'), findsOneWidget);
        }
        expect(find.textContaining('@test_channel\nPeer'), findsOneWidget);
        if (action != '解除封鎖／禁言') {
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining('fixture reason'),
            ),
            findsOneWidget,
          );
        }
        expect(api.userActions, isEmpty);
        if (outcome == 'promoted') runtime.targetModerator = true;
        if (outcome == 'missing') runtime.targetVisible = false;
        await tester.tap(find.text(outcome == 'cancel' ? '取消' : '確認'));
        await tester.pumpAndSettle();
        if (outcome == 'success') {
          expect(api.userActions, [
            switch (action) {
              '禁言 10 分鐘' => 'ban:30:600:fixture reason',
              '自訂禁言時間' => 'ban:30:90:fixture reason',
              '封鎖' => 'ban:30:null:fixture reason',
              _ => 'unban:30',
            },
          ]);
        } else {
          expect(api.userActions, isEmpty);
        }
        if (outcome == 'promoted' || outcome == 'missing') {
          await tester.scrollUntilVisible(
            find.text('對象身分已變更或無法確認，未送出操作。'),
            -150,
            scrollable: scrollable,
          );
          expect(find.text('對象身分已變更或無法確認，未送出操作。'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('Moderation opens batch selection for its original channel', (
    tester,
  ) async {
    await open(tester);
    await tester.scrollUntilVisible(
      find.text('批次刪除訊息'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('批次刪除訊息'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('batch-select-0')), findsOneWidget);
    expect(find.text('@test_channel'), findsWidgets);
    expect(api.updates, isEmpty);
    expect(api.warnings, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'duration validates and requires explicit confirmation before update',
    (tester) async {
      await open(tester);
      await tester.ensureVisible(find.text('慢速模式'));
      await tester.tap(find.text('慢速模式'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '121');
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(find.text('請輸入範圍內的整數。'), findsOneWidget);
      expect(api.updates, isEmpty);
      await tester.enterText(find.byType(TextFormField), '60');
      await tester.tap(find.text('繼續'));
      await tester.pumpAndSettle();
      expect(api.updates, isEmpty);
      expect(find.textContaining('@test_channel\n'), findsOneWidget);
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.updates.single, {
        'slow_mode': true,
        'slow_mode_wait_time': 60,
      });
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(SwitchListTile).first)).pop();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('role change during confirmation prevents room mutation', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('僅限貼圖'));
    await tester.pumpAndSettle();
    permission = false;
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.updates, isEmpty);
    expect(find.text('你沒有這個頻道的管理權限。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(SwitchListTile).first)).pop();
    await tester.pumpAndSettle();
  });
  testWidgets(
    'moderation settings opens independent AutoMod panel for the same channel',
    (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.text('AutoMod 設定'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('AutoMod 設定'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchAutomodSettingsPanel), findsOneWidget);
      expect(api.automodReads, 1);
      expect(
        tester
            .widget<TwitchAutomodSettingsPanel>(
              find.byType(TwitchAutomodSettingsPanel),
            )
            .channelName,
        'test_channel',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final promoted in [true, false]) {
    testWidgets(
      'Warning rechecks target after confirmation: promoted=$promoted',
      (tester) async {
        await open(tester);
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(TextField),
          150,
          scrollable: scrollable,
        );
        await tester.enterText(find.byType(TextField), 'fixture warning');
        await tester.scrollUntilVisible(
          find.text('Peer'),
          150,
          scrollable: scrollable,
        );
        final tile = find.ancestor(
          of: find.text('Peer'),
          matching: find.byType(ListTile),
        );
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('警告'));
        await tester.pumpAndSettle();
        runtime.targetModerator = promoted;
        runtime.targetVisible = promoted;
        await tester.tap(find.text('確認'));
        await tester.pumpAndSettle();
        expect(api.warnings, isEmpty);
        await tester.scrollUntilVisible(
          find.text('對象身分已變更或無法確認，未送出操作。'),
          -150,
          scrollable: scrollable,
        );
        expect(find.text('對象身分已變更或無法確認，未送出操作。'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('warning confirmation includes recipient, reason and channel', (
    tester,
  ) async {
    await open(tester);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.byType(TextField), 'test warning reason');
    await tester.scrollUntilVisible(
      find.text('Peer'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final tile = find.ancestor(
      of: find.text('Peer'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('警告'));
    await tester.pumpAndSettle();
    expect(api.warnings, isEmpty);
    expect(find.textContaining('@test_channel\nPeer'), findsOneWidget);
    expect(find.textContaining('test warning reason'), findsWidgets);
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.warnings, ['30:test warning reason']);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(SwitchListTile).first)).pop();
    await tester.pumpAndSettle();
  });
}
