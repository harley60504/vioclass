import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/models/discovery/twitch_live_stream.dart';

void main() {
  for (final type in [
    'archive',
    ' ARCHIVE ',
    'highlight',
    'upload',
    '',
    'unknown',
  ]) {
    test('Recent video is only a growing candidate for archive type=$type', () {
      final video = TwitchChannelVideo.fromHelixJson({
        'type': type,
        'created_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 10))
            .toIso8601String(),
        'duration': '10m',
      });
      expect(
        video.isLikelyGrowingArchive,
        type.trim().toLowerCase() == 'archive',
      );
    });
  }
  for (final age in [-6, 0, 10, 21]) {
    test('Archive retains existing estimated-end window ageMinutes=$age', () {
      final video = TwitchChannelVideo.fromHelixJson({
        'type': 'archive',
        'created_at': DateTime.now()
            .toUtc()
            .subtract(Duration(minutes: age + 10))
            .toIso8601String(),
        'duration': '10m',
      });
      expect(video.isLikelyGrowingArchive, age == 0 || age == 10);
    });
  }
  test('Archive published timestamp fallback remains usable', () {
    final video = TwitchChannelVideo.fromHelixJson({
      'type': 'archive',
      'published_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
      'duration': '10m',
    });
    expect(video.isLikelyGrowingArchive, isTrue);
  });
  test('Missing archive timestamp or duration is not a growing candidate', () {
    expect(
      TwitchChannelVideo.fromHelixJson({
        'type': 'archive',
        'duration': '10m',
      }).isLikelyGrowingArchive,
      isFalse,
    );
    expect(
      TwitchChannelVideo.fromHelixJson({
        'type': 'archive',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).isLikelyGrowingArchive,
      isFalse,
    );
  });
}
