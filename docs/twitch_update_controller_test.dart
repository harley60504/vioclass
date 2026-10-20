// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/twitch/presentation/settings/vioclass_update_controller.dart';
import '../lib/features/twitch/services/update/vioclass_update_installer.dart';
import '../lib/features/twitch/services/update/vioclass_update_service.dart';

const info = VioClassUpdateInfo(
  currentVersion: '1.0.0',
  updateAvailable: true,
  release: VioClassRelease(
    tagName: 'v1.1.0',
    version: '1.1.0',
    name: 'Fixture update',
    body: '',
    htmlUrl: '',
    publishedAt: null,
    assets: [],
  ),
);

class _Service extends VioClassUpdateService {
  int checks = 0;
  int downloads = 0;
  bool disposed = false;
  bool failCheck = false;
  bool failDownload = false;
  Completer<VioClassUpdateInfo>? pendingCheck;
  Completer<File>? pendingDownload;

  @override
  Future<VioClassUpdateInfo> checkLatest() async {
    checks++;
    if (failCheck) throw StateError('fixture check failure');
    return pendingCheck == null ? info : await pendingCheck!.future;
  }

  @override
  Future<File> downloadPreferredAsset({
    required VioClassUpdateInfo info,
    required void Function(double progress) onProgress,
  }) async {
    downloads++;
    if (failDownload) throw StateError('fixture download failure');
    onProgress(.5);
    final file = pendingDownload == null
        ? File('fixture-no-file-is-created.zip')
        : await pendingDownload!.future;
    onProgress(1);
    return file;
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Installer extends VioClassUpdateInstaller {
  int calls = 0;
  bool fail = false;

  @override
  Future<void> install(File file) async {
    calls++;
    if (fail) throw StateError('fixture install failure');
    // Never create a helper, launch a process, read a file or replace the App.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Service service;
  late _Installer installer;
  late VioClassUpdateController controller;
  var announcements = 0;
  setUp(() {
    // This Flutter test lives in docs rather than the standard test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    announcements = 0;
    service = _Service();
    installer = _Installer();
    controller = VioClassUpdateController(
      service: service,
      installer: installer,
      onNewVersion: (_) async => announcements++,
    );
  });
  tearDown(() {
    if (!service.disposed) controller.dispose();
  });

  test('Duplicate checks share one request without downloads', () async {
    service.pendingCheck = Completer<VioClassUpdateInfo>();
    final first = controller.checkNow();
    expect(controller.checking, true);
    expect(await controller.checkNow(), isNull);
    expect(service.checks, 1);
    service.pendingCheck!.complete(info);
    expect(await first, info);
    expect(controller.hasUpdate, true);
    expect(controller.checking, false);
    expect(service.downloads, 0);
    expect(installer.calls, 0);
  });

  test('Check failure recovers on explicit retry', () async {
    service.failCheck = true;
    expect(await controller.checkNow(), isNull);
    expect(controller.errorText, contains('fixture check failure'));
    expect(controller.checking, false);
    service.failCheck = false;
    expect(await controller.checkNow(), info);
    expect(controller.errorText, isNull);
  });

  test('Disposed check ignores late success and announcements', () async {
    await controller.load();
    service.pendingCheck = Completer<VioClassUpdateInfo>();
    final pending = controller.checkNow(announce: true);
    controller.dispose();
    service.pendingCheck!.complete(info);
    expect(await pending, isNull);
    expect(controller.latest, isNull);
    expect(announcements, 0);
    expect(await controller.checkNow(), isNull);
    expect(service.checks, 1);
  });

  test(
    'Announcement persists once per version in isolated preferences',
    () async {
      await controller.load();
      await controller.checkNow(announce: true);
      await controller.checkNow(announce: true);
      expect(announcements, 1);
      await controller.setAutoCheckEnabled(false);
      await controller.checkNow(announce: true);
      expect(announcements, 1);
      expect(service.downloads, 0);
    },
  );

  test('No checked update never dispatches installation', () async {
    expect(await controller.installUpdate(), false);
    expect(service.downloads, 0);
    expect(installer.calls, 0);
  });

  test('Duplicate install is rejected and mock progress completes', () async {
    await controller.checkNow();
    service.pendingDownload = Completer<File>();
    final first = controller.installUpdate();
    expect(controller.installing, true);
    expect(controller.installProgress, .5);
    expect(await controller.installUpdate(), false);
    service.pendingDownload!.complete(File('fixture-unused.zip'));
    expect(await first, true);
    expect(service.downloads, 1);
    expect(installer.calls, 1);
    expect(controller.installProgress, 1);
    expect(controller.installing, false);
  });

  test('Disposed download never dispatches a late installer', () async {
    await controller.checkNow();
    service.pendingDownload = Completer<File>();
    final pending = controller.installUpdate();
    controller.dispose();
    // Attach the expectation before completing the fake download, so even a
    // late exception remains captured rather than leaking into another test.
    final result = expectLater(pending, completion(false));
    service.pendingDownload!.complete(File('fixture-unused.zip'));
    await result;
    expect(installer.calls, 0);
  });

  for (final downloadFailure in [true, false]) {
    test('Mock install failure recovers: download=$downloadFailure', () async {
      await controller.checkNow();
      service.failDownload = downloadFailure;
      installer.fail = !downloadFailure;
      expect(await controller.installUpdate(), false);
      expect(controller.errorText, contains('fixture'));
      expect(controller.installing, false);
      expect(installer.calls, downloadFailure ? 0 : 1);
      service.failDownload = false;
      installer.fail = false;
      expect(await controller.installUpdate(), true);
      expect(controller.errorText, isNull);
    });
  }
}
