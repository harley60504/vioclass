// Stage 226: Android Picture-in-Picture bridge for the media_kit Watch player.
//
// This file intentionally stays platform-facing and UI-free. Widgets should call
// TwitchAndroidPipController.instance.enterPictureInPicture() and listen to this
// ChangeNotifier to hide non-video chrome while Android is in PiP mode.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TwitchAndroidPipController extends ChangeNotifier {
  TwitchAndroidPipController._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final TwitchAndroidPipController instance = TwitchAndroidPipController._();

  static const MethodChannel _channel = MethodChannel('vio_class/android_pip');

  bool _isInPictureInPictureMode = false;
  bool _lastKnownAvailable = Platform.isAndroid;

  bool get isAndroid => Platform.isAndroid;
  bool get isInPictureInPictureMode => _isInPictureInPictureMode;
  bool get lastKnownAvailable => _lastKnownAvailable;

  Future<bool> isPictureInPictureAvailable() async {
    if (!Platform.isAndroid) {
      _lastKnownAvailable = false;
      return false;
    }

    try {
      final available = await _channel.invokeMethod<bool>('isPipAvailable');
      _lastKnownAvailable = available ?? false;
      return _lastKnownAvailable;
    } catch (_) {
      _lastKnownAvailable = false;
      return false;
    }
  }

  Future<bool> enterPictureInPicture({
    int aspectRatioWidth = 16,
    int aspectRatioHeight = 9,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final entered = await _channel.invokeMethod<bool>(
        'enterPip',
        <String, Object>{
          'aspectRatioWidth': aspectRatioWidth,
          'aspectRatioHeight': aspectRatioHeight,
        },
      );
      return entered ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        final args = call.arguments;
        final enabled = args is Map ? args['isInPip'] == true : false;
        _setPictureInPictureMode(enabled);
        break;
    }
  }

  void _setPictureInPictureMode(bool value) {
    if (_isInPictureInPictureMode == value) return;
    _isInPictureInPictureMode = value;
    notifyListeners();
  }
}
