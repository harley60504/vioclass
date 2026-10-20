// ignore_for_file: avoid_relative_lib_imports, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/presentation/sheets/twitch_app_settings_sheet.dart';
import '../lib/features/twitch/services/update/vioclass_update_service.dart';
import '../lib/features/twitch/services/update/vioclass_update_installer.dart';

class _Service extends VioClassUpdateService {
  bool failCheck = true;
  bool failDownload = true;
  Completer<VioClassUpdateInfo>? gate;
  int checks = 0;
  int downloads = 0;
  @override
  Future<VioClassUpdateInfo> checkLatest() async {
    checks++;
    if (failCheck) throw StateError('fixture private check failure');
    return gate!.future;
  }

  @override
  Future<File> downloadPreferredAsset({
    required VioClassUpdateInfo info,
    required void Function(double progress) onProgress,
  }) async {
    downloads++;
    if (failDownload) throw StateError('fixture private download failure');
    onProgress(1);
    return File('fixture-never-created.zip');
  }
}

class _Installer extends VioClassUpdateInstaller {
  int calls = 0;
  @override
  Future<void> install(File file) async {
    calls++;
  }
}

void main() {
  for (final size in [const Size(900, 700), const Size(320, 640)]) {
    testWidgets('Update sheet retry and fake installation at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'vioclass_auto_check_updates_v1': false,
      });
      final service = _Service();
      final installer = _Installer();
      final controller = VioClassUpdateController(
        service: service,
        installer: installer,
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showVioClassUpdateSheet(
                  context: context,
                  controller: controller,
                ),
                child: const Text('fixture open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('fixture open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('立即檢查'));
      await tester.pumpAndSettle();
      expect(find.text('更新檢查失敗，稍後再試。'), findsOneWidget);
      expect(find.text('fixture private check failure'), findsNothing);
      service.failCheck = false;
      service.gate = Completer<VioClassUpdateInfo>();
      await tester.tap(find.text('立即檢查'));
      await tester.pump();
      final checking = find.widgetWithText(FilledButton, '檢查中');
      expect(tester.widget<FilledButton>(checking).onPressed, isNull);
      await tester.tap(checking);
      expect(service.checks, 2);
      service.gate!.complete(
        VioClassUpdateInfo(
          currentVersion: '1.0.0',
          updateAvailable: true,
          release: VioClassRelease.fromGithubJson({
            'tag_name': 'v9.0.0',
            'assets': [
              {
                'name': 'VioClass-Windows.zip',
                'browser_download_url': 'https://fixture.invalid/file.zip',
              },
              {
                'name': 'VioClass.apk',
                'browser_download_url': 'https://fixture.invalid/file.apk',
              },
            ],
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('找到新版 v9.0.0'), findsOneWidget);
      await tester.tap(find.text('下載並安裝'));
      await tester.pumpAndSettle();
      expect(service.downloads, 1);
      expect(installer.calls, 0);
      expect(find.text('fixture private download failure'), findsNothing);
      service.failDownload = false;
      await tester.tap(find.text('下載並安裝'));
      await tester.pumpAndSettle();
      expect(service.downloads, 2);
      expect(installer.calls, 1);
      expect(controller.installing, isFalse);
      expect(controller.errorText, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
