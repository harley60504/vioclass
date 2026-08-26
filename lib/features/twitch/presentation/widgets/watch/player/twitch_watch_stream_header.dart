import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../shared/twitch_glass.dart';

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
    final size = math.min(height - 12.0, tiny ? 36.0 : 40.0);

    return Tooltip(
      message: data.channelLabel,
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(tiny ? 14 : 16),
        backgroundColor: Colors.black.withValues(alpha: 0.42),
        borderColor: Colors.white.withValues(alpha: 0.10),
        blurSigma: 0,
        boxShadow: const <BoxShadow>[],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenChannel,
            borderRadius: BorderRadius.circular(tiny ? 14 : 16),
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
    final avatarSize = compact ? 34.0 : 44.0;

    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(compact ? 16 : 20),
      backgroundColor: Colors.black.withValues(alpha: 0.46),
      borderColor: Colors.white.withValues(alpha: 0.11),
      blurSigma: 0,
      boxShadow: const <BoxShadow>[],
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 5 : 9,
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenChannel,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: _WatchChannelAvatar(
                      imageUrl: data.profileImageUrl,
                      channelLogin: data.channelLogin,
                      size: avatarSize,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: _WatchStreamHeaderTextBlock(
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
    final language = metadata.language.trim();

    return _WatchStreamHeaderData(
      channelLogin: channelLogin,
      channelLabel: channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
      streamTitle: metadata.streamTitle.trim(),
      gameName: metadata.gameName.trim(),
      viewerCount: metadata.viewerCount,
      profileImageUrl: metadata.profileImageUrl.trim(),
      language: language,
      languageLabel: language.toUpperCase(),
    );
  }
}

class _WatchStreamHeaderTextBlock extends StatelessWidget {
  final _WatchStreamHeaderData data;
  final bool compact;

  const _WatchStreamHeaderTextBlock({
    required this.data,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WatchStreamHeaderMainRow(data: data, compact: compact),
        if (data.streamTitle.isNotEmpty) ...[
          SizedBox(height: compact ? 3 : 4),
          _WatchStreamTitleText(title: data.streamTitle, compact: compact),
        ],
      ],
    );
  }
}

class _WatchStreamHeaderMainRow extends StatelessWidget {
  final _WatchStreamHeaderData data;
  final bool compact;

  const _WatchStreamHeaderMainRow({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: _WatchChannelNameText(
            label: data.channelLabel,
            compact: compact,
          ),
        ),
        if (data.viewerCount != null && data.viewerCount! > 0) ...[
          SizedBox(width: compact ? 5 : 7),
          _WatchInfoPill(
            icon: Icons.visibility_rounded,
            label: _formatViewerCount(data.viewerCount!),
            compact: compact,
          ),
        ],
        if (data.gameName.isNotEmpty) ...[
          SizedBox(width: compact ? 5 : 7),
          _WatchInfoPill(
            icon: Icons.sports_esports_rounded,
            label: data.gameName,
            copyText: data.gameName,
            compact: compact,
          ),
        ],
        if (data.languageLabel.isNotEmpty) ...[
          SizedBox(width: compact ? 5 : 7),
          _WatchInfoPill(
            icon: Icons.translate_rounded,
            label: data.languageLabel,
            copyText: data.language,
            compact: compact,
            maxWidth: compact ? 62 : 72,
          ),
        ],
      ],
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
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 13.5 : 17,
          fontWeight: FontWeight.w900,
          height: 1.05,
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
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white70,
          fontSize: compact ? 11.5 : 13,
          fontWeight: FontWeight.w800,
          height: 1.05,
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
        color: const Color(0xFF2A2236),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
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
          color: const Color(0xFF57F287),
          border: Border.all(color: const Color(0xDD0E0E10), width: 2),
        ),
      ),
    );
  }
}

String _formatViewerCount(int value) {
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
      message: canCopy ? '點擊複製：$label' : label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: canCopy
              ? () async {
                  await Clipboard.setData(
                    ClipboardData(text: copyText!.trim()),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已複製：$label')));
                }
              : null,
          child: Container(
            height: compact ? 24 : 28,
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? (compact ? 120 : 190),
            ),
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 13 : 15,
                  color: const Color(0xFFBF94FF),
                ),
                SizedBox(width: compact ? 4 : 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w900,
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
