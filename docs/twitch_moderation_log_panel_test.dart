// ignore_for_file: avoid_relative_lib_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_archive_store.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_controller.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_log_entry.dart';
import '../lib/features/twitch/presentation/sheets/twitch_moderation_log_sheet.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/services/chat/twitch_moderation_log_eventsub_service.dart';

class _PanelApi extends TwitchModerationApiService {
  Completer<void>? gate;
  _PanelApi(String owner, String channel)
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        moderatorId: owner,
        broadcasterId: channel,
      );
  @override
  Future<TwitchModerationSession> moderationLogSession() async {
    await gate?.future;
    return TwitchModerationSession(
      'fake',
      TwitchTokenValidation(
        clientId: 'fake',
        userId: moderatorId,
        login: 'fixture',
        scopes: const [],
        expiresIn: 1000,
      ),
    );
  }
}

class _PanelReceiver extends TwitchModerationLogEventSubService {
  bool stopped = false;
  _PanelReceiver({
    required super.api,
    required super.onEntry,
    required super.onStatus,
  }) : super(onEvent: (_, _, _) {});
  @override
  void start() {
    connected = true;
    onStatus('fixture connected');
  }

  @override
  void stop() {
    stopped = true;
    connected = false;
  }

  void emit(String id, String target) => onEntry!(
    TwitchModerationLogEntry.parse(
      id: id,
      time: DateTime.utc(2026),
      expectedBroadcasterId: api.broadcasterId,
      event: {
        'action': 'ban',
        'broadcaster_user_id': api.broadcasterId,
        'moderator_user_id': api.moderatorId,
        'ban': {
          'user_id': '100',
          'user_name': target,
          'reason': 'fixture reason',
        },
      },
    )!,
  );
}

Future<void> _advanceLogPanel(WidgetTester tester) async {
  for (var step = 0; step < 8; step++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

class _PopulatedController extends TwitchModerationLogController {
  bool testSaving = false;
  int testUnsaved = 0;
  int retries = 0;
  List<TwitchModerationLogEntry>? testEntries;
  void setSaving(bool value) {
    testSaving = value;
    notifyListeners();
  }

  @override
  bool get saving => testSaving;
  @override
  int get unsavedCount => testUnsaved;
  @override
  Future<void> retrySaving() async => retries++;
  _PopulatedController()
    : super(
        archive: TwitchModerationLogArchiveStore(
          read: (_) async => null,
          write: (_, _) async {},
        ),
      );
  @override
  List<TwitchModerationLogEntry> get entries =>
      testEntries ??
      [
        for (var index = 0; index < 12; index++)
          TwitchModerationLogEntry.parse(
            id: 'entry-$index',
            time: DateTime.utc(2026, 10, 4, index),
            expectedBroadcasterId: '20',
            event: {
              'action': index.isEven ? 'ban' : 'clear',
              'broadcaster_user_id': '20',
              'moderator_user_id': '30',
              'moderator_user_name': 'Helper',
              if (index.isEven)
                'ban': {
                  'user_id': '${100 + index}',
                  'user_login': 'target$index',
                  'user_name': 'Target $index',
                  'reason': 'fixture reason $index',
                },
            },
          )!,
      ];
}

void main() {
  for (final scenario in [
    (
      action: 'shared_chat_delete',
      target: 'fixturelogin',
      query: '999',
      details: <String, dynamic>{
        'user_id': '100',
        'user_name': ' ',
        'user_login': 'fixturelogin',
        'message_body': 'line one\nline two',
      },
      expected: '共享聊天室刪除訊息 · fixturelogin',
    ),
    (
      action: 'ban',
      target: '777',
      query: '777',
      details: <String, dynamic>{
        'user_id': '777',
        'user_name': '',
        'user_login': ' ',
      },
      expected: '封鎖 · 777',
    ),
    (
      action: 'future_action',
      target: '',
      query: 'future_action',
      details: <String, dynamic>{},
      expected: '未識別的管理事件',
    ),
    (
      action: 'warn',
      target: '',
      query: 'warn',
      details: <String, dynamic>{},
      expected: '警告',
    ),
  ]) {
    testWidgets(
      'Log preserves source and incomplete identity: ${scenario.action}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final entry = TwitchModerationLogEntry.parse(
          id: 'fixture-${scenario.action}',
          time: DateTime.utc(2026),
          expectedBroadcasterId: '20',
          event: {
            'broadcaster_user_id': '20',
            'moderator_user_id': '30',
            'action': scenario.action,
            if (scenario.action.startsWith('shared_chat_'))
              'source_broadcaster_user_id': '999',
            if (scenario.details.isNotEmpty) scenario.action: scenario.details,
          },
        )!;
        final controller = _PopulatedController()..testEntries = [entry];
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TwitchModerationLogPanel(
                controller: controller,
                onReconnect: () {},
              ),
            ),
          ),
        );
        final title = find.text(scenario.expected);
        await tester.scrollUntilVisible(
          title,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        expect(title, findsOneWidget);
        if (scenario.target.isNotEmpty) {
          expect(
            find.textContaining('使用者 ID：${entry.targetUserId}'),
            findsOneWidget,
          );
        } else {
          expect(find.textContaining('事件詳細資料未提供。'), findsOneWidget);
        }
        if (entry.isSharedChat) {
          expect(find.textContaining('共享來源頻道：999'), findsOneWidget);
          expect(find.textContaining('line one\nline two'), findsOneWidget);
        }
        if (entry.category == TwitchModerationLogCategory.unknown) {
          expect(find.textContaining('官方動作：future_action'), findsOneWidget);
        }
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, scenario.query);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          title,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        expect(title, findsOneWidget);
        expect(controller.entries.single.id, entry.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'Open log panel isolates controller context changes and stopped callbacks',
    (tester) async {
      final disk = <String, String>{};
      final archive = TwitchModerationLogArchiveStore(
        read: (key) async => disk[key],
        write: (key, raw) async => disk[key] = raw,
      );
      final receivers = <_PanelReceiver>[];
      final controller = TwitchModerationLogController(
        archive: archive,
        receiverFactory: ({required api, required onEntry, required onStatus}) {
          final receiver = _PanelReceiver(
            api: api,
            onEntry: onEntry,
            onStatus: onStatus,
          );
          receivers.add(receiver);
          return receiver;
        },
      );
      final oldApi = _PanelApi('10', '20');
      final nextApi = _PanelApi('11', '21')..gate = Completer<void>();
      addTearDown(() {
        controller.dispose();
        oldApi.client.close();
        nextApi.client.close();
      });
      var initialized = false;
      unawaited(() async {
        await controller.start(oldApi);
        receivers.single.emit('old', 'Old target');
        await controller.flush();
        initialized = true;
      }());
      await _advanceLogPanel(tester);
      expect(initialized, true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchModerationLogPanel(
              controller: controller,
              onReconnect: () {},
            ),
          ),
        ),
      );
      expect(find.text('封鎖 · Old target'), findsOneWidget);
      final old = receivers.single;
      var switched = false;
      unawaited(controller.start(nextApi).then((_) => switched = true));
      await _advanceLogPanel(tester);
      expect(find.text('封鎖 · Old target'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(old.stopped, true);
      old.emit('late', 'Stale target');
      old.onStatus('stale status');
      nextApi.gate!.complete();
      await _advanceLogPanel(tester);
      expect(switched, true);
      expect(controller.ownerId, '11');
      expect(find.text('stale status'), findsNothing);
      receivers.last.emit('new', 'New target');
      await _advanceLogPanel(tester);
      expect(find.text('封鎖 · New target'), findsOneWidget);
      expect(find.text('封鎖 · Stale target'), findsNothing);
      expect(disk['vioclass_twitch_mod_log_v1_10_20'], contains('Old target'));
      expect(
        disk['vioclass_twitch_mod_log_v1_10_20'],
        isNot(contains('Stale target')),
      );
      expect(disk['vioclass_twitch_mod_log_v1_11_21'], contains('New target'));
      controller.stop();
      receivers.last.emit('after-stop', 'Stopped target');
      await _advanceLogPanel(tester);
      expect(find.text('封鎖 · New target'), findsNothing);
      expect(find.text('封鎖 · Stopped target'), findsNothing);
      expect(controller.entries, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Log retry button exposes saving state and preserves error', (
    tester,
  ) async {
    final controller = _PopulatedController()
      ..testUnsaved = 1
      ..storageError = 'fixture storage error';
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchModerationLogPanel(
            controller: controller,
            onReconnect: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('重試保存'));
    expect(controller.retries, 1);
    controller.setSaving(true);
    await tester.pump();
    final saving = find.widgetWithText(TextButton, '正在保存…');
    expect(tester.widget<TextButton>(saving).onPressed, isNull);
    await tester.tap(saving);
    expect(controller.retries, 1);
    expect(find.text('fixture storage error'), findsOneWidget);
    controller.setSaving(false);
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '重試保存'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final scenario in [
    (size: const Size(900, 700), scale: 1.0, keyboard: 0.0),
    (size: const Size(320, 640), scale: 1.5, keyboard: 280.0),
    (size: const Size(844, 290), scale: 1.3, keyboard: 100.0),
  ]) {
    testWidgets('Populated log filtering remains usable at ${scenario.size}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: scenario.keyboard);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = _PopulatedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!,
          ),
          home: Scaffold(
            body: TwitchModerationLogPanel(
              controller: controller,
              onReconnect: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.enterText(search, ' TARGET 10 ');
      await tester.pumpAndSettle();
      final result = find.text('封鎖 · Target 10');
      await tester.scrollUntilVisible(
        result,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      expect(result, findsOneWidget);
      expect(find.textContaining('fixture reason 10'), findsOneWidget);
      final category = find.byType(DropdownButton<TwitchModerationLogCategory>);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(category);
      await tester.pumpAndSettle();
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('聊天室').last);
      await tester.pumpAndSettle();
      expect(find.text('沒有符合條件的本機管理紀錄。'), findsOneWidget);
      await tester.ensureVisible(search);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      final room = find.text('清除聊天室').first;
      await tester.scrollUntilVisible(
        room,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      expect(room, findsOneWidget);
      expect(find.textContaining('封鎖 · Target'), findsNothing);
      await tester.ensureVisible(search);
      await tester.enterText(search, 'no-match');
      await tester.pumpAndSettle();
      expect(find.text('沒有符合條件的本機管理紀錄。'), findsOneWidget);
      expect(controller.entries, hasLength(12));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'Local persistence adapter saves a received entry without token keys',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = TwitchModerationLogArchiveStore.local();
      final entry = TwitchModerationLogEntry.parse(
        id: 'fixture',
        time: DateTime.utc(2026),
        expectedBroadcasterId: '20',
        event: {
          'action': 'clear',
          'broadcaster_user_id': '20',
          'moderator_user_id': '30',
        },
      )!;
      await store.append('10', '20', entry);
      expect(
        (await TwitchModerationLogArchiveStore.local().load(
          '10',
          '20',
        )).single.id,
        'fixture',
      );
      expect((await SharedPreferences.getInstance()).getKeys(), {
        'vioclass_twitch_mod_log_v1_10_20',
      });
    },
  );
  for (final size in [const Size(900, 700), const Size(390, 700)]) {
    testWidgets('Log panel states and reconnect at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TwitchModerationLogController(
        archive: TwitchModerationLogArchiveStore(
          read: (_) async => null,
          write: (_, _) async {},
        ),
      );
      addTearDown(controller.dispose);
      var reconnects = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchModerationLogPanel(
              controller: controller,
              onReconnect: () => reconnects++,
            ),
          ),
        ),
      );
      expect(find.text('沒有符合條件的本機管理紀錄。'), findsOneWidget);
      expect(find.textContaining('斷線期間'), findsOneWidget);
      await tester.tap(find.text('重新連線'));
      expect(reconnects, 1);
      await tester.enterText(find.byType(TextField), 'helper');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
