// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/twitch/api/core/twitch_api_constants.dart';
import '../lib/features/twitch/services/auth/twitch_desktop_webview_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeAndroidAgent =
      'Mozilla/5.0 (Linux; Android 15; Pixel 9; wv) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
      'Chrome/152.0.7955.12 Mobile Safari/537.36';
  test(
    'Mobile identity retains native engine version without WebView markers',
    () {
      final desktop = twitchDesktopUserAgentFromAndroid(nativeAndroidAgent);
      expect(desktop, contains('Chrome/152.0.7955.12'));
      expect(desktop, contains('AppleWebKit/537.36'));
      expect(desktop, contains('Android'));
      expect(desktop, contains('Mobile'));
      expect(desktop, isNot(contains('Windows')));
      expect(desktop, isNot(contains('; wv')));
      expect(desktop, isNot(contains('Version/4.0')));
      expect(
        () => twitchDesktopUserAgentFromAndroid('unknown'),
        throwsStateError,
      );
    },
  );
  test(
    'Android mobile UA and viewport are set before initial navigation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await prepareTwitchDesktopWebViewSettings(
          userAgentProvider: () async => nativeAndroidAgent,
        );
        final original = InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          useShouldOverrideUrlLoading: true,
          userAgent: 'Android Mobile',
        );
        final settings = twitchDesktopWebViewSettings(original);
        expect(identical(settings, original), isTrue);
        expect(settings.preferredContentMode, UserPreferredContentMode.MOBILE);
        expect(
          settings.userAgent,
          twitchDesktopUserAgentFromAndroid(nativeAndroidAgent),
        );
        expect(settings.userAgent, contains('Mobile'));
        expect(settings.userAgent, contains('Android'));
        expect(settings.useWideViewPort, isTrue);
        expect(settings.loadWithOverviewMode, isTrue);
        expect(settings.javaScriptEnabled, isTrue);
        expect(settings.domStorageEnabled, isTrue);
        expect(settings.databaseEnabled, isTrue);
        expect(settings.useShouldOverrideUrlLoading, isTrue);
        expect(settings.incognito, isNot(true));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'iOS requests desktop site without enabling Android viewport settings',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final settings = twitchDesktopWebViewSettings(InAppWebViewSettings());
        expect(settings.preferredContentMode, UserPreferredContentMode.DESKTOP);
        expect(settings.userAgent, TwitchApiConstants.browserUserAgent);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test('Windows keeps native browser identification and unrelated options', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final settings = twitchDesktopWebViewSettings(
        InAppWebViewSettings(
          userAgent: 'native desktop UA',
          supportMultipleWindows: true,
          sharedCookiesEnabled: true,
        ),
      );
      expect(settings.preferredContentMode, UserPreferredContentMode.DESKTOP);
      expect(settings.userAgent, 'native desktop UA');
      expect(settings.supportMultipleWindows, isTrue);
      expect(settings.sharedCookiesEnabled, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
