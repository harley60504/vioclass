// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/models/chat/twitch_automod_settings.dart';
import '../lib/features/twitch/models/chat/twitch_automod_queue.dart';
import '../lib/features/twitch/presentation/sheets/twitch_automod_settings_sheet.dart';

Map<String, int> _levels() => {
  for (final key in TwitchAutomodSettings.categories.keys)
    key: key == 'aggression' ? 2 : 1,
};
TwitchAutomodSettings _settings({int? overall = 2}) =>
    TwitchAutomodSettings(overallLevel: overall, levels: _levels());

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = '10';
  List<String> scopes = [
    'moderator:read:automod_settings',
    'moderator:manage:automod_settings',
  ];
  bool malformed = false;
  String channel = '20';
  void Function()? onSettingsResponse;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object response;
    if (options.uri.path.endsWith('/validate')) {
      response = {
        'user_id': owner,
        'client_id': 'validated-client',
        'login': 'mod',
        'expires_in': 1000,
        'scopes': scopes,
      };
    } else {
      requests.add(options);
      onSettingsResponse?.call();
      response = {
        'data': [
          {
            'broadcaster_id': channel,
            'moderator_id': '10',
            'overall_level': 2,
            ..._levels(),
            if (malformed) 'aggression': 5,
          },
        ],
      };
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Api extends TwitchModerationApiService {
  int reads = 0;
  final writes = <Map<String, int>>[];
  bool failRead = false;
  bool failWrite = false;
  bool changedOnPreflight = false;
  _Api({bool Function()? permission})
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: permission,
      );
  @override
  Future<TwitchAutomodSettings> automodSettings({
    Map<String, int>? changes,
  }) async {
    if (changes != null) {
      writes.add(Map.of(changes));
      if (failWrite) {
        throw const TwitchModerationException('fake unconfirmed result');
      }
      return TwitchAutomodSettings(
        overallLevel: changes['overall_level'],
        levels: changes.containsKey('overall_level') ? _levels() : changes,
      );
    }
    reads++;
    if (failRead) {
      throw const TwitchModerationException('fake read unavailable');
    }
    return _settings(overall: changedOnPreflight && reads > 1 ? 4 : 2);
  }
}

void main() {
  test(
    'settings uses official GET/PUT scope, selected moderator, whole custom body and validated client',
    () async {
      final adapter = _Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      final initial = await api.automodSettings();
      expect(initial.levels['aggression'], 2);
      final custom = {...initial.levels, 'swearing': 3};
      await api.automodSettings(changes: custom);
      await api.automodSettings(changes: {'overall_level': 4});
      expect(adapter.requests.map((r) => r.method), ['GET', 'PUT', 'PUT']);
      expect(
        adapter.requests.first.uri.path,
        '/helix/moderation/automod/settings',
      );
      expect(adapter.requests.first.queryParameters, {
        'broadcaster_id': '20',
        'moderator_id': '10',
      });
      expect(adapter.requests.first.headers['Client-ID'], 'validated-client');
      expect(adapter.requests[1].data, custom);
      expect(adapter.requests.last.data, {'overall_level': 4});
      adapter.scopes = ['moderator:manage:automod_settings'];
      await api.automodSettings();
      client.close();
    },
  );
  test(
    'reject partial custom, mixed mode, out of range, wrong account/scope/channel and malformed response',
    () async {
      final adapter = _Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
      );
      for (final changes in <Map<String, int>>[
        {},
        {'aggression': 3},
        {..._levels(), 'overall_level': 2},
        {'overall_level': -1},
        {..._levels(), 'swearing': 5},
      ]) {
        await expectLater(
          api.automodSettings(changes: changes),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      expect(adapter.requests, isEmpty);
      adapter.owner = '99';
      await expectLater(
        api.automodSettings(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      adapter.scopes = ['moderator:read:automod_settings'];
      await expectLater(
        api.automodSettings(changes: {'overall_level': 2}),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      adapter.channel = 'other';
      await expectLater(
        api.automodSettings(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.channel = '20';
      adapter.malformed = true;
      await expectLater(
        api.automodSettings(),
        throwsA(isA<TwitchModerationException>()),
      );
      client.close();
    },
  );
  test(
    'settings model keeps immutable eight-level snapshot and detects default/category changes',
    () {
      final levels = _levels();
      final settings = TwitchAutomodSettings(overallLevel: 2, levels: levels);
      levels['aggression'] = 4;
      expect(settings.levels['aggression'], 2);
      expect(settings.sameAs(_settings()), true);
      expect(settings.sameAs(_settings(overall: null)), false);
      expect(
        TwitchAutomodSettings.parse({
          'overall_level': 2,
          ..._levels(),
          'swearing': 1.5,
        }),
        isNull,
      );
    },
  );
  test(
    'role changed after accepted PUT is reported submitted, not falsely unsent',
    () async {
      var permitted = true;
      final adapter = _Adapter()..onSettingsResponse = () => permitted = false;
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: () => permitted,
      );
      await expectLater(
        api.automodSettings(changes: {'overall_level': 3}),
        throwsA(
          isA<TwitchModerationException>().having(
            (e) => e.message,
            'message',
            contains('已送出'),
          ),
        ),
      );
      expect(adapter.requests.single.method, 'PUT');
      client.close();
    },
  );
  test(
    'held reason distinguishes blocked links and retains valid official inclusive bounds',
    () {
      final held = TwitchHeldAutomodMessage.parse({
        'message_id': 'id',
        'user_id': '30',
        'message': {'text': '😀中文 https://example.test'},
        'held_at': '2026-10-03T12:00:00Z',
        'reason': 'blocked_link',
        'blocked_term': {
          'terms_found': [
            {
              'boundary': {'start_pos': 4, 'end_pos': 23},
            },
            {
              'boundary': {'start_pos': 4, 'end_pos': 23},
            },
            {
              'boundary': {'start_pos': -1, 'end_pos': 2},
            },
          ],
        },
      });
      expect(held!.reason, '封鎖連結');
      expect(held.boundaries, [(4, 23)]);
      expect(held.text, startsWith('😀中文'));
      final queue = TwitchAutomodQueue('20');
      queue.apply('automod.message.update', {
        'broadcaster_user_id': '20',
        'message_id': 'id',
        'status': 'Approved',
      });
      expect(
        queue.apply('automod.message.hold', {
          'broadcaster_user_id': '20',
          'message_id': 'id',
        }),
        false,
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    _Api api, {
    Size size = const Size(800, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      api.client.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 150),
            ),
            child: TwitchAutomodSettingsPanel(api: api, channelName: 'test'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String value) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('儲存 AutoMod 設定'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('儲存 AutoMod 設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存 AutoMod 設定'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'default confirmation can cancel; confirmed save re-reads and sends only overall',
    (tester) async {
      final api = _Api();
      await mount(tester, api);
      await choose(tester, 'overall_level:2', '3');
      await save(tester);
      expect(find.textContaining('整體等級：3'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      await save(tester);
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(api.writes, [
        {'overall_level': 3},
      ]);
      expect(find.text('AutoMod 設定已更新，以下是官方回傳的等級。'), findsOneWidget);
    },
  );
  testWidgets('custom editor preserves seven unchanged category values', (
    tester,
  ) async {
    final api = _Api();
    await mount(tester, api);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await choose(tester, 'aggression:2', '4');
    await save(tester);
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.writes.single, {..._levels(), 'aggression': 4});
    expect(api.writes.single.containsKey('overall_level'), false);
  });
  testWidgets(
    'changed remote snapshot prevents overwrite, preserves draft and requires explicit reload',
    (tester) async {
      final api = _Api()..changedOnPreflight = true;
      await mount(tester, api);
      await choose(tester, 'overall_level:2', '3');
      await save(tester);
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      expect(find.textContaining('設定已被變更'), findsOneWidget);
      expect(find.byKey(const ValueKey('overall_level:3')), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '儲存 AutoMod 設定'),
      );
      expect(button.onPressed, isNull);
      await tester.ensureVisible(find.text('重新載入官方設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新載入官方設定'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overall_level:4')), findsOneWidget);
    },
  );
  testWidgets(
    'role lost during confirmation prevents write; unknown write result locks resubmission',
    (tester) async {
      var permission = true;
      final api = _Api(permission: () => permission);
      await mount(tester, api);
      await choose(tester, 'overall_level:2', '3');
      await save(tester);
      permission = false;
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      expect(find.textContaining('管理身分或頻道已變更'), findsOneWidget);
      permission = true;
      await tester.tap(find.text('重新載入官方設定'));
      await tester.pumpAndSettle();
      await choose(tester, 'overall_level:2', '3');
      api.failWrite = true;
      await save(tester);
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes.length, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '儲存 AutoMod 設定'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'read failure has no fake zero settings and 320px large-text custom mode scrolls safely',
    (tester) async {
      final api = _Api()..failRead = true;
      await mount(tester, api, size: const Size(320, 640));
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.text('fake read unavailable'), findsOneWidget);
      api.failRead = false;
      await tester.tap(find.text('重新載入官方設定'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('儲存 AutoMod 設定'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('儲存 AutoMod 設定'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
