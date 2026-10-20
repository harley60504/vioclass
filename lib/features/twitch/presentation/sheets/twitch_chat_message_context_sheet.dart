//
// Chat message context sheet. Reply-thread construction and card UI live in
// chat_message_context/* so this file stays as the sheet entry/list composer.

import 'package:flutter/material.dart';

import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../localization/vioclass_localizations.dart';
import '../widgets/chat/twitch_chat_text_style.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'chat_message_context/twitch_reply_thread_builder.dart';
import 'chat_message_context/twitch_reply_thread_card.dart';
import 'twitch_chat_user_profile_sheet.dart' show twitchChatUserLocalHistory;

Future<void> showTwitchChatMessageContextSheet({
  required BuildContext context,
  required TwitchChatRuntimeMessage selectedMessage,
  required List<TwitchChatRuntimeMessage> messages,
  TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  TwitchOfficialEmoteCacheService? officialEmotes,
  double fontScale = 1.0,
  Widget Function(BuildContext, TwitchChatRuntimeMessage)? messageActionBuilder,
  Future<void> Function(TwitchChatRuntimeMessage)? onOpenUser,
}) {
  final l10n = context.vio;
  final entries = TwitchReplyThreadBuilder.build(
    selectedMessage: selectedMessage,
    messages: messages,
  );

  return showTwitchUnifiedSheet<void>(
    context: context,
    title: l10n.t('回覆串'),
    icon: Icons.reply_rounded,
    size: TwitchUnifiedSheetSize.medium,
    showRefresh: false,
    builder: (_) => TwitchChatMessageContextCard(
      selectedMessage: selectedMessage,
      entries: entries,
      messages: messages,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
      fontScale: fontScale,
      messageActionBuilder: messageActionBuilder,
      onOpenUser: onOpenUser,
    ),
  );
}

class TwitchChatMessageContextCard extends StatefulWidget {
  final List<TwitchChatRuntimeMessage> messages;
  final TwitchChatRuntimeMessage selectedMessage;
  final List<TwitchReplyThreadEntry> entries;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final double fontScale;
  final Widget Function(BuildContext, TwitchChatRuntimeMessage)?
  messageActionBuilder;
  final Future<void> Function(TwitchChatRuntimeMessage)? onOpenUser;

  const TwitchChatMessageContextCard({
    super.key,
    required this.messages,
    required this.selectedMessage,
    required this.entries,
    required this.thirdPartyEmotes,
    required this.officialEmotes,
    required this.fontScale,
    required this.messageActionBuilder,
    required this.onOpenUser,
  });

  @override
  State<TwitchChatMessageContextCard> createState() => _MessageContextState();
}

class _MessageContextState extends State<TwitchChatMessageContextCard> {
  bool _showHistory = false;
  @override
  Widget build(BuildContext context) {
    final history = twitchChatUserLocalHistory(
      widget.selectedMessage,
      widget.messages,
    );
    final entries = _showHistory
        ? history
              .map(
                (message) => TwitchReplyThreadEntry(
                  message: message,
                  kind: TwitchReplyThreadEntryKind.selected,
                  depth: 0,
                ),
              )
              .toList()
        : widget.entries;
    return TwitchChatTextScope(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(context.vio.t('聊天串')),
                selected: !_showHistory,
                onSelected: (_) => setState(() => _showHistory = false),
              ),
              ChoiceChip(
                label: Text(context.vio.t('聊天紀錄')),
                selected: _showHistory,
                onSelected: (_) => setState(() => _showHistory = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TwitchReplyThreadMessageCard(
                entry: entry,
                selected: _isSelectedEntry(entry.message),
                showEntryKind: !_showHistory,
                thirdPartyEmotes: widget.thirdPartyEmotes,
                officialEmotes: widget.officialEmotes,
                fontScale: widget.fontScale,
                onOpenUser: widget.onOpenUser == null
                    ? null
                    : () => widget.onOpenUser!(entry.message),
                actions: widget.messageActionBuilder?.call(
                  context,
                  entry.message,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSelectedEntry(TwitchChatRuntimeMessage message) {
    final selectedMessage = widget.selectedMessage;
    final selectedId = selectedMessage.id.trim();
    final messageId = message.id.trim();

    if (selectedId.isNotEmpty && messageId.isNotEmpty) {
      return selectedId == messageId;
    }

    return identical(message, selectedMessage) ||
        (message.userLogin == selectedMessage.userLogin &&
            message.receivedAt == selectedMessage.receivedAt &&
            message.message == selectedMessage.message);
  }
}
