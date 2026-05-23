import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stage 249 internal app notification type.
///
/// This is intentionally app-local only. It does not use Windows toast,
/// flutter_local_notifications, or platform permissions. Future Drops monitor
/// code can call [twitchAppNotificationCenter] directly.
enum TwitchAppNotificationTypeStage249 {
  info,
  success,
  warning,
  error,
}

@immutable
class TwitchAppNotificationStage249 {
  final int id;
  final String title;
  final String message;
  final TwitchAppNotificationTypeStage249 type;
  final DateTime createdAt;
  final Duration duration;

  const TwitchAppNotificationStage249({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.duration,
  });

  IconData get icon {
    switch (type) {
      case TwitchAppNotificationTypeStage249.success:
        return Icons.check_circle_rounded;
      case TwitchAppNotificationTypeStage249.warning:
        return Icons.warning_amber_rounded;
      case TwitchAppNotificationTypeStage249.error:
        return Icons.error_rounded;
      case TwitchAppNotificationTypeStage249.info:
        return Icons.notifications_active_rounded;
    }
  }

  Color get accentColor {
    switch (type) {
      case TwitchAppNotificationTypeStage249.success:
        return const Color(0xFF5CFFB1);
      case TwitchAppNotificationTypeStage249.warning:
        return const Color(0xFFFFC857);
      case TwitchAppNotificationTypeStage249.error:
        return const Color(0xFFFF5C7A);
      case TwitchAppNotificationTypeStage249.info:
        return const Color(0xFFBF94FF);
    }
  }
}

class TwitchAppNotificationCenterStage249 extends ChangeNotifier {
  static const int maxVisibleNotifications = 3;
  static const Duration defaultDuration = Duration(seconds: 5);

  final List<TwitchAppNotificationStage249> _items =
      <TwitchAppNotificationStage249>[];
  final Map<int, Timer> _dismissTimers = <int, Timer>{};

  int _nextId = 1;

  List<TwitchAppNotificationStage249> get items {
    return List<TwitchAppNotificationStage249>.unmodifiable(_items);
  }

  bool get hasItems => _items.isNotEmpty;

  int show({
    required String title,
    required String message,
    TwitchAppNotificationTypeStage249 type =
        TwitchAppNotificationTypeStage249.info,
    Duration duration = defaultDuration,
  }) {
    final safeTitle = title.trim().isEmpty ? 'VioClass' : title.trim();
    final safeMessage = message.trim();
    final id = _nextId++;

    final item = TwitchAppNotificationStage249(
      id: id,
      title: safeTitle,
      message: safeMessage,
      type: type,
      createdAt: DateTime.now(),
      duration: duration,
    );

    _items.insert(0, item);

    while (_items.length > maxVisibleNotifications) {
      final removed = _items.removeLast();
      _dismissTimers.remove(removed.id)?.cancel();
    }

    if (duration > Duration.zero) {
      _dismissTimers[id] = Timer(duration, () {
        dismiss(id);
      });
    }

    notifyListeners();
    return id;
  }

  int showInfo({
    required String title,
    required String message,
    Duration duration = defaultDuration,
  }) {
    return show(
      title: title,
      message: message,
      type: TwitchAppNotificationTypeStage249.info,
      duration: duration,
    );
  }

  int showSuccess({
    required String title,
    required String message,
    Duration duration = defaultDuration,
  }) {
    return show(
      title: title,
      message: message,
      type: TwitchAppNotificationTypeStage249.success,
      duration: duration,
    );
  }

  int showWarning({
    required String title,
    required String message,
    Duration duration = defaultDuration,
  }) {
    return show(
      title: title,
      message: message,
      type: TwitchAppNotificationTypeStage249.warning,
      duration: duration,
    );
  }

  int showError({
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 8),
  }) {
    return show(
      title: title,
      message: message,
      type: TwitchAppNotificationTypeStage249.error,
      duration: duration,
    );
  }

  void dismiss(int id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    _items.removeAt(index);
    _dismissTimers.remove(id)?.cancel();
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty && _dismissTimers.isEmpty) return;

    _items.clear();
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

final TwitchAppNotificationCenterStage249 twitchAppNotificationCenter =
    TwitchAppNotificationCenterStage249();
