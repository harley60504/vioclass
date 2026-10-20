// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_font_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const family = 'FixtureUnavailableFont';
  const missingPath = 'docs/fixture-unavailable-font-1296168.ttf';
  for (final restoring in [false, true]) {
    test('Missing custom font does not become selected restoring=$restoring', () async {
      SharedPreferences.setMockInitialValues({
        'twitch_app_font_selected_v1': restoring ? 'custom:$family' : 'system',
        'twitch_app_font_custom_families_v1': [family],
        'twitch_app_font_custom_labels_v1': ['Fixture unavailable font'],
        'twitch_app_font_custom_paths_v1': [missingPath],
      });
      final controller = TwitchAppFontController();
      addTearDown(controller.dispose);
      await controller.load();
      if (restoring) {
        expect(controller.selectedChoice.kind, TwitchAppFontKind.vioClass);
        expect(controller.fontFamily, TwitchAppFontController.vioClass.family);
      } else {
        final custom = controller.choices.singleWhere((choice) => choice.family == family);
        await expectLater(controller.select(custom), throwsStateError);
        expect(controller.selectedChoice.kind, TwitchAppFontKind.system);
        expect(controller.fontFamily, isNull);
        expect((await SharedPreferences.getInstance()).getString('twitch_app_font_selected_v1'), 'system');
      }
      expect(controller.loaded, true);
      expect(controller.picking, false);
    });
  }
}
