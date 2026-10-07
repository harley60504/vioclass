import 'package:flutter/services.dart';

/// EventSub does not specify a Unicode index unit, and AutoMod has a reported
/// non-ASCII offset bug. Keep plausible interpretations instead of guessing.
class TwitchAutomodHitCandidate {
  final List<String> units;

  /// UTF-16, half-open, merged and expanded to whole grapheme clusters.
  final List<(int, int)> ranges;
  TwitchAutomodHitCandidate(List<String> units, List<(int, int)> ranges)
    : units = List.unmodifiable(units),
      ranges = List.unmodifiable(ranges);
}

class TwitchAutomodHighlight {
  final List<TwitchAutomodHitCandidate> candidates;
  const TwitchAutomodHighlight(this.candidates);
  bool get ambiguous => candidates.length > 1;
  List<(int, int)> get ranges =>
      candidates.length == 1 ? candidates.single.ranges : const [];

  static TwitchAutomodHighlight map(String text, List<(int, int)> boundaries) {
    if (text.isEmpty || boundaries.isEmpty) {
      return const TwitchAutomodHighlight([]);
    }
    final utf16 = <int, int>{0: 0};
    final scalar = <int, int>{0: 0};
    final bytes = <int, int>{0: 0};
    var offset = 0;
    var count = 0;
    var byteOffset = 0;
    for (final rune in text.runes) {
      offset += rune > 0xffff ? 2 : 1;
      count++;
      byteOffset += rune <= 0x7f
          ? 1
          : rune <= 0x7ff
          ? 2
          : rune <= 0xffff
          ? 3
          : 4;
      utf16[offset] = offset;
      scalar[count] = offset;
      bytes[byteOffset] = offset;
    }
    final graphemes = CharacterBoundary(text);
    final candidates = <TwitchAutomodHitCandidate>[];
    for (final (unit, indexes) in [
      ('UTF-16', utf16),
      ('Unicode', scalar),
      ('UTF-8', bytes),
    ]) {
      final mapped = <(int, int)>[];
      var valid = true;
      for (final (start, inclusiveEnd) in boundaries) {
        final begin = indexes[start];
        final end = indexes[inclusiveEnd + 1];
        if (start < 0 || inclusiveEnd < start || begin == null || end == null) {
          valid = false;
          break;
        }
        mapped.add((
          graphemes.getLeadingTextBoundaryAt(begin) ?? begin,
          graphemes.getTrailingTextBoundaryAt(end - 1) ?? end,
        ));
      }
      if (!valid) continue;
      mapped.sort((a, b) => a.$1.compareTo(b.$1));
      final merged = <(int, int)>[];
      for (final range in mapped) {
        if (merged.isNotEmpty && range.$1 <= merged.last.$2) {
          final last = merged.removeLast();
          merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
        } else {
          merged.add(range);
        }
      }
      var equivalent = -1;
      for (var i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        var same = candidate.ranges.length == merged.length;
        for (var j = 0; same && j < merged.length; j++) {
          same = candidate.ranges[j] == merged[j];
        }
        if (same) {
          equivalent = i;
          break;
        }
      }
      if (equivalent >= 0) {
        candidates[equivalent] = TwitchAutomodHitCandidate([
          ...candidates[equivalent].units,
          unit,
        ], merged);
      } else {
        candidates.add(
          TwitchAutomodHitCandidate([unit], List.unmodifiable(merged)),
        );
      }
    }
    return TwitchAutomodHighlight(List.unmodifiable(candidates));
  }
}
