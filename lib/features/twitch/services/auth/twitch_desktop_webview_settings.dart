import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/core/twitch_api_constants.dart';

String? _androidDesktopUserAgent;
Future<void>? _preparingAndroidUserAgent;

/// Keep the actual engine versions while requesting the Android mobile site.
/// The legacy helper name is retained for existing callers.
String twitchDesktopUserAgentFromAndroid(String nativeUserAgent) {
  final chrome = RegExp(r'Chrome/([0-9.]+)').firstMatch(nativeUserAgent)?[1];
  final webkit = RegExp(
    r'AppleWebKit/([0-9.]+)',
  ).firstMatch(nativeUserAgent)?[1];
  final safari = RegExp(r'Safari/([0-9.]+)').firstMatch(nativeUserAgent)?[1];
  if (chrome == null || webkit == null || safari == null) {
    throw StateError('Native Android browser identification unavailable');
  }
  return 'Mozilla/5.0 (Linux; Android 10; K) '
      'AppleWebKit/$webkit (KHTML, like Gecko) '
      'Chrome/$chrome Mobile Safari/$safari';
}

Future<void> prepareTwitchDesktopWebViewSettings({
  Future<String> Function()? userAgentProvider,
}) {
  if (defaultTargetPlatform != TargetPlatform.android ||
      _androidDesktopUserAgent != null) {
    return Future<void>.value();
  }
  return _preparingAndroidUserAgent ??= _prepareAndroidUserAgent(
    userAgentProvider ?? InAppWebViewController.getDefaultUserAgent,
  );
}

Future<void> _prepareAndroidUserAgent(
  Future<String> Function() provider,
) async {
  try {
    _androidDesktopUserAgent = twitchDesktopUserAgentFromAndroid(
      await provider(),
    );
  } finally {
    _preparingAndroidUserAgent = null;
  }
}

String? get twitchAndroidDesktopUserAgent => _androidDesktopUserAgent;

/// Apply before native creation, including the very first OAuth navigation.
/// Android uses the mobile site; other platforms retain their existing settings.
InAppWebViewSettings twitchDesktopWebViewSettings(
  InAppWebViewSettings settings,
) {
  settings.preferredContentMode = UserPreferredContentMode.DESKTOP;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    settings.userAgent = TwitchApiConstants.browserUserAgent;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Primary login and background verification await preparation before use.
    settings.preferredContentMode = UserPreferredContentMode.MOBILE;
    // The login host prepares this before creation. If unavailable, keep the
    // native Android identity rather than falling back to a Windows desktop UA.
    settings.userAgent = _androidDesktopUserAgent;
    settings.useWideViewPort = true;
    settings.loadWithOverviewMode = true;
  }
  return settings;
}
