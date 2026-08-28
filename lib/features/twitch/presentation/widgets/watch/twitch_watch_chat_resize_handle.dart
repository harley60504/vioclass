import 'package:flutter/material.dart';

class TwitchWatchChatResizeHandle extends StatefulWidget {
  final ValueChanged<DragStartDetails>? onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback? onDragEnd;

  const TwitchWatchChatResizeHandle({
    super.key,
    this.onDragStart,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<TwitchWatchChatResizeHandle> createState() =>
      _TwitchWatchChatResizeHandleState();
}

class _TwitchWatchChatResizeHandleState
    extends State<TwitchWatchChatResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          widget.onDragStart?.call(details);
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onDragEnd?.call();
        },
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: active ? 3 : 1,
            height: double.infinity,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF8F7CC0)
                  : Colors.white.withValues(alpha: 0.10),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8F7CC0).withValues(alpha: 0.38),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
