/// Normalize only this public fixture's legacy fragment addressing flags.
/// Trun offsets are already moof-relative; never modify production media.
List<int> twitchMoofRelativeFixture(List<int> input) {
  final result = input.toList();
  var changes = 0;
  void visit(int start, int end) {
    var cursor = start;
    while (cursor < end) {
      if (cursor + 8 > end) throw StateError('Incomplete fixture box');
      final size =
          (input[cursor] << 24) |
          (input[cursor + 1] << 16) |
          (input[cursor + 2] << 8) |
          input[cursor + 3];
      if (size < 8 || cursor + size > end) {
        throw StateError('Invalid fixture box size');
      }
      final type = String.fromCharCodes(input.sublist(cursor + 4, cursor + 8));
      if (type == 'moof' || type == 'traf') {
        visit(cursor + 8, cursor + size);
      } else if (type == 'tfhd') {
        if (size < 16 || (input[cursor + 11] & 1) != 0) {
          throw StateError('Fixture uses unsupported absolute addressing');
        }
        result[cursor + 9] |= 2;
        changes++;
      }
      cursor += size;
    }
  }

  visit(0, input.length);
  if (changes == 0) throw StateError('Missing fixture track fragment header');
  return result;
}

/// Test-only ISO BMFF fixture timestamps; never modifies production media.
List<int> twitchShiftFixtureFragment({
  required List<int> initialization,
  required List<int> fragment,
  required int seconds,
}) {
  int read(List<int> bytes, int offset, int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      value = (value << 8) | bytes[offset + i];
    }
    return value;
  }

  List<(String, int, int)> boxes(List<int> bytes, int start, int end) {
    final result = <(String, int, int)>[];
    var offset = start;
    while (offset < end) {
      if (offset + 8 > end) throw StateError('Incomplete fixture box.');
      final size = read(bytes, offset, 4);
      if (size < 8 || offset + size > end) {
        throw StateError('Unsupported fixture box size.');
      }
      result.add((
        String.fromCharCodes(bytes.skip(offset + 4).take(4)),
        offset,
        size,
      ));
      offset += size;
    }
    return result;
  }

  List<(String, int, int)> children(List<int> bytes, (String, int, int) box) =>
      boxes(bytes, box.$2 + 8, box.$2 + box.$3);
  final scales = <int, int>{};
  for (final movie in boxes(
    initialization,
    0,
    initialization.length,
  ).where((box) => box.$1 == 'moov')) {
    for (final track in children(
      initialization,
      movie,
    ).where((box) => box.$1 == 'trak')) {
      final fields = children(initialization, track);
      final header = fields.singleWhere((box) => box.$1 == 'tkhd');
      final trackId = read(
        initialization,
        header.$2 + (initialization[header.$2 + 8] == 1 ? 28 : 20),
        4,
      );
      final media = fields.singleWhere((box) => box.$1 == 'mdia');
      final mediaHeader = children(
        initialization,
        media,
      ).singleWhere((box) => box.$1 == 'mdhd');
      final scale = read(
        initialization,
        mediaHeader.$2 + (initialization[mediaHeader.$2 + 8] == 1 ? 28 : 20),
        4,
      );
      if (scale <= 0) throw StateError('Invalid fixture timescale.');
      scales[trackId] = scale;
    }
  }
  final shifted = fragment.toList();
  var changes = 0;
  for (final movie in boxes(
    fragment,
    0,
    fragment.length,
  ).where((box) => box.$1 == 'moof')) {
    for (final track in children(
      fragment,
      movie,
    ).where((box) => box.$1 == 'traf')) {
      final fields = children(fragment, track);
      final header = fields.singleWhere((box) => box.$1 == 'tfhd');
      final trackId = read(fragment, header.$2 + 12, 4);
      final decodeTime = fields.singleWhere((box) => box.$1 == 'tfdt');
      final width = fragment[decodeTime.$2 + 8] == 1 ? 8 : 4;
      final offset = decodeTime.$2 + 12;
      final scale = scales[trackId];
      if (scale == null) throw StateError('Missing fixture track.');
      var value = read(fragment, offset, width) + seconds * scale;
      if (value < 0 || (width == 4 && value > 0xffffffff)) {
        throw StateError('Fixture timestamp overflow.');
      }
      for (var i = width - 1; i >= 0; i--) {
        shifted[offset + i] = value & 255;
        value >>= 8;
      }
      changes++;
    }
  }
  if (changes == 0) throw StateError('No fixture decode timestamps.');
  return shifted;
}
