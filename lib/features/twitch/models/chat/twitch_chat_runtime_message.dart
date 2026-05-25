import './twitch_chat_badge.dart';
import './twitch_chat_fragment.dart';
import './twitch_chat_message.dart';
import './twitch_chat_message_metadata.dart';
import './twitch_chat_render_segment.dart';

class TwitchChatRuntimeMessage {
  final TwitchChatMessage source;
  final List<TwitchChatBadge> resolvedBadges;
  final DateTime receivedAt;
  final List<TwitchChatFragment> fragments;
  final List<TwitchChatRenderSegment> segments;
  final TwitchChatMessageMetadata metadata;

  const TwitchChatRuntimeMessage({
    required this.source,
    required this.resolvedBadges,
    required this.receivedAt,
    required this.fragments,
    required this.segments,
    required this.metadata,
  });

  String get id {
    return source.tags['id'] ??
        '${source.source.name}-${source.userLogin}-${receivedAt.microsecondsSinceEpoch}';
  }

  String get userLogin => source.userLogin;
  String get displayName => source.displayName;
  String get message => source.message;
  String get color => source.tags['color'] ?? '';
  String get channel => source.channel;

  bool get isActionMessage => metadata.isAction;
  bool get hasVisibleContent =>
      message.trim().isNotEmpty || segments.isNotEmpty || metadata.isSystemLike;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userLogin': userLogin,
      'displayName': displayName,
      'message': message,
      'color': color,
      'channel': channel,
      'isActionMessage': isActionMessage,
      'hasVisibleContent': hasVisibleContent,
      'receivedAt': receivedAt.toIso8601String(),
      'resolvedBadges': resolvedBadges.map((badge) => badge.toJson()).toList(),
      'fragments': fragments.map((fragment) => fragment.toJson()).toList(),
      'segments': segments.map((segment) => segment.toJson()).toList(),
      'metadata': metadata.toJson(),
      'source': source.toJson(),
    };
  }
}
