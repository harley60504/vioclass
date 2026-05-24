import 'package:flutter/material.dart';

import '../../../services/notifications/twitch_app_notification_service.dart';

class TwitchAppNotificationOverlay extends StatelessWidget {
  final Widget child;

  const TwitchAppNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Positioned(
          top: 18,
          right: 18,
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 6, right: 6),
            child: IgnorePointer(
              ignoring: false,
              child: AnimatedBuilder(
                animation: twitchAppNotificationCenter,
                builder: (context, _) {
                  final items = twitchAppNotificationCenter.items;
                  if (items.isEmpty) return const SizedBox.shrink();

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final item in items)
                          Padding(
                            key: ValueKey<int>(item.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TwitchAppNotificationCard(
                              item: item,
                              onDismiss: () {
                                twitchAppNotificationCenter.dismiss(item.id);
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TwitchAppNotificationCard extends StatelessWidget {
  final TwitchAppNotification item;
  final VoidCallback onDismiss;

  const _TwitchAppNotificationCard({
    required this.item,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.accentColor;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 28, 0),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          constraints: const BoxConstraints(minHeight: 82),
          decoration: BoxDecoration(
            color: const Color(0xF216111F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.34)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(0.38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: accent.withOpacity(0.16),
                blurRadius: 18,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 5,
                    color: accent,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 14, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent.withOpacity(0.32)),
                        ),
                        child: Icon(item.icon, color: accent, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (item.message.trim().isNotEmpty) ...<Widget>[
                              const SizedBox(height: 5),
                              Text(
                                item.message,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.70),
                                  fontSize: 12.5,
                                  height: 1.28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '關閉通知',
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.58),
                          size: 19,
                        ),
                      ),
                    ],
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
