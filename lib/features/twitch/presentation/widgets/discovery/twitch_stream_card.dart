import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_cached_image_layer.dart';
import '../shared/twitch_ui_primitives.dart';

const double twitchStreamCardGridHorizontalPadding = 32;
const double twitchStreamCardGridSpacing = 16;
const double twitchStreamCardGridMaxCrossAxisExtent = 380;

const int _thumbnailMinPhysicalWidth = 320;
const int _thumbnailMaxPhysicalWidth = 480;

double twitchStreamCardGridMainAxisExtent(double viewportWidth) {
  final contentWidth = math.max(
    1.0,
    viewportWidth - twitchStreamCardGridHorizontalPadding,
  );
  final columnCount = math.max(
    1,
    (contentWidth /
            (twitchStreamCardGridMaxCrossAxisExtent +
                twitchStreamCardGridSpacing))
        .ceil(),
  );
  final cardWidth = math.max(
    1.0,
    (contentWidth - twitchStreamCardGridSpacing * (columnCount - 1)) /
        columnCount,
  );
  final thumbnailHeight = cardWidth * 9 / 16;
  final infoHeight = cardWidth < 330 ? 142.0 : 136.0;
  return (thumbnailHeight + infoHeight).clamp(286.0, 360.0).toDouble();
}

class TwitchStreamCard extends StatelessWidget {
  final TwitchLiveStream stream;
  final VoidCallback onTap;

  const TwitchStreamCard({
    super.key,
    required this.stream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchUiInteractiveSurface(
      onTap: onTap,
      radius: TwitchUiRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreamThumbnail(stream: stream),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: _StreamInfo(stream: stream),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamThumbnail extends StatelessWidget {
  final TwitchLiveStream stream;

  const _StreamThumbnail({required this.stream});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = TwitchCachedImageLayer.physicalWidthFor(
            context: context,
            logicalWidth: constraints.maxWidth,
            minPhysicalWidth: _thumbnailMinPhysicalWidth,
            maxPhysicalWidth: _thumbnailMaxPhysicalWidth,
          );
          final imageHeight = TwitchCachedImageLayer.heightForAspectRatio(
            width: imageWidth,
            aspectRatio: 16 / 9,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              TwitchCachedImageLayer(
                imageUrl: stream.thumbnail(width: imageWidth, height: imageHeight),
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                cacheWidth: imageWidth,
                cacheHeight: imageHeight,
                fallbackColor: TwitchUiColors.surfaceRaised,
                fallbackIcon: Icons.live_tv_rounded,
                fallbackIconColor: TwitchUiColors.textFaint,
                fallbackIconSize: 34,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x08000000),
                      Color(0x16000000),
                      Color(0x8A000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: TwitchUiSpacing.space8,
                left: TwitchUiSpacing.space8,
                child: _LiveBadge(label: context.vio.t('直播')),
              ),
              if (stream.viewerCount > 0)
                Positioned(
                  right: TwitchUiSpacing.space8,
                  bottom: TwitchUiSpacing.space8,
                  child: _ViewerBadge(viewerCount: stream.viewerCount),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final String label;

  const _LiveBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TwitchUiColors.live,
        borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: TwitchUiColors.textOnAccent,
          fontSize: TwitchUiFontSize.micro,
          fontWeight: TwitchUiFontWeight.strong,
        ),
      ),
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  final int viewerCount;

  const _ViewerBadge({required this.viewerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xB30A0B10),
        borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
        border: Border.all(color: TwitchUiColors.border),
      ),
      child: Text(
        _formatViewerCount(context, viewerCount),
        style: const TextStyle(
          color: TwitchUiColors.textPrimary,
          fontSize: TwitchUiFontSize.micro,
          fontWeight: TwitchUiFontWeight.medium,
        ),
      ),
    );
  }
}

class _StreamInfo extends StatelessWidget {
  final TwitchLiveStream stream;

  const _StreamInfo({required this.stream});

  @override
  Widget build(BuildContext context) {
    final title = stream.title.trim().isEmpty
        ? context.vio.t('未命名直播')
        : stream.title.trim();
    final game = stream.gameName.trim().isEmpty
        ? context.vio.t('未分類')
        : stream.gameName.trim();
    final language = stream.language.trim().toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: TwitchUiColors.textPrimary,
            fontSize: TwitchUiFontSize.cardTitle,
            height: 1.22,
            fontWeight: TwitchUiFontWeight.strong,
          ),
        ),
        const SizedBox(height: TwitchUiSpacing.space8),
        Row(
          children: [
            Expanded(
              child: Text(
                game,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TwitchUiColors.primarySoft,
                  fontSize: TwitchUiFontSize.bodyCompact,
                  fontWeight: TwitchUiFontWeight.medium,
                ),
              ),
            ),
            if (language.isNotEmpty) ...[
              const SizedBox(width: TwitchUiSpacing.space8),
              Text(
                language,
                style: const TextStyle(
                  color: TwitchUiColors.textMuted,
                  fontSize: TwitchUiFontSize.micro,
                  fontWeight: TwitchUiFontWeight.strong,
                ),
              ),
            ],
          ],
        ),
        const Spacer(),
        _StreamerFooter(stream: stream),
      ],
    );
  }
}

class _StreamerFooter extends StatelessWidget {
  final TwitchLiveStream stream;

  const _StreamerFooter({required this.stream});

  @override
  Widget build(BuildContext context) {
    const avatarSize = 30.0;
    return Row(
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: TwitchUiColors.border),
          ),
          child: TwitchCachedImageLayer.avatar(
            imageUrl: stream.profileImageUrl,
            size: avatarSize,
            cacheWidth: 64,
            cacheHeight: 64,
            fallbackColor: TwitchUiColors.surfaceRaised,
            fallbackIconColor: TwitchUiColors.textFaint,
            fallbackIconSize: 18,
          ),
        ),
        const SizedBox(width: TwitchUiSpacing.space8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stream.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TwitchUiColors.textSecondary,
                  fontSize: TwitchUiFontSize.bodyCompact,
                  fontWeight: TwitchUiFontWeight.strong,
                ),
              ),
              if (stream.channelLogin.isNotEmpty)
                Text(
                  stream.channelLogin,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TwitchUiColors.textFaint,
                    fontSize: TwitchUiFontSize.micro,
                    fontWeight: TwitchUiFontWeight.regular,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatViewerCount(BuildContext context, int value) {
  final compact = value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1).replaceFirst(RegExp(r'\.0$'), '')}M'
      : value >= 1000
          ? '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1).replaceFirst(RegExp(r'\.0$'), '')}K'
          : '$value';
  return context.vio.isEnglish ? '$compact viewers' : '$compact 人';
}
