// PATCH VERSION: twitch_fullscreen_controller_desktop_method_channel_v49
// Place at: lib/features/twitch/services/window/twitch_fullscreen_controller.dart
// Fullscreen and chat visibility are independent.
// Desktop uses the same window_manager MethodChannel contract as the plugin,
// without importing package:window_manager in shared/mobile code.
// Android/iOS use Flutter immersive SystemChrome mode only.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TwitchFullscreenController {
  const TwitchFullscreenController._();

  static const MethodChannel _windowManagerChannel = MethodChannel(
    'window_manager',
  );

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
      final handled = await _tryDesktopWindowFullscreen(enabled);
      if (handled) return;
    }

    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  static Future<void> exitFullscreen() => setFullscreen(false);

  static Future<bool> _tryDesktopWindowFullscreen(bool enabled) async {
    try {
      if (!_desktopInitialized) {
        await _windowManagerChannel.invokeMethod<void>('ensureInitialized');
        _desktopInitialized = true;
      }

      // Important: this must match package:window_manager's argument shape:
      // {'isFullScreen': bool}. Passing a raw bool can crash/fail on Windows.
      await _windowManagerChannel.invokeMethod<void>(
        'setFullScreen',
        <String, Object?>{
          'isFullScreen': enabled,
        },
      );
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Desktop fullscreen fallback: $error');
      }
      return false;
    }
  }
}
