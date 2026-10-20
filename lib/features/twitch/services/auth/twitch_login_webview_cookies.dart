import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Explicit Android logout also ends the app's shared WebView login session.
/// This does not clear Chrome cookies, WebView storage, or saved app tokens.
Future<void> clearTwitchAndroidLoginCookies({
  Future<bool> Function()? deleteCookies,
}) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  // Android reports whether cookies existed, not whether deletion succeeded.
  // An already empty store may legitimately return false.
  await (deleteCookies ?? CookieManager.instance().deleteAllCookies)();
}
