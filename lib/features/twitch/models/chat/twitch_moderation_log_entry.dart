enum TwitchModerationLogCategory { user, room, role, raid, automod, unknown }

/// A received channel.moderate v2 event, never a locally submitted command.
class TwitchModerationLogEntry {
  final String id;
  final DateTime time;
  final String broadcasterId;
  final String sourceBroadcasterId;
  final String moderatorId;
  final String moderatorLogin;
  final String moderatorName;
  final String action;
  final Map<String, Object?> details;
  final bool detailsAvailable;

  const TwitchModerationLogEntry._({
    required this.id,
    required this.time,
    required this.broadcasterId,
    required this.sourceBroadcasterId,
    required this.moderatorId,
    required this.moderatorLogin,
    required this.moderatorName,
    required this.action,
    required this.details,
    required this.detailsAvailable,
  });

  static const actions = <String, (TwitchModerationLogCategory, String)>{
    'ban': (TwitchModerationLogCategory.user, '封鎖'),
    'unban': (TwitchModerationLogCategory.user, '解除封鎖'),
    'timeout': (TwitchModerationLogCategory.user, '暫時禁言'),
    'untimeout': (TwitchModerationLogCategory.user, '解除禁言'),
    'delete': (TwitchModerationLogCategory.user, '刪除訊息'),
    'warn': (TwitchModerationLogCategory.user, '警告'),
    'approve_unban_request': (TwitchModerationLogCategory.user, '核准解封申請'),
    'deny_unban_request': (TwitchModerationLogCategory.user, '拒絕解封申請'),
    'shared_chat_ban': (TwitchModerationLogCategory.user, '共享聊天室封鎖'),
    'shared_chat_unban': (TwitchModerationLogCategory.user, '共享聊天室解除封鎖'),
    'shared_chat_timeout': (TwitchModerationLogCategory.user, '共享聊天室暫時禁言'),
    'shared_chat_untimeout': (TwitchModerationLogCategory.user, '共享聊天室解除禁言'),
    'shared_chat_delete': (TwitchModerationLogCategory.user, '共享聊天室刪除訊息'),
    'clear': (TwitchModerationLogCategory.room, '清除聊天室'),
    'emoteonly': (TwitchModerationLogCategory.room, '開啟僅限表情模式'),
    'emoteonlyoff': (TwitchModerationLogCategory.room, '關閉僅限表情模式'),
    'followers': (TwitchModerationLogCategory.room, '開啟追隨者模式'),
    'followersoff': (TwitchModerationLogCategory.room, '關閉追隨者模式'),
    'uniquechat': (TwitchModerationLogCategory.room, '開啟不重複訊息模式'),
    'uniquechatoff': (TwitchModerationLogCategory.room, '關閉不重複訊息模式'),
    'slow': (TwitchModerationLogCategory.room, '開啟慢速模式'),
    'slowoff': (TwitchModerationLogCategory.room, '關閉慢速模式'),
    'subscribers': (TwitchModerationLogCategory.room, '開啟訂閱者模式'),
    'subscribersoff': (TwitchModerationLogCategory.room, '關閉訂閱者模式'),
    'vip': (TwitchModerationLogCategory.role, '授予 VIP'),
    'unvip': (TwitchModerationLogCategory.role, '移除 VIP'),
    'mod': (TwitchModerationLogCategory.role, '授予管理員'),
    'unmod': (TwitchModerationLogCategory.role, '移除管理員'),
    'raid': (TwitchModerationLogCategory.raid, '揪團'),
    'unraid': (TwitchModerationLogCategory.raid, '取消揪團'),
    'add_blocked_term': (TwitchModerationLogCategory.automod, '新增封鎖詞'),
    'remove_blocked_term': (TwitchModerationLogCategory.automod, '移除封鎖詞'),
    'add_permitted_term': (TwitchModerationLogCategory.automod, '新增允許詞'),
    'remove_permitted_term': (TwitchModerationLogCategory.automod, '移除允許詞'),
  };

  TwitchModerationLogCategory get category =>
      actions[action]?.$1 ?? TwitchModerationLogCategory.unknown;
  String get label => actions[action]?.$2 ?? '未識別的管理事件';
  bool get isSharedChat => sourceBroadcasterId != broadcasterId;
  String? get targetUserId => details['user_id'] as String?;

  static String? _string(dynamic value) => value is String ? value : null;

  static String? _detailKey(String action) {
    if (!actions.containsKey(action)) return null;
    if (action.endsWith('_term')) return 'automod_terms';
    if (action.endsWith('_unban_request')) return 'unban_request';
    if (categoryFor(action) != TwitchModerationLogCategory.room ||
        action == 'followers' ||
        action == 'slow') {
      return action;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'time': time.toUtc().toIso8601String(),
    'event': {
      'broadcaster_user_id': broadcasterId,
      'source_broadcaster_user_id': sourceBroadcasterId,
      'moderator_user_id': moderatorId,
      'moderator_user_login': moderatorLogin,
      'moderator_user_name': moderatorName,
      'action': action,
      if (_detailKey(action) != null && detailsAvailable)
        _detailKey(action)!: details,
    },
  };

  static TwitchModerationLogEntry fromJson(
    Map<String, dynamic> json, {
    required String expectedBroadcasterId,
  }) {
    final id = _string(json['id']);
    final time = DateTime.tryParse(_string(json['time']) ?? '');
    final event = json['event'];
    if (id == null || time == null || event is! Map<String, dynamic>) {
      throw const FormatException('Invalid moderation record');
    }
    final entry = parse(
      id: id,
      time: time,
      expectedBroadcasterId: expectedBroadcasterId,
      event: event,
    );
    if (entry == null) {
      throw const FormatException('Invalid moderation identity');
    }
    return entry;
  }

  static TwitchModerationLogEntry? parse({
    required String id,
    required DateTime time,
    required String expectedBroadcasterId,
    required Map<String, dynamic> event,
  }) {
    final broadcaster = _string(event['broadcaster_user_id']);
    final actor = _string(event['moderator_user_id']);
    final action = _string(event['action']);
    if (id.trim().isEmpty ||
        expectedBroadcasterId.isEmpty ||
        broadcaster != expectedBroadcasterId ||
        actor == null ||
        actor.trim().isEmpty ||
        action == null ||
        action.trim().isEmpty) {
      return null;
    }
    final source = _string(event['source_broadcaster_user_id']);
    // Never present a shared-chat action as if it happened locally.
    if (action.startsWith('shared_chat_') &&
        (source == null || source.isEmpty)) {
      return null;
    }
    final key = _detailKey(action);
    final raw = key == null ? null : event[key];
    final details = <String, Object?>{};
    if (raw is Map) {
      // Keep only documented fields; unrelated payloads or credentials are not logs.
      for (final field in const [
        'user_id',
        'user_login',
        'user_name',
        'reason',
        'message_id',
        'message_body',
        'moderator_message',
        'action',
        'list',
      ]) {
        final value = _string(raw[field]);
        if (value != null) details[field] = value;
      }
      for (final field in const [
        'follow_duration_minutes',
        'wait_time_seconds',
        'viewer_count',
      ]) {
        final value = raw[field];
        if (value is int && value >= 0) details[field] = value;
      }
      for (final field in const ['is_approved', 'from_automod']) {
        if (raw[field] is bool) details[field] = raw[field] as bool;
      }
      for (final field in const ['terms', 'chat_rules_cited']) {
        final value = raw[field];
        if (value is List && value.every((item) => item is String)) {
          details[field] = List<String>.unmodifiable(value.cast<String>());
        }
      }
      final expires = _string(raw['expires_at']);
      if (expires != null && DateTime.tryParse(expires) != null) {
        details['expires_at'] = expires;
      }
    }
    return TwitchModerationLogEntry._(
      id: id,
      time: time.toUtc(),
      broadcasterId: broadcaster!,
      sourceBroadcasterId: source == null || source.isEmpty
          ? broadcaster
          : source,
      moderatorId: actor,
      moderatorLogin: _string(event['moderator_user_login']) ?? '',
      moderatorName: _string(event['moderator_user_name']) ?? '',
      action: action,
      details: Map.unmodifiable(details),
      detailsAvailable: key == null ? actions.containsKey(action) : raw is Map,
    );
  }

  static TwitchModerationLogCategory categoryFor(String action) =>
      actions[action]?.$1 ?? TwitchModerationLogCategory.unknown;
}
