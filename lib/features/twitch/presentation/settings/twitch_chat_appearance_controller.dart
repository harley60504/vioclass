import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/chat/links/twitch_chat_link_preview_policy.dart';

class TwitchChatAppearanceController extends ChangeNotifier {
  static const double defaultFontScale = 1.0;
  static const String _fontScaleKey = 'twitch_chat_font_scale_v1';
  static const String _linkPreviewsEnabledKey =
      'twitch_chat_link_previews_enabled_v1';
  static const String _messageTimestampsEnabledKey =
      'twitch_chat_message_timestamps_enabled_v1';
  static const String _trustedPreviewDomainsKey =
      'twitch_chat_trusted_preview_domains_v1';

  double _fontScale = defaultFontScale;
  bool _linkPreviewsEnabled = true;
  bool _messageTimestampsEnabled = false;
  List<String> _trustedPreviewDomains = const <String>[];
  bool _loaded = false;
  Future<void> _writes = Future<void>.value();

  double get fontScale => _fontScale;
  bool get linkPreviewsEnabled => _linkPreviewsEnabled;
  bool get messageTimestampsEnabled => _messageTimestampsEnabled;
  List<String> get trustedPreviewDomains => _trustedPreviewDomains;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _fontScale = (prefs.getDouble(_fontScaleKey) ?? defaultFontScale).clamp(
      0.82,
      1.45,
    );
    _linkPreviewsEnabled = prefs.getBool(_linkPreviewsEnabledKey) ?? true;
    _messageTimestampsEnabled =
        prefs.getBool(_messageTimestampsEnabledKey) ?? false;
    _trustedPreviewDomains = _normalizeDomains(
      prefs.getStringList(_trustedPreviewDomainsKey) ?? const <String>[],
    );
    _applyLinkPreviewSettings();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFontScale(double value) => _queueWrite(() async {
    final next = value.clamp(0.82, 1.45);
    if ((_fontScale - next).abs() < 0.001) return;

    await _savePreference((prefs) => prefs.setDouble(_fontScaleKey, next));
    _fontScale = next;
    notifyListeners();
  });

  Future<void> setLinkPreviewsEnabled(bool value) => _queueWrite(() async {
    if (_linkPreviewsEnabled == value) return;
    await _savePreference(
      (prefs) => prefs.setBool(_linkPreviewsEnabledKey, value),
    );
    _linkPreviewsEnabled = value;
    _applyLinkPreviewSettings();
    notifyListeners();
  });

  Future<void> setMessageTimestampsEnabled(bool value) => _queueWrite(() async {
    if (_messageTimestampsEnabled == value) return;
    await _savePreference(
      (prefs) => prefs.setBool(_messageTimestampsEnabledKey, value),
    );
    _messageTimestampsEnabled = value;
    notifyListeners();
  });

  Future<void> addTrustedPreviewDomain(String value) => _queueWrite(() async {
    final domain = _normalizeDomain(value);
    if (domain.isEmpty || _trustedPreviewDomains.contains(domain)) return;
    final next = <String>[..._trustedPreviewDomains, domain]..sort();
    await _saveTrustedPreviewDomains(next);
  });

  Future<void> removeTrustedPreviewDomain(String value) =>
      _queueWrite(() async {
        final domain = _normalizeDomain(value);
        final next = _trustedPreviewDomains
            .where((item) => item != domain)
            .toList(growable: false);
        if (next.length == _trustedPreviewDomains.length) return;
        await _saveTrustedPreviewDomains(next);
      });

  Future<void> _queueWrite(Future<void> Function() write) {
    final result = _writes.then((_) => write());
    _writes = result.catchError((Object _) {});
    return result;
  }

  Future<void> reset() => setFontScale(defaultFontScale);

  Future<void> _saveTrustedPreviewDomains(List<String> next) async {
    await _savePreference(
      (prefs) => prefs.setStringList(_trustedPreviewDomainsKey, next),
    );
    _trustedPreviewDomains = next;
    _applyLinkPreviewSettings();
    notifyListeners();
  }

  Future<void> _savePreference(
    Future<bool> Function(SharedPreferences) write,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await write(prefs)) {
        throw StateError('Chat appearance preference was not saved');
      }
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
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

final TwitchChatAppearanceController twitchChatAppearanceController =
    TwitchChatAppearanceController();
