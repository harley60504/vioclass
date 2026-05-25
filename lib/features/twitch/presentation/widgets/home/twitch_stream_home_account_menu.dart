import 'package:flutter/material.dart';

class TwitchStreamHomeAccountMenu extends StatelessWidget {
  final Future<void> Function() onLogin;
  final Future<void> Function() onRefresh;
  final VoidCallback onTestAppNotification;
  final Future<void> Function() onLogout;

  const TwitchStreamHomeAccountMenu({
    super.key,
    required this.onLogin,
    required this.onRefresh,
    required this.onTestAppNotification,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '設定',
      color: const Color(0xFF191421),
      icon: const Icon(Icons.settings_rounded, color: Color(0xFFBF94FF)),
      onSelected: (value) async {
        switch (value) {
          case 'login':
            await onLogin();
            break;
          case 'refresh':
            await onRefresh();
            break;
          case 'test_app_notification':
            onTestAppNotification();
            break;
          case 'logout':
            await onLogout();
            break;
        }
      },
      itemBuilder: (context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'login', child: Text('完整登入 / 修復登入')),
        PopupMenuItem<String>(value: 'refresh', child: Text('重新檢查登入狀態')),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'test_app_notification',
          child: Text('測試程式內部通知'),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'logout', child: Text('登出')),
      ],
    );
  }
}
