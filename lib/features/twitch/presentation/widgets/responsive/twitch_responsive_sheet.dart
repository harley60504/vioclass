import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum TwitchUnifiedSheetSize {
  compact,
  medium,
  large,
  wide,
}

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
  Color backgroundColor = const Color(0xFF18181B),
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
    viewportSize.height - media.padding.top - media.padding.bottom -
        (keyboardOpen ? 4.0 : 10.0),
  );
  final effectiveMaxWidth = math.min(resolvedSize.maxWidth, availableDialogWidth);

  if (landscapeCompact) {
    return showDialog<T>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (dialogContext) {
        return SafeArea(
          left: false,
          right: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  borderRadius: BorderRadius.circular(14),
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
                maxHeight: viewportSize.height * resolvedSize.portraitHeightFactor,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
  Color backgroundColor = const Color(0xFF18181B),
}) {
  final refreshHandler = onRefresh;

  return showTwitchResponsiveSheet<T>(
    context: context,
    size: size,
    maxWidth: maxWidth,
    portraitHeightFactor: portraitHeightFactor,
    landscapeHeightFactor: landscapeHeightFactor,
    backgroundColor: backgroundColor,
    builder: (sheetContext) {
      return TwitchUnifiedSheetScaffold(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconImageUrl: iconImageUrl,
        loading: loading,
        onRefresh: refreshHandler == null
            ? null
            : () {
                unawaited(refreshHandler());
              },
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
    final refreshHandler = onRefresh;

    return SizedBox.expand(
      child: Column(
        children: [
          TwitchUnifiedSheetHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            iconImageUrl: iconImageUrl,
            loading: loading,
            onRefresh: refreshHandler == null
                ? null
                : () {
                    refreshHandler();
                  },
            onClose: onClose,
            showRefresh: showRefresh,
            showClose: showClose,
            trailing: trailing,
          ),
          Expanded(child: child),
        ],
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
    final subtitleText = subtitle?.trim();
    final iconUrl = iconImageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2D)),
        ),
      ),
      child: Row(
        children: [
          _UnifiedSheetHeaderIcon(
            icon: icon,
            imageUrl: iconUrl,
          ),
          const SizedBox(width: 9),
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
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitleText != null && subtitleText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...trailing,
          ],
          if (showRefresh) ...[
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '重新整理',
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
          if (showClose)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '關閉',
              onPressed: onClose ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _UnifiedSheetHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String imageUrl;

  const _UnifiedSheetHeaderIcon({
    required this.icon,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.network(
          imageUrl,
          width: 24,
          height: 24,
          cacheWidth: 48,
          cacheHeight: 48,
          filterQuality: FilterQuality.low,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    }

    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF9146FF).withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.36)),
      ),
      child: Icon(icon, color: const Color(0xFFBF94FF), size: 16),
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
    final verticalPadding = compact ? 6.0 : 8.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, verticalPadding, 8, verticalPadding),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (searchController != null)
            Expanded(
              flex: 5,
              child: SizedBox(
                height: compact ? 34 : 38,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: compact ? 7 : 9,
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '重新整理',
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
            tooltip: '關閉',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, size: compact ? 19 : 21),
          ),
        ],
      ),
    );
  }
}
