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
  String get key => switch (this) {
    _AndroidDiagnosticEngine.mediaKit =>
      TwitchPlayerEngineDiagnosticState.mediaKitKey,
    _AndroidDiagnosticEngine.videoPlayer =>
      TwitchPlayerEngineDiagnosticState.videoPlayerKey,
    _AndroidDiagnosticEngine.libVlc =>
      TwitchPlayerEngineDiagnosticState.libVlcKey,
  };

  String get label => TwitchPlayerEngineDiagnosticState.labelFor(key);
}

_AndroidDiagnosticEngine _diagnosticEngineFromKey(String key) => switch (key) {
  TwitchPlayerEngineDiagnosticState.videoPlayerKey =>
    _AndroidDiagnosticEngine.videoPlayer,
  TwitchPlayerEngineDiagnosticState.libVlcKey => _AndroidDiagnosticEngine.libVlc,
  _ => _AndroidDiagnosticEngine.mediaKit,
};

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
  late _AndroidDiagnosticEngine _diagnosticEngine;

  String? _diagnosticUri;
  String? _diagnosticError;
  bool _switchingEngine = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stableVideo = _buildVideo();
    _diagnosticEngine = _diagnosticEngineFromKey(
      TwitchPlayerEngineDiagnosticState.selectedEngineKey,
    );
    _attachExternalListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportSourceRectHint();
      unawaited(_initializeDiagnosticEngine());
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
    _detachExternalListeners();
    super.dispose();
  }

  Widget _buildVideo() {
    return Video(
      controller: widget.controller,
      fit: widget.fit,
      controls: widget.controls,
    );
  }

  void _attachExternalListeners() {
    final official = TwitchPlayerEngineDiagnosticState.videoPlayerController;
    official?.removeListener(_onOfficialVideoChanged);
    official?.addListener(_onOfficialVideoChanged);

    final vlc = TwitchPlayerEngineDiagnosticState.vlcController;
    vlc?.removeListener(_onVlcChanged);
    vlc?.addListener(_onVlcChanged);
  }

  void _detachExternalListeners() {
    TwitchPlayerEngineDiagnosticState.videoPlayerController?.removeListener(
      _onOfficialVideoChanged,
    );
    TwitchPlayerEngineDiagnosticState.vlcController?.removeListener(
      _onVlcChanged,
    );
  }

  Future<String?> _waitForCurrentMediaUri() async {
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      final candidate = TwitchMediaKitPlayerHost.currentMediaUri?.trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
      final remembered = TwitchPlayerEngineDiagnosticState.mediaUri?.trim();
      if (remembered != null && remembered.isNotEmpty) return remembered;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _initializeDiagnosticEngine() async {
    if (!Platform.isAndroid || !mounted) return;
    final uri = await _waitForCurrentMediaUri();
    if (!mounted) return;
    if (uri == null || uri.isEmpty) {
      debugPrint('[PlayerEngineTest] no current media URI; keep media_kit');
      return;
    }

    _diagnosticUri = uri;
    final selected = _diagnosticEngineFromKey(
      TwitchPlayerEngineDiagnosticState.selectedEngineKey,
    );
    try {
      await TwitchPlayerEngineDiagnosticState.selectEngine(
        engineKey: selected.key,
        uri: uri,
      );
      if (!mounted) return;
      _attachExternalListeners();
      setState(() {
        _diagnosticEngine = selected;
        _diagnosticError = null;
      });
      debugPrint(
        '[PlayerEngineTest] restore engine=${selected.label} uri=$uri',
      );
      _logDiagnosticSnapshot('restored');
    } catch (error, stackTrace) {
      debugPrint('[PlayerEngineTest] restore failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _diagnosticError = '$error';
      });
    }
  }

  Future<void> _selectDiagnosticEngine(
    _AndroidDiagnosticEngine engine,
  ) async {
    if (!Platform.isAndroid || !mounted || _switchingEngine) return;
    final uri =
        TwitchMediaKitPlayerHost.currentMediaUri?.trim() ??
        _diagnosticUri?.trim() ??
        TwitchPlayerEngineDiagnosticState.mediaUri?.trim();
    if (uri == null || uri.isEmpty) {
      setState(() => _diagnosticError = 'No active media URI');
      return;
    }

    if (_diagnosticEngine == engine &&
        TwitchPlayerEngineDiagnosticState.selectedEngineKey == engine.key) {
      return;
    }

    setState(() {
      _switchingEngine = true;
      _diagnosticError = null;
    });
    _detachExternalListeners();

    try {
      await TwitchPlayerEngineDiagnosticState.selectEngine(
        engineKey: engine.key,
        uri: uri,
      );
      if (!mounted) return;
      _attachExternalListeners();
      setState(() {
        _diagnosticEngine = engine;
        _diagnosticUri = uri;
        _switchingEngine = false;
      });
      debugPrint('[PlayerEngineTest] engine=${engine.label} uri=$uri');
      _logDiagnosticSnapshot('selected');
    } catch (error, stackTrace) {
      debugPrint('[PlayerEngineTest] failed engine=${engine.label}: $error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      _attachExternalListeners();
      setState(() {
        _diagnosticEngine = _diagnosticEngineFromKey(
          TwitchPlayerEngineDiagnosticState.selectedEngineKey,
        );
        _switchingEngine = false;
        _diagnosticError = '$error';
      });
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
        final value =
            TwitchPlayerEngineDiagnosticState.videoPlayerController?.value;
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
        final value = TwitchPlayerEngineDiagnosticState.vlcController?.value;
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
        final controller =
            TwitchPlayerEngineDiagnosticState.videoPlayerController;
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
        final controller = TwitchPlayerEngineDiagnosticState.vlcController;
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
                          child: _DiagnosticEnginePanel(
                            selected: _diagnosticEngine,
                            switching: _switchingEngine,
                            error: _diagnosticError,
                            onSelected: _selectDiagnosticEngine,
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

class _DiagnosticEnginePanel extends StatelessWidget {
  final _AndroidDiagnosticEngine selected;
  final bool switching;
  final String? error;
  final ValueChanged<_AndroidDiagnosticEngine> onSelected;

  const _DiagnosticEnginePanel({
    required this.selected,
    required this.switching,
    required this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = error?.trim();
    return Material(
      color: Colors.black.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorText != null && errorText.isNotEmpty
                  ? 'TEST ERROR: $errorText'
                  : switching
                  ? 'TEST switching...'
                  : 'TEST ${selected.label}',
              style: TextStyle(
                color: errorText != null && errorText.isNotEmpty
                    ? Colors.redAccent
                    : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final engine in _AndroidDiagnosticEngine.values)
                  ChoiceChip(
                    label: Text(
                      switch (engine) {
                        _AndroidDiagnosticEngine.mediaKit => 'media_kit',
                        _AndroidDiagnosticEngine.videoPlayer => 'video_player',
                        _AndroidDiagnosticEngine.libVlc => 'LibVLC',
                      },
                    ),
                    selected: selected == engine,
                    onSelected: switching ? null : (_) => onSelected(engine),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
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
