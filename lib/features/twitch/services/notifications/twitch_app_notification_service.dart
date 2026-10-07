import 'dart:async';

import 'package:flutter/material.dart';

enum TwitchAppNotificationType { info, success, warning, error }

@immutable
class TwitchWhisperNotificationTarget {
  final String ownerId;
  final String peerId;

  const TwitchWhisperNotificationTarget({
    required this.ownerId,
    required this.peerId,
  });

  String get payload => 'whisper:$ownerId:$peerId';

  static TwitchWhisperNotificationTarget? fromPayload(String? payload) {
    final parts = payload?.split(':');
    if (parts == null || parts.length != 3 || parts.first != 'whisper') {
      return null;
    }
    final numericId = RegExp(r'^[1-9][0-9]*$');
    if (!numericId.hasMatch(parts[1]) ||
        !numericId.hasMatch(parts[2]) ||
        parts[1] == parts[2]) {
      return null;
    }
    return TwitchWhisperNotificationTarget(ownerId: parts[1], peerId: parts[2]);
  }
}

@immutable
class TwitchAppNotification {
  final int id;
  final String title;
  final String message;
  final TwitchAppNotificationType type;
  final DateTime createdAt;
  final Duration duration;
  final TwitchWhisperNotificationTarget? whisperTarget;

  const TwitchAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.duration,
    this.whisperTarget,
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
  static const int maxStoredNotifications = 30;
  static const int maxVisibleNotifications = 1;
  static const Duration defaultDuration = Duration(seconds: 8);

  final List<TwitchAppNotification> _items = <TwitchAppNotification>[];
  final List<int> _visibleToastIds = <int>[];
  final Set<int> _unreadIds = <int>{};
  final Map<int, Timer> _dismissTimers = <int, Timer>{};
  final Map<int, DateTime> _dismissDeadlines = <int, DateTime>{};
  final Map<int, Duration> _pausedDurations = <int, Duration>{};

  int _nextId = 1;
  bool _autoDismissPaused = false;

  List<TwitchAppNotification> get items {
    return List<TwitchAppNotification>.unmodifiable(_items);
  }

  List<TwitchAppNotification> get visibleItems {
    final visible = <TwitchAppNotification>[];
    for (final id in _visibleToastIds) {
      final index = _items.indexWhere((item) => item.id == id);
      if (index >= 0) visible.add(_items[index]);
    }
    return List<TwitchAppNotification>.unmodifiable(visible);
  }

  bool get hasItems => _items.isNotEmpty;
  int get unreadCount => _unreadIds.length;

  int show({
    required String title,
    required String message,
    TwitchAppNotificationType type = TwitchAppNotificationType.info,
    Duration duration = defaultDuration,
    TwitchWhisperNotificationTarget? whisperTarget,
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
      whisperTarget: whisperTarget,
    );

    _items.insert(0, item);
    _unreadIds.add(id);
    _visibleToastIds.insert(0, id);

    while (_items.length > maxStoredNotifications) {
      final removed = _items.removeLast();
      _visibleToastIds.remove(removed.id);
      _unreadIds.remove(removed.id);
      _dismissTimers.remove(removed.id)?.cancel();
      _dismissDeadlines.remove(removed.id);
      _pausedDurations.remove(removed.id);
    }

    while (_visibleToastIds.length > maxVisibleNotifications) {
      final hiddenId = _visibleToastIds.removeLast();
      _dismissTimers.remove(hiddenId)?.cancel();
      _dismissDeadlines.remove(hiddenId);
      _pausedDurations.remove(hiddenId);
    }

    _scheduleDismiss(id, duration);

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
    _visibleToastIds.remove(id);
    _unreadIds.remove(id);
    _dismissTimers.remove(id)?.cancel();
    _dismissDeadlines.remove(id);
    _pausedDurations.remove(id);
    notifyListeners();
  }

  void hideToast(int id) {
    if (!_visibleToastIds.remove(id)) return;

    _dismissTimers.remove(id)?.cancel();
    _dismissDeadlines.remove(id);
    _pausedDurations.remove(id);
    notifyListeners();
  }

  void markAllRead() {
    if (_unreadIds.isEmpty) return;
    _unreadIds.clear();
    notifyListeners();
  }

  void pauseAutoDismiss() {
    if (_autoDismissPaused) return;
    _autoDismissPaused = true;
    final now = DateTime.now();

    for (final entry in _dismissDeadlines.entries.toList(growable: false)) {
      final remaining = entry.value.difference(now);
      _pausedDurations[entry.key] = remaining > Duration.zero
          ? remaining
          : const Duration(milliseconds: 200);
      _dismissTimers.remove(entry.key)?.cancel();
    }
    _dismissDeadlines.clear();
  }

  void resumeAutoDismiss() {
    if (!_autoDismissPaused) return;
    _autoDismissPaused = false;

    for (final entry in _pausedDurations.entries.toList(growable: false)) {
      if (_visibleToastIds.contains(entry.key)) {
        _scheduleDismiss(entry.key, entry.value);
      }
    }
    _pausedDurations.clear();
  }

  void clear() {
    if (_items.isEmpty && _dismissTimers.isEmpty) return;

    _items.clear();
    _visibleToastIds.clear();
    _unreadIds.clear();
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _dismissDeadlines.clear();
    _pausedDurations.clear();
    notifyListeners();
  }

  void _scheduleDismiss(int id, Duration duration) {
    if (duration <= Duration.zero) return;
    if (_autoDismissPaused) {
      _pausedDurations[id] = duration;
      return;
    }

    _dismissTimers.remove(id)?.cancel();
    _dismissDeadlines[id] = DateTime.now().add(duration);
    _dismissTimers[id] = Timer(duration, () => hideToast(id));
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

final TwitchAppNotificationCenter twitchAppNotificationCenter =
    TwitchAppNotificationCenter();
