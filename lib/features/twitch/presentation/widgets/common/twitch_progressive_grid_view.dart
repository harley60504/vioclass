// PATCH VERSION: twitch_progressive_grid_view_stage185_simplified_tile
//
// Generic progressive grid renderer. It keeps the full data set intact but only
// exposes an initial batch of widgets, then reveals more as the user scrolls or
// taps the trailing load-more tile.

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
