import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/playback/twitch_m3u8_variant.dart';

enum TwitchQualityMode { manual, highest, auto }

/// Rebuffering-based adaptation, not a bandwidth estimate. DVR and paused
/// playback are excluded so automatic quality cannot steal a replay position.
class TwitchAdaptiveQualityController extends ChangeNotifier {
  static const preferenceKey = 'twitch_player_quality_mode_v1';
  final List<TwitchM3u8Variant> Function() variants;
  final TwitchM3u8Variant? Function() current;
  final bool Function() playing;
  final bool Function() buffering;
  final bool Function() enabled;
  final FutureOr<void> Function(TwitchM3u8Variant) select;
  final DateTime Function() now;
  TwitchQualityMode mode = TwitchQualityMode.manual;
  Timer? _timer;
  DateTime? _bufferingSince;
  DateTime? _stableSince;
  DateTime? _lastSwitch;
  bool _busy = false;
  bool _disposed = false;
  bool _loaded = false;
  int _revision = 0;
  Future<void> _modeWrites = Future<void>.value();

  TwitchAdaptiveQualityController({
    required this.variants,
    required this.current,
    required this.playing,
    required this.buffering,
    required this.enabled,
    required this.select,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static List<TwitchM3u8Variant> ranked(List<TwitchM3u8Variant> choices) {
    final result = choices.where((v) => !v.isAudioOnly).toList();
    result.sort((a, b) {
      final height = b.height.compareTo(a.height);
      if (height != 0) return height;
      final fps = b.fpsRounded.compareTo(a.fpsRounded);
      if (fps != 0) return fps;
      if (a.hasAds != b.hasAds) return a.hasAds ? 1 : -1;
      return (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
    });
    // Alternate token contexts can expose the same quality more than once.
    // One downgrade must actually lower the rendition, not just swap URLs.
    final unique = <String, TwitchM3u8Variant>{};
    for (final variant in result) {
      unique.putIfAbsent(variant.adAwareQualityKey, () => variant);
    }
    return unique.values.toList();
  }

  Future<void> start() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    if (revision == _revision) {
      final saved = prefs.getString(preferenceKey);
      mode = TwitchQualityMode.values.firstWhere(
        (v) => v.name == saved,
        orElse: () => TwitchQualityMode.manual,
      );
      _loaded = true;
      notifyListeners();
    }
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(sample());
    });
  }

  Future<void> setMode(TwitchQualityMode value) {
    final revision = ++_revision;
    final result = _modeWrites.then((_) => _applyMode(value, revision));
    _modeWrites = result.catchError((Object _) {});
    return result;
  }

  Future<void> _applyMode(TwitchQualityMode value, int revision) async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    if (!await prefs.setString(preferenceKey, value.name)) {
      throw StateError('Quality preference was not saved');
    }
    if (_disposed || revision != _revision) return;
    mode = value;
    _loaded = true;
    _bufferingSince = null;
    _stableSince = null;
    _lastSwitch = null;
    notifyListeners();
    if (value != TwitchQualityMode.manual && enabled()) {
      final choices = ranked(variants());
      if (choices.isNotEmpty) await _choose(choices.first);
    }
  }

  Future<void> chooseManual(TwitchM3u8Variant variant) async {
    await setMode(TwitchQualityMode.manual);
    if (!_disposed && mode == TwitchQualityMode.manual) await _choose(variant);
  }

  Future<void> sample() async {
    if (_disposed || !_loaded || _busy || mode == TwitchQualityMode.manual) {
      return;
    }
    if (!enabled() || !playing()) {
      _bufferingSince = null;
      _stableSince = null;
      return;
    }
    final choices = ranked(variants());
    if (choices.isEmpty) return;
    if (mode == TwitchQualityMode.highest) {
      if (_lastSwitch == null ||
          now().difference(_lastSwitch!) >= const Duration(seconds: 30)) {
        await _choose(choices.first);
      }
      return;
    }
    final time = now();
    final index = choices.indexWhere((v) => v.url == current()?.url);
    if (index < 0) return;
    if (buffering()) {
      _stableSince = null;
      _bufferingSince ??= time;
    } else {
      _bufferingSince = null;
      _stableSince ??= time;
    }
    if (_lastSwitch != null &&
        time.difference(_lastSwitch!) < const Duration(seconds: 30)) {
      return;
    }
    if (_bufferingSince != null &&
        time.difference(_bufferingSince!) >= const Duration(seconds: 6) &&
        index + 1 < choices.length) {
      await _choose(choices[index + 1]);
    } else if (_stableSince != null &&
        time.difference(_stableSince!) >= const Duration(seconds: 60) &&
        index > 0) {
      await _choose(choices[index - 1]);
    }
  }

  Future<void> _choose(TwitchM3u8Variant variant) async {
    if (_disposed || _busy || variant.url == current()?.url) return;
    _busy = true;
    _lastSwitch = now();
    _stableSince = null;
    _bufferingSince = null;
    try {
      await select(variant);
    } catch (_) {
      /* Preserve the existing source and respect the cooldown. */
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    super.dispose();
  }
}
