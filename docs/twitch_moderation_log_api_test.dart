// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';

const _read = [
  'moderator:read:blocked_terms',
  'moderator:read:chat_settings',
  'moderator:read:unban_requests',
  'moderator:read:banned_users',
  'moderator:read:chat_messages',
  'moderator:read:warnings',
  'moderator:read:moderators',
  'moderator:read:vips',
];

class _Adapter implements HttpClientAdapter {
  String owner = '10';
  List<String> scopes = List.of(_read);
  int status = 202;
  void Function()? afterValidation;
  void Function()? afterSubscription;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final validation = options.uri.path.endsWith('/validate');
    if (validation) {
      afterValidation?.call();
    } else {
      requests.add(options);
      afterSubscription?.call();
    }
    return ResponseBody.fromString(
      jsonEncode(
        validation
            ? {
                'user_id': owner,
                'client_id': 'selected-client',
                'login': 'mod',
                'expires_in': 1000,
                'scopes': scopes,
              }
            : {},
      ),
      validation ? 200 : status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late TwitchApiClient client;
  late TwitchModerationApiService api;
  var permitted = true;
  setUp(() {
    permitted = true;
    adapter = _Adapter();
    client = TwitchApiClient(dio: Dio()..httpClientAdapter = adapter);
    api = TwitchModerationApiService(
      client: client,
      tokenProviders: [() async => 'selected-token'],
      broadcasterId: '20',
      moderatorId: '10',
      canModerate: () => permitted,
    );
  });
  tearDown(() => client.close());

  test(
    'moderation log uses all read scopes and exact v2 websocket contract',
    () async {
      final auth = await api.moderationLogSession();
      await api.subscribeModerationLog(auth, 'session-1');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/helix/eventsub/subscriptions');
      expect(request.queryParameters, isEmpty);
      expect(request.data, {
        'type': 'channel.moderate',
        'version': '2',
        'condition': {'broadcaster_user_id': '20', 'moderator_user_id': '10'},
        'transport': {'method': 'websocket', 'session_id': 'session-1'},
      });
      expect(request.headers['Client-ID'], 'selected-client');
      expect(request.headers['Authorization'], 'Bearer selected-token');
    },
  );

  test(
    'each scope group is required; manage alternatives do not replace role reads',
    () async {
      for (final missing in _read) {
        adapter.scopes = _read.where((scope) => scope != missing).toList();
        await expectLater(
          api.moderationLogSession(),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      adapter.scopes = [
        for (final scope in _read.take(6))
          scope.replaceFirst(':read:', ':manage:'),
        ..._read.skip(6),
      ];
      expect(await api.moderationLogSession(), isA<TwitchModerationSession>());
      adapter.scopes = ['moderator:manage:automod'];
      await expectLater(
        api.moderationLogSession(),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'wrong owner and permission changes reject session and late subscription',
    () async {
      adapter.owner = '99';
      await expectLater(
        api.moderationLogSession(),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      adapter.afterValidation = () => permitted = false;
      await expectLater(
        api.moderationLogSession(),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      permitted = true;
      adapter.afterValidation = null;
      final auth = await api.moderationLogSession();
      adapter.afterSubscription = () => permitted = false;
      await expectLater(
        api.subscribeModerationLog(auth, 'session'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests.length, 1);
    },
  );

  test(
    'invalid prevalidated sessions never subscribe; only 202 is accepted',
    () async {
      final auth = await api.moderationLogSession();
      await expectLater(
        api.subscribeModerationLog(auth, ' '),
        throwsA(isA<TwitchModerationException>()),
      );
      final wrong = TwitchModerationSession(
        'token',
        TwitchTokenValidation(
          userId: '99',
          clientId: 'selected-client',
          login: 'other',
          expiresIn: 1000,
          scopes: _read,
        ),
      );
      await expectLater(
        api.subscribeModerationLog(wrong, 'session'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      for (final status in [200, 204, 401, 403]) {
        adapter.status = status;
        await expectLater(
          api.subscribeModerationLog(auth, 'session'),
          throwsA(
            isA<TwitchModerationException>().having(
              (error) => error.terminal,
              'terminal auth failure',
              status == 401 || status == 403,
            ),
          ),
        );
      }
    },
  );
}
