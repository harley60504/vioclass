import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// flutter_inappwebview_windows 0.6.0 creates its Dart disposal channel with
/// the static factory ID instead of the environment ID. Native creation uses
/// environment.id correctly. Retry that exact native channel, not deleteAll.
Future<void> disposeTwitchWebViewEnvironment(
  WebViewEnvironment environment,
) async {
  try {
    await environment.dispose();
  } on MissingPluginException {
    await MethodChannel(
      'com.pichillilorenzo/flutter_webview_environment_${environment.id}',
    ).invokeMethod<void>('dispose', <String, dynamic>{});
  }
}
