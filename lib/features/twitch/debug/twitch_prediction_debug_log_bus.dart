import 'package:flutter/foundation.dart';

/// Small in-app log buffer for debugging Twitch Prediction realtime updates.
///
/// This is intentionally UI-friendly: widgets can listen to [instance] and show
/// recent Hermes / prediction bus events without relying on terminal output.
class TwitchPredictionDebugLogBus extends ChangeNotifier {
  TwitchPredictionDebugLogBus._();

  static final TwitchPredictionDebugLogBus instance =
      TwitchPredictionDebugLogBus._();

  static const int maxEntries = 80;

  final List<String> _entries = <String>[];

  List<String> get entries => List<String>.unmodifiable(_entries);

  void add(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final line = '$hh:$mm:$ss  $trimmed';

    _entries.add(line);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }

    if (kDebugMode) {
      debugPrint('[PredictionDebug] $line');
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
