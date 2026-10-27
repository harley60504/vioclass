// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_video_enhancement.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Chroma enhancement keeps decoded color on Windows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    MediaKit.ensureInitialized();
    final player = await Player.create(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.debug,
        options: {'aid': 'no'},
      ),
    );
    final errors = <String>[];
    final logs = player.stream.log.listen((event) {
      if (event.prefix.contains('render') &&
          RegExp(
            r'ERROR:|syntax error|not compiled|log \(status=0\)',
          ).hasMatch(event.text)) {
        errors.add('${event.prefix}: ${event.text}');
      }
    });
    final controller = await VideoController.create(player);
    final boundary = GlobalKey();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 360,
                child: RepaintBoundary(
                  key: boundary,
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await player.setVolume(0);
      player.setProperty('loop-file', 'inf');
      await player.open(
        Media(File('docs/twitch-decoder-fixture.mp4').absolute.uri.toString()),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (player.state.position.inMilliseconds < 500 &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(player.state.position.inMilliseconds, greaterThanOrEqualTo(500));
      await player.pause();
      List<int>? baseline;
      for (final enabled in [false, true, false]) {
        await TwitchVideoEnhancementRuntime.applyToPlayer(
          player,
          config: TwitchVideoEnhancementConfig(
            enabled: true,
            mode: TwitchVideoEnhancementMode.ewaLanczosSharp,
            chromaEnhance: enabled,
            deband: false,
            sharpen: false,
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var green = 0;
        var nonBlack = 0;
        var difference = 0;
        for (var i = 0; i < rgba.lengthInBytes; i += 4) {
          final r = rgba.getUint8(i),
              g = rgba.getUint8(i + 1),
              b = rgba.getUint8(i + 2);
          if (g > 70 && g > r * 1.5 && g > b * 1.5) green++;
          if (r > 16 || g > 16 || b > 16) nonBlack++;
          if (baseline != null) {
            difference +=
                (r - baseline[i]).abs() +
                (g - baseline[i + 1]).abs() +
                (b - baseline[i + 2]).abs();
          }
        }
        baseline ??= rgba.buffer.asUint8List().toList();
        final meanDifference = difference / (image.width * image.height * 3);
        expect(nonBlack / (image.width * image.height), greaterThan(.25));
        expect(
          meanDifference,
          lessThan(25),
          reason: 'Chroma must preserve the original frame colors',
        );
        final fraction = green / (image.width * image.height);
        debugPrint(
          '[ChromaTest] enabled=$enabled greenFraction=$fraction meanDifference=$meanDifference',
        );
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          'docs/chroma-${enabled ? 'on' : 'off'}.png',
        ).writeAsBytes(png.buffer.asUint8List());
        image.dispose();
        debugPrint('[ChromaTest] logs=${errors.join('\n')}');
        expect(
          errors,
          isEmpty,
          reason: 'Every Chroma shader pass must compile',
        );
        errors.clear();
        expect(
          fraction,
          lessThan(.7),
          reason: 'Shader must not turn the video green',
        );
      }
    } finally {
      await logs.cancel();
      await tester.pumpWidget(const SizedBox());
      await player.dispose();
    }
  });
}
