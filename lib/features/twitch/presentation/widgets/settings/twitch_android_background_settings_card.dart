import 'package:flutter/material.dart';
import '../../localization/vioclass_localizations.dart';
import '../../../services/notifications/twitch_android_background_controller.dart';
import '../../../services/notifications/twitch_android_live_notification_controller.dart';

class TwitchAndroidBackgroundSettingsCard extends StatefulWidget {
  final TwitchAndroidBackgroundController? controller;
  const TwitchAndroidBackgroundSettingsCard({super.key, this.controller});

  @override
  State<TwitchAndroidBackgroundSettingsCard> createState() =>
      _TwitchAndroidBackgroundSettingsCardState();
}

class _TwitchAndroidBackgroundSettingsCardState
    extends State<TwitchAndroidBackgroundSettingsCard>
    with WidgetsBindingObserver {
  TwitchAndroidBackgroundController get controller =>
      widget.controller ?? TwitchAndroidBackgroundController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.refreshNotificationPermission();
      if (mounted) TwitchAndroidLiveNotificationController.instance.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshNotificationPermission();
    }
  }

  Future<void> _openSettings() async {
    final opened = await controller.openNotificationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟系統設定，請手動前往 VioClass 的通知設定。')),
      );
    }
  }

  Future<void> _setEnabled(bool value) async {
    await controller.setEnabled(value);
    if (!mounted || !value || controller.notificationsAllowed != false) return;
    await _showPermissionDialog();
  }

  Future<void> _openReceivingSettings() async {
    final opened = await controller.openReceivingNotificationSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟通知分類，請在系統通知設定中調整「悄悄話背景收件」。')),
      );
    }
  }

  Future<void> _setLiveEnabled(bool value) async {
    await TwitchAndroidLiveNotificationController.instance.setEnabled(value);
    await controller.refreshNotificationPermission();
    if (!mounted || !value || controller.notificationsAllowed != false) return;
    await _showPermissionDialog();
  }

  Future<void> _showPermissionDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('允許 VioClass 通知'),
        content: const Text('系統目前封鎖通知，無法顯示悄悄話與開台提醒。請在系統設定中開啟通知，再啟用所需的通知功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍後'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('前往設定'),
          ),
        ],
      ),
    );
    if (open == true && mounted) await _openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final live = TwitchAndroidLiveNotificationController.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, live]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              title: const Text('開台通知'),
              subtitle: const Text('追隨的頻道開台時通知你'),
              value: live.enabled,
              onChanged: live.busy ? null : _setLiveEnabled,
            ),
          ),
          if (live.errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                live.errorText!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              title: Text(context.vio.t('背景悄悄話')),
              subtitle: Text(context.vio.t('關閉 App 後仍接收悄悄話')),
              value: controller.enabled,
              onChanged: controller.busy ? null : _setEnabled,
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.busy ? null : _openReceivingSettings,
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('隱藏背景服務通知'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.busy ? null : _openSettings,
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('系統通知設定'),
            ),
          ),
          if (controller.notificationsAllowed == false)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('通知權限未開啟'),
            ),
        ],
      ),
    );
  }
}
