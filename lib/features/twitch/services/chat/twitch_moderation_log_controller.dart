import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/moderation/twitch_moderation_api_service.dart';
import '../../models/chat/twitch_moderation_log_entry.dart';
import 'twitch_moderation_log_archive_store.dart';
import 'twitch_moderation_log_eventsub_service.dart';

typedef TwitchModerationLogReceiverFactory =
    TwitchModerationLogEventSubService Function({
      required TwitchModerationApiService api,
      required void Function(TwitchModerationLogEntry) onEntry,
      required void Function(String) onStatus,
    });

TwitchModerationLogEventSubService _createReceiver({
  required TwitchModerationApiService api,
  required void Function(TwitchModerationLogEntry) onEntry,
  required void Function(String) onStatus,
}) => TwitchModerationLogEventSubService(
  api: api,
  onEntry: onEntry,
  onStatus: onStatus,
  onEvent: (_, _, _) {},
);

/// Keeps received logs alive independently of the panel. The watch lifecycle must
/// explicitly start/stop on account, permission or channel changes.
class TwitchModerationLogController extends ChangeNotifier {
  final TwitchModerationLogArchiveStore archive;
  final TwitchModerationLogReceiverFactory createReceiver;
  TwitchModerationLogEventSubService? _receiver;
  TwitchModerationApiService? _api;
  Future<void> _writes = Future<void>.value();
  final _pending = <String, (String, String, TwitchModerationLogEntry)>{};
  List<TwitchModerationLogEntry> _entries = const [];
  int _generation = 0;
  int? _savingGeneration;
  bool _disposed = false;
  bool loading = false;
  String status = '管理紀錄尚未連線。';
  String? storageError;
  String? ownerId;
  String? broadcasterId;

  TwitchModerationLogController({
    required this.archive,
    TwitchModerationLogReceiverFactory? receiverFactory,
  }) : createReceiver = receiverFactory ?? _createReceiver;

  List<TwitchModerationLogEntry> get entries => _entries;
  bool get connected => _receiver?.connected ?? false;
  bool get saving => _savingGeneration == _generation;
  Iterable<(String, String, TwitchModerationLogEntry)> get _activePending =>
      _pending.values.where(
        (value) => value.$1 == ownerId && value.$2 == broadcasterId,
      );
  int get unsavedCount => _activePending.length;
  String _pendingKey(String owner, String channel, String id) =>
      '$owner:$channel:$id';
  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start(TwitchModerationApiService api) async {
    if (_disposed) return;
    stop();
    final generation = _generation;
    _api = api;
    loading = true;
    status = '正在驗證管理紀錄授權…';
    _notify();
    try {
      final session = await api.moderationLogSession();
      if (!_current(generation)) return;
      if (api.canModerate?.call() == false) {
        throw const TwitchModerationException(
          '管理身分或頻道已變更，未連線。',
          terminal: true,
        );
      }
      if (session.validation.userId != api.moderatorId ||
          !RegExp(r'^\d+$').hasMatch(api.moderatorId) ||
          !RegExp(r'^\d+$').hasMatch(api.broadcasterId)) {
        throw const TwitchModerationException(
          '管理紀錄登入身分不符，未連線。',
          terminal: true,
        );
      }
      final saved = await archive.load(api.moderatorId, api.broadcasterId);
      if (!_current(generation)) return;
      if (api.canModerate?.call() == false) {
        throw const TwitchModerationException(
          '管理身分或頻道已變更，未連線。',
          terminal: true,
        );
      }
      ownerId = api.moderatorId;
      broadcasterId = api.broadcasterId;
      _entries = saved;
      _merge(_activePending.map((value) => value.$3));
      if (unsavedCount > 0) {
        storageError = '原帳號／頻道仍有未保存管理紀錄，請重試保存。';
      }
      final receiver = createReceiver(
        api: api,
        onEntry: (entry) => _receive(entry, api, generation),
        onStatus: (value) {
          if (!_current(generation)) return;
          status = value;
          _notify();
        },
      );
      _receiver = receiver;
      loading = false;
      receiver.start();
      _notify();
    } on TwitchModerationLogArchiveException catch (error) {
      if (!_current(generation)) return;
      storageError = error.message;
      status = '管理紀錄保存資料無法讀取，未開始收件；請保留原始資料。';
      loading = false;
      _notify();
    } on TwitchModerationException catch (error) {
      if (!_current(generation)) return;
      status = error.message;
      loading = false;
      _notify();
    } catch (_) {
      if (!_current(generation)) return;
      status = '管理紀錄未能啟動，請重新連線；不代表沒有管理事件。';
      loading = false;
      _notify();
    }
  }

  void _receive(
    TwitchModerationLogEntry entry,
    TwitchModerationApiService api,
    int generation,
  ) {
    if (!_current(generation) ||
        api.canModerate?.call() == false ||
        ownerId != api.moderatorId ||
        entry.broadcasterId != broadcasterId ||
        _entries.any((value) => value.id == entry.id)) {
      return;
    }
    if (_pending.length >= archive.maxEntries) {
      _receiver?.stop();
      status = '未保存管理紀錄已達上限，收件已停止；請重試保存後重新連線，停止期間事件不會補回。';
      _notify();
      return;
    }
    _pending[_pendingKey(api.moderatorId, api.broadcasterId, entry.id)] = (
      api.moderatorId,
      api.broadcasterId,
      entry,
    );
    _merge([entry]);
    _enqueue(entry, api, generation);
    _notify();
  }

  void _merge(Iterable<TwitchModerationLogEntry> values) {
    final byId = {for (final entry in _entries) entry.id: entry};
    for (final entry in values) {
      byId.putIfAbsent(entry.id, () => entry);
    }
    final sorted = byId.values.toList()
      ..sort((a, b) {
        final order = a.time.compareTo(b.time);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    if (sorted.length > archive.maxEntries) {
      sorted.removeRange(0, sorted.length - archive.maxEntries);
    }
    _entries = List.unmodifiable(sorted);
  }

  void _enqueue(
    TwitchModerationLogEntry entry,
    TwitchModerationApiService api,
    int generation,
  ) {
    // Accepted records finish writing to their original account/channel even if
    // the view changes; late completion may never update the new view.
    _writes = _writes.then((_) async {
      try {
        await archive.append(api.moderatorId, api.broadcasterId, entry);
        _pending.remove(
          _pendingKey(api.moderatorId, api.broadcasterId, entry.id),
        );
        if (!_current(generation)) return;
        if (unsavedCount == 0) storageError = null;
        _notify();
      } catch (_) {
        if (!_current(generation)) return;
        storageError = '部分管理紀錄尚未保存，請重試保存；目前畫面不是完整歷史。';
        _notify();
      }
    });
  }

  Future<void> retrySaving() async {
    final api = _api;
    if (_disposed ||
        saving ||
        loading ||
        unsavedCount == 0 ||
        api == null ||
        ownerId != api.moderatorId ||
        broadcasterId != api.broadcasterId) {
      return;
    }
    final generation = _generation;
    _savingGeneration = generation;
    _notify();
    try {
      for (final value in _activePending.toList()) {
        _enqueue(value.$3, api, generation);
      }
      await flush();
    } finally {
      if (_current(generation) && _savingGeneration == generation) {
        _savingGeneration = null;
        _notify();
      }
    }
  }

  Future<void> flush() => _writes;

  void stop() {
    ++_generation;
    _savingGeneration = null;
    _receiver?.stop();
    _receiver = null;
    _api = null;
    loading = false;
    ownerId = null;
    broadcasterId = null;
    _entries = const [];
    storageError = null;
    status = '管理紀錄已停止；離線期間事件不會自動補回。';
    _notify();
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    _pending.clear();
    super.dispose();
  }
}
