import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum TwitchAppNotificationType {
  info,
  success,
  warning,
  error,
}

@immutable
class TwitchAppNotification {
  final int id;
  final String title;
  final String message;
  final TwitchAppNotificationType type;
  final DateTime createdAt;
  final Duration duration;

  const TwitchAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.duration,
  });

  IconData get icon {
    switch (type) {
      case TwitchAppNotificationType.success:
        return Icons.check_circle_rounded;
      case TwitchAppNotificationType.warning:
        return Icons.warning_amber_rounded;
      case TwitchAppNotificationType.error:
        return Icons.error_rounded;
      case TwitchAppNotificationType.info:
        return Icons.notifications_active_rounded;
    }
  }

  Color get accentColor {
    switch (type) {
      case TwitchAppNotificationType.success:
        return const Color(0xFF5CFFB1);
      case TwitchAppNotificationType.warning:
        return const Color(0xFFFFC857);
      case TwitchAppNotificationType.error:
        return const Color(0xFFFF5C7A);
      case TwitchAppNotificationType.info:
        return const Color(0xFFBF94FF);
    }
  }
}

class TwitchAppNotificationCenter extends ChangeNotifier {
  static const int maxVisibleNotifications = 3;
  static const Duration defaultDuration = Duration(seconds: 5);

  final List<TwitchAppNotification> _items = <TwitchAppNotification>[];
  final Map<int, Timer> _dismissTimers = <int, Timer>{};

  int _nextId = 1;

  List<TwitchAppNotification> get items {
    return List<TwitchAppNotification>.unmodifiable(_items);
  }

  bool get hasItems => _items.isNotEmpty;

  int show({
    required String title,
    required String message,
    TwitchAppNotificationType type = TwitchAppNotificationType.info,
    Duration duration = defaultDuration,
  }) {
    final safeTitle = title.trim().isEmpty ? 'VioClass' : title.trim();
    final safeMessage = message.trim();
    final id = _nextId++;

    final item = TwitchAppNotification(
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
      type: TwitchAppNotificationType.info,
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
      type: TwitchAppNotificationType.success,
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
      type: TwitchAppNotificationType.warning,
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
      type: TwitchAppNotificationType.error,
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

final TwitchAppNotificationCenter twitchAppNotificationCenter =
    TwitchAppNotificationCenter();
