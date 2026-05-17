// PATCH VERSION: twitch_stream_card_stage189b_obvious_glass_cards

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../shared/twitch_cached_image_layer.dart';

const double twitchStreamCardGridHorizontalPadding = 36;
const double twitchStreamCardGridSpacing = 16;
const double twitchStreamCardGridMaxCrossAxisExtent = 380;

const int _thumbnailMinPhysicalWidth = 320;
const int _thumbnailMaxPhysicalWidth = 480;
const int _avatarPhysicalSize = 64;

/// Returns a stable tile height for the discovery stream grid.
///
/// Normal Flutter sliver grids do not let a child auto-expand its own row.
/// Instead, we calculate a responsive `mainAxisExtent` from the current
/// viewport width so tablet / split-view layouts get taller cards instead of
/// clipping the streamer footer.
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

  // Keep a real fixed area for title + game/language row + streamer footer.
  // Narrow cards need slightly more vertical room because text wraps/truncates
  // less gracefully at tablet widths.
  final infoHeight = cardWidth < 330
      ? 174.0
      : cardWidth < 370
          ? 164.0
          : 154.0;

  return (thumbnailHeight + infoHeight).clamp(306.0, 392.0).toDouble();
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
    final colors = _StreamCardColors.fromContext(context);
    final radius = BorderRadius.circular(22);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.purpleGlow,
            blurRadius: 28,
            spreadRadius: -8,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: colors.shadow,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.cardTop,
                  colors.cardMiddle,
                  colors.cardBottom,
                ],
              ),
              border: Border.all(color: colors.border, width: 1.15),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          const Color(0xFF9146FF).withOpacity(0.0),
                          const Color(0xFFBF94FF).withOpacity(0.70),
                          const Color(0xFF9146FF).withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StreamThumbnail(
                      stream: stream,
                      colors: colors,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 130;
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              13,
                              compact ? 8 : 11,
                              13,
                              compact ? 9 : 12,
                            ),
                            child: _StreamInfo(
                              stream: stream,
                              colors: colors,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamThumbnail extends StatelessWidget {
  final TwitchLiveStream stream;
  final _StreamCardColors colors;

  const _StreamThumbnail({
    required this.stream,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final viewerCount = _readInt(stream, const <String>['viewerCount', 'viewer_count']);

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
          final thumbnailUrl = _thumbnailUrl(
            stream,
            width: imageWidth,
            height: imageHeight,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              TwitchCachedImageLayer(
                imageUrl: thumbnailUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                cacheWidth: imageWidth,
                cacheHeight: imageHeight,
                fallbackColor: colors.thumbnailFallback,
                fallbackIcon: Icons.live_tv_rounded,
                fallbackIconColor: colors.mutedText,
                fallbackIconSize: 36,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withOpacity(0.06),
                      Colors.black.withOpacity(0.18),
                      Colors.black.withOpacity(0.42),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _LiveBadge(colors: colors),
              ),
              if (viewerCount > 0)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _ViewerBadge(
                    viewerCount: viewerCount,
                    colors: colors,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final _StreamCardColors colors;

  const _LiveBadge({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE91916),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE91916).withOpacity(0.48),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  final int viewerCount;
  final _StreamCardColors colors;

  const _ViewerBadge({
    required this.viewerCount,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '${_formatViewerCount(viewerCount)} viewers',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StreamInfo extends StatelessWidget {
  final TwitchLiveStream stream;
  final _StreamCardColors colors;

  const _StreamInfo({
    required this.stream,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final title = _readString(stream, const <String>['title']);
    final gameName = _readString(stream, const <String>['gameName', 'game_name']);
    final userName = _readString(stream, const <String>['userName', 'user_name', 'displayName']);
    final userLogin = _readString(stream, const <String>['userLogin', 'user_login', 'channelLogin']);
    final profileImageUrl = _readString(stream, const <String>['profileImageUrl', 'profile_image_url']);
    final language = _readString(stream, const <String>['language']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;
        final tight = height < 104;
        final compact = height < 124;
        final titleMaxLines = tight ? 1 : 2;
        final titleFontSize = tight ? 12.1 : compact ? 12.6 : 13.2;
        final gapAfterTitle = tight ? 4.0 : compact ? 5.0 : 8.0;
        final gapAfterMeta = tight ? 5.0 : compact ? 6.0 : 10.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? 'Untitled stream' : title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primaryText,
                fontSize: titleFontSize,
                height: 1.13,
                fontWeight: FontWeight.w900,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            SizedBox(height: gapAfterTitle),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _GameBadge(
                    gameName: gameName.isEmpty ? '未分類' : gameName,
                    colors: colors,
                    compact: compact,
                  ),
                ),
                if (language.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _LanguageBadge(
                    language: language,
                    colors: colors,
                    compact: compact,
                  ),
                ],
              ],
            ),
            SizedBox(height: gapAfterMeta),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _StreamerFooter(
                  profileImageUrl: profileImageUrl,
                  displayName: userName.isEmpty ? userLogin : userName,
                  login: userLogin,
                  colors: colors,
                  compact: compact,
                  showLogin: !tight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GameBadge extends StatelessWidget {
  final String gameName;
  final _StreamCardColors colors;
  final bool compact;

  const _GameBadge({
    required this.gameName,
    required this.colors,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 27 : 31,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.gameBadge,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.gameBorder, width: 1.1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF9146FF).withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_esports_rounded,
            color: colors.accent,
            size: compact ? 13 : 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              gameName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.gameText,
                fontSize: compact ? 11.2 : 12,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  final String language;
  final _StreamCardColors colors;
  final bool compact;

  const _LanguageBadge({
    required this.language,
    required this.colors,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 27 : 31,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        language.toUpperCase(),
        style: TextStyle(
          color: colors.secondaryText,
          fontSize: compact ? 10 : 10.5,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StreamerFooter extends StatelessWidget {
  final String profileImageUrl;
  final String displayName;
  final String login;
  final _StreamCardColors colors;
  final bool compact;
  final bool showLogin;

  const _StreamerFooter({
    required this.profileImageUrl,
    required this.displayName,
    required this.login,
    required this.colors,
    required this.compact,
    required this.showLogin,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 27.0 : 31.0;

    return Row(
      children: [
        _Avatar(
          imageUrl: profileImageUrl,
          colors: colors,
          size: avatarSize,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty ? 'Unknown streamer' : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: compact ? 11.4 : 12.2,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (showLogin && login.isNotEmpty && login.toLowerCase() != displayName.toLowerCase()) ...[
                const SizedBox(height: 2),
                Text(
                  login,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: compact ? 9.8 : 10.6,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;
  final _StreamCardColors colors;
  final double size;

  const _Avatar({
    required this.imageUrl,
    required this.colors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.softFill,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF9146FF).withOpacity(0.20),
            blurRadius: 12,
          ),
        ],
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: imageUrl,
        size: size,
        cacheWidth: _avatarPhysicalSize,
        cacheHeight: _avatarPhysicalSize,
        fallbackColor: colors.softFill,
        fallbackIconColor: colors.mutedText,
        fallbackIconSize: size * 0.57,
      ),
    );
  }
}

class _StreamCardColors {
  final Color cardTop;
  final Color cardMiddle;
  final Color cardBottom;
  final Color border;
  final Color shadow;
  final Color purpleGlow;
  final Color thumbnailFallback;
  final Color softFill;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color accent;
  final Color gameBadge;
  final Color gameBorder;
  final Color gameText;

  const _StreamCardColors({
    required this.cardTop,
    required this.cardMiddle,
    required this.cardBottom,
    required this.border,
    required this.shadow,
    required this.purpleGlow,
    required this.thumbnailFallback,
    required this.softFill,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.accent,
    required this.gameBadge,
    required this.gameBorder,
    required this.gameText,
  });

  factory _StreamCardColors.fromContext(BuildContext _) {
    const twitchPurple = Color(0xFF9146FF);

    return _StreamCardColors(
      cardTop: const Color(0xFF23202D).withOpacity(0.98),
      cardMiddle: const Color(0xFF191922).withOpacity(0.96),
      cardBottom: const Color(0xFF15151C).withOpacity(0.98),
      border: twitchPurple.withOpacity(0.24),
      shadow: Colors.black.withOpacity(0.50),
      purpleGlow: twitchPurple.withOpacity(0.20),
      thumbnailFallback: const Color(0xFF111116),
      softFill: Colors.white.withOpacity(0.075),
      primaryText: Colors.white,
      secondaryText: Colors.white.withOpacity(0.78),
      mutedText: Colors.white.withOpacity(0.46),
      accent: const Color(0xFFBF94FF),
      gameBadge: twitchPurple.withOpacity(0.26),
      gameBorder: twitchPurple.withOpacity(0.58),
      gameText: const Color(0xFFF0E7FF),
    );
  }
}

String _thumbnailUrl(
  TwitchLiveStream stream, {
  required int width,
  required int height,
}) {
  final dynamic value = stream;

  for (final fn in <String>['thumbnail', 'getThumbnailUrl', 'thumbnailUrlFor']) {
    try {
      final Object? url = switch (fn) {
        'thumbnail' => value.thumbnail(width: width, height: height),
        'getThumbnailUrl' => value.getThumbnailUrl(width: width, height: height),
        'thumbnailUrlFor' => value.thumbnailUrlFor(width: width, height: height),
        _ => null,
      };
      final text = url?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (_) {
      // Try the next known helper/field shape.
    }
  }

  final raw = _readString(stream, const <String>['thumbnailUrl', 'thumbnail_url']);
  if (raw.isEmpty) return '';

  return raw
      .replaceAll('{width}', width.toString())
      .replaceAll('{height}', height.toString());
}

String _readString(Object object, List<String> keys) {
  final dynamic value = object;

  for (final key in keys) {
    try {
      final Object? raw = switch (key) {
        'id' => value.id,
        'title' => value.title,
        'userName' => value.userName,
        'user_name' => value.user_name,
        'displayName' => value.displayName,
        'userLogin' => value.userLogin,
        'user_login' => value.user_login,
        'channelLogin' => value.channelLogin,
        'gameName' => value.gameName,
        'game_name' => value.game_name,
        'language' => value.language,
        'profileImageUrl' => value.profileImageUrl,
        'profile_image_url' => value.profile_image_url,
        'thumbnailUrl' => value.thumbnailUrl,
        'thumbnail_url' => value.thumbnail_url,
        _ => null,
      };
      final text = raw?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    } catch (_) {
      // Field does not exist on this model shape.
    }
  }

  return '';
}

int _readInt(Object object, List<String> keys) {
  final dynamic value = object;

  for (final key in keys) {
    try {
      final Object? raw = switch (key) {
        'viewerCount' => value.viewerCount,
        'viewer_count' => value.viewer_count,
        _ => null,
      };

      if (raw is int) return raw;
      if (raw is double) return raw.round();

      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    } catch (_) {
      // Field does not exist on this model shape.
    }
  }

  return 0;
}

String _formatViewerCount(int count) {
  if (count >= 10000) {
    final value = count / 10000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}萬';
  }

  if (count >= 1000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}K';
  }

  return count.toString();
}
