import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter-side controller for Android Picture-in-Picture.
///
/// Responsibilities kept here:
/// - call the Android MethodChannel bridge;
/// - expose whether Android is currently in PiP;
/// - briefly ask the Flutter Watch layout to render only the player surface
///   before a manual PiP request;
/// - recover automatically if Android refuses to enter PiP.
class TwitchAndroidPipController extends ChangeNotifier {
  TwitchAndroidPipController._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final TwitchAndroidPipController instance = TwitchAndroidPipController._();

  static const MethodChannel _channel = MethodChannel('vio_class/android_pip');
  static const Duration _manualPrepareFrameDelay = Duration(milliseconds: 60);
  static const Duration _prepareSafetyTimeout = Duration(milliseconds: 1600);

  bool _isInPictureInPictureMode = false;
  bool _isPreparingPictureInPicture = false;
  bool _lastKnownAvailable = Platform.isAndroid;
  Timer? _prepareTimeout;

  bool get isAndroid => Platform.isAndroid;
  bool get isInPictureInPictureMode => _isInPictureInPictureMode;
  bool get isPreparingPictureInPicture => _isPreparingPictureInPicture;
  bool get shouldRenderPlayerOnly =>
      _isInPictureInPictureMode || _isPreparingPictureInPicture;
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
      await _prepareManualPictureInPictureFrame();
      final entered = await _channel.invokeMethod<bool>(
        'enterPip',
        <String, Object>{
          'aspectRatioWidth': aspectRatioWidth,
          'aspectRatioHeight': aspectRatioHeight,
        },
      );
      if (entered != true) {
        _setPreparingPictureInPicture(false);
      }
      return entered ?? false;
    } catch (_) {
      _setPreparingPictureInPicture(false);
      return false;
    }
  }

  Future<void> _prepareManualPictureInPictureFrame() async {
    _setPreparingPictureInPicture(true);
    await Future<void>.delayed(_manualPrepareFrameDelay);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onAutoPipRequested':
        // Auto PiP from onUserLeaveHint must be immediate on Android. We only
        // flip this flag as a best-effort hint; native should not wait for it.
        _setPreparingPictureInPicture(true);
        return true;
      case 'onPipModeChanged':
        final args = call.arguments;
        final enabled = args is Map ? args['isInPip'] == true : false;
        _setPictureInPictureMode(enabled);
        if (!enabled) {
          _setPreparingPictureInPicture(false);
        }
        return null;
    }
  }

  void _setPictureInPictureMode(bool value) {
    if (_isInPictureInPictureMode == value) return;
    _isInPictureInPictureMode = value;
    if (value) {
      _prepareTimeout?.cancel();
      _prepareTimeout = null;
    }
    notifyListeners();
  }

  void _setPreparingPictureInPicture(bool value) {
    if (_isPreparingPictureInPicture == value) {
      if (value) _schedulePrepareTimeout();
      return;
    }

    _isPreparingPictureInPicture = value;
    if (value) {
      _schedulePrepareTimeout();
    } else {
      _prepareTimeout?.cancel();
      _prepareTimeout = null;
    }
    notifyListeners();
  }

  void _schedulePrepareTimeout() {
    _prepareTimeout?.cancel();
    _prepareTimeout = Timer(_prepareSafetyTimeout, () {
      if (!_isInPictureInPictureMode) {
        _setPreparingPictureInPicture(false);
      }
    });
  }
}
