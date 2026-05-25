// PATCH VERSION: twitch_ui_avatar_stage145
//
// Shared circular avatar used by player header, chat cards, pinned messages,
// sheets and discovery widgets. Prefer this instead of rebuilding avatar
// fallback logic in every UI file.

import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';
import 'twitch_cached_image_layer.dart';

class TwitchUiAvatar extends StatelessWidget {
  final String imageUrl;
  final String displayName;
  final double size;
  final Color? accentColor;
  final IconData? fallbackIcon;

  const TwitchUiAvatar({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.size = 32,
    this.accentColor,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? TwitchUiColors.primarySoft;
    final fallback = _fallbackText(displayName);
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(32, 160)
        .toInt();

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withValues(alpha: 0.82),
                TwitchUiColors.surfaceElevated,
              ],
            ),
          ),
          child: imageUrl.trim().isEmpty
              ? _TwitchUiAvatarFallback(
                  text: fallback,
                  icon: fallbackIcon,
                  size: size,
                )
              : TwitchCachedImageLayer(
                  imageUrl: imageUrl.trim(),
                  width: size,
                  height: size,
                  cacheWidth: cacheSize,
                  cacheHeight: cacheSize,
                  fit: BoxFit.cover,
                  fallbackColor: Colors.transparent,
                  errorWidget: _TwitchUiAvatarFallback(
                    text: fallback,
                    icon: fallbackIcon,
                    size: size,
                  ),
                ),
        ),
      ),
    );
  }

  String _fallbackText(String value) {
    final text = value.trim();
    if (text.isEmpty) return '?';
    return String.fromCharCode(text.runes.first).toUpperCase();
  }
}

class _TwitchUiAvatarFallback extends StatelessWidget {
  final String text;
  final IconData? icon;
  final double size;

  const _TwitchUiAvatarFallback({
    required this.text,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return Center(
        child: Icon(icon, color: TwitchUiColors.textPrimary, size: size * 0.48),
      );
    }

    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: TwitchUiColors.textPrimary,
          fontSize: (size * 0.42).clamp(11.0, 22.0),
          height: 1,
          fontWeight: TwitchUiFontWeight.heavy,
        ),
      ),
    );
  }
}
