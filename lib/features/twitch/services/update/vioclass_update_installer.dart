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
    final launcher = File(
      '${helperDirectory.path}${Platform.pathSeparator}launch_update.cmd',
    );
    final script = _windowsUpdateScript(
      pid: pid,
      zipPath: file.path,
      appDirectory: appDirectory.path,
      executableName: executable.path.split(Platform.pathSeparator).last,
    );
    helper.writeAsBytesSync(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(script)]);
    launcher.writeAsStringSync(
      _windowsLauncherBatch(helper.path),
      encoding: ascii,
    );

    await Process.start('cmd.exe', <String>[
      '/c',
      launcher.path,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  String _windowsLauncherBatch(String helperPath) {
    final batchPath = helperPath.replaceAll('%', '%%');
    return '''
@echo off
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$batchPath"
''';
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
\$logPath = Join-Path \$env:TEMP 'VioClassUpdate.log'
\$staging = Join-Path \$env:TEMP ('VioClassUpdate-' + [Guid]::NewGuid().ToString('N'))

function Write-UpdateLog([string]\$message) {
  \$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Add-Content -LiteralPath \$logPath -Encoding UTF8 -Value "[\$timestamp] \$message"
}

try {
  Write-UpdateLog 'Update helper started.'
  Write-UpdateLog "Zip: \$zipPath"
  Write-UpdateLog "AppDir: \$appDir"
  Write-UpdateLog "Exe: \$exeName"

  Start-Sleep -Milliseconds 800
  try {
    Wait-Process -Id \$pidToWait -Timeout 60 -ErrorAction SilentlyContinue
  } catch {
    Write-UpdateLog "Wait-Process warning: \$(\$_.Exception.Message)"
  }

  New-Item -ItemType Directory -Path \$staging -Force | Out-Null
  Expand-Archive -LiteralPath \$zipPath -DestinationPath \$staging -Force
  Write-UpdateLog "Expanded to: \$staging"

  \$candidateExe = Get-ChildItem -LiteralPath \$staging -Filter \$exeName -Recurse -File |
    Select-Object -First 1
  if (\$null -eq \$candidateExe) {
    throw "Cannot find \$exeName in extracted update."
  }
  \$source = \$candidateExe.DirectoryName
  Write-UpdateLog "Source: \$source"

  robocopy \$source \$appDir /E /IS /IT /R:20 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
  \$copyExitCode = \$LASTEXITCODE
  Write-UpdateLog "Robocopy exit code: \$copyExitCode"
  if (\$copyExitCode -ge 8) {
    throw "Robocopy failed with exit code \$copyExitCode."
  }

  \$targetExe = Join-Path \$appDir \$exeName
  if (-not (Test-Path -LiteralPath \$targetExe)) {
    throw "Updated executable not found: \$targetExe"
  }

  Write-UpdateLog "Restarting: \$targetExe"
  Start-Process -FilePath \$targetExe -WorkingDirectory \$appDir
  Write-UpdateLog 'Update helper finished.'
} catch {
  Write-UpdateLog "ERROR: \$(\$_.Exception.Message)"
  Start-Sleep -Seconds 3
}
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
