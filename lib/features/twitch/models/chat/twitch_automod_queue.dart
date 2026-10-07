import '../emotes/twitch_official_emote.dart';

class TwitchAutomodFragment {
  final String text;
  final TwitchOfficialEmote? emote;
  final int? bits;
  final String? cheerPrefix;
  final int? cheerTier;
  const TwitchAutomodFragment(
    this.text, {
    this.emote,
    this.bits,
    this.cheerPrefix,
    this.cheerTier,
  });

  static List<TwitchAutomodFragment> parse(String text, dynamic raw) {
    if (raw is! List || raw.isEmpty) return [TwitchAutomodFragment(text)];
    final parts = <TwitchAutomodFragment>[];
    for (final item in raw) {
      if (item is! Map || item['text'] is! String) {
        return [TwitchAutomodFragment(text)];
      }
      final value = item['text'] as String;
      if (value.isEmpty) continue;
      final metadata = item['emote'];
      final id = metadata is Map ? metadata['id'] : null;
      if (item['type'] == 'emote' &&
          id is String &&
          RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)) {
        parts.add(
          TwitchAutomodFragment(
            value,
            emote: TwitchOfficialEmote(
              id: id,
              name: value,
              imageUrl:
                  'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0',
              emoteType: '',
              tier: '',
              ownerId: '',
              emoteSetId: metadata['emote_set_id'] is String
                  ? metadata['emote_set_id'] as String
                  : '',
              source: TwitchOfficialEmoteSource.channel,
              unlocked: false,
            ),
          ),
        );
      } else {
        final cheer = item['cheermote'];
        final bits = cheer is Map ? cheer['bits'] : null;
        final prefix = cheer is Map ? cheer['prefix'] : null;
        final tier = cheer is Map ? cheer['tier'] : null;
        final valid =
            item['type'] == 'cheermote' &&
            bits is int &&
            bits > 0 &&
            prefix is String &&
            prefix.isNotEmpty &&
            tier is int &&
            tier > 0;
        parts.add(
          TwitchAutomodFragment(
            value,
            bits: valid ? bits : null,
            cheerPrefix: valid ? prefix : null,
            cheerTier: valid ? tier : null,
          ),
        );
      }
    }
    if (parts.map((part) => part.text).join() != text) {
      return [TwitchAutomodFragment(text)];
    }
    return List.unmodifiable(parts);
  }
}

class TwitchHeldAutomodMessage {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final String reason;
  final DateTime heldAt;
  final List<(int, int)> boundaries;
  final List<TwitchAutomodFragment> fragments;
  const TwitchHeldAutomodMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.reason,
    required this.heldAt,
    this.boundaries = const [],
    this.fragments = const [],
  });

  static TwitchHeldAutomodMessage? parse(Map<String, dynamic> event) {
    final id = event['message_id'];
    final user = event['user_id'];
    final message = event['message'];
    final at = DateTime.tryParse(event['held_at']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        user is! String ||
        user.isEmpty ||
        message is! Map ||
        message['text'] is! String ||
        at == null) {
      return null;
    }
    final automod = event['automod'];
    final reason = event['reason'] == 'blocked_link'
        ? '封鎖連結'
        : event['reason'] == 'blocked_term'
        ? '封鎖詞'
        : automod is Map
        ? '${automod['category'] ?? 'AutoMod'} · 等級 ${automod['level'] ?? '未提供'}'
        : 'AutoMod';
    final ranges = <(int, int)>[];
    final blocked = event['blocked_term'];
    final raw = event['reason'] == 'automod' && automod is Map
        ? automod['boundaries']
        : blocked is Map && blocked['terms_found'] is List
        ? (blocked['terms_found'] as List)
              .whereType<Map>()
              .map((term) => term['boundary'])
              .toList()
        : null;
    if (raw is List) {
      for (final boundary in raw.whereType<Map>()) {
        final start = boundary['start_pos'];
        final end = boundary['end_pos'];
        if (start is int && end is int && start >= 0 && end >= start) {
          final range = (start, end);
          if (!ranges.contains(range)) ranges.add(range);
        }
      }
    }
    return TwitchHeldAutomodMessage(
      id: id,
      userId: user,
      userName: (event['user_name'] ?? event['user_login'] ?? user).toString(),
      text: message['text'] as String,
      reason: reason,
      heldAt: at,
      boundaries: List.unmodifiable(ranges),
      fragments: TwitchAutomodFragment.parse(
        message['text'] as String,
        message['fragments'],
      ),
    );
  }
}

/// Per-channel connection snapshot, not an authoritative full queue/history.
/// Resolved IDs are tombstones: late/duplicate hold delivery must not resurrect them.
class TwitchAutomodQueue {
  final String broadcasterId;
  final _held = <String, TwitchHeldAutomodMessage>{};
  final _resolved = <String>{};
  TwitchAutomodQueue(this.broadcasterId);
  List<TwitchHeldAutomodMessage> get messages =>
      List.unmodifiable(_held.values);
  bool contains(String id) => _held.containsKey(id);
  bool apply(String type, Map<String, dynamic> event) {
    if (event['broadcaster_user_id'] != broadcasterId) return false;
    final id = event['message_id'];
    if (id is! String || id.isEmpty) return false;
    if (type == 'automod.message.update') {
      if (!const {
        'approved',
        'denied',
        'expired',
      }.contains(event['status']?.toString().toLowerCase())) {
        return false;
      }
      _resolved.add(id);
      // Bound memory without inventing unseen queue entries.
      if (_resolved.length > 2000) _resolved.remove(_resolved.first);
      return _held.remove(id) != null;
    }
    if (type != 'automod.message.hold' ||
        _resolved.contains(id) ||
        _held.containsKey(id)) {
      return false;
    }
    final row = TwitchHeldAutomodMessage.parse(event);
    if (row == null) return false;
    _held[id] = row;
    return true;
  }

  void clear() {
    _held.clear();
    _resolved.clear();
  }
}
