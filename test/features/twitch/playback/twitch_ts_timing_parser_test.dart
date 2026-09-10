import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vioclass/features/twitch/parsers/playback/twitch_ts_timing_parser.dart';

void main() {
  test('parses PAT PMT PTS PCR and H264 IDR keyframes', () {
    const pmtPid = 0x0100;
    const videoPid = 0x0101;
    const firstPts = 900000; // 10 s on the 90 kHz clock.
    const secondPts = 1080000; // 12 s.

    final bytes = Uint8List.fromList(<int>[
      ..._packet(pid: 0, payloadUnitStart: true, payload: _pat(pmtPid)),
      ..._packet(
        pid: pmtPid,
        payloadUnitStart: true,
        payload: _pmt(videoPid),
      ),
      ..._packet(
        pid: videoPid,
        payloadUnitStart: true,
        pcr27m: firstPts * 300,
        payload: _videoPes(firstPts, idr: true),
      ),
      ..._packet(
        pid: videoPid,
        payloadUnitStart: true,
        pcr27m: secondPts * 300,
        payload: _videoPes(secondPts, idr: true),
      ),
    ]);

    final timing = TwitchTsTimingParser.parse(bytes);

    expect(timing.packetCount, 4);
    expect(timing.pmtPid, pmtPid);
    expect(timing.videoPid, videoPid);
    expect(timing.pcrPid, videoPid);
    expect(timing.isH264, isTrue);
    expect(timing.firstPts90k, firstPts);
    expect(timing.lastPts90k, secondPts);
    expect(timing.keyframePts90k, <int>[firstPts, secondPts]);
    expect(timing.ptsSpan, const Duration(seconds: 2));
    expect(timing.pcrSpan, const Duration(seconds: 2));
    expect(
      timing.keyframeOffsetAtOrBefore(const Duration(milliseconds: 1500)),
      Duration.zero,
    );
    expect(
      timing.keyframeOffsetAtOrBefore(const Duration(milliseconds: 2500)),
      const Duration(seconds: 2),
    );
  });

  test('returns empty timing for non TS input', () {
    final timing = TwitchTsTimingParser.parse(<int>[1, 2, 3, 4, 5]);
    expect(timing.packetCount, 0);
    expect(timing.hasMediaClock, isFalse);
    expect(timing.hasKeyframes, isFalse);
  });
}

List<int> _pat(int pmtPid) => <int>[
  0x00, // pointer field
  0x00, 0xB0, 0x0D, // PAT header, section_length = 13
  0x00, 0x01, // transport_stream_id
  0xC1, 0x00, 0x00,
  0x00, 0x01, // program_number
  0xE0 | ((pmtPid >> 8) & 0x1F), pmtPid & 0xFF,
  0x00, 0x00, 0x00, 0x00, // CRC (not validated by the lightweight parser)
];

List<int> _pmt(int videoPid) => <int>[
  0x00, // pointer field
  0x02, 0xB0, 0x12, // PMT header, section_length = 18
  0x00, 0x01, // program_number
  0xC1, 0x00, 0x00,
  0xE0 | ((videoPid >> 8) & 0x1F), videoPid & 0xFF, // PCR PID
  0xF0, 0x00, // program_info_length
  0x1B, // H.264 / AVC
  0xE0 | ((videoPid >> 8) & 0x1F), videoPid & 0xFF,
  0xF0, 0x00, // ES_info_length
  0x00, 0x00, 0x00, 0x00, // CRC
];

List<int> _videoPes(int pts90k, {required bool idr}) => <int>[
  0x00, 0x00, 0x01, 0xE0,
  0x00, 0x00, // unbounded PES packet length
  0x80, 0x80, 0x05,
  ..._encodePts(pts90k),
  0x00, 0x00, 0x00, 0x01,
  idr ? 0x65 : 0x41,
  0x88, 0x84, 0x21,
];

List<int> _encodePts(int pts) => <int>[
  0x20 | (((pts >> 30) & 0x07) << 1) | 1,
  (pts >> 22) & 0xFF,
  (((pts >> 15) & 0x7F) << 1) | 1,
  (pts >> 7) & 0xFF,
  ((pts & 0x7F) << 1) | 1,
];

List<int> _packet({
  required int pid,
  required bool payloadUnitStart,
  required List<int> payload,
  int? pcr27m,
}) {
  final packet = List<int>.filled(188, 0xFF);
  packet[0] = 0x47;
  packet[1] = (payloadUnitStart ? 0x40 : 0x00) | ((pid >> 8) & 0x1F);
  packet[2] = pid & 0xFF;

  var cursor = 4;
  if (pcr27m != null) {
    packet[3] = 0x30; // adaptation + payload
    packet[cursor++] = 7;
    packet[cursor++] = 0x10; // PCR flag
    final pcr = _encodePcr(pcr27m);
    packet.setRange(cursor, cursor + pcr.length, pcr);
    cursor += pcr.length;
  } else {
    packet[3] = 0x10; // payload only
  }

  final available = 188 - cursor;
  final length = payload.length < available ? payload.length : available;
  packet.setRange(cursor, cursor + length, payload.take(length));
  return packet;
}

List<int> _encodePcr(int pcr27m) {
  final base = pcr27m ~/ 300;
  final extension = pcr27m % 300;
  return <int>[
    (base >> 25) & 0xFF,
    (base >> 17) & 0xFF,
    (base >> 9) & 0xFF,
    (base >> 1) & 0xFF,
    ((base & 1) << 7) | 0x7E | ((extension >> 8) & 1),
    extension & 0xFF,
  ];
}
