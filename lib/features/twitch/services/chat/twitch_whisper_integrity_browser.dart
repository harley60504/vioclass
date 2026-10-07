import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../auth/twitch_webview_environment_disposal.dart';

/// Runs normal Twitch verification in the existing cookie profile, not OAuth
/// authorization or whisper DOM scraping. Always disposes its browser.
Future<void> withTwitchWhisperIntegrityBrowser({
  required String documentStartScript,
  required Future<void> Function(Future<dynamic> Function(String)) capture,
}) async {
  if (!Platform.isWindows && !Platform.isAndroid) {
    throw UnsupportedError(
      'Background private verification supports Windows/Android only.',
    );
  }
  // A desktop_webview_window is visible during native creation, before Dart
  // can hide it. HeadlessInAppWebView creates a non-visible native host instead.
  // Keep the exact existing login profile so changing hosts does not log out.
  final environment = Platform.isWindows
      ? await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder:
                '${Directory.systemTemp.path}${Platform.pathSeparator}'
                'new_twitch_app_shared_twitch_desktop_webview_v30',
          ),
        )
      : null;
  try {
    final controller = Completer<InAppWebViewController>();
    final browser = HeadlessInAppWebView(
      webViewEnvironment: environment,
      initialUrlRequest: URLRequest(url: WebUri('https://www.twitch.tv/')),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: documentStartScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
      ),
      onWebViewCreated: (value) => controller.complete(value),
    );
    try {
      await browser.run();
      final value = await controller.future.timeout(
        const Duration(seconds: 10),
      );
      await capture((script) => value.evaluateJavascript(source: script));
    } finally {
      await browser.dispose();
    }
  } finally {
    if (environment != null) await disposeTwitchWebViewEnvironment(environment);
  }
}
