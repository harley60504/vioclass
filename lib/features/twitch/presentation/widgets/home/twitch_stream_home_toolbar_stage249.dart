import 'package:flutter/material.dart';

import '../../pages/twitch_stream_home_models_stage249.dart';
import 'twitch_stream_home_account_menu_stage249.dart';

const Color _kTwitchPurple = Color(0xFF9146FF);
const Color _kTwitchPurpleLight = Color(0xFFBF94FF);
const Color _kSoftPanel = Color(0xB8221B32);

class TwitchStreamHomeToolbarStage249 extends StatelessWidget {
  final TwitchHomeSection selectedSection;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onShowGameMenu;
  final VoidCallback onShowLanguageMenu;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogin;
  final Future<void> Function() onOpenDropsConnector;
  final VoidCallback onTestAppNotification;
  final Future<void> Function() onLogout;

  const TwitchStreamHomeToolbarStage249({
    super.key,
    required this.selectedSection,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowGameMenu,
    required this.onShowLanguageMenu,
    required this.onRefresh,
    required this.onLogin,
    required this.onOpenDropsConnector,
    required this.onTestAppNotification,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        border: Border(
          bottom: BorderSide(color: _kTwitchPurple.withOpacity(0.22)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
          if (selectedSection == TwitchHomeSection.browse) ...<Widget>[
            TwitchStreamHomeToolbarIconButtonStage249(
              tooltip: '遊戲分類',
              icon: Icons.sports_esports_rounded,
              onPressed: onShowGameMenu,
            ),
            const SizedBox(width: 4),
          ],
          TwitchStreamHomeToolbarIconButtonStage249(
            tooltip: '語言篩選',
            icon: Icons.tune_rounded,
            onPressed: onShowLanguageMenu,
          ),
          const SizedBox(width: 4),
          TwitchStreamHomeToolbarIconButtonStage249(
            tooltip: '重新整理',
            icon: Icons.refresh_rounded,
            onPressed: () => onRefresh(),
          ),
          const SizedBox(width: 4),
          TwitchStreamHomeAccountMenuStage249(
            onLogin: onLogin,
            onRefresh: onRefresh,
            onOpenDropsConnector: onOpenDropsConnector,
            onTestAppNotification: onTestAppNotification,
            onLogout: onLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: selectedSection == TwitchHomeSection.following
              ? '搜尋追隨直播'
              : '搜尋直播、遊戲或實況主',
          hintStyle: const TextStyle(
            color: Colors.white38,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white54,
            size: 21,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? IconButton(
                  tooltip: '清除搜尋',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearSearch,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 19,
                  ),
                )
              : null,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class TwitchStreamHomeToolbarIconButtonStage249 extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const TwitchStreamHomeToolbarIconButtonStage249({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _kSoftPanel,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              icon,
              color: onPressed == null ? Colors.white30 : _kTwitchPurpleLight,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
