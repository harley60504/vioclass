import 'package:flutter/material.dart';
import '../../../services/notifications/twitch_android_background_controller.dart';

class TwitchAndroidBackgroundSettingsCard extends StatelessWidget {
  const TwitchAndroidBackgroundSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TwitchAndroidBackgroundController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              title: const Text('背景收件'),
              subtitle: const Text(
                '離開 App 或鎖屏時維持私訊與開台通知。開啟後會顯示常駐系統通知並增加耗電；關閉 App 工作或強制停止後不會自動重啟。',
              ),
              value: controller.enabled,
              onChanged: controller.busy ? null : controller.setEnabled,
            ),
          ),
          if (controller.errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                controller.errorText!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
        ],
      ),
    );
  }
}
