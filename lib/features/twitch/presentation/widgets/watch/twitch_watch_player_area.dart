// PATCH VERSION: watch_player_area_stage95_equal_top_controls
// Place at: lib/features/twitch/presentation/widgets/watch/twitch_watch_player_area.dart
//
// StreamNook-style player area:
// - Top action bar: equal-height Follow / Subscribe / Reload / Close
// - Bottom controls: play/pause, media_kit progress/time status, volume, quality, chat toggle, fullscreen, More > Debug
// - The Follow action is supplied by WatchPage through private GQL service.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';
import '../../../services/playback/twitch_playlist_player_runtime.dart';

class TwitchWatchPlayerArea extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final Player player;
  final VideoController videoController;
  final TwitchStreamHeaderMetadata metadata;
  final bool loading;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  // Compatibility with current watch_page call site. These values are optional
  // aliases because older WatchPage versions pass quality/relationship state
  // directly instead of reading it from playerRuntime.
  final List<TwitchM3u8Variant>? qualityVariants;
  final TwitchM3u8Variant? currentVariant;
  final bool qualityBusy;
  final ValueChanged<TwitchM3u8Variant>? onQualitySelected;
  final bool relationshipBusy;
  final String? relationshipError;

  final bool isFollowing;
  final bool followBusy;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;

  final bool chatVisible;
  final VoidCallback? onToggleChat;
  final bool fullscreen;
  final bool fullscreenMode;
  final bool showFullscreenButton;
  final VoidCallback? onToggleFullscreen;

  final bool muted;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<TwitchM3u8Variant>? onQualityChanged;

  const TwitchWatchPlayerArea({
    super.key,
    required this.playerRuntime,
    required this.player,
    required this.videoController,
    required this.metadata,
    required this.loading,
    required this.error,
    required this.onBack,
    required this.onReload,
    required this.onStop,
    this.qualityVariants,
    this.currentVariant,
    this.qualityBusy = false,
    this.onQualitySelected,
    this.relationshipBusy = false,
    this.relationshipError,
    this.isFollowing = false,
    this.followBusy = false,
    this.onToggleFollow,
    this.onSubscribe,
    this.chatVisible = true,
    this.onToggleChat,
    this.fullscreen = false,
    this.fullscreenMode = false,
    this.showFullscreenButton = true,
    this.onToggleFullscreen,
    this.muted = false,
    this.volume = 100,
    this.onToggleMute,
    this.onVolumeChanged,
    this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playerRuntime,
      builder: (context, _) {
        final effectiveFullscreen = fullscreen || fullscreenMode;
        final effectiveChatVisible = chatVisible;
        final effectiveFollowBusy = followBusy || relationshipBusy;
        final effectiveQualityVariants =
            qualityVariants ?? playerRuntime.variants;
        final effectiveCurrentVariant =
            currentVariant ?? playerRuntime.currentVariant;
        final effectiveOnQualityChanged =
            onQualityChanged ?? onQualitySelected;

        return Container(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: Video(
                  controller: videoController,
                  fit: BoxFit.contain,
                  // v37: 把 Watch Page 的控制列放進 media_kit Video.controls。
                  // Windows 上原生 video surface 有時會蓋住 Flutter Stack overlay，
                  // 造成「有聲音但黑畫面、控制列出不來」。放進 controls layer
                  // 可避免控制列被 video surface 壓在下面。
                  controls: (_) => _WatchControlsOverlay(
                    loading: loading ||
                        playerRuntime.loading ||
                        playerRuntime.switchingQuality,
                    error: error,
                    runtimeError: playerRuntime.error,
                    metadata: metadata,
                    isFollowing: isFollowing,
                    followBusy: effectiveFollowBusy,
                    onBack: onBack,
                    onToggleFollow: onToggleFollow,
                    onSubscribe: onSubscribe,
                    onReload: onReload,
                    onStop: onStop,
                    player: player,
                    playerRuntime: playerRuntime,
                    muted: muted,
                    volume: volume,
                    fullscreen: effectiveFullscreen,
                    chatVisible: effectiveChatVisible,
                    showFullscreenButton: showFullscreenButton,
                    onToggleMute: onToggleMute,
                    onVolumeChanged: onVolumeChanged,
                    qualityVariants: effectiveQualityVariants,
                    currentVariant: effectiveCurrentVariant,
                    onQualityChanged: effectiveOnQualityChanged,
                    onToggleChat: onToggleChat,
                    onToggleFullscreen: onToggleFullscreen,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _WatchControlsOverlay extends StatefulWidget {
  final bool loading;
  final String? error;
  final Object? runtimeError;
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;
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

  const _WatchControlsOverlay({
    required this.loading,
    required this.error,
    required this.runtimeError,
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStop,
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
  });

  @override
  State<_WatchControlsOverlay> createState() => _WatchControlsOverlayState();
}

class _WatchControlsOverlayState extends State<_WatchControlsOverlay> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _WatchControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading || widget.error != null || widget.runtimeError != null) {
      _showAndHold();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.loading || widget.error != null || widget.runtimeError != null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  void _showAndHold() {
    _hideTimer?.cancel();
    if (!_visible && mounted) {
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showAndHold(),
      onHover: (_) => _showAndHold(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _showAndHold,
        child: Stack(
          children: [
            Positioned.fill(
              child: _PlayerDimOverlay(visible: widget.loading),
            ),
            IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: _WatchTopActionBar(
                        metadata: widget.metadata,
                        isFollowing: widget.isFollowing,
                        followBusy: widget.followBusy,
                        onBack: widget.onBack,
                        onToggleFollow: widget.onToggleFollow,
                        onSubscribe: widget.onSubscribe,
                        onReload: widget.onReload,
                        onStop: widget.onStop,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: SafeArea(
                        top: false,
                        minimum: const EdgeInsets.only(bottom: 2),
                        child: _WatchBottomControlBar(
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.error != null && widget.error!.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: _ErrorCard(message: widget.error!),
              ),
            if (widget.runtimeError != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 88,
                child: _ErrorCard(message: widget.runtimeError.toString()),
              ),
          ],
        ),
      ),
    );
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
        child: CircularProgressIndicator(color: Color(0xFF9146FF)),
      ),
    );
  }
}

class _WatchTopActionBar extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool isFollowing;
  final bool followBusy;
  final VoidCallback onBack;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onSubscribe;
  final VoidCallback? onReload;
  final VoidCallback onStop;

  const _WatchTopActionBar({
    required this.metadata,
    required this.isFollowing,
    required this.followBusy,
    required this.onBack,
    required this.onToggleFollow,
    required this.onSubscribe,
    required this.onReload,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final actionTiny = constraints.maxWidth < 430;
        final actionGap = actionTiny ? 6.0 : 9.0;

        // Stage 101: keep every visible item in the top action bar at the
        // same visual height. This avoids the 1px bottom overflow caused by
        // the info card having a different internal height from the buttons.
        final slotHeight = compact ? 62.0 : 78.0;
        final controlHeight = compact ? 52.0 : 72.0;

        final infoCard = _WatchStreamHeaderCard(
          metadata: metadata,
          compact: compact,
          height: controlHeight,
        );

        final actionButtons = <Widget>[
          _FollowButton(
            followed: isFollowing,
            busy: followBusy,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onToggleFollow,
          ),
          SizedBox(width: actionGap),
          _SubscribeButton(
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onSubscribe,
          ),
          SizedBox(width: actionGap),
          _RoundIconButton(
            tooltip: '重新載入',
            icon: Icons.refresh,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onReload,
          ),
          SizedBox(width: actionGap),
          _RoundIconButton(
            tooltip: '停止',
            icon: Icons.close,
            iconColor: Colors.redAccent,
            compact: compact,
            tiny: actionTiny,
            height: controlHeight,
            onPressed: onStop,
          ),
        ];

        Widget content;
        double designWidth;

        if (compact) {
          designWidth = actionTiny ? 470 : 570;
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoundIconButton(
                tooltip: '返回',
                icon: Icons.arrow_back,
                compact: true,
                tiny: actionTiny,
                height: controlHeight,
                onPressed: onBack,
              ),
              SizedBox(width: actionGap),
              _WatchCompactAvatarTile(
                metadata: metadata,
                tiny: actionTiny,
                height: controlHeight,
              ),
              const Spacer(),
              SizedBox(width: actionGap),
              ...actionButtons,
            ],
          );
        } else {
          designWidth = 1040;
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoundIconButton(
                tooltip: '返回',
                icon: Icons.arrow_back,
                height: controlHeight,
                onPressed: onBack,
              ),
              const SizedBox(width: 10),
              Expanded(child: infoCard),
              const SizedBox(width: 12),
              ...actionButtons,
            ],
          );
        }

        // Stage 102: keep full-width behavior, but restore the top-bar
        // scaleDown safety net for every breakpoint. If the viewport is
        // narrower than the designed row, shrink the whole row instead of
        // letting fixed-height buttons/info cards overflow. When there is
        // enough space, use the full available width so the info card stretches.
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : designWidth;
        final shouldScaleDown = availableWidth < designWidth;

        if (!shouldScaleDown) {
          return SizedBox(
            width: double.infinity,
            height: slotHeight,
            child: content,
          );
        }

        return SizedBox(
          width: double.infinity,
          height: slotHeight,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: designWidth,
                  height: slotHeight,
                  child: Center(child: content),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


class _WatchCompactAvatarTile extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool tiny;
  final double height;

  const _WatchCompactAvatarTile({
    required this.metadata,
    required this.tiny,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final channelLogin = metadata.channelLogin.trim();
    final profileImageUrl = metadata.profileImageUrl.trim();
    final tileSize = height;
    final size = math.min(tileSize - 12.0, tiny ? 36.0 : 40.0);

    return Tooltip(
      message: channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
      child: Container(
        width: tileSize,
        height: tileSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xDD0E0E10),
          borderRadius: BorderRadius.circular(tiny ? 12 : 14),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _WatchChannelAvatar(
          imageUrl: profileImageUrl,
          channelLogin: channelLogin,
          size: size,
        ),
      ),
    );
  }
}

class _WatchStreamHeaderCard extends StatelessWidget {
  final TwitchStreamHeaderMetadata metadata;
  final bool compact;
  final double height;

  const _WatchStreamHeaderCard({
    required this.metadata,
    required this.compact,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final channelLogin = metadata.channelLogin.trim();
    final streamTitle = metadata.streamTitle.trim();
    final gameName = metadata.gameName.trim();
    final viewerCount = metadata.viewerCount;
    final profileImageUrl = metadata.profileImageUrl.trim();
    final language = metadata.language.trim().toUpperCase();

    final avatarSize = compact ? 34.0 : 44.0;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 16,
        vertical: compact ? 5 : 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xDD0E0E10),
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: compact ? 12 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _WatchChannelAvatar(
            imageUrl: profileImageUrl,
            channelLogin: channelLogin,
            size: avatarSize,
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Tooltip(
                        message: channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
                        child: Text(
                          channelLogin.isEmpty ? 'Twitch Stream' : channelLogin,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 13.5 : 17,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                    if (viewerCount != null && viewerCount > 0) ...[
                      SizedBox(width: compact ? 5 : 7),
                      _WatchInfoPill(
                        icon: Icons.visibility_rounded,
                        label: _formatViewerCount(viewerCount),
                        compact: compact,
                      ),
                    ],
                    if (gameName.isNotEmpty) ...[
                      SizedBox(width: compact ? 5 : 7),
                      _WatchInfoPill(
                        icon: Icons.sports_esports_rounded,
                        label: gameName,
                        copyText: gameName,
                        compact: compact,
                      ),
                    ],
                    if (language.isNotEmpty) ...[
                      SizedBox(width: compact ? 5 : 7),
                      _WatchInfoPill(
                        icon: Icons.translate_rounded,
                        label: language,
                        copyText: metadata.language.trim(),
                        compact: compact,
                        maxWidth: compact ? 62 : 72,
                      ),
                    ],
                  ],
                ),
                if (streamTitle.isNotEmpty) ...[
                  SizedBox(height: compact ? 3 : 4),
                  Tooltip(
                    message: streamTitle,
                    child: Text(
                      streamTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: compact ? 11.5 : 13,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _WatchChannelAvatar extends StatelessWidget {
  final String imageUrl;
  final String channelLogin;
  final double size;

  const _WatchChannelAvatar({
    required this.imageUrl,
    required this.channelLogin,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    final fallbackLetter = channelLogin.trim().isEmpty
        ? 'T'
        : channelLogin.trim().characters.first.toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A2236),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          clipBehavior: Clip.antiAlias,
          child: cleanUrl.isEmpty
              ? Center(
                  child: Text(
                    fallbackLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Image.network(
                  cleanUrl,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 2).round(),
                  cacheHeight: (size * 2).round(),
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      fallbackLetter,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.30,
            height: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF57F287),
              border: Border.all(color: const Color(0xDD0E0E10), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatViewerCount(int value) {
  if (value >= 10000) {
    final text = (value / 10000).toStringAsFixed(value >= 100000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}萬人';
  }
  if (value >= 1000) {
    final text = (value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}k 人';
  }
  return '$value 人';
}

class _WatchInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? copyText;
  final bool compact;
  final double? maxWidth;

  const _WatchInfoPill({
    required this.icon,
    required this.label,
    this.copyText,
    this.compact = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final canCopy = copyText != null && copyText!.trim().isNotEmpty;

    return Tooltip(
      message: canCopy ? '點擊複製：$label' : label,
      child: Material(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: canCopy
              ? () async {
                  await Clipboard.setData(ClipboardData(text: copyText!.trim()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已複製：$label')),
                  );
                }
              : null,
          child: Container(
            height: compact ? 24 : 28,
            constraints: BoxConstraints(maxWidth: maxWidth ?? (compact ? 120 : 190)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: compact ? 13 : 15, color: const Color(0xFFBF94FF)),
                SizedBox(width: compact ? 4 : 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool followed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;
  final VoidCallback? onPressed;

  const _FollowButton({
    required this.followed,
    required this.busy,
    this.compact = false,
    this.tiny = false,
    this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final size = visualHeight;
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;

    return Tooltip(
      message: followed ? '取消追隨' : '追隨',
      child: Material(
        color: const Color(0xDD18181B),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Container(
            width: size,
            height: visualHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    followed ? Icons.favorite : Icons.favorite_border,
                    color: followed ? Colors.pinkAccent : Colors.white,
                    size: tiny ? 20 : compact ? 23 : 32,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const _SubscribeButton({
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;

    return Material(
      color: const Color(0xDD18181B),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: visualHeight,
          width: compact ? visualHeight : null,
          padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: compact
              ? Icon(Icons.auto_awesome, color: Colors.white, size: tiny ? 19 : 22)
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Subscribe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, color: Colors.white, size: 19),
                  ],
                ),
        ),
      ),
    );
  }
}

class _WatchBottomControlBar extends StatelessWidget {
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

  const _WatchBottomControlBar({
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
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: player.state.playing,
      builder: (context, playingSnapshot) {
        final playing = playingSnapshot.data ?? false;

        return LayoutBuilder(
          builder: (context, constraints) {
            final veryNarrow = constraints.maxWidth < 430;
            final useCompactLayout = constraints.maxWidth < 700;
            final barHeight = useCompactLayout ? 58.0 : 72.0;
            final horizontalPadding = veryNarrow ? 4.0 : useCompactLayout ? 7.0 : 20.0;

            final compactDesignWidth = veryNarrow ? 430.0 : 620.0;
            final compactDesignHeight = 58.0;
            final contentWidth = useCompactLayout ? compactDesignWidth : constraints.maxWidth;
            final contentHeight = useCompactLayout ? compactDesignHeight : barHeight;

            final controlsContent = SizedBox(
              width: contentWidth,
              height: contentHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: useCompactLayout
                    ? Row(
                        children: [
                          _PlainIconButton(
                            tooltip: playing ? '暫停' : '播放',
                            icon: playing ? Icons.pause : Icons.play_arrow,
                            size: veryNarrow ? 26 : 28,
                            dense: true,
                            onPressed: () {
                              unawaited(playing ? player.pause() : player.play());
                            },
                          ),
                          SizedBox(width: veryNarrow ? 2 : 6),
                          Expanded(
                            child: _LivePlaybackStrip(
                              player: player,
                              playerRuntime: playerRuntime,
                              compact: true,
                            ),
                          ),
                          SizedBox(width: veryNarrow ? 2 : 6),
                          _CompactInlineVolumeControl(
                            muted: muted,
                            volume: volume,
                            sliderWidth: veryNarrow ? 54 : 76,
                            onToggleMute: onToggleMute,
                            onVolumeChanged: onVolumeChanged,
                          ),
                          if (!veryNarrow) ...[
                            const SizedBox(width: 4),
                            _QualityButton(
                              variants: qualityVariants,
                              currentVariant: currentVariant,
                              onChanged: onQualityChanged,
                            ),
                          ],
                          _PlainIconButton(
                            tooltip: chatVisible ? '隱藏聊天室' : '顯示聊天室',
                            icon: chatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: veryNarrow ? 21 : 23,
                            active: chatVisible,
                            dense: true,
                            onPressed: onToggleChat,
                          ),
                          if (showFullscreenButton)
                            _PlainIconButton(
                              tooltip: fullscreen ? '離開全螢幕' : '全螢幕',
                              icon: fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: veryNarrow ? 23 : 25,
                              active: fullscreen,
                              dense: true,
                              onPressed: onToggleFullscreen,
                            ),
                          _PlayerMoreActionsButton(playerRuntime: playerRuntime),
                        ],
                      )
                    : Row(
                        children: [
                          _PlainIconButton(
                            tooltip: playing ? '暫停' : '播放',
                            icon: playing ? Icons.pause : Icons.play_arrow,
                            size: 32,
                            onPressed: () {
                              unawaited(playing ? player.pause() : player.play());
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _LivePlaybackStrip(
                              player: player,
                              playerRuntime: playerRuntime,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _PlainIconButton(
                            tooltip: muted ? '取消靜音' : '靜音',
                            icon: muted || volume <= 0
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 24,
                            onPressed: onToggleMute,
                          ),
                          SizedBox(
                            width: 92,
                            child: Slider(
                              value: volume.clamp(0.0, 100.0).toDouble(),
                              min: 0,
                              max: 100,
                              onChanged: onVolumeChanged,
                            ),
                          ),
                          _QualityButton(
                            variants: qualityVariants,
                            currentVariant: currentVariant,
                            onChanged: onQualityChanged,
                          ),
                          _PlainIconButton(
                            tooltip: chatVisible ? '隱藏聊天室' : '顯示聊天室',
                            icon: chatVisible
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            size: 23,
                            active: chatVisible,
                            onPressed: onToggleChat,
                          ),
                          if (showFullscreenButton)
                            _PlainIconButton(
                              tooltip: fullscreen ? '離開全螢幕' : '全螢幕',
                              icon: fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              size: 25,
                              active: fullscreen,
                              onPressed: onToggleFullscreen,
                            ),
                          _PlayerMoreActionsButton(playerRuntime: playerRuntime),
                        ],
                      ),
              ),
            );

            return Container(
              height: barHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xEE0E0E10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: useCompactLayout
                  ? ClipRect(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: controlsContent,
                      ),
                    )
                  : controlsContent,
            );
          },
        );
      },
    );
  }
}


class _CompactInlineVolumeControl extends StatelessWidget {
  final bool muted;
  final double volume;
  final double sliderWidth;
  final VoidCallback? onToggleMute;
  final ValueChanged<double>? onVolumeChanged;

  const _CompactInlineVolumeControl({
    required this.muted,
    required this.volume,
    required this.sliderWidth,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlainIconButton(
          tooltip: muted ? '取消靜音' : '靜音',
          icon: muted || volume <= 0 ? Icons.volume_off : Icons.volume_up,
          size: 21,
          dense: true,
          active: muted || volume <= 0,
          onPressed: onToggleMute,
        ),
        SizedBox(
          width: sliderWidth,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 5.5,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 10,
              ),
            ),
            child: Slider(
              value: volume.clamp(0.0, 100.0).toDouble(),
              min: 0,
              max: 100,
              onChanged: onVolumeChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LivePlaybackStrip extends StatelessWidget {
  final Player player;
  final TwitchPlaylistPlayerRuntime playerRuntime;
  final bool compact;

  const _LivePlaybackStrip({
    required this.player,
    required this.playerRuntime,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            return StreamBuilder<bool>(
              stream: player.stream.buffering,
              initialData: player.state.buffering,
              builder: (context, bufferingSnapshot) {
                return StreamBuilder<bool>(
                  stream: player.stream.playing,
                  initialData: player.state.playing,
                  builder: (context, playingSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final buffering = bufferingSnapshot.data ?? false;
                    final playing = playingSnapshot.data ?? false;

                    final hasSeekableDuration = duration.inMilliseconds > 500;
                    final rawValue = hasSeekableDuration
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 1.0;
                    final value = rawValue.clamp(0.0, 1.0).toDouble();
                    final liveLag = hasSeekableDuration
                        ? duration - position
                        : Duration.zero;
                    final isAtLiveEdge = !hasSeekableDuration ||
                        liveLag <= const Duration(milliseconds: 1200) ||
                        value >= 0.992;
                    final positionText = _formatDuration(position);
                    final durationText = hasSeekableDuration
                        ? _formatDuration(duration)
                        : '--:--';
                    final liveColor = buffering
                        ? Colors.orangeAccent
                        : isAtLiveEdge
                            ? Colors.redAccent
                            : Colors.white60;

                    final liveText = buffering
                        ? 'BUFFER'
                        : isAtLiveEdge
                            ? 'LIVE'
                            : '$positionText / $durationText';

                    return Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: compact ? 4 : 5,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: compact ? 6 : 7,
                              ),
                            ),
                            child: Slider(
                              value: value,
                              min: 0,
                              max: 1,
                              onChanged: hasSeekableDuration
                                  ? (next) {
                                      final targetMs =
                                          (duration.inMilliseconds * next).round();
                                      unawaited(
                                        player.seek(Duration(milliseconds: targetMs)),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 8 : 12),
                        Tooltip(
                          message: _timeStatusTooltip(
                            position: position,
                            duration: duration,
                            buffering: buffering,
                            playing: playing,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: compact ? 82 : 108,
                              maxWidth: compact ? 104 : 136,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 4 : 6,
                                vertical: compact ? 5 : 6,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isAtLiveEdge || buffering) ...[
                                    Container(
                                      width: compact ? 6 : 7,
                                      height: compact ? 6 : 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: buffering
                                            ? Colors.orangeAccent
                                            : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      liveText,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: liveColor,
                                        fontSize: compact ? 11 : 12,
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  static String _timeStatusTooltip({
    required Duration position,
    required Duration duration,
    required bool buffering,
    required bool playing,
  }) {
    final pos = _formatDuration(position);
    final dur = duration.inMilliseconds > 0 ? _formatDuration(duration) : '--:--';
    final state = buffering ? 'buffering' : playing ? 'playing' : 'paused';
    return 'media_kit $state · $pos / $dur';
  }

  static String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final minutesTotal = totalSeconds ~/ 60;
    final minutes = (minutesTotal % 60).toString().padLeft(2, '0');
    final hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

enum _PlayerMoreAction {
  debug,
}

class _PlayerMoreActionsButton extends StatefulWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _PlayerMoreActionsButton({required this.playerRuntime});

  @override
  State<_PlayerMoreActionsButton> createState() => _PlayerMoreActionsButtonState();
}

class _PlayerMoreActionsButtonState extends State<_PlayerMoreActionsButton> {
  final GlobalKey _buttonKey = GlobalKey();

  bool get _showDebugMenu {
    return !Platform.isAndroid && !Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showDebugMenu) return const SizedBox.shrink();

    return IconButton(
      key: _buttonKey,
      tooltip: '更多',
      splashRadius: 22,
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
      onPressed: _openMoreMenu,
    );
  }

  Future<void> _openMoreMenu() async {
    final selected = await _showAnchoredMenu<_PlayerMoreAction>(
      width: 184,
      height: 56,
      items: const <PopupMenuEntry<_PlayerMoreAction>>[
        PopupMenuItem<_PlayerMoreAction>(
          value: _PlayerMoreAction.debug,
          child: _DebugMenuRow(
            icon: Icons.bug_report_outlined,
            label: 'Debug  ›',
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _PlayerMoreAction.debug:
        await _openDebugSubmenu();
        break;
    }
  }

  Future<void> _openDebugSubmenu() async {
    final selected = await _showAnchoredMenu<_PlaybackDebugCopyAction>(
      width: 270,
      height: 112,
      items: const <PopupMenuEntry<_PlaybackDebugCopyAction>>[
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.proxyUrl,
          child: _DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.mpvProxyCommand,
          child: _DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    await _PlaybackDebugCopyButton.copyAction(
      context: context,
      playerRuntime: widget.playerRuntime,
      action: selected,
    );
  }

  Future<T?> _showAnchoredMenu<T>({
    required double width,
    required double height,
    required List<PopupMenuEntry<T>> items,
  }) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final buttonContext = _buttonKey.currentContext;
    final buttonBox = buttonContext?.findRenderObject() as RenderBox?;

    if (overlay == null || buttonBox == null || !buttonBox.hasSize) {
      return Future<T?>.value(null);
    }

    final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomRight = buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final left = (buttonBottomRight.dx - width)
        .clamp(8.0, math.max(8.0, overlay.size.width - width - 8.0))
        .toDouble();

    final preferAbove = buttonTopLeft.dy > height + 16;
    final top = preferAbove
        ? (buttonTopLeft.dy - height - 10.0)
            .clamp(8.0, math.max(8.0, overlay.size.height - height - 8.0))
            .toDouble()
        : (buttonBottomRight.dy + 8.0)
            .clamp(8.0, math.max(8.0, overlay.size.height - height - 8.0))
            .toDouble();

    return showMenu<T>(
      context: context,
      color: const Color(0xFF18181B),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(left, top, width, height),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
  }
}

enum _PlaybackDebugCopyAction {
  proxyUrl,
  mpvProxyCommand,
}

class _PlaybackDebugCopyButton extends StatelessWidget {
  final TwitchPlaylistPlayerRuntime playerRuntime;

  const _PlaybackDebugCopyButton({required this.playerRuntime});

  static const String _mpvUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  @override
  Widget build(BuildContext context) {
    final proxyUrl = playerRuntime.proxyMpvUrl?.trim() ?? playerRuntime.proxyUrl?.trim();
    final hasProxyUrl = proxyUrl != null && proxyUrl.isNotEmpty;

    return PopupMenuButton<_PlaybackDebugCopyAction>(
      tooltip: 'Debug：複製 Dart Proxy URL',
      color: const Color(0xFF18181B),
      icon: const Icon(Icons.bug_report_outlined, color: Colors.white, size: 23),
      enabled: hasProxyUrl,
      onSelected: (action) => _handleCopy(context, action),
      itemBuilder: (context) => <PopupMenuEntry<_PlaybackDebugCopyAction>>[
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.proxyUrl,
          enabled: hasProxyUrl,
          child: const _DebugMenuRow(
            icon: Icons.link,
            label: '複製 Dart Proxy URL',
          ),
        ),
        PopupMenuItem<_PlaybackDebugCopyAction>(
          value: _PlaybackDebugCopyAction.mpvProxyCommand,
          enabled: hasProxyUrl,
          child: const _DebugMenuRow(
            icon: Icons.terminal,
            label: '複製 mpv Proxy 指令',
          ),
        ),
      ],
    );
  }

  Future<void> _handleCopy(
    BuildContext context,
    _PlaybackDebugCopyAction action,
  ) {
    return copyAction(
      context: context,
      playerRuntime: playerRuntime,
      action: action,
    );
  }

  static Future<void> copyAction({
    required BuildContext context,
    required TwitchPlaylistPlayerRuntime playerRuntime,
    required _PlaybackDebugCopyAction action,
  }) async {
    final proxyUrl =
        playerRuntime.proxyMpvUrl?.trim() ?? playerRuntime.proxyUrl?.trim();
    if (proxyUrl == null || proxyUrl.isEmpty) {
      _showCopySnack(context, '目前沒有可複製的 Dart Proxy URL。');
      return;
    }

    String label;
    String text;
    switch (action) {
      case _PlaybackDebugCopyAction.proxyUrl:
        label = 'Dart Proxy URL';
        text = proxyUrl;
        break;
      case _PlaybackDebugCopyAction.mpvProxyCommand:
        label = 'mpv Proxy 指令';
        text = _buildMpvCommand(proxyUrl);
        break;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    _showCopySnack(context, '已複製$label。');
  }

  static String _buildMpvCommand(String url) {
    final escapedUrl = _escapeForDoubleQuotedShell(url);
    return 'mpv '
        '--msg-level=ffmpeg/video=fatal '
        '--user-agent="$_mpvUserAgent" '
        '--referrer="https://www.twitch.tv/" '
        '--http-header-fields="Origin: https://www.twitch.tv" '
        '"$escapedUrl"';
  }

  static String _escapeForDoubleQuotedShell(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', r'\"')
        .replaceAll(r'$', r'\$')
        .replaceAll('`', r'\`');
  }

  static void _showCopySnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DebugMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DebugMenuRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFBF94FF), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _QualityButton extends StatelessWidget {
  final List<TwitchM3u8Variant> variants;
  final TwitchM3u8Variant? currentVariant;
  final ValueChanged<TwitchM3u8Variant>? onChanged;

  const _QualityButton({
    required this.variants,
    required this.currentVariant,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TwitchM3u8Variant>(
      tooltip: '畫質：${currentVariant?.displayName ?? currentVariant?.name ?? '自動'}',
      color: const Color(0xFF18181B),
      icon: const Icon(Icons.settings, color: Colors.white, size: 24),
      onSelected: onChanged,
      itemBuilder: (context) {
        if (variants.isEmpty) {
          return const [
            PopupMenuItem<TwitchM3u8Variant>(
              enabled: false,
              child: Text('尚未取得畫質', style: TextStyle(color: Colors.white54)),
            ),
          ];
        }

        return variants.map((variant) {
          final selected = variant.name == currentVariant?.name &&
              variant.url == currentVariant?.url;
          return PopupMenuItem<TwitchM3u8Variant>(
            value: variant,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: selected
                      ? const Icon(Icons.check, color: Color(0xFF9146FF), size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    variant.displayName.isNotEmpty ? variant.displayName : variant.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    this.iconColor = Colors.white,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = height ?? (tiny ? 36.0 : compact ? 42.0 : 64.0);
    final radius = tiny ? 13.0 : compact ? 15.0 : 18.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xDD18181B),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Icon(icon, color: iconColor, size: tiny ? 20 : compact ? 23 : 30),
          ),
        ),
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final bool dense;

  const _PlainIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 25,
    this.active = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!dense) {
      return IconButton(
        tooltip: tooltip,
        splashRadius: 22,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: active ? const Color(0xFFBF94FF) : Colors.white,
          size: size,
        ),
      );
    }

    final hitSize = (size + 16).clamp(34.0, 48.0).toDouble();

    return IconButton(
      tooltip: tooltip,
      splashRadius: hitSize / 2,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: hitSize, height: hitSize),
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: active ? const Color(0xFFBF94FF) : Colors.white,
        size: size,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.36)),
      ),
      child: SelectableText(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
      ),
    );
  }
}
