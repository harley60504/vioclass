import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../responsive/twitch_responsive_layout.dart';
import 'player/twitch_player_only_surface.dart';
import 'twitch_watch_chat_resize_handle.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

/// Temporary minimal Watch mode for the Android resize-black-frame test.
/// A normal `flutter run` enables it automatically. Release builds keep the
/// regular Watch layout unless explicitly enabled with a dart-define.
const bool _debugMinimalLiveWatch = bool.fromEnvironment(
  'TWITCH_DEBUG_MINIMAL_LIVE_WATCH',
  defaultValue: kDebugMode,
);

class TwitchWatchResponsiveBody extends StatelessWidget {
  static const double _chatMinWidthVisualBoost = 18.0;
  static const double _playerAspectRatio = 16 / 9;

  final bool chatVisible;
  final bool fullscreenMode;
  final double chatPanelWidth;
  final double chatPanelRatio;
  final double minChatPanelWidth;
  final double maxEffectiveMinChatPanelWidth;
  final double maxChatPanelWidth;
  final double minChatPanelRatio;
  final double minStoredChatPanelRatio;
  final double maxChatPanelRatio;
  final Widget player;
  final Widget chat;
  final Widget? belowPlayer;
  final void Function({required double viewportWidth, required double value})
  onSetChatPanelWidthForViewport;
  final VoidCallback onPersistChatPanelWidth;

  const TwitchWatchResponsiveBody({
    super.key,
    required this.chatVisible,
    this.fullscreenMode = false,
    required this.chatPanelWidth,
    required this.chatPanelRatio,
    required this.minChatPanelWidth,
    required this.maxEffectiveMinChatPanelWidth,
    required this.maxChatPanelWidth,
    required this.minChatPanelRatio,
    required this.minStoredChatPanelRatio,
    required this.maxChatPanelRatio,
    required this.player,
    required this.chat,
    this.belowPlayer,
    required this.onSetChatPanelWidthForViewport,
    required this.onPersistChatPanelWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (_debugMinimalLiveWatch) {
      return _DebugMinimalLiveResizeLayout(player: player);
    }

    final pip = TwitchAndroidPipController.instance;

    return AnimatedBuilder(
      animation: pip,
      builder: (context, _) {
        if (pip.shouldRenderPlayerOnly || fullscreenMode) {
          return TwitchPlayerOnlySurface(player: player);
        }

        return DecoratedBox(
          decoration: const BoxDecoration(
            color: TwitchUiColors.appBackground,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0x14FFFFFF),
                Color(0x08FFFFFF),
                Color(0x00000000),
              ],
              stops: <double>[0.0, 0.48, 1.0],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = TwitchResponsiveLayout.fromConstraints(
                constraints,
              );

              if (!_enableWatchPlayer) {
                return _DisabledPlayerLayout(
                  layout: layout,
                  chatVisible: chatVisible,
                  chat: chat,
                );
              }

              if (layout.shouldUseBottomChat) {
                return _BottomChatLayout(
                  layout: layout,
                  chatVisible: chatVisible,
                  player: player,
                  chat: chat,
                  belowPlayer: belowPlayer,
                );
              }

              final bounds = _chatPanelWidthBoundsForViewport(layout);
              return _SideChatLayout(
                layout: layout,
                chatVisible: chatVisible,
                chatPanelWidth: _effectiveChatPanelWidthForViewport(
                  layout,
                  bounds: bounds,
                ),
                minChatPanelWidth: bounds.min,
                maxChatPanelWidth: bounds.max,
                player: player,
                chat: chat,
                belowPlayer: belowPlayer,
                onSetChatPanelWidthForViewport: onSetChatPanelWidthForViewport,
                onPersistChatPanelWidth: onPersistChatPanelWidth,
              );
            },
          ),
        );
      },
    );
  }

  static EdgeInsets shellPaddingFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait) return const EdgeInsets.all(8);
    if (layout.width < 900 || layout.isPhoneLandscape) {
      return const EdgeInsets.all(10);
    }
    return const EdgeInsets.all(14);
  }

  static double shellGapFor(TwitchResponsiveLayout layout) {
    if (layout.isPhonePortrait || layout.width < 900) return 8;
    return 12;
  }

  ({double min, double max, double usableWidth})
  _chatPanelWidthBoundsForViewport(TwitchResponsiveLayout layout) {
    final horizontalPadding = shellPaddingFor(layout).horizontal;
    final gapWidth = chatVisible ? shellGapFor(layout) : 0.0;
    final usableWidth = (layout.width - horizontalPadding - gapWidth)
        .clamp(1.0, layout.width)
        .toDouble();
    final minByViewport = usableWidth * minChatPanelRatio;
    final boostedMinChatPanelWidth =
        minChatPanelWidth + _chatMinWidthVisualBoost;
    final boostedMaxEffectiveMinChatPanelWidth =
        maxEffectiveMinChatPanelWidth + _chatMinWidthVisualBoost;
    final minWidth = minByViewport
        .clamp(boostedMinChatPanelWidth, boostedMaxEffectiveMinChatPanelWidth)
        .toDouble();
    final maxWidth = maxChatPanelWidth
        .clamp(minWidth, usableWidth - 120.0)
        .toDouble();
    return (min: minWidth, max: maxWidth, usableWidth: usableWidth);
  }

  double _effectiveChatPanelWidthForViewport(
    TwitchResponsiveLayout layout, {
    ({double min, double max, double usableWidth})? bounds,
  }) {
    final resolvedBounds = bounds ?? _chatPanelWidthBoundsForViewport(layout);
    final ratioWidth = resolvedBounds.usableWidth * chatPanelRatio;
    return ratioWidth
        .clamp(resolvedBounds.min, resolvedBounds.max)
        .toDouble();
  }
}

class _DebugMinimalLiveResizeLayout extends StatefulWidget {
  final Widget player;

  const _DebugMinimalLiveResizeLayout({required this.player});

  @override
  State<_DebugMinimalLiveResizeLayout> createState() =>
      _DebugMinimalLiveResizeLayoutState();
}

class _DebugMinimalLiveResizeLayoutState
    extends State<_DebugMinimalLiveResizeLayout> {
  static const double _dividerWidth = 18.0;
  static const double _minPlayerFraction = 0.30;
  static const double _maxPlayerFraction = 0.92;

  double _playerFraction = 0.70;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1C1025),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final available = (totalWidth - _dividerWidth).clamp(1.0, totalWidth);
          final playerWidth = (available * _playerFraction)
              .clamp(1.0, available)
              .toDouble();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: playerWidth, child: widget.player),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  if (available <= 0) return;
                  final next = (_playerFraction + details.delta.dx / available)
                      .clamp(_minPlayerFraction, _maxPlayerFraction)
                      .toDouble();
                  if (next == _playerFraction) return;
                  setState(() => _playerFraction = next);
                },
                child: const ColoredBox(
                  color: Color(0xFF7A5B8C),
                  child: SizedBox(width: _dividerWidth),
                ),
              ),
              const Expanded(
                child: ColoredBox(color: Color(0xFF261331)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DisabledPlayerLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final Widget chat;

  const _DisabledPlayerLayout({
    required this.layout,
    required this.chatVisible,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: TwitchWatchResponsiveBody.shellPaddingFor(layout),
      child: _WatchSurface(
        child: chatVisible ? chat : const _WatchPlayerDisabledPlaceholder(),
      ),
    );
  }
}

class _BottomChatLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final Widget player;
  final Widget chat;
  final Widget? belowPlayer;

  const _BottomChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.player,
    required this.chat,
    required this.belowPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(layout);
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(layout);

    final availableWidth = layout.width - shellPadding.horizontal;
    final availableHeight = layout.height - shellPadding.vertical;
    final preferredPlayerHeight =
        (availableWidth / TwitchWatchResponsiveBody._playerAspectRatio)
            .clamp(150.0, 320.0)
            .toDouble();
    final maxPlayerHeightWithChat = (availableHeight - 430.0)
        .clamp(140.0, 320.0)
        .toDouble();
    final playerHeight = preferredPlayerHeight
        .clamp(140.0, maxPlayerHeightWithChat)
        .toDouble();

    return Padding(
      padding: shellPadding,
      child: Column(
        children: [
          if (chatVisible)
            SizedBox(
              height: playerHeight,
              width: double.infinity,
              child: _PlayerSurface(child: player),
            )
          else
            Expanded(
              child: _PlayerColumn(player: player, belowPlayer: belowPlayer),
            ),
          if (chatVisible) SizedBox(height: shellGap),
          if (chatVisible) Expanded(child: _WatchSurface(child: chat)),
        ],
      ),
    );
  }
}

class _SideChatLayout extends StatefulWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final double chatPanelWidth;
  final double minChatPanelWidth;
  final double maxChatPanelWidth;
  final Widget player;
  final Widget chat;
  final Widget? belowPlayer;
  final void Function({required double viewportWidth, required double value})
  onSetChatPanelWidthForViewport;
  final VoidCallback onPersistChatPanelWidth;

  const _SideChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.chatPanelWidth,
    required this.minChatPanelWidth,
    required this.maxChatPanelWidth,
    required this.player,
    required this.chat,
    required this.belowPlayer,
    required this.onSetChatPanelWidthForViewport,
    required this.onPersistChatPanelWidth,
  });

  @override
  State<_SideChatLayout> createState() => _SideChatLayoutState();
}

class _SideChatLayoutState extends State<_SideChatLayout> {
  late final ValueNotifier<double> _liveChatPanelWidth;
  bool _dragging = false;
  double _dragStartWidth = 0;
  double _accumulatedDx = 0;

  @override
  void initState() {
    super.initState();
    _liveChatPanelWidth = ValueNotifier<double>(widget.chatPanelWidth);
  }

  @override
  void didUpdateWidget(covariant _SideChatLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) return;
    final next = widget.chatPanelWidth
        .clamp(widget.minChatPanelWidth, widget.maxChatPanelWidth)
        .toDouble();
    if ((_liveChatPanelWidth.value - next).abs() >= 0.5) {
      _liveChatPanelWidth.value = next;
    }
  }

  @override
  void dispose() {
    _liveChatPanelWidth.dispose();
    super.dispose();
  }

  void _beginDrag() {
    _dragging = true;
    _dragStartWidth = _liveChatPanelWidth.value;
    _accumulatedDx = 0;
  }

  void _updateDrag(DragUpdateDetails delta) {
    _accumulatedDx += delta.delta.dx;
    final next = (_dragStartWidth - _accumulatedDx)
        .clamp(widget.minChatPanelWidth, widget.maxChatPanelWidth)
        .toDouble();
    if ((_liveChatPanelWidth.value - next).abs() < 0.5) return;
    _liveChatPanelWidth.value = next;
  }

  void _finishDrag(double usableWidth) {
    if (!_dragging) return;
    _dragging = false;
    widget.onSetChatPanelWidthForViewport(
      viewportWidth: usableWidth,
      value: _liveChatPanelWidth.value,
    );
    widget.onPersistChatPanelWidth();
  }

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(
      widget.layout,
    );
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(widget.layout);
    final showResizeHandle = !widget.layout.shouldDisableWatchChatResizeHandle;
    final usableWidth =
        (widget.layout.width - shellPadding.horizontal - shellGap)
            .clamp(1.0, widget.layout.width)
            .toDouble();

    // These are created once per parent Watch rebuild. During a drag only the
    // ValueListenableBuilder below rebuilds, so the exact same player/chat
    // widget instances stay attached while their layout constraints change.
    final playerSlot = _PlayerColumn(
      player: widget.player,
      belowPlayer: widget.belowPlayer,
    );
    final chatSlot = _WatchSurface(child: widget.chat);

    return ValueListenableBuilder<double>(
      valueListenable: _liveChatPanelWidth,
      builder: (context, liveChatPanelWidth, _) {
        return Padding(
          padding: shellPadding,
          child: Row(
            children: [
              Expanded(
                flex: widget.layout.isPhoneLandscape ? 10 : 1,
                child: playerSlot,
              ),
              if (widget.chatVisible)
                SizedBox(
                  width: shellGap,
                  child: showResizeHandle
                      ? TwitchWatchChatResizeHandle(
                          onDragStart: (_) => _beginDrag(),
                          onDragUpdate: _updateDrag,
                          onDragEnd: () => _finishDrag(usableWidth),
                        )
                      : const SizedBox.expand(),
                ),
              if (widget.chatVisible)
                SizedBox(width: liveChatPanelWidth, child: chatSlot),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerColumn extends StatefulWidget {
  final Widget player;
  final Widget? belowPlayer;

  const _PlayerColumn({required this.player, required this.belowPlayer});

  @override
  State<_PlayerColumn> createState() => _PlayerColumnState();
}

class _PlayerColumnState extends State<_PlayerColumn> {
  late final PageController _pageController;
  late final ScrollController _aboutScrollController;
  bool _switchingPage = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _aboutScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _aboutScrollController.dispose();
    super.dispose();
  }

  Future<void> _showPage(int page) async {
    if (_switchingPage || !_pageController.hasClients) return;
    _switchingPage = true;
    try {
      await _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _switchingPage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.belowPlayer;
    if (content == null) return _PlayerSurface(child: widget.player);

    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.vertical,
      children: <Widget>[
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent && event.scrollDelta.dy > 0) {
              _showPage(1);
            }
          },
          child: _PlayerSurface(child: widget.player),
        ),
        _WatchSurface(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent &&
                  event.scrollDelta.dy < 0 &&
                  _aboutScrollController.hasClients &&
                  _aboutScrollController.offset <= 0) {
                _showPage(0);
              }
            },
            child: Scrollbar(
              controller: _aboutScrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                controller: _aboutScrollController,
                padding: EdgeInsets.zero,
                child: content,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  final Widget child;

  const _PlayerSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: TwitchUiColors.borderSubtle),
        ),
      ),
      child: child,
    );
  }
}

class _WatchSurface extends StatelessWidget {
  final Widget child;

  const _WatchSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TwitchUiColors.surfacePanel,
        border: Border.fromBorderSide(
          BorderSide(color: TwitchUiColors.borderSubtle),
        ),
      ),
      child: child,
    );
  }
}

class _WatchPlayerDisabledPlaceholder extends StatelessWidget {
  const _WatchPlayerDisabledPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.vio.t('播放器已停用'),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
