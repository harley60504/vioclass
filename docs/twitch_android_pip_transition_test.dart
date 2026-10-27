import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/platform/android_pip/twitch_android_pip_controller.dart';

Future<void> nativeEvent(String method, [Map<String, Object>? args]) async {
  final done = Completer<void>();
  ServicesBinding.instance.channelBuffers.push(
    'vio_class/android_pip',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
    (_) => done.complete(),
  );
  await done.future;
}

void main() {
  testWidgets(
    'PiP preparation survives an activity stop before mode confirmation',
    (tester) async {
      final pip = TwitchAndroidPipController.instance;
      await nativeEvent('onActivityStarted', {'isInPip': false});
      final backgroundDecisions = <bool>[];
      void observe() =>
          backgroundDecisions.add(pip.stoppedOutsidePictureInPicture);
      pip.addListener(observe);
      try {
        await nativeEvent('onAutoPipRequested');
        await nativeEvent('onActivityStopped', {'isInPip': false});
        expect(pip.isPreparingPictureInPicture, true);
        expect(pip.stoppedOutsidePictureInPicture, false);
        expect(backgroundDecisions, everyElement(false));
        await nativeEvent('onPipModeChanged', {'isInPip': true});
        expect(pip.isInPictureInPictureMode, true);
        expect(pip.isPreparingPictureInPicture, false);
        expect(pip.stoppedOutsidePictureInPicture, false);
      } finally {
        pip.removeListener(observe);
        await nativeEvent('onPipModeChanged', {'isInPip': false});
        await nativeEvent('onActivityStarted', {'isInPip': false});
      }
      // The singleton channel handler belongs to this binding; keep the failure
      // fallback in the same lifecycle scenario instead of resetting the binding.
      await nativeEvent('onActivityStarted', {'isInPip': false});
      await nativeEvent('onAutoPipRequested');
      await nativeEvent('onActivityStopped', {'isInPip': false});
      await tester.pump(const Duration(milliseconds: 1700));
      expect(pip.isPreparingPictureInPicture, false);
      expect(pip.isInPictureInPictureMode, false);
      expect(pip.stoppedOutsidePictureInPicture, true);
      await nativeEvent('onActivityStarted', {'isInPip': false});
    },
  );
}
