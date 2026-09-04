//
// Reply-thread card UI for Twitch chat message context sheet. This owns the
// card shell, relation chips, copy-to-clipboard behavior, and @tag readability.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../../widgets/chat/twitch_chat_text_style.dart';
import '../../widgets/chat/twitch_runtime_message_tile.dart';
import 'twitch_reply_thread_builder.dart';

class TwitchReplyThreadMessageCard extends StatelessWidget {
  final TwitchReplyThreadEntry entry;
  final bool selected;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final double fontScale;

  const TwitchReplyThreadMessageCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.thirdPartyEmotes,
    this.officialEmotes,
    this.fontScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final safeFontScale = fontScale.clamp(0.82, 1.45).toDouble();
    final depthIndent = (entry.depth * 12.0).clamp(0.0, 42.0).toDouble();
    final compactBodyScale = (safeFontScale * 0.96)
        .clamp(0.82, 1.45)
        .toDouble();

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
                    ? TwitchUiColors.sheet.cardFillActive
                    : TwitchUiColors.surfaceCard,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? TwitchUiColors.sheet.cardBorderActive
                      : TwitchUiColors.sheet.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReplyThreadCardHeader(
                    entry: entry,
                    selected: selected,
                    fontScale: safeFontScale,
                  ),
                  if (_hasRelation(message)) ...[
                    const SizedBox(height: 7),
                    _RelationLine(message: message, fontScale: safeFontScale),
                  ],
                  const SizedBox(height: 7),
                  TwitchRuntimeMessageTile(
                    message: message,
                    thirdPartyEmotes: thirdPartyEmotes,
                    officialEmotes: officialEmotes,
                    showTimestamp: false,
                    fontScale: compactBodyScale,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.vio.t('已複製這則聊天室訊息'))));
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
  final double fontScale;

  const _ReplyThreadCardHeader({
    required this.entry,
    required this.selected,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final message = entry.message;
    final safeFontScale = fontScale.clamp(0.82, 1.45).toDouble();

    return Row(
      children: [
        _EntryKindChip(kind: entry.kind, fontScale: safeFontScale),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            formatContextMessageDisplayName(message),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: twitchChatTextStyle(
              TextStyle(
                color: selected
                    ? TwitchUiColors.textPrimary
                    : TwitchUiColors.sheet.backplate.foreground,
                fontSize: 12.5 * safeFontScale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatContextMessageTime(message.receivedAt),
          style: twitchChatTextStyle(
            TextStyle(
              color: Colors.white54,
              fontSize: 10.5 * safeFontScale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryKindChip extends StatelessWidget {
  final TwitchReplyThreadEntryKind kind;
  final double fontScale;

  const _EntryKindChip({required this.kind, required this.fontScale});

  @override
  Widget build(BuildContext context) {
    final safeFontScale = fontScale.clamp(0.82, 1.45).toDouble();
    final l10n = context.vio;
    final label = switch (kind) {
      TwitchReplyThreadEntryKind.ancestor => l10n.t('上文'),
      TwitchReplyThreadEntryKind.selected => l10n.t('目前'),
      TwitchReplyThreadEntryKind.directReply => l10n.t('回覆'),
    };

    final color = switch (kind) {
      TwitchReplyThreadEntryKind.ancestor => Colors.white70,
      TwitchReplyThreadEntryKind.selected =>
        TwitchUiColors.sheet.backplate.foreground,
      TwitchReplyThreadEntryKind.directReply => const Color(0xFF57F287),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: twitchChatTextStyle(
          TextStyle(
            color: color,
            fontSize: 10.5 * safeFontScale,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RelationLine extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final double fontScale;

  const _RelationLine({required this.message, required this.fontScale});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final reply = _replyTargetLogin(message);
    if (reply.isNotEmpty) {
      chips.add(
        _RelationChip(
          label: '回覆 @${_stripAt(reply)}',
          prefix: context.vio.t('回覆'),
          type: _RelationChipType.reply,
          fontScale: fontScale,
        ),
      );
    }

    for (final login in _mentionedLogins(message)) {
      final text = login.trim();
      if (text.isEmpty) continue;
      chips.add(
        _RelationChip(
          label: '提及 @${_stripAt(text)}',
          prefix: context.vio.t('提及'),
          type: _RelationChipType.tag,
          fontScale: fontScale,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 5, children: chips);
  }
}

enum _RelationChipType { reply, tag }

class _RelationChip extends StatelessWidget {
  final String label;
  final String prefix;
  final _RelationChipType type;
  final double fontScale;

  const _RelationChip({
    required this.label,
    required this.prefix,
    required this.type,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    final safeFontScale = fontScale.clamp(0.82, 1.45).toDouble();
    final color = switch (type) {
      _RelationChipType.reply => TwitchUiColors.sheet.backplate.foreground,
      _RelationChipType.tag => TwitchUiColors.textSecondary,
    };

    final backgroundOpacity = switch (type) {
      _RelationChipType.reply => 0.13,
      _RelationChipType.tag => 0.16,
    };

    final borderOpacity = switch (type) {
      _RelationChipType.reply => 0.30,
      _RelationChipType.tag => 0.34,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: borderOpacity)),
      ),
      child: Text(
        label.replaceFirst(RegExp(r'^[^@]+'), '$prefix '),
        style: twitchChatTextStyle(
          TextStyle(
            color: color,
            fontSize: 11 * safeFontScale,
            fontWeight: FontWeight.w900,
          ),
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
