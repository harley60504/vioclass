import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_hls_proxy_models.dart';
import 'package:vioclass/features/twitch/models/playback/twitch_segment_timeline_index.dart';

TwitchHlsSegmentItem _segment({
  required int sequence,
  required Duration duration,
  DateTime? programDateTime,
}) {
  return TwitchHlsSegmentItem(
    url: 'https://example.test/$sequence.ts',
    mapUrl: null,
    label: 'segment-$sequence',
    sequence: sequence,
    duration: duration,
    programDateTime: programDateTime,
  );
}

void main() {
  group('TwitchSegmentTimelineIndex', () {
    test('maps segments onto a non-zero canonical stream position', () {
      final index = TwitchSegmentTimelineIndex.fromSegments(
        <TwitchHlsSegmentItem>[
          _segment(sequence: 100, duration: const Duration(seconds: 2)),
          _segment(sequence: 101, duration: const Duration(milliseconds: 2500)),
          _segment(sequence: 102, duration: const Duration(milliseconds: 1500)),
        ],
        canonicalStart: const Duration(seconds: 120),
      );

      expect(index.canonicalStart, const Duration(seconds: 120));
      expect(index.canonicalEnd, const Duration(seconds: 126));
      expect(index.indexedDuration, const Duration(seconds: 6));
      expect(index.entries[0].canonicalStart, const Duration(seconds: 120));
      expect(index.entries[1].canonicalStart, const Duration(seconds: 122));
      expect(
        index.entries[2].canonicalStart,
        const Duration(milliseconds: 124500),
      );
    });

    test('an exact segment boundary resolves to the next segment', () {
      final index = TwitchSegmentTimelineIndex.fromSegments(
        <TwitchHlsSegmentItem>[
          _segment(sequence: 10, duration: const Duration(seconds: 2)),
          _segment(sequence: 11, duration: const Duration(seconds: 2)),
        ],
      );

      final seek = index.resolveCanonical(const Duration(seconds: 2));

      expect(seek, isNotNull);
      expect(seek!.sequence, 11);
      expect(seek.offset, Duration.zero);
    });

    test('resolves sub-segment canonical offsets without second quantization', () {
      final index = TwitchSegmentTimelineIndex.fromSegments(
        <TwitchHlsSegmentItem>[
          _segment(sequence: 20, duration: const Duration(seconds: 2)),
          _segment(sequence: 21, duration: const Duration(seconds: 2)),
          _segment(sequence: 22, duration: const Duration(seconds: 2)),
        ],
        canonicalStart: const Duration(seconds: 100),
      );

      final seek = index.resolveCanonical(
        const Duration(microseconds: 103427000),
      );

      expect(seek, isNotNull);
      expect(seek!.sequence, 21);
      expect(seek.offset, const Duration(microseconds: 1427000));
      expect(
        seek.canonicalPosition,
        const Duration(microseconds: 103427000),
      );
    });

    test('resolves PROGRAM-DATE-TIME to the same canonical media clock', () {
      final origin = DateTime.utc(2026, 9, 10, 12, 0, 0);
      final index = TwitchSegmentTimelineIndex.fromSegments(
        <TwitchHlsSegmentItem>[
          _segment(
            sequence: 30,
            duration: const Duration(seconds: 2),
            programDateTime: origin.add(const Duration(seconds: 50)),
          ),
          _segment(
            sequence: 31,
            duration: const Duration(seconds: 2),
            programDateTime: origin.add(const Duration(seconds: 52)),
          ),
        ],
        canonicalStart: const Duration(seconds: 50),
        timelineOrigin: origin,
      );

      final target = origin.add(const Duration(milliseconds: 53250));
      final seek = index.resolveProgramDateTime(target);

      expect(seek, isNotNull);
      expect(seek!.sequence, 31);
      expect(seek.offset, const Duration(milliseconds: 1250));
      expect(seek.canonicalPosition, const Duration(milliseconds: 53250));
      expect(index.canonicalPositionForProgramDateTime(target),
          const Duration(milliseconds: 53250));
    });

    test('computes preroll duration from indexed media ranges', () {
      final index = TwitchSegmentTimelineIndex.fromSegments(
        <TwitchHlsSegmentItem>[
          _segment(sequence: 40, duration: const Duration(seconds: 10)),
          _segment(sequence: 41, duration: const Duration(seconds: 12)),
          _segment(sequence: 42, duration: const Duration(seconds: 8)),
          _segment(sequence: 43, duration: const Duration(seconds: 9)),
        ],
      );

      expect(index.durationBeforeIndex(2), const Duration(seconds: 22));
      expect(index.durationBetweenIndexes(1, 3), const Duration(seconds: 20));
    });
  });
}
