// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/features/twitch/services/playback/twitch_audio_settings.dart';

class _Output implements TwitchAudioOutput {
  final writes = <String>[];
  final gains = <double>[];
  bool filters = false;
  @override
  bool get supportsFilters => filters;
  @override
  void setGainDb(double value) {
    gains.add(value);
    if (reject && value > 0) throw StateError('unsupported');
  }

  final events = StreamController<String>.broadcast();
  bool reject = false;
  @override
  Stream<String> get errors => events.stream;
  @override
  void setFilter(String value) {
    writes.add(value);
    if (reject && value.isNotEmpty) throw StateError('unsupported');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // This Flutter test lives in docs rather than the standard test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  test('Original and neutral audio do not need a filter', () {
    expect(TwitchAudioConfig().filter, '');
    expect(TwitchAudioConfig(enabled: true).filter, '');
    expect(TwitchAudioConfig(gainDb: 6, compressor: true).filter, '');
  });

  test('Signal chain ends in non-makeup peak limiting', () {
    final config = TwitchAudioConfig(
      enabled: true,
      compressor: true,
      gainDb: 3,
      bands: [2, 0, 0, 0, -2],
    );
    final filter = config.filter;
    expect(filter, startsWith('@vioclass-audio:lavfi=['));
    expect(
      filter.indexOf('equalizer'),
      lessThan(filter.indexOf('acompressor')),
    );
    expect(filter, contains('volume=volume=3.0dB'));
    expect(filter.indexOf('volume='), lessThan(filter.indexOf('alimiter=')));
    expect(
      filter,
      endsWith('alimiter=limit=0.95:attack=5:release=80:level=false]'),
    );
  });

  test('Stored values are bounded, immutable and versioned', () {
    final config = TwitchAudioConfig(
      enabled: true,
      gainDb: 900,
      bands: [double.nan, -100, 100],
    );
    expect(config.gainDb, 6);
    expect(config.bands, [0, -6, 6, 0, 0]);
    expect(() => config.bands[0] = 2, throwsUnsupportedError);
    expect(TwitchAudioConfig.decode(config.encode()).encode(), config.encode());
    expect(TwitchAudioConfig.decode('broken').enabled, false);
    expect(
      TwitchAudioConfig.decode('{"version":2,"enabled":true}').enabled,
      false,
    );
  });

  test('Filter failures are distinct from network/video errors', () {
    expect(
      TwitchMpvAudioOutput.isAudioFilterFailure('[af] Failed to create lavfi'),
      true,
    );
    expect(
      TwitchMpvAudioOutput.isAudioFilterFailure('No such filter: alimiter'),
      true,
    );
    expect(
      TwitchMpvAudioOutput.isAudioFilterFailure('HTTP connection failed'),
      false,
    );
    expect(
      TwitchMpvAudioOutput.isAudioFilterFailure('video decoder error'),
      false,
    );
  });

  test(
    'Default attach untouched; disable removes filter; restart restores config',
    () async {
      final output = _Output();
      final runtime = TwitchAudioSettingsRuntime();
      await runtime.attach(output);
      expect(output.writes, isEmpty);
      await runtime.update(TwitchAudioConfig(enabled: true, gainDb: 3));
      expect(output.gains.single, 3);
      await runtime.update(runtime.config.copyWith(enabled: false));
      expect(output.gains.last, 0);
      await runtime.update(runtime.config.copyWith(enabled: true));
      runtime.dispose();
      final restored = TwitchAudioSettingsRuntime();
      final nextOutput = _Output();
      await restored.attach(nextOutput);
      expect(nextOutput.gains.single, 3);
      restored.dispose();
      await output.events.close();
      await nextOutput.events.close();
    },
  );

  test('Concurrent updates save and apply in the same order', () async {
    final output = _Output();
    final runtime = TwitchAudioSettingsRuntime();
    await runtime.attach(output);
    await Future.wait([
      runtime.update(TwitchAudioConfig(enabled: true, gainDb: 2)),
      runtime.update(TwitchAudioConfig(enabled: true, gainDb: 5)),
      runtime.update(TwitchAudioConfig()),
    ]);
    expect(output.gains, [2, 5, 0]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      TwitchAudioConfig.decode(
        prefs.getString(TwitchAudioSettingsRuntime.preferenceKey),
      ).enabled,
      false,
    );
    runtime.dispose();
    await output.events.close();
  });

  test('Rejected native filter rolls back and saves bypass', () async {
    final output = _Output()..reject = true;
    final runtime = TwitchAudioSettingsRuntime();
    await runtime.attach(output);
    await runtime.update(
      TwitchAudioConfig(enabled: true, gainDb: 3, bands: [2, 0, 0, 0, 0]),
    );
    expect(runtime.config.enabled, false);
    expect(runtime.error, isNotNull);
    expect(output.writes.last, '');
    runtime.dispose();
    await output.events.close();
  });

  test('Asynchronous rejection restores original audio', () async {
    final output = _Output()..filters = true;
    final runtime = TwitchAudioSettingsRuntime();
    await runtime.attach(output);
    await runtime.update(
      TwitchAudioConfig(enabled: true, gainDb: 3, bands: [2, 0, 0, 0, 0]),
    );
    final bypassed = Completer<void>();
    runtime.addListener(() {
      if (!runtime.config.enabled &&
          runtime.error != null &&
          !bypassed.isCompleted) {
        bypassed.complete();
      }
    });
    output.events.add('[af] lavfi failed');
    await bypassed.future;
    expect(output.writes.last, '');
    runtime.dispose();
    await output.events.close();
  });

  test('Gain does not depend on missing FFmpeg filters', () async {
    final output = _Output()..filters = false;
    final runtime = TwitchAudioSettingsRuntime();
    await runtime.attach(output);
    await runtime.update(
      TwitchAudioConfig(
        enabled: true,
        gainDb: 3,
        compressor: true,
        bands: [2, 2, 2, 2, 2],
      ),
    );
    expect(output.gains, [3]);
    expect(output.writes, isEmpty);
    expect(runtime.filtersAvailable, false);
    await runtime.update(runtime.config.copyWith(enabled: false));
    expect(output.gains.last, 0);
    runtime.dispose();
    await output.events.close();
  });

  test('Full build gain is before limiter, not after native volume', () async {
    final output = _Output()..filters = true;
    final runtime = TwitchAudioSettingsRuntime();
    await runtime.attach(output);
    await runtime.update(TwitchAudioConfig(enabled: true, gainDb: 3));
    expect(output.gains, isEmpty);
    expect(output.writes.single, contains('volume=volume=3.0dB,alimiter='));
    await runtime.update(runtime.config.copyWith(enabled: false));
    expect(output.writes.last, '');
    runtime.dispose();
    await output.events.close();
  });
}
