import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../localization/vioclass_localizations.dart';

enum TwitchNoticeTone { info, success, warning, error }

OverlayEntry? _activeNoticeEntry;
Timer? _activeNoticeTimer;

void showTwitchNotice(
  BuildContext context,
  String message, {
  TwitchNoticeTone? tone,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final text = context.vio.t(message).trim();
  if (text.isEmpty) return;
  final resolvedTone = tone ?? _inferNoticeTone(text);
  final colors = _NoticeColors.forTone(resolvedTone);

  _activeNoticeTimer?.cancel();
  if (_activeNoticeEntry?.mounted ?? false) {
    _activeNoticeEntry?.remove();
  }
  _activeNoticeEntry = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final availableWidth = MediaQuery.sizeOf(overlayContext).width;
      final noticeWidth = math.min(
        520.0,
        math.max(220.0, availableWidth - 24.0),
      );
      return Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, progress, child) => Opacity(
                  opacity: progress,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - progress)),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  width: noticeWidth,
                  child: Material(
                    color: const Color(0xFF211A2D),
                    elevation: 18,
                    shadowColor: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Semantics(
                        liveRegion: true,
                        label: text,
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                colors.icon,
                                size: 17,
                                color: colors.foreground,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  color: Color(0xFFF5F1FA),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
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
          ),
        ),
      );
    },
  );
  _activeNoticeEntry = entry;
  overlay.insert(entry);
  _activeNoticeTimer = Timer(duration, () {
    if (!identical(_activeNoticeEntry, entry)) return;
    if (entry.mounted) entry.remove();
    _activeNoticeEntry = null;
    _activeNoticeTimer = null;
  });
}

TwitchNoticeTone _inferNoticeTone(String message) {
  if (_containsAny(message, const <String>[
    '已複製',
    '已分享',
    '已兌換',
    '已追隨',
    '已取消追隨',
    '已套用',
  ])) {
    return TwitchNoticeTone.success;
  }
  if (_containsAny(message, const <String>['失敗', '錯誤', '無法', '未送出', '拒絕'])) {
    return TwitchNoticeTone.error;
  }
  if (_containsAny(message, const <String>[
    '目前',
    '找不到',
    '尚未',
    '不支援',
    '請先',
    '稍後',
    '至少',
  ])) {
    return TwitchNoticeTone.warning;
  }
  return TwitchNoticeTone.info;
}

bool _containsAny(String message, List<String> needles) {
  return needles.any(message.contains);
}

class _NoticeColors {
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const _NoticeColors({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  factory _NoticeColors.forTone(TwitchNoticeTone tone) {
    return switch (tone) {
      TwitchNoticeTone.info => const _NoticeColors(
        foreground: Color(0xFFD8B4FE),
        background: Color(0xFF3A2454),
        border: Color(0x665C3A78),
        icon: Icons.info_outline_rounded,
      ),
      TwitchNoticeTone.success => const _NoticeColors(
        foreground: Color(0xFF86EFAC),
        background: Color(0xFF193D30),
        border: Color(0x6648A879),
        icon: Icons.check_rounded,
      ),
      TwitchNoticeTone.warning => const _NoticeColors(
        foreground: Color(0xFFFCD34D),
        background: Color(0xFF493718),
        border: Color(0x668E6E29),
        icon: Icons.priority_high_rounded,
      ),
      TwitchNoticeTone.error => const _NoticeColors(
        foreground: Color(0xFFFDA4AF),
        background: Color(0xFF4A202C),
        border: Color(0x669B465B),
        icon: Icons.close_rounded,
      ),
    };
  }
}
