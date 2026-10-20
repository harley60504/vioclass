// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';
import '../lib/features/twitch/api/core/twitch_api_exception.dart';
import '../lib/features/twitch/api/clips/twitch_clip_api_service.dart';

class _Client extends TwitchApiClient {
  final calls = <String>[];
  final responses = <String, Map<String, dynamic>>{};
  @override
  Future<T> postJson<T>(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final input = data as Map<String, dynamic>;
    final operation = input['operationName'] as String;
    calls.add(operation);
    expect(headers?['Authorization'], 'OAuth fixture-raw-token');
    expect(headers?['Client-ID'], 'fixture-client');
    return responses[operation]! as T;
  }
}

Map<String, dynamic> _response(Map<String, dynamic> data) => {
  'data': data,
  'errors': <Object>[],
};

void main() {
  late _Client client;
  late TwitchClipApiService api;
  String? token;
  setUp(() {
    client = _Client();
    token = 'fixture-raw-token';
    api = TwitchClipApiService(
      client: client,
      accessTokenProvider: () async {
        fail('Editor must use raw-media credentials');
      },
      clientIdProvider: () async {
        fail('Editor must use raw-media credentials');
      },
      rawMediaAccessTokenProvider: () async => token,
      rawMediaClientIdProvider: () async => 'fixture-client',
    );
  });
  tearDown(() => client.close(force: true));
  test(
    'Editor prepares valid raw media even with an empty errors array',
    () async {
      client.responses['CreateRawMedia'] = _response({
        'createRawMedia': {
          'rawMedia': {'id': 'raw-fixture'},
        },
      });
      client.responses['GetRawMedia'] = _response({
        'rawMedia': {
          'status': 'CREATED',
          'assets': [
            {
              'renditions': [
                {
                  'sourceURL': 'https://fixture.invalid/preview',
                  'duration': '30',
                },
              ],
            },
          ],
        },
      });
      final session = await api.beginClipEdit(
        vodId: 'fixture-vod',
        offsetSeconds: 120,
      );
      expect(session.rawMediaId, 'raw-fixture');
      expect(session.durationSeconds, 30);
      expect(session.previewUrl, 'https://fixture.invalid/preview');
      expect(client.calls, ['CreateRawMedia', 'GetRawMedia']);
    },
  );
  test(
    'Editor finalization parses created slug with empty errors array',
    () async {
      client.responses['ClipCreation_CreateClipFromRawMedia'] = _response({
        'createClipFromRawMedia': {
          'clip': {'slug': 'fixture-slug'},
        },
      });
      final result = await api.finalizeClip(
        rawMediaId: 'raw-fixture',
        startSeconds: 1,
        durationSeconds: 10,
        title: 'fixture title',
      );
      expect(result.id, 'fixture-slug');
      expect(client.calls, ['ClipCreation_CreateClipFromRawMedia']);
    },
  );
  test(
    'Render readiness needs both created state and playable source',
    () async {
      for (final value in [
        ('PROCESSING', true, false),
        ('CREATED', false, false),
        ('CREATED', true, true),
      ]) {
        client.responses['ShareClipRenderStatus'] = _response({
          'clip': {
            'assets': [
              {
                'creationState': value.$1,
                'videoQualities': value.$2
                    ? [
                        {'sourceURL': 'https://fixture.invalid/playback'},
                      ]
                    : [],
              },
            ],
          },
        });
        expect(
          (await api.getClipRenderStatus(clipSlug: 'fixture-slug')).ready,
          value.$3,
        );
      }
      expect(client.calls.length, 3);
    },
  );
  test(
    'Editor rejects missing source and missing raw token before requests',
    () async {
      await expectLater(
        api.beginClipEdit(offsetSeconds: 0),
        throwsA(isA<TwitchApiException>()),
      );
      token = null;
      await expectLater(
        api.beginClipEdit(vodId: 'fixture', offsetSeconds: 0),
        throwsA(isA<TwitchApiException>()),
      );
      expect(client.calls, isEmpty);
    },
  );
  test(
    'Nonempty GQL errors reject raw preparation with no automatic write retry',
    () async {
      client.responses['CreateRawMedia'] = {
        'errors': [
          {'message': 'fixture rejection'},
        ],
      };
      await expectLater(
        api.beginClipEdit(vodId: 'fixture', offsetSeconds: 0),
        throwsA(isA<TwitchApiException>()),
      );
      expect(client.calls, ['CreateRawMedia']);
    },
  );
}
