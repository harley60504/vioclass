import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../localization/vioclass_localizations.dart';
import '../../settings/twitch_app_settings_launcher.dart';
import '../../../services/notifications/twitch_app_notification_service.dart';

class TwitchAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const TwitchAppNotificationOverlay({super.key, required this.child});

  @override
  State<TwitchAppNotificationOverlay> createState() =>
      _TwitchAppNotificationOverlayState();
}

class _TwitchAppNotificationOverlayState
    extends State<TwitchAppNotificationOverlay>
    with WidgetsBindingObserver, WindowListener {
  static const double _windowsTitleBarHeight = 42;

  bool _isNotificationPanelOpen = false;
  bool _isWindowMaximized = false;
  bool _isWindowFullScreen = false;

  bool get _usesCustomWindowsFrame =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_usesCustomWindowsFrame) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((value) {
        if (mounted) setState(() => _isWindowMaximized = value);
      });
      windowManager.isFullScreen().then((value) {
        if (mounted) setState(() => _isWindowFullScreen = value);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_usesCustomWindowsFrame) windowManager.removeListener(this);
    twitchAppNotificationCenter.resumeAutoDismiss();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      twitchAppNotificationCenter.resumeAutoDismiss();
    } else {
      twitchAppNotificationCenter.pauseAutoDismiss();
    }
  }

  void _openNotificationPanel() {
    setState(() => _isNotificationPanelOpen = true);
    twitchAppNotificationCenter.markAllRead();
  }

  void _closeNotificationPanel() {
    setState(() => _isNotificationPanelOpen = false);
  }

  bool _openingWhisper = false;

  Future<void> _openNotification(TwitchAppNotification item) async {
    final target = item.whisperTarget;
    if (target == null || _openingWhisper) return;
    _openingWhisper = true;
    _closeNotificationPanel();
    twitchAppNotificationCenter.hideToast(item.id);
    try {
      await twitchAppSettingsLauncher.openWhisperConversation(
        ownerId: target.ownerId,
        peerId: target.peerId,
      );
    } on StateError catch (error) {
      twitchAppNotificationCenter.showWarning(
        title: '無法開啟私訊',
        message: error.message.toString(),
      );
    } catch (_) {
      twitchAppNotificationCenter.showWarning(
        title: '無法開啟私訊',
        message: '請開啟私訊列表查看。',
      );
    } finally {
      _openingWhisper = false;
    }
  }

  void _toggleNotificationPanel() {
    if (_isNotificationPanelOpen) {
      _closeNotificationPanel();
    } else {
      _openNotificationPanel();
    }
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isWindowMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isWindowMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isWindowFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isWindowFullScreen = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        twitchAppNotificationCenter,
        twitchAppSettingsLauncher,
      ]),
      builder: (context, _) {
        final center = twitchAppNotificationCenter;
        final toast = center.visibleItems.firstOrNull;
        final screenSize = MediaQuery.sizeOf(context);
        final screenWidth = screenSize.width;
        final hasWindowsFrame = _usesCustomWindowsFrame && !_isWindowFullScreen;
        final panelTop = hasWindowsFrame ? _windowsTitleBarHeight + 8 : 12.0;
        final panelWidth = math.min(400.0, math.max(0.0, screenWidth - 24));
        final panelHeight = math.min(
          480.0,
          math.max(0.0, screenSize.height - panelTop - 12),
        );
        final toastWidth = math.min(390.0, math.max(0.0, screenWidth - 24));
        final content = hasWindowsFrame
            ? Column(
                children: <Widget>[
                  _TwitchWindowsTitleBar(
                    height: _windowsTitleBarHeight,
                    isMaximized: _isWindowMaximized,
                    unreadCount: center.unreadCount,
                    isNotificationPanelOpen: _isNotificationPanelOpen,
                    onToggleNotifications: _toggleNotificationPanel,
                    onOpenSettings: twitchAppSettingsLauncher.open,
                    hasUpdate: twitchAppSettingsLauncher.hasUpdate,
                    onOpenUpdate: twitchAppSettingsLauncher.openUpdate,
                    onMinimize: windowManager.minimize,
                    onToggleMaximize: _toggleMaximize,
                    onClose: windowManager.close,
                  ),
                  Expanded(child: widget.child),
                ],
              )
            : widget.child;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            content,
            if (_isNotificationPanelOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeNotificationPanel,
                  child: const SizedBox.expand(),
                ),
              ),
            if (!_isNotificationPanelOpen && toast != null)
              Positioned(
                top: hasWindowsFrame ? _windowsTitleBarHeight + 8 : 62,
                left: math.max(12, (screenWidth - toastWidth) / 2),
                width: toastWidth,
                child: _TwitchAppNotificationCard(
                  item: toast,
                  onOpen: () => _openNotification(toast),
                  onDismiss: () => center.hideToast(toast.id),
                ),
              ),
            if (!hasWindowsFrame && !_isNotificationPanelOpen)
              Positioned(
                top: 8,
                right: 12,
                child: SafeArea(
                  minimum: EdgeInsets.zero,
                  child: _NotificationIslandButton(
                    unreadCount: center.unreadCount,
                    onPressed: _openNotificationPanel,
                  ),
                ),
              ),
            if (_isNotificationPanelOpen)
              Positioned(
                top: panelTop,
                left: math.max(12, (screenWidth - panelWidth) / 2),
                width: panelWidth,
                height: panelHeight,
                child: _NotificationPanel(
                  items: center.items,
                  onClose: _closeNotificationPanel,
                  onOpen: _openNotification,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TwitchWindowsTitleBar extends StatelessWidget {
  final double height;
  final bool isMaximized;
  final int unreadCount;
  final bool isNotificationPanelOpen;
  final VoidCallback onToggleNotifications;
  final VoidCallback onOpenSettings;
  final bool hasUpdate;
  final VoidCallback onOpenUpdate;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  const _TwitchWindowsTitleBar({
    required this.height,
    required this.isMaximized,
    required this.unreadCount,
    required this.isNotificationPanelOpen,
    required this.onToggleNotifications,
    required this.onOpenSettings,
    required this.hasUpdate,
    required this.onOpenUpdate,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF20B0A0E),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white70,
          decoration: TextDecoration.none,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: onToggleMaximize,
              ),
              if (MediaQuery.sizeOf(context).width >= 520)
                const Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.live_tv_rounded,
                          color: Color(0xFFBF94FF),
                          size: 17,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'VioClass',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: MediaQuery.sizeOf(context).width < 720
                    ? Alignment.centerLeft
                    : Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: MediaQuery.sizeOf(context).width < 520
                        ? 8
                        : MediaQuery.sizeOf(context).width < 720
                        ? 135
                        : 0,
                  ),
                  child: _NotificationIslandButton(
                    unreadCount: unreadCount,
                    selected: isNotificationPanelOpen,
                    onPressed: onToggleNotifications,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  children: <Widget>[
                    if (hasUpdate && MediaQuery.sizeOf(context).width < 720)
                      Semantics(
                        label: context.vio.t('有更新'),
                        child: _WindowFrameButton(
                          icon: Icons.system_update_alt_rounded,
                          onPressed: onOpenUpdate,
                        ),
                      ),
                    if (hasUpdate && MediaQuery.sizeOf(context).width >= 720)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton.icon(
                          onPressed: onOpenUpdate,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7BE8B4),
                            backgroundColor: const Color(0x247BE8B4),
                            minimumSize: const Size(0, 28),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(
                            Icons.system_update_alt_rounded,
                            size: 15,
                          ),
                          label: Text(context.vio.t('有更新')),
                        ),
                      ),
                    Semantics(
                      label: context.vio.t('Twitch 私訊'),
                      child: _WindowFrameButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        badgeCount:
                            twitchAppSettingsLauncher.whisperUnreadCount,
                        iconSize: 16,
                        onPressed: twitchAppSettingsLauncher.openWhispers,
                      ),
                    ),
                    _WindowFrameButton(
                      icon: Icons.settings_rounded,
                      iconSize: 16,
                      onPressed: onOpenSettings,
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    _WindowFrameButton(
                      icon: Icons.remove_rounded,
                      onPressed: onMinimize,
                    ),
                    _WindowFrameButton(
                      icon: isMaximized
                          ? Icons.filter_none_rounded
                          : Icons.crop_square_rounded,
                      iconSize: isMaximized ? 14 : 15,
                      onPressed: onToggleMaximize,
                    ),
                    _WindowFrameButton(
                      icon: Icons.close_rounded,
                      isClose: true,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowFrameButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final bool isClose;
  final int badgeCount;
  final VoidCallback onPressed;

  const _WindowFrameButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 17,
    this.isClose = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose
            ? const Color(0xFFE81123)
            : Colors.white.withValues(alpha: 0.09),
        child: SizedBox(
          width: 46,
          height: double.infinity,
          child: Center(
            child: Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
              child: Icon(icon, size: iconSize, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationIslandButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;
  final bool selected;

  const _NotificationIslandButton({
    required this.unreadCount,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: unreadCount > 0 ? 58 : 42,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF241A31) : const Color(0xDD15131A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? const Color(0xFFBF94FF).withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFFBF94FF),
                size: 17,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D73),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
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

class _NotificationPanel extends StatelessWidget {
  final List<TwitchAppNotification> items;
  final VoidCallback onClose;
  final ValueChanged<TwitchAppNotification> onOpen;

  const _NotificationPanel({
    required this.items,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: const Color(0xC7100C16),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 62,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFFBF94FF),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.vio.t('通知中心'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (items.isNotEmpty)
                          TextButton(
                            onPressed: twitchAppNotificationCenter.clear,
                            child: Text(context.vio.t('全部清除')),
                          ),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.09)),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.notifications_none_rounded,
                                color: Colors.white.withValues(alpha: 0.24),
                                size: 42,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                context.vio.t('目前沒有通知'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _TwitchAppNotificationCard(
                              key: ValueKey<int>(item.id),
                              item: item,
                              onOpen: () => onOpen(item),
                              onDismiss: () =>
                                  twitchAppNotificationCenter.dismiss(item.id),
                            );
                          },
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

class _TwitchAppNotificationCard extends StatelessWidget {
  final TwitchAppNotification item;
  final VoidCallback onDismiss;
  final VoidCallback? onOpen;

  const _TwitchAppNotificationCard({
    super.key,
    required this.item,
    required this.onDismiss,
    this.onOpen,
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
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 78),
          decoration: BoxDecoration(
            color: const Color(0xC216111F),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent.withValues(alpha: 0.34)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 5, color: accent),
                ),
                InkWell(
                  onTap: item.whisperTarget == null ? null : onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Icon(item.icon, color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatTimeOfDay(
                                      TimeOfDay.fromDateTime(item.createdAt),
                                      alwaysUse24HourFormat: true,
                                    ),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.message.trim().isNotEmpty) ...<Widget>[
                                const SizedBox(height: 5),
                                Text(
                                  item.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.70),
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
                        Semantics(
                          button: true,
                          label: context.vio.t('關閉通知'),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onDismiss,
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withValues(alpha: 0.58),
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
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
