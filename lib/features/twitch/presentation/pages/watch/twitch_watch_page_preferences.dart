import 'dart:async';

import '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension TwitchWatchPagePreferenceMethods on TwitchWatchPageState {
  Future<void> loadWatchPreferences() async {
    await preferencesController.load();
    bindPlayerVolumeStream();
  }

  void bindPlayerVolumeStream() {
    final previousCancel = playerVolumeSubscription?.cancel();
    if (previousCancel != null) unawaited(previousCancel);
    playerVolumeSubscription = null;
  }

  Future<void> setPlayerVolume(double value) {
    return preferencesController.setPlayerVolume(value);
  }

  Future<void> togglePlayerMute() {
    return preferencesController.togglePlayerMute();
  }

  Future<void> applyPlayerVolume() {
    return preferencesController.applyPlayerVolume();
  }

  Future<void> saveChatPanelWidthPreference() {
    return preferencesController.saveChatPanelWidthPreference();
  }

  void setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    preferencesController.setChatPanelWidthForViewport(
      viewportWidth: viewportWidth,
      value: value,
    );
  }
}
