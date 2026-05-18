// Stage 220A: Independent Twitch player core state.

import 'twitch_player_profile.dart';

class TwitchPlayerState {
  final bool initialized;
  final bool opening;
  final bool playing;
  final bool buffering;
  final bool muted;
  final double volume;
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final int? videoWidth;
  final int? videoHeight;
  final String? mediaUri;
  final Object? error;
  final TwitchPlayerProfile profile;

  const TwitchPlayerState({
    required this.initialized,
    required this.opening,
    required this.playing,
    required this.buffering,
    required this.muted,
    required this.volume,
    required this.position,
    required this.duration,
    required this.buffered,
    required this.videoWidth,
    required this.videoHeight,
    required this.mediaUri,
    required this.error,
    required this.profile,
  });

  factory TwitchPlayerState.initial(TwitchPlayerProfile profile) {
    return TwitchPlayerState(
      initialized: false,
      opening: false,
      playing: false,
      buffering: false,
      muted: false,
      volume: 100.0,
      position: Duration.zero,
      duration: Duration.zero,
      buffered: Duration.zero,
      videoWidth: null,
      videoHeight: null,
      mediaUri: null,
      error: null,
      profile: profile,
    );
  }

  bool get hasVideoSize => (videoWidth ?? 0) > 0 && (videoHeight ?? 0) > 0;
  bool get hasError => error != null;
  bool get hasMedia => mediaUri != null && mediaUri!.trim().isNotEmpty;

  double get aspectRatio {
    final width = videoWidth ?? 0;
    final height = videoHeight ?? 0;
    if (width <= 0 || height <= 0) return 16 / 9;
    return width / height;
  }

  TwitchPlayerState copyWith({
    bool? initialized,
    bool? opening,
    bool? playing,
    bool? buffering,
    bool? muted,
    double? volume,
    Duration? position,
    Duration? duration,
    Duration? buffered,
    int? videoWidth,
    int? videoHeight,
    bool clearVideoSize = false,
    String? mediaUri,
    bool clearMediaUri = false,
    Object? error,
    bool clearError = false,
    TwitchPlayerProfile? profile,
  }) {
    return TwitchPlayerState(
      initialized: initialized ?? this.initialized,
      opening: opening ?? this.opening,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      muted: muted ?? this.muted,
      volume: volume ?? this.volume,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      videoWidth: clearVideoSize ? null : videoWidth ?? this.videoWidth,
      videoHeight: clearVideoSize ? null : videoHeight ?? this.videoHeight,
      mediaUri: clearMediaUri ? null : mediaUri ?? this.mediaUri,
      error: clearError ? null : error ?? this.error,
      profile: profile ?? this.profile,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'initialized': initialized,
      'opening': opening,
      'playing': playing,
      'buffering': buffering,
      'muted': muted,
      'volume': volume,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'bufferedMs': buffered.inMilliseconds,
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'mediaUri': mediaUri,
      'error': error?.toString(),
      'profile': profile.toJson(),
    };
  }
}
