import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update/vioclass_update_installer.dart';
import '../../services/update/vioclass_update_service.dart';

class VioClassUpdateController extends ChangeNotifier {
  static const String _autoCheckKey = 'vioclass_auto_check_updates_v1';
  static const String _announcedKey = 'vioclass_announced_update_versions_v1';
  final Future<void> Function(VioClassUpdateInfo)? onNewVersion;
  Timer? _autoCheckTimer;
  bool _disposed = false;

  final VioClassUpdateService service;
  final VioClassUpdateInstaller installer;

  bool _loaded = false;
  bool _autoCheckEnabled = false;
  bool _checking = false;
  bool _installing = false;
  double _installProgress = 0;
  String? _errorText;
  VioClassUpdateInfo? _latest;

  VioClassUpdateController({
    VioClassUpdateService? service,
    VioClassUpdateInstaller? installer,
    this.onNewVersion,
  }) : service = service ?? VioClassUpdateService(),
       installer = installer ?? VioClassUpdateInstaller();

  bool get loaded => _loaded;
  bool get autoCheckEnabled => _autoCheckEnabled;
  bool get checking => _checking;
  bool get installing => _installing;
  double get installProgress => _installProgress;
  String? get errorText => _errorText;
  VioClassUpdateInfo? get latest => _latest;
  bool get hasUpdate => _latest?.updateAvailable == true;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _autoCheckEnabled = prefs.getBool(_autoCheckKey) ?? true;
    if (_disposed) return;
    _loaded = true;
    _syncAutoCheckTimer();
    notifyListeners();
  }

  Future<void> setAutoCheckEnabled(bool value) async {
    if (_autoCheckEnabled == value) return;
    _autoCheckEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckKey, value);
    _syncAutoCheckTimer();
  }

  void _syncAutoCheckTimer() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
    if (_disposed || !_autoCheckEnabled) return;
    _autoCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => unawaited(checkNow(announce: true)),
    );
  }

  Future<VioClassUpdateInfo?> checkNow({bool announce = false}) async {
    if (_disposed) return null;
    if (_checking) return _latest;
    _checking = true;
    _errorText = null;
    notifyListeners();

    try {
      final info = await service.checkLatest();
      if (_disposed) return null;
      _latest = info;
      if (announce &&
          _autoCheckEnabled &&
          info.updateAvailable &&
          onNewVersion != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_disposed || !_autoCheckEnabled) return info;
        final seen = prefs.getStringList(_announcedKey) ?? [];
        final version = info.release.tagName;
        if (version.isNotEmpty && !seen.contains(version)) {
          await onNewVersion!(info);
          await prefs.setStringList(_announcedKey, [...seen, version]);
        }
      }
      return info;
    } catch (error) {
      _errorText = error.toString();
      return null;
    } finally {
      _checking = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> openUpdate() async {
    final info = _latest;
    if (info == null) return false;
    final target = info.preferredAsset?.downloadUrl.trim().isNotEmpty == true
        ? info.preferredAsset!.downloadUrl
        : info.release.htmlUrl;
    final uri = Uri.tryParse(target);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> installUpdate() async {
    if (_disposed) return false;
    final info = _latest;
    if (info == null) return false;
    if (_installing) return false;
    _installing = true;
    _installProgress = 0;
    _errorText = null;
    notifyListeners();

    try {
      final file = await service.downloadPreferredAsset(
        info: info,
        onProgress: (progress) {
          if (_disposed) return;
          _installProgress = progress;
          notifyListeners();
        },
      );
      if (_disposed) return false;
      await installer.install(file);
      return true;
    } catch (error) {
      _errorText = error.toString();
      return false;
    } finally {
      _installing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autoCheckTimer?.cancel();
    service.dispose();
    super.dispose();
  }
}
