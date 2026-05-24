import 'package:flutter/material.dart';

import '../../pages/twitch_stream_home_models_stage249.dart';

class TwitchStreamHomeBottomNavigationStage254 extends StatelessWidget {
  final TwitchHomeSection selectedSection;
  final ValueChanged<TwitchHomeSection> onSelectSection;

  const TwitchStreamHomeBottomNavigationStage254({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedSection == TwitchHomeSection.following ? 0 : 1,
        onDestinationSelected: (index) {
          onSelectSection(
            index == 0 ? TwitchHomeSection.following : TwitchHomeSection.browse,
          );
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '追隨',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: '瀏覽',
          ),
        ],
      ),
    );
  }
}
