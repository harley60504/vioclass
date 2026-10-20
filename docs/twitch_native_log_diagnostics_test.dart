import 'package:flutter_test/flutter_test.dart';
import 'twitch_native_log_diagnostics.dart';

void main() {
  test('Audio decode and output failures remain distinct fixed categories', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record(
      'Error decoding audio https://fixture.invalid/?secret=token',
    );
    diagnostics.record(
      'Could not open/initialize audio device fixture-private-name',
    );
    expect(diagnostics.snapshot, {
      'audio_decode_failed': 1,
      'audio_output_failed': 1,
      'open_failed': 1,
    });
  });
  test('Audio sync diagnostics expose only numeric and boolean fields', () {
    final values = {
      'audio-params/samplerate': '48000',
      'audio-params/channel-count': '2',
      'audio-out-params/samplerate': '48000',
      'avsync': '-0.025',
      'volume': '0',
      'mute': 'yes',
    };
    expect(
      twitchNativePlaybackProperties(
        (name) => values[name] ?? (throw StateError('unsupported')),
      ),
      values,
    );
  });
  test(
    'Switch flags ignore URL keywords but retain actual native failures',
    () {
      expect(
        twitchNativeLogFlags(
          'Opened https://fixture.invalid/error/decoder?failed=403&moov=404',
        ),
        isEmpty,
      );
      expect(
        twitchNativeLogFlags(
          'Failed to open decoder https://fixture.invalid/video?error=403',
        ),
        unorderedEquals(['failed', 'decoder']),
      );
    },
  );
  test(
    'Decode and output fields omit unsupported properties independently',
    () {
      final values = {
        'video-params/w': '1920',
        'video-params/h': '1080',
        'video-out-params/w': '1280',
        'video-out-params/h': '720',
        'decoder-frame-drop-count': '2',
        'frame-drop-count': '3',
        'vo-delayed-frame-count': '0',
      };
      expect(
        twitchNativePlaybackProperties(
          (name) => values[name] ?? (throw StateError('unsupported')),
        ),
        values,
      );
    },
  );
  test(
    'Ignored Range cannot retain a full segment or request another chunk',
    () async {
      var extraRequested = false;
      var cancelled = false;
      Stream<List<int>> body() async* {
        try {
          yield List<int>.filled(65536, 7);
          extraRequested = true;
          yield [8];
        } finally {
          cancelled = true;
        }
      }

      expect(await twitchReadMediaPrefix(body()), List<int>.filled(4096, 7));
      expect(extraRequested, isFalse);
      expect(cancelled, isTrue);
    },
  );
  test(
    'Bounded prefix handles short, empty and split response bodies',
    () async {
      expect(
        await twitchReadMediaPrefix(const Stream<List<int>>.empty()),
        isEmpty,
      );
      expect(
        await twitchReadMediaPrefix(
          Stream.fromIterable([
            [1, 2],
            [3],
          ]),
        ),
        [1, 2, 3],
      );
      expect(
        await twitchReadMediaPrefix(
          Stream.fromIterable([
            List<int>.filled(4000, 1),
            List<int>.filled(200, 2),
          ]),
        ),
        [...List<int>.filled(4000, 1), ...List<int>.filled(96, 2)],
      );
    },
  );
  test('Matched central regions exclude bright borders at different sizes', () {
    for (final size in [10, 20]) {
      final rgba = List<int>.filled(size * size * 4, 0);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          if (x < size * .2 ||
              x >= size * .8 ||
              y < size * .2 ||
              y >= size * .8) {
            rgba[(y * size + x) * 4] = 255;
          }
        }
      }
      expect(
        twitchFramePixelSummary(
          rgba: rgba,
          width: size,
          height: size,
        )['nonBlackFraction'],
        greaterThan(.1),
      );
      final center = twitchCentralFramePixelSummary(
        rgba: rgba,
        width: size,
        height: size,
      );
      expect(center['nonBlackFraction'], 0);
      expect(center['colors'], 1);
      expect(center['samples'], greaterThan(0));
    }
  });
  test('URL contents cannot invent failures or known error categories', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record(
      'Opened https://fixture.invalid/error/failed%20to%20open',
    );
    expect(diagnostics.snapshot, isEmpty);
    final encoded = TwitchNativeLogDiagnostics();
    encoded.record(
      'Unknown error https://fixture.invalid/failed-to-open/invalid?reason=error',
    );
    expect(encoded.snapshot, {'unclassified_failure': 1});
    final known = TwitchNativeLogDiagnostics();
    known.record(
      'Read error https://fixture.invalid/?reason=decoder-failed&audio=error',
    );
    expect(known.snapshot, {'read_failed': 1});
  });
  test(
    'Native cache properties retain only fixed numeric and boolean fields',
    () {
      final values = {
        'stream-pos': '764465',
        'cache-speed': '0',
        'demuxer-cache-state/fw-bytes': '1234',
        'demuxer-cache-state/total-bytes': '4321',
        'demuxer-cache-duration': '2.769',
        'demuxer-cache-state/underrun': 'no',
        'core-idle': 'yes',
      };
      final readNames = <String>[];
      expect(
        twitchNativePlaybackProperties((name) {
          readNames.add(name);
          return values[name] ?? (throw StateError('unavailable'));
        }),
        values,
      );
      expect(readNames, isNot(contains('path')));
      expect(readNames, isNot(contains('stream-path')));
      expect(readNames, isNot(contains('metadata')));
    },
  );
  test('Native cache properties reject text and unavailable values', () {
    final invalid = [
      'fixture-private-text',
      'https://fixture.invalid/secret',
      'NaN',
      'Infinity',
      '1\nfixture-private-text',
      '9' * 33,
    ];
    for (final value in invalid) {
      expect(twitchNativePlaybackProperties((_) => value), isEmpty);
    }
    expect(
      twitchNativePlaybackProperties((_) => throw StateError('unsupported')),
      isEmpty,
    );
  });
  test(
    'Frame summaries distinguish black from rendered pixels without exporting pixels',
    () {
      final black = List<int>.filled(4 * 4 * 4, 0);
      expect(twitchFramePixelSummary(rgba: black, width: 4, height: 4), {
        'samples': 4,
        'nonBlackFraction': 0,
        'colors': 1,
      });
      black[0] = 17;
      expect(
        twitchFramePixelSummary(
          rgba: black,
          width: 4,
          height: 4,
        )['nonBlackFraction'],
        .25,
      );
      expect(
        twitchFramePixelSummary(
          rgba: black,
          width: 4,
          height: 4,
          left: -10,
          right: 100,
          top: -10,
          bottom: 100,
        )['samples'],
        4,
      );
      expect(
        twitchFramePixelSummary(
          rgba: black,
          width: 4,
          height: 4,
          left: 4,
        )['samples'],
        0,
      );
      expect(
        () => twitchFramePixelSummary(rgba: [], width: 4, height: 4),
        throwsArgumentError,
      );
      expect(
        () => twitchFramePixelSummary(rgba: [], width: 0, height: 0),
        throwsArgumentError,
      );
    },
  );
  test('Graphics backend hints remain fixed and exclude URL contents', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record('EGL error SECRET https://fixture.invalid/d3d11-vulkan');
    expect(diagnostics.snapshot, {
      'unclassified_failure': 1,
      'unclassified_hint_gpu': 1,
      'unclassified_hint_gpu_egl': 1,
    });
  });
  test('Unclassified hints are fixed, redact URLs, and do not claim a cause', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record(
      'Failed initialization GPU device SECRET https://fixture.invalid/audio-codec.dll',
    );
    expect(diagnostics.snapshot, {
      'unclassified_failure': 1,
      'unclassified_hint_gpu': 1,
      'unclassified_hint_device': 1,
      'unclassified_hint_initialization': 1,
    });
    expect(diagnostics.snapshot.toString(), isNot(contains('SECRET')));
    expect(diagnostics.snapshot.toString(), isNot(contains('fixture.invalid')));
    diagnostics.record('GPU device initialized successfully SECRET');
    expect(diagnostics.snapshot['unclassified_failure'], 1);
  });
  test(
    'Known hardware and video output failures are not unclassified hints',
    () {
      final diagnostics = TwitchNativeLogDiagnostics();
      diagnostics.record(
        'Failed setup for format: hwaccel initialisation returned error SECRET',
      );
      diagnostics.record('Failed initializing any suitable GPU context SECRET');
      expect(diagnostics.snapshot, {
        'hardware_decode_failed': 1,
        'video_output_failed': 1,
      });
    },
  );
  test('Media hints distinguish packet sync, MP4 boxes, and unknown data', () {
    final ts = List<int>.filled(377, 0);
    ts[0] = ts[188] = ts[376] = 0x47;
    expect(twitchMediaHeaderHints(ts), {
      'tsSyncAtStart': true,
      'mp4BoxAtStart': false,
    });
    expect(twitchMediaHeaderHints([0, 0, 0, 8, ...'moof'.codeUnits]), {
      'tsSyncAtStart': false,
      'mp4BoxAtStart': true,
    });
    expect(twitchMediaHeaderHints([]).values.every((value) => !value), isTrue);
    expect(
      twitchMediaHeaderHints(
        'SECRET'.codeUnits,
      ).values.every((value) => !value),
      isTrue,
    );
  });
  test(
    'Metadata and padding boxes remain MP4 hints without exposing bytes',
    () {
      for (final box in ['emsg', 'prft', 'uuid', 'free', 'skip']) {
        expect(
          twitchMediaHeaderHints([
            0,
            0,
            0,
            8,
            ...box.codeUnits,
          ])['mp4BoxAtStart'],
          isTrue,
        );
      }
    },
  );
  test('Only fixed categories and counts survive sensitive native text', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record(
      'Failed to recognize file format: https://fixture.invalid/?token=SECRET',
    );
    diagnostics.record('Failed to open signed SECRET stream');
    diagnostics.record('UNKNOWN FAILURE SECRET');
    diagnostics.record('unclassified error SECRET');
    expect(diagnostics.snapshot, {
      'format_unrecognized': 1,
      'open_failed': 1,
      'unclassified_failure': 1,
    });
    expect(diagnostics.snapshot.toString(), isNot(contains('SECRET')));
    expect(diagnostics.snapshot.toString(), isNot(contains('https')));
  });
  test('Counts multiple categories and returns an immutable snapshot', () {
    final diagnostics = TwitchNativeLogDiagnostics();
    diagnostics.record('Failed to open: Connection refused');
    final earlier = diagnostics.snapshot;
    diagnostics.record('failed to open');
    expect(earlier['open_failed'], 1);
    expect(diagnostics.snapshot['open_failed'], 2);
    expect(diagnostics.snapshot['connection_refused'], 1);
    expect(() => earlier['extra'] = 1, throwsUnsupportedError);
  });
}
