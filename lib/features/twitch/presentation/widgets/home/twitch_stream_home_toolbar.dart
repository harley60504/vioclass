import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../pages/twitch_stream_home_models.dart';
import '../../localization/vioclass_localizations.dart';
import '../../settings/twitch_app_settings_launcher.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_centered_text_field.dart';
import '../shared/twitch_glass.dart';
import 'twitch_stream_home_account_menu.dart';

class TwitchStreamHomeToolbar extends StatelessWidget {
  final TwitchHomeSection selectedSection;
  final ValueChanged<TwitchHomeSection> onSelectSection;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onShowGameMenu;
  final VoidCallback onShowLanguageMenu;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenDropsConnector;
  final Future<void> Function() onOpenSettings;
  final bool forceTwoRows;
  final bool showSectionSwitcher;

  const TwitchStreamHomeToolbar({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowGameMenu,
    required this.onShowLanguageMenu,
    required this.onRefresh,
    required this.onOpenDropsConnector,
    required this.onOpenSettings,
    this.forceTwoRows = false,
    this.showSectionSwitcher = true,
  });

  @override
  Widget build(BuildContext context) {
    if (forceTwoRows) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FloatingSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
            onClear: onClearSearch,
          ),
          const SizedBox(height: TwitchUiSpacing.space8),
          SizedBox(
            height: 44,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (showSectionSwitcher) ...[
                    _HomeSectionSwitcher(
                      selectedSection: selectedSection,
                      onSelectSection: onSelectSection,
                      compact: true,
                    ),
                    const SizedBox(width: TwitchUiSpacing.space8),
                  ],
                  ..._buildActions(context, compact: true),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          if (showSectionSwitcher) ...[
            _HomeSectionSwitcher(
              selectedSection: selectedSection,
              onSelectSection: onSelectSection,
            ),
            const SizedBox(width: TwitchUiSpacing.space12),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: _FloatingSearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
              ),
            ),
          ),
          const SizedBox(width: TwitchUiSpacing.space12),
          ..._buildActions(context),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, {bool compact = false}) {
    final l10n = context.vio;
    return <Widget>[
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) ...[
        PopupMenuButton<String>(
          tooltip: l10n.t('私訊與更新'),
          icon: AnimatedBuilder(
            animation: twitchAppSettingsLauncher,
            builder: (context, _) => Badge(
              isLabelVisible: twitchAppSettingsLauncher.whisperUnreadCount > 0,
              label: Text('${twitchAppSettingsLauncher.whisperUnreadCount}'),
              child: const Icon(Icons.more_horiz),
            ),
          ),
          onSelected: (value) {
            if (value == 'whispers') {
              twitchAppSettingsLauncher.openWhispers();
            } else {
              twitchAppSettingsLauncher.openUpdate();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'whispers',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.t('Twitch 私訊')),
                  if (twitchAppSettingsLauncher.whisperUnreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Badge.count(
                      count: twitchAppSettingsLauncher.whisperUnreadCount,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(value: 'updates', child: Text(l10n.t('App 更新'))),
          ],
        ),
        const SizedBox(width: TwitchUiSpacing.space8),
      ],
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('遊戲分類'),
        icon: Icons.sports_esports_rounded,
        compact: compact,
        onPressed: onShowGameMenu,
      ),
      const SizedBox(width: TwitchUiSpacing.space8),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('語言篩選'),
        icon: Icons.tune_rounded,
        compact: compact,
        onPressed: onShowLanguageMenu,
      ),
      const SizedBox(width: TwitchUiSpacing.space8),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('重新整理'),
        icon: Icons.refresh_rounded,
        compact: compact,
        onPressed: () => onRefresh(),
      ),
      const SizedBox(width: TwitchUiSpacing.space8),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('Drops 連接'),
        icon: Icons.card_giftcard_rounded,
        compact: compact,
        onPressed: () => onOpenDropsConnector(),
      ),
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) ...[
        const SizedBox(width: TwitchUiSpacing.space8),
        TwitchStreamHomeAccountMenu(
          onOpenSettings: onOpenSettings,
          compact: compact,
        ),
      ],
    ];
  }
}

Color _homeGlassFill({double alpha = 0.34}) {
  return TwitchUiColors.surfacePanel.withValues(alpha: alpha);
}

Color _homeGlassBorder({double alpha = 0.10}) {
  return Colors.white.withValues(alpha: alpha);
}

class _FloatingSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _FloatingSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
      backgroundColor: _homeGlassFill(alpha: 0.38),
      borderColor: _homeGlassBorder(alpha: 0.11),
      blurSigma: TwitchUiGlass.blurStrong,
      boxShadow: TwitchUiShadows.soft,
      child: TwitchCenteredTextField(
        height: 50,
        radius: TwitchUiRadius.lg,
        controller: controller,
        hintText: l10n.t('搜尋直播、遊戲或實況主'),
        prefixIcon: Icons.search_rounded,
        onChanged: onChanged,
        fontSize: 14,
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        hintColor: TwitchUiColors.textMuted,
        iconColor: TwitchUiColors.textSecondary,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                tooltip: l10n.t('清除搜尋'),
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: TwitchUiColors.textMuted,
                  size: 18,
                ),
              )
            : null,
      ),
    );
  }
}

class _HomeSectionSwitcher extends StatelessWidget {
  final TwitchHomeSection selectedSection;
  final ValueChanged<TwitchHomeSection> onSelectSection;
  final bool compact;

  const _HomeSectionSwitcher({
    required this.selectedSection,
    required this.onSelectSection,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final sections = TwitchHomeSection.values;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const SizedBox(width: TwitchUiSpacing.space8),
          _HomeSectionButton(
            section: sections[index],
            selected: selectedSection == sections[index],
            compact: compact,
            onPressed: () => onSelectSection(sections[index]),
          ),
        ],
      ],
    );
  }
}

class _HomeSectionButton extends StatelessWidget {
  final TwitchHomeSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  const _HomeSectionButton({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TwitchStreamHomeToolbarIconButton(
      tooltip: section.localizedLabel(context),
      icon: section.icon,
      selected: selected,
      compact: compact,
      onPressed: onPressed,
    );
  }
}

class TwitchStreamHomeToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;
  final bool selected;

  const TwitchStreamHomeToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 46.0;
    return Tooltip(
      message: tooltip,
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        backgroundColor: selected
            ? TwitchUiColors.primary.withValues(alpha: 0.22)
            : _homeGlassFill(alpha: 0.30),
        borderColor: selected
            ? TwitchUiColors.primarySoft.withValues(alpha: 0.28)
            : _homeGlassBorder(alpha: 0.09),
        blurSigma: TwitchUiGlass.blurStrong,
        boxShadow: TwitchUiShadows.soft,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                color: onPressed == null
                    ? TwitchUiColors.disabledForeground
                    : selected
                    ? TwitchUiColors.primarySoft
                    : TwitchUiColors.textSecondary,
                size: compact ? 19 : 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
