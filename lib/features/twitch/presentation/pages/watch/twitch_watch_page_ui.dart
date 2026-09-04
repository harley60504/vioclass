import 'package:flutter/material.dart';

import '../../../services/window/twitch_fullscreen_controller.dart';
import '../../localization/vioclass_localizations.dart';
import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPageUiMethods on TwitchWatchPageState {
  Future<void> enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;
    try {
      await TwitchFullscreenController.setFullscreen(true);
      mobileImmersiveEntered = true;
    } catch (_) {}
  }

  Future<void> toggleFullscreenMode() async {
    final next = !fullscreenMode;
    try {
      await TwitchFullscreenController.setFullscreen(next);
      if (!mounted) return;
      setState(() => fullscreenMode = next);
    } catch (error) {
      showSnack('切換全螢幕失敗，請稍後再試。');
    }
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.vio.t(message))));
  }
}
