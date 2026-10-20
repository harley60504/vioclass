// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/services/playback/twitch_video_enhancement.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_preferences_controller.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store(this.failKey, this.throws, Map<String, Object> data)
    : super.withData(data);
  final String failKey;
  final bool throws;
  bool failed = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$failKey' && !failed) {
      failed = true;
      if (throws) throw StateError('fixture save failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'enabled',
    'mode',
    'chroma',
    'deband',
    'sharpen',
    'reset-volume',
    'reset-enhancement',
  ]) {
    for (final throws in [false, true]) {
      test(
        '$scenario failure restores preferences and retries throws=$throws',
        () async {
          const volumeKey =
              TwitchWatchPreferencesController.playerVolumePreferenceKey;
          SharedPreferences.setMockInitialValues({volumeKey: 40.0});
          final resetting = scenario.startsWith('reset');
          final initialMode = resetting
              ? TwitchVideoEnhancementMode.lanczos
              : TwitchVideoEnhancementMode.ewaLanczosSharp;
          await TwitchVideoEnhancementRuntime.saveAndApply(
            player: null,
            enabled: resetting,
            mode: initialMode,
            chromaEnhance: resetting,
            deband: resetting,
            sharpen: resetting,
          );
          final prefs = await SharedPreferences.getInstance();
          final seed = {
            for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
          };
          final key = switch (scenario) {
            'enabled' => TwitchVideoEnhancementRuntime.enabledPreferenceKey,
            'mode' => TwitchVideoEnhancementRuntime.modePreferenceKey,
            'chroma' =>
              TwitchVideoEnhancementRuntime.chromaEnhancePreferenceKey,
            'deband' => TwitchVideoEnhancementRuntime.debandPreferenceKey,
            'sharpen' || 'reset-enhancement' =>
              TwitchVideoEnhancementRuntime.sharpenPreferenceKey,
            _ => volumeKey,
          };
          final previous = SharedPreferencesStorePlatform.instance;
          SharedPreferencesStorePlatform.instance = _Store(key, throws, seed);
          addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
          final controller = TwitchPlayerSettingsController();
          addTearDown(controller.dispose);
          await controller.load();
          Future<void> change() => switch (scenario) {
            'enabled' => controller.setVideoEnhancementEnabled(true),
            'mode' => controller.setVideoEnhancementMode(
              TwitchVideoEnhancementMode.lanczos,
            ),
            'chroma' => controller.setVideoChromaEnhance(true),
            'deband' => controller.setVideoDeband(true),
            'sharpen' => controller.setVideoSharpen(true),
            _ => controller.resetPlayback(),
          };
          await expectLater(change(), throwsA(isA<StateError>()));
          expect(controller.volume, 40);
          expect(controller.videoEnhancementEnabled, resetting);
          expect(controller.videoEnhancementMode, initialMode);
          expect(controller.videoChromaEnhance, resetting);
          expect(controller.videoDeband, resetting);
          expect(controller.videoSharpen, resetting);
          expect(controller.videoEnhancementBusy, false);
          expect(TwitchVideoEnhancementRuntime.config.enabled, resetting);
          expect(TwitchVideoEnhancementRuntime.config.mode, initialMode);
          await prefs.reload();
          expect({
            for (final k in prefs.getKeys()) 'flutter.$k': prefs.get(k)!,
          }, seed);
          await change();
          expect(controller.videoEnhancementBusy, false);
          await prefs.reload();
          final reload = TwitchPlayerSettingsController();
          addTearDown(reload.dispose);
          await reload.load();
          expect(reload.volume, scenario.startsWith('reset') ? 100 : 40);
          expect(reload.videoEnhancementEnabled, scenario == 'enabled');
          expect(
            reload.videoEnhancementMode,
            scenario == 'mode'
                ? TwitchVideoEnhancementMode.lanczos
                : TwitchVideoEnhancementMode.ewaLanczosSharp,
          );
          expect(reload.videoChromaEnhance, scenario == 'chroma');
          expect(reload.videoDeband, scenario == 'deband');
          expect(reload.videoSharpen, scenario == 'sharpen');
        },
      );
    }
  }
}
