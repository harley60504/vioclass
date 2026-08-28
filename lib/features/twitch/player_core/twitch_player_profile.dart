// Independent Twitch player core profile with aggressive lower-latency
// PiliPlus-style media_kit tuning.
//
// Previous working media_kit path used almost no mpv options, while this branch
// can now inject options through the fork API. Keep only options that help live
// latency testing and avoid options that let mpv build a larger cache.

import 'package:flutter/foundation.dart';

class TwitchPlayerProfile {
  final String id;
  final String label;
  final int bufferSize;
  final bool enableHardwareAcceleration;
  final String? hwdec;
  final bool androidAttachSurfaceAfterVideoParameters;
  final Map<String, String> mpvOptions;

  const TwitchPlayerProfile({
    required this.id,
    required this.label,
    required this.bufferSize,
    required this.enableHardwareAcceleration,
    required this.hwdec,
    required this.androidAttachSurfaceAfterVideoParameters,
    this.mpvOptions = const <String, String>{},
  });

  static const Map<String, String> _mobileLowLatencyOptions = <String, String>{
    'volume-max': '100',
    'force-seekable': 'yes',
    'video-sync': 'audio',
    // autosync=30 from the previous test can smooth clock drift, but for a
    // live local HLS proxy it may also tolerate more buffering. Use 0 for the
    // lower-latency profile and compare against the previous commit if needed.
    'autosync': '0',
    // Do not let mpv build an additional demuxer cache on top of our own HLS
    // proxy prefetch queue.
    'cache': 'no',
    'cache-pause': 'no',
    'demuxer-seekable-cache': 'no',
    'demuxer-readahead-secs': '0',
    'demuxer-max-back-bytes': '0',
    'demuxer-max-bytes': '1048576',
  };

  static const Map<String, String> _desktopLowLatencyOptions = <String, String>{
    'volume': '100',
    'force-seekable': 'yes',
    'video-sync': 'audio',
    'autosync': '0',
    'cache': 'no',
    'cache-pause': 'no',
    'demuxer-seekable-cache': 'no',
    'demuxer-readahead-secs': '0',
    'demuxer-max-back-bytes': '0',
    'demuxer-max-bytes': '1048576',
  };

  static TwitchPlayerProfile forCurrentPlatform({
    TargetPlatform? platform,
    bool live = true,
    bool lowLatency = true,
  }) {
    final target = platform ?? defaultTargetPlatform;
    switch (target) {
      case TargetPlatform.android:
        return androidLive(lowLatency: lowLatency);
      case TargetPlatform.iOS:
        return iosLive(lowLatency: lowLatency);
      case TargetPlatform.windows:
        return windowsLive(lowLatency: lowLatency);
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return desktopLive(lowLatency: lowLatency);
      case TargetPlatform.fuchsia:
        return genericLive(lowLatency: lowLatency);
    }
  }

  static TwitchPlayerProfile androidLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency
          ? 'android-live-low-latency-piliplus-stage220h'
          : 'android-live-stable-piliplus',
      label: lowLatency
          ? 'Android Live Low Latency PiliPlus Stage 220H'
          : 'Android Live Stable PiliPlus',
      bufferSize: lowLatency ? 8 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: lowLatency
          ? _mobileLowLatencyOptions
          : const <String, String>{
              'volume-max': '100',
              'video-sync': 'audio',
              'autosync': '30',
              'force-seekable': 'yes',
            },
    );
  }

  static TwitchPlayerProfile iosLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency
          ? 'ios-live-low-latency-piliplus-stage220h'
          : 'ios-live-stable-piliplus',
      label: lowLatency
          ? 'iOS Live Low Latency PiliPlus Stage 220H'
          : 'iOS Live Stable PiliPlus',
      bufferSize: lowLatency ? 8 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: lowLatency
          ? _mobileLowLatencyOptions
          : const <String, String>{
              'video-sync': 'audio',
              'autosync': '30',
              'force-seekable': 'yes',
            },
    );
  }

  static TwitchPlayerProfile windowsLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency
          ? 'windows-live-low-latency-piliplus-stage220h'
          : 'windows-live-stable-piliplus',
      label: lowLatency
          ? 'Windows Live Low Latency PiliPlus Stage 220H'
          : 'Windows Live Stable PiliPlus',
      bufferSize: lowLatency ? 8 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: lowLatency
          ? _desktopLowLatencyOptions
          : const <String, String>{
              'volume': '100',
              'video-sync': 'audio',
              'autosync': '30',
              'force-seekable': 'yes',
            },
    );
  }

  static TwitchPlayerProfile desktopLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency
          ? 'desktop-live-low-latency-piliplus-stage220h'
          : 'desktop-live-stable-piliplus',
      label: lowLatency
          ? 'Desktop Live Low Latency PiliPlus Stage 220H'
          : 'Desktop Live Stable PiliPlus',
      bufferSize: lowLatency ? 8 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: lowLatency
          ? _desktopLowLatencyOptions
          : const <String, String>{
              'volume': '100',
              'video-sync': 'audio',
              'autosync': '30',
              'force-seekable': 'yes',
            },
    );
  }

  static TwitchPlayerProfile genericLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency
          ? 'generic-live-low-latency-piliplus-stage220h'
          : 'generic-live-stable-piliplus',
      label: lowLatency
          ? 'Generic Live Low Latency PiliPlus Stage 220H'
          : 'Generic Live Stable PiliPlus',
      bufferSize: lowLatency ? 8 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: lowLatency
          ? _desktopLowLatencyOptions
          : const <String, String>{
              'video-sync': 'audio',
              'autosync': '30',
              'force-seekable': 'yes',
            },
    );
  }

  TwitchPlayerProfile copyWith({
    String? id,
    String? label,
    int? bufferSize,
    bool? enableHardwareAcceleration,
    String? hwdec,
    bool? androidAttachSurfaceAfterVideoParameters,
    Map<String, String>? mpvOptions,
  }) {
    return TwitchPlayerProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      bufferSize: bufferSize ?? this.bufferSize,
      enableHardwareAcceleration:
          enableHardwareAcceleration ?? this.enableHardwareAcceleration,
      hwdec: hwdec ?? this.hwdec,
      androidAttachSurfaceAfterVideoParameters:
          androidAttachSurfaceAfterVideoParameters ??
          this.androidAttachSurfaceAfterVideoParameters,
      mpvOptions: mpvOptions ?? this.mpvOptions,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'label': label,
      'bufferSize': bufferSize,
      'enableHardwareAcceleration': enableHardwareAcceleration,
      'hwdec': hwdec,
      'androidAttachSurfaceAfterVideoParameters':
          androidAttachSurfaceAfterVideoParameters,
      'mpvOptions': mpvOptions,
    };
  }
}
