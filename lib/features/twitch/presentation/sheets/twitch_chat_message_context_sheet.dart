//
// Chat message context sheet. Reply-thread construction and card UI live in
// chat_message_context/* so this file stays as the sheet entry/list composer.

import 'package:flutter/material.dart';

import '../../models/chat/twitch_chat_runtime_message.dart';
import '../../services/chat/twitch_official_emote_cache_service.dart';
import '../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../widgets/chat/twitch_chat_text_style.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import 'chat_message_context/twitch_reply_thread_builder.dart';
import 'chat_message_context/twitch_reply_thread_card.dart';

Future<void> showTwitchChatMessageContextSheet({
  required BuildContext context,
  required TwitchChatRuntimeMessage selectedMessage,
  required List<TwitchChatRuntimeMessage> messages,
  TwitchThirdPartyEmoteCacheService? thirdPartyEmotes,
  TwitchOfficialEmoteCacheService? officialEmotes,
  double fontScale = 1.0,
}) {
  final entries = TwitchReplyThreadBuilder.build(
    selectedMessage: selectedMessage,
    messages: messages,
  );

  return showTwitchUnifiedSheet<void>(
    context: context,
    title: '回覆串 · ${entries.length}',
    subtitle: '依回覆關係顯示；提及標記不聚集',
    icon: Icons.reply_rounded,
    size: TwitchUnifiedSheetSize.medium,
    showRefresh: false,
    builder: (_) => _TwitchChatMessageContextSheet(
      selectedMessage: selectedMessage,
      entries: entries,
      thirdPartyEmotes: thirdPartyEmotes,
      officialEmotes: officialEmotes,
      fontScale: fontScale,
    ),
  );
}

class _TwitchChatMessageContextSheet extends StatelessWidget {
  final TwitchChatRuntimeMessage selectedMessage;
  final List<TwitchReplyThreadEntry> entries;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final double fontScale;

  const _TwitchChatMessageContextSheet({
    required this.selectedMessage,
    required this.entries,
    required this.thirdPartyEmotes,
    required this.officialEmotes,
    required this.fontScale,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchChatTextScope(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return TwitchReplyThreadMessageCard(
            entry: entry,
            selected: _isSelectedEntry(entry.message),
            thirdPartyEmotes: thirdPartyEmotes,
            officialEmotes: officialEmotes,
            fontScale: fontScale,
          );
        },
      ),
    );
  }

  bool _isSelectedEntry(TwitchChatRuntimeMessage message) {
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
