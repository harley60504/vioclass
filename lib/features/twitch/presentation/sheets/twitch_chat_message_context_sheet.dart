// PATCH VERSION: chat_message_context_sheet_reply_thread_only_v63
// Place at: lib/features/twitch/presentation/sheets/twitch_chat_message_context_sheet.dart
//
// Stage 103:
// - Match Twitch official behavior more closely: reply metadata forms the
//   context thread; @mentions are displayed only as tags and no longer cause
//   message aggregation.
// - Display parent chain + selected message + direct replies to the selected
//   message. Sibling replies are not shown when opening a child reply.
// - Keep the clean original sheet style and keep Twitch / third-party emote
//   rendering in the message body.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/chat/twitch_chat_render_segment.dart';
import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../models/emotes/twitch_third_party_emote.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';

Future<void> showTwitchChatMessageContextSheet({
  required BuildContext context,
  required TwitchChatRuntimeMessage selectedMessage,
  required List<TwitchChatRuntimeMessage> messages,
  TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
}) {
  final entries = _ReplyThreadBuilder.build(
    selectedMessage: selectedMessage,
    messages: messages,
  );

  return showTwitchUnifiedSheet<void>(
    context: context,
    title: '回覆串 · ${entries.length}',
    subtitle: '依 reply 關係顯示；@tag 只標記，不聚集',
    icon: Icons.reply_rounded,
    size: TwitchUnifiedSheetSize.medium,
    showRefresh: false,
    builder: (_) => _TwitchChatMessageContextSheet(
      selectedMessage: selectedMessage,
      entries: entries,
      thirdPartyEmotes: thirdPartyEmotes,
    ),
  );
}

enum _ReplyThreadEntryKind {
  ancestor,
  selected,
  directReply,
}

class _ReplyThreadEntry {
  final TwitchChatRuntimeMessage message;
  final _ReplyThreadEntryKind kind;
  final int depth;

  const _ReplyThreadEntry({
    required this.message,
    required this.kind,
    required this.depth,
  });
}

class _ReplyThreadBuilder {
  const _ReplyThreadBuilder._();

  static const int _maxParentDepth = 6;
  static const int _maxDirectReplies = 8;
  static const int _maxTotalRows = 12;

  static List<_ReplyThreadEntry> build({
    required TwitchChatRuntimeMessage selectedMessage,
    required List<TwitchChatRuntimeMessage> messages,
  }) {
    final sourceMessages = _mergeSelectedMessage(
      selectedMessage: selectedMessage,
      messages: messages,
    );

    final messagesById = <String, TwitchChatRuntimeMessage>{};
    for (final message in sourceMessages) {
      final id = _messageId(message);
      if (id.isNotEmpty) messagesById[id] = message;
    }

    final parentChain = <TwitchChatRuntimeMessage>[];
    final seenParentKeys = <String>{_messageIdentityKey(selectedMessage)};
    var cursor = selectedMessage;

    for (var depth = 0; depth < _maxParentDepth; depth++) {
      final parent = _findParentMessage(
        message: cursor,
        messages: sourceMessages,
        messagesById: messagesById,
      );

      if (parent == null) break;

      final key = _messageIdentityKey(parent);
      if (!seenParentKeys.add(key)) break;

      parentChain.insert(0, parent);
      cursor = parent;
    }

    final selectedKey = _messageIdentityKey(selectedMessage);
    final parentKeys = parentChain.map(_messageIdentityKey).toSet();

    final directReplies = sourceMessages.where((candidate) {
      final candidateKey = _messageIdentityKey(candidate);
      if (candidateKey == selectedKey || parentKeys.contains(candidateKey)) {
        return false;
      }
      return _isDirectReplyTo(candidate: candidate, target: selectedMessage);
    }).toList(growable: false)
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    final entries = <_ReplyThreadEntry>[
      for (var i = 0; i < parentChain.length; i++)
        _ReplyThreadEntry(
          message: parentChain[i],
          kind: _ReplyThreadEntryKind.ancestor,
          depth: i,
        ),
      _ReplyThreadEntry(
        message: selectedMessage,
        kind: _ReplyThreadEntryKind.selected,
        depth: parentChain.length,
      ),
      for (final reply in directReplies.take(_maxDirectReplies))
        _ReplyThreadEntry(
          message: reply,
          kind: _ReplyThreadEntryKind.directReply,
          depth: parentChain.length + 1,
        ),
    ];

    if (entries.length <= _maxTotalRows) {
      return List<_ReplyThreadEntry>.unmodifiable(entries);
    }

    return List<_ReplyThreadEntry>.unmodifiable(entries.take(_maxTotalRows));
  }

  static List<TwitchChatRuntimeMessage> _mergeSelectedMessage({
    required TwitchChatRuntimeMessage selectedMessage,
    required List<TwitchChatRuntimeMessage> messages,
  }) {
    final output = <TwitchChatRuntimeMessage>[];
    final seenKeys = <String>{};

    void add(TwitchChatRuntimeMessage message) {
      final key = _messageIdentityKey(message);
      if (!seenKeys.add(key)) return;
      output.add(message);
    }

    for (final message in messages) {
      add(message);
    }
    add(selectedMessage);

    output.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
    return output;
  }

  static TwitchChatRuntimeMessage? _findParentMessage({
    required TwitchChatRuntimeMessage message,
    required List<TwitchChatRuntimeMessage> messages,
    required Map<String, TwitchChatRuntimeMessage> messagesById,
  }) {
    final parentId = _replyParentMessageId(message);
    if (parentId.isNotEmpty) {
      final byId = messagesById[parentId];
      if (byId != null) return byId;
    }

    final parentLogin = _normalizeLogin(_replyParentLogin(message));
    final parentBody = _normalizeBody(_replyParentBody(message));

    if (parentLogin.isEmpty && parentBody.isEmpty) return null;

    for (final candidate in messages.reversed) {
      if (_messageIdentityKey(candidate) == _messageIdentityKey(message)) continue;
      if (candidate.receivedAt.isAfter(message.receivedAt)) continue;

      final candidateLogin = _normalizeLogin(candidate.userLogin);
      final candidateDisplayName = _normalizeLogin(candidate.displayName);
      final candidateBody = _normalizeBody(_messagePlainText(candidate));

      final loginMatches = parentLogin.isEmpty ||
          parentLogin == candidateLogin ||
          parentLogin == candidateDisplayName;
      final bodyMatches = parentBody.isEmpty || parentBody == candidateBody;

      if (loginMatches && bodyMatches) {
        return candidate;
      }
    }

    return null;
  }

  static bool _isDirectReplyTo({
    required TwitchChatRuntimeMessage candidate,
    required TwitchChatRuntimeMessage target,
  }) {
    final candidateParentId = _replyParentMessageId(candidate);
    final targetId = _messageId(target);

    if (candidateParentId.isNotEmpty && targetId.isNotEmpty) {
      return candidateParentId == targetId;
    }

    final parentLogin = _normalizeLogin(_replyParentLogin(candidate));
    final parentBody = _normalizeBody(_replyParentBody(candidate));

    if (parentLogin.isEmpty && parentBody.isEmpty) return false;

    final targetLogin = _normalizeLogin(target.userLogin);
    final targetDisplayName = _normalizeLogin(target.displayName);
    final targetBody = _normalizeBody(_messagePlainText(target));

    final loginMatches = parentLogin.isEmpty ||
        parentLogin == targetLogin ||
        parentLogin == targetDisplayName;
    final bodyMatches = parentBody.isEmpty || parentBody == targetBody;

    // A direct reply should not appear before the target in the visible chat
    // history. This avoids false positives when we fall back to login/body match.
    final timeLooksValid = !candidate.receivedAt.isBefore(target.receivedAt);

    return loginMatches && bodyMatches && timeLooksValid;
  }

  static String _messageId(TwitchChatRuntimeMessage message) {
    return message.id.trim();
  }

  static String _messageIdentityKey(TwitchChatRuntimeMessage message) {
    final id = _messageId(message);
    if (id.isNotEmpty) return 'id:$id';
    return 'fallback:${message.userLogin}:${message.receivedAt.microsecondsSinceEpoch}:${message.message.hashCode}';
  }

  static String _replyParentMessageId(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentMessageId,
      () => reply.parentMsgId,
      () => reply.parentId,
      () => reply.messageId,
      () => reply.id,
    ]);
  }

  static String _replyParentLogin(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentUserLogin,
      () => reply.parentLogin,
      () => reply.parentUserName,
      () => reply.parentDisplayName,
      () => reply.displayName,
    ]);
  }

  static String _replyParentDisplayName(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentDisplayName,
      () => reply.parentUserLogin,
      () => reply.parentLogin,
      () => reply.parentUserName,
    ]);
  }

  static String _replyParentBody(TwitchChatRuntimeMessage message) {
    final dynamic reply = message.metadata.replyInfo;
    if (reply == null) return '';

    return _firstNonEmpty([
      () => reply.parentMsgBody,
      () => reply.parentMessageBody,
      () => reply.parentBody,
      () => reply.messageBody,
    ]);
  }

  static String _firstNonEmpty(List<Object? Function()> readers) {
    for (final reader in readers) {
      final value = _readDynamicString(reader);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _readDynamicString(Object? Function() reader) {
    try {
      final value = reader();
      return value?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _messagePlainText(TwitchChatRuntimeMessage message) {
    final text = message.message.trim();
    if (text.isNotEmpty) return text;
    return (message.metadata.systemMessage ?? '').trim();
  }

  static String _normalizeLogin(String value) {
    final text = value.trim().toLowerCase();
    if (text.startsWith('@')) return text.substring(1);
    return text;
  }

  static String _normalizeBody(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _TwitchChatMessageContextSheet extends StatelessWidget {
  final TwitchChatRuntimeMessage selectedMessage;
  final List<_ReplyThreadEntry> entries;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const _TwitchChatMessageContextSheet({
    required this.selectedMessage,
    required this.entries,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _ReplyThreadMessageCard(
          entry: entry,
          selected: entry.message.id == selectedMessage.id,
          thirdPartyEmotes: thirdPartyEmotes,
        );
      },
    );
  }
}

class _ReplyThreadMessageCard extends StatelessWidget {
  final _ReplyThreadEntry entry;
  final bool selected;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const _ReplyThreadMessageCard({
    required this.entry,
    required this.selected,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final displayName = _displayName(message);
    final depthIndent = (entry.depth * 12.0).clamp(0.0, 42.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(left: depthIndent),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _copyMessage(context, message),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF241B32) : const Color(0xFF1B1B23),
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
                Row(
                  children: [
                    _EntryKindChip(kind: entry.kind),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD9C5FF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(message.receivedAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (_hasRelation(message)) ...[
                  const SizedBox(height: 7),
                  _RelationLine(message: message),
                ],
                const SizedBox(height: 8),
                _CompactMessageBody(
                  message: message,
                  thirdPartyEmotes: thirdPartyEmotes,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasRelation(TwitchChatRuntimeMessage message) {
    return _replyTargetLogin(message).isNotEmpty || _mentionedLogins(message).isNotEmpty;
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

  String _displayName(TwitchChatRuntimeMessage message) {
    final displayName = message.displayName.trim();
    final login = message.userLogin.trim();

    if (displayName.isEmpty) return login;
    if (login.isEmpty || displayName.toLowerCase() == login.toLowerCase()) {
      return displayName;
    }

    return '$displayName ($login)';
  }

  String _copyText(TwitchChatRuntimeMessage message) {
    final name = _displayName(message);
    final body = _messagePlainText(message);

    if (name.isEmpty) return body;
    if (body.isEmpty) return name;
    return '$name: $body';
  }

  String _messagePlainText(TwitchChatRuntimeMessage message) {
    final text = message.message.trim();
    if (text.isNotEmpty) return text;
    return (message.metadata.systemMessage ?? '').trim();
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EntryKindChip extends StatelessWidget {
  final _ReplyThreadEntryKind kind;

  const _EntryKindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      _ReplyThreadEntryKind.ancestor => '上文',
      _ReplyThreadEntryKind.selected => '目前',
      _ReplyThreadEntryKind.directReply => '回覆',
    };

    final color = switch (kind) {
      _ReplyThreadEntryKind.ancestor => Colors.white54,
      _ReplyThreadEntryKind.selected => const Color(0xFFBF94FF),
      _ReplyThreadEntryKind.directReply => const Color(0xFF57F287),
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
  return output.where((login) => login.trim().toLowerCase() != reply).toList(growable: false);
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

class _CompactMessageBody extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const _CompactMessageBody({
    required this.message,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final segments = message.segments;

    if (segments.isEmpty) {
      final fallback = message.message.trim().isNotEmpty
          ? message.message.trim()
          : (message.metadata.systemMessage ?? '').trim();

      return Text(
        fallback.isEmpty ? '〔空訊息〕' : fallback,
        style: TextStyle(
          color: fallback.isEmpty ? Colors.white38 : Colors.white,
          fontSize: 13,
          height: 1.32,
          fontWeight: FontWeight.w600,
          fontStyle: fallback.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      children: [
        for (final segment in segments)
          _MessageSegmentView(
            segment: segment,
            thirdPartyEmotes: thirdPartyEmotes,
          ),
      ],
    );
  }
}

class _MessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const _MessageSegmentView({
    required this.segment,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
      case TwitchChatRenderSegmentType.emoji:
        return _TextSegment(
          segment: segment,
          thirdPartyEmotes: thirdPartyEmotes,
        );
      case TwitchChatRenderSegmentType.link:
        return Text(
          segment.content,
          style: const TextStyle(
            color: Color(0xFF8AB4F8),
            fontSize: 13,
            height: 1.32,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
        );
      case TwitchChatRenderSegmentType.twitchEmote:
        return _NetworkEmote(
          imageUrl: segment.url,
          fallbackText: segment.content.isEmpty ? '[emote]' : segment.content,
          tooltip: segment.content.isEmpty
              ? (segment.emoteId == null
                  ? 'Twitch emote'
                  : 'Twitch emote ${segment.emoteId}')
              : segment.content,
          size: 27,
        );
      case TwitchChatRenderSegmentType.cheermote:
        return Text(
          segment.content,
          style: const TextStyle(
            color: Color(0xFFFFC857),
            fontSize: 13,
            height: 1.32,
            fontWeight: FontWeight.w900,
          ),
        );
    }
  }
}

class _TextSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;

  const _TextSegment({
    required this.segment,
    required this.thirdPartyEmotes,
  });

  @override
  Widget build(BuildContext context) {
    final text = segment.content;
    if (text.isEmpty) return const SizedBox.shrink();

    final cache = thirdPartyEmotes;
    if (cache == null || cache.count == 0) {
      return _PlainText(text: text);
    }

    final parts = _splitPreservingWhitespace(text);
    if (parts.length == 1 && cache.lookup(parts.first) == null) {
      return _PlainText(text: text);
    }

    return Wrap(
      spacing: 0,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in parts)
          _TextOrThirdPartyEmote(
            text: part,
            emote: cache.lookup(part),
          ),
      ],
    );
  }

  List<String> _splitPreservingWhitespace(String text) {
    final output = <String>[];
    final regex = RegExp(r'(\s+|\S+)');

    for (final match in regex.allMatches(text)) {
      final value = match.group(0);
      if (value != null && value.isNotEmpty) output.add(value);
    }

    return output;
  }
}

class _TextOrThirdPartyEmote extends StatelessWidget {
  final String text;
  final TwitchThirdPartyEmote? emote;

  const _TextOrThirdPartyEmote({
    required this.text,
    required this.emote,
  });

  @override
  Widget build(BuildContext context) {
    final item = emote;
    if (item == null || text.trim().isEmpty) {
      return _PlainText(text: text);
    }

    return _NetworkEmote(
      imageUrl: item.imageUrl,
      fallbackText: item.name,
      tooltip: '${item.name} · ${item.providerLabel}',
      size: item.isZeroWidth ? 24 : 27,
    );
  }
}

class _NetworkEmote extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final String tooltip;
  final double size;

  const _NetworkEmote({
    required this.imageUrl,
    required this.fallbackText,
    required this.tooltip,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) return _PlainText(text: fallbackText);

    return Tooltip(
      message: tooltip,
      child: Image.network(
        url,
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _PlainText(text: fallbackText),
      ),
    );
  }
}

class _PlainText extends StatelessWidget {
  final String text;

  const _PlainText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        height: 1.32,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
