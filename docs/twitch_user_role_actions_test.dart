// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_user_role_actions.dart';
import '../lib/features/twitch/presentation/widgets/chat/message/twitch_user_moderation_controls.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_runtime_message.dart';
import '../lib/features/twitch/models/chat/twitch_chat_message_metadata.dart';
import '../lib/features/twitch/models/chat/twitch_moderation_target_policy.dart';

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = '20';
  List<String> scopes = [
    'moderation:read',
    'channel:read:vips',
    'channel:manage:moderators',
    'channel:manage:vips',
  ];
  List<Map<String, dynamic>> rows = [];
  int writeStatus = 204;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      return ResponseBody.fromString(
        jsonEncode({
          'client_id': 'matched-client',
          'user_id': owner,
          'login': 'owner',
          'scopes': scopes,
          'expires_in': 1000,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    requests.add(options);
    return ResponseBody.fromString(
      options.method == 'GET' ? jsonEncode({'data': rows}) : '',
      options.method == 'GET' ? 200 : writeStatus,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeApi extends TwitchModerationApiService {
  bool mod = false;
  bool vip = false;
  bool failMod = false;
  bool failReadAfterWrite = false;
  Map<String, dynamic>? banStatus;
  final writes = <String>[];
  FakeApi(bool Function() permission)
    : super(
        client: TwitchApiClient(),
        tokenProviders: const [],
        broadcasterId: '20',
        moderatorId: '20',
        canModerate: permission,
      );
  @override
  Future<bool> userHasRole(String userId, {required bool vip}) async {
    if ((!vip && failMod) || (failReadAfterWrite && writes.isNotEmpty)) {
      throw const TwitchModerationException('fake missing scope');
    }
    return vip ? this.vip : mod;
  }

  @override
  Future<Map<String, dynamic>?> userBanStatus(String userId) async => banStatus;
  @override
  Future<void> setUserRole(
    String userId, {
    required bool vip,
    required bool enabled,
  }) async {
    writes.add('$userId:$vip:$enabled');
    if (vip) {
      this.vip = enabled;
    } else {
      mod = enabled;
    }
  }
}

void main() {
  TwitchChatRuntimeMessage message({bool historicalMod = false}) {
    final raw = TwitchChatMessage(
      raw: '',
      command: 'PRIVMSG',
      channel: 'channel',
      userLogin: 'peer',
      displayName: 'Peer',
      message: 'fake',
      tags: {
        'id': 'official',
        'room-id': '20',
        'user-id': '30',
        if (historicalMod) 'badges': 'moderator/1',
      },
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

  test(
    'fresh broadcaster role state may override historic MOD badge, not another MOD viewer',
    () {
      expect(
        TwitchModerationTargetPolicy.canManageUser(
          message(historicalMod: true),
          broadcasterId: '20',
          moderatorId: '20',
          currentModeratorStatus: false,
        ),
        true,
      );
      expect(
        TwitchModerationTargetPolicy.canManageUser(
          message(historicalMod: true),
          broadcasterId: '20',
          moderatorId: '10',
          currentModeratorStatus: false,
        ),
        false,
      );
      expect(
        TwitchModerationTargetPolicy.canManageUser(
          message(),
          broadcasterId: '20',
          moderatorId: '20',
          currentModeratorStatus: true,
        ),
        false,
      );
    },
  );
  testWidgets(
    'revoke MOD refreshes user actions despite historical moderator badge',
    (tester) async {
      final api = FakeApi(() => true)..mod = true;
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchUserModerationControls(
              api: api,
              message: message(historicalMod: true),
              channelName: 'channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤銷 MOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('管理這則訊息'));
      await tester.pumpAndSettle();
      expect(find.text('警告'), findsOneWidget);
      expect(api.writes, ['30:false:false']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed role refresh keeps risky user actions locked instead of trusting old non-MOD badge',
    (tester) async {
      final api = FakeApi(() => true)..failReadAfterWrite = true;
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchUserModerationControls(
              api: api,
              message: message(),
              channelName: 'channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('授予 MOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['30:false:true']);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        false,
      );
      expect(find.text('MOD：未確認 · VIP：未確認'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'official role endpoints use matched broadcaster/client and no moderator_id',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '20',
      );
      expect(await api.userHasRole('30', vip: false), false);
      adapter.rows = [
        {'user_id': '30'},
      ];
      expect(await api.userHasRole('30', vip: true), true);
      adapter.rows = [
        {'user_id': '30', 'expires_at': '', 'reason': 'test'},
      ];
      expect((await api.userBanStatus('30'))?['reason'], 'test');
      await api.setUserRole('30', vip: false, enabled: true);
      await api.setUserRole('30', vip: false, enabled: false);
      await api.setUserRole('30', vip: true, enabled: true);
      await api.setUserRole('30', vip: true, enabled: false);
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'GET',
        'GET',
        'POST',
        'DELETE',
        'POST',
        'DELETE',
      ]);
      expect(adapter.requests.map((r) => r.uri.path.split('/').last), [
        'moderators',
        'vips',
        'banned',
        'moderators',
        'moderators',
        'vips',
        'vips',
      ]);
      for (final r in adapter.requests) {
        expect(r.queryParameters, {'broadcaster_id': '20', 'user_id': '30'});
        expect(r.headers['Client-ID'], 'matched-client');
      }
    },
  );
  test(
    'role write needs only its own manage scope; read failure is not fabricated false',
    () async {
      final adapter = Adapter()..scopes = ['channel:manage:moderators'];
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '20',
      );
      await api.setUserRole('30', vip: false, enabled: true);
      expect(adapter.requests.single.method, 'POST');
      expect(await api.userHasRole('30', vip: false), false);
      await expectLater(
        api.userHasRole('30', vip: true),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'MOD viewer, linked wrong owner, self and stale context cannot mutate roles',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      TwitchModerationApiService api(String viewer, {bool current = true}) =>
          TwitchModerationApiService(
            client: client,
            tokenProviders: [() async => 'fake'],
            broadcasterId: '20',
            moderatorId: viewer,
            canModerate: () => current,
          );
      await expectLater(
        api('10').setUserRole('30', vip: true, enabled: true),
        throwsA(isA<TwitchModerationException>()),
      );
      await expectLater(
        api('20').setUserRole('20', vip: true, enabled: true),
        throwsA(isA<TwitchModerationException>()),
      );
      await expectLater(
        api('20', current: false).setUserRole('30', vip: true, enabled: true),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '99';
      await expectLater(
        api('20').setUserRole('30', vip: true, enabled: true),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'conflicting role/VIP capacity errors never trigger automatic removal or retry',
    () async {
      final adapter = Adapter();
      final client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
      addTearDown(client.close);
      final api = TwitchModerationApiService(
        client: client,
        tokenProviders: [() async => 'fake'],
        broadcasterId: '20',
        moderatorId: '20',
      );
      for (final status in [422, 409, 425, 429]) {
        adapter.writeStatus = status;
        await expectLater(
          api.setUserRole('30', vip: true, enabled: true),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      expect(adapter.requests.length, 4);
      expect(adapter.requests.every((r) => r.method == 'POST'), true);
      adapter.rows = [
        {'user_id': '99'},
      ];
      await expectLater(
        api.userHasRole('30', vip: true),
        throwsA(isA<TwitchModerationException>()),
      );
    },
  );
  testWidgets('role read failure stays unknown; cancellation never writes', (
    tester,
  ) async {
    final api = FakeApi(() => true)..failMod = true;
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchUserRoleActions(
            api: api,
            userId: '30',
            userName: 'Peer',
            channelName: 'channel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MOD：未確認 · VIP：否'), findsOneWidget);
    expect(find.text('封鎖／禁言：未封鎖／禁言'), findsOneWidget);
    await tester.tap(find.text('授予 MOD'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@channel\nPeer'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
  });
  testWidgets(
    'confirmed role changes refresh actual response and can be revoked',
    (tester) async {
      final api = FakeApi(() => true);
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchUserRoleActions(
              api: api,
              userId: '30',
              userName: 'Peer',
              channelName: 'channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('授予 VIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['30:true:true']);
      expect(find.text('MOD：否 · VIP：是'), findsOneWidget);
      await tester.tap(find.text('撤銷 VIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['30:true:true', '30:true:false']);
      expect(find.text('MOD：否 · VIP：否'), findsOneWidget);
    },
  );
  testWidgets('role loss during confirmation prevents sending', (tester) async {
    var allowed = true;
    final api = FakeApi(() => allowed);
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TwitchUserRoleActions(
            api: api,
            userId: '30',
            userName: 'Peer',
            channelName: 'channel',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('授予 MOD'));
    await tester.pumpAndSettle();
    allowed = false;
    await tester.tap(find.text('確認'));
    await tester.pumpAndSettle();
    expect(api.writes, isEmpty);
    expect(find.textContaining('未送出操作'), findsOneWidget);
  });
  testWidgets(
    'refresh failure after successful write reports submitted and unknown, not fictional current role',
    (tester) async {
      final api = FakeApi(() => true)..failReadAfterWrite = true;
      addTearDown(api.client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TwitchUserRoleActions(
              api: api,
              userId: '30',
              userName: 'Peer',
              channelName: 'channel',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('授予 MOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確認'));
      await tester.pumpAndSettle();
      expect(api.writes, ['30:false:true']);
      expect(find.text('MOD：未確認 · VIP：未確認'), findsOneWidget);
      expect(find.textContaining('角色操作已提交'), findsOneWidget);
    },
  );
  testWidgets('small phone with larger type keeps role actions within width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeApi(() => true)
      ..banStatus = {'expires_at': '', 'reason': 'test'};
    addTearDown(api.client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TwitchUserRoleActions(
                api: api,
                userId: '30',
                userName: 'Peer',
                channelName: 'channel',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('封鎖／禁言：已封鎖'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '授予 MOD'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
