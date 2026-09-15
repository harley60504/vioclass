import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../../models/playback/twitch_m3u8_variant.dart';
import '../../../../services/playback/twitch_playlist_player_runtime.dart';
import '../../../watch/controllers/twitch_playback_timeline_controller.dart';
import '../../../watch/twitch_watch_playback_kind.dart';
import '../../../theme/twitch_ui_tokens.dart';
import 'twitch_player_error_card.dart';
import 'twitch_watch_bottom_control_bar.dart';
import 'twitch_watch_top_action_bar.dart';

class WatchControlsChromeController extends ChangeNotifier {
  static const Duration _autoHideDelay = Duration(seconds: 5);

  bool _visible = true;
  bool _keepVisible = false;
  Timer? _hideTimer;

  bool get visible => _visible;

  void configure({required bool keepVisible}) {
    _keepVisible = keepVisible;
    if (keepVisible) {
      _hideTimer?.cancel();
      _setVisible(true);
      return;
    }
    _scheduleAutoHide();
  }

  void wake() {
    _setVisible(true);
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (_keepVisible) return;

    _hideTimer = Timer(_autoHideDelay, () {
      if (_hasEditableTextFocus) {
        _scheduleAutoHide();
        return;
      }
      _setVisible(false);
    });
  }

  bool get _hasEditableTextFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext.findAncestorStateOfType<EditableTextState>() != null;
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

class WatchControlsOverlay extends StatefulWidget {
  final bool loading;
  final String? error;
  final Object? runtimeError;
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onHome;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onOpenChannel;
  final VoidCallback? onCreateClip;
  final bool creatingClip;
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool muted;
  final double volume;
  final bool fullscreen;
  final bool chatVisible;
  final bool showFullscreenButton;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final List<TwitchM3u8Variant> qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;
  final VoidCallback? onToggleChat;
  final VoidCallback? onToggleFullscreen;
  final bool hasDvrReplay;
  final bool hasFullLiveDvr;
  final bool showLiveEdgeLabel;
  final Duration? liveDvrDuration;
  final DateTime? liveDvrStartedAt;
  final ValueChanged<Duration>? onOpenDvrReplayAtPosition;
  final VoidCallback? onReturnToLive;
  final TwitchWatchPlaybackKind playbackKind;
  final bool timelineEnabled;
  final TwitchPlaybackTimelineController? playbackTimelineController;
  final bool showTopActionBar;
  final WatchControlsChromeController? chromeController;

  const WatchControlsOverlay({
    super.key,
    required this.loading,
    required this.error,
    required this.runtimeError,
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    this.onHome,
    required this.onToggleFollow,
    required this.onSubscribe,
    this.onOpenChannel,
    this.onCreateClip,
    this.creatingClip = false,
    required this.player,
    required this.playerRuntime,
    required this.muted,
    required this.volume,
    required this.fullscreen,
    required this.chatVisible,
    required this.showFullscreenButton,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.qualityVariants,
    required this.currentVariant,
    required this.onQualityChanged,
    required this.onToggleChat,
    required this.onToggleFullscreen,
    this.hasDvrReplay = false,
    this.hasFullLiveDvr = false,
    this.showLiveEdgeLabel = false,
    this.liveDvrDuration,
    this.liveDvrStartedAt,
    this.onOpenDvrReplayAtPosition,
    this.onReturnToLive,
    this.playbackKind = TwitchWatchPlaybackKind.live,
    this.timelineEnabled = true,
    this.playbackTimelineController,
    this.showTopActionBar = true,
    this.chromeController,
  });

  @override
  State<WatchControlsOverlay> createState() => _WatchControlsOverlayState();
}

class _WatchControlsOverlayState extends State<WatchControlsOverlay> {
  static const Duration _fadeDuration = Duration(milliseconds: 180);

  late WatchControlsChromeController _chromeController;
  late bool _ownsChromeController;

  bool get _hasError =>
      (widget.error != null && widget.error!.trim().isNotEmpty) ||
      widget.runtimeError != null;

  @override
  void initState() {
    super.initState();
    _bindChromeController();
    _syncChromePolicy();
  }

  @override
  void didUpdateWidget(covariant WatchControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chromeController, widget.chromeController)) {
      if (_ownsChromeController) {
        _chromeController.dispose();
      }
      _bindChromeController();
    }
    _syncChromePolicy();
  }

  void _bindChromeController() {
    final external = widget.chromeController;
    if (external != null) {
      _chromeController = external;
      _ownsChromeController = false;
    } else {
      _chromeController = WatchControlsChromeController();
      _ownsChromeController = true;
    }
  }

  void _syncChromePolicy() {
    _chromeController.configure(keepVisible: widget.loading || _hasError);
  }

  @override
  void dispose() {
    if (_ownsChromeController) {
      _chromeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _WatchControlsInteractionLayer(
      onWakeControls: _chromeController.wake,
      child: AnimatedBuilder(
        animation: _chromeController,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(child: _PlayerDimOverlay(visible: widget.loading)),
              _FadingWatchChrome(
                visible: _chromeController.visible,
                fadeDuration: _fadeDuration,
                child: _WatchChromeStack(widget: widget, hasError: _hasError),
              ),
              _WatchErrorOverlay(
                error: widget.error,
                runtimeError: widget.runtimeError,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WatchControlsInteractionLayer extends StatelessWidget {
  final VoidCallback onWakeControls;
  final Widget child;

  const _WatchControlsInteractionLayer({
    required this.onWakeControls,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onWakeControls(),
      onHover: (_) => onWakeControls(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onWakeControls,
        child: child,
      ),
    );
  }
}

class _FadingWatchChrome extends StatelessWidget {
  final bool visible;
  final Duration fadeDuration;
  final Widget child;

  const _FadingWatchChrome({
    required this.visible,
    required this.fadeDuration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: fadeDuration,
        curve: Curves.easeOutCubic,
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

class _WatchChromeStack extends StatelessWidget {
  final WatchControlsOverlay widget;
  final bool hasError;

  const _WatchChromeStack({required this.widget, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showTopActionBar)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: WatchTopActionBar(
              metadata: widget.metadata,
              isFollowing: widget.isFollowing,
              followBusy: widget.followBusy,
              onBack: widget.onBack,
              onHome: widget.onHome,
              onToggleFollow: widget.onToggleFollow,
              onSubscribe: widget.onSubscribe,
              onOpenChannel: widget.onOpenChannel,
              onCreateClip: widget.onCreateClip,
              creatingClip: widget.creatingClip,
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 2),
            child: WatchBottomControlBar(
              player: widget.player,
              playerRuntime: widget.playerRuntime,
              muted: widget.muted,
              volume: widget.volume,
              fullscreen: widget.fullscreen,
              chatVisible: widget.chatVisible,
              showFullscreenButton: widget.showFullscreenButton,
              onToggleMute: widget.onToggleMute,
              onVolumeChanged: widget.onVolumeChanged,
              qualityVariants: widget.qualityVariants,
              currentVariant: widget.currentVariant,
              onQualityChanged: widget.onQualityChanged,
              onToggleChat: widget.onToggleChat,
              onToggleFullscreen: widget.onToggleFullscreen,
              hasDvrReplay: widget.hasDvrReplay,
              hasFullLiveDvr: widget.hasFullLiveDvr,
              showLiveEdgeLabel: widget.showLiveEdgeLabel,
              liveDvrDuration: widget.liveDvrDuration,
              liveDvrStartedAt: widget.liveDvrStartedAt,
              onOpenDvrReplayAtPosition: widget.onOpenDvrReplayAtPosition,
              onReturnToLive: widget.onReturnToLive,
              playbackKind: widget.playbackKind,
              timelineEnabled: widget.timelineEnabled && !hasError,
              playbackTimelineController: widget.playbackTimelineController,
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchErrorOverlay extends StatelessWidget {
  final String? error;
  final Object? runtimeError;

  const _WatchErrorOverlay({required this.error, required this.runtimeError});

  @override
  Widget build(BuildContext context) {
    final message = _resolveMessage();
    if (message == null) return const SizedBox.shrink();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 88,
      child: PlayerErrorCard(message: message),
    );
  }

  String? _resolveMessage() {
    final explicitError = error?.trim();
    if (explicitError != null && explicitError.isNotEmpty) {
      return explicitError;
    }
    final runtime = runtimeError;
    if (runtime == null) return null;
    return runtime.toString();
  }
}

class _PlayerDimOverlay extends StatelessWidget {
  final bool visible;

  const _PlayerDimOverlay({required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return const ColoredBox(
      color: Color(0x66000000),
      child: Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primarySoft),
      ),
    );
  }
}
