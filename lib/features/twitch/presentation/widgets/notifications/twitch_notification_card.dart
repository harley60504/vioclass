import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../services/notifications/twitch_app_notification_service.dart';
import '../../localization/vioclass_localizations.dart';
import '../shared/twitch_cached_image_layer.dart';

/// Shared notification content, with flat rows inside the notification center.
class TwitchNotificationCard extends StatelessWidget {
  final TwitchAppNotification item;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;
  final bool embedded;
  const TwitchNotificationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    this.onOpen,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return _NotificationHistoryRow(
        item: item,
        onDismiss: onDismiss,
        onOpen: onOpen,
      );
    }
    final stream = item.liveStream;
    final actionable = item.whisperTarget != null || item.onOpen != null;
    final accent = item.accentColor;
    final english = context.vio.isEnglish;
    final categoryLabel = switch (item.category) {
      TwitchAppNotificationCategory.live => english ? 'LIVE' : '直播',
      TwitchAppNotificationCategory.whisper => english ? 'Whispers' : '悄悄話',
      TwitchAppNotificationCategory.channelPoints =>
        english ? 'Channel Points' : '頻道點數',
      TwitchAppNotificationCategory.update => english ? 'Update' : '更新',
      TwitchAppNotificationCategory.drops => english ? 'Drops' : '掉寶',
      TwitchAppNotificationCategory.giftSubscription =>
        english ? 'Gift subscription' : '贈送訂閱',
      TwitchAppNotificationCategory.badge => english ? 'Badge' : '徽章',
      TwitchAppNotificationCategory.general => english ? 'Notification' : '通知',
    };
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
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      accent.withValues(alpha: 0.07),
                      const Color(0xF21B1725),
                    ),
                    const Color(0xEE111018),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: InkWell(
                onTap: actionable ? onOpen : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, color: accent, size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Semantics(
                            label: context.vio.t('關閉通知'),
                            button: true,
                            child: IconButton(
                              onPressed: onDismiss,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white54,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NotificationPortrait(item: item),
                          const SizedBox(width: 12),
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
                                    fontSize: 14,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
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
                        ],
                      ),
                      if (actionable) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onOpen,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE0CDFF),
                              backgroundColor: const Color(0xFF39284D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              stream != null
                                  ? Icons.play_arrow_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: Text(
                              context.vio.t(stream != null ? '觀看直播' : '開啟'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _NotificationHistoryRow extends StatelessWidget {
  final TwitchAppNotification item;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  const _NotificationHistoryRow({
    required this.item,
    required this.onDismiss,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final stream = item.liveStream;
    final detail = stream == null
        ? item.message.trim()
        : [
            stream.gameName.trim(),
            stream.title.trim(),
          ].where((text) => text.isNotEmpty).join(' · ');
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(item.createdAt),
      alwaysUse24HourFormat: true,
    );
    final actionable = item.whisperTarget != null || item.onOpen != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actionable ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _NotificationPortrait(item: item, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(width: 4),
              Semantics(
                label: context.vio.t('關閉通知'),
                button: true,
                child: IconButton(
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPortrait extends StatelessWidget {
  final TwitchAppNotification item;
  final double size;
  const _NotificationPortrait({required this.item, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final avatars = item.avatarUrls;
    if (avatars.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            for (var index = avatars.length - 1; index >= 0; index--)
              Positioned(
                left: avatars.length == 1 ? 0 : index * size * 5 / 48,
                top: avatars.length == 1 ? 0 : index * size * 4 / 48,
                child: TwitchCachedImageLayer.avatar(
                  imageUrl: avatars[index],
                  size: avatars.length == 1 ? size - 2 : size * 34 / 48,
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
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 14 / 48),
        border: Border.all(color: item.accentColor.withValues(alpha: 0.18)),
        color: item.accentColor.withValues(alpha: 0.09),
      ),
      child: Icon(item.icon, size: size / 2, color: item.accentColor),
    );
  }
}
