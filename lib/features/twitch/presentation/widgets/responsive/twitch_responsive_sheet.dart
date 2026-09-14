import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../shared/twitch_text_field.dart';

enum TwitchUnifiedSheetSize { compact, medium, large, wide }

class TwitchUnifiedSheetSizeSpec {
  final double maxWidth;
  final double portraitHeightFactor;
  final double landscapeHeightFactor;

  const TwitchUnifiedSheetSizeSpec({
    required this.maxWidth,
    required this.portraitHeightFactor,
    required this.landscapeHeightFactor,
  });
}

extension TwitchUnifiedSheetSizeSpecResolver on TwitchUnifiedSheetSize {
  TwitchUnifiedSheetSizeSpec get spec {
    switch (this) {
      case TwitchUnifiedSheetSize.compact:
        return const TwitchUnifiedSheetSizeSpec(
          maxWidth: 560,
          portraitHeightFactor: 0.68,
          landscapeHeightFactor: 0.90,
        );
      case TwitchUnifiedSheetSize.medium:
        return const TwitchUnifiedSheetSizeSpec(
          maxWidth: 680,
          portraitHeightFactor: 0.74,
          landscapeHeightFactor: 0.94,
        );
      case TwitchUnifiedSheetSize.large:
        return const TwitchUnifiedSheetSizeSpec(
          maxWidth: 760,
          portraitHeightFactor: 0.78,
          landscapeHeightFactor: 0.96,
        );
      case TwitchUnifiedSheetSize.wide:
        return const TwitchUnifiedSheetSizeSpec(
          maxWidth: 840,
          portraitHeightFactor: 0.80,
          landscapeHeightFactor: 0.98,
        );
    }
  }
}

TwitchUnifiedSheetSizeSpec _resolveUnifiedSheetSize({
  required TwitchUnifiedSheetSize size,
  double? maxWidth,
  double? portraitHeightFactor,
  double? landscapeHeightFactor,
}) {
  final base = size.spec;
  return TwitchUnifiedSheetSizeSpec(
    maxWidth: maxWidth ?? base.maxWidth,
    portraitHeightFactor: portraitHeightFactor ?? base.portraitHeightFactor,
    landscapeHeightFactor: landscapeHeightFactor ?? base.landscapeHeightFactor,
  );
}

Future<T?> showTwitchResponsiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  TwitchUnifiedSheetSize size = TwitchUnifiedSheetSize.medium,
  double? maxWidth,
  double? portraitHeightFactor,
  double? landscapeHeightFactor,
  Color backgroundColor = TwitchUiColors.surfacePanel,
  bool enableDrag = false,
}) {
  final resolvedSize = _resolveUnifiedSheetSize(
    size: size,
    maxWidth: maxWidth,
    portraitHeightFactor: portraitHeightFactor,
    landscapeHeightFactor: landscapeHeightFactor,
  );
  final media = MediaQuery.of(context);
  final viewportSize = media.size;
  final aspectRatio = viewportSize.height <= 0
      ? 1.0
      : viewportSize.width / viewportSize.height;
  final landscapeCompact = aspectRatio >= 1.25 && viewportSize.height < 620;
  final keyboardOpen = media.viewInsets.bottom > 0;
  final availableDialogWidth = math.max(260.0, viewportSize.width - 20.0);
  final availableDialogHeight = math.max(
    180.0,
    viewportSize.height -
        media.padding.top -
        media.padding.bottom -
        (keyboardOpen ? 4.0 : 10.0),
  );
  final effectiveMaxWidth = math.min(
    resolvedSize.maxWidth,
    availableDialogWidth,
  );

  if (landscapeCompact) {
    return showDialog<T>(
      context: context,
      useSafeArea: false,
      barrierColor: TwitchUiColors.sheet.scrim,
      builder: (dialogContext) {
        return SafeArea(
          left: false,
          right: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            backgroundColor: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: effectiveMaxWidth,
                  maxHeight: math.min(
                    availableDialogHeight,
                    viewportSize.height * resolvedSize.landscapeHeightFactor,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TwitchUiRadius.xl),
                  child: Material(
                    color: backgroundColor,
                    child: builder(dialogContext),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    enableDrag: enableDrag,
    barrierColor: TwitchUiColors.sheet.scrim,
    builder: (sheetContext) {
      final insetBottom = MediaQuery.of(sheetContext).viewInsets.bottom;
      return SafeArea(
        left: false,
        right: false,
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: insetBottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: effectiveMaxWidth,
                maxHeight:
                    viewportSize.height * resolvedSize.portraitHeightFactor,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(TwitchUiRadius.xl),
                ),
                child: Material(
                  color: backgroundColor,
                  child: builder(sheetContext),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<T?> showTwitchUnifiedSheet<T>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required WidgetBuilder builder,
  String? subtitle,
  String? iconImageUrl,
  bool loading = false,
  Future<void> Function()? onRefresh,
  VoidCallback? onClose,
  bool showRefresh = true,
  bool showClose = true,
  List<Widget> trailing = const <Widget>[],
  TwitchUnifiedSheetSize size = TwitchUnifiedSheetSize.medium,
  double? maxWidth,
  double? portraitHeightFactor,
  double? landscapeHeightFactor,
  Color backgroundColor = TwitchUiColors.surfacePanel,
  bool enableDrag = false,
}) {
  final refreshHandler = onRefresh;
  return showTwitchResponsiveSheet<T>(
    context: context,
    size: size,
    maxWidth: maxWidth,
    portraitHeightFactor: portraitHeightFactor,
    landscapeHeightFactor: landscapeHeightFactor,
    backgroundColor: backgroundColor,
    enableDrag: enableDrag,
    builder: (sheetContext) {
      return TwitchUnifiedSheetScaffold(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconImageUrl: iconImageUrl,
        loading: loading,
        onRefresh: refreshHandler == null
            ? null
            : () => unawaited(refreshHandler()),
        onClose: onClose ?? () => Navigator.of(sheetContext).maybePop(),
        showRefresh: showRefresh,
        showClose: showClose,
        trailing: trailing,
        child: builder(sheetContext),
      );
    },
  );
}

class TwitchUnifiedSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? iconImageUrl;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback? onClose;
  final bool showRefresh;
  final bool showClose;
  final Widget child;
  final List<Widget> trailing;

  const TwitchUnifiedSheetScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.iconImageUrl,
    this.loading = false,
    this.onRefresh,
    this.onClose,
    this.showRefresh = true,
    this.showClose = true,
    this.trailing = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TwitchUiColors.surfacePanel,
        border: Border.all(color: TwitchUiColors.border),
        boxShadow: TwitchUiShadows.floating,
      ),
      child: SizedBox.expand(
        child: Column(
          children: [
            TwitchUnifiedSheetHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              iconImageUrl: iconImageUrl,
              loading: loading,
              onRefresh: onRefresh,
              onClose: onClose,
              showRefresh: showRefresh,
              showClose: showClose,
              trailing: trailing,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class TwitchUnifiedSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? iconImageUrl;
  final bool loading;
  final VoidCallback? onRefresh;
  final VoidCallback? onClose;
  final bool showRefresh;
  final bool showClose;
  final List<Widget> trailing;

  const TwitchUnifiedSheetHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.iconImageUrl,
    this.loading = false,
    this.onRefresh,
    this.onClose,
    this.showRefresh = true,
    this.showClose = true,
    this.trailing = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final subtitleText = subtitle?.trim();
    final iconUrl = iconImageUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: TwitchUiColors.divider)),
      ),
      child: Row(
        children: [
          _UnifiedSheetHeaderIcon(icon: icon, imageUrl: iconUrl),
          const SizedBox(width: TwitchUiSpacing.space12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TwitchUiColors.textPrimary,
                    fontSize: TwitchUiFontSize.heading,
                    height: 1.15,
                    fontWeight: TwitchUiFontWeight.strong,
                  ),
                ),
                if (subtitleText != null && subtitleText.isNotEmpty) ...[
                  const SizedBox(height: TwitchUiSpacing.space2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TwitchUiColors.textMuted,
                      fontSize: TwitchUiFontSize.meta,
                      height: 1.2,
                      fontWeight: TwitchUiFontWeight.medium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: TwitchUiSpacing.space8),
            ...trailing,
          ],
          if (showRefresh) ...[
            const SizedBox(width: TwitchUiSpacing.space4),
            _SheetHeaderIconButton(
              tooltip: l10n.t('重新整理'),
              loading: loading,
              icon: Icons.refresh_rounded,
              onPressed: loading ? null : onRefresh,
            ),
          ],
          if (showClose)
            _SheetHeaderIconButton(
              tooltip: l10n.t('關閉'),
              icon: Icons.close_rounded,
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
            ),
        ],
      ),
    );
  }
}

class _SheetHeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _SheetHeaderIconButton({
    required this.tooltip,
    required this.icon,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: TwitchUiControlSize.hitCompact,
        height: TwitchUiControlSize.hitCompact,
        child: IconButton(
          onPressed: onPressed,
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 19),
          style: IconButton.styleFrom(
            backgroundColor: TwitchUiColors.surfaceInteractive,
            foregroundColor: TwitchUiColors.textSecondary,
            disabledForegroundColor: TwitchUiColors.disabledForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
              side: const BorderSide(color: TwitchUiColors.borderSubtle),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnifiedSheetHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String imageUrl;

  const _UnifiedSheetHeaderIcon({required this.icon, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: TwitchUiColors.surfaceSelected,
          borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
          border: Border.all(color: TwitchUiColors.borderInteractive),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TwitchUiRadius.xs),
          child: Image.network(
            imageUrl,
            width: 28,
            height: 28,
            cacheWidth: 56,
            cacheHeight: 56,
            filterQuality: FilterQuality.low,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackIcon(),
          ),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TwitchUiColors.surfaceSelected,
        borderRadius: BorderRadius.circular(TwitchUiRadius.sm),
        border: Border.all(color: TwitchUiColors.borderInteractive),
      ),
      child: Icon(icon, color: TwitchUiColors.primarySoft, size: 18),
    );
  }
}

class TwitchResponsiveSheetHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool loading;
  final VoidCallback? onRefresh;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;
  final bool compact;
  final bool showTitle;

  const TwitchResponsiveSheetHeader({
    super.key,
    this.title,
    this.subtitle,
    this.loading = false,
    this.onRefresh,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = '搜尋',
    this.compact = false,
    this.showTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final verticalPadding = compact ? 6.0 : 8.0;
    return Container(
      padding: EdgeInsets.fromLTRB(10, verticalPadding, 8, verticalPadding),
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: TwitchUiColors.divider)),
      ),
      child: Row(
        children: [
          if (showTitle && title != null && title!.isNotEmpty) ...[
            Expanded(
              flex: 2,
              child: Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TwitchUiColors.textPrimary,
                  fontSize: TwitchUiFontSize.body,
                  fontWeight: TwitchUiFontWeight.strong,
                ),
              ),
            ),
            const SizedBox(width: TwitchUiSpacing.space8),
          ],
          if (searchController != null)
            Expanded(
              flex: 5,
              child: SizedBox(
                height: compact ? 34 : 38,
                child: TwitchTextField(
                  height: compact ? 34 : 38,
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    fontSize: TwitchUiFontSize.bodyCompact,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.t(searchHint),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: TwitchUiSpacing.space8,
                      vertical: compact ? 7 : 9,
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: TwitchUiSpacing.space4),
          IconButton(
            tooltip: l10n.t('重新整理'),
            visualDensity: VisualDensity.compact,
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? SizedBox(
                    width: compact ? 16 : 18,
                    height: compact ? 16 : 18,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh_rounded, size: compact ? 19 : 21),
          ),
          IconButton(
            tooltip: l10n.t('關閉'),
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, size: compact ? 19 : 21),
          ),
        ],
      ),
    );
  }
}
