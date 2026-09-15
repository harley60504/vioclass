import 'package:flutter/material.dart';

import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_chrome_button.dart';

/// Compatibility wrapper for existing player call sites.
class RoundIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double glowOpacity;
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.iconColor = TwitchUiColors.textPrimary,
    this.backgroundColor,
    this.borderColor,
    this.glowOpacity = 0.18,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerChromeButton(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      foregroundColor: iconColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      compact: compact,
      tiny: tiny,
      height: height,
    );
  }
}

class PlainIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final bool dense;

  const PlainIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = TwitchUiControlSize.icon,
    this.active = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final hitSize = dense
        ? (size + 16).clamp(
            TwitchUiControlSize.hitCompact,
            TwitchUiControlSize.hitLarge,
          ).toDouble()
        : TwitchUiControlSize.hitLarge;

    return IconButton(
      tooltip: tooltip,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: hitSize, height: hitSize),
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return TwitchUiColors.hoverOverlay;
          }
          if (active) return TwitchUiColors.selectedOverlay;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return TwitchUiColors.disabledForeground;
          }
          return active
              ? TwitchUiColors.primarySoft
              : TwitchUiColors.textPrimary;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          ),
        ),
      ),
      icon: Icon(icon, size: size),
    );
  }
}
