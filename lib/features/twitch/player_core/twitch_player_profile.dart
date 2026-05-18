// Stage 220A: Independent Twitch player core profile.
//
// This file intentionally has no WatchPage dependency. It describes how the
// media engine should be configured on each platform so Android / Windows can
// be tuned independently before the new core is wired into WatchPage.

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
      id: lowLatency ? 'android-live-low-latency' : 'android-live-stable',
      label: lowLatency ? 'Android Live Low Latency' : 'Android Live Stable',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        // PiliPlus-style: keep platform-specific mpv options centralized.
        // Keep this conservative for Stage 220A; more aggressive values can be
        // tested without touching WatchPage.
        'volume-max': '100',
        'video-sync': 'audio',
      },
    );
  }

  static TwitchPlayerProfile iosLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'ios-live-low-latency' : 'ios-live-stable',
      label: lowLatency ? 'iOS Live Low Latency' : 'iOS Live Stable',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
      },
    );
  }

  static TwitchPlayerProfile windowsLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'windows-live-low-latency' : 'windows-live-stable',
      label: lowLatency ? 'Windows Live Low Latency' : 'Windows Live Stable',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
      },
    );
  }

  static TwitchPlayerProfile desktopLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'desktop-live-low-latency' : 'desktop-live-stable',
      label: lowLatency ? 'Desktop Live Low Latency' : 'Desktop Live Stable',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
      },
    );
  }

  static TwitchPlayerProfile genericLive({bool lowLatency = true}) {
    return TwitchPlayerProfile(
      id: lowLatency ? 'generic-live-low-latency' : 'generic-live-stable',
      label: lowLatency ? 'Generic Live Low Latency' : 'Generic Live Stable',
      bufferSize: lowLatency ? 16 * 1024 * 1024 : 32 * 1024 * 1024,
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
      mpvOptions: const <String, String>{
        'video-sync': 'audio',
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
