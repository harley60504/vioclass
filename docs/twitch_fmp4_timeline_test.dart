import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart';
import 'twitch_fragment_timestamp_fixture.dart';

class _Bytes implements TwitchHlsByteSink {
  final bytes = <int>[];
  @override
  int get bufferedBytes => bytes.length;
  @override
  void close() {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
  }
}

List<int> _number(BigInt value, int width) => List.generate(
  width,
  (index) => ((value >> ((width - index - 1) * 8)) & BigInt.from(255)).toInt(),
);
List<int> _box(String type, List<int> body, {bool extended = false}) => [
  ..._number(BigInt.from(extended ? 1 : body.length + 8), 4),
  ...type.codeUnits,
  if (extended) ..._number(BigInt.from(body.length + 16), 8),
  ...body,
];
List<int> _track(int id, int scale) => _box('trak', [
  ..._box('tkhd', [...List<int>.filled(12, 0), ..._number(BigInt.from(id), 4)]),
  ..._box(
    'mdia',
    _box('mdhd', [
      ...List<int>.filled(12, 0),
      ..._number(BigInt.from(scale), 4),
    ]),
  ),
]);
List<int> _twoTrackFragment(
  int video,
  int audio, {
  int version = 1,
  bool extended = false,
}) => [
  ..._box('moof', [
    for (final track in [(1, video), (2, audio)])
      ..._box('traf', [
        ..._box('tfhd', [0, 0, 0, 0, ..._number(BigInt.from(track.$1), 4)]),
        ..._box('tfdt', [
          version,
          0,
          0,
          0,
          ..._number(BigInt.from(track.$2), version == 1 ? 8 : 4),
        ]),
      ]),
  ], extended: extended),
  ..._box('mdat', [1, 2, 3, 4]),
];

void main() {
  test('Discontinuity preserves the new audio video time difference', () async {
    final timeline = TwitchFmp4Timeline()
      ..setInitialization(
        _box('moov', [..._track(1, 1000), ..._track(2, 48000)]),
      );
    final output = _Bytes();
    await timeline
        .segmentSink(output, epoch: 0, writtenDuration: Duration.zero)
        .addStream(Stream.value(_twoTrackFragment(0, 0)));
    output.bytes.clear();
    await timeline
        .segmentSink(
          output,
          epoch: 1,
          writtenDuration: const Duration(seconds: 6),
        )
        .addStream(Stream.value(_twoTrackFragment(0, 9600)));
    expect(output.bytes, _twoTrackFragment(6000, 297600));
    output.bytes.clear();
    await timeline
        .segmentSink(
          output,
          epoch: 2,
          writtenDuration: const Duration(seconds: 9),
        )
        .addStream(Stream.value(_twoTrackFragment(10000, 489600)));
    expect(output.bytes, _twoTrackFragment(9000, 441600));
    output.bytes.clear();
    timeline.setInitialization(
      _box('moov', [..._track(1, 1000), ..._track(2, 44100)]),
    );
    await timeline
        .segmentSink(
          output,
          epoch: 3,
          writtenDuration: const Duration(seconds: 12),
        )
        .addStream(Stream.value(_twoTrackFragment(0, 4410)));
    expect(output.bytes, _twoTrackFragment(12000, 533610));
  });
  for (final version in [0, 1]) {
    test(
      'Full byte splitting and extended boxes tfdt version=$version',
      () async {
        final timeline = TwitchFmp4Timeline()
          ..setInitialization(
            _box('moov', [..._track(1, 1000), ..._track(2, 48000)]),
          );
        final output = _Bytes();
        final original = _twoTrackFragment(
          0,
          0,
          version: version,
          extended: true,
        );
        await timeline
            .segmentSink(output, epoch: 0, writtenDuration: Duration.zero)
            .addStream(Stream.value(original));
        expect(output.bytes, original);
        output.bytes.clear();
        await timeline
            .segmentSink(
              output,
              epoch: 1,
              writtenDuration: const Duration(seconds: 6),
            )
            .addStream(Stream.fromIterable(original.map((byte) => [byte])));
        expect(
          output.bytes,
          _twoTrackFragment(6000, 288000, version: version, extended: true),
        );
      },
    );
  }
  test('32 bit decode-time overflow never emits damaged metadata', () async {
    final timeline = TwitchFmp4Timeline()
      ..setInitialization(
        _box('moov', [..._track(1, 1000), ..._track(2, 48000)]),
      );
    final output = _Bytes();
    final fragment = _twoTrackFragment(0xfffffff0, 0, version: 0);
    await timeline
        .segmentSink(output, epoch: 0, writtenDuration: Duration.zero)
        .addStream(Stream.value(fragment));
    output.bytes.clear();
    await expectLater(
      timeline
          .segmentSink(
            output,
            epoch: 1,
            writtenDuration: const Duration(seconds: 6),
          )
          .addStream(Stream.value(fragment)),
      throwsFormatException,
    );
    expect(output.bytes, isEmpty);
  });
  test('Empty initialization full box fails as a format error', () {
    final timeline = TwitchFmp4Timeline();
    expect(
      () => timeline.setInitialization(
        _box('moov', _box('trak', _box('tkhd', []))),
      ),
      throwsFormatException,
    );
  });
  late List<int> init;
  late List<int> fragment;
  setUpAll(() async {
    final bytes = await File('docs/twitch-decoder-fixture.mp4').readAsBytes();
    var offset = 0;
    while (String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)) !=
        'moof') {
      offset +=
          (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
    }
    init = bytes.sublist(0, offset);
    fragment = bytes.sublist(offset);
  });
  for (final split in [false, true]) {
    test('Only discontinuity decode times change split=$split', () async {
      final timeline = TwitchFmp4Timeline()..setInitialization(init);
      final output = _Bytes();
      final first = timeline.segmentSink(
        output,
        epoch: 7,
        writtenDuration: Duration.zero,
      );
      await first.addStream(Stream.value(fragment));
      expect(output.bytes, fragment);
      output.bytes.clear();
      final shifted = twitchShiftFixtureFragment(
        initialization: init,
        fragment: fragment,
        seconds: 3,
      );
      final normal = timeline.segmentSink(
        output,
        epoch: 7,
        writtenDuration: const Duration(seconds: 3),
      );
      await normal.addStream(Stream.value(shifted));
      expect(output.bytes, shifted);
      output.bytes.clear();
      final reset = timeline.segmentSink(
        output,
        epoch: 8,
        writtenDuration: const Duration(seconds: 6),
      );
      if (split) {
        // Prefix and fallback suffix arrive through separate addStream calls.
        await reset.addStream(Stream.value(fragment.sublist(0, 3)));
        expect(output.bytes, isEmpty);
        await reset.addStream(Stream.value(fragment.sublist(3, 17)));
        await reset.addStream(Stream.value(fragment.sublist(17)));
      } else {
        await reset.addStream(Stream.value(fragment));
      }
      expect(
        output.bytes,
        twitchShiftFixtureFragment(
          initialization: init,
          fragment: fragment,
          seconds: 6,
        ),
      );
      expect(fragment, isNot(output.bytes));
      output.bytes.clear();
      // Offset persists for the next segment in the same new epoch.
      await timeline
          .segmentSink(
            output,
            epoch: 8,
            writtenDuration: const Duration(seconds: 9),
          )
          .addStream(Stream.value(shifted));
      expect(
        output.bytes,
        twitchShiftFixtureFragment(
          initialization: init,
          fragment: fragment,
          seconds: 9,
        ),
      );
    });
  }
  test('Oversized metadata is rejected before emission', () async {
    final timeline = TwitchFmp4Timeline()..setInitialization(init);
    final output = _Bytes();
    final sink = timeline.segmentSink(
      output,
      epoch: 0,
      writtenDuration: Duration.zero,
    );
    await expectLater(
      sink.addStream(Stream.value([0, 32, 0, 0, ...'moof'.codeUnits])),
      throwsFormatException,
    );
    expect(output.bytes, isEmpty);
  });
}
