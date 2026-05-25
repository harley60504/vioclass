part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPagePreferenceMethods on _TwitchWatchPageState {
  Future<void> _loadWatchPreferences() async {
    await _preferencesController.load();
    _bindPlayerVolumeStream();
  }

  void _bindPlayerVolumeStream() {
    final previousCancel = _playerVolumeSubscription?.cancel();
    if (previousCancel != null) unawaited(previousCancel);
    _playerVolumeSubscription = null;
  }

  Future<void> _setPlayerVolume(double value) {
    return _preferencesController.setPlayerVolume(value);
  }

  Future<void> _togglePlayerMute() {
    return _preferencesController.togglePlayerMute();
  }

  Future<void> _applyPlayerVolume() {
    return _preferencesController.applyPlayerVolume();
  }

  Future<void> _saveChatPanelWidthPreference() {
    return _preferencesController.saveChatPanelWidthPreference();
  }

  void _setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    _preferencesController.setChatPanelWidthForViewport(
      viewportWidth: viewportWidth,
      value: value,
    );
  }
}
