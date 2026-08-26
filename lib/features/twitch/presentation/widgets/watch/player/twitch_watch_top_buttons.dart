import 'package:flutter/material.dart';

import '../../shared/twitch_glass.dart';

class FollowButton extends StatelessWidget {
  final bool followed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;
  final VoidCallback? onPressed;

  const FollowButton({
    super.key,
    required this.followed,
    required this.busy,
    this.compact = false,
    this.tiny = false,
    this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight =
        height ??
        (tiny
            ? 36.0
            : compact
            ? 42.0
            : 64.0);
    final size = visualHeight;
    final radius = tiny
        ? 14.0
        : compact
        ? 16.0
        : 20.0;

    return Tooltip(
      message: followed ? '取消追隨' : '追隨',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(radius),
            backgroundColor: followed
                ? Colors.pinkAccent.withValues(alpha: 0.24)
                : Colors.black.withValues(alpha: 0.42),
            borderColor: followed
                ? Colors.pinkAccent.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.10),
            blurSigma: 0,
            boxShadow: const <BoxShadow>[],
            child: SizedBox(
              width: size,
              height: visualHeight,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        followed ? Icons.favorite : Icons.favorite_border,
                        color: followed ? Colors.pinkAccent : Colors.white,
                        size: tiny
                            ? 20
                            : compact
                            ? 23
                            : 32,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubscribeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const SubscribeButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight =
        height ??
        (tiny
            ? 36.0
            : compact
            ? 42.0
            : 64.0);
    final radius = tiny
        ? 14.0
        : compact
        ? 16.0
        : 20.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: TwitchGlassSurface(
          borderRadius: BorderRadius.circular(radius),
          backgroundColor: const Color(0xFF9146FF).withValues(alpha: 0.28),
          borderColor: const Color(0xFFBF94FF).withValues(alpha: 0.30),
          blurSigma: 0,
          boxShadow: const <BoxShadow>[],
          child: SizedBox(
            height: visualHeight,
            width: compact ? visualHeight : null,
            child: Padding(
              padding: compact
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 22),
              child: Center(
                child: compact
                    ? Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: tiny ? 19 : 22,
                      )
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
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 19,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChannelLibraryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;
  final bool tiny;
  final double? height;

  const ChannelLibraryButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight =
        height ??
        (tiny
            ? 36.0
            : compact
            ? 42.0
            : 64.0);
    final radius = tiny
        ? 14.0
        : compact
        ? 16.0
        : 20.0;

    return Tooltip(
      message: 'About / VOD',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(radius),
            backgroundColor: Colors.black.withValues(alpha: 0.42),
            borderColor: const Color(0xFFBF94FF).withValues(alpha: 0.22),
            blurSigma: 0,
            boxShadow: const <BoxShadow>[],
            child: SizedBox(
              height: visualHeight,
              width: compact ? visualHeight : null,
              child: Padding(
                padding: compact
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: compact
                      ? Icon(
                          Icons.video_library_rounded,
                          color: const Color(0xFFBF94FF),
                          size: tiny ? 18 : 21,
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.video_library_rounded,
                              color: Color(0xFFBF94FF),
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'About / VOD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateClipButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;
  final bool tiny;
  final double? height;

  const CreateClipButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.compact = false,
    this.tiny = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final visualHeight =
        height ??
        (tiny
            ? 36.0
            : compact
            ? 42.0
            : 64.0);
    final radius = tiny
        ? 14.0
        : compact
        ? 16.0
        : 20.0;

    return Tooltip(
      message: '建立 Clip',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: TwitchGlassSurface(
            borderRadius: BorderRadius.circular(radius),
            backgroundColor: const Color(0xFF4C1D95).withValues(alpha: 0.24),
            borderColor: const Color(0xFFBF94FF).withValues(alpha: 0.26),
            blurSigma: 0,
            boxShadow: const <BoxShadow>[],
            child: SizedBox(
              height: visualHeight,
              width: visualHeight,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.movie_creation_outlined,
                        color: const Color(0xFFBF94FF),
                        size: tiny
                            ? 18
                            : compact
                            ? 21
                            : 28,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
