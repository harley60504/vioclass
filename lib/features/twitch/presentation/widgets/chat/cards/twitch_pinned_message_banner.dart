//
// Extracted pinned-message UI component. Keep pinned card visuals here instead
// of embedding style decisions inside the engagement strip.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/engagement/twitch_pinned_chat.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../links/twitch_chat_link_preview.dart';
import '../twitch_chat_text_style.dart';
import '../message/twitch_chat_message_visual_metrics.dart';
import '../../shared/twitch_notice.dart';
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

    showTwitchNotice(
      context,
      '已複製置頂留言',
      tone: TwitchNoticeTone.success,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderUser = message.sender ?? message.pinnedBy;
    final sender =
        _cleanName(senderUser?.displayName) ??
        _cleanName(widget.fallbackDisplayName) ??
        context.vio.t('置頂留言');
    final pinnedBy = _cleanName(message.pinnedBy?.displayName);
    final senderColor =
        _parseUserColor(senderUser?.chatColor) ?? TwitchUiColors.primarySoft;
    final avatarUrl = _resolveAvatarUrl(senderUser);
    final metaText = pinnedBy == null || pinnedBy == sender
        ? context.vio.t('置頂留言')
        : context.vio.isEnglish
        ? '${context.vio.t('置頂')} $pinnedBy'
        : '$pinnedBy ${context.vio.t('置頂')}';
    final cleanText = message.text.trim();
    final previewItems = extractTwitchChatPreviewUrls(cleanText, max: 1);
    final metrics = TwitchChatMessageVisualMetrics(_safeFontScale);
    final scale = metrics.scale;

    final nameFontSize = metrics.nameFontSize;
    final metaFontSize = metrics.metaFontSize;
    final bodyFontSize = metrics.messageFontSize;
    final hintFontSize = 10.8 * scale;
    final avatarSize = (22.0 * scale).clamp(20.0, 28.0).toDouble();

    return Material(
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                const Color(0xFF242031).withValues(alpha: 0.85),
                const Color(0xFF17171E).withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(11, 10 * scale, 11, 11 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TwitchUiColors.primary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TwitchUiColors.primarySoft.withValues(
                            alpha: 0.38,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: TwitchUiColors.primarySoft,
                        size: 15,
                      ),
                    ),
                    SizedBox(height: 7 * scale),
                    TwitchUiAvatar(
                      imageUrl: avatarUrl,
                      displayName: sender,
                      size: avatarSize,
                      accentColor: senderColor,
                    ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
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
                                  fontWeight: FontWeight.w600,
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
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
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
                                  color: const Color(0xFFF3EAFE),
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
                          context.vio.t('點一下收合 · 長按複製'),
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
