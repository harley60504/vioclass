import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';

class TwitchEmotePickerCategory {
  final String id;
  final String label;
  final int count;
  const TwitchEmotePickerCategory({
    required this.id,
    required this.label,
    required this.count,
  });
}

/// Data-independent shell shared by chat and whispers. Search and source
/// selection live here; callers only supply their authorized data and actions.
class TwitchEmotePickerPanel extends StatefulWidget {
  final List<TwitchEmotePickerCategory> categories;
  final Widget Function(BuildContext, String, String) categoryBuilder;
  final VoidCallback? onClose;
  final bool loading;
  final String? error;
  final String? initialCategory;
  const TwitchEmotePickerPanel({
    super.key,
    required this.categories,
    required this.categoryBuilder,
    this.onClose,
    this.loading = false,
    this.error,
    this.initialCategory,
  }) : assert(categories.length > 0);

  @override
  State<TwitchEmotePickerPanel> createState() => _TwitchEmotePickerPanelState();
}

class _TwitchEmotePickerPanelState extends State<TwitchEmotePickerPanel> {
  String? selected;
  String query = '';

  @override
  void initState() {
    super.initState();
    selected = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.categories.any((c) => c.id == selected)
        ? selected!
        : widget.categories.first.id;
    return Material(
      color: TwitchUiColors.surfaceAlt,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              SizedBox(
                height: 38,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('emote-panel-search'),
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.vio.t('搜尋貼圖'),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => query = value.trim().toLowerCase()),
                      ),
                    ),
                    if (widget.error != null)
                      Tooltip(
                        message: widget.error!,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: context.vio.t('關閉貼圖'),
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
              if (widget.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: const ValueKey('emote-category-sidebar'),
                      width: (constraints.maxWidth * .24).clamp(64.0, 108.0),
                      child: ListView(
                        primary: false,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          for (final c in widget.categories)
                            Tooltip(
                              message: '${c.label} · ${c.count}',
                              child: Semantics(
                                selected: active == c.id,
                                button: true,
                                child: InkWell(
                                  key: ValueKey('emote-category-${c.id}'),
                                  onTap: () => setState(() => selected = c.id),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minHeight:
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(12) *
                                              2 +
                                          16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active == c.id
                                          ? TwitchUiColors.primarySoft
                                                .withValues(alpha: .2)
                                          : Colors.transparent,
                                      border: Border(
                                        left: BorderSide(
                                          width: 3,
                                          color: active == c.id
                                              ? TwitchUiColors.primary
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      c.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: active == c.id
                                            ? TwitchUiColors.primary
                                            : Colors.white60,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey('emote-category-content-$active'),
                        child: widget.categoryBuilder(context, active, query),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
