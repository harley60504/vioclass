import 'package:flutter/material.dart';

class TwitchChatEmptyView extends StatelessWidget {
  const TwitchChatEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '按 Connect 連線聊天室。這頁獨立測完整聊天室：recent messages、IRC live、發送訊息與穩定滾輪。',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
