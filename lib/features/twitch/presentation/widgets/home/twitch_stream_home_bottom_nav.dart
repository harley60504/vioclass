import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../pages/twitch_stream_home_models.dart';
import '../../theme/twitch_ui_tokens.dart';
import 'twitch_stream_home_toolbar.dart';

class TwitchStreamHomeBottomNavigation extends StatelessWidget {
  final TwitchHomeSection selectedSection;
  final ValueChanged<TwitchHomeSection> onSelectSection;

  const TwitchStreamHomeBottomNavigation({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceBase,
        border: Border(top: BorderSide(color: TwitchUiColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(top: TwitchUiSpacing.space8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _BottomNavigationButton(
              label: l10n.t('追隨'),
              icon: Icons.favorite_rounded,
              selected: selectedSection == TwitchHomeSection.following,
              onPressed: () => onSelectSection(TwitchHomeSection.following),
            ),
            _BottomNavigationButton(
              label: l10n.t('瀏覽'),
              icon: Icons.explore_rounded,
              selected: selectedSection == TwitchHomeSection.browse,
              onPressed: () => onSelectSection(TwitchHomeSection.browse),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _BottomNavigationButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TwitchStreamHomeToolbarIconButton(
            tooltip: label,
            icon: icon,
            selected: selected,
            compact: true,
            onPressed: onPressed,
          ),
          const SizedBox(height: TwitchUiSpacing.space4),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? TwitchUiColors.primarySoft
                  : TwitchUiColors.textMuted,
              fontSize: TwitchUiFontSize.meta,
              fontWeight: selected
                  ? TwitchUiFontWeight.strong
                  : TwitchUiFontWeight.medium,
            ),
          ),
        ],
      ),
    );
  }
}
