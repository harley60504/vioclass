// PATCH VERSION: twitch_pinned_message_banner_stage194_no_outer_shadow
//
// Extracted pinned-message UI component. Keep pinned card visuals here instead
// of embedding style decisions inside the engagement strip.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/engagement/twitch_pinned_chat.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../shared/twitch_ui_avatar.dart';

class TwitchPinnedMessageBanner extends StatefulWidget {
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
  State<TwitchPinnedMessageBanner> createState() => _TwitchPinnedMessageBannerState();
}

class _TwitchPinnedMessageBannerState extends State<TwitchPinnedMessageBanner> {
  bool _expanded = false;

  TwitchPinnedChatMessage get message => widget.message;

  Future<void> _copyPinnedMessage() async {
    final text = message.text.trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已複製置頂留言'),
        duration: Duration(milliseconds: 1100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderUser = message.sender ?? message.pinnedBy;
    final sender = _cleanName(senderUser?.displayName) ??
        _cleanName(widget.fallbackDisplayName) ??
        'Pinned';
    final pinnedBy = _cleanName(message.pinnedBy?.displayName);
    final senderColor = _parseUserColor(senderUser?.chatColor) ??
        TwitchUiColors.primarySoft;
    final avatarUrl = _resolveAvatarUrl(senderUser);
    final metaText = pinnedBy == null || pinnedBy == sender
        ? 'PINNED MESSAGE'
        : 'PINNED BY $pinnedBy';
    final cleanText = message.text.trim();

    return Material(
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        splashColor: TwitchUiColors.primary.withOpacity(0.10),
        highlightColor: TwitchUiColors.primary.withOpacity(0.06),
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: _copyPinnedMessage,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF241538).withOpacity(0.96),
                const Color(0xFF15131D).withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: TwitchUiColors.primarySoft.withOpacity(0.28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              crossAxisAlignment: _expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
                          const SizedBox(width: 6),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Text(
                          cleanText,
                          maxLines: _expanded ? 12 : 2,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF5F0FF),
                            fontSize: TwitchUiFontSize.cardBody,
                            height: 1.24,
                            fontWeight: TwitchUiFontWeight.body,
                          ),
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 7),
                        const Text(
                          '點一下收合 · 長按複製',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
      final fallback = widget.fallbackProfileImageUrl.trim();
      if (fallback.isNotEmpty) return fallback;
    }

    return '';
  }

  bool _looksLikeFallbackUser(TwitchPinnedChatUser? user) {
    if (user == null) return widget.fallbackProfileImageUrl.trim().isNotEmpty;

    final fallbackId = widget.fallbackUserId.trim();
    if (fallbackId.isNotEmpty && user.id.trim() == fallbackId) return true;

    final fallbackLoginText = widget.fallbackLogin.trim().toLowerCase();
    final userLogin = user.login.trim().toLowerCase();
    if (fallbackLoginText.isNotEmpty && userLogin == fallbackLoginText) return true;

    final fallbackName = widget.fallbackDisplayName.trim().toLowerCase();
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
