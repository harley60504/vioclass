import 'package:flutter_inappwebview/flutter_inappwebview.dart';

bool isExpectedTwitchLoginNavigationAbort({
  required Uri? uri,
  required WebResourceErrorType type,
  required bool completingLogin,
}) {
  if (type == WebResourceErrorType.CANCELLED) return true;
  if (type != WebResourceErrorType.CONNECTION_ABORTED) return false;
  return completingLogin || (uri?.scheme == 'about' && uri?.path == 'blank');
}
