import 'package:flutter/material.dart';

import '../../theme/twitch_ui_tokens.dart';
import 'twitch_stream_home_account_menu.dart';

const Color _kSoftPanel = Color(0xB8221B32);

class TwitchStreamHomeToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowLanguageMenu;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenDropsConnector;
  final Future<void> Function() onOpenSettings;
  final bool forceTwoRows;

  const TwitchStreamHomeToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowLanguageMenu,
    required this.onRefresh,
    required this.onOpenDropsConnector,
    required this.onOpenSettings,
    this.forceTwoRows = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      TwitchStreamHomeToolbarIconButton(
        tooltip: '語言篩選',
        icon: Icons.tune_rounded,
        onPressed: onShowLanguageMenu,
      ),
      const SizedBox(width: 4),
      TwitchStreamHomeToolbarIconButton(
        tooltip: '重新整理',
        icon: Icons.refresh_rounded,
        onPressed: () => onRefresh(),
      ),
      const SizedBox(width: 4),
      TwitchStreamHomeToolbarIconButton(
        tooltip: 'Drops 連接',
        icon: Icons.card_giftcard_rounded,
        onPressed: () => onOpenDropsConnector(),
      ),
      const SizedBox(width: 4),
      TwitchStreamHomeAccountMenu(onOpenSettings: onOpenSettings),
    ];

    if (forceTwoRows) {
      return Container(
        height: 124,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.30),
          border: Border(
            bottom: BorderSide(
              color: TwitchUiColors.primary.withValues(alpha: 0.22),
            ),
          ),
        ),
        child: Column(
          children: <Widget>[
            SizedBox(height: 50, child: _buildSearchField()),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actions),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        border: Border(
          bottom: BorderSide(
            color: TwitchUiColors.primary.withValues(alpha: 0.22),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
          hintText: '搜尋追隨直播、頻道或實況主',
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

class TwitchStreamHomeToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const TwitchStreamHomeToolbarIconButton({
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(
              icon,
              color: onPressed == null
                  ? Colors.white30
                  : TwitchUiColors.primarySoft,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
