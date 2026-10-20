// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_font_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_language_controller.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store(this.key, this.throws, this.original)
    : super.withData({'flutter.$key': original});
  final String key;
  final String original;
  final bool throws;
  int attempts = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}') {
      attempts++;
      if (attempts == 1) {
        if (throws) throw StateError('fixture storage error');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final font in [false, true]) {
    for (final throws in [false, true]) {
      test(
        'Selection retains old choice on failure font=$font throws=$throws',
        () async {
          final key = font
              ? 'twitch_app_font_selected_v1'
              : 'twitch_app_language_selected_v1';
          final oldId = font ? 'vioClass' : 'zhTw';
          final newId = font ? 'system' : 'en';
          SharedPreferences.setMockInitialValues({key: oldId});
          final previous = SharedPreferencesStorePlatform.instance;
          final store = _Store(key, throws, oldId);
          SharedPreferencesStorePlatform.instance = store;
          addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
          final fonts = TwitchAppFontController();
          final languages = TwitchAppLanguageController();
          addTearDown(fonts.dispose);
          addTearDown(languages.dispose);
          if (font) {
            await fonts.load();
          } else {
            await languages.load();
          }
          Future<void> select() => font
              ? fonts.select(TwitchAppFontController.system)
              : languages.select(TwitchAppLanguageMode.en);
          String current() => font ? fonts.selectedId : languages.mode.id;
          await expectLater(select(), throwsStateError);
          expect(current(), oldId);
          expect((await SharedPreferences.getInstance()).getString(key), oldId);
          await select();
          expect(store.attempts, 2);
          expect(current(), newId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
          final restoredFonts = TwitchAppFontController();
          final restoredLanguages = TwitchAppLanguageController();
          addTearDown(restoredFonts.dispose);
          addTearDown(restoredLanguages.dispose);
          if (font) {
            await restoredFonts.load();
          } else {
            await restoredLanguages.load();
          }
          expect(
            font ? restoredFonts.selectedId : restoredLanguages.mode.id,
            newId,
          );
        },
      );
    }
  }
}
