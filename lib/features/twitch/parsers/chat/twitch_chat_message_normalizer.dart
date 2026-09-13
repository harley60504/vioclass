import 'package:flutter/foundation.dart';

import '../../models/chat/twitch_chat_fragment.dart';
import '../../models/chat/twitch_chat_message.dart';
import '../../models/chat/twitch_chat_message_metadata.dart';
import '../../models/chat/twitch_chat_render_segment.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_badge_cache_service.dart';

/// 把不同來源的 ChatMessage 統一成 UI 可吃的 RuntimeMessage。
///
/// 來源可以是：
/// - live IRC
/// - recent raw IRC
/// - recent object / historical object
///
/// 這層開始往 render-ready model 靠攏：
/// badge / fragments / segments / metadata 都先算好，UI 只負責畫。
class TwitchChatMessageNormalizer {
  final TwitchBadgeCacheService badgeCache;

  const TwitchChatMessageNormalizer({required this.badgeCache});

  TwitchChatRuntimeMessage normalize(
    TwitchChatMessage message, {
    required DateTime receivedAt,
  }) {
    final fragments = TwitchChatFragment.buildFromMessage(message);
    final metadata = TwitchChatMessageMetadata.fromMessage(message);
    final segments = TwitchChatRenderSegment.buildFromMessage(
      message,
      fragments,
    );

    final msgId = message.tags['msg-id']?.trim() ?? '';
    final gifsTag = message.tags['gifs']?.trim() ?? '';
    if (msgId == 'gigantified-emote-message' || gifsTag.isNotEmpty) {
      debugPrint(
        '[TwitchChatVisualDebug] '
        'source=${message.source.name} '
        'command=${message.command} '
        'msgId=$msgId '
        'emotes=${message.tags['emotes'] ?? ''} '
        'gifs=$gifsTag '
        'message=${message.message} '
        'fragments=${fragments.map((item) => item.toJson()).toList()} '
        'segments=${segments.map((item) => item.toJson()).toList()}',
      );
    }

    return TwitchChatRuntimeMessage(
      source: message,
      resolvedBadges: badgeCache.resolveBadgeTags(message.tags['badges'] ?? ''),
      receivedAt: receivedAt,
      fragments: fragments,
      segments: segments,
      metadata: metadata,
    );
  }

  DateTime readMessageTimeOrNow(TwitchChatMessage message) {
    final ts = message.tags['tmi-sent-ts'];
    if (ts == null || ts.isEmpty) return DateTime.now();

    final millis = int.tryParse(ts);
    if (millis == null) return DateTime.now();

    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
