import '../../../models/playback/twitch_hls_proxy_models.dart';

/// A live reader is reusable only when it kept pace with elapsed wall time.
/// Merely observing playback advancing after resume does not prove freshness.
class TwitchLiveForegroundCheckpoint {
  /// Give a running writer a bounded chance to finish its network recovery.
  /// Cancellation is supplied by the route/source owner, not by the proxy.
  static Future<TwitchHlsLiveStatus?> confirmUpstream({
    required TwitchHlsLiveStatus? initial,
    required Future<TwitchHlsLiveStatus?> Function() refresh,
    required bool Function() isCurrent,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
    Duration confirmationWindow = const Duration(seconds: 2),
  }) async {
    final clock = now ?? DateTime.now;
    final pause = wait ?? (duration) => Future<void>.delayed(duration);
    final deadline = clock().add(confirmationWindow);
    var status = initial;
    while (isCurrent()) {
      if (upstreamIsCurrent(status, clock()) ||
          status?.running != true ||
          status?.hasWriter != true) {
        return status;
      }
      final remaining = deadline.difference(clock());
      if (remaining <= Duration.zero) return status;
      const interval = Duration(milliseconds: 250);
      await pause(remaining < interval ? remaining : interval);
      if (!isCurrent()) return null;
      final readBudget = deadline.difference(clock());
      if (readBudget <= Duration.zero) return status;
      try {
        final refreshed = await refresh().timeout(readBudget);
        if (!isCurrent()) return null;
        status = refreshed;
      } catch (_) {
        // A failed status read cannot prove recovery. Keep the last snapshot
        // and retry only within the same confirmation window.
      }
    }
    return null;
  }

  static bool upstreamIsCurrent(TwitchHlsLiveStatus? status, DateTime now) {
    if (status == null ||
        !status.running ||
        !status.hasWriter ||
        !status.hasOutput ||
        status.lastWrittenSequence < 0 ||
        status.latestPlayableSequence < 0 ||
        status.lagSegments > 1) {
      return false;
    }
    final age = now.difference(status.updatedAt);
    return age >= Duration.zero && age <= const Duration(seconds: 10);
  }

  final DateTime capturedAt;
  final Duration position;
  final String mediaUri;
  final bool wasPlaying;

  const TwitchLiveForegroundCheckpoint({
    required this.capturedAt,
    required this.position,
    required this.mediaUri,
    required this.wasPlaying,
  });

  bool keptUp({
    required DateTime now,
    required Duration currentPosition,
    required String? currentUri,
    required bool playing,
    required bool buffering,
    required bool hasError,
  }) {
    final elapsed = now.difference(capturedAt);
    final advanced = currentPosition - position;
    if (!wasPlaying ||
        !playing ||
        buffering ||
        hasError ||
        mediaUri.isEmpty ||
        currentUri != mediaUri ||
        elapsed < const Duration(seconds: 1) ||
        advanced <= Duration.zero) {
      return false;
    }
    // Allow a small timestamp/reporting delay, not a proportional drift that
    // would grow without bound during a long background stay.
    return advanced >= elapsed - const Duration(seconds: 1);
  }
}
