// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member, depend_on_referenced_packages
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../lib/features/twitch/presentation/settings/twitch_app_font_controller.dart';

final class _File extends PlatformFile {
  _File(this.path);
  @override
  final String path;
  @override
  String get name => 'Fixture.ttf';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected file operation');
}

class _Picker with MockPlatformInterfaceMixin implements FilePickerPlatform {
  _Picker(this.file);
  final PlatformFile file;
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #pickFile) {
      calls++;
      return Future<PlatformFile?>.value(file);
    }
    throw StateError('Unexpected picker operation');
  }
}

class _Paths with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getApplicationSupportPath) {
      return Future<String?>.value(path);
    }
    throw StateError('Unexpected directory request');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final removing in [false, true]) {
    for (final key in [
      'twitch_app_font_selected_v1',
      'twitch_app_font_custom_families_v1',
      'twitch_app_font_custom_labels_v1',
      'twitch_app_font_custom_paths_v1',
    ]) {
      for (final throws in [false, true]) {
        test(
          'Font list save failure removing=$removing key=$key throws=$throws',
          () async {
            SharedPreferences.setMockInitialValues({
              'twitch_app_font_selected_v1': 'system',
            });
            final dir = await Directory.systemTemp.createTemp(
              'vioclass-font-test-',
            );
            addTearDown(() async {
              expect(
                dir.absolute.path.startsWith(
                  Directory.systemTemp.absolute.path,
                ),
                true,
              );
              expect(dir.path.contains('vioclass-font-test-'), true);
              await dir.delete(recursive: true);
            });
            final previousPicker = FilePickerPlatform.instance;
            final previousPaths = PathProviderPlatform.instance;
            final previousStore = SharedPreferencesStorePlatform.instance;
            FilePickerPlatform.instance = _Picker(
              _File(
                File(
                  'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
                ).absolute.path,
              ),
            );
            PathProviderPlatform.instance = _Paths(dir.path);
            final store = _SaveStore(key, throws);
            SharedPreferencesStorePlatform.instance = store;
            addTearDown(() {
              FilePickerPlatform.instance = previousPicker;
              PathProviderPlatform.instance = previousPaths;
              SharedPreferencesStorePlatform.instance = previousStore;
            });
            final controller = TwitchAppFontController(
              loadFont: (_, _) async {},
            );
            addTearDown(controller.dispose);
            await controller.load();
            if (removing) await controller.pickAndSelectFont();
            final originalChoice = controller.selectedId;
            final family = controller.selectedChoice.family;
            final prefs = await SharedPreferences.getInstance();
            final original = {
              for (final key in prefs.getKeys()) key: prefs.get(key),
            };
            store.armed = true;
            Future<void> change() => removing
                ? controller.removeCustomFont(family!)
                : controller.pickAndSelectFont();
            await expectLater(change(), throwsStateError);
            expect(controller.selectedId, originalChoice);
            expect(controller.choices.length, removing ? 3 : 2);
            expect(controller.picking, false);
            expect({
              for (final key in prefs.getKeys()) key: prefs.get(key),
            }, original);
            expect(
              await Directory('${dir.path}/fonts').list().length,
              removing ? 1 : 0,
            );
            await change();
            expect(controller.choices.length, removing ? 2 : 3);
            expect(
              controller.selectedChoice.kind,
              removing ? TwitchAppFontKind.vioClass : TwitchAppFontKind.custom,
            );
            expect(
              await Directory('${dir.path}/fonts').list().length,
              removing ? 0 : 1,
            );
            await prefs.reload();
            final reload = TwitchAppFontController(loadFont: (_, _) async {});
            addTearDown(reload.dispose);
            await reload.load();
            expect(reload.selectedId, controller.selectedId);
            expect(reload.choices.length, controller.choices.length);
          },
        );
      }
    }
  }
  test(
    'Failed font import retains selection, clears busy and retries',
    () async {
      SharedPreferences.setMockInitialValues({
        'twitch_app_font_selected_v1': 'system',
      });
      final dir = await Directory.systemTemp.createTemp('vioclass-font-test-');
      addTearDown(() async {
        expect(
          dir.absolute.path.startsWith(Directory.systemTemp.absolute.path),
          true,
        );
        expect(dir.path.contains('vioclass-font-test-'), true);
        await dir.delete(recursive: true);
      });
      final asset = File('assets/fonts/NotoSansTC-VariableFont_wght.ttf');
      final picker = _Picker(_File(asset.absolute.path));
      final previousPicker = FilePickerPlatform.instance;
      final previousPaths = PathProviderPlatform.instance;
      FilePickerPlatform.instance = picker;
      PathProviderPlatform.instance = _Paths(dir.path);
      addTearDown(() {
        FilePickerPlatform.instance = previousPicker;
        PathProviderPlatform.instance = previousPaths;
      });
      var loads = 0;
      final controller = TwitchAppFontController(
        loadFont: (family, bytes) async {
          loads++;
          expect(bytes.lengthInBytes, greaterThan(0));
          if (loads == 1) throw StateError('fixture font engine failure');
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      await expectLater(controller.pickAndSelectFont(), throwsStateError);
      expect(controller.selectedId, 'system');
      expect(controller.choices.length, 2);
      expect(controller.picking, false);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'twitch_app_font_selected_v1',
        ),
        'system',
      );
      expect(await Directory('${dir.path}/fonts').list().length, 0);
      await controller.pickAndSelectFont();
      expect(picker.calls, 2);
      expect(loads, 2);
      expect(controller.selectedChoice.kind, TwitchAppFontKind.custom);
      expect(controller.picking, false);
      expect(controller.choices.length, 3);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'twitch_app_font_selected_v1',
        ),
        controller.selectedId,
      );
      expect(await Directory('${dir.path}/fonts').list().length, 1);
    },
  );
}

class _SaveStore extends InMemorySharedPreferencesStore {
  _SaveStore(this.failKey, this.throws)
    : super.withData({'flutter.twitch_app_font_selected_v1': 'system'});
  final String failKey;
  final bool throws;
  bool armed = false;
  bool failed = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (armed && !failed && key == 'flutter.$failKey') {
      failed = true;
      if (throws) throw StateError('fixture list save failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
