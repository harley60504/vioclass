import 'package:flutter/material.dart';

import '../../../../models/chat/twitch_chat_fragment.dart';
import '../../../../models/chat/twitch_chat_render_segment.dart';
import '../../../../models/chat/twitch_chat_runtime_message.dart';
import '../../../../services/chat/twitch_official_emote_cache_service.dart';
import '../../../../services/chat/twitch_third_party_emote_cache_service.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../shared/twitch_emote_image.dart';
import '../twitch_chat_text_style.dart';
import 'twitch_chat_message_author.dart';
import 'twitch_chat_message_badges.dart';
import 'twitch_chat_message_chips.dart';
import 'twitch_chat_message_reply_preview.dart';
import 'twitch_chat_message_segments.dart';
import 'twitch_chat_message_timestamp.dart';
import 'twitch_chat_message_visual_metrics.dart';

class TwitchChatMessageContent extends StatelessWidget {
  final TwitchChatRuntimeMessage message;
  final TwitchThirdPartyEmoteCacheService? thirdPartyEmotes;
  final TwitchOfficialEmoteCacheService? officialEmotes;
  final Color displayColor;
  final String displayNameText;
  final bool showSystemMessage;
  final bool showTimestamp;
  final bool compact;
  final bool animateEmotes;
  final TwitchChatMessageVisualMetrics metrics;

  const TwitchChatMessageContent({
    super.key,
    required this.message,
    required this.thirdPartyEmotes,
    this.officialEmotes,
    required this.displayColor,
    required this.displayNameText,
    required this.showSystemMessage,
    required this.showTimestamp,
    required this.metrics,
    this.compact = false,
    this.animateEmotes = true,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata;
    final detached = _resolveDetachedVisuals();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.hasReply)
          TwitchChatMessageReplyPreview(message: message, metrics: metrics),
        if (showSystemMessage && metadata.isSystemLike)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              metadata.systemMessage!,
              textAlign: TextAlign.left,
              style: twitchChatTextStyle(
                TextStyle(
                  color: const Color(0xFFFFC857),
                  fontSize: metrics.compactMessageFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: _buildMessageSpans(
                context,
                segments: detached.inlineSegments,
                hasDetachedVisuals: detached.hasDetachedVisuals,
              ),
            ),
            textAlign: TextAlign.left,
          ),
        ),
        for (final gif in detached.gifs) _buildTwitchGif(gif),
        if (detached.giantEmote != null)
          _buildGigantifiedEmote(detached.giantEmote!),
      ],
    );
  }

  _TwitchDetachedChatVisuals _resolveDetachedVisuals() {
    final sourceSegments = message.segments;
    final gifs = sourceSegments
        .where((segment) => segment.type == TwitchChatRenderSegmentType.twitchGif)
        .toList(growable: false);

    var giantIndex = -1;
    final isGigantified =
        message.source.tags['msg-id']?.trim() == 'gigantified-emote-message';
    if (isGigantified) {
      for (var i = sourceSegments.length - 1; i >= 0; i -= 1) {
        final segment = sourceSegments[i];
        if (segment.type == TwitchChatRenderSegmentType.twitchEmote &&
            !segment.isZeroWidth &&
            (segment.emoteId?.trim().isNotEmpty ?? false)) {
          giantIndex = i;
          break;
        }
      }
    }

    final inline = <TwitchChatRenderSegment>[];
    TwitchChatRenderSegment? giant;
    for (var i = 0; i < sourceSegments.length; i += 1) {
      final segment = sourceSegments[i];
      if (segment.type == TwitchChatRenderSegmentType.twitchGif) continue;
      if (i == giantIndex) {
        giant = segment;
        continue;
      }
      inline.add(segment);
    }

    return _TwitchDetachedChatVisuals(
      inlineSegments: List<TwitchChatRenderSegment>.unmodifiable(inline),
      gifs: gifs,
      giantEmote: giant,
    );
  }

  Widget _buildTwitchGif(TwitchChatRenderSegment segment) {
    final url = segment.url?.trim() ?? '';
    if (url.isEmpty) return const SizedBox.shrink();

    final label = segment.content
        .replaceFirst(RegExp(r'^\['), '')
        .replaceFirst(RegExp(r'\]$'), '')
        .trim();
    final height = (80.0 * metrics.scale * metrics.compactFactor)
        .clamp(64.0, 116.0)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 320.0,
                maxHeight: height,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TwitchEmoteImage(
                  // Keep GIFs out of the normal emote-id fallback path. The
                  // Twitch-supplied URL is the source of truth for this asset.
                  id: '',
                  name: label.isEmpty ? 'GIF' : label,
                  imageUrl: url,
                  providerLabel: 'Twitch GIF',
                  isAnimated: true,
                  height: height,
                  fit: BoxFit.contain,
                  errorPlaceholder: Text(
                    segment.content.isEmpty ? '[GIF]' : segment.content,
                    style: twitchChatTextStyle(
                      TextStyle(
                        color: Colors.white54,
                        fontSize: metrics.compactMessageFontSize,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGigantifiedEmote(TwitchChatRenderSegment segment) {
    final emoteId = segment.emoteId?.trim() ?? '';
    if (emoteId.isEmpty) return const SizedBox.shrink();

    final height = (metrics.emoteSize * 4).clamp(88.0, 152.0).toDouble();
    final highResolutionUrl = TwitchChatFragment.twitchEmoteImageUrl(
      emoteId,
      scale: '4.0',
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height,
            maxWidth: height * 3,
          ),
          child: TwitchEmoteImage(
            // Use the same native animated-image decoder as normal VioClass
            // emotes, but request Twitch's larger source for the giant layout.
            id: '',
            name: segment.content,
            imageUrl: highResolutionUrl,
            providerLabel: 'Twitch',
            isAnimated: true,
            height: height,
            fit: BoxFit.contain,
            errorPlaceholder: Text(
              segment.content,
              style: twitchChatTextStyle(
                TextStyle(
                  color: Colors.white70,
                  fontSize: metrics.compactMessageFontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildMessageSpans(
    BuildContext context, {
    required List<TwitchChatRenderSegment> segments,
    required bool hasDetachedVisuals,
  }) {
    final spans = <InlineSpan>[];

    if (showTimestamp) {
      spans.add(
        TextSpan(
          text: '${formatTwitchChatMessageTime(message.receivedAt)} ',
          style: twitchChatTextStyle(
            TextStyle(
              color: Colors.white38,
              fontSize: metrics.metaFontSize,
              fontWeight: FontWeight.w700,
              height: metrics.lineHeight,
            ),
          ),
        ),
      );
    }

    for (final badge in message.resolvedBadges) {
      if (badge.image1x.trim().isEmpty) continue;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: TwitchChatMessageBadge(
              badge: badge,
              metrics: metrics,
              compact: compact,
            ),
          ),
        ),
      );
    }

    spans.addAll(
      buildTwitchChatMessageAuthorSpans(
        displayNameText: displayNameText,
        displayColor: displayColor,
        isAction: message.metadata.isAction,
        isFirstMessage: message.metadata.isFirstMessage,
        compact: compact,
        metrics: metrics,
      ),
    );

    if (segments.isEmpty) {
      if (!hasDetachedVisuals) {
        spans.add(
          TextSpan(
            text: context.vio.t('〔空訊息〕'),
            style: twitchChatTextStyle(
              TextStyle(
                color: Colors.white38,
                fontSize: metrics.compactMessageFontSize,
                fontStyle: FontStyle.italic,
                height: metrics.lineHeight,
              ),
            ),
          ),
        );
      }
    } else {
      spans.addAll(
        buildTwitchChatMessageSegmentSpans(
          context: context,
          segments: segments,
          thirdPartyEmotes: thirdPartyEmotes,
          officialEmotes: officialEmotes,
          metrics: metrics,
          animateEmotes: animateEmotes,
        ),
      );
    }

    if (message.metadata.hasBits) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TwitchChatBitsChip(
              bits: message.metadata.bitsAmount!,
              metrics: metrics,
            ),
          ),
        ),
      );
    }

    if (message.metadata.isRewardRedemption) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: TwitchChatSmallChip(
              label: context.vio.t('獎勵'),
              metrics: metrics,
            ),
          ),
        ),
      );
    }

    return spans;
  }
}

class _TwitchDetachedChatVisuals {
  final List<TwitchChatRenderSegment> inlineSegments;
  final List<TwitchChatRenderSegment> gifs;
  final TwitchChatRenderSegment? giantEmote;

  const _TwitchDetachedChatVisuals({
    required this.inlineSegments,
    required this.gifs,
    required this.giantEmote,
  });

  bool get hasDetachedVisuals => gifs.isNotEmpty || giantEmote != null;
}
