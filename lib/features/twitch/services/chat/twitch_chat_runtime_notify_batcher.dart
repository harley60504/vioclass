import 'dart:async';

import 'package:flutter/foundation.dart';

/// Small runtime-level notifier batcher for hot Twitch chat streams.
///
/// The runtime can receive many IRC messages per second. Batching visible-chat
/// notifications keeps message append / normalization inside the runtime while
/// reducing how often listeners rebuild. This mirrors Frosty's store-level
/// buffer direction without moving message ownership out of TwitchChatRuntime.
class TwitchChatRuntimeNotifyBatcher {
  final Duration interval;

  Timer? _timer;
  bool _disposed = false;

  TwitchChatRuntimeNotifyBatcher({required this.interval});

  void request(VoidCallback notify) {
    if (_disposed) return;

    if (interval <= Duration.zero) {
      notify();
      return;
    }

    if (_timer?.isActive ?? false) return;

    _timer = Timer(interval, () {
      _timer = null;
      if (_disposed) return;
      notify();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
