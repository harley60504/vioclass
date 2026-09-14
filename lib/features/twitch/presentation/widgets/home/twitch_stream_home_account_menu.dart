import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_glass.dart';

class TwitchStreamHomeAccountMenu extends StatelessWidget {
  final Future<void> Function() onOpenSettings;
  final bool compact;

  const TwitchStreamHomeAccountMenu({
    super.key,
    required this.onOpenSettings,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 46.0;
    return Tooltip(
      message: context.vio.t('設定'),
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        backgroundColor: TwitchUiColors.surfacePanel.withValues(alpha: 0.30),
        borderColor: Colors.white.withValues(alpha: 0.09),
        blurSigma: TwitchUiGlass.blurStrong,
        boxShadow: TwitchUiShadows.soft,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpenSettings(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                Icons.settings_rounded,
                color: TwitchUiColors.textSecondary,
                size: compact ? 19 : 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
