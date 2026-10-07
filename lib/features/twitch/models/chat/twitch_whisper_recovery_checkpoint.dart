import 'twitch_whisper_remote_history.dart';

/// Owner-scoped archive work, independent of the UI's browsing cursors.
class TwitchWhisperRecoveryCheckpoint {
  final DateTime since;
  final DateTime? gapObservedAt;
  final String? gapObservationId;
  final String phase;
  final List<String> peerIds;
  final int peerIndex;
  final String? cursor;
  final List<String> visitedCursors;
  bool get complete => phase == 'complete';
  String? get activePeerId => phase == 'history' ? peerIds[peerIndex] : null;

  TwitchWhisperRecoveryCheckpoint({
    required this.since,
    this.gapObservedAt,
    this.gapObservationId,
    required this.phase,
    required Iterable<String> peerIds,
    this.peerIndex = 0,
    this.cursor,
    Iterable<String> visitedCursors = const [],
  }) : peerIds = List.unmodifiable(peerIds),
       visitedCursors = List.unmodifiable(visitedCursors) {
    if ((gapObservationId != null &&
            !RegExp(r'^[0-9a-f]{32}$').hasMatch(gapObservationId!)) ||
        !['threads', 'history', 'complete'].contains(phase) ||
        this.peerIds.length > 500 ||
        this.peerIds.toSet().length != this.peerIds.length ||
        this.peerIds.any((id) => !RegExp(r'^\d+$').hasMatch(id)) ||
        peerIndex < 0 ||
        peerIndex > this.peerIds.length ||
        (phase == 'threads' && peerIndex != 0) ||
        (phase == 'history' && peerIndex >= this.peerIds.length) ||
        (complete && (peerIndex != this.peerIds.length || cursor != null)) ||
        (cursor != null && (cursor!.isEmpty || cursor!.length > 4096)) ||
        this.visitedCursors.length > 1000 ||
        this.visitedCursors.toSet().length != this.visitedCursors.length ||
        this.visitedCursors.any((c) => c.isEmpty || c.length > 4096) ||
        (cursor != null && this.visitedCursors.contains(cursor))) {
      throw const FormatException('Invalid whisper recovery checkpoint');
    }
  }

  Map<String, dynamic> toJson() => {
    'since': since.toUtc().toIso8601String(),
    'gapObservedAt': gapObservedAt?.toUtc().toIso8601String(),
    'gapObservationId': gapObservationId,
    'phase': phase,
    'peerIds': peerIds,
    'peerIndex': peerIndex,
    'cursor': cursor,
    'visitedCursors': visitedCursors,
  };

  factory TwitchWhisperRecoveryCheckpoint.fromJson(Map<String, dynamic> json) {
    final raw = json['since'];
    final observed = json['gapObservedAt'];
    if (observed != null &&
        (observed is! String ||
            DateTime.tryParse(observed)?.toUtc().toIso8601String() !=
                observed)) {
      throw const FormatException('Invalid recovery gap observation');
    }
    if (raw is! String ||
        DateTime.tryParse(raw)?.toUtc().toIso8601String() != raw) {
      throw const FormatException('Invalid recovery timestamp');
    }
    return TwitchWhisperRecoveryCheckpoint(
      since: DateTime.parse(raw),
      gapObservationId: json['gapObservationId'] as String?,
      gapObservedAt: observed == null
          ? null
          : DateTime.parse(observed as String),
      phase: json['phase'] as String,
      peerIds: (json['peerIds'] as List).cast<String>(),
      peerIndex: json['peerIndex'] as int,
      cursor: json['cursor'] as String?,
      visitedCursors: (json['visitedCursors'] as List).cast<String>(),
    );
  }

  void _checkPage(String? requested, String? next) {
    if (requested != cursor ||
        (next != null && (next == cursor || visitedCursors.contains(next)))) {
      throw const FormatException('Stale or cyclic recovery page');
    }
  }

  TwitchWhisperRecoveryCheckpoint afterThreads(TwitchWhisperThreadsPage page) {
    if (phase != 'threads') {
      throw const FormatException('Recovery is not discovering threads');
    }
    _checkPage(page.requestedCursor, page.nextCursor);
    final peers = {
      ...peerIds,
      ...page.conversations.map((p) => p.userId),
    }.toList();
    final finished = page.nextCursor == null;
    return TwitchWhisperRecoveryCheckpoint(
      since: since,
      gapObservedAt: gapObservedAt,
      gapObservationId: gapObservationId,
      phase: finished ? (peers.isEmpty ? 'complete' : 'history') : 'threads',
      peerIds: peers,
      cursor: finished ? null : page.nextCursor,
      visitedCursors: finished ? const [] : [...visitedCursors, ?cursor],
    );
  }

  TwitchWhisperRecoveryCheckpoint afterHistory(TwitchWhisperRemotePage page) {
    if (phase != 'history' || page.peerId != activePeerId) {
      throw const FormatException('Recovery peer mismatch');
    }
    _checkPage(page.requestedCursor, page.nextCursor);
    final nextIndex = page.exhausted ? peerIndex + 1 : peerIndex;
    return TwitchWhisperRecoveryCheckpoint(
      since: since,
      gapObservedAt: gapObservedAt,
      gapObservationId: gapObservationId,
      phase: nextIndex == peerIds.length ? 'complete' : 'history',
      peerIds: peerIds,
      peerIndex: nextIndex,
      cursor: page.nextCursor,
      visitedCursors: page.exhausted ? const [] : [...visitedCursors, ?cursor],
    );
  }
}
