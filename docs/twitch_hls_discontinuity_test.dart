import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/parsers/playback/twitch_hls_playlist_parser.dart';

void main() {
  List<int> epochs(String text) => TwitchHlsPlaylistParser.parse(
    text,
    playlistUrl: 'https://fixture.invalid/live.m3u8',
  ).items.map((item) => item.discontinuitySequence).toList();

  test('Discontinuity identity survives playlist window removal', () {
    expect(
      epochs(
        '#EXTM3U\n#EXT-X-DISCONTINUITY-SEQUENCE:7\n'
        '#EXTINF:2,\na.m4s\n#EXT-X-DISCONTINUITY\n#EXTINF:2,\nb.m4s\n',
      ),
      [7, 8],
    );
    expect(
      epochs(
        '#EXTM3U\n#EXT-X-MEDIA-SEQUENCE:1\n'
        '#EXT-X-DISCONTINUITY-SEQUENCE:8\n#EXTINF:2,\nb.m4s\n',
      ),
      [8],
    );
  });
  test('All future segment styles retain discontinuity identity', () {
    expect(
      epochs(
        '#EXTM3U\n#EXT-X-DISCONTINUITY\n'
        '#EXTINF:2,\na.m4s\n#EXT-X-TWITCH-PREFETCH:b.m4s\n'
        '#EXT-X-PREFETCH:c.m4s\n#EXT-X-PRELOAD-HINT:TYPE=SEGMENT,URI="d.m4s"\n',
      ),
      [1, 1, 1, 1],
    );
  });
  test('Ordinary media remains in the default discontinuity identity', () {
    expect(epochs('#EXTM3U\n#EXTINF:2,\na.ts\n#EXTINF:2,\nb.ts\n'), [0, 0]);
  });
}
