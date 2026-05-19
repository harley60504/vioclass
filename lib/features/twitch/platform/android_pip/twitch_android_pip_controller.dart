// Stage 226D: Android Picture-in-Picture bridge for the media_kit Watch player.
//
// The Android PiP API is Activity-level, but the Watch player area can still
// provide a source-rect hint so Android animates PiP from the actual video area
// instead of from the whole WatchPage.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

  Future<void> setSourceRectHint(Rect rect) async {
    if (!Platform.isAndroid) return;
    if (rect.isEmpty || !rect.isFinite) return;

    try {
      await _channel.invokeMethod<void>(
        'setSourceRectHint',
        <String, Object>{
          'left': rect.left.round(),
          'top': rect.top.round(),
          'right': rect.right.round(),
          'bottom': rect.bottom.round(),
        },
      );
    } catch (_) {}
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
