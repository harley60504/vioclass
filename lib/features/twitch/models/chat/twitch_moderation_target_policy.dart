import 'twitch_chat_runtime_message.dart';
import 'twitch_chat_message.dart';

/// Local eligibility, not a substitute for Twitch's authorization checks.
class TwitchModerationTargetPolicy {
  /// Conservative live-list gate, not an authoritative Twitch role lookup.
  static bool canManageVisibleUser(
    Iterable<TwitchChatRuntimeMessage> messages,
    String userId, {
    required String broadcasterId,
    required String moderatorId,
  }) {
    final matching = messages
        .where(
          (message) =>
              message.source.tags['user-id'] == userId &&
              message.source.isPrivMsg &&
              sameChannel(message, broadcasterId) &&
              message.source.source != TwitchChatMessageSource.synthetic &&
              message.source.source != TwitchChatMessageSource.localEcho,
        )
        .toList();
    return matching.isNotEmpty &&
        matching.every(
          (message) => canManageUser(
            message,
            broadcasterId: broadcasterId,
            moderatorId: moderatorId,
          ),
        );
  }

  static bool sameChannel(TwitchChatRuntimeMessage message, String channelId) {
    final origin =
        message.metadata.sourceRoomId ?? message.source.tags['room-id'];
    return channelId.isNotEmpty && (origin == null || origin == channelId);
  }

  static bool canManageUser(
    TwitchChatRuntimeMessage message, {
    required String broadcasterId,
    required String moderatorId,
    bool? currentModeratorStatus,
  }) {
    final id = message.source.tags['user-id'] ?? '';
    final badges = message.source.tags['badges'] ?? '';
    return sameChannel(message, broadcasterId) &&
        RegExp(r'^\d+$').hasMatch(id) &&
        id != broadcasterId &&
        id != moderatorId &&
        !(broadcasterId == moderatorId && currentModeratorStatus != null
            ? currentModeratorStatus
            : message.metadata.isModerator ||
                  badges
                      .split(',')
                      .any((badge) => badge.startsWith('moderator/'))) &&
        !badges.split(',').any((badge) => badge.startsWith('broadcaster/'));
  }

  static bool canDelete(
    TwitchChatRuntimeMessage message,
    String broadcasterId,
  ) =>
      sameChannel(message, broadcasterId) &&
      message.source.source != TwitchChatMessageSource.localEcho &&
      message.source.source != TwitchChatMessageSource.synthetic &&
      (message.source.tags['id']?.trim().isNotEmpty ?? false) &&
      message.source.tags['user-id'] != broadcasterId &&
      message.source.isPrivMsg;
}
