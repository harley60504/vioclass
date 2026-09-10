import 'dart:typed_data';

/// Minimal MPEG-TS timing/keyframe metadata used by the Twitch DVR seek path.
///
/// This parser is intentionally read-only: it never rewrites transport-stream
/// packets. It extracts PAT/PMT, PCR, video PTS and H.264/H.265 random-access
/// points so the HLS timeline can be cross-checked against the media clock.
class TwitchTsTimingInfo {
  static const int ptsClockHz = 90000;
  static const int pcrClockHz = 27000000;
  static const int _ptsModulo = 1 << 33;

  final int packetCount;
  final int? pmtPid;
  final int? videoPid;
  final int? pcrPid;
  final int? videoStreamType;
  final int? firstPts90k;
  final int? lastPts90k;
  final int? firstPcr27m;
  final int? lastPcr27m;
  final List<int> keyframePts90k;

  const TwitchTsTimingInfo({
    required this.packetCount,
    required this.pmtPid,
    required this.videoPid,
    required this.pcrPid,
    required this.videoStreamType,
    required this.firstPts90k,
    required this.lastPts90k,
    required this.firstPcr27m,
    required this.lastPcr27m,
    required this.keyframePts90k,
  });

  bool get isH264 => videoStreamType == 0x1b;
  bool get isH265 => videoStreamType == 0x24;
  bool get hasMediaClock => firstPts90k != null || firstPcr27m != null;
  bool get hasKeyframes => keyframePts90k.isNotEmpty;

  Duration? get ptsSpan {
    final first = firstPts90k;
    final last = lastPts90k;
    if (first == null || last == null) return null;
    return _ticksToDuration(_forwardPtsDelta(first, last), ptsClockHz);
  }

  Duration? get pcrSpan {
    final first = firstPcr27m;
    final last = lastPcr27m;
    if (first == null || last == null) return null;
    final delta = last >= first ? last - first : null;
    if (delta == null) return null;
    return _ticksToDuration(delta, pcrClockHz);
  }

  /// Returns the latest parsed random-access point not after [targetOffset],
  /// expressed relative to this segment's first video PTS.
  Duration? keyframeOffsetAtOrBefore(Duration targetOffset) {
    final first = firstPts90k;
    if (first == null || keyframePts90k.isEmpty) return null;
    final targetTicks = ((targetOffset.inMicroseconds * ptsClockHz) /
            Duration.microsecondsPerSecond)
        .round();
    int? bestTicks;
    for (final pts in keyframePts90k) {
      final delta = _forwardPtsDelta(first, pts);
      if (delta <= targetTicks && (bestTicks == null || delta > bestTicks)) {
        bestTicks = delta;
      }
    }
    if (bestTicks == null) return null;
    return _ticksToDuration(bestTicks, ptsClockHz);
  }

  static int _forwardPtsDelta(int start, int end) {
    final raw = end - start;
    return raw >= 0 ? raw : raw + _ptsModulo;
  }

  static Duration _ticksToDuration(int ticks, int clockHz) {
    return Duration(
      microseconds:
          ((ticks * Duration.microsecondsPerSecond) / clockHz).round(),
    );
  }
}

class TwitchTsTimingParser {
  const TwitchTsTimingParser._();

  static const int _packetSize = 188;

  static TwitchTsTimingInfo parse(List<int> input) {
    final bytes = input is Uint8List ? input : Uint8List.fromList(input);
    final syncOffset = _findSyncOffset(bytes);
    if (syncOffset < 0) {
      return const TwitchTsTimingInfo(
        packetCount: 0,
        pmtPid: null,
        videoPid: null,
        pcrPid: null,
        videoStreamType: null,
        firstPts90k: null,
        lastPts90k: null,
        firstPcr27m: null,
        lastPcr27m: null,
        keyframePts90k: <int>[],
      );
    }

    int? pmtPid;
    int? videoPid;
    int? pcrPid;
    int? videoStreamType;
    int? firstPts;
    int? lastPts;
    int? currentVideoPesPts;
    int? firstPcr;
    int? lastPcr;
    final keyframes = <int>[];
    var packetCount = 0;
    var nalCarry = <int>[];

    for (var packetStart = syncOffset;
        packetStart + _packetSize <= bytes.length;
        packetStart += _packetSize) {
      if (bytes[packetStart] != 0x47) continue;
      packetCount++;

      final b1 = bytes[packetStart + 1];
      final b2 = bytes[packetStart + 2];
      final b3 = bytes[packetStart + 3];
      final payloadUnitStart = (b1 & 0x40) != 0;
      final pid = ((b1 & 0x1f) << 8) | b2;
      final adaptationControl = (b3 >> 4) & 0x03;
      final hasAdaptation = adaptationControl == 2 || adaptationControl == 3;
      final hasPayload = adaptationControl == 1 || adaptationControl == 3;

      var cursor = packetStart + 4;
      final packetEnd = packetStart + _packetSize;

      if (hasAdaptation && cursor < packetEnd) {
        final adaptationLength = bytes[cursor];
        if (adaptationLength > 0 &&
            cursor + adaptationLength < packetEnd &&
            cursor + 7 < packetEnd) {
          final flags = bytes[cursor + 1];
          if ((flags & 0x10) != 0 && adaptationLength >= 7) {
            final pcr = _readPcr27m(bytes, cursor + 2);
            firstPcr ??= pcr;
            lastPcr = pcr;
          }
        }
        cursor += adaptationLength + 1;
      }

      if (!hasPayload || cursor >= packetEnd) continue;

      if (pid == 0 && payloadUnitStart) {
        final section = _psiSectionStart(bytes, cursor, packetEnd);
        if (section != null) {
          pmtPid ??= _parsePatForPmtPid(bytes, section, packetEnd);
        }
        continue;
      }

      if (pmtPid != null && pid == pmtPid && payloadUnitStart) {
        final section = _psiSectionStart(bytes, cursor, packetEnd);
        if (section != null) {
          final pmt = _parsePmt(bytes, section, packetEnd);
          if (pmt != null) {
            pcrPid = pmt.pcrPid;
            videoPid = pmt.videoPid;
            videoStreamType = pmt.videoStreamType;
          }
        }
        continue;
      }

      if (videoPid == null || pid != videoPid) continue;

      var elementaryStart = cursor;
      if (payloadUnitStart && cursor + 9 <= packetEnd) {
        final pes = _parsePesHeader(bytes, cursor, packetEnd);
        if (pes != null) {
          currentVideoPesPts = pes.pts90k;
          if (pes.pts90k != null) {
            firstPts ??= pes.pts90k;
            lastPts = pes.pts90k;
          }
          elementaryStart = pes.payloadStart;
          nalCarry = <int>[];
        }
      }

      if (elementaryStart >= packetEnd || currentVideoPesPts == null) continue;
      final payload = bytes.sublist(elementaryStart, packetEnd);
      final scan = <int>[...nalCarry, ...payload];
      if (_containsRandomAccessNal(scan, videoStreamType)) {
        if (keyframes.isEmpty || keyframes.last != currentVideoPesPts) {
          keyframes.add(currentVideoPesPts!);
        }
      }
      nalCarry = scan.length <= 4
          ? List<int>.from(scan)
          : scan.sublist(scan.length - 4);
    }

    return TwitchTsTimingInfo(
      packetCount: packetCount,
      pmtPid: pmtPid,
      videoPid: videoPid,
      pcrPid: pcrPid,
      videoStreamType: videoStreamType,
      firstPts90k: firstPts,
      lastPts90k: lastPts,
      firstPcr27m: firstPcr,
      lastPcr27m: lastPcr,
      keyframePts90k: List<int>.unmodifiable(keyframes),
    );
  }

  static int _findSyncOffset(Uint8List bytes) {
    final searchLimit = bytes.length < _packetSize * 5
        ? bytes.length
        : _packetSize * 5;
    for (var i = 0; i < searchLimit; i++) {
      if (bytes[i] != 0x47) continue;
      var matches = 1;
      for (var n = 1; n < 3; n++) {
        final next = i + n * _packetSize;
        if (next >= bytes.length) break;
        if (bytes[next] == 0x47) matches++;
      }
      if (matches >= 2 || i + _packetSize >= bytes.length) return i;
    }
    return -1;
  }

  static int? _psiSectionStart(Uint8List bytes, int payload, int end) {
    if (payload >= end) return null;
    final pointer = bytes[payload];
    final start = payload + 1 + pointer;
    return start < end ? start : null;
  }

  static int? _parsePatForPmtPid(Uint8List bytes, int start, int end) {
    if (start + 8 > end || bytes[start] != 0x00) return null;
    final sectionLength = ((bytes[start + 1] & 0x0f) << 8) | bytes[start + 2];
    final sectionEnd = (start + 3 + sectionLength).clamp(start, end).toInt();
    var cursor = start + 8;
    final programsEnd = sectionEnd - 4;
    while (cursor + 4 <= programsEnd) {
      final programNumber = (bytes[cursor] << 8) | bytes[cursor + 1];
      final pid = ((bytes[cursor + 2] & 0x1f) << 8) | bytes[cursor + 3];
      if (programNumber != 0) return pid;
      cursor += 4;
    }
    return null;
  }

  static ({int pcrPid, int? videoPid, int? videoStreamType})? _parsePmt(
    Uint8List bytes,
    int start,
    int end,
  ) {
    if (start + 12 > end || bytes[start] != 0x02) return null;
    final sectionLength = ((bytes[start + 1] & 0x0f) << 8) | bytes[start + 2];
    final sectionEnd = (start + 3 + sectionLength).clamp(start, end).toInt();
    if (start + 12 > sectionEnd) return null;
    final pcrPid = ((bytes[start + 8] & 0x1f) << 8) | bytes[start + 9];
    final programInfoLength =
        ((bytes[start + 10] & 0x0f) << 8) | bytes[start + 11];
    var cursor = start + 12 + programInfoLength;
    final streamsEnd = sectionEnd - 4;
    int? selectedPid;
    int? selectedType;

    while (cursor + 5 <= streamsEnd) {
      final streamType = bytes[cursor];
      final elementaryPid =
          ((bytes[cursor + 1] & 0x1f) << 8) | bytes[cursor + 2];
      final esInfoLength =
          ((bytes[cursor + 3] & 0x0f) << 8) | bytes[cursor + 4];
      if (selectedPid == null && (streamType == 0x1b || streamType == 0x24)) {
        selectedPid = elementaryPid;
        selectedType = streamType;
      }
      cursor += 5 + esInfoLength;
    }

    return (
      pcrPid: pcrPid,
      videoPid: selectedPid,
      videoStreamType: selectedType,
    );
  }

  static ({int? pts90k, int payloadStart})? _parsePesHeader(
    Uint8List bytes,
    int start,
    int end,
  ) {
    if (start + 9 > end ||
        bytes[start] != 0x00 ||
        bytes[start + 1] != 0x00 ||
        bytes[start + 2] != 0x01) {
      return null;
    }
    final flags = bytes[start + 7];
    final headerLength = bytes[start + 8];
    int? pts;
    final ptsDtsFlags = (flags >> 6) & 0x03;
    if ((ptsDtsFlags == 2 || ptsDtsFlags == 3) && start + 14 <= end) {
      pts = _readPts90k(bytes, start + 9);
    }
    final payloadStart = (start + 9 + headerLength).clamp(start, end).toInt();
    return (pts90k: pts, payloadStart: payloadStart);
  }

  static int _readPts90k(Uint8List b, int o) {
    return ((b[o] & 0x0e) << 29) |
        (b[o + 1] << 22) |
        ((b[o + 2] & 0xfe) << 14) |
        (b[o + 3] << 7) |
        ((b[o + 4] & 0xfe) >> 1);
  }

  static int _readPcr27m(Uint8List b, int o) {
    final base = (b[o] << 25) |
        (b[o + 1] << 17) |
        (b[o + 2] << 9) |
        (b[o + 3] << 1) |
        ((b[o + 4] & 0x80) >> 7);
    final extension = ((b[o + 4] & 0x01) << 8) | b[o + 5];
    return base * 300 + extension;
  }

  static bool _containsRandomAccessNal(List<int> bytes, int? streamType) {
    if (streamType != 0x1b && streamType != 0x24) return false;
    for (var i = 0; i + 4 < bytes.length; i++) {
      var nalIndex = -1;
      if (bytes[i] == 0 && bytes[i + 1] == 0 && bytes[i + 2] == 1) {
        nalIndex = i + 3;
      } else if (i + 4 < bytes.length &&
          bytes[i] == 0 &&
          bytes[i + 1] == 0 &&
          bytes[i + 2] == 0 &&
          bytes[i + 3] == 1) {
        nalIndex = i + 4;
      }
      if (nalIndex < 0 || nalIndex >= bytes.length) continue;
      final header = bytes[nalIndex];
      if (streamType == 0x1b) {
        if ((header & 0x1f) == 5) return true;
      } else {
        final nalType = (header >> 1) & 0x3f;
        if (nalType == 19 || nalType == 20 || nalType == 21) return true;
      }
    }
    return false;
  }
}
