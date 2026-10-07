import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat/twitch_moderation_log_entry.dart';

/// Local received events only. One shared instance serializes all read/merge/write
/// operations; persistence is injected, with no dependency on OAuth storage.
class TwitchModerationLogArchiveStore {
  static final _local = TwitchModerationLogArchiveStore(
    read: (key) async => (await SharedPreferences.getInstance()).getString(key),
    write: (key, value) async {
      if (!await (await SharedPreferences.getInstance()).setString(
        key,
        value,
      )) {
        throw const TwitchModerationLogArchiveException('管理紀錄未能保存。');
      }
    },
  );

  /// Share the serialized archive queue across simultaneous watch routes.
  factory TwitchModerationLogArchiveStore.local() => _local;
  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final int maxEntries;
  final int maxBytes;
  Future<void> _queue = Future<void>.value();

  TwitchModerationLogArchiveStore({
    required this.read,
    required this.write,
    this.maxEntries = 500,
    this.maxBytes = 2 * 1024 * 1024,
  }) {
    if (maxEntries < 1 || maxEntries > 5000 || maxBytes < 128) {
      throw ArgumentError('Invalid moderation archive limits');
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _key(String ownerId, String broadcasterId) {
    final numeric = RegExp(r'^\d+$');
    if (!numeric.hasMatch(ownerId) || !numeric.hasMatch(broadcasterId)) {
      throw ArgumentError('Expected Twitch account and channel IDs');
    }
    return 'vioclass_twitch_mod_log_v1_${ownerId}_$broadcasterId';
  }

  Future<List<TwitchModerationLogEntry>> load(
    String ownerId,
    String broadcasterId,
  ) => _serialized(() => _load(ownerId, broadcasterId));

  Future<List<TwitchModerationLogEntry>> _load(
    String ownerId,
    String broadcasterId,
  ) async {
    final raw = await read(_key(ownerId, broadcasterId));
    if (raw == null) return const [];
    try {
      if (utf8.encode(raw).length > maxBytes) {
        throw const FormatException('Oversized moderation archive');
      }
      final json = jsonDecode(raw);
      if (json is! Map ||
          json['version'] != 1 ||
          json['ownerId'] != ownerId ||
          json['broadcasterId'] != broadcasterId ||
          json['entries'] is! List) {
        throw const FormatException('Mismatched moderation archive');
      }
      final values = json['entries'] as List;
      if (values.length > maxEntries) {
        throw const FormatException('Too many moderation records');
      }
      final ids = <String>{};
      final entries = <TwitchModerationLogEntry>[];
      for (final value in values) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid moderation record');
        }
        final entry = TwitchModerationLogEntry.fromJson(
          value,
          expectedBroadcasterId: broadcasterId,
        );
        if (!ids.add(entry.id)) {
          throw const FormatException('Duplicate moderation record');
        }
        entries.add(entry);
      }
      _sort(entries);
      return List.unmodifiable(entries);
    } catch (_) {
      // Append also stops here. Never replace unreadable data with an empty log.
      throw const TwitchModerationLogArchiveException('管理紀錄無法讀取，原始資料已保留。');
    }
  }

  void _sort(List<TwitchModerationLogEntry> entries) => entries.sort((a, b) {
    final order = a.time.compareTo(b.time);
    return order == 0 ? a.id.compareTo(b.id) : order;
  });

  Future<List<TwitchModerationLogEntry>> append(
    String ownerId,
    String broadcasterId,
    TwitchModerationLogEntry entry,
  ) => _serialized(() async {
    final key = _key(ownerId, broadcasterId);
    if (entry.broadcasterId != broadcasterId) {
      throw ArgumentError('Moderation event belongs to another channel');
    }
    final entries = (await _load(ownerId, broadcasterId)).toList();
    // First official copy wins, including handoff/restart duplicate deliveries.
    if (entries.any((value) => value.id == entry.id)) {
      return List<TwitchModerationLogEntry>.unmodifiable(entries);
    }
    String encode(List<TwitchModerationLogEntry> values) => jsonEncode({
      'version': 1,
      'ownerId': ownerId,
      'broadcasterId': broadcasterId,
      'entries': values.map((value) => value.toJson()).toList(),
    });
    if (utf8.encode(encode([entry])).length > maxBytes) {
      throw const TwitchModerationLogArchiveException('單筆管理紀錄超過保存上限，原始資料已保留。');
    }
    entries.add(entry);
    _sort(entries);
    if (entries.length > maxEntries) {
      entries.removeRange(0, entries.length - maxEntries);
    }
    var encoded = encode(entries);
    while (utf8.encode(encoded).length > maxBytes) {
      entries.removeAt(0);
      encoded = encode(entries);
    }
    await write(key, encoded);
    return List<TwitchModerationLogEntry>.unmodifiable(entries);
  });
}

class TwitchModerationLogArchiveException implements Exception {
  final String message;
  const TwitchModerationLogArchiveException(this.message);
  @override
  String toString() => message;
}
