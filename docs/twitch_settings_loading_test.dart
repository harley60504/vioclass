// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_language_controller.dart';
import '../lib/features/twitch/presentation/settings/twitch_chat_appearance_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Language selected during load wins over stored language', () async {
    SharedPreferences.setMockInitialValues({'twitch_app_language_selected_v1': 'zhTw'});
    final controller = TwitchAppLanguageController();
    addTearDown(controller.dispose);
    final loading = controller.load();
    final selection = controller.select(TwitchAppLanguageMode.en);
    await Future.wait([loading, selection]);
    expect(controller.mode, TwitchAppLanguageMode.en);
    final reload = TwitchAppLanguageController();
    addTearDown(reload.dispose);
    await reload.load();
    expect(reload.mode, TwitchAppLanguageMode.en);
  });
  test('Chat font size selected during load wins over stored size', () async {
    SharedPreferences.setMockInitialValues({'twitch_chat_font_scale_v1': 1.0});
    final controller = TwitchChatAppearanceController();
    addTearDown(controller.dispose);
    final loading = controller.load();
    final selection = controller.setFontScale(1.3);
    await Future.wait([loading, selection]);
    expect(controller.fontScale, 1.3);
    final reload = TwitchChatAppearanceController();
    addTearDown(reload.dispose);
    await reload.load();
    expect(reload.fontScale, 1.3);
  });
}
