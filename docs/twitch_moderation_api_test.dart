// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/moderation/twitch_moderation_api_service.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String owner = '10';
  List<String> scopes = [
    'moderator:manage:chat_settings',
    'moderator:manage:banned_users',
    'moderator:manage:warnings',
  ];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      return ResponseBody.fromString(
        jsonEncode({
          'client_id': 'validated-client',
          'user_id': owner,
          'login': 'fake',
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
      jsonEncode({
        'data': [
          {'slow_mode': true, 'slow_mode_wait_time': 60},
        ],
      }),
      status,
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
  var permission = true;
  setUp(() {
    permission = true;
    adapter = _Adapter();
    final dio = Dio(
      BaseOptions(validateStatus: (status) => status != null && status < 500),
    );
    dio.httpClientAdapter = adapter;
    client = TwitchApiClient(dio: dio);
    api = TwitchModerationApiService(
      client: client,
      tokenProviders: [() async => 'fake-token'],
      broadcasterId: '20',
      moderatorId: '10',
      canModerate: () => permission,
    );
  });
  tearDown(() => client.close());
  test(
    'validated client/account and selected durations form exact room update',
    () async {
      final result = await api.settings(
        changes: {'slow_mode': true, 'slow_mode_wait_time': 60},
      );
      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.headers['Client-ID'], 'validated-client');
      expect(request.queryParameters, {
        'broadcaster_id': '20',
        'moderator_id': '10',
      });
      expect(request.data, {'slow_mode': true, 'slow_mode_wait_time': 60});
      expect(result['slow_mode_wait_time'], 60);
    },
  );
  test(
    'invalid mode values and unmatched duration flags never reach network',
    () async {
      for (final changes in <Map<String, dynamic>>[
        {'slow_mode': true, 'slow_mode_wait_time': 2},
        {'slow_mode': true, 'slow_mode_wait_time': 121},
        {'slow_mode_wait_time': 30},
        {'follower_mode': true, 'follower_mode_duration': -1},
        {'follower_mode': true, 'follower_mode_duration': 129601},
        {
          'non_moderator_chat_delay': true,
          'non_moderator_chat_delay_duration': 3,
        },
        {'emote_mode': 'true'},
        {'unknown': true},
        {},
      ]) {
        await expectLater(
          api.settings(changes: changes),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'warning requires a real target and reason; custom timeout obeys max',
    () async {
      for (final user in ['10', '20', '', 'bad-id']) {
        await expectLater(
          api.warn(user, reason: 'test'),
          throwsA(isA<TwitchModerationException>()),
        );
      }
      await expectLater(
        api.warn('30', reason: ''),
        throwsA(isA<TwitchModerationException>()),
      );
      await expectLater(
        api.warn('30', reason: 'a' * 501),
        throwsA(isA<TwitchModerationException>()),
      );
      await expectLater(
        api.ban('30', seconds: 1209601),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
      await api.warn('30', reason: ' test reason ');
      expect(adapter.requests.single.data, {
        'data': {'user_id': '30', 'reason': 'test reason'},
      });
      expect(adapter.requests.single.uri.path, '/helix/moderation/warnings');
      adapter.requests.clear();
      await api.ban('30', seconds: 1209600, reason: 'test');
      expect(adapter.requests.single.data, {
        'data': {'user_id': '30', 'duration': 1209600, 'reason': 'test'},
      });
    },
  );
  test(
    'wrong account, absent scope, and permission change block external mutation',
    () async {
      adapter.owner = '99';
      await expectLater(
        api.ban('30'),
        throwsA(isA<TwitchModerationException>()),
      );
      adapter.owner = '10';
      adapter.scopes = [];
      await expectLater(
        api.warn('30', reason: 'test'),
        throwsA(isA<TwitchModerationException>()),
      );
      api = TwitchModerationApiService(
        client: client,
        tokenProviders: [
          () async {
            permission = false;
            return 'fake-token';
          },
        ],
        broadcasterId: '20',
        moderatorId: '10',
        canModerate: () => permission,
      );
      adapter.scopes = ['moderator:manage:banned_users'];
      await expectLater(
        api.ban('30'),
        throwsA(isA<TwitchModerationException>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test(
    'conflict and rate limit are distinct failures with no automatic retry',
    () async {
      adapter.status = 409;
      await expectLater(
        api.warn('30', reason: 'test'),
        throwsA(
          isA<TwitchModerationException>().having(
            (error) => error.message,
            'message',
            contains('其他管理員'),
          ),
        ),
      );
      expect(adapter.requests.length, 1);
      adapter.status = 429;
      await expectLater(
        api.ban('30'),
        throwsA(
          isA<TwitchModerationException>().having(
            (error) => error.message,
            'message',
            contains('太頻繁'),
          ),
        ),
      );
      expect(adapter.requests.length, 2);
    },
  );
}
