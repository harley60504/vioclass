// Stage 220E: Independent Twitch player core profile with PiliPlus-style
// media_kit tuning.
//
// This branch intentionally tests the media_kit dependency set and mpv options
// used by PiliPlus' player controller style before touching WatchPage.

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
      id: lowLatency ? 'android-live-low-latency-piliplus' : 'android-live-stable-piliplus',
      label: lowLatency ? 'Android Live Low Latency PiliPlus' : 'Android Live Stable PiliPlus',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        // PiliPlus core options.
        'volume-max': '100',
        'video-sync': 'audio',
        'autosync': '30',
        // For stable local HLS proxy URLs: keep mpv treating the stream as
        // seekable enough for smoother live-edge behavior.
        'force-seekable': 'yes',
        // Conservative live-cache hints. These can be tuned after Android test.
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
      },
    );
  }

  static TwitchPlayerProfile iosLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'ios-live-low-latency-piliplus' : 'ios-live-stable-piliplus',
      label: lowLatency ? 'iOS Live Low Latency PiliPlus' : 'iOS Live Stable PiliPlus',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
        'autosync': '30',
        'force-seekable': 'yes',
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
      },
    );
  }

  static TwitchPlayerProfile windowsLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'windows-live-low-latency-piliplus' : 'windows-live-stable-piliplus',
      label: lowLatency ? 'Windows Live Low Latency PiliPlus' : 'Windows Live Stable PiliPlus',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'volume': '100',
        'video-sync': 'audio',
        'autosync': '30',
        'force-seekable': 'yes',
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
      },
    );
  }

  static TwitchPlayerProfile desktopLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'desktop-live-low-latency-piliplus' : 'desktop-live-stable-piliplus',
      label: lowLatency ? 'Desktop Live Low Latency PiliPlus' : 'Desktop Live Stable PiliPlus',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'volume': '100',
        'video-sync': 'audio',
        'autosync': '30',
        'force-seekable': 'yes',
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
      },
    );
  }

  static TwitchPlayerProfile genericLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'generic-live-low-latency-piliplus' : 'generic-live-stable-piliplus',
      label: lowLatency ? 'Generic Live Low Latency PiliPlus' : 'Generic Live Stable PiliPlus',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 64 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
        'autosync': '30',
        'force-seekable': 'yes',
        'cache': 'yes',
        'demuxer-seekable-cache': 'yes',
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
