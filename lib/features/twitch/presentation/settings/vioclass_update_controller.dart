import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update/vioclass_update_installer.dart';
import '../../services/update/vioclass_update_service.dart';

class VioClassUpdateController extends ChangeNotifier {
  static const String _autoCheckKey = 'vioclass_auto_check_updates_v1';

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
    _autoCheckEnabled = prefs.getBool(_autoCheckKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setAutoCheckEnabled(bool value) async {
    if (_autoCheckEnabled == value) return;
    _autoCheckEnabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckKey, value);
  }

  Future<VioClassUpdateInfo?> checkNow() async {
    if (_checking) return _latest;
    _checking = true;
    _errorText = null;
    notifyListeners();

    try {
      final info = await service.checkLatest();
      _latest = info;
      return info;
    } catch (error) {
      _errorText = error.toString();
      return null;
    } finally {
      _checking = false;
      notifyListeners();
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
          _installProgress = progress;
          notifyListeners();
        },
      );
      await installer.install(file);
      return true;
    } catch (error) {
      _errorText = error.toString();
      return false;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }
}
