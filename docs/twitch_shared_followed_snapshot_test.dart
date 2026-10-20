import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_shared_query_cache.dart';
import 'package:vioclass/features/twitch/services/discovery/twitch_android_followed_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Concurrent consumers and fresh reads share one request; expiry refreshes',
    () async {
      var now = DateTime.utc(2026);
      final cache = TwitchSharedQueryCache<String, int>(now: () => now);
      final gate = Completer<int>();
      var calls = 0;
      Future<int> fetch() {
        calls++;
        return gate.future;
      }

      final a = cache.read('owner', fetch);
      final b = cache.read('owner', fetch);
      expect(identical(a, b), true);
      gate.complete(7);
      expect(await a, 7);
      expect(await cache.read('owner', fetch), 7);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 1));
      expect(
        await cache.read('owner', () async {
          calls++;
          return 8;
        }),
        8,
      );
      expect(calls, 2);
    },
  );

  test(
    'Failures retry and a cleared in-flight result cannot repopulate cache',
    () async {
      final cache = TwitchSharedQueryCache<String, int>();
      await expectLater(
        cache.read('old', () async => throw StateError('fixture')),
        throwsStateError,
      );
      expect(await cache.read('old', () async => 1), 1);
      final gate = Completer<int>();
      final pending = cache.read('pending', () => gate.future);
      cache.clear();
      gate.complete(2);
      expect(await pending, 2);
      expect(await cache.read('pending', () async => 3), 3);
      expect(await cache.read('different-account', () async => 4), 4);
    },
  );

  test(
    'Android snapshot pagination reuses one native query and keeps profile data',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(TwitchAndroidFollowedSnapshot.channel, (
            call,
          ) async {
            calls++;
            expect(call.method, 'followedLiveSnapshot');
            expect(call.arguments, {'owner': '42'});
            return jsonEncode({
              'owner': '42',
              'updatedAt': 123,
              'streams': [
                for (var i = 0; i < 126; i++)
                  {
                    'id': '$i',
                    'user_id': '$i',
                    'user_login': 'channel$i',
                    'profile_image_url': 'https://example.invalid/$i.png',
                    'viewer_count': 126 - i,
                  },
              ],
            });
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              TwitchAndroidFollowedSnapshot.channel,
              null,
            ),
      );
      final snapshot = TwitchAndroidFollowedSnapshot();
      final first = (await snapshot.page(owner: '42', first: 100))!;
      final second = (await snapshot.page(
        owner: '42',
        first: 100,
        after: first.cursor,
      ))!;
      expect(first.streams, hasLength(100));
      expect(second.streams, hasLength(26));
      expect(second.cursor, null);
      expect(
        first.streams.first.profileImageUrl,
        'https://example.invalid/0.png',
      );
      expect(calls, 1);
      await expectLater(
        snapshot.page(owner: 'other', first: 100, after: first.cursor),
        throwsException,
      );
      snapshot.clear();
      await expectLater(
        snapshot.page(owner: '42', first: 100, after: first.cursor),
        throwsException,
      );
    },
  );

  test(
    'Missing native setup falls back, foreign snapshots are rejected',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      String? value;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            TwitchAndroidFollowedSnapshot.channel,
            (_) async => value,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              TwitchAndroidFollowedSnapshot.channel,
              null,
            ),
      );
      final snapshot = TwitchAndroidFollowedSnapshot();
      expect(await snapshot.page(owner: '42', first: 100), null);
      value = jsonEncode({'owner': 'other', 'updatedAt': 1, 'streams': []});
      expect(await snapshot.page(owner: '42', first: 100), null);
    },
  );
}
