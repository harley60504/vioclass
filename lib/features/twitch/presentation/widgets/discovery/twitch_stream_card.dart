import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';


const double twitchStreamCardGridHorizontalPadding = 36;
const double twitchStreamCardGridSpacing = 16;
const double twitchStreamCardGridMaxCrossAxisExtent = 380;

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
    final radius = BorderRadius.circular(18);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: colors.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: colors.border),
            ),
            child: Column(
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
                          12,
                          compact ? 7 : 10,
                          12,
                          compact ? 8 : 11,
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
    final thumbnailUrl = _thumbnailUrl(stream, width: 520, height: 292);
    final viewerCount = _readInt(stream, const <String>['viewerCount', 'viewer_count']);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _ThumbnailFallback(colors: colors),
            )
          else
            _ThumbnailFallback(colors: colors),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.22),
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
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  final _StreamCardColors colors;

  const _ThumbnailFallback({required this.colors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.thumbnailFallback,
      ),
      child: Icon(
        Icons.live_tv_rounded,
        color: colors.mutedText,
        size: 36,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE91916),
        borderRadius: BorderRadius.circular(7),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFE91916).withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
      height: compact ? 26 : 30,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colors.gameBadge,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.gameBorder),
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
      height: compact ? 26 : 30,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(10),
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
    final avatarSize = compact ? 26.0 : 30.0;

    return Row(
      children: [
        _Avatar(
          imageUrl: profileImageUrl,
          colors: colors,
          size: avatarSize,
        ),
        const SizedBox(width: 8),
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
    final url = imageUrl.trim();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.softFill,
        shape: BoxShape.circle,
        border: Border.all(color: colors.border),
      ),
      child: url.isEmpty
          ? Icon(
              Icons.person_rounded,
              color: colors.mutedText,
              size: size * 0.57,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_rounded,
                color: colors.mutedText,
                size: size * 0.57,
              ),
            ),
    );
  }
}

class _StreamCardColors {
  final Color card;
  final Color border;
  final Color shadow;
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
    required this.card,
    required this.border,
    required this.shadow,
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
      card: const Color(0xFF18181F),
      border: Colors.white.withValues(alpha: 0.085),
      shadow: Colors.black.withValues(alpha: 0.40),
      thumbnailFallback: const Color(0xFF111116),
      softFill: Colors.white.withValues(alpha: 0.055),
      primaryText: Colors.white,
      secondaryText: Colors.white.withValues(alpha: 0.74),
      mutedText: Colors.white.withValues(alpha: 0.42),
      accent: const Color(0xFFBF94FF),
      gameBadge: twitchPurple.withValues(alpha: 0.18),
      gameBorder: twitchPurple.withValues(alpha: 0.42),
      gameText: const Color(0xFFE4D3FF),
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
