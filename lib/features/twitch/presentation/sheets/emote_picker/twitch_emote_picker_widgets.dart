// PATCH VERSION: twitch_emote_picker_widgets_stage175
//
// Shared visual widgets for Twitch emote picker sheets.

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
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onInsert,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF242429),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: emote.isZeroWidth
                  ? const Color(0xFFEAB308).withOpacity(0.55)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: TwitchOptimizedEmoteImage(
                        imageUrl: emote.imageUrl,
                        cacheSize: twitchEmoteGridCacheSize,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emote.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emote.providerLabel,
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                      if (emote.isZeroWidth) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'ZW',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFEAB308),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Positioned(
                top: -8,
                right: -8,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    favorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked ? null : onInsert,
        child: Opacity(
          opacity: locked ? 0.48 : 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF242429),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: locked
                    ? const Color(0xFFFFD166).withOpacity(0.32)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: TwitchOptimizedEmoteImage(
                          imageUrl: emote.imageUrl,
                          cacheSize: twitchEmoteGridCacheSize,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emote.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      locked ? 'LOCKED' : emote.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: locked ? const Color(0xFFFFD166) : Colors.white38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                    ),
                  ),
                ),
                if (locked)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: Color(0xFFFFD166),
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
