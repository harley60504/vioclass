// PATCH VERSION: twitch_pinned_message_banner_stage192_glass_card
//
// Extracted pinned-message UI component. Keep pinned card visuals here instead
// of embedding style decisions inside the engagement strip.

import 'package:flutter/material.dart';

import '../../../../models/engagement/twitch_pinned_chat.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../shared/twitch_ui_avatar.dart';

class TwitchPinnedMessageBanner extends StatelessWidget {
  final TwitchPinnedChatMessage message;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;

  const TwitchPinnedMessageBanner({
    super.key,
    required this.message,
    this.fallbackProfileImageUrl = '',
    this.fallbackDisplayName = '',
    this.fallbackUserId = '',
    this.fallbackLogin = '',
  });

  @override
  Widget build(BuildContext context) {
    final senderUser = message.sender ?? message.pinnedBy;
    final sender = _cleanName(senderUser?.displayName) ??
        _cleanName(fallbackDisplayName) ??
        'Pinned';
    final pinnedBy = _cleanName(message.pinnedBy?.displayName);
    final senderColor = _parseUserColor(senderUser?.chatColor) ??
        TwitchUiColors.primarySoft;
    final avatarUrl = _resolveAvatarUrl(senderUser);
    final metaText = pinnedBy == null || pinnedBy == sender
        ? 'PINNED MESSAGE'
        : 'PINNED BY $pinnedBy';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF221530).withOpacity(0.96),
            const Color(0xFF15151D).withOpacity(0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TwitchUiColors.primarySoft.withOpacity(0.18)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TwitchUiColors.primary.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TwitchUiAvatar(
            imageUrl: avatarUrl,
            displayName: sender,
            size: 33,
            accentColor: senderColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TwitchUiColors.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: TwitchUiColors.primarySoft.withOpacity(0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: TwitchUiColors.primarySoft,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: senderColor,
                          fontSize: TwitchUiFontSize.chatName,
                          height: 1.1,
                          fontWeight: TwitchUiFontWeight.heavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: TwitchUiColors.textMuted,
                          fontSize: TwitchUiFontSize.chatMeta,
                          height: 1.1,
                          fontWeight: TwitchUiFontWeight.heavy,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF5F0FF),
                    fontSize: TwitchUiFontSize.cardBody,
                    height: 1.24,
                    fontWeight: TwitchUiFontWeight.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveAvatarUrl(TwitchPinnedChatUser? user) {
    final direct = user?.profileImageUrl.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    // Most pinned messages are pinned by / sent by the broadcaster. If the
    // pinned GQL payload omits profileImageURL, reuse the WatchPage stream
    // metadata avatar flow that is already used by player header and discovery.
    if (_looksLikeFallbackUser(user)) {
      final fallback = fallbackProfileImageUrl.trim();
      if (fallback.isNotEmpty) return fallback;
    }

    return '';
  }

  bool _looksLikeFallbackUser(TwitchPinnedChatUser? user) {
    if (user == null) return fallbackProfileImageUrl.trim().isNotEmpty;

    final fallbackId = fallbackUserId.trim();
    if (fallbackId.isNotEmpty && user.id.trim() == fallbackId) return true;

    final fallbackLoginText = fallbackLogin.trim().toLowerCase();
    final userLogin = user.login.trim().toLowerCase();
    if (fallbackLoginText.isNotEmpty && userLogin == fallbackLoginText) return true;

    final fallbackName = fallbackDisplayName.trim().toLowerCase();
    final displayName = user.displayName.trim().toLowerCase();
    if (fallbackName.isNotEmpty && displayName == fallbackName) return true;

    return false;
  }

  String? _cleanName(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Color? _parseUserColor(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (!text.startsWith('#') || text.length != 7) return null;
    final parsed = int.tryParse(text.substring(1), radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
}
