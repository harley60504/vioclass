// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/api/engagement/twitch_channel_points_api_service.dart';

class _ResponseClient extends TwitchApiClient {
  Object? response;
  int requests = 0;

  @override
  Future<T> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    requests++;
    return response as T;
  }
}

Map<String, dynamic> _contextResponse(Object? points) => {
  'data': {
    'user': {
      'id': '123',
      'channel': {
        'id': '123',
        'self': points == null ? null : {'communityPoints': points},
      },
    },
  },
};

void main() {
  late _ResponseClient client;

  setUp(() => client = _ResponseClient());
  tearDown(() => client.close());

  test('No points authorization means no personal balance request', () async {
    final api = TwitchChannelPointsApiService(
      client: client,
      tokenProvider: () async => null,
    );
    await expectLater(
      api.getContext(channelLogin: 'channel'),
      throwsA(isA<TwitchApiException>()),
    );
    expect(client.requests, 0);
  });

  test('Missing viewer or balance must not become a zero balance', () async {
    final api = TwitchChannelPointsApiService(
      client: client,
      tokenProvider: () async => 'test-web-token',
    );
    for (final points in <Object?>[
      null,
      <String, dynamic>{},
      {'balance': null},
    ]) {
      client.response = _contextResponse(points);
      await expectLater(
        api.getContext(channelLogin: 'channel'),
        throwsA(isA<TwitchApiException>()),
      );
    }
  });

  test('Web authorization can return real balances, including zero', () async {
    final api = TwitchChannelPointsApiService(
      client: client,
      tokenProvider: () async => 'test-web-token',
    );
    for (final balance in [0, 1250]) {
      client.response = _contextResponse({'balance': balance});
      final context = await api.getContext(channelLogin: 'channel');
      expect(context.balance, balance);
    }
  });
}
