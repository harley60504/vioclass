import 'package:flutter/material.dart';

class TwitchStreamHomeAccountMenu extends StatelessWidget {
  final Future<void> Function() onOpenSettings;

  const TwitchStreamHomeAccountMenu({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '設定',
      onPressed: () => onOpenSettings(),
      icon: const Icon(Icons.settings_rounded, color: Color(0xFFBF94FF)),
    );
  }
}
