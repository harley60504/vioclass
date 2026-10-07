// ignore_for_file: avoid_relative_lib_imports
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/twitch/api/chat/twitch_chat_identity_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_client.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 204;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('/validate')) {
      final token = options.headers['Authorization'];
      return ResponseBody.fromString(
        jsonEncode({
          'user_id': token == 'OAuth other' ? 'other-owner' : 'fixture-owner',
          'client_id': 'fixture-client',
          'login': 'fixture',
          'expires_in': 1000,
          'scopes': token == 'OAuth missing'
              ? <String>[]
              : ['user:manage:chat_color'],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    requests.add(options);
    return ResponseBody.fromString(
      status == 204 ? '' : '{}',
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
  late TwitchApiClient client;
  late _Adapter adapter;
  setUp(() {
    adapter = _Adapter();
    client = TwitchApiClient();
    client.dio.httpClientAdapter = adapter;
  });
  tearDown(() => client.close());
  TwitchChatIdentityApiService api(List<String?> tokens) =>
      TwitchChatIdentityApiService(
        client: client,
        tokenProviders: [for (final token in tokens) () async => token],
      );
  test(
    'Color write uses validated owner and client after rejecting unsuitable tokens',
    () async {
      await api([
        null,
        ' ',
        'other',
        'missing',
        'selected',
      ]).updateColor(userId: 'fixture-owner', color: 'blue');
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri.path, '/helix/chat/color');
      expect(request.queryParameters, {
        'user_id': 'fixture-owner',
        'color': 'blue',
      });
      expect(request.headers['Client-ID'], 'fixture-client');
      expect(request.headers['Authorization'], 'Bearer selected');
    },
  );
  test('Missing scope or another owner never sends a color write', () async {
    await expectLater(
      api([
        'other',
        'missing',
      ]).updateColor(userId: 'fixture-owner', color: '#9146FF'),
      throwsA(
        isA<TwitchChatColorException>().having(
          (e) => e.message,
          'message',
          contains('user:manage:chat_color'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
  for (final status in [400, 403]) {
    test(
      'Rejected color write $status is not success or retried through another token',
      () async {
        adapter.status = status;
        await expectLater(
          api([
            'selected',
            'fallback',
          ]).updateColor(userId: 'fixture-owner', color: '#9146FF'),
          throwsA(
            isA<TwitchChatColorException>().having(
              (e) => e.message,
              'message',
              contains(status == 400 ? 'Prime' : '更新失敗'),
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }
}
