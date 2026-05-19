// Stage 226G: Android Picture-in-Picture bridge for the media_kit Watch player.
//
// Android PiP captures the current Activity surface. Before entering PiP we ask
// Flutter to render only the player surface for a short moment, then native
// enters PiP. The prepare state has a safety timeout so chat/layout cannot stay
// hidden if Android refuses or misses PiP.

import 'dart:async';
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
  static const Duration _prepareFrameDelay = Duration(milliseconds: 60);
  static const Duration _prepareSafetyTimeout = Duration(milliseconds: 1600);

  bool _isInPictureInPictureMode = false;
  bool _isPreparingAutoPictureInPicture = false;
  bool _lastKnownAvailable = Platform.isAndroid;
  Timer? _prepareTimeout;

  bool get isAndroid => Platform.isAndroid;
  bool get isInPictureInPictureMode => _isInPictureInPictureMode;
  bool get isPreparingAutoPictureInPicture => _isPreparingAutoPictureInPicture;
  bool get shouldRenderPlayerOnly =>
      _isInPictureInPictureMode || _isPreparingAutoPictureInPicture;
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
      await preparePlayerOnlyForPictureInPicture();
      final entered = await _channel.invokeMethod<bool>(
        'enterPip',
        <String, Object>{
          'aspectRatioWidth': aspectRatioWidth,
          'aspectRatioHeight': aspectRatioHeight,
        },
      );
      if (entered != true) {
        _setPreparingAutoPictureInPicture(false);
      }
      return entered ?? false;
    } catch (_) {
      _setPreparingAutoPictureInPicture(false);
      return false;
    }
  }

  Future<void> preparePlayerOnlyForPictureInPicture() async {
    _setPreparingAutoPictureInPicture(true);
    await Future<void>.delayed(_prepareFrameDelay);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onAutoPipRequested':
        await preparePlayerOnlyForPictureInPicture();
        return true;
      case 'onPipModeChanged':
        final args = call.arguments;
        final enabled = args is Map ? args['isInPip'] == true : false;
        _setPictureInPictureMode(enabled);
        if (!enabled) {
          _setPreparingAutoPictureInPicture(false);
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

  void _setPreparingAutoPictureInPicture(bool value) {
    if (_isPreparingAutoPictureInPicture == value) {
      if (value) _schedulePrepareTimeout();
      return;
    }
    _isPreparingAutoPictureInPicture = value;
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
        _setPreparingAutoPictureInPicture(false);
      }
    });
  }
}
