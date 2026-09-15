import 'dart:async';

import '../../watch/twitch_watch_playback_kind.dart';

class TwitchLiveWatchRecovery {
  TwitchLiveWatchRecovery({
    required this.onPoll,
    this.interval = const Duration(seconds: 8),
  });

  final Future<void> Function() onPoll;
  final Duration interval;

  Timer? _timer;
  bool _polling = false;
  TwitchWatchMode _mode = TwitchWatchMode.recordedWatch;

  TwitchWatchMode get mode => _mode;
  bool get isRunning => _timer != null;

  void setMode(TwitchWatchMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    if (mode == TwitchWatchMode.liveWatch) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_mode != TwitchWatchMode.liveWatch || _timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(interval, (_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (_mode != TwitchWatchMode.liveWatch || _polling) return;
    _polling = true;
    try {
      await onPoll();
    } finally {
      _polling = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
