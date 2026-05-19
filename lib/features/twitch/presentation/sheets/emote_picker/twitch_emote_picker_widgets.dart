// PATCH VERSION: twitch_emote_picker_widgets_stage225_unified_large_grid
//
// Shared visual widgets for Twitch emote picker sheets.
// Stage 216: make emote grid cards translucent instead of solid dark blocks.
// Stage 222: favorite toggling uses long press instead of a visible star button.
// Stage 223: normal emote picker grid cards show image + emote name only.
// Stage 225: unify locked/unlocked cards into the same large visible grid model.

import 'package:flutter/material.dart';

import '../../../models/emotes/twitch_official_emote.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import 'twitch_emote_picker_models.dart';

class TwitchEmotePickerTabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const TwitchEmotePickerTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchOfficialSubFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const TwitchOfficialSubFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchThirdPartyScopeFilterChip extends StatelessWidget {
  final TwitchThirdPartyEmoteScopeFilter scopeFilter;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const TwitchThirdPartyScopeFilterChip({
    super.key,
    required this.scopeFilter,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Text(
                scopeFilter.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchThirdPartyEmoteGridCard extends StatelessWidget {
  final TwitchThirdPartyEmote emote;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const TwitchThirdPartyEmoteGridCard({
    super.key,
    required this.emote,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return _TwitchUnifiedEmoteGridCard(
      imageUrl: emote.imageUrl,
      label: emote.name,
      favorite: favorite,
      locked: false,
      zeroWidth: emote.isZeroWidth,
      onTap: onInsert,
      onLongPress: onToggleFavorite,
    );
  }
}

class TwitchOfficialEmoteGridCard extends StatelessWidget {
  final TwitchOfficialEmote emote;
  final bool locked;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const TwitchOfficialEmoteGridCard({
    super.key,
    required this.emote,
    required this.locked,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return _TwitchUnifiedEmoteGridCard(
      imageUrl: emote.imageUrl,
      label: emote.name,
      favorite: favorite,
      locked: locked,
      zeroWidth: false,
      onTap: locked ? null : onInsert,
      onLongPress: onToggleFavorite,
    );
  }
}

class _TwitchUnifiedEmoteGridCard extends StatelessWidget {
  final String imageUrl;
  final String label;
  final bool favorite;
  final bool locked;
  final bool zeroWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _TwitchUnifiedEmoteGridCard({
    required this.imageUrl,
    required this.label,
    required this.favorite,
    required this.locked,
    required this.zeroWidth,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip = favorite ? '長按取消收藏' : '長按加入收藏';
    final borderColor = favorite
        ? const Color(0xFFEAB308).withOpacity(0.78)
        : locked
            ? const Color(0xFFFFD166).withOpacity(0.46)
            : zeroWidth
                ? const Color(0xFFEAB308).withOpacity(0.46)
                : const Color(0xFF9146FF).withOpacity(0.34);

    return RepaintBoundary(
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 650),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF242429),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Opacity(
                          opacity: locked ? 0.70 : 1,
                          child: TwitchOptimizedEmoteImage(
                            imageUrl: imageUrl,
                            cacheSize: 132,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (favorite)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: Color(0xFFEAB308),
                    ),
                  ),
                if (locked)
                  const Positioned(
                    right: 0,
                    bottom: 20,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 17,
                      color: Color(0xFFFFD166),
                    ),
                  ),
                if (zeroWidth)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Text(
                      'ZW',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFFEAB308),
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

class TwitchOptimizedEmoteImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final int cacheSize;

  const TwitchOptimizedEmoteImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.cacheSize = twitchEmoteGridCacheSize,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.white54);
    }

    return RepaintBoundary(
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }
}
