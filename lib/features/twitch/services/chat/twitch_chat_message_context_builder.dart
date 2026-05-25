import '../../models/chat/twitch_chat_message_context.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';

class TwitchChatMessageContextBuilder {
  const TwitchChatMessageContextBuilder();

  TwitchChatMessageContextGroup build({
    required TwitchChatRuntimeMessage selectedMessage,
    required List<TwitchChatRuntimeMessage> messages,
  }) {
    final selectedRelations = _relationsFor(selectedMessage);

    // User requested: if there is no tag/reply relation, the sheet should
    // contain only the tapped message, not all messages from the same user.
    if (!selectedRelations.hasRelation) {
      return TwitchChatMessageContextGroup(
        selectedMessage: selectedMessage,
        groupedByMention: false,
        entries: <TwitchChatMessageContextEntry>[
          TwitchChatMessageContextEntry(
            message: selectedMessage,
            mentionedLogins: selectedRelations.mentionedLogins.toList(
              growable: false,
            ),
            replyTargetLogin: selectedRelations.replyTargetLogin,
          ),
        ],
      );
    }

    final indexed = <_MessageRelation>[];
    for (final message in messages) {
      if (!message.hasVisibleContent) continue;
      indexed.add(_relationsFor(message));
    }

    final selectedKey = selectedMessage.id;
    final selectedIndex = indexed.indexWhere(
      (item) => item.message.id == selectedKey,
    );
    if (selectedIndex < 0) {
      return TwitchChatMessageContextGroup(
        selectedMessage: selectedMessage,
        groupedByMention: true,
        entries: <TwitchChatMessageContextEntry>[
          TwitchChatMessageContextEntry(
            message: selectedMessage,
            mentionedLogins: selectedRelations.mentionedLogins.toList(
              growable: false,
            ),
            replyTargetLogin: selectedRelations.replyTargetLogin,
          ),
        ],
      );
    }

    final componentUsers = <String>{...selectedRelations.participants};
    final selectedMessageIds = <String>{selectedKey};

    var changed = true;
    while (changed) {
      changed = false;

      for (final relation in indexed) {
        if (selectedMessageIds.contains(relation.message.id)) continue;
        if (relation.participants.isEmpty) continue;
        if (!_intersects(componentUsers, relation.participants)) continue;

        selectedMessageIds.add(relation.message.id);
        final before = componentUsers.length;
        componentUsers.addAll(relation.participants);
        if (componentUsers.length != before) {
          changed = true;
        }
      }
    }

    final entries = indexed
        .where((relation) => selectedMessageIds.contains(relation.message.id))
        .map(
          (relation) => TwitchChatMessageContextEntry(
            message: relation.message,
            mentionedLogins: relation.mentionedLogins.toList(growable: false),
            replyTargetLogin: relation.replyTargetLogin,
          ),
        )
        .toList(growable: false);

    entries.sort(
      (a, b) => a.message.receivedAt.compareTo(b.message.receivedAt),
    );

    return TwitchChatMessageContextGroup(
      selectedMessage: selectedMessage,
      groupedByMention: true,
      entries: entries,
    );
  }

  _MessageRelation _relationsFor(TwitchChatRuntimeMessage message) {
    final author = _normalizeLogin(message.userLogin);
    final mentioned = _extractMentionedLogins(message.message);
    final replyTarget = _normalizeLogin(
      message.metadata.replyInfo?.parentUserLogin,
    );

    final participants = <String>{};
    if (author != null) participants.add(author);
    participants.addAll(mentioned);
    if (replyTarget != null) participants.add(replyTarget);

    return _MessageRelation(
      message: message,
      participants: participants,
      mentionedLogins: mentioned,
      replyTargetLogin: replyTarget,
    );
  }

  Set<String> _extractMentionedLogins(String text) {
    final result = <String>{};
    final regex = RegExp(r'(^|[\s:，。,.!?])@([A-Za-z0-9_]{2,25})');

    for (final match in regex.allMatches(text)) {
      final login = _normalizeLogin(match.group(2));
      if (login != null) {
        result.add(login);
      }
    }

    return result;
  }

  String? _normalizeLogin(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;

    final normalized = text.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (normalized.length < 2) return null;
    return normalized;
  }

  bool _intersects(Set<String> left, Set<String> right) {
    if (left.length < right.length) {
      return left.any(right.contains);
    }
    return right.any(left.contains);
  }
}

class _MessageRelation {
  final TwitchChatRuntimeMessage message;
  final Set<String> participants;
  final Set<String> mentionedLogins;
  final String? replyTargetLogin;

  const _MessageRelation({
    required this.message,
    required this.participants,
    required this.mentionedLogins,
    required this.replyTargetLogin,
  });

  bool get hasRelation =>
      mentionedLogins.isNotEmpty || replyTargetLogin != null;
}
