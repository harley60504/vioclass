// PATCH VERSION: twitch_fullscreen_controller_stage231_window_manager_api
// Fullscreen and chat visibility are independent.
// Desktop uses package:window_manager directly so Windows/macOS/Linux enter real
// OS fullscreen. Android/iOS use Flutter immersive SystemChrome mode only.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class TwitchFullscreenController {
  const TwitchFullscreenController._();

  static bool _desktopInitialized = false;

  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<void> setFullscreen(bool enabled) async {
    if (isDesktopPlatform) {
      await _setDesktopFullscreen(enabled);
      return;
    }

    await _setMobileFullscreen(enabled);
  }

  static Future<void> exitFullscreen() => setFullscreen(false);

  static Future<void> _setDesktopFullscreen(bool enabled) async {
    await _ensureDesktopInitialized();

    final alreadyFullscreen = await windowManager.isFullScreen();
    if (alreadyFullscreen == enabled) return;

    await windowManager.setFullScreen(enabled);
    if (enabled) {
      await windowManager.focus();
    }
  }

  static Future<void> _ensureDesktopInitialized() async {
    if (_desktopInitialized) return;
    await windowManager.ensureInitialized();
    _desktopInitialized = true;
  }

  static Future<void> _setMobileFullscreen(bool enabled) {
    return SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}
