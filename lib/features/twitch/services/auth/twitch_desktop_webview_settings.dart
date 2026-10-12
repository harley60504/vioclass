import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../api/core/twitch_api_constants.dart';

String? _androidDesktopUserAgent;
Future<void>? _preparingAndroidUserAgent;

/// Keep the actual Chromium/WebKit versions, not an unrelated Chrome 120 UA.
String twitchDesktopUserAgentFromAndroid(String nativeUserAgent) {
  final chrome = RegExp(r'Chrome/([0-9.]+)').firstMatch(nativeUserAgent)?[1];
  final webkit = RegExp(
    r'AppleWebKit/([0-9.]+)',
  ).firstMatch(nativeUserAgent)?[1];
  final safari = RegExp(r'Safari/([0-9.]+)').firstMatch(nativeUserAgent)?[1];
  if (chrome == null || webkit == null || safari == null) {
    throw StateError('Native Android browser identification unavailable');
  }
  return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/$webkit (KHTML, like Gecko) Chrome/$chrome Safari/$safari';
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
/// Keep native desktop UAs; mobile views explicitly request the desktop site.
InAppWebViewSettings twitchDesktopWebViewSettings(
  InAppWebViewSettings settings,
) {
  settings.preferredContentMode = UserPreferredContentMode.DESKTOP;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    settings.userAgent = TwitchApiConstants.browserUserAgent;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Primary login and background verification await preparation before use.
    settings.userAgent =
        _androidDesktopUserAgent ?? TwitchApiConstants.browserUserAgent;
    settings.useWideViewPort = true;
    settings.loadWithOverviewMode = true;
  }
  return settings;
}
