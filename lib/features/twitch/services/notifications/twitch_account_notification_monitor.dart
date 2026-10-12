import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/notifications/twitch_account_notification_api.dart';

/// Only IDs are persisted, separately for each validated account. A failed
/// fetch never becomes an empty snapshot or overwrites the last good baseline.
class TwitchAccountNotificationMonitor {
  final Future<List<TwitchAccountNotification>> Function(String ownerId) fetch;
  final Future<void> Function(TwitchAccountNotification item) notify;
  final Duration interval;
  Timer? _timer;
  String? _owner;
  int _generation = 0;
  int? _busyGeneration;
  Future<void> _pendingWrite = Future<void>.value();

  TwitchAccountNotificationMonitor({
    required this.fetch,
    required this.notify,
    this.interval = const Duration(minutes: 5),
  });

  static String storageKey(String ownerId) =>
      'vioclass_account_notification_seen_v1_$ownerId';

  void start(String ownerId) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(ownerId)) {
      stop();
      return;
    }
    if (_owner == ownerId && _timer != null) return;
    stop();
    _owner = ownerId;
    _timer = Timer.periodic(interval, (_) => unawaited(checkNow()));
    unawaited(checkNow());
  }

  void stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _owner = null;
  }

  Future<void> checkNow() async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null || _busyGeneration == generation) return;
    _busyGeneration = generation;
    bool current() => generation == _generation && owner == _owner;
    try {
      final items = await fetch(owner);
      if (!current()) return;
      final prefs = await SharedPreferences.getInstance();
      if (!current()) return;
      final key = storageKey(owner);
      final raw = prefs.getString(key);
      List<String>? previous;
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List && decoded.every((id) => id is String)) {
            previous = decoded.cast<String>();
          }
        } catch (_) {
          // Corrupt baseline: seed quietly instead of replaying old rewards.
        }
      }
      final seen = previous?.toSet() ?? <String>{};
      final fresh = <TwitchAccountNotification>[];
      for (final item in items) {
        if (seen.add(item.id) && previous != null) fresh.add(item);
      }
      final next = <String>{
        ...items.map((item) => item.id),
        ...seen,
      }.take(200).toList();
      final write = _pendingWrite.then((_) async {
        if (!current()) return;
        if (!await prefs.setString(key, jsonEncode(next))) {
          throw StateError('Notification baseline not saved');
        }
      });
      _pendingWrite = write.catchError((Object _) {});
      await write;
      if (!current()) return;
      fresh.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final item in fresh) {
        if (!current()) return;
        await notify(item);
      }
    } catch (error) {
      // Do not log tokens, response bodies, account IDs or private messages.
      debugPrint('Account notification check failed (${error.runtimeType}).');
    } finally {
      if (_busyGeneration == generation) _busyGeneration = null;
    }
  }
}
