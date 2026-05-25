part of '../twitch_watch_page.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _TwitchWatchPageUiMethods on _TwitchWatchPageState {
  void _notifyControllerChanged() {
    if (mounted) setState(() {});
  }

  void _setResolvedChannelId(String channelId) {
    final next = channelId.trim();
    if (next.isEmpty || next == _channelId) return;
    _channelId = next;
    if (mounted) setState(() {});
  }

  Future<void> _enterMobileImmersiveByDefault() async {
    if (!TwitchFullscreenController.isMobilePlatform) return;
    try {
      await TwitchFullscreenController.setFullscreen(true);
      _mobileImmersiveEntered = true;
    } catch (_) {}
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
