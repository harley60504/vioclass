import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'twitch_fragment_timestamp_fixture.dart';

void main() {
  test(
    'Public fragment addressing changes only default-base-is-moof bits',
    () async {
      final input = await File('docs/twitch-decoder-fixture.mp4').readAsBytes();
      final original = input.toList();
      final corrected = twitchMoofRelativeFixture(input);
      expect(corrected.length, input.length);
      var changes = 0;
      for (var i = 0; i < input.length; i++) {
        if (corrected[i] == input[i]) continue;
        expect(corrected[i], input[i] | 2);
        expect(String.fromCharCodes(input.sublist(i - 5, i - 1)), 'tfhd');
        changes++;
      }
      expect(changes, greaterThan(1));
      expect(input, original);
      expect(twitchMoofRelativeFixture(corrected), corrected);
    },
  );
  test(
    'Public fMP4 fixture shifts timestamps without modifying its bytes',
    () async {
      final bytes = await File('docs/twitch-decoder-fixture.mp4').readAsBytes();
      var offset = 0;
      while (String.fromCharCodes(bytes.skip(offset + 4).take(4)) != 'moof') {
        final size =
            (bytes[offset] << 24) |
            (bytes[offset + 1] << 16) |
            (bytes[offset + 2] << 8) |
            bytes[offset + 3];
        expect(size, greaterThanOrEqualTo(8));
        offset += size;
      }
      final initialization = bytes.sublist(0, offset);
      final fragment = bytes.sublist(offset);
      final original = fragment.toList();
      final unchanged = twitchShiftFixtureFragment(
        initialization: initialization,
        fragment: fragment,
        seconds: 0,
      );
      final shifted = twitchShiftFixtureFragment(
        initialization: initialization,
        fragment: fragment,
        seconds: 3,
      );
      expect(unchanged, original);
      expect(shifted.length, original.length);
      expect(shifted, isNot(original));
      expect(fragment, original);
      expect(
        twitchShiftFixtureFragment(
          initialization: initialization,
          fragment: shifted,
          seconds: -3,
        ),
        original,
      );
    },
  );
}
