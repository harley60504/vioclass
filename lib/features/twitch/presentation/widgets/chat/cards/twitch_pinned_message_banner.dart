//
// Extracted pinned-message UI component. Keep pinned card visuals here instead
// of embedding style decisions inside the engagement strip.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/engagement/twitch_pinned_chat.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../links/twitch_chat_link_preview.dart';
import '../twitch_chat_text_style.dart';
import '../../shared/twitch_ui_avatar.dart';

class TwitchPinnedMessageBanner extends StatefulWidget {
  final TwitchPinnedChatMessage message;
  final double fontScale;
  final String fallbackProfileImageUrl;
  final String fallbackDisplayName;
  final String fallbackUserId;
  final String fallbackLogin;

  const TwitchPinnedMessageBanner({
    super.key,
    required this.message,
    this.fontScale = 1.0,
    this.fallbackProfileImageUrl = '',
    this.fallbackDisplayName = '',
    this.fallbackUserId = '',
    this.fallbackLogin = '',
  });

  @override
  State<TwitchPinnedMessageBanner> createState() =>
      _TwitchPinnedMessageBannerState();
}

class _TwitchPinnedMessageBannerState extends State<TwitchPinnedMessageBanner> {
  bool _expanded = false;

  TwitchPinnedChatMessage get message => widget.message;

  double get _safeFontScale => widget.fontScale.clamp(0.82, 1.36).toDouble();

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
    final sender =
        _cleanName(senderUser?.displayName) ??
        _cleanName(widget.fallbackDisplayName) ??
        'Pinned';
    final pinnedBy = _cleanName(message.pinnedBy?.displayName);
    final senderColor =
        _parseUserColor(senderUser?.chatColor) ?? TwitchUiColors.primarySoft;
    final avatarUrl = _resolveAvatarUrl(senderUser);
    final metaText = pinnedBy == null || pinnedBy == sender
        ? 'PINNED MESSAGE'
        : 'PINNED BY $pinnedBy';
    final cleanText = message.text.trim();
    final previewItems = extractTwitchChatPreviewUrls(cleanText, max: 1);
    final scale = _safeFontScale;

    final nameFontSize = (TwitchUiFontSize.chatName + 0.8) * scale;
    final metaFontSize = (TwitchUiFontSize.chatMeta + 0.6) * scale;
    final bodyFontSize = (TwitchUiFontSize.cardBody + 1.2) * scale;
    final hintFontSize = 10.8 * scale;
    final iconSize = (12.0 * scale).clamp(12.0, 16.0).toDouble();
    final pinBoxSize = (20.0 * scale).clamp(20.0, 26.0).toDouble();
    final avatarSize = (33.0 * scale).clamp(33.0, 43.0).toDouble();

    return Material(
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        splashColor: TwitchUiColors.primary.withValues(alpha: 0.10),
        highlightColor: TwitchUiColors.primary.withValues(alpha: 0.06),
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: _copyPinnedMessage,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                const Color(0xFF241538).withValues(alpha: 0.96),
                const Color(0xFF15131D).withValues(alpha: 0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: TwitchUiColors.primarySoft.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 8 * scale, 10, 8 * scale),
            child: Row(
              crossAxisAlignment: _expanded
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                TwitchUiAvatar(
                  imageUrl: avatarUrl,
                  displayName: sender,
                  size: avatarSize,
                  accentColor: senderColor,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: pinBoxSize,
                            height: pinBoxSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: TwitchUiColors.primary.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TwitchUiColors.primarySoft.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.push_pin_rounded,
                              color: TwitchUiColors.primarySoft,
                              size: iconSize,
                            ),
                          ),
                          SizedBox(width: 7 * scale),
                          Flexible(
                            child: Text(
                              sender,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: twitchChatTextStyle(
                                TextStyle(
                                  color: senderColor,
                                  fontSize: nameFontSize,
                                  height: 1.1,
                                  fontWeight: TwitchUiFontWeight.heavy,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 7 * scale),
                          Flexible(
                            child: Text(
                              metaText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: twitchChatTextStyle(
                                TextStyle(
                                  color: TwitchUiColors.textMuted,
                                  fontSize: metaFontSize,
                                  height: 1.1,
                                  fontWeight: TwitchUiFontWeight.heavy,
                                  letterSpacing: 0.35,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6 * scale),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white38,
                            size: (18.0 * scale).clamp(18.0, 23.0).toDouble(),
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * scale),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: RichText(
                          maxLines: _expanded ? 12 : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          text: TextSpan(
                            children: buildTwitchChatLinkifiedSpans(
                              context: context,
                              text: cleanText,
                              textStyle: twitchChatTextStyle(
                                TextStyle(
                                  color: const Color(0xFFF5F0FF),
                                  fontSize: bodyFontSize,
                                  height: 1.24,
                                  fontWeight: TwitchUiFontWeight.body,
                                ),
                              ),
                              linkStyle: twitchChatTextStyle(
                                TextStyle(
                                  color: const Color(0xFF8AB4F8),
                                  fontSize: bodyFontSize,
                                  height: 1.24,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_expanded && previewItems.isNotEmpty) ...[
                        SizedBox(height: 7 * scale),
                        TwitchChatLinkPreviewColumn(
                          items: previewItems,
                          fontScale: scale,
                        ),
                      ],
                      if (_expanded) ...[
                        SizedBox(height: 7 * scale),
                        Text(
                          '點一下收合 · 長按複製',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: twitchChatTextStyle(
                            TextStyle(
                              color: Colors.white38,
                              fontSize: hintFontSize,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
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
    if (fallbackLoginText.isNotEmpty && userLogin == fallbackLoginText) {
      return true;
    }

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
