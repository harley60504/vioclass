import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TwitchWatchPreferencesController extends ChangeNotifier {
  static const String chatPanelWidthPreferenceKey =
      'twitch_watch_v2_chat_panel_width';
  static const String chatPanelRatioPreferenceKey =
      'twitch_watch_v3_chat_panel_ratio';
  static const String playerVolumePreferenceKey =
      'twitch_watch_v2_player_volume';
  static const String playerMutedPreferenceKey = 'twitch_watch_v2_player_muted';
  static const String chatVisiblePreferenceKey = 'twitch_watch_v2_chat_visible';

  static const String legacyChatPanelWidthPreferenceKey =
      'twitch_watch_chat_panel_width';
  static const String legacyPlayerVolumePreferenceKey =
      'twitch_watch_player_volume';
  static const String legacyPlayerMutedPreferenceKey =
      'twitch_watch_player_muted';

  final double minChatPanelWidth;
  final double maxEffectiveMinChatPanelWidth;
  final double maxChatPanelWidth;
  final double minChatPanelRatio;
  final double minStoredChatPanelRatio;
  final double maxChatPanelRatio;
  final Future<void> Function(double volume) applyVolume;

  Timer? _volumePreferenceSaveDebounce;
  Timer? _chatWidthPreferenceSaveDebounce;

  double chatPanelWidth;
  double chatPanelRatio;
  double volume;
  double lastNonZeroVolume;
  bool muted;
  bool chatVisible;

  TwitchWatchPreferencesController({
    required this.applyVolume,
    this.chatPanelWidth = 430,
    this.chatPanelRatio = 0.34,
    this.volume = 100.0,
    this.lastNonZeroVolume = 100.0,
    this.muted = false,
    this.chatVisible = true,
    this.minChatPanelWidth = 180.0,
    this.maxEffectiveMinChatPanelWidth = 280.0,
    this.maxChatPanelWidth = 620.0,
    this.minChatPanelRatio = 0.22,
    this.minStoredChatPanelRatio = 0.08,
    this.maxChatPanelRatio = 0.48,
  });

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      chatPanelWidth =
          (prefs.getDouble(chatPanelWidthPreferenceKey) ??
                  prefs.getDouble(legacyChatPanelWidthPreferenceKey) ??
                  chatPanelWidth)
              .clamp(minChatPanelWidth, maxChatPanelWidth)
              .toDouble();
      chatPanelRatio =
          (prefs.getDouble(chatPanelRatioPreferenceKey) ?? chatPanelRatio)
              .clamp(minStoredChatPanelRatio, maxChatPanelRatio)
              .toDouble();
      volume =
          (prefs.getDouble(playerVolumePreferenceKey) ??
                  prefs.getDouble(legacyPlayerVolumePreferenceKey) ??
                  volume)
              .clamp(0.0, 100.0)
              .toDouble();
      lastNonZeroVolume = volume > 0 ? volume : 100.0;
      muted =
          prefs.getBool(playerMutedPreferenceKey) ??
          prefs.getBool(legacyPlayerMutedPreferenceKey) ??
          false;
      chatVisible = prefs.getBool(chatVisiblePreferenceKey) ?? chatVisible;
      notifyListeners();

      unawaited(saveChatPanelWidthPreference());
      unawaited(saveVolumePreference());
    } catch (error) {
      debugPrint('load watch preferences failed: $error');
    }

    await applyPlayerVolume();
  }

  Future<void> setPlayerVolume(double value) async {
    final nextVolume = value.clamp(0.0, 100.0).toDouble();
    volume = nextVolume;
    muted = nextVolume <= 0.0;
    if (nextVolume > 0.0) lastNonZeroVolume = nextVolume;
    notifyListeners();
    await applyVolume(muted ? 0.0 : nextVolume);
    scheduleVolumePreferenceSave();
  }

  Future<void> togglePlayerMute() async {
    final nextMuted = !muted;
    final nextVolume = nextMuted
        ? 0.0
        : (volume > 0.0 ? volume : lastNonZeroVolume)
              .clamp(1.0, 100.0)
              .toDouble();
    muted = nextMuted;
    if (!nextMuted) {
      volume = nextVolume;
      lastNonZeroVolume = nextVolume;
    }
    notifyListeners();
    await applyVolume(nextMuted ? 0.0 : nextVolume);
    scheduleVolumePreferenceSave();
  }

  Future<void> applyPlayerVolume() async {
    if (!muted && volume <= 0) {
      volume = lastNonZeroVolume.clamp(1.0, 100.0).toDouble();
      notifyListeners();
    }
    await applyVolume(muted ? 0.0 : volume.clamp(0.0, 100.0).toDouble());
  }

  void toggleChatVisibility() {
    chatVisible = !chatVisible;
    notifyListeners();
    unawaited(saveChatVisiblePreference());
  }

  void setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    if (viewportWidth <= 0) return;
    final ratioLimitedMin = viewportWidth * minChatPanelRatio;
    final effectiveMinWidth = ratioLimitedMin
        .clamp(minChatPanelWidth, maxEffectiveMinChatPanelWidth)
        .toDouble();
    final effectiveMaxWidth = maxChatPanelWidth
        .clamp(effectiveMinWidth, viewportWidth - 120.0)
        .toDouble();
    final nextWidth = value
        .clamp(effectiveMinWidth, effectiveMaxWidth)
        .toDouble();
    final effectiveMinRatio = (effectiveMinWidth / viewportWidth)
        .clamp(minStoredChatPanelRatio, maxChatPanelRatio)
        .toDouble();
    final nextRatio = (nextWidth / viewportWidth)
        .clamp(effectiveMinRatio, maxChatPanelRatio)
        .toDouble();

    if ((chatPanelWidth - nextWidth).abs() < 0.5 &&
        (chatPanelRatio - nextRatio).abs() < 0.002) {
      return;
    }

    chatPanelWidth = nextWidth;
    chatPanelRatio = nextRatio;
    notifyListeners();
    scheduleChatPanelWidthPreferenceSave();
  }

  void scheduleVolumePreferenceSave() {
    _volumePreferenceSaveDebounce?.cancel();
    _volumePreferenceSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        unawaited(saveVolumePreference());
      },
    );
  }

  void scheduleChatPanelWidthPreferenceSave() {
    _chatWidthPreferenceSaveDebounce?.cancel();
    _chatWidthPreferenceSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(saveChatPanelWidthPreference()),
    );
  }

  Future<void> saveVolumePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        playerVolumePreferenceKey,
        volume.clamp(0.0, 100.0).toDouble(),
      );
      await prefs.setBool(playerMutedPreferenceKey, muted);
    } catch (error) {
      debugPrint('save watch volume preference failed: $error');
    }
  }

  Future<void> saveChatVisiblePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(chatVisiblePreferenceKey, chatVisible);
    } catch (error) {
      debugPrint('save watch chat visibility preference failed: $error');
    }
  }

  Future<void> saveChatPanelWidthPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        chatPanelWidthPreferenceKey,
        chatPanelWidth.clamp(minChatPanelWidth, maxChatPanelWidth).toDouble(),
      );
      await prefs.setDouble(
        chatPanelRatioPreferenceKey,
        chatPanelRatio
            .clamp(minStoredChatPanelRatio, maxChatPanelRatio)
            .toDouble(),
      );
    } catch (error) {
      debugPrint('save watch chat width preference failed: $error');
    }
  }

  @override
  void dispose() {
    _volumePreferenceSaveDebounce?.cancel();
    _chatWidthPreferenceSaveDebounce?.cancel();
    unawaited(saveVolumePreference());
    unawaited(saveChatPanelWidthPreference());
    super.dispose();
  }
}
