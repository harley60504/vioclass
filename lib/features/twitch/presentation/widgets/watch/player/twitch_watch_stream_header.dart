import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../localization/vioclass_localizations.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../shared/twitch_glass.dart';
import '../../shared/twitch_notice.dart';

class WatchCompactAvatarTile extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool tiny;
  final double height;
  final VoidCallback? onOpenChannel;

  const WatchCompactAvatarTile({
    super.key,
    required this.metadata,
    required this.tiny,
    required this.height,
    this.onOpenChannel,
  });

  @override
  Widget build(BuildContext context) {
    final data = _WatchStreamHeaderData.fromMetadata(metadata);
    final size = math.min(height - 10.0, tiny ? 30.0 : 34.0);
    final radius = tiny ? TwitchUiRadius.sm : TwitchUiRadius.md;

    return Tooltip(
      message: data.channelLabel,
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(radius),
        backgroundColor: TwitchUiColors.surfacePlayer,
        borderColor: TwitchUiColors.border,
        blurSigma: 0,
        boxShadow: TwitchUiShadows.none,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenChannel,
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: height,
              height: height,
              child: Center(
                child: _WatchChannelAvatar(
                  imageUrl: data.profileImageUrl,
                  channelLogin: data.channelLogin,
                  size: size,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WatchStreamHeaderCard extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool compact;
  final double height;
  final VoidCallback? onOpenChannel;

  const WatchStreamHeaderCard({
    super.key,
    required this.metadata,
    required this.compact,
    required this.height,
    this.onOpenChannel,
  });

  @override
  Widget build(BuildContext context) {
    final data = _WatchStreamHeaderData.fromMetadata(metadata);
    final avatarSize = math.min(compact ? 30.0 : 34.0, height - 12.0);

    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(TwitchUiRadius.md),
      backgroundColor: TwitchUiColors.surfacePlayer,
      borderColor: TwitchUiColors.border,
      blurSigma: 0,
      boxShadow: TwitchUiShadows.none,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact
                ? TwitchUiSpacing.space8
                : TwitchUiSpacing.space12,
            vertical: TwitchUiSpacing.space4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenChannel,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(TwitchUiSpacing.space2),
                    child: _WatchChannelAvatar(
                      imageUrl: data.profileImageUrl,
                      channelLogin: data.channelLogin,
                      size: avatarSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TwitchUiSpacing.space8),
              Expanded(
                child: _WatchStreamHeaderSingleRow(
                  data: data,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchStreamHeaderData {
  final String channelLogin;
  final String channelLabel;
  final String streamTitle;
  final String gameName;
  final int? viewerCount;
  final String profileImageUrl;
  final String language;
  final String languageLabel;

  const _WatchStreamHeaderData({
    required this.channelLogin,
    required this.channelLabel,
    required this.streamTitle,
    required this.gameName,
    required this.viewerCount,
    required this.profileImageUrl,
    required this.language,
    required this.languageLabel,
  });

  factory _WatchStreamHeaderData.fromMetadata(
    TwitchStreamHeaderMetadata metadata,
  ) {
    final channelLogin = metadata.channelLogin.trim();
    final displayName = metadata.displayName.trim();
    final language = metadata.language.trim();
    return _WatchStreamHeaderData(
      channelLogin: channelLogin,
      channelLabel: displayName.isNotEmpty
          ? displayName
          : channelLogin.isEmpty
          ? 'Twitch 直播'
          : channelLogin,
      streamTitle: metadata.streamTitle.trim(),
      gameName: metadata.gameName.trim(),
      viewerCount: metadata.viewerCount,
      profileImageUrl: metadata.profileImageUrl.trim(),
      language: language,
      languageLabel: language.toUpperCase(),
    );
  }
}

class _WatchStreamHeaderSingleRow extends StatelessWidget {
  final _WatchStreamHeaderData data;
  final bool compact;

  const _WatchStreamHeaderSingleRow({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showViewer = width >= 310 &&
            data.viewerCount != null &&
            data.viewerCount! > 0;
        final showGame = width >= 500 && data.gameName.isNotEmpty;
        final showLanguage = width >= 650 && data.languageLabel.isNotEmpty;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width * 0.28),
              child: _WatchChannelNameText(
                label: data.channelLabel,
                compact: compact,
              ),
            ),
            if (data.streamTitle.isNotEmpty) ...[
              const SizedBox(width: TwitchUiSpacing.space8),
              Text(
                '•',
                style: TextStyle(
                  color: TwitchUiColors.textFaint,
                  fontSize: TwitchUiFontSize.meta,
                  fontWeight: TwitchUiFontWeight.strong,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: TwitchUiSpacing.space8),
              Expanded(
                child: _WatchStreamTitleText(
                  title: data.streamTitle,
                  compact: compact,
                ),
              ),
            ] else
              const Spacer(),
            if (showViewer) ...[
              const SizedBox(width: TwitchUiSpacing.space8),
              _WatchInfoPill(
                icon: Icons.visibility_rounded,
                label: _formatViewerCount(context, data.viewerCount!),
                compact: true,
                maxWidth: 110,
              ),
            ],
            if (showGame) ...[
              const SizedBox(width: TwitchUiSpacing.space4),
              _WatchInfoPill(
                icon: Icons.sports_esports_rounded,
                label: data.gameName,
                copyText: data.gameName,
                compact: true,
                maxWidth: 150,
              ),
            ],
            if (showLanguage) ...[
              const SizedBox(width: TwitchUiSpacing.space4),
              _WatchInfoPill(
                icon: Icons.translate_rounded,
                label: data.languageLabel,
                copyText: data.language,
                compact: true,
                maxWidth: 64,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WatchChannelNameText extends StatelessWidget {
  final String label;
  final bool compact;

  const _WatchChannelNameText({required this.label, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: TwitchUiColors.textPrimary,
          fontSize: compact
              ? TwitchUiFontSize.body
              : TwitchUiFontSize.heading,
          fontWeight: TwitchUiFontWeight.strong,
          height: 1.0,
        ),
      ),
    );
  }
}

class _WatchStreamTitleText extends StatelessWidget {
  final String title;
  final bool compact;

  const _WatchStreamTitleText({required this.title, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: Text(
        title,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: TwitchUiColors.textSecondary,
          fontSize: compact
              ? TwitchUiFontSize.meta
              : TwitchUiFontSize.bodyCompact,
          fontWeight: TwitchUiFontWeight.medium,
          height: 1.0,
        ),
      ),
    );
  }
}

class _WatchChannelAvatar extends StatelessWidget {
  final String imageUrl;
  final String channelLogin;
  final double size;

  const _WatchChannelAvatar({
    required this.imageUrl,
    required this.channelLogin,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    final fallbackLetter = channelLogin.trim().isEmpty
        ? 'T'
        : channelLogin.trim().characters.first.toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _WatchAvatarImage(
          imageUrl: cleanUrl,
          fallbackLetter: fallbackLetter,
          size: size,
        ),
        _WatchLiveStatusDot(size: size),
      ],
    );
  }
}

class _WatchAvatarImage extends StatelessWidget {
  final String imageUrl;
  final String fallbackLetter;
  final double size;

  const _WatchAvatarImage({
    required this.imageUrl,
    required this.fallbackLetter,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TwitchUiColors.surfaceInteractive,
        border: Border.all(color: TwitchUiColors.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? _WatchAvatarFallbackLetter(letter: fallbackLetter, size: size)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: (size * 2).round(),
              cacheHeight: (size * 2).round(),
              errorBuilder: (_, _, _) => _WatchAvatarFallbackLetter(
                letter: fallbackLetter,
                size: size,
              ),
            ),
    );
  }
}

class _WatchAvatarFallbackLetter extends StatelessWidget {
  final String letter;
  final double size;

  const _WatchAvatarFallbackLetter({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: TwitchUiColors.textPrimary,
          fontSize: size * 0.42,
          fontWeight: TwitchUiFontWeight.heavy,
        ),
      ),
    );
  }
}

class _WatchLiveStatusDot extends StatelessWidget {
  final double size;

  const _WatchLiveStatusDot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -1,
      bottom: -1,
      child: Container(
        width: size * 0.30,
        height: size * 0.30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TwitchUiColors.live,
          border: Border.all(color: TwitchUiColors.surfaceBase, width: 2),
        ),
      ),
    );
  }
}

String _formatViewerCount(BuildContext context, int value) {
  final l10n = context.vio;
  if (l10n.isEnglish) {
    if (value >= 1000000) {
      final text = (value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1);
      return '${text.replaceFirst(RegExp(r'\.0$'), '')}M viewers';
    }
    if (value >= 1000) {
      final text = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
      return '${text.replaceFirst(RegExp(r'\.0$'), '')}k viewers';
    }
    return '$value viewers';
  }
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}萬人';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}k 人';
  }
  return '$value 人';
}

class _WatchInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? copyText;
  final bool compact;
  final double? maxWidth;

  const _WatchInfoPill({
    required this.icon,
    required this.label,
    this.copyText,
    this.compact = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final canCopy = copyText != null && copyText!.trim().isNotEmpty;
    return Tooltip(
      message: canCopy ? '${context.vio.t('點擊複製：')}$label' : label,
      child: Material(
        color: TwitchUiColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
          onTap: canCopy
              ? () async {
                  await Clipboard.setData(ClipboardData(text: copyText!.trim()));
                  if (!context.mounted) return;
                  showTwitchNotice(
                    context,
                    '${context.vio.t('已複製：')}$label',
                    tone: TwitchNoticeTone.success,
                  );
                }
              : null,
          child: Container(
            height: compact ? 22 : 26,
            constraints: BoxConstraints(maxWidth: maxWidth ?? 150),
            padding: const EdgeInsets.symmetric(
              horizontal: TwitchUiSpacing.space4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
              border: Border.all(color: TwitchUiColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: compact ? 12 : 14,
                  color: TwitchUiColors.textMuted,
                ),
                const SizedBox(width: TwitchUiSpacing.space4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TwitchUiColors.textSecondary,
                      fontSize: compact
                          ? TwitchUiFontSize.micro
                          : TwitchUiFontSize.meta,
                      fontWeight: TwitchUiFontWeight.medium,
                      height: 1.0,
                    ),
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
