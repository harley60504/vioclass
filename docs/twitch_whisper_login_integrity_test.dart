// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../lib/features/twitch/api/auth/twitch_auth_api_service.dart';
import '../lib/features/twitch/api/chat/twitch_whisper_api_service.dart';
import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/services/chat/twitch_whisper_login_integrity_service.dart';

TwitchWhisperSession session({
  String owner = '1',
  String token = 'fixture-web',
  String client = TwitchApiConstants.twitchWebClientId,
}) => TwitchWhisperSession(
  token,
  TwitchTokenValidation(
    clientId: client,
    userId: owner,
    login: 'fixture',
    scopes: const [],
    expiresIn: 3600,
  ),
);

Map<String, Object> result({DateTime? expiry}) => {
  'token': 'fixture-integrity',
  'deviceId': 'fixture_device_123456789',
  'userAgent': 'fixture-native-UA',
  'expiration':
      (expiry ?? DateTime.now().toUtc().add(const Duration(minutes: 5)))
          .millisecondsSinceEpoch,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Late rejection cannot discard newer proof', () async {
    final service = TwitchWhisperLoginIntegrityService();
    await service.captureFromLogin(
      session: session(),
      stillCurrent: () => true,
      evaluate: (_) async => {...result(), 'token': 'new-proof'},
    );
    await service.invalidateRejected(session(), 'old-proof');
    expect(
      (await service.headersFor(session()))['Client-Integrity'],
      'new-proof',
    );
    await service.invalidateRejected(session(), 'new-proof');
    await expectLater(
      service.forSession(session()),
      throwsA(isA<TwitchWhisperException>()),
    );
  });
  test('Concurrent threads/history acquire once, then use cache', () async {
    var calls = 0;
    final gate = Completer<void>();
    final entered = Completer<void>();
    final service = TwitchWhisperLoginIntegrityService(
      browser: ({required documentStartScript, required capture}) async {
        calls++;
        entered.complete();
        await gate.future;
        await capture((_) async => result());
      },
    );
    final requests = List.generate(8, (_) => service.headersFor(session()));
    await entered.future;
    expect(calls, 1);
    gate.complete();
    final headers = await Future.wait(requests);
    expect(
      headers.every((h) => h['Client-Integrity'] == 'fixture-integrity'),
      true,
    );
    await service.headersFor(session());
    expect(calls, 1);
    var restartedCalls = 0;
    final restarted = TwitchWhisperLoginIntegrityService(
      browser: ({required documentStartScript, required capture}) async {
        restartedCalls++;
        throw StateError('Should not create a browser');
      },
    );
    await restarted.headersFor(session());
    expect(restartedCalls, 0);
  });
  for (final lifetime in [
    const Duration(seconds: 10),
    const Duration(seconds: -10),
  ]) {
    test('Restart renews expiring/expired cache: $lifetime', () async {
      final service = TwitchWhisperLoginIntegrityService();
      await service.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        evaluate: (_) async => result(),
      );
      const storage = FlutterSecureStorage();
      final data =
          jsonDecode(
                (await storage.read(
                  key: TwitchWhisperLoginIntegrityService.storageKey,
                ))!,
              )
              as Map;
      data['expiresAt'] = DateTime.now()
          .toUtc()
          .add(lifetime)
          .millisecondsSinceEpoch;
      await storage.write(
        key: TwitchWhisperLoginIntegrityService.storageKey,
        value: jsonEncode(data),
      );
      var calls = 0;
      final restarted = TwitchWhisperLoginIntegrityService(
        browser: ({required documentStartScript, required capture}) async {
          calls++;
          await capture(
            (_) async => {...result(), 'token': 'renewed-integrity'},
          );
        },
      );
      expect(
        (await restarted.headersFor(session()))['Client-Integrity'],
        'renewed-integrity',
      );
      await restarted.headersFor(session());
      expect(calls, 1);
    });
  }
  test(
    'Logout while browser creation waits cannot capture or resurrect cache',
    () async {
      final gate = Completer<void>();
      final entered = Completer<void>();
      var evaluations = 0;
      final service = TwitchWhisperLoginIntegrityService(
        browser: ({required documentStartScript, required capture}) async {
          entered.complete();
          await gate.future;
          await capture((_) async {
            evaluations++;
            return result();
          });
        },
      );
      final pending = service.forSession(session());
      final assertion = expectLater(
        pending,
        throwsA(isA<TwitchWhisperException>()),
      );
      await entered.future;
      service.clear();
      gate.complete();
      await assertion;
      expect(evaluations, 0);
      expect(service.hasValidContextFor('fixture-web'), false);
      expect(
        await const FlutterSecureStorage().read(
          key: TwitchWhisperLoginIntegrityService.storageKey,
        ),
        isNull,
      );
    },
  );
  test('Corrupt cache is replaced, never used as authentication', () async {
    FlutterSecureStorage.setMockInitialValues({
      TwitchWhisperLoginIntegrityService.storageKey: 'broken',
    });
    final service = TwitchWhisperLoginIntegrityService(
      browser: ({required documentStartScript, required capture}) async {
        await capture((_) async => result());
      },
    );
    expect(
      (await service.headersFor(session()))['Client-Integrity'],
      'fixture-integrity',
    );
  });
  test('Failed renewal remains a failure and can subsequently retry', () async {
    var fail = true;
    final service = TwitchWhisperLoginIntegrityService(
      browser: ({required documentStartScript, required capture}) async {
        if (fail) throw StateError('fixture offline');
        await capture((_) async => result());
      },
    );
    await expectLater(
      service.forSession(session()),
      throwsA(isA<TwitchWhisperException>()),
    );
    fail = false;
    await service.forSession(session());
    expect(service.hasValidContextFor('fixture-web'), true);
  });
  test(
    'Restart restores matching unexpired verification without browser',
    () async {
      final first = TwitchWhisperLoginIntegrityService();
      await first.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        evaluate: (_) async => result(),
      );
      final restarted = TwitchWhisperLoginIntegrityService();
      final headers = await restarted.headersFor(session());
      expect(headers['Client-Integrity'], 'fixture-integrity');
      expect(restarted.hasValidContextFor('fixture-web'), true);
      restarted.clear();
      await expectLater(
        TwitchWhisperLoginIntegrityService().forSession(session()),
        throwsA(isA<TwitchWhisperException>()),
      );
    },
  );
  test(
    'Synchronization without login context fails without creating a browser',
    () async {
      final service = TwitchWhisperLoginIntegrityService();
      expect(service.hasValidContextFor('fixture-web'), false);
      await expectLater(
        service.forSession(session()),
        throwsA(isA<TwitchWhisperException>()),
      );
    },
  );

  test(
    'One existing login evaluation supplies all subsequent direct requests',
    () async {
      final service = TwitchWhisperLoginIntegrityService();
      var evaluations = 0;
      await service.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        evaluate: (script) async {
          evaluations++;
          expect(script, contains('window.__vioLoginIntegrity'));
          return jsonEncode(jsonEncode(result()));
        },
      );
      for (var i = 0; i < 10; i++) {
        final headers = await service.headersFor(session());
        expect(headers['Client-Integrity'], 'fixture-integrity');
        expect(headers['User-Agent'], 'fixture-native-UA');
        expect(headers['X-Device-ID'], headers['Device-ID']);
      }
      expect(evaluations, 1);
      expect(service.hasValidContextFor('fixture-web'), true);
      service.clear();
      expect(service.hasValidContextFor('fixture-web'), false);
      await expectLater(
        service.forSession(session()),
        throwsA(isA<TwitchWhisperException>()),
      );
    },
  );

  test(
    'Other owner, client or replaced web token cannot borrow login context',
    () async {
      final service = TwitchWhisperLoginIntegrityService();
      await service.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        evaluate: (_) async => result(),
      );
      for (final other in [
        session(owner: '2'),
        session(client: 'other'),
        session(token: 'replaced'),
      ]) {
        await expectLater(
          service.forSession(other),
          throwsA(isA<TwitchWhisperException>()),
        );
      }
    },
  );

  for (final bad in [
    <String, Object>{'error': 'integrity-http'},
    <String, Object>{'token': 'incomplete'},
    result(expiry: DateTime.utc(2000)),
  ]) {
    test(
      'Invalid or expired login result is rejected: ${bad.containsKey('error')
          ? 'sdk-error'
          : bad.containsKey('expiration')
          ? 'expired'
          : 'format'}',
      () async {
        final service = TwitchWhisperLoginIntegrityService();
        await expectLater(
          service.captureFromLogin(
            session: session(),
            stillCurrent: () => true,
            evaluate: (_) async => bad,
          ),
          throwsA(isA<TwitchWhisperException>()),
        );
        expect(service.hasValidContextFor('fixture-web'), false);
      },
    );
  }

  test(
    'Logout invalidates capture already awaiting the existing login browser',
    () async {
      final service = TwitchWhisperLoginIntegrityService();
      final gate = Completer<Object>();
      final pending = service.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        evaluate: (_) => gate.future,
      );
      final assertion = expectLater(
        pending,
        throwsA(isA<TwitchWhisperException>()),
      );
      service.clear();
      gate.complete(result());
      await assertion;
      expect(service.hasValidContextFor('fixture-web'), false);
    },
  );

  test('Closed login never evaluates or captures a context', () async {
    final service = TwitchWhisperLoginIntegrityService();
    var evaluations = 0;
    await expectLater(
      service.captureFromLogin(
        session: session(),
        stillCurrent: () => false,
        evaluate: (_) async {
          evaluations++;
          return result();
        },
      ),
      throwsA(isA<TwitchWhisperException>()),
    );
    expect(evaluations, 0);
  });

  test('Timeout has no hidden fallback window or persisted result', () async {
    final service = TwitchWhisperLoginIntegrityService();
    await expectLater(
      service.captureFromLogin(
        session: session(),
        stillCurrent: () => true,
        timeout: Duration.zero,
        evaluate: (_) async => null,
      ),
      throwsA(isA<TwitchWhisperException>()),
    );
    expect(service.hasValidContextFor('fixture-web'), false);
  });
}
