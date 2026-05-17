// PATCH VERSION: twitch_reply_thread_card_stage165
//
// Reply-thread card UI for Twitch chat message context sheet. This owns the
// card shell, relation chips and copy-to-clipboard behavior.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../widgets/chat/twitch_runtime_message_tile.dart';
import 'twitch_reply_thread_builder.dart';

class TwitchReplyThreadMessageCard extends StatelessWidget {
  final TwitchReplyThreadEntry entry;
  final bool selected;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const TwitchReplyThreadMessageCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final depthIndent = (entry.depth * 12.0).clamp(0.0, 42.0).toDouble();

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(left: depthIndent),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => _copyMessage(context, message),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF241B32)
                    : const Color(0xFF1B1B23),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF9146FF).withOpacity(0.62)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReplyThreadCardHeader(
                    entry: entry,
                    selected: selected,
                  ),
                  if (_hasRelation(message)) ...[
                    const SizedBox(height: 7),
                    _RelationLine(message: message),
                  ],
                  const SizedBox(height: 7),
                  TwitchRuntimeMessageTile(
                    message: message,
                    thirdPartyEmotes: thirdPartyEmotes,
                    showTimestamp: false,
                    fontScale: 0.96,
                    compact: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasRelation(TwitchChatRuntimeMessage message) {
    return _replyTargetLogin(message).isNotEmpty ||
        _mentionedLogins(message).isNotEmpty;
  }

  Future<void> _copyMessage(
    BuildContext context,
    TwitchChatRuntimeMessage message,
  ) async {
    await Clipboard.setData(ClipboardData(text: _copyText(message)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製這則聊天室訊息')),
    );
  }

  String _copyText(TwitchChatRuntimeMessage message) {
    final name = formatContextMessageDisplayName(message);
    final body = contextMessagePlainText(message);

    if (name.isEmpty) return body;
    if (body.isEmpty) return name;
    return '$name: $body';
  }
}

class _ReplyThreadCardHeader extends StatelessWidget {
  final TwitchReplyThreadEntry entry;
  final bool selected;

  const _ReplyThreadCardHeader({
    required this.entry,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final message = entry.message;

    return Row(
      children: [
        _EntryKindChip(kind: entry.kind),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            formatContextMessageDisplayName(message),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFE4D4FF)
                  : const Color(0xFFD9C5FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatContextMessageTime(message.receivedAt),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EntryKindChip extends StatelessWidget {
  final TwitchReplyThreadEntryKind kind;

  const _EntryKindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      TwitchReplyThreadEntryKind.ancestor => '上文',
      TwitchReplyThreadEntryKind.selected => '目前',
      TwitchReplyThreadEntryKind.directReply => '回覆',
    };

    final color = switch (kind) {
      TwitchReplyThreadEntryKind.ancestor => Colors.white54,
      TwitchReplyThreadEntryKind.selected => const Color(0xFFBF94FF),
      TwitchReplyThreadEntryKind.directReply => const Color(0xFF57F287),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RelationLine extends StatelessWidget {
  final TwitchChatRuntimeMessage message;

  const _RelationLine({required this.message});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final reply = _replyTargetLogin(message);
    if (reply.isNotEmpty) {
      chips.add(_RelationChip(label: 'reply @${_stripAt(reply)}'));
    }

    for (final login in _mentionedLogins(message)) {
      final text = login.trim();
      if (text.isEmpty) continue;
      chips.add(_RelationChip(label: 'tag @${_stripAt(text)}'));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: chips,
    );
  }
}

class _RelationChip extends StatelessWidget {
  final String label;

  const _RelationChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isReply = label.startsWith('reply');
    final color = isReply ? const Color(0xFFBF94FF) : const Color(0xFF57F287);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String formatContextMessageDisplayName(TwitchChatRuntimeMessage message) {
  final displayName = message.displayName.trim();
  final login = message.userLogin.trim();

  if (displayName.isEmpty) return login;
  if (login.isEmpty || displayName.toLowerCase() == login.toLowerCase()) {
    return displayName;
  }

  return '$displayName ($login)';
}

String contextMessagePlainText(TwitchChatRuntimeMessage message) {
  final text = message.message.trim();
  if (text.isNotEmpty) return text;
  return (message.metadata.systemMessage ?? '').trim();
}

String formatContextMessageTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _stripAt(String value) {
  final text = value.trim();
  return text.startsWith('@') ? text.substring(1) : text;
}

String _replyTargetLogin(TwitchChatRuntimeMessage message) {
  final dynamic reply = message.metadata.replyInfo;
  if (reply == null) return '';

  return _firstNonEmpty([
    () => reply.parentUserLogin,
    () => reply.parentLogin,
    () => reply.parentUserName,
    () => reply.parentDisplayName,
  ]);
}

String _replyTargetDisplayName(TwitchChatRuntimeMessage message) {
  final dynamic reply = message.metadata.replyInfo;
  if (reply == null) return '';

  return _firstNonEmpty([
    () => reply.parentDisplayName,
    () => reply.parentUserLogin,
    () => reply.parentLogin,
    () => reply.parentUserName,
  ]);
}

List<String> _mentionedLogins(TwitchChatRuntimeMessage message) {
  final output = <String>{};
  final text = message.message;
  final regex = RegExp(r'(^|[^A-Za-z0-9_])@([A-Za-z0-9_]{3,25})');

  for (final match in regex.allMatches(text)) {
    final login = match.group(2)?.trim();
    if (login != null && login.isNotEmpty) output.add(login);
  }

  final reply = _replyTargetDisplayName(message).trim().toLowerCase();
  return output
      .where((login) => login.trim().toLowerCase() != reply)
      .toList(growable: false);
}

String _firstNonEmpty(List<Object? Function()> readers) {
  for (final reader in readers) {
    final value = _readDynamicString(reader);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _readDynamicString(Object? Function() reader) {
  try {
    final value = reader();
    return value?.toString().trim() ?? '';
  } catch (_) {
    return '';
  }
}
