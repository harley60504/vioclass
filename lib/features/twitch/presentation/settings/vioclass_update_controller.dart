import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update/vioclass_update_service.dart';

class VioClassUpdateController extends ChangeNotifier {
  static const String _autoCheckKey = 'vioclass_auto_check_updates_v1';

  final VioClassUpdateService service;

  bool _loaded = false;
  bool _autoCheckEnabled = false;
  bool _checking = false;
  String? _errorText;
  VioClassUpdateInfo? _latest;

  VioClassUpdateController({VioClassUpdateService? service})
    : service = service ?? VioClassUpdateService();

  bool get loaded => _loaded;
  bool get autoCheckEnabled => _autoCheckEnabled;
  bool get checking => _checking;
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

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }
}
