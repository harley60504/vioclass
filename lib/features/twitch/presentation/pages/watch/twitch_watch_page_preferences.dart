part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPagePreferenceMethods on _TwitchWatchPageState {
  Future<void> _loadWatchPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChatPanelWidth =
          (prefs.getDouble(_chatPanelWidthPreferenceKey) ??
                  prefs.getDouble(_legacyChatPanelWidthPreferenceKey) ??
                  _chatPanelWidth)
              .clamp(_minChatPanelWidth, _maxChatPanelWidth)
              .toDouble();
      final savedChatPanelRatio =
          (prefs.getDouble(_chatPanelRatioPreferenceKey) ?? _chatPanelRatio)
              .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
              .toDouble();
      final savedVolume =
          (prefs.getDouble(_playerVolumePreferenceKey) ??
                  prefs.getDouble(_legacyPlayerVolumePreferenceKey) ??
                  _volume)
              .clamp(0.0, 100.0)
              .toDouble();
      final savedMuted =
          prefs.getBool(_playerMutedPreferenceKey) ??
          prefs.getBool(_legacyPlayerMutedPreferenceKey) ??
          false;
      final savedChatVisible =
          prefs.getBool(_chatVisiblePreferenceKey) ?? _chatVisible;

      if (!mounted) return;
      setState(() {
        _chatPanelWidth = savedChatPanelWidth;
        _chatPanelRatio = savedChatPanelRatio;
        _volume = savedVolume;
        _lastNonZeroVolume = savedVolume > 0 ? savedVolume : 100.0;
        _isMuted = savedMuted;
        _chatVisible = savedChatVisible;
      });

      unawaited(_saveChatPanelWidthPreference());
      unawaited(_saveVolumePreference());
    } catch (error) {
      debugPrint('load watch preferences failed: $error');
    }

    await _applyPlayerVolume();
    _bindPlayerVolumeStream();
  }

  void _bindPlayerVolumeStream() {
    final previousCancel = _playerVolumeSubscription?.cancel();
    if (previousCancel != null) unawaited(previousCancel);
    _playerVolumeSubscription = null;
  }

  Future<void> _setPlayerVolume(double value) async {
    final nextVolume = value.clamp(0.0, 100.0).toDouble();
    setState(() {
      _volume = nextVolume;
      _isMuted = nextVolume <= 0.0;
      if (nextVolume > 0.0) _lastNonZeroVolume = nextVolume;
    });
    final player = _playerSession.playerOrNull;
    if (player != null) {
      await player.setVolume(_isMuted ? 0.0 : nextVolume);
    }
    _scheduleVolumePreferenceSave();
  }

  Future<void> _togglePlayerMute() async {
    final nextMuted = !_isMuted;
    final nextVolume = nextMuted
        ? 0.0
        : (_volume > 0.0 ? _volume : _lastNonZeroVolume)
              .clamp(1.0, 100.0)
              .toDouble();
    setState(() {
      _isMuted = nextMuted;
      if (!nextMuted) {
        _volume = nextVolume;
        _lastNonZeroVolume = nextVolume;
      }
    });
    final player = _playerSession.playerOrNull;
    if (player != null) {
      await player.setVolume(nextMuted ? 0.0 : nextVolume);
    }
    _scheduleVolumePreferenceSave();
  }

  Future<void> _applyPlayerVolume() async {
    if (!_isMuted && _volume <= 0) {
      _volume = _lastNonZeroVolume.clamp(1.0, 100.0).toDouble();
    }
    final player = _playerSession.playerOrNull;
    if (player == null) return;
    await player.setVolume(
      _isMuted ? 0.0 : _volume.clamp(0.0, 100.0).toDouble(),
    );
  }

  void _scheduleVolumePreferenceSave() {
    _volumePreferenceSaveDebounce?.cancel();
    _volumePreferenceSaveDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        unawaited(_saveVolumePreference());
      },
    );
  }

  Future<void> _saveVolumePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _playerVolumePreferenceKey,
        _volume.clamp(0.0, 100.0).toDouble(),
      );
      await prefs.setBool(_playerMutedPreferenceKey, _isMuted);
    } catch (error) {
      debugPrint('save watch volume preference failed: $error');
    }
  }

  Future<void> _saveChatVisiblePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatVisiblePreferenceKey, _chatVisible);
    } catch (error) {
      debugPrint('save watch chat visibility preference failed: $error');
    }
  }

  Future<void> _saveChatPanelWidthPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        _chatPanelWidthPreferenceKey,
        _chatPanelWidth
            .clamp(_minChatPanelWidth, _maxChatPanelWidth)
            .toDouble(),
      );
      await prefs.setDouble(
        _chatPanelRatioPreferenceKey,
        _chatPanelRatio
            .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
            .toDouble(),
      );
    } catch (error) {
      debugPrint('save watch chat width preference failed: $error');
    }
  }

  void _setChatPanelWidthForViewport({
    required double viewportWidth,
    required double value,
  }) {
    if (viewportWidth <= 0) return;
    final ratioLimitedMin = viewportWidth * _minChatPanelRatio;
    final effectiveMinWidth = ratioLimitedMin
        .clamp(_minChatPanelWidth, _maxEffectiveMinChatPanelWidth)
        .toDouble();
    final effectiveMaxWidth = _maxChatPanelWidth
        .clamp(effectiveMinWidth, viewportWidth - 120.0)
        .toDouble();
    final nextWidth = value
        .clamp(effectiveMinWidth, effectiveMaxWidth)
        .toDouble();
    final effectiveMinRatio = (effectiveMinWidth / viewportWidth)
        .clamp(_minStoredChatPanelRatio, _maxChatPanelRatio)
        .toDouble();
    final nextRatio = (nextWidth / viewportWidth)
        .clamp(effectiveMinRatio, _maxChatPanelRatio)
        .toDouble();

    if ((_chatPanelWidth - nextWidth).abs() < 0.5 &&
        (_chatPanelRatio - nextRatio).abs() < 0.002) {
      return;
    }

    setState(() {
      _chatPanelWidth = nextWidth;
      _chatPanelRatio = nextRatio;
    });
  }
}
