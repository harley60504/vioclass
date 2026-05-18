// Stage 220B: Standalone player-core test page.
//
// This page intentionally does not use WatchPage. It tests the new
// lib/features/twitch/player_core stack in isolation.
//
// Stage 220D:
// - Fix overlay ParentDataWidget conflict. TwitchPlayerView already places the
//   supplied overlay with Positioned.fill, so the overlay itself must not return
//   another Positioned widget.
//
// Stage 220F:
// - Remove the in-video test controls overlay. The right-side control panel is
//   enough for testing, and the overlay covered the actual stream content.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/core/twitch_api_client.dart';
import '../../api/core/twitch_gql_api_service.dart';
import '../../api/playback/twitch_playback_api_service.dart';
import '../../player_core/twitch_player_core.dart';
import '../../services/playback/twitch_playlist_player_runtime.dart';

class TwitchPlayerCoreTestPage extends StatefulWidget {
  const TwitchPlayerCoreTestPage({super.key});

  @override
  State<TwitchPlayerCoreTestPage> createState() => _TwitchPlayerCoreTestPageState();
}

class _TwitchPlayerCoreTestPageState extends State<TwitchPlayerCoreTestPage> {
  late final TextEditingController _channelController;
  late final TextEditingController _urlController;
  late final TwitchApiClient _apiClient;
  late final TwitchPlaylistPlayerRuntime _playlistRuntime;
  late final TwitchPlayerController _playerController;

  bool _loadingChannel = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _channelController = TextEditingController(text: 'roger9527');
    _urlController = TextEditingController();

    _apiClient = TwitchApiClient();
    _playlistRuntime = TwitchPlaylistPlayerRuntime(
      playbackApi: TwitchPlaybackApiService(
        gql: TwitchGqlApiService(client: _apiClient),
      ),
    );
    _playerController = TwitchPlayerController();
  }

  @override
  void dispose() {
    _channelController.dispose();
    _urlController.dispose();
    _playlistRuntime.dispose();
    _apiClient.close(force: true);
    unawaited(_playerController.disposeAsync());
    super.dispose();
  }

  Future<void> _openUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _setStatus('請先貼上 m3u8 / proxy / media URL。');
      return;
    }

    try {
      _setStatus('Opening direct URL...');
      await _playerController.open(uri: url, play: true, force: true);
      _setStatus('Direct URL opened.');
    } catch (error) {
      _setStatus('Open URL failed: $error');
    }
  }

  Future<void> _openChannel() async {
    if (_loadingChannel) return;
    final channel = _channelController.text.trim().toLowerCase();
    if (channel.isEmpty) {
      _setStatus('請先輸入 channel login。');
      return;
    }

    setState(() => _loadingChannel = true);
    try {
      _setStatus('Loading Twitch playlist for $channel...');
      final uri = await _playlistRuntime.loadLivePlaylist(channelLogin: channel);
      final url = uri?.toString().trim() ?? '';
      if (url.isEmpty) {
        throw StateError(_playlistRuntime.error?.toString() ?? 'No playable URL returned.');
      }

      _urlController.text = url;
      _setStatus('Opening proxy URL for $channel...');
      await _playerController.open(uri: url, play: true, force: true);
      _setStatus('Playing $channel via ${_playlistRuntime.currentVariant?.displayName ?? 'auto'}.');
    } catch (error) {
      _setStatus('Open channel failed: $error');
    } finally {
      if (mounted) setState(() => _loadingChannel = false);
    }
  }

  Future<void> _stop() async {
    await _playerController.stop();
    _setStatus('Stopped.');
  }

  void _setStatus(String message) {
    if (!mounted) return;
    setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        title: const Text('Twitch Player Core Test'),
        backgroundColor: const Color(0xFF18181B),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final controls = _ControlPanel(
              channelController: _channelController,
              urlController: _urlController,
              loadingChannel: _loadingChannel,
              status: _status,
              playerController: _playerController,
              playlistRuntime: _playlistRuntime,
              onOpenChannel: _openChannel,
              onOpenUrl: _openUrl,
              onStop: _stop,
            );
            final player = _PlayerPanel(controller: _playerController);

            if (isWide) {
              return Row(
                children: [
                  Expanded(flex: 3, child: player),
                  const VerticalDivider(width: 1, color: Color(0x22FFFFFF)),
                  SizedBox(width: 420, child: controls),
                ],
              );
            }

            return Column(
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: player),
                const Divider(height: 1, color: Color(0x22FFFFFF)),
                Expanded(child: controls),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final TwitchPlayerController controller;

  const _PlayerPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: TwitchPlayerView(
        controller: controller,
        showDebugOverlay: true,
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final TextEditingController channelController;
  final TextEditingController urlController;
  final bool loadingChannel;
  final String? status;
  final TwitchPlayerController playerController;
  final TwitchPlaylistPlayerRuntime playlistRuntime;
  final Future<void> Function() onOpenChannel;
  final Future<void> Function() onOpenUrl;
  final Future<void> Function() onStop;

  const _ControlPanel({
    required this.channelController,
    required this.urlController,
    required this.loadingChannel,
    required this.status,
    required this.playerController,
    required this.playlistRuntime,
    required this.onOpenChannel,
    required this.onOpenUrl,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([playerController, playlistRuntime]),
      builder: (context, _) {
        final playerState = playerController.state;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Standalone player_core test',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '這頁不依賴 WatchPage，只測新的 TwitchPlayerController / Engine / View。',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: channelController,
              decoration: const InputDecoration(
                labelText: 'Twitch channel login',
                hintText: '例如 roger9527',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => unawaited(onOpenChannel()),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: loadingChannel ? null : () => unawaited(onOpenChannel()),
              icon: loadingChannel
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.live_tv_rounded),
              label: const Text('Load channel via Twitch playlist runtime'),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: urlController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Direct media URL',
                hintText: '貼上 m3u8 / local proxy / media URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(onOpenUrl()),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Open URL'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => unawaited(onStop()),
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _DebugSection(
              status: status,
              playerState: playerState,
              playlistRuntime: playlistRuntime,
            ),
          ],
        );
      },
    );
  }
}

class _DebugSection extends StatelessWidget {
  final String? status;
  final dynamic playerState;
  final TwitchPlaylistPlayerRuntime playlistRuntime;

  const _DebugSection({
    required this.status,
    required this.playerState,
    required this.playlistRuntime,
  });

  @override
  Widget build(BuildContext context) {
    final playerJson = playerState.toJson();
    final playlistJson = playlistRuntime.toJson();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Debug',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text('status: ${status ?? '-'}'),
              const Divider(height: 20, color: Color(0x22FFFFFF)),
              Text('player: $playerJson'),
              const Divider(height: 20, color: Color(0x22FFFFFF)),
              Text('playlist: $playlistJson'),
            ],
          ),
        ),
      ),
    );
  }
}
