import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_video_enhancement.dart';

class _Player implements Player {
  final properties = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #setProperty) {
      properties[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test(
    'Windows Chroma uses the native scaler and clears it when switched off',
    () async {
      if (!Platform.isWindows) return;
      final player = _Player();
      for (final enabled in [true, false]) {
        await TwitchVideoEnhancementRuntime.applyToPlayer(
          player,
          config: TwitchVideoEnhancementConfig(
            enabled: true,
            mode: TwitchVideoEnhancementMode.ewaLanczosSharp,
            chromaEnhance: enabled,
            deband: true,
            sharpen: false,
          ),
        );
        expect(
          player.properties['cscale'],
          enabled ? 'ewa_lanczossharp' : 'bilinear',
        );
        expect(player.properties['glsl-shaders'], '');
        expect(player.properties['scale'], 'ewa_lanczossharp');
        expect(player.properties['deband'], 'yes');
        expect(player.properties.containsKey('hwdec'), isFalse);
      }
    },
  );
}
