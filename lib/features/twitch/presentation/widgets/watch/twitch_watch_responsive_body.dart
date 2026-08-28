import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../responsive/twitch_responsive_layout.dart';
import 'player/twitch_player_only_surface.dart';
import 'twitch_watch_chat_resize_handle.dart';

const bool _enableWatchPlayer = bool.fromEnvironment(
  'TWITCH_ENABLE_WATCH_PLAYER',
  defaultValue: true,
);

class TwitchWatchResponsiveBody extends StatelessWidget {
  static const double _chatMinWidthVisualBoost = 18.0;
  static const double _playerAspectRatio = 16 / 9;
  static const Color _watchBackgroundColor = Color(0xFF171222);

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
    final pip = TwitchAndroidPipController.instance;

    return AnimatedBuilder(
      animation: pip,
      builder: (context, _) {
        if (pip.shouldRenderPlayerOnly || fullscreenMode) {
          return TwitchPlayerOnlySurface(player: player);
        }

        return ColoredBox(
          color: _watchBackgroundColor,
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

              return _SideChatLayout(
                layout: layout,
                chatVisible: chatVisible,
                chatPanelWidth: _effectiveChatPanelWidthForViewport(layout),
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

  double _effectiveChatPanelWidthForViewport(TwitchResponsiveLayout layout) {
    final horizontalPadding = shellPaddingFor(layout).horizontal;
    final gapWidth = chatVisible ? shellGapFor(layout) : 0.0;
    final usableWidth = (layout.width - horizontalPadding - gapWidth)
        .clamp(1.0, layout.width)
        .toDouble();
    final ratioWidth = usableWidth * chatPanelRatio;
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
    return ratioWidth.clamp(minWidth, maxWidth).toDouble();
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
              child: _WatchSurface(child: player),
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
  final void Function({required double viewportWidth, required double value})
  onSetChatPanelWidthForViewport;
  final VoidCallback onPersistChatPanelWidth;

  const _SideChatLayout({
    required this.layout,
    required this.chatVisible,
    required this.chatPanelWidth,
    required this.player,
    required this.chat,
    required this.belowPlayer,
    required this.onSetChatPanelWidthForViewport,
    required this.onPersistChatPanelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final shellPadding = TwitchWatchResponsiveBody.shellPaddingFor(layout);
    final shellGap = TwitchWatchResponsiveBody.shellGapFor(layout);
    final showResizeHandle = !layout.shouldDisableWatchChatResizeHandle;
    final usableWidth = (layout.width - shellPadding.horizontal - shellGap)
        .clamp(1.0, layout.width)
        .toDouble();
    var dragStartWidth = chatPanelWidth;
    var accumulatedDx = 0.0;

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
                      onDragStart: (_) {
                        dragStartWidth = chatPanelWidth;
                        accumulatedDx = 0.0;
                      },
                      onDragUpdate: (delta) {
                        accumulatedDx += delta.delta.dx;
                        onSetChatPanelWidthForViewport(
                          viewportWidth: usableWidth,
                          value: dragStartWidth - accumulatedDx,
                        );
                      },
                      onDragEnd: onPersistChatPanelWidth,
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
    if (content == null) return _WatchSurface(child: widget.player);

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
          child: _WatchSurface(child: widget.player),
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

class _WatchSurface extends StatelessWidget {
  final Widget child;

  const _WatchSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
      ),
      child: child,
    );
  }
}

class _WatchPlayerDisabledPlaceholder extends StatelessWidget {
  const _WatchPlayerDisabledPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '播放器已停用',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
