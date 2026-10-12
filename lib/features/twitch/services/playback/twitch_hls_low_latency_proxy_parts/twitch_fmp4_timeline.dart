part of '../twitch_hls_low_latency_proxy.dart';

// Only decode-time metadata is rewritten. Sample bytes and box sizes stay
// unchanged; incomplete/oversized metadata fails instead of fabricating media.
class TwitchFmp4Timeline {
  Map<int, int> _scales = {};
  (BigInt, int)? _origin;
  (BigInt, BigInt)? _epochShift;
  int? _epoch;
  bool get hasTrackTimescales => _scales.isNotEmpty;

  void setInitialization(List<int> bytes) {
    final scales = <int, int>{};
    for (final movie in _fmp4Boxes(bytes, 0, bytes.length)) {
      if (movie.type != 'moov') continue;
      for (final track in _fmp4Boxes(bytes, movie.body, movie.end)) {
        if (track.type != 'trak') continue;
        int? id;
        int? scale;
        for (final field in _fmp4Boxes(bytes, track.body, track.end)) {
          if (field.type == 'tkhd') {
            id = _fmp4Read(
              bytes,
              field.body +
                  (_fmp4Version(bytes, field.body, field.end) == 1 ? 20 : 12),
              4,
              field.end,
            ).toInt();
          } else if (field.type == 'mdia') {
            for (final media in _fmp4Boxes(bytes, field.body, field.end)) {
              if (media.type == 'mdhd') {
                scale = _fmp4Read(
                  bytes,
                  media.body +
                      (_fmp4Version(bytes, media.body, media.end) == 1
                          ? 20
                          : 12),
                  4,
                  media.end,
                ).toInt();
              }
            }
          }
        }
        if (id != null && scale != null && scale > 0) scales[id] = scale;
      }
    }
    _scales = scales;
  }

  TwitchHlsByteSink segmentSink(
    TwitchHlsByteSink output, {
    required int epoch,
    required Duration writtenDuration,
  }) {
    final boundary = _epoch != null && _epoch != epoch;
    _epoch = epoch;
    if (boundary) _epochShift = null;
    return _Fmp4TimelineSink(output, this, boundary, writtenDuration);
  }

  void _rewrite(List<int> bytes, bool boundary, Duration duration) {
    final times = <({BigInt value, int scale, int offset, int width})>[];
    for (final movie in _fmp4Boxes(bytes, 0, bytes.length)) {
      if (movie.type != 'moof') continue;
      for (final track in _fmp4Boxes(bytes, movie.body, movie.end)) {
        if (track.type != 'traf') continue;
        final fields = _fmp4Boxes(bytes, track.body, track.end).toList();
        final header = fields.where((field) => field.type == 'tfhd').single;
        final id = _fmp4Read(bytes, header.body + 4, 4, header.end).toInt();
        final scale = _scales[id];
        if (scale == null)
          throw const FormatException('Unknown fMP4 track timescale');
        final time = fields.where((field) => field.type == 'tfdt').single;
        final version = _fmp4Version(bytes, time.body, time.end);
        final width = version == 1 ? 8 : 4;
        final value = _fmp4Read(bytes, time.body + 4, width, time.end);
        times.add((
          value: value,
          scale: scale,
          offset: time.body + 4,
          width: width,
        ));
      }
    }
    if (times.isEmpty) throw const FormatException('Missing fMP4 decode times');
    final anchor = times.reduce(
      (a, b) => a.value * BigInt.from(b.scale) <= b.value * BigInt.from(a.scale)
          ? a
          : b,
    );
    _origin ??= (anchor.value, anchor.scale);
    if (boundary && _epochShift == null) {
      final origin = _origin!;
      final oldScale = BigInt.from(origin.$2);
      final newScale = BigInt.from(anchor.scale);
      final million = BigInt.from(1000000);
      // One wall-time shift for every track preserves the new A/V skew.
      _epochShift = (
        origin.$1 * newScale * million +
            BigInt.from(duration.inMicroseconds) * oldScale * newScale -
            anchor.value * oldScale * million,
        oldScale * newScale * million,
      );
    }
    final shift = _epochShift;
    if (shift == null) return;
    for (final time in times) {
      final numerator = shift.$1 * BigInt.from(time.scale);
      // Round to the nearest track tick without floating point precision loss.
      final offset = numerator.isNegative
          ? -((-numerator + shift.$2 ~/ BigInt.two) ~/ shift.$2)
          : (numerator + shift.$2 ~/ BigInt.two) ~/ shift.$2;
      var shifted = time.value + offset;
      if (shifted < BigInt.zero ||
          shifted >= (BigInt.one << (time.width * 8))) {
        throw const FormatException('fMP4 decode time overflow');
      }
      for (var i = time.width - 1; i >= 0; i--) {
        bytes[time.offset + i] = (shifted & BigInt.from(255)).toInt();
        shifted >>= 8;
      }
    }
  }
}

int _fmp4Version(List<int> bytes, int body, int end) {
  final version = _fmp4Read(bytes, body, 4, end) >> 24;
  if (version != BigInt.zero && version != BigInt.one) {
    throw const FormatException('Unsupported fMP4 full box version');
  }
  return version.toInt();
}

BigInt _fmp4Read(List<int> bytes, int offset, int width, int end) {
  if (offset < 0 || offset + width > end)
    throw const FormatException('Incomplete fMP4 field');
  var value = BigInt.zero;
  for (var i = 0; i < width; i++) {
    value = (value << 8) | BigInt.from(bytes[offset + i]);
  }
  return value;
}

Iterable<({String type, int body, int end})> _fmp4Boxes(
  List<int> bytes,
  int start,
  int end,
) sync* {
  var cursor = start;
  while (cursor < end) {
    var size = _fmp4Read(bytes, cursor, 4, end).toInt();
    if (cursor + 8 > end) throw const FormatException('Incomplete fMP4 box');
    final type = String.fromCharCodes(bytes.sublist(cursor + 4, cursor + 8));
    var header = 8;
    if (size == 1) {
      size = _fmp4Read(bytes, cursor + 8, 8, end).toInt();
      header = 16;
    } else if (size == 0) {
      size = end - cursor;
    }
    if (size < header || cursor + size > end)
      throw const FormatException('Invalid fMP4 box length');
    yield (type: type, body: cursor + header, end: cursor + size);
    cursor += size;
  }
}

class _Fmp4TimelineSink implements TwitchHlsByteSink {
  _Fmp4TimelineSink(this.output, this.timeline, this.boundary, this.duration);
  final TwitchHlsByteSink output;
  final TwitchFmp4Timeline timeline;
  final bool boundary;
  final Duration duration;
  final List<int> _pending = [];
  int _opaqueRemaining = 0;
  bool _opaqueToEnd = false;
  @override
  int get bufferedBytes => output.bufferedBytes;
  @override
  void close() => output.close();

  Future<void> _emit(List<int> bytes) => output.addStream(Stream.value(bytes));
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _pending.addAll(chunk);
      while (_pending.isNotEmpty) {
        if (_opaqueToEnd || _opaqueRemaining > 0) {
          final count = _opaqueToEnd
              ? _pending.length
              : math.min(_pending.length, _opaqueRemaining);
          final data = _pending.sublist(0, count);
          _pending.removeRange(0, count);
          if (!_opaqueToEnd) _opaqueRemaining -= count;
          await _emit(data);
          continue;
        }
        if (_pending.length < 8) break;
        var size = _fmp4Read(_pending, 0, 4, _pending.length).toInt();
        var header = 8;
        if (size == 1) {
          if (_pending.length < 16) break;
          header = 16;
          size = _fmp4Read(_pending, 8, 8, _pending.length).toInt();
        }
        final type = String.fromCharCodes(_pending.sublist(4, 8));
        if (type == 'moof') {
          if (size < header || size > 1024 * 1024)
            throw const FormatException(
              'Unsupported fMP4 fragment header size',
            );
          if (_pending.length < size) break;
          final metadata = _pending.sublist(0, size);
          _pending.removeRange(0, size);
          timeline._rewrite(metadata, boundary, duration);
          await _emit(metadata);
        } else {
          if (size != 0 && size < header)
            throw const FormatException('Invalid fMP4 media box');
          final bytes = _pending.sublist(0, header);
          _pending.removeRange(0, header);
          _opaqueToEnd = size == 0;
          _opaqueRemaining = size == 0 ? 0 : size - header;
          await _emit(bytes);
        }
      }
    }
  }

  void finish() {
    if (_pending.isNotEmpty || _opaqueRemaining != 0)
      throw const FormatException('Incomplete fMP4 media segment');
  }
}
