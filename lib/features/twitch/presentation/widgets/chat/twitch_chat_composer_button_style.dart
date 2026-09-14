import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

ButtonStyle twitchChatComposerButtonStyle({
  required bool enabled,
  bool active = false,
  bool emphasized = false,
  EdgeInsetsGeometry padding = const EdgeInsets.all(10),
}) {
  final palette = TwitchUiColors.sheet.backplate;
  final background = emphasized
      ? (enabled ? TwitchUiColors.primary : TwitchUiColors.surfaceInteractive)
      : (active ? palette.fillActive : palette.fill);
  final foreground = emphasized
      ? (enabled
            ? TwitchUiColors.textOnAccent
            : TwitchUiColors.disabledForeground)
      : (active ? palette.foreground : palette.foregroundMuted);
  final border = emphasized
      ? (enabled
            ? TwitchUiColors.primarySoft.withValues(alpha: 0.34)
            : TwitchUiColors.borderSubtle)
      : (active ? palette.borderActive : palette.border);

  return IconButton.styleFrom(
    minimumSize: const Size(36, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: padding,
    backgroundColor: background,
    foregroundColor: foreground,
    disabledBackgroundColor: background,
    disabledForegroundColor: foreground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TwitchUiRadius.md),
      side: BorderSide(color: border),
    ),
  );
}
