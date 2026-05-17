// PATCH VERSION: twitch_emote_picker_widgets_stage181_progressive_grid
//
// Shared visual widgets for Twitch emote picker sheets.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/emotes/twitch_official_emote.dart';
import '../../../models/emotes/twitch_third_party_emote.dart';
import 'twitch_emote_picker_models.dart';

typedef TwitchProgressiveGridItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  int index,
);

class TwitchProgressiveGridView<T> extends StatefulWidget {
  final List<T> items;
  final TwitchProgressiveGridItemBuilder<T> itemBuilder;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry padding;
  final int initialItemCount;
  final int pageSize;
  final String resetKey;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool autoLoadOnScroll;
  final String loadMoreLabel;

  const TwitchProgressiveGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.gridDelegate,
    required this.resetKey,
    this.padding = EdgeInsets.zero,
    this.initialItemCount = 48,
    this.pageSize = 48,
    this.shrinkWrap = false,
    this.physics,
    this.autoLoadOnScroll = true,
    this.loadMoreLabel = '載入更多',
  });

  @override
  State<TwitchProgressiveGridView<T>> createState() =>
      _TwitchProgressiveGridViewState<T>();
}

class _TwitchProgressiveGridViewState<T>
    extends State<TwitchProgressiveGridView<T>> {
  ScrollController? _controller;
  late int _visibleCount;

  @override
  void initState() {
    super.initState();
    _visibleCount = _initialVisibleCount();
    if (!widget.shrinkWrap && widget.autoLoadOnScroll) {
      _controller = ScrollController()..addListener(_maybeLoadMoreFromScroll);
    }
  }

  @override
  void didUpdateWidget(covariant TwitchProgressiveGridView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldHaveController = !widget.shrinkWrap && widget.autoLoadOnScroll;
    final hadController = _controller != null;
    if (shouldHaveController && !hadController) {
      _controller = ScrollController()..addListener(_maybeLoadMoreFromScroll);
    } else if (!shouldHaveController && hadController) {
      _controller?.removeListener(_maybeLoadMoreFromScroll);
      _controller?.dispose();
      _controller = null;
    }

    if (oldWidget.resetKey != widget.resetKey) {
      _visibleCount = _initialVisibleCount();
      return;
    }

    if (_visibleCount > widget.items.length) {
      _visibleCount = widget.items.length;
    }

    if (_visibleCount <= 0 && widget.items.isNotEmpty) {
      _visibleCount = _initialVisibleCount();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_maybeLoadMoreFromScroll);
    _controller?.dispose();
    super.dispose();
  }

  int _initialVisibleCount() {
    return math.min(widget.initialItemCount, widget.items.length);
  }

  bool get _hasMore => _visibleCount < widget.items.length;

  void _loadMore() {
    if (!_hasMore) return;
    setState(() {
      _visibleCount = math.min(
        widget.items.length,
        _visibleCount + widget.pageSize,
      );
    });
  }

  void _maybeLoadMoreFromScroll() {
    final controller = _controller;
    if (controller == null || !controller.hasClients || !_hasMore) return;

    final position = controller.position;
    final distanceToEnd = position.maxScrollExtent - position.pixels;
    if (distanceToEnd < 520) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(_visibleCount, widget.items.length);
    final hasMore = visibleCount < widget.items.length;

    return GridView.builder(
      controller: _controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      gridDelegate: widget.gridDelegate,
      itemCount: visibleCount + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visibleCount) {
          return TwitchProgressiveGridLoadMoreTile(
            label: '${widget.loadMoreLabel} $visibleCount/${widget.items.length}',
            onTap: _loadMore,
          );
        }

        return widget.itemBuilder(context, widget.items[index], index);
      },
    );
  }
}

class TwitchProgressiveGridLoadMoreTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const TwitchProgressiveGridLoadMoreTile({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1B23),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF9146FF).withOpacity(0.34)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.expand_more_rounded,
                color: Color(0xFFBF94FF),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBF94FF),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchEmotePickerTabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const TwitchEmotePickerTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchOfficialSubFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const TwitchOfficialSubFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? const Color(0xFF9146FF).withOpacity(0.26)
        : const Color(0xFF242429);
    final foreground = selected ? const Color(0xFFD9C5FF) : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withOpacity(0.7)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: foreground.withOpacity(0.62),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchThirdPartyEmoteGridCard extends StatelessWidget {
  final TwitchThirdPartyEmote emote;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const TwitchThirdPartyEmoteGridCard({
    super.key,
    required this.emote,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onInsert,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF242429),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: emote.isZeroWidth
                  ? const Color(0xFFEAB308).withOpacity(0.55)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: TwitchOptimizedEmoteImage(
                        imageUrl: emote.imageUrl,
                        cacheSize: twitchEmoteGridCacheSize,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emote.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emote.providerLabel,
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                      if (emote.isZeroWidth) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'ZW',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFEAB308),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Positioned(
                top: -8,
                right: -8,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    favorite ? Icons.star : Icons.star_border,
                    size: 18,
                    color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TwitchOfficialEmoteGridCard extends StatelessWidget {
  final TwitchOfficialEmote emote;
  final bool locked;
  final bool favorite;
  final VoidCallback onInsert;
  final VoidCallback onToggleFavorite;

  const TwitchOfficialEmoteGridCard({
    super.key,
    required this.emote,
    required this.locked,
    required this.favorite,
    required this.onInsert,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: locked ? null : onInsert,
        child: Opacity(
          opacity: locked ? 0.48 : 1,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF242429),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: locked
                    ? const Color(0xFFFFD166).withOpacity(0.32)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: TwitchOptimizedEmoteImage(
                          imageUrl: emote.imageUrl,
                          cacheSize: twitchEmoteGridCacheSize,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emote.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      locked ? 'LOCKED' : emote.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: locked ? const Color(0xFFFFD166) : Colors.white38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      favorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: favorite ? const Color(0xFFEAB308) : Colors.white54,
                    ),
                  ),
                ),
                if (locked)
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: Color(0xFFFFD166),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TwitchOptimizedEmoteImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final int cacheSize;

  const TwitchOptimizedEmoteImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.cacheSize = twitchEmoteGridCacheSize,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.white54);
    }

    return RepaintBoundary(
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.contain,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white54),
      ),
    );
  }
}
