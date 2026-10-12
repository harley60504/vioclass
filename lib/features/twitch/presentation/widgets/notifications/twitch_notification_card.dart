import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../services/notifications/twitch_app_notification_service.dart';
import '../../localization/vioclass_localizations.dart';
import '../shared/twitch_cached_image_layer.dart';

/// The same compact glass surface is used by transient and history notifications.
class TwitchNotificationCard extends StatelessWidget {
  final TwitchAppNotification item;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;
  const TwitchNotificationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final stream = item.liveStream;
    final actionable = item.whisperTarget != null || item.onOpen != null;
    final accent = item.accentColor;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.createdAt),
      alwaysUse24HourFormat: true,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * -8),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xEE25232E), const Color(0xDB15151D)],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: InkWell(
                onTap: actionable ? onOpen : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 6, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NotificationPortrait(item: item),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (stream != null) ...[
                                  if (stream.gameName.trim().isNotEmpty)
                                    Text(
                                      stream.gameName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFCBBBDD),
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (stream.title.trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      stream.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ] else if (item.message.trim().isNotEmpty)
                                  Text(
                                    item.message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 3),
                          Semantics(
                            label: context.vio.t('關閉通知'),
                            child: IconButton(
                              onPressed: onDismiss,
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.category ==
                                  TwitchAppNotificationCategory.live) ...[
                                const Icon(
                                  Icons.circle,
                                  color: Color(0xFFE88998),
                                  size: 6,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  context.vio.t('直播'),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ] else
                                Icon(
                                  item.icon,
                                  size: 12,
                                  color: accent.withValues(alpha: 0.8),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                time,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (actionable)
                            TextButton(
                              onPressed: onOpen,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFD0B8F4),
                                minimumSize: const Size(0, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                context.vio.t(stream != null ? '觀看直播' : '開啟'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
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

class _NotificationPortrait extends StatelessWidget {
  final TwitchAppNotification item;
  const _NotificationPortrait({required this.item});
  @override
  Widget build(BuildContext context) {
    final avatars = item.avatarUrls;
    if (avatars.isNotEmpty) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          children: [
            for (var index = avatars.length - 1; index >= 0; index--)
              Positioned(
                left: avatars.length == 1 ? 0 : index * 5,
                top: avatars.length == 1 ? 0 : index * 4,
                child: TwitchCachedImageLayer.avatar(
                  imageUrl: avatars[index],
                  size: avatars.length == 1 ? 40 : 30,
                  cacheWidth: 80,
                  cacheHeight: 80,
                  fallbackIcon: Icons.person_outline_rounded,
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: item.accentColor.withValues(alpha: 0.09),
      ),
      child: Icon(item.icon, size: 20, color: item.accentColor),
    );
  }
}
