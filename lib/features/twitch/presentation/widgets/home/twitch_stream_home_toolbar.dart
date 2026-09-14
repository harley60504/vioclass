import 'package:flutter/material.dart';

import '../../pages/twitch_stream_home_models.dart';
import '../../localization/vioclass_localizations.dart';
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
                  _HomeSectionSwitcher(
                    selectedSection: selectedSection,
                    onSelectSection: onSelectSection,
                    compact: true,
                  ),
                  const SizedBox(width: TwitchUiSpacing.space8),
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
          _HomeSectionSwitcher(
            selectedSection: selectedSection,
            onSelectSection: onSelectSection,
          ),
          const SizedBox(width: TwitchUiSpacing.space12),
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
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('遊戲分類'),
        icon: Icons.sports_esports_rounded,
        compact: compact,
        onPressed: onShowGameMenu,
      ),
      const SizedBox(width: TwitchUiSpacing.space4),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('語言篩選'),
        icon: Icons.tune_rounded,
        compact: compact,
        onPressed: onShowLanguageMenu,
      ),
      const SizedBox(width: TwitchUiSpacing.space4),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('重新整理'),
        icon: Icons.refresh_rounded,
        compact: compact,
        onPressed: () => onRefresh(),
      ),
      const SizedBox(width: TwitchUiSpacing.space4),
      TwitchStreamHomeToolbarIconButton(
        tooltip: l10n.t('Drops 連接'),
        icon: Icons.card_giftcard_rounded,
        compact: compact,
        onPressed: () => onOpenDropsConnector(),
      ),
      const SizedBox(width: TwitchUiSpacing.space4),
      TwitchStreamHomeAccountMenu(
        onOpenSettings: onOpenSettings,
        compact: compact,
      ),
    ];
  }
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
      backgroundColor: TwitchUiColors.surfaceGlass,
      borderColor: TwitchUiColors.border,
      blurSigma: TwitchUiGlass.blurSoft,
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
    return TwitchGlassSurface(
      borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
      backgroundColor: TwitchUiColors.surfaceGlass,
      borderColor: TwitchUiColors.border,
      blurSigma: TwitchUiGlass.blurSoft,
      boxShadow: TwitchUiShadows.soft,
      padding: const EdgeInsets.all(TwitchUiSpacing.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TwitchHomeSection.values.map((section) {
          final selected = selectedSection == section;
          return Padding(
            padding: const EdgeInsets.only(right: TwitchUiSpacing.space2),
            child: Material(
              color: selected
                  ? TwitchUiColors.surfaceSelected
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
                onTap: () => onSelectSection(section),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact
                        ? TwitchUiSpacing.space8
                        : TwitchUiSpacing.space12,
                    vertical: TwitchUiSpacing.space8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section.icon,
                        size: compact ? 17 : 18,
                        color: selected
                            ? TwitchUiColors.primarySoft
                            : TwitchUiColors.textMuted,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: TwitchUiSpacing.space8),
                        Text(
                          section.localizedLabel(context),
                          style: TextStyle(
                            color: selected
                                ? TwitchUiColors.textPrimary
                                : TwitchUiColors.textSecondary,
                            fontSize: TwitchUiFontSize.bodyCompact,
                            fontWeight: TwitchUiFontWeight.strong,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class TwitchStreamHomeToolbarIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  const TwitchStreamHomeToolbarIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 46.0;
    return Tooltip(
      message: tooltip,
      child: TwitchGlassSurface(
        borderRadius: BorderRadius.circular(TwitchUiRadius.pill),
        backgroundColor: TwitchUiColors.surfaceGlass,
        borderColor: TwitchUiColors.border,
        blurSigma: TwitchUiGlass.blurSoft,
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
