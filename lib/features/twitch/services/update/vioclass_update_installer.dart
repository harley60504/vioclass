import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class VioClassUpdateInstaller {
  static const MethodChannel _androidChannel = MethodChannel(
    'vio_class/app_update',
  );

  Future<void> install(File file) async {
    if (Platform.isWindows) {
      await _installWindowsZip(file);
      return;
    }
    if (Platform.isAndroid) {
      await _installAndroidApk(file);
      return;
    }
    throw UnsupportedError('此平台暫不支援自動更新。');
  }

  Future<void> _installAndroidApk(File file) async {
    if (!file.path.toLowerCase().endsWith('.apk')) {
      throw StateError('Android 更新檔不是 APK。');
    }
    await _androidChannel.invokeMethod<void>('installApk', <String, Object?>{
      'path': file.path,
    });
  }

  Future<void> _installWindowsZip(File file) async {
    if (!file.path.toLowerCase().endsWith('.zip')) {
      throw StateError('Windows 自動更新目前需要 zip 更新檔。');
    }

    final executable = File(Platform.resolvedExecutable);
    final appDirectory = executable.parent;
    final helperDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}vioclass_update_helper',
    );
    if (!helperDirectory.existsSync()) {
      helperDirectory.createSync(recursive: true);
    }

    if (_looksLikeFlutterBuildDirectory(appDirectory.path)) {
      throw StateError('Debug 模式不會自動覆蓋 build 目錄，請用正式版測試自動更新。');
    }

    final helper = File(
      '${helperDirectory.path}${Platform.pathSeparator}update_vioclass.ps1',
    );
    helper.writeAsStringSync(
      _windowsUpdateScript(
        pid: pid,
        zipPath: file.path,
        appDirectory: appDirectory.path,
        executableName: executable.path.split(Platform.pathSeparator).last,
      ),
      encoding: utf8,
    );

    await Process.start('powershell.exe', <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      helper.path,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  String _windowsUpdateScript({
    required int pid,
    required String zipPath,
    required String appDirectory,
    required String executableName,
  }) {
    final safeZip = _psSingleQuote(zipPath);
    final safeAppDir = _psSingleQuote(appDirectory);
    final safeExe = _psSingleQuote(executableName);
    return '''
\$ErrorActionPreference = 'Stop'
\$pidToWait = $pid
\$zipPath = '$safeZip'
\$appDir = '$safeAppDir'
\$exeName = '$safeExe'
\$staging = Join-Path \$env:TEMP ('VioClassUpdate-' + [Guid]::NewGuid().ToString('N'))

Start-Sleep -Milliseconds 500
try {
  Wait-Process -Id \$pidToWait -Timeout 45 -ErrorAction SilentlyContinue
} catch {}

New-Item -ItemType Directory -Path \$staging -Force | Out-Null
Expand-Archive -LiteralPath \$zipPath -DestinationPath \$staging -Force

\$source = \$staging
\$children = @(Get-ChildItem -LiteralPath \$staging)
if (\$children.Count -eq 1 -and \$children[0].PSIsContainer) {
  \$candidateExe = Join-Path \$children[0].FullName \$exeName
  if (Test-Path -LiteralPath \$candidateExe) {
    \$source = \$children[0].FullName
  }
}

Copy-Item -Path (Join-Path \$source '*') -Destination \$appDir -Recurse -Force
Start-Process -FilePath (Join-Path \$appDir \$exeName) -WorkingDirectory \$appDir
''';
  }

  String _psSingleQuote(String value) {
    return value.replaceAll("'", "''");
  }

  bool _looksLikeFlutterBuildDirectory(String path) {
    final normalized = path.replaceAll('/', r'\').toLowerCase();
    return normalized.contains(r'\build\windows\');
  }
}
