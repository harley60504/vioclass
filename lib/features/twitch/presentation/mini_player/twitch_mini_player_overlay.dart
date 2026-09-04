import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../platform/android_pip/twitch_android_pip_controller.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../../services/playback/twitch_media_kit_player_host.dart';
import '../localization/vioclass_localizations.dart';
import '../pages/twitch_watch_route_guard.dart';
import '../widgets/watch/player/twitch_player_only_surface.dart';
import '../widgets/watch/player/twitch_media_kit_video_surface.dart';
import '../watch/twitch_watch_playback_kind.dart';
import 'twitch_mini_player_controller.dart';

class TwitchMiniPlayerOverlay extends StatefulWidget {
  final TwitchMiniPlayerController controller;
  final TwitchDiscoveryService discoveryService;
  final bool androidPipEnabled;

  const TwitchMiniPlayerOverlay({
    super.key,
    required this.controller,
    required this.discoveryService,
    required this.androidPipEnabled,
  });

  @override
  State<TwitchMiniPlayerOverlay> createState() =>
      _TwitchMiniPlayerOverlayState();
}

class _TwitchMiniPlayerOverlayState extends State<TwitchMiniPlayerOverlay> {
  Offset _offset = Offset.zero;
  bool _expandingToWatchPage = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _syncAutoPip();
  }

  @override
  void didUpdateWidget(covariant TwitchMiniPlayerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (oldWidget.androidPipEnabled != widget.androidPipEnabled) {
      _syncAutoPip();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    unawaited(TwitchAndroidPipController.instance.setAutoEnterEnabled(false));
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncAutoPip();
    if (mounted) setState(() {});
  }

  void _syncAutoPip() {
    if (_expandingToWatchPage) return;
    final enabled = widget.controller.isActive && widget.androidPipEnabled;
    unawaited(TwitchAndroidPipController.instance.setAutoEnterEnabled(enabled));
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.controller.entry;
    if (entry == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: _MiniPlayerCard(
        key: ValueKey<String>(entry.mediaUri),
        entry: entry,
        androidPipEnabled: widget.androidPipEnabled,
        offset: _offset,
        onClose: widget.controller.close,
        onExpand: () async {
          final initialVodVideo = entry.kind == TwitchWatchPlaybackKind.liveDvr
              ? entry.resumeVodVideo ?? entry.activeDvrVideo
              : entry.resumeVodVideo;
          _expandingToWatchPage = true;
          final route = PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => TwitchWatchRouteGuard(
              initialMetadata: entry.metadata,
              initialDiscoveryService: widget.discoveryService,
              initialActiveDvrVideo: entry.activeDvrVideo,
              initialVodVideo: initialVodVideo,
              initialClip: entry.resumeClip,
              initialVodReplayRatio: entry.resumeVodRatio,
              initialPreferVodReplayChat: entry.resumeVodReplayChat,
              initialReuseCurrentPlayback: true,
              initialPlayerRuntime: entry.playerRuntime,
            ),
          );
          await Navigator.of(context).push(route);
          _expandingToWatchPage = false;
          _syncAutoPip();
        },
        onPanUpdate: (details) {
          setState(() => _offset += details.delta);
        },
        onPanEnd: (details) {
          setState(() => _offset = Offset.zero);
        },
      ),
    );
  }
}

class _MiniPlayerCard extends StatefulWidget {
  final TwitchMiniPlayerEntry entry;
  final bool androidPipEnabled;
  final Offset offset;
  final VoidCallback onClose;
  final Future<void> Function() onExpand;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _MiniPlayerCard({
    super.key,
    required this.entry,
    required this.androidPipEnabled,
    required this.offset,
    required this.onClose,
    required this.onExpand,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  State<_MiniPlayerCard> createState() => _MiniPlayerCardState();
}

class _MiniPlayerCardState extends State<_MiniPlayerCard> {
  late final TwitchMediaKitPlayerSession _session;
  bool _ready = false;
  bool _handingOffToWatchPage = false;

  @override
  void initState() {
    super.initState();
    _session = TwitchMediaKitPlayerHost.acquire(title: 'VioClass Mini');
    TwitchMiniPlayerController.instance.attachSession(_session);
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(null);
    unawaited(_open());
  }

  @override
  void didUpdateWidget(covariant _MiniPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.mediaUri != widget.entry.mediaUri) {
      setState(() => _ready = false);
      unawaited(_open());
    }
  }

  @override
  void dispose() {
    if (!_handingOffToWatchPage) {
      unawaited(_session.pauseCurrent().catchError((_) {}));
    }
    TwitchMiniPlayerController.instance.detachSession(_session);
    _session.release();
    super.dispose();
  }

  void _expandToWatchPage() {
    if (_handingOffToWatchPage) return;
    setState(() => _handingOffToWatchPage = true);
    unawaited(
      widget.onExpand().whenComplete(() {
        if (!mounted || TwitchMiniPlayerController.instance.entry == null) {
          return;
        }
        setState(() => _handingOffToWatchPage = false);
      }),
    );
  }

  Future<void> _open() async {
    try {
      await _session.openOrResume(uri: widget.entry.mediaUri, play: true);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ready = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pip = TwitchAndroidPipController.instance;
    if (_handingOffToWatchPage) {
      return const IgnorePointer(child: SizedBox.shrink());
    }

    return AnimatedBuilder(
      animation: pip,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final cardWidth = width < 520 ? width - 28 : 360.0;
        final title = widget.entry.metadata.channelLogin;
        final subtitle = widget.entry.metadata.streamTitle.trim();
        final videoController = _session.videoControllerOrNull;
        final renderPlayerOnly = pip.shouldRenderPlayerOnly;
        final video = AspectRatio(
          aspectRatio: 16 / 9,
          child: _ready && videoController != null
              ? TwitchMediaKitVideoSurface(
                  controller: videoController,
                  fit: BoxFit.cover,
                )
              : const TwitchMediaKitVideoWaitingSurface(),
        );

        if (renderPlayerOnly) {
          return TwitchPlayerOnlySurface(player: video, fit: BoxFit.cover);
        }

        return Stack(
          children: [
            Positioned(
              right: 14 - widget.offset.dx,
              bottom: 14 - widget.offset.dy,
              child: GestureDetector(
                onTap: _expandToWatchPage,
                onPanUpdate: widget.onPanUpdate,
                onPanEnd: widget.onPanEnd,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: cardWidth,
                    decoration: BoxDecoration(
                      color: const Color(0xF216161D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xAA000000),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        video,
                        _MiniPlayerFooter(
                          title: title.isEmpty ? context.vio.t('直播小窗') : title,
                          subtitle: subtitle,
                          playbackKind: widget.entry.kind,
                          androidPipEnabled: widget.androidPipEnabled,
                          onClose: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniPlayerFooter extends StatelessWidget {
  final String title;
  final String subtitle;
  final TwitchWatchPlaybackKind playbackKind;
  final bool androidPipEnabled;
  final VoidCallback onClose;

  const _MiniPlayerFooter({
    required this.title,
    required this.subtitle,
    required this.playbackKind,
    required this.androidPipEnabled,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Row(
                  children: [
                    _MiniPlaybackKindBadge(kind: playbackKind),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (androidPipEnabled && Platform.isAndroid)
            IconButton(
              tooltip: l10n.t('子母畫面'),
              onPressed: () async {
                final entered = await TwitchAndroidPipController.instance
                    .enterPictureInPicture(
                      aspectRatioWidth: 16,
                      aspectRatioHeight: 9,
                    );
                if (entered || !context.mounted) return;
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text(l10n.t('目前裝置不支援子母畫面'))));
              },
              icon: const Icon(Icons.picture_in_picture_alt_rounded),
              color: Colors.white70,
            ),
          IconButton(
            tooltip: l10n.t('關閉'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _MiniPlaybackKindBadge extends StatelessWidget {
  final TwitchWatchPlaybackKind kind;

  const _MiniPlaybackKindBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      TwitchWatchPlaybackKind.live => context.vio.t('直播'),
      TwitchWatchPlaybackKind.liveDvr => 'DVR',
      TwitchWatchPlaybackKind.vod => 'VOD',
      TwitchWatchPlaybackKind.clip => context.vio.t('片段'),
      TwitchWatchPlaybackKind.none => context.vio.t('播放'),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
