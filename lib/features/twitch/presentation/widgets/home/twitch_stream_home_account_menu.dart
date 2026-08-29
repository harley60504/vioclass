import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';

class TwitchStreamHomeAccountMenu extends StatelessWidget {
  final Future<void> Function() onOpenSettings;

  const TwitchStreamHomeAccountMenu({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '設定',
      child: Material(
        color: const Color(0xB8221B32),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpenSettings(),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: TwitchUiColors.primarySoft,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
