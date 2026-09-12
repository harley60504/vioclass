import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as official_video;

import '../../../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../../../services/playback/twitch_media_kit_player_host.dart';
import '../../../../services/playback/twitch_player_engine_diagnostic_state.dart';
import '../../../theme/twitch_ui_tokens.dart';
import '../../../watch/controllers/twitch_dvr_transition_mask_controller.dart';

const double twitchWatchVideoAspectRatio = 16 / 9;

enum _AndroidDiagnosticEngine { mediaKit, videoPlayer, libVlc }

extension on _AndroidDiagnosticEngine {
  String get label => switch (this) {
    _AndroidDiagnosticEngine.mediaKit => 'media_kit / libmpv',
    _AndroidDiagnosticEngine.videoPlayer => 'video_player / ExoPlayer',
    _AndroidDiagnosticEngine.libVlc => 'LibVLC',
  };
}

class TwitchMediaKitVideoSurface extends StatefulWidget {
  final VideoController controller;
  final double aspectRatio;
  final BoxFit fit;
  final bool reportAndroidPipSourceRect;
  final VideoControlsBuilder? controls;

  const TwitchMediaKitVideoSurface({
    super.key,
    required this.controller,
    this.aspectRatio = twitchWatchVideoAspectRatio,
    this.fit = BoxFit.contain,
    this.reportAndroidPipSourceRect = true,
    this.controls = NoVideoControls,
  });

  @override
  State<TwitchMediaKitVideoSurface> createState() =>
      _TwitchMediaKitVideoSurfaceState();
}

class _TwitchMediaKitVideoSurfaceState
    extends State<TwitchMediaKitVideoSurface>
    with WidgetsBindingObserver {
  final GlobalKey _videoSurfaceKey = GlobalKey();
  late Widget _stableVideo;

  _AndroidDiagnosticEngine _diagnosticEngine =
      _AndroidDiagnosticEngine.mediaKit;
  official_video.VideoPlayerController? _officialVideoController;
  VlcPlayerController? _vlcController;
  String? _diagnosticUri;
  String? _diagnosticError;
  bool _choiceOffered = false;
  bool _switchingEngine = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stableVideo = _buildVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSourceRectHint();
      unawaited(_offerAndroidEngineChoice());
    });
  }

  @override
  void didUpdateWidget(covariant TwitchMediaKitVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.fit != widget.fit ||
        oldWidget.controls != widget.controls) {
      _stableVideo = _buildVideo();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reportSourceRectHint(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logDiagnosticSnapshot('lifecycle=${state.name}');
    if (state == AppLifecycleState.resumed) {
      for (final delay in <Duration>[
        const Duration(milliseconds: 250),
        const Duration(seconds: 1),
        const Duration(milliseconds: 2500),
      ]) {
        Timer(delay, () {
          if (mounted) {
            _logDiagnosticSnapshot('resume+${delay.inMilliseconds}ms');
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TwitchPlayerEngineDiagnosticState.externalPlaybackActive = false;
    TwitchPlayerEngineDiagnosticState.engineLabel = 'media_kit';

    final official = _officialVideoController;
    _officialVideoController = null;
    if (official != null) {
      official.removeListener(_onOfficialVideoChanged);
      unawaited(official.dispose());
    }

    final vlc = _vlcController;
    _vlcController = null;
    if (vlc != null) {
      vlc.removeListener(_onVlcChanged);
      unawaited(vlc.dispose());
    }

    super.dispose();
  }

  Widget _buildVideo() {
    return Video(
      controller: widget.controller,
      fit: widget.fit,
      controls: widget.controls,
    );
  }

  Future<void> _offerAndroidEngineChoice() async {
    if (!Platform.isAndroid || _choiceOffered || !mounted) return;
    _choiceOffered = true;

    String? uri;
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      final candidate = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        uri = candidate;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;
    if (uri == null || uri.isEmpty) {
      debugPrint('[PlayerEngineTest] no current media URI; keep media_kit');
      return;
    }

    final selection = await showDialog<_AndroidDiagnosticEngine>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Android 播放引擎 A/B 測試'),
          content: const Text(
            '請每次只選一個引擎，播放約 5 秒後切到背景 10–30 秒，再回來觀察是否卡頓或出現殘缺畫面。\n\n'
            '三個選項都會使用目前 VioClass 的同一條 media URI。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _AndroidDiagnosticEngine.mediaKit,
              ),
              child: const Text('media_kit'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _AndroidDiagnosticEngine.videoPlayer,
              ),
              child: const Text('video_player'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _AndroidDiagnosticEngine.libVlc,
              ),
              child: const Text('LibVLC'),
            ),
          ],
        );
      },
    );

    if (!mounted || selection == null) return;
    _diagnosticUri = uri;
    if (selection == _AndroidDiagnosticEngine.mediaKit) {
      debugPrint('[PlayerEngineTest] engine=media_kit uri=$uri');
      _logDiagnosticSnapshot('selected');
      return;
    }

    await _activateExternalEngine(selection, uri);
  }

  Future<void> _activateExternalEngine(
    _AndroidDiagnosticEngine engine,
    String uri,
  ) async {
    if (!mounted || _switchingEngine) return;
    setState(() {
      _switchingEngine = true;
      _diagnosticError = null;
    });

    TwitchPlayerEngineDiagnosticState.externalPlaybackActive = true;
    TwitchPlayerEngineDiagnosticState.engineLabel = engine.label;

    try {
      await TwitchMediaKitPlayerHost.pauseShared();

      switch (engine) {
        case _AndroidDiagnosticEngine.mediaKit:
          break;
        case _AndroidDiagnosticEngine.videoPlayer:
          final controller = official_video.VideoPlayerController.networkUrl(
            Uri.parse(uri),
            videoPlayerOptions: official_video.VideoPlayerOptions(
              mixWithOthers: false,
            ),
          );
          _officialVideoController = controller;
          controller.addListener(_onOfficialVideoChanged);
          await controller.initialize();
          await controller.play();
          break;
        case _AndroidDiagnosticEngine.libVlc:
          final controller = VlcPlayerController.network(
            uri,
            hwAcc: HwAcc.full,
            autoInitialize: true,
            autoPlay: true,
            options: VlcPlayerOptions(),
          );
          _vlcController = controller;
          controller.addListener(_onVlcChanged);
          break;
      }

      if (!mounted) return;
      setState(() {
        _diagnosticEngine = engine;
        _switchingEngine = false;
      });
      debugPrint('[PlayerEngineTest] engine=${engine.label} uri=$uri');
      _logDiagnosticSnapshot('selected');
    } catch (error, stackTrace) {
      debugPrint('[PlayerEngineTest] failed engine=${engine.label}: $error');
      debugPrint('$stackTrace');
      TwitchPlayerEngineDiagnosticState.externalPlaybackActive = false;
      TwitchPlayerEngineDiagnosticState.engineLabel = 'media_kit';
      if (!mounted) return;
      setState(() {
        _diagnosticEngine = _AndroidDiagnosticEngine.mediaKit;
        _switchingEngine = false;
        _diagnosticError = '$error';
      });
      await TwitchMediaKitPlayerHost.restoreSharedMedia(
        uri: uri,
        play: true,
        forceOpen: false,
      );
    }
  }

  void _onOfficialVideoChanged() {
    if (!mounted || _diagnosticEngine != _AndroidDiagnosticEngine.videoPlayer) {
      return;
    }
    setState(() {});
  }

  void _onVlcChanged() {
    if (!mounted || _diagnosticEngine != _AndroidDiagnosticEngine.libVlc) {
      return;
    }
    setState(() {});
  }

  void _logDiagnosticSnapshot(String event) {
    if (!Platform.isAndroid) return;

    switch (_diagnosticEngine) {
      case _AndroidDiagnosticEngine.mediaKit:
        final player = TwitchMediaKitPlayerHost.playerOrNull;
        debugPrint(
          '[PlayerEngineTest][media_kit] $event '
          'playing=${player?.state.playing} '
          'buffering=${player?.state.buffering} '
          'position=${player?.state.position.inMilliseconds}ms',
        );
        break;
      case _AndroidDiagnosticEngine.videoPlayer:
        final value = _officialVideoController?.value;
        debugPrint(
          '[PlayerEngineTest][video_player] $event '
          'initialized=${value?.isInitialized} '
          'playing=${value?.isPlaying} '
          'buffering=${value?.isBuffering} '
          'position=${value?.position.inMilliseconds}ms '
          'error=${value?.errorDescription}',
        );
        break;
      case _AndroidDiagnosticEngine.libVlc:
        final value = _vlcController?.value;
        debugPrint(
          '[PlayerEngineTest][LibVLC] $event '
          'initialized=${value?.isInitialized} '
          'playing=${value?.isPlaying} '
          'buffering=${value?.isBuffering} '
          'position=${value?.position.inMilliseconds}ms '
          'error=${value?.errorDescription}',
        );
        break;
    }
  }

  Widget _diagnosticVideo(Widget mediaKitVideo) {
    if (!Platform.isAndroid) return mediaKitVideo;

    switch (_diagnosticEngine) {
      case _AndroidDiagnosticEngine.mediaKit:
        return mediaKitVideo;
      case _AndroidDiagnosticEngine.videoPlayer:
        final controller = _officialVideoController;
        if (controller == null || !controller.value.isInitialized) {
          return const _DiagnosticWaitingSurface(label: 'video_player');
        }
        final aspectRatio = controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : widget.aspectRatio;
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: official_video.VideoPlayer(controller),
            ),
          ),
        );
      case _AndroidDiagnosticEngine.libVlc:
        final controller = _vlcController;
        if (controller == null) {
          return const _DiagnosticWaitingSurface(label: 'LibVLC');
        }
        return ColoredBox(
          color: Colors.black,
          child: VlcPlayer(
            controller: controller,
            aspectRatio: widget.aspectRatio,
            placeholder: const _DiagnosticWaitingSurface(label: 'LibVLC'),
          ),
        );
    }
  }

  void _reportSourceRectHint() {
    if (!mounted || !Platform.isAndroid || !widget.reportAndroidPipSourceRect) {
      return;
    }
    final context = _videoSurfaceKey.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    unawaited(TwitchAndroidPipController.instance.setSourceRectHint(rect));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;

          // Keep the native Video widget mounted even when an interactive
          // layout resize briefly produces a zero-sized constraint. Removing
          // it from the tree detaches/re-attaches the texture and can expose a
          // black frame while dragging the chat/player divider.
          var width = 0.0;
          var height = 0.0;
          if (maxWidth > 0 && maxHeight > 0) {
            width = maxWidth;
            height = width / widget.aspectRatio;
            if (height > maxHeight) {
              height = maxHeight;
              width = height * widget.aspectRatio;
            }
            width = width.clamp(1.0, maxWidth).toDouble();
            height = height.clamp(1.0, maxHeight).toDouble();
          }

          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _reportSourceRectHint(),
          );

          final transitionMask = TwitchDvrTransitionMaskController.instance;
          return Center(
            child: SizedBox(
              key: _videoSurfaceKey,
              width: width,
              height: height,
              child: AnimatedBuilder(
                animation: transitionMask,
                child: _stableVideo,
                builder: (context, mediaKitVideo) {
                  final activeVideo = _diagnosticVideo(
                    mediaKitVideo ?? const SizedBox.shrink(),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      activeVideo,
                      if (_diagnosticEngine ==
                              _AndroidDiagnosticEngine.mediaKit &&
                          transitionMask.visible)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _PlaybackTransitionOverlay(
                              previewImageUrl:
                                  transitionMask.previewImageUrl,
                              showLoading: transitionMask.showLoading,
                            ),
                          ),
                        ),
                      if (Platform.isAndroid)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: IgnorePointer(
                            child: _DiagnosticEngineBadge(
                              engine: _diagnosticEngine.label,
                              switching: _switchingEngine,
                              error: _diagnosticError,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiagnosticWaitingSurface extends StatelessWidget {
  final String label;

  const _DiagnosticWaitingSurface({required this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 10),
            Text(
              'TEST: $label',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticEngineBadge extends StatelessWidget {
  final String engine;
  final bool switching;
  final String? error;

  const _DiagnosticEngineBadge({
    required this.engine,
    required this.switching,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = error?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          errorText != null && errorText.isNotEmpty
              ? 'TEST $engine ERROR: $errorText'
              : switching
              ? 'TEST switching engine...'
              : 'TEST $engine',
          style: TextStyle(
            color: errorText != null && errorText.isNotEmpty
                ? Colors.redAccent
                : Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PlaybackTransitionOverlay extends StatelessWidget {
  final String previewImageUrl;
  final bool showLoading;

  const _PlaybackTransitionOverlay({
    required this.previewImageUrl,
    required this.showLoading,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = previewImageUrl.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (imageUrl.isNotEmpty)
          ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
        if (showLoading)
          Center(
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: TwitchUiColors.primarySoft,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TwitchMediaKitVideoWaitingSurface extends StatelessWidget {
  const TwitchMediaKitVideoWaitingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final transitionMask = TwitchDvrTransitionMaskController.instance;
    return AnimatedBuilder(
      animation: transitionMask,
      builder: (context, _) {
        if (transitionMask.visible) {
          return _PlaybackTransitionOverlay(
            previewImageUrl: transitionMask.previewImageUrl,
            showLoading: transitionMask.showLoading,
          );
        }
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: TwitchUiColors.primarySoft,
              ),
            ),
          ),
        );
      },
    );
  }
}
