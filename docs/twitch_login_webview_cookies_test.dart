// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/services/auth/twitch_login_webview_cookies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android logout awaits WebView cookie deletion', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var deleted = false;
    await clearTwitchAndroidLoginCookies(
      deleteCookies: () async {
        deleted = true;
        return true;
      },
    );
    expect(deleted, isTrue);
  });

  test('An already empty cookie store is a successful logout', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await clearTwitchAndroidLoginCookies(deleteCookies: () async => false);
  });

  test('Cookie deletion exception is not reported as success', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await expectLater(
      clearTwitchAndroidLoginCookies(
        deleteCookies: () async {
          throw StateError('unavailable');
        },
      ),
      throwsStateError,
    );
  });

  test('Other platforms keep their existing browser sessions', () async {
    for (final platform in [TargetPlatform.windows, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await clearTwitchAndroidLoginCookies(
        deleteCookies: () async {
          fail('Must not clear another platform cookie store');
        },
      );
    }
  });
}
