import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Independent of volume/mute and of account credentials.
class TwitchAudioConfig {
  static const frequencies = [125, 500, 1000, 4000, 8000];
  final bool enabled;
  final bool compressor;
  final double gainDb;
  final List<double> bands;

  TwitchAudioConfig({
    this.enabled = false,
    this.compressor = false,
    double gainDb = 0,
    List<double> bands = const [0, 0, 0, 0, 0],
  }) : gainDb = _safeDb(gainDb, 0, 6),
       bands = List.unmodifiable(
         List.generate(
           5,
           (i) => _safeDb(i < bands.length ? bands[i] : 0, -6, 6),
         ),
       );

  static double _safeDb(double value, double min, double max) =>
      value.isFinite ? value.clamp(min, max).toDouble() : 0;

  TwitchAudioConfig copyWith({
    bool? enabled,
    bool? compressor,
    double? gainDb,
    List<double>? bands,
  }) => TwitchAudioConfig(
    enabled: enabled ?? this.enabled,
    compressor: compressor ?? this.compressor,
    gainDb: gainDb ?? this.gainDb,
    bands: bands ?? this.bands,
  );

  /// Optional EQ -> compression -> gain -> peak limiter. On the full Windows
  /// build gain stays inside this graph, before the limiter. Limiter
  /// makeup is disabled so the ceiling is not amplified back to full scale.
  String get filter {
    if (!enabled) return '';
    final graph = <String>[];
    for (var i = 0; i < bands.length; i++) {
      if (bands[i] != 0) {
        graph.add(
          'equalizer=f=${frequencies[i]}:t=q:w=1:g=${bands[i].toStringAsFixed(1)}',
        );
      }
    }
    if (compressor) {
      graph.add(
        'acompressor=threshold=0.25:ratio=3:attack=10:release=180:makeup=1',
      );
    }
    if (gainDb > 0) graph.add('volume=volume=${gainDb.toStringAsFixed(1)}dB');
    if (graph.isEmpty) return '';
    graph.add('alimiter=limit=0.95:attack=5:release=80:level=false');
    return '@vioclass-audio:lavfi=[${graph.join(',')}]';
  }

  String encode() => jsonEncode({
    'version': 1,
    'enabled': enabled,
    'compressor': compressor,
    'gainDb': gainDb,
    'bands': bands,
  });

  static TwitchAudioConfig decode(String? value) {
    try {
      final data = jsonDecode(value ?? '') as Map<String, dynamic>;
      if (data['version'] != 1) return TwitchAudioConfig();
      return TwitchAudioConfig(
        enabled: data['enabled'] == true,
        compressor: data['compressor'] == true,
        gainDb: (data['gainDb'] as num?)?.toDouble() ?? 0,
        bands:
            (data['bands'] as List?)
                ?.map((v) => v is num ? v.toDouble() : 0.0)
                .toList() ??
            const [],
      );
    } catch (_) {
      return TwitchAudioConfig();
    }
  }
}

abstract class TwitchAudioOutput {
  bool get supportsFilters;
  void setGainDb(double gainDb);
  void setFilter(String filter);
  Stream<String> get errors;
}

class TwitchMpvAudioOutput implements TwitchAudioOutput {
  final Player player;
  double _baseVolume;
  double _gainDb = 0;
  TwitchMpvAudioOutput(this.player)
    : _baseVolume = player.state.volume.clamp(0, 100).toDouble();

  // Windows CMake pins a full build. Android retains its existing package;
  // do not enable filters there without native device validation.
  @override
  bool get supportsFilters =>
      Platform.isWindows &&
      player.getProperty('mpv-version').contains('gfd9265a90');

  void setBaseVolume(double value) {
    _baseVolume = value.clamp(0, 100).toDouble();
    _writeVolume();
  }

  @override
  void setGainDb(double gainDb) {
    _gainDb = gainDb.clamp(0, 6).toDouble();
    _writeVolume();
  }

  void _writeVolume() {
    // Core mpv soft volume, not the unavailable FFmpeg volume filter.
    final effective = _baseVolume * math.pow(10, _gainDb / 20);
    player.setProperty('volume-max', _gainDb > 0 ? '200' : '100');
    player.setProperty('volume', effective.toStringAsFixed(6));
    final actual = double.tryParse(player.getProperty('volume'));
    if (actual == null || (actual - effective).abs() > 0.01) {
      throw StateError('mpv rejected native volume gain');
    }
  }

  @override
  void setFilter(String filter) => player.setProperty('af', filter);

  @override
  Stream<String> get errors => player.stream.log
      .map((log) => log.toString())
      .where(isAudioFilterFailure);

  static bool isAudioFilterFailure(String message) {
    final text = message.toLowerCase();
    final audio =
        text.contains('lavfi') ||
        text.contains('alimiter') ||
        text.contains('acompressor') ||
        text.contains('equalizer') ||
        text.contains('audio filter') ||
        text.contains('[af');
    return audio &&
        (text.contains('error') ||
            text.contains('failed') ||
            text.contains('not found') ||
            text.contains('no such filter'));
  }
}

final twitchAudioSettings = TwitchAudioSettingsRuntime();

/// Owns the application's mpv `af` chain (no other feature writes it).
/// Defaults perform no native writes. A reported filter failure removes the
/// chain and persists bypass, without restarting media or touching mute.
class TwitchAudioSettingsRuntime extends ChangeNotifier {
  static const preferenceKey = 'twitch_player_audio_v1';
  TwitchAudioConfig _config = TwitchAudioConfig();
  TwitchAudioOutput? _output;
  StreamSubscription<String>? _errors;
  Future<void>? _loading;
  Future<void> _queue = Future.value();
  bool _loaded = false;
  bool _applied = false;
  bool _gainApplied = false;
  bool _busy = false;
  String? _error;

  TwitchAudioConfig get config => _config;
  bool get busy => _busy;
  String? get error => _error;
  bool get filtersAvailable => _output?.supportsFilters ?? Platform.isWindows;

  /// Keep the stored/user-facing percentage independent of native gain.
  Future<void> setPlayerVolume(Player player, double volume) async {
    final output = _output;
    if (output is TwitchMpvAudioOutput && identical(output.player, player)) {
      output.setBaseVolume(volume);
    } else if (_config.enabled && _config.gainDb > 0) {
      TwitchMpvAudioOutput(player)
        ..setBaseVolume(volume)
        ..setGainDb(_config.gainDb);
    } else {
      await player.setVolume(volume);
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    _loading ??= () async {
      final prefs = await SharedPreferences.getInstance();
      _config = TwitchAudioConfig.decode(prefs.getString(preferenceKey));
      _loaded = true;
      notifyListeners();
    }();
    try {
      await _loading;
    } finally {
      _loading = null;
    }
  }

  Future<void> attach(TwitchAudioOutput output) async {
    detach();
    _output = output;
    _errors = output.errors.listen((message) {
      if (!identical(_output, output) || !_applied) return;
      debugPrint('[TwitchAudio] filter rejected: $message');
      unawaited(
        _enqueue(() async {
          if (!identical(_output, output) || !_applied) return;
          await _bypass('此裝置無法套用音效，已恢復原音。');
        }),
      );
    });
    await _enqueue(() async {
      await load();
      if (!identical(_output, output)) return;
      try {
        _apply(_config);
      } catch (_) {
        await _bypass('音效套用失敗，已恢復原音。');
      }
    });
  }

  void detach() {
    unawaited(_errors?.cancel());
    _errors = null;
    _output = null;
    _applied = false;
    _gainApplied = false;
  }

  Future<void> update(TwitchAudioConfig next) => _enqueue(() async {
    await load();
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _apply(next);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(preferenceKey, next.encode())) {
        throw StateError('Audio preference write failed');
      }
      _config = next;
    } catch (_) {
      await _bypass('音效套用或儲存失敗，已恢復原音。');
    } finally {
      _busy = false;
      notifyListeners();
    }
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object error) {
      debugPrint('[TwitchAudio] operation failed: $error');
    });
    return next;
  }

  void _apply(TwitchAudioConfig next) {
    final output = _output;
    if (output == null) return;
    final gain = next.enabled && !output.supportsFilters ? next.gainDb : 0.0;
    if (gain > 0 || _gainApplied) {
      _gainApplied = gain > 0;
      output.setGainDb(gain);
    }
    final filter = output.supportsFilters ? next.filter : '';
    if (filter.isEmpty && !_applied) return;
    // Mark before submitting: native failures may arrive asynchronously.
    _applied = filter.isNotEmpty;
    output.setFilter(filter);
  }

  Future<void> _bypass(String message) async {
    try {
      _output?.setFilter('');
      _output?.setGainDb(0);
    } catch (_) {}
    _applied = false;
    _gainApplied = false;
    _config = _config.copyWith(enabled: false);
    _error = message;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, _config.encode());
    } catch (error) {
      // Native bypass still takes precedence if preference storage is broken.
      debugPrint('[TwitchAudio] bypass preference write failed: $error');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
