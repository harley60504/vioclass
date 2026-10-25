import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

typedef PlayerSettingsDrawerBuilder =
    Widget Function(BuildContext, VoidCallback);

/// Owns the panel inside the video viewport, independent of the window/chat.
class PlayerSettingsDrawerHost extends StatefulWidget {
  final Widget child;
  const PlayerSettingsDrawerHost({super.key, required this.child});

  static Future<void> show(
    BuildContext context,
    PlayerSettingsDrawerBuilder builder,
  ) {
    final host = context
        .findAncestorStateOfType<_PlayerSettingsDrawerHostState>();
    if (host == null) {
      return Future<void>.error(StateError('Missing player drawer host'));
    }
    return host.open(builder);
  }

  @override
  State<PlayerSettingsDrawerHost> createState() =>
      _PlayerSettingsDrawerHostState();
}

class _PlayerSettingsDrawerHostState extends State<PlayerSettingsDrawerHost> {
  PlayerSettingsDrawerBuilder? _builder;
  Completer<void>? _closed;

  Future<void> open(PlayerSettingsDrawerBuilder builder) {
    if (_closed != null) return _closed!.future;
    final closed = Completer<void>();
    _closed = closed;
    setState(() => _builder = builder);
    return closed.future;
  }

  void _close() {
    final closed = _closed;
    if (closed == null) return;
    _closed = null;
    setState(() => _builder = null);
    // Let the panel unmount before its caller disposes preference listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!closed.isCompleted) closed.complete();
    });
  }

  @override
  void dispose() {
    final closed = _closed;
    if (closed != null && !closed.isCompleted) closed.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_builder != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: constraints.maxWidth.clamp(1.0, 420.0),
                  height: constraints.maxHeight,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 0),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => FractionalTranslation(
                      translation: Offset(value, 0),
                      child: child,
                    ),
                    child: Focus(
                      autofocus: true,
                      onKeyEvent: (_, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.escape) {
                          _close();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent) {
                            GestureBinding.instance.pointerSignalResolver
                                .register(event, (_) {});
                          }
                        },
                        child: _builder!(context, _close),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
