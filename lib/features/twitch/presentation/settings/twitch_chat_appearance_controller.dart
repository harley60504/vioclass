import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/chat/links/twitch_chat_link_preview_policy.dart';

class TwitchChatAppearanceController extends ChangeNotifier {
  static const String _fontScaleKey = 'twitch_chat_font_scale_v1';
  static const String _linkPreviewsEnabledKey =
      'twitch_chat_link_previews_enabled_v1';
  static const String _trustedPreviewDomainsKey =
      'twitch_chat_trusted_preview_domains_v1';

  double _fontScale = 1.0;
  bool _linkPreviewsEnabled = true;
  List<String> _trustedPreviewDomains = const <String>[];
  bool _loaded = false;

  double get fontScale => _fontScale;
  bool get linkPreviewsEnabled => _linkPreviewsEnabled;
  List<String> get trustedPreviewDomains => _trustedPreviewDomains;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _fontScale = (prefs.getDouble(_fontScaleKey) ?? 1.0).clamp(0.82, 1.45);
    _linkPreviewsEnabled = prefs.getBool(_linkPreviewsEnabledKey) ?? true;
    _trustedPreviewDomains = _normalizeDomains(
      prefs.getStringList(_trustedPreviewDomainsKey) ?? const <String>[],
    );
    _applyLinkPreviewSettings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    final next = value.clamp(0.82, 1.45);
    if ((_fontScale - next).abs() < 0.001) return;

    _fontScale = next;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, _fontScale);
  }

  Future<void> setLinkPreviewsEnabled(bool value) async {
    if (_linkPreviewsEnabled == value) return;
    _linkPreviewsEnabled = value;
    _applyLinkPreviewSettings();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_linkPreviewsEnabledKey, value);
  }

  Future<void> addTrustedPreviewDomain(String value) async {
    final domain = _normalizeDomain(value);
    if (domain.isEmpty || _trustedPreviewDomains.contains(domain)) return;
    _trustedPreviewDomains = <String>[..._trustedPreviewDomains, domain]
      ..sort();
    await _saveTrustedPreviewDomains();
  }

  Future<void> removeTrustedPreviewDomain(String value) async {
    final domain = _normalizeDomain(value);
    final next = _trustedPreviewDomains
        .where((item) => item != domain)
        .toList(growable: false);
    if (next.length == _trustedPreviewDomains.length) return;
    _trustedPreviewDomains = next;
    await _saveTrustedPreviewDomains();
  }

  Future<void> reset() => setFontScale(1.0);

  Future<void> _saveTrustedPreviewDomains() async {
    _applyLinkPreviewSettings();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _trustedPreviewDomainsKey,
      _trustedPreviewDomains,
    );
  }

  void _applyLinkPreviewSettings() {
    configureTwitchChatLinkPreviews(
      enabled: _linkPreviewsEnabled,
      trustedDomains: _trustedPreviewDomains,
    );
  }

  List<String> _normalizeDomains(List<String> values) {
    return values
        .map(_normalizeDomain)
        .where((domain) => domain.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  String _normalizeDomain(String value) {
    var text = value.trim().toLowerCase();
    if (text.isEmpty) return '';
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    final host = uri?.host.trim().toLowerCase() ?? '';
    if (host.isEmpty || host == 'localhost') return '';
    if (host.endsWith('.local') || host.endsWith('.localhost')) return '';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }
}
