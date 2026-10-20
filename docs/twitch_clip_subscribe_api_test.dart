// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/api/clips/twitch_clip_api_service.dart';
import '../lib/features/twitch/api/engagement/twitch_subscribe_api_service_v1.dart';

class _Client extends TwitchApiClient {
  int calls = 0;
  Object response = {
    'data': [
      {'id': 'fixture-clip', 'edit_url': 'https://fixture.invalid/edit'},
    ],
  };
  Object? error;
  Map<String, dynamic>? query;
  Map<String, String>? suppliedHeaders;
  @override
  Future<T> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    calls++;
    query = queryParameters;
    suppliedHeaders = headers;
    expect(Uri.parse(url).path, '/helix/clips');
    if (error != null) throw error!;
    return response as T;
  }
}

class _Subscribe extends TwitchSubscribeApiServiceV1 {
  final opened = <Uri>[];
  @override
  Future<void> openExternalUri(Uri uri) async {
    opened.add(uri);
  }
}

void main() {
  late _Client client;
  String? token;
  late TwitchClipApiService clip;
  setUp(() {
    client = _Client();
    token = 'fixture-token';
    clip = TwitchClipApiService(
      client: client,
      accessTokenProvider: () async => token,
      clientIdProvider: () async => 'fixture-client',
      rawMediaAccessTokenProvider: () async {
        fail('Raw media must not be requested');
      },
      rawMediaClientIdProvider: () async {
        fail('Raw media must not be requested');
      },
    );
  });
  tearDown(() => client.close(force: true));
  for (final missingChannel in [false, true]) {
    test(
      'Clip rejects missing input or login before write channel=$missingChannel',
      () async {
        if (!missingChannel) token = null;
        await expectLater(
          clip.createClip(broadcasterId: missingChannel ? ' ' : '7'),
          throwsA(isA<TwitchApiException>()),
        );
        expect(client.calls, 0);
      },
    );
  }
  test(
    'Clip creation uses one fake authorized write and parses destination',
    () async {
      token = ' fixture-token ';
      final result = await clip.createClip(broadcasterId: ' 7 ');
      expect(client.calls, 1);
      expect(client.query, {'broadcaster_id': '7'});
      expect(client.suppliedHeaders, {
        'Client-ID': 'fixture-client',
        'Authorization': 'Bearer fixture-token',
      });
      expect(result.id, 'fixture-clip');
      expect(result.publicUrl, 'https://clips.twitch.tv/fixture-clip');
    },
  );
  test(
    'Malformed clip responses reject rather than report creation success',
    () async {
      for (final raw in [
        {'data': []},
        {
          'data': [{}],
        },
        {
          'data': [
            {'id': ' '},
          ],
        },
      ]) {
        client.response = raw;
        await expectLater(
          clip.createClip(broadcasterId: '7'),
          throwsA(isA<TwitchApiException>()),
        );
      }
      expect(client.calls, 3);
    },
  );
  test(
    'Clip rejection preserves error and only explicit retry writes again',
    () async {
      final error = StateError('fixture permission rejected');
      client.error = error;
      await expectLater(
        clip.createClip(broadcasterId: '7'),
        throwsA(same(error)),
      );
      expect(client.calls, 1);
      client.error = null;
      expect((await clip.createClip(broadcasterId: '7')).id, 'fixture-clip');
      expect(client.calls, 2);
    },
  );
  test(
    'Subscription destination normalizes login without real browser or payment',
    () async {
      final api = _Subscribe();
      await api.openSubscribePage(' Fixture_Channel ');
      expect(
        api.opened.single,
        Uri.https('www.twitch.tv', '/subs/fixture_channel'),
      );
      expect(
        api.buildChannelUri(' Fixture_Channel '),
        Uri.https('www.twitch.tv', '/fixture_channel'),
      );
    },
  );
  test('Empty subscription channel opens nothing', () async {
    final api = _Subscribe();
    await expectLater(api.openSubscribePage(' '), throwsArgumentError);
    expect(api.opened, isEmpty);
  });
}
