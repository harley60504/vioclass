// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_player_settings_controller.dart';
import '../lib/features/twitch/presentation/watch/controllers/twitch_watch_preferences_controller.dart';

const volumeKey = TwitchWatchPreferencesController.playerVolumePreferenceKey;
const mutedKey = TwitchWatchPreferencesController.playerMutedPreferenceKey;

class _Store extends InMemorySharedPreferencesStore {
  _Store(this.failKey, this.throws)
    : super.withData({'flutter.$volumeKey': 40.0, 'flutter.$mutedKey': false});
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
  test('Queued volume and mute changes preserve request order', () async {
    SharedPreferences.setMockInitialValues({volumeKey: 40.0, mutedKey: false});
    final controller = TwitchPlayerSettingsController();
    addTearDown(controller.dispose);
    await controller.load();
    await Future.wait([
      controller.setVolume(65),
      controller.setVolume(0),
      controller.setMuted(false),
    ]);
    expect(controller.volume, 0);
    expect(controller.muted, false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getDouble(volumeKey), 0);
    expect(prefs.getBool(mutedKey), false);
  });
  for (final scenario in ['volume', 'mute', 'zero-volume-second-write']) {
    for (final throws in [false, true]) {
      test(
        '$scenario failure preserves state and retries throws=$throws',
        () async {
          SharedPreferences.setMockInitialValues({
            volumeKey: 40.0,
            mutedKey: false,
          });
          final previous = SharedPreferencesStorePlatform.instance;
          SharedPreferencesStorePlatform.instance = _Store(
            scenario == 'volume' ? volumeKey : mutedKey,
            throws,
          );
          addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
          final controller = TwitchPlayerSettingsController();
          addTearDown(controller.dispose);
          await controller.load();
          Future<void> change() => scenario == 'mute'
              ? controller.setMuted(true)
              : controller.setVolume(scenario == 'volume' ? 65 : 0);
          await expectLater(change(), throwsA(isA<StateError>()));
          expect(controller.volume, 40);
          expect(controller.muted, false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
          expect(prefs.getDouble(volumeKey), 40);
          expect(prefs.getBool(mutedKey), false);
          await change();
          await prefs.reload();
          final restored = TwitchPlayerSettingsController();
          addTearDown(restored.dispose);
          await restored.load();
          expect(
            restored.volume,
            scenario == 'mute'
                ? 40
                : scenario == 'volume'
                ? 65
                : 0,
          );
          expect(restored.muted, scenario != 'volume');
        },
      );
    }
  }
}
