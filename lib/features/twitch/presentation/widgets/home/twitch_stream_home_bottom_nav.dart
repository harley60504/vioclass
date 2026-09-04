import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../pages/twitch_stream_home_models.dart';

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
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedSection == TwitchHomeSection.following ? 0 : 1,
        onDestinationSelected: (index) {
          onSelectSection(
            index == 0 ? TwitchHomeSection.following : TwitchHomeSection.browse,
          );
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.favorite_border_rounded),
            selectedIcon: const Icon(Icons.favorite_rounded),
            label: l10n.t('追隨'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore_rounded),
            label: l10n.t('瀏覽'),
          ),
        ],
      ),
    );
  }
}
