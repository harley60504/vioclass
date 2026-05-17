part of '../twitch_watch_page.dart';

extension _TwitchWatchPagePlayerPart on _TwitchWatchPageState {
  Future<void> _loadPlayer(String channel) async {
    setState(() {
      _loadingPlayer = true;
      _playerError = null;
    });

    try {
      await _applyPlayerVolume();
      await _watchPorts.player.openLive(channelLogin: channel);
      await _applyPlayerVolume();
      await _waitForInitialPlaybackSettle();
    } catch (error) {
      _playerError = error.toString();
      rethrow;
    } finally {
      if (mounted) setState(() => _loadingPlayer = false);
    }
  }

  Future<void> _waitForInitialPlaybackSettle() async {
    if (_player.state.width != null && _player.state.width! > 0) return;

    final completer = Completer<void>();
    StreamSubscription<int?>? widthSubscription;
    StreamSubscription<bool>? playingSubscription;
    Timer? timeout;

    void complete() {
      if (completer.isCompleted) return;
      completer.complete();
      final widthCancel = widthSubscription?.cancel();
      if (widthCancel != null) unawaited(widthCancel);
      final playingCancel = playingSubscription?.cancel();
      if (playingCancel != null) unawaited(playingCancel);
      timeout?.cancel();
    }

    widthSubscription = _player.stream.width.listen((width) {
      if ((width ?? 0) > 0) complete();
    });
    playingSubscription = _player.stream.playing.listen((playing) {
      if (playing) Timer(const Duration(milliseconds: 180), complete);
    });
    timeout = Timer(const Duration(milliseconds: 850), complete);
    return completer.future;
  }

  Future<void> _enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;
    try {
      await TwitchFullscreenController.setFullscreen(true);
      _mobileImmersiveEntered = true;
    } catch (_) {}
  }

  void _toggleChatVisibility() {
    setState(() => _chatVisible = !_chatVisible);
    unawaited(_saveChatVisiblePreference());
  }

  Future<void> _toggleFullscreenMode() async {
    final next = !_fullscreenMode;
    try {
      await TwitchFullscreenController.setFullscreen(next);
      if (!mounted) return;
      setState(() => _fullscreenMode = next);
    } catch (error) {
      _showSnack('切換全螢幕失敗：$error');
    }
  }
}
