import 'package:flutter/material.dart';

import '../../../models/chat/twitch_chat_message_metadata.dart';
import '../../../models/chat/twitch_chat_render_segment.dart';
import '../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import '../../../services/chat/twitch_third_party_emote_cache_service.dart';

class TwitchRuntimeMessageTile extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final bool showTimestamp;
  final double fontScale;
  final bool compact;
  final VoidCallback? onOpenContext;

  const TwitchRuntimeMessageTile({
    super.key,
    required this.message,
    this.thirdPartyEmotes,
    this.showTimestamp = false,
    this.fontScale = 1.0,
    this.compact = false,
    this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor =
        _parseColor(message.color) ?? _fallbackUserColor(message.userLogin);
    final displayNameText = _formatDisplayName(message);
    final metrics = _ChatMessageVisualMetrics(fontScale, compact: compact);
    final style = _SpecialMessageStyle.fromMetadata(message.metadata);

    if (style != null) {
      return _SpecialMessageCard(
        message: message,
        thirdPartyEmotes: thirdPartyEmotes,
        displayColor: displayColor,
        displayNameText: displayNameText,
        style: style,
        showTimestamp: showTimestamp,
        metrics: metrics,
        onOpenContext: onOpenContext,
      );
    }

    return _NormalMessageCard(
      message: message,
      thirdPartyEmotes: thirdPartyEmotes,
      displayColor: displayColor,
      displayNameText: displayNameText,
      showTimestamp: showTimestamp,
      metrics: metrics,
      onOpenContext: onOpenContext,
    );
  }

  String _formatDisplayName(TwitchChatRuntimeMessage message) {
    final displayName = message.displayName.trim();
    final login = message.userLogin.trim();

    if (displayName.isEmpty) return login;
    if (login.isEmpty) return displayName;
    if (displayName.toLowerCase() == login.toLowerCase()) return displayName;

    return '$displayName ($login)';
  }

  Color _fallbackUserColor(String login) {
    const palette = <Color>[
      Color(0xFFFF0000),
      Color(0xFF0000FF),
      Color(0xFF008000),
      Color(0xFFB22222),
      Color(0xFFFF7F50),
      Color(0xFF9ACD32),
      Color(0xFFFF4500),
      Color(0xFF2E8B57),
      Color(0xFFDAA520),
      Color(0xFFD2691E),
      Color(0xFF5F9EA0),
      Color(0xFF1E90FF),
      Color(0xFFFF69B4),
      Color(0xFF8A2BE2),
      Color(0xFF00FF7F),
    ];

    final clean = login.trim().toLowerCase();
    if (clean.isEmpty) return const Color(0xFFBF94FF);

    var hash = 0;
    for (final codeUnit in clean.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return palette[hash % palette.length];
  }

  Color? _parseColor(String value) {
    final text = value.trim();
    if (!text.startsWith('#') || text.length != 7) return null;

    final parsed = int.tryParse(text.substring(1), radix: 16);
    if (parsed == null) return null;

    return Color(0xFF000000 | parsed);
  }
}



class _ChatMessageVisualMetrics {
  final double scale;
  final bool compact;

  const _ChatMessageVisualMetrics(double rawScale, {this.compact = false})
      : scale = rawScale < 0.82
            ? 0.82
            : rawScale > 1.45
                ? 1.45
                : rawScale;

  double get _compactFactor => compact ? 0.92 : 1.0;

  double get messageFontSize => 13 * scale * _compactFactor;
  double get compactMessageFontSize => 12.4 * scale * _compactFactor;
  double get nameFontSize => 13 * scale * _compactFactor;
  double get compactNameFontSize => 12.2 * scale * _compactFactor;
  double get metaFontSize => 10.5 * scale * _compactFactor;
  double get chipFontSize => 10 * scale * _compactFactor;
  double get badgeSize => 18 * scale * _compactFactor;
  double get compactBadgeSize => 16 * scale * _compactFactor;
  double get emoteSize => 28 * scale * _compactFactor;
  double get thirdPartyEmoteSize => 28 * scale * _compactFactor;
  double get zeroWidthEmoteSize => 24 * scale * _compactFactor;
  double get lineHeight => compact ? 1.18 : 1.25;
}

class _NormalMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showTimestamp;
  final _ChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const _NormalMessageCard({
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showTimestamp,
    required this.metrics,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B23),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.075)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
            child: _MessageContent(
              message: message,
              thirdPartyEmotes: thirdPartyEmotes,
              displayColor: displayColor,
              displayNameText: displayNameText,
              showSystemMessage: true,
              showTimestamp: showTimestamp,
              metrics: metrics,
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _SpecialMessageCard extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final _SpecialMessageStyle style;
  final bool showTimestamp;
  final _ChatMessageVisualMetrics metrics;
  final VoidCallback? onOpenContext;

  const _SpecialMessageCard({
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.style,
    required this.showTimestamp,
    required this.metrics,
    required this.onOpenContext,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata;
    final bannerText = metadata.systemMessage?.trim();
    final hasVisibleChatText =
        message.message.trim().isNotEmpty || message.segments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenContext,
        onLongPress: onOpenContext,
        onSecondaryTap: onOpenContext,
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: style.borderColor),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: style.accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 9, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 15, color: style.accentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            metadata.specialLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.accentColor,
                              fontSize: 11 * metrics.scale,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (showTimestamp) ...[
                          const SizedBox(width: 7),
                          _TimestampChip(
                            time: message.receivedAt,
                            metrics: metrics,
                          ),
                        ],
                        if (metadata.msgId != null &&
                            metadata.msgId!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _SmallChip(
                            label: metadata.msgId!,
                            metrics: metrics,
                          ),
                        ],
                      ],
                    ),
                    if (bannerText != null && bannerText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bannerText,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: metrics.compactMessageFontSize,
                          height: metrics.lineHeight,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (hasVisibleChatText) ...[
                      if (bannerText != null && bannerText.isNotEmpty)
                        const SizedBox(height: 6),
                      _MessageContent(
                        message: message,
                        thirdPartyEmotes: thirdPartyEmotes,
                        displayColor: displayColor,
                        displayNameText: displayNameText,
                        showSystemMessage: false,
                        showTimestamp: false,
                        compact: true,
                        metrics: metrics,
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
}

class _MessageContent extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showSystemMessage;
  final bool showTimestamp;
  final bool compact;
  final _ChatMessageVisualMetrics metrics;

  const _MessageContent({
    required this.message,
    required this.thirdPartyEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showSystemMessage,
    required this.showTimestamp,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final segments = message.segments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.metadata.hasReply)
          _ReplyPreview(message: message, metrics: metrics),
        if (showSystemMessage && message.metadata.isSystemLike)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              message.metadata.systemMessage!,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: const Color(0xFFFFC857),
                fontSize: metrics.compactMessageFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.start,
            spacing: 4,
            runSpacing: 3,
            children: [
              if (showTimestamp)
                _TimestampText(time: message.receivedAt, metrics: metrics),
              for (final badge in message.resolvedBadges)
                if (badge.image1x.isNotEmpty)
                  Tooltip(
                    message: badge.title,
                    child: Image.network(
                      badge.image1x,
                      width: compact
                          ? metrics.compactBadgeSize
                          : metrics.badgeSize,
                      height: compact
                          ? metrics.compactBadgeSize
                          : metrics.badgeSize,
                      cacheWidth: 36,
                      cacheHeight: 36,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              Text(
                displayNameText,
                style: TextStyle(
                  color: displayColor,
                  fontWeight: FontWeight.w900,
                  fontSize: compact
                      ? metrics.compactNameFontSize
                      : metrics.nameFontSize,
                  fontStyle: message.metadata.isAction
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
              Text(
                ':',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: metrics.messageFontSize,
                ),
              ),
              if (segments.isEmpty)
                Text(
                  '〔空訊息〕',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: metrics.compactMessageFontSize,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                for (final segment in segments)
                  _MessageSegmentView(
                    segment: segment,
                    thirdPartyEmotes: thirdPartyEmotes,
                    metrics: metrics,
                  ),
              if (message.metadata.hasBits)
                _BitsChip(bits: message.metadata.bitsAmount!, metrics: metrics),
              if (message.metadata.isRewardRedemption)
                _SmallChip(label: 'reward', metrics: metrics),
              if (message.metadata.isFirstMessage)
                _SmallChip(label: 'first', metrics: metrics),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecialMessageStyle {
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;

  const _SpecialMessageStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
  });

  static _SpecialMessageStyle? fromMetadata(TwitchChatMessageMetadata metadata) {
    switch (metadata.specialKind) {
      case TwitchChatSpecialMessageKind.channelPointReward:
        return _style(
          accent: const Color(0xFFB778FF),
          icon: Icons.diamond_rounded,
        );
      case TwitchChatSpecialMessageKind.bits:
      case TwitchChatSpecialMessageKind.bitsBadgeTier:
        return _style(
          accent: const Color(0xFFFFC857),
          icon: Icons.auto_awesome_rounded,
        );
      case TwitchChatSpecialMessageKind.sub:
      case TwitchChatSpecialMessageKind.resub:
        return _style(
          accent: const Color(0xFFFF75B7),
          icon: Icons.star_rounded,
        );
      case TwitchChatSpecialMessageKind.subGift:
      case TwitchChatSpecialMessageKind.subMysteryGift:
      case TwitchChatSpecialMessageKind.giftPaidUpgrade:
        return _style(
          accent: const Color(0xFFFF9D5C),
          icon: Icons.card_giftcard_rounded,
        );
      case TwitchChatSpecialMessageKind.raid:
        return _style(
          accent: const Color(0xFFFF5C5C),
          icon: Icons.groups_rounded,
        );
      case TwitchChatSpecialMessageKind.announcement:
        return _style(
          accent: const Color(0xFF5CC8FF),
          icon: Icons.campaign_rounded,
        );
      case TwitchChatSpecialMessageKind.notice:
      case TwitchChatSpecialMessageKind.clearChat:
      case TwitchChatSpecialMessageKind.clearMsg:
      case TwitchChatSpecialMessageKind.system:
        return _style(
          accent: const Color(0xFFFFC857),
          icon: Icons.info_outline_rounded,
        );
      case TwitchChatSpecialMessageKind.ritual:
        return _style(
          accent: const Color(0xFF7EE787),
          icon: Icons.auto_awesome_rounded,
        );
      case TwitchChatSpecialMessageKind.normal:
      case TwitchChatSpecialMessageKind.action:
        return null;
    }
  }

  static _SpecialMessageStyle _style({
    required Color accent,
    required IconData icon,
  }) {
    return _SpecialMessageStyle(
      accentColor: accent,
      backgroundColor: Color.alphaBlend(
        accent.withOpacity(0.14),
        const Color(0xFF191922),
      ),
      borderColor: accent.withOpacity(0.46),
      icon: icon,
    );
  }
}

class _TimestampText extends StatelessWidget {
  final DateTime time;
  final _ChatMessageVisualMetrics metrics;

  const _TimestampText({required this.time, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatTime(time),
      style: TextStyle(
        color: Colors.white38,
        fontSize: metrics.metaFontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TimestampChip extends StatelessWidget {
  final DateTime time;
  final _ChatMessageVisualMetrics metrics;

  const _TimestampChip({required this.time, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _formatTime(time),
        style: TextStyle(
          color: Colors.white60,
          fontSize: metrics.chipFontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ReplyPreview extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final _ChatMessageVisualMetrics metrics;

  const _ReplyPreview({required this.message, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final reply = message.metadata.replyInfo;
    if (reply == null) return const SizedBox.shrink();

    final name = reply.parentDisplayName.isEmpty
        ? reply.parentUserLogin
        : reply.parentDisplayName;
    final body = reply.parentMsgBody;

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 3),
      child: Text(
        name.isEmpty && body.isEmpty ? 'reply' : '$name: $body',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white38,
          fontSize: metrics.metaFontSize,
        ),
      ),
    );
  }
}

class _MessageSegmentView extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final _ChatMessageVisualMetrics metrics;

  const _MessageSegmentView({
    required this.segment,
    this.thirdPartyEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    switch (segment.type) {
      case TwitchChatRenderSegmentType.text:
        return _TextSegment(
          segment: segment,
          thirdPartyEmotes: thirdPartyEmotes,
          metrics: metrics,
        );
      case TwitchChatRenderSegmentType.link:
        return _LinkSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.twitchEmote:
        return _EmoteSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.emoji:
        return _TextSegment(segment: segment, metrics: metrics);
      case TwitchChatRenderSegmentType.cheermote:
        return _CheermoteSegment(segment: segment, metrics: metrics);
    }
  }
}

class _TextSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final _ChatMessageVisualMetrics metrics;

  const _TextSegment({
    required this.segment,
    this.thirdPartyEmotes,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (segment.content.isEmpty) return const SizedBox.shrink();

    final cache = thirdPartyEmotes;
    if (cache == null || cache.count == 0) {
      return Text(
        segment.content,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    final parts = _splitPreservingWhitespace(segment.content);
    if (parts.length == 1 && cache.lookup(parts.first) == null) {
      return Text(
        segment.content,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    return Wrap(
      spacing: 0,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.start,
      children: [
        for (final part in parts)
          _TextOrThirdPartyEmote(
            text: part,
            emote: cache.lookup(part),
            metrics: metrics,
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
  final _ChatMessageVisualMetrics metrics;

  const _TextOrThirdPartyEmote({
    required this.text,
    required this.emote,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final item = emote;
    if (item == null || text.trim().isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    return Tooltip(
      message: '${item.name} · ${item.providerLabel}',
      child: Image.network(
        item.imageUrl,
        width: item.isZeroWidth
            ? metrics.zeroWidthEmoteSize
            : metrics.thirdPartyEmoteSize,
        height: item.isZeroWidth
            ? metrics.zeroWidthEmoteSize
            : metrics.thirdPartyEmoteSize,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) {
          return Text(
            item.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: metrics.messageFontSize,
            ),
          );
        },
      ),
    );
  }
}

class _LinkSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final _ChatMessageVisualMetrics metrics;

  const _LinkSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      segment.content,
      textAlign: TextAlign.left,
      style: TextStyle(
        color: const Color(0xFF8AB4F8),
        fontSize: metrics.messageFontSize,
        height: metrics.lineHeight,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _EmoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final _ChatMessageVisualMetrics metrics;

  const _EmoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final imageUrl = segment.url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Text(
        segment.content,
        style: TextStyle(
          color: Colors.white,
          fontSize: metrics.messageFontSize,
          height: metrics.lineHeight,
        ),
      );
    }

    final size = metrics.emoteSize;
    return Tooltip(
      message: segment.content.isEmpty
          ? (segment.emoteId == null
              ? 'Twitch emote'
              : 'Twitch emote ${segment.emoteId}')
          : segment.content,
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) {
          return Text(
            segment.content.isEmpty ? '[emote]' : segment.content,
            style: TextStyle(
              color: Colors.white,
              fontSize: metrics.messageFontSize,
            ),
          );
        },
      ),
    );
  }
}

class _CheermoteSegment extends StatelessWidget {
  final TwitchChatRenderSegment segment;
  final _ChatMessageVisualMetrics metrics;

  const _CheermoteSegment({required this.segment, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Text(
      segment.content,
      style: TextStyle(
        color: const Color(0xFFFFC857),
        fontWeight: FontWeight.w900,
        fontSize: metrics.messageFontSize,
      ),
    );
  }
}

class _BitsChip extends StatelessWidget {
  final int bits;
  final _ChatMessageVisualMetrics metrics;

  const _BitsChip({required this.bits, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return _SmallChip(label: '$bits bits', metrics: metrics);
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final _ChatMessageVisualMetrics metrics;

  const _SmallChip({required this.label, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF9146FF).withOpacity(0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFFBF94FF),
          fontSize: metrics.chipFontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
