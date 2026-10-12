import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/discovery/twitch_live_stream.dart';
import 'twitch_notification_history_store.dart';

enum TwitchAppNotificationType { info, success, warning, error }

enum TwitchAppNotificationCategory {
  general,
  live,
  channelPoints,
  whisper,
  update,
  drops,
  giftSubscription,
  badge,
}

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
  final TwitchAppNotificationCategory category;
  final TwitchLiveStream? liveStream;
  final List<String> avatarUrls;
  final Future<void> Function()? onOpen;
  final String? accountOwnerId;

  const TwitchAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.duration,
    this.whisperTarget,
    this.category = TwitchAppNotificationCategory.general,
    this.liveStream,
    this.avatarUrls = const [],
    this.onOpen,
    this.accountOwnerId,
  });

  IconData get icon {
    if (category == TwitchAppNotificationCategory.live) {
      return Icons.live_tv_rounded;
    }
    if (category == TwitchAppNotificationCategory.channelPoints) {
      return Icons.monetization_on_outlined;
    }
    if (category == TwitchAppNotificationCategory.whisper) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (category == TwitchAppNotificationCategory.update) {
      return Icons.system_update_alt_rounded;
    }
    if (category == TwitchAppNotificationCategory.drops) {
      return Icons.card_giftcard_rounded;
    }
    if (category == TwitchAppNotificationCategory.giftSubscription) {
      return Icons.card_giftcard_rounded;
    }
    if (category == TwitchAppNotificationCategory.badge) {
      return Icons.workspace_premium_outlined;
    }
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
  static const int maxStoredNotifications =
      TwitchNotificationHistoryStore.capacity;
  static const int maxVisibleNotifications = 1;
  static const Duration defaultDuration = Duration(seconds: 5);
  static const Duration liveDuration = Duration(seconds: 8);

  final TwitchNotificationHistoryStore? historyStore;
  TwitchAppNotificationCenter({this.historyStore});
  bool _historyLoaded = false;
  bool _disposed = false;
  int _historyGeneration = 0;
  Future<void>? _historyLoading;
  Future<void> _pendingWrite = Future<void>.value();
  bool _whisperOwnerResolved = false;
  String? _whisperOwner;
  bool _accountOwnerResolved = false;
  String? _accountOwner;

  void retainAccountOwner(String? ownerId) {
    _accountOwnerResolved = true;
    _accountOwner = ownerId;
    _pruneHistory();
    _saveHistory();
    notifyListeners();
  }

  void retainWhisperOwner(String? ownerId) {
    _whisperOwnerResolved = true;
    _whisperOwner = ownerId;
    _pruneHistory();
    _saveHistory();
    notifyListeners();
  }

  Future<void> loadHistory({
    Future<void> Function(TwitchLiveStream)? onLiveOpen,
    Future<void> Function()? onUpdateOpen,
  }) {
    if (_historyLoaded || historyStore == null) return Future<void>.value();
    return _historyLoading ??= _restoreHistory(onLiveOpen, onUpdateOpen);
  }

  Future<void> _restoreHistory(
    Future<void> Function(TwitchLiveStream)? onLiveOpen,
    Future<void> Function()? onUpdateOpen,
  ) async {
    final generation = _historyGeneration;
    final saved = await historyStore!.read();
    if (_disposed) return;
    _historyLoaded = true;
    if (generation == _historyGeneration) {
      for (final entry in saved) {
        try {
          final createdAt = DateTime.parse(entry['createdAt'] as String);
          if (!_withinRetention(createdAt)) continue;
          final category = TwitchAppNotificationCategory.values.byName(
            entry['category'] as String,
          );
          final streamJson = entry['stream'];
          final stream = streamJson is Map
              ? _restoreStream(Map<String, dynamic>.from(streamJson))
              : null;
          final id = _nextId++;
          _items.add(
            TwitchAppNotification(
              id: id,
              title: entry['title'] as String,
              message: entry['message'] as String,
              type: TwitchAppNotificationType.values.byName(
                entry['type'] as String,
              ),
              createdAt: createdAt,
              duration: category == TwitchAppNotificationCategory.live
                  ? liveDuration
                  : defaultDuration,
              category: category,
              accountOwnerId: entry['accountOwnerId'] as String?,
              liveStream: stream,
              avatarUrls:
                  (entry['avatars'] as List?)
                      ?.whereType<String>()
                      .take(3)
                      .toList() ??
                  const [],
              whisperTarget: TwitchWhisperNotificationTarget.fromPayload(
                entry['whisper'] as String?,
              ),
              onOpen: stream != null && onLiveOpen != null
                  ? () => onLiveOpen(stream)
                  : category == TwitchAppNotificationCategory.update
                  ? onUpdateOpen
                  : null,
            ),
          );
          if (entry['unread'] == true) _unreadIds.add(id);
        } catch (_) {
          // A malformed entry must not discard the rest of the history.
        }
      }
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _pruneHistory();
    }
    _saveHistory();
    notifyListeners();
    // Restored records never become toasts or system notifications.
  }

  bool _withinRetention(DateTime date) {
    final now = DateTime.now();
    return !date.isAfter(now) &&
        now.difference(date) < TwitchNotificationHistoryStore.retention;
  }

  void _pruneHistory() {
    final removed = _items
        .where(
          (item) =>
              !_withinRetention(item.createdAt) ||
              (_accountOwnerResolved &&
                  item.accountOwnerId != null &&
                  item.accountOwnerId != _accountOwner) ||
              (_whisperOwnerResolved &&
                  item.whisperTarget != null &&
                  item.whisperTarget!.ownerId != _whisperOwner),
        )
        .map((item) => item.id)
        .toSet();
    if (_items.length > maxStoredNotifications) {
      removed.addAll(
        _items.skip(maxStoredNotifications).map((item) => item.id),
      );
    }
    _items.removeWhere((item) => removed.contains(item.id));
    for (final id in removed) {
      _unreadIds.remove(id);
      _visibleToastIds.remove(id);
      _dismissTimers.remove(id)?.cancel();
      _dismissDeadlines.remove(id);
    }
  }

  void _saveHistory() {
    if (!_historyLoaded || historyStore == null || _disposed) return;
    final snapshot = _items
        .map(
          (item) => <String, dynamic>{
            'title': item.title,
            'message': item.message,
            'type': item.type.name,
            'createdAt': item.createdAt.toIso8601String(),
            'category': item.category.name,
            'accountOwnerId': item.accountOwnerId,
            'stream': item.liveStream?.toJson(),
            'avatars': item.avatarUrls,
            'whisper': item.whisperTarget?.payload,
            'unread': _unreadIds.contains(item.id),
          },
        )
        .toList(growable: false);
    _pendingWrite = _pendingWrite
        .then((_) => historyStore!.write(snapshot))
        .catchError((Object error) {
          debugPrint(
            'Notification history could not be saved (${error.runtimeType}).',
          );
        });
  }

  Future<void> flushHistory() => _pendingWrite;

  static TwitchLiveStream _restoreStream(Map<String, dynamic> value) =>
      TwitchLiveStream(
        id: value['id'] as String,
        userId: value['userId'] as String,
        userLogin: value['userLogin'] as String,
        userName: value['userName'] as String,
        gameId: value['gameId'] as String,
        gameName: value['gameName'] as String,
        title: value['title'] as String,
        viewerCount: value['viewerCount'] as int,
        startedAt: DateTime.tryParse(value['startedAt']?.toString() ?? ''),
        language: value['language'] as String,
        thumbnailUrl: value['thumbnailUrl'] as String,
        tags: (value['tags'] as List).whereType<String>().toList(),
        isMature: value['isMature'] == true,
        profileImageUrl: value['profileImageUrl'] as String,
      );

  final List<TwitchAppNotification> _items = <TwitchAppNotification>[];
  final List<int> _visibleToastIds = <int>[];
  final Set<int> _unreadIds = <int>{};
  final Map<int, Timer> _dismissTimers = <int, Timer>{};
  final Map<int, DateTime> _dismissDeadlines = <int, DateTime>{};

  int _nextId = 1;

  List<TwitchAppNotification> get items {
    _pruneHistory();
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
    TwitchAppNotificationCategory category =
        TwitchAppNotificationCategory.general,
    TwitchLiveStream? liveStream,
    List<String> avatarUrls = const [],
    Future<void> Function()? onOpen,
    String? accountOwnerId,
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
      category: category,
      liveStream: liveStream,
      avatarUrls: List.unmodifiable(avatarUrls.take(3)),
      onOpen: onOpen,
      accountOwnerId: accountOwnerId,
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
    }

    while (_visibleToastIds.length > maxVisibleNotifications) {
      final hiddenId = _visibleToastIds.removeLast();
      _dismissTimers.remove(hiddenId)?.cancel();
      _dismissDeadlines.remove(hiddenId);
    }

    _scheduleDismiss(id, duration);
    _pruneHistory();
    _saveHistory();
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
    Duration duration = defaultDuration,
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
    _saveHistory();
    notifyListeners();
  }

  void hideToast(int id) {
    if (!_visibleToastIds.remove(id)) return;

    _dismissTimers.remove(id)?.cancel();
    _dismissDeadlines.remove(id);
    notifyListeners();
  }

  void markAllRead() {
    if (_unreadIds.isEmpty) return;
    _unreadIds.clear();
    _saveHistory();
    notifyListeners();
  }

  void pauseAutoDismiss() {
    // Toast lifetime is elapsed time, not foreground viewing time. Inactive
    // transitions (including native WebView focus) must not cancel its timer.
  }

  void resumeAutoDismiss() {
    // If the OS suspended the Dart isolate, reconcile absolute deadlines
    // before an expired toast can be displayed again after resume.
    final now = DateTime.now();
    for (final entry in _dismissDeadlines.entries.toList(growable: false)) {
      if (!entry.value.isAfter(now)) hideToast(entry.key);
    }
  }

  void clear() {
    _historyGeneration++;
    if (_items.isEmpty && _dismissTimers.isEmpty) return;

    _items.clear();
    _visibleToastIds.clear();
    _unreadIds.clear();
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _dismissDeadlines.clear();
    _saveHistory();
    notifyListeners();
  }

  void _scheduleDismiss(int id, Duration duration) {
    if (duration <= Duration.zero) return;
    _dismissTimers.remove(id)?.cancel();
    _dismissDeadlines[id] = DateTime.now().add(duration);
    _dismissTimers[id] = Timer(duration, () => hideToast(id));
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }
}

final TwitchAppNotificationCenter twitchAppNotificationCenter =
    TwitchAppNotificationCenter(historyStore: TwitchNotificationHistoryStore());
