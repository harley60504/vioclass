import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

const bool _disableDebugSemantics = bool.fromEnvironment(
  'TWITCH_DISABLE_DEBUG_SEMANTICS',
  defaultValue: true,
);

const bool _filterAxTreeDebugLogs = bool.fromEnvironment(
  'TWITCH_FILTER_AXTREE_LOGS',
  defaultValue: true,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _installDebugLogFilter();

  final app = kDebugMode && _disableDebugSemantics
      ? const ExcludeSemantics(child: VioClassApp())
      : const VioClassApp();

  runApp(app);
}

void _installDebugLogFilter() {
  if (!kDebugMode) return;

  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (_filterAxTreeDebugLogs && _shouldDropDebugLog(message)) {
      return;
    }

    previousDebugPrint(message, wrapWidth: wrapWidth);
  };
}

bool _shouldDropDebugLog(String? message) {
  final text = message ?? '';
  if (text.isEmpty) return false;

  final lower = text.toLowerCase();
  return lower.contains('ui::axtree') ||
      lower.contains('update ui::axtree') ||
      lower.contains('axtree');
}
