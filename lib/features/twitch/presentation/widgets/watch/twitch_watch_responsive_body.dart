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

class TwitchWatchResponsiveBody extends StatefulWidget {
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
  State<TwitchWatchResponsiveBody> createState() =>
      _TwitchWatchResponsiveBodyState();

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
}

class _TwitchWatchResponsiveBodyState extends State<TwitchWatchResponsiveBody> {
  bool _resizingChat = false;
  double? _dragChatWidth;
  double _dragStartWidth = 0;
  double _accumulatedDx = 0;

  double _usableWidth(TwitchResponsiveLayout layout) {
    final horizontalPadding =
        TwitchWatchResponsiveBody.shellPaddingFor(layout).horizontal;
    final gapWidth = widget.chatVisible
        ? TwitchWatchResponsiveBody.shellGapFor(layout)
        : 0.0;
    return (layout.width - horizontalPadding - gapWidth)
        .clamp(1.0, layout.width)
        .toDouble();
  }

  ({double min, double max}) _chatWidthBounds(
    TwitchResponsiveLayout layout,
  ) {
    final usableWidth = _usableWidth(layout);
    final minByViewport = usableWidth * widget.minChatPanelRatio;
    final boostedMinChatPanelWidth =
        widget.minChatPanelWidth +
        TwitchWatchResponsiveBody._chatMinWidthVisualBoost;
    final boostedMaxEffectiveMinChatPanelWidth =
        widget.maxEffectiveMinChatPanelWidth +
        TwitchWatchResponsiveBody._chatMinWidthVisualBoost;
    final minWidth = minByViewport
        .clamp(
          boostedMinChatPanelWidth,
          boostedMaxEffectiveMinChatPanelWidth,
        )
        .toDouble();
    final maxWidth = widget.maxChatPanelWidth
        .clamp(minWidth, usableWidth - 120.0)
        .toDouble();
    return (min: minWidth, max: maxWidth);
  }

  double _storedChatWidth(TwitchResponsiveLayout layout) {
    final usableWidth = _usableWidth(layout);
    final bounds = _chatWidthBounds(layout);
    final ratioWidth = usableWidth * widget.chatPanelRatio;
    return ratioWidth.clamp(bounds.min, bounds.max).toDouble();
  }

  double _visibleChatWidth(TwitchResponsiveLayout layout) {
    if (_resizingChat && _dragChatWidth != null) {
      final bounds = _chatWidthBounds(layout);
      return _dragChatWidth!.clamp(bounds.min, bounds.max).toDouble();
    }
    return _storedChatWidth(layout);
  }

  void _beginChatResize(TwitchResponsiveLayout layout) {
    final current = _visibleChatWidth(layout);
    setState(() {
      _resizingChat = true;
      _dragChatWidth = current;
      _dragStartWidth = current;
      _accumulatedDx = 0;
    });
  }

  void _updateChatResize(
    TwitchResponsiveLayout layout,
    DragUpdateDetails details,
  ) {
    final bounds = _chatWidthBounds(layout);
    _accumulatedDx += details.delta.dx;
    final next = (_dragStartWidth - _accumulatedDx)
        .clamp(bounds.min, bounds.max)
        .toDouble();
    if (_dragChatWidth == next) return;
    setState(() => _dragChatWidth = next);
  }

  void _finishChatResize(TwitchResponsiveLayout layout) {
    if (!_resizingChat) return;
    final usableWidth = _usableWidth(layout);
    final finalWidth = _visibleChatWidth(layout);

    // Commit once, after interactive resizing has finished. Keeping pointer
    // deltas local prevents TwitchWatchPage and the native video subtree from
    // being rebuilt on every drag frame.
    widget.onSetChatPanelWidthForViewport(
      viewportWidth: usableWidth,
      value: finalWidth,
    );
    widget.onPersistChatPanelWidth();

    setState(() {
      _resizingChat = false;
      _dragChatWidth = null;
      _accumulatedDx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pip = TwitchAndroidPipController.instance;

    return AnimatedBuilder(
      animation: pip,
      builder: (context, _) {
        if (pip.shouldRenderPlayerOnly || widget.fullscreenMode) {
          return TwitchPlayerOnlySurface(
            player: _StablePlayerSurface(child: widget.player),
          );
        }

        return ColoredBox(
          color: TwitchUiColors.appBackground,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = TwitchResponsiveLayout.fromConstraints(
                constraints,
              );

              if (!_enableWatchPlayer) {
                return _DisabledPlayerLayout(
                  layout: layout,
                  chatVisible: widget.chatVisible,
                  chat: widget.chat,
                );
              }

              if (layout.shouldUseBottomChat) {
                return _BottomChatLayout(
                  layout: layout,
                  chatVisible: widget.chatVisible,
                  player: widget.player,
                  chat: widget.chat,
                  belowPlayer: widget.belowPlayer,
                );
              }

              return _SideChatLayout(
                layout: layout,
                chatVisible: widget.chatVisible,
                chatPanelWidth: _visibleChatWidth(layout),
                player: widget.player,
                chat: widget.chat,
                belowPlayer: widget.belowPlayer,
                onDragStart: () => _beginChatResize(layout),
                onDragUpdate: (details) =>
                    _updateChatResize(layout, details),
                onDragEnd: () => _finishChatResize(layout),
              );
            },
          ),
        );
      },
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
              child: _WatchSurface(
                child: _StablePlayerSurface(child: player),
              ),
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

class _SideChatLayout extends StatelessWidget {
  final TwitchResponsiveLayout layout;
  final bool chatVisible;
  final double chatPanelWidth;
  final Widget player;
  final Widget chat;
  final Widget? belowPlayer;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const _SideChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.chatPanelWidth,
    required this.player,
    required this.chat,
    required this.belowPlayer,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(layout);
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(layout);
    final showResizeHandle = !layout.shouldDisableWatchChatResizeHandle;

    return Padding(
      padding: shellPadding,
      child: Row(
        children: [
          Expanded(
            flex: layout.isPhoneLandscape ? 10 : 1,
            child: _PlayerColumn(player: player, belowPlayer: belowPlayer),
          ),
          if (chatVisible)
            SizedBox(
              width: shellGap,
              child: showResizeHandle
                  ? TwitchWatchChatResizeHandle(
                      onDragStart: (_) => onDragStart(),
                      onDragUpdate: onDragUpdate,
                      onDragEnd: onDragEnd,
                    )
                  : const SizedBox.expand(),
            ),
          if (chatVisible)
            SizedBox(
              width: chatPanelWidth,
              child: _WatchSurface(child: chat),
            ),
        ],
      ),
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
    if (content == null) {
      return _WatchSurface(
        child: _StablePlayerSurface(child: widget.player),
      );
    }

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
          child: _WatchSurface(
            child: _StablePlayerSurface(child: widget.player),
          ),
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

class _StablePlayerSurface extends StatelessWidget {
  final Widget child;

  const _StablePlayerSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
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
