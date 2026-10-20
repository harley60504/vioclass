// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../lib/features/twitch/services/playback/twitch_audio_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('正在驗證原生音效（不會播放聲音）'))),
    ),
  );
  final dir = await Directory.systemTemp.createTemp('vioclass-audio-probe-');
  final input = File('${dir.path}/tone.wav');
  const count = 48000 * 4;
  final bytes = ByteData(44 + count * 2);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + count * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, 48000, Endian.little);
  bytes.setUint32(28, 96000, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
      44 + i * 2,
      (1600 * sin(2 * pi * 1000 * i / 48000)).round(),
      Endian.little,
    );
  }
  await input.writeAsBytes(bytes.buffer.asUint8List());
  final player = await Player.create(
    configuration: const PlayerConfiguration(
      logLevel: MPVLogLevel.info,
      options: {'ao': 'null', 'vo': 'null'},
    ),
  );
  final failures = <String>[];
  final subscription = player.stream.log.listen((log) {
    if (log.level == 'error' || log.level == 'fatal') {
      failures.add(log.toString());
    }
  });
  final output = TwitchMpvAudioOutput(player);
  debugPrint('[AudioProbe] runtime=${player.getProperty('mpv-version')}');
  final cases = <String, (double, double)>{
    'gain-3db': (100, 3),
    'gain-6db': (100, 6),
    'volume-50-with-gain': (50, 3),
    'muted-with-gain': (0, 3),
    'restored-original': (50, 0),
  };
  for (final entry in cases.entries) {
    await player.stop();
    player.setProperty('af', '');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    failures.clear();
    output.setGainDb(0);
    output.setBaseVolume(entry.value.$1);
    output.setGainDb(entry.value.$2);
    await player.open(Media(input.path));
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final actual = double.parse(player.getProperty('volume'));
    final expected = entry.value.$1 * pow(10, entry.value.$2 / 20);
    if ((actual - expected).abs() > 0.01 ||
        failures.isNotEmpty ||
        player.state.position == Duration.zero) {
      throw StateError('Native gain verification failed: ${entry.key}');
    }
    debugPrint(
      '[AudioProbe] PASS ${entry.key} af=${player.getProperty('af')} volume=$actual errors=${failures.length}',
    );
    for (final error in failures) {
      debugPrint('[AudioProbe] $error');
    }
  }
  final filterCases = {
    'filter-gain': TwitchAudioConfig(enabled: true, gainDb: 3),
    'filter-equalizer': TwitchAudioConfig(
      enabled: true,
      bands: [2, -2, 1, -1, 2],
    ),
    'filter-compressor': TwitchAudioConfig(enabled: true, compressor: true),
    'filter-all': TwitchAudioConfig(
      enabled: true,
      gainDb: 6,
      compressor: true,
      bands: [2, -2, 1, -1, 2],
    ),
  };
  for (final entry in filterCases.entries) {
    await player.stop();
    output.setGainDb(0);
    output.setBaseVolume(100);
    output.setFilter('');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    failures.clear();
    output.setFilter(entry.value.filter);
    await player.open(Media(input.path));
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (failures.isNotEmpty || player.state.position == Duration.zero) {
      for (final error in failures) {
        debugPrint('[AudioProbe] $error');
      }
      throw StateError('Filter verification failed: ${entry.key}');
    }
    debugPrint(
      '[AudioProbe] PASS ${entry.key} af=${player.getProperty('af')} errors=0',
    );
  }
  await subscription.cancel();
  await player.dispose();
  Future<({double rms, double peak})> capture(
    String name,
    TwitchAudioConfig config,
  ) async {
    final rendered = File('${dir.path}/$name.pcm');
    final capturedPlayer = await Player.create(
      configuration: PlayerConfiguration(
        options: {
          'ao': 'pcm',
          'vo': 'null',
          'ao-pcm-waveheader': 'no',
          'ao-pcm-file': rendered.path,
          'audio-format': 'float',
        },
      ),
    );
    final completed = Completer<void>();
    final sub = capturedPlayer.stream.completed.listen((value) {
      if (value && !completed.isCompleted) completed.complete();
    });
    TwitchMpvAudioOutput(capturedPlayer).setFilter(config.filter);
    await capturedPlayer.open(Media(input.path));
    await completed.future.timeout(const Duration(seconds: 15));
    final format = capturedPlayer.getProperty('audio-out-params/format');
    await capturedPlayer.stop();
    await sub.cancel();
    await capturedPlayer.dispose();
    final renderedBytes = await rendered.readAsBytes();
    if (format != 'float' ||
        renderedBytes.isEmpty ||
        renderedBytes.length % 4 != 0) {
      throw StateError(
        'Unexpected PCM format $format, bytes=${renderedBytes.length}',
      );
    }
    final values = ByteData.sublistView(renderedBytes);
    var squared = 0.0;
    var peak = 0.0;
    for (var i = 0; i < renderedBytes.length; i += 4) {
      final sample = values.getFloat32(i, Endian.little);
      squared += sample * sample;
      peak = max(peak, sample.abs());
    }
    final result = (
      rms: sqrt(squared / (renderedBytes.length / 4)),
      peak: peak,
    );
    await rendered.delete();
    debugPrint('[AudioProbe] PCM $name rms=${result.rms} peak=${result.peak}');
    return result;
  }

  final original = await capture('original', TwitchAudioConfig());
  final boosted = await capture(
    'boosted',
    TwitchAudioConfig(enabled: true, gainDb: 3),
  );
  final ratio = boosted.rms / original.rms;
  if ((ratio - pow(10, 3 / 20)).abs() > 0.03) {
    throw StateError('Rendered gain ratio incorrect: $ratio');
  }
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
      44 + i * 2,
      (31000 * sin(2 * pi * 1000 * i / 48000)).round(),
      Endian.little,
    );
  }
  await input.writeAsBytes(bytes.buffer.asUint8List());
  final limited = await capture(
    'limited',
    TwitchAudioConfig(enabled: true, gainDb: 6),
  );
  if (limited.peak > 0.951) {
    throw StateError('Limiter ceiling exceeded: ${limited.peak}');
  }
  debugPrint(
    '[AudioProbe] PASS rendered-gain ratio=$ratio; limiter peak=${limited.peak}',
  );
  // Only temporary files created by this probe, never app/user data.
  await input.delete();
  await dir.delete();
  debugPrint('[AudioProbe] finished');
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('驗證完成'))),
    ),
  );
}
