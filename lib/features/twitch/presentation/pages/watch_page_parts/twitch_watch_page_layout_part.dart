part of '../twitch_watch_page.dart';

extension _TwitchWatchPageLayoutPart on _TwitchWatchPageState {
  Widget _buildWatchBody(BuildContext context) {
    final runtime = _chatRuntime;
    final metadata = widget.resolvedInitialMetadata.copyWith(channelLogin: _channelLogin);

    Widget buildPlayerArea() {
      return TwitchWatchPlayerAreaPortAdapter(
        metadata: metadata,
        loading: _loadingPlayer,
        error: _playerError,
        isFollowing: _isFollowing,
        relationshipBusy: _checkingRelationship || _followBusy || _relationshipBootstrapping,
        relationshipError: _relationshipError,
        onToggleFollow: _toggleFollowChannel,
        onSubscribe: _openSubscribePage,
        chatVisible: _chatVisible,
        fullscreenMode: _fullscreenMode,
        showFullscreenButton: TwitchFullscreenController.isDesktopPlatform,
        onToggleChat: _toggleChatVisibility,
        onToggleFullscreen: () => unawaited(_toggleFullscreenMode()),
        muted: _isMuted,
        volume: _volume,
        onToggleMute: () => unawaited(_togglePlayerMute()),
        onVolumeChanged: (value) => unawaited(_setPlayerVolume(value)),
        onBack: () => Navigator.of(context).maybePop(),
        onReload: _busy ? null : _loadWatch,
        onStop: () => _stopCurrentSession(),
        onError: (message) {
          if (!mounted) return;
          setState(() => _playerError = message);
          _showSnack('播放器操作失敗：$message');
        },
      );
    }

    Widget buildChatPanel() {
      return TwitchWatchChatPanelPortAdapter(
        runtime: runtime,
        viewerLogin: _viewerLogin,
        viewerId: _viewerId,
        metadata: metadata,
        channelPoints: _channelPointsSnapshot,
        pinnedMessages: _pinnedMessages,
        prediction: _prediction,
        loadingEmotes: _loadingEmotes || _emoteBootstrapping,
        loadingEngagement: _loadingEngagement || _engagementBootstrapping,
        engagementError: _engagementError,
        messageController: _messageController,
        sending: _sending,
        onSend: _sendMessage,
        onOpenEmotes: _openEmotePicker,
        onRefreshEmotes: () => _loadThirdPartyEmotes(forceRefresh: true),
        onRefreshEngagement: () => _refreshEngagement(showSnackOnError: true),
        onOpenChannelPoints: _openChannelPointsSheet,
        onOpenPrediction: _openPredictionBetSheet,
      );
    }

    Widget buildMainBody() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final layout = TwitchResponsiveLayout.fromConstraints(constraints);

          if (layout.shouldUseBottomChat) {
            final preferredPlayerHeight =
                (layout.width * 9 / 16).clamp(160.0, 320.0).toDouble();
            final maxPlayerHeightWithChat =
                (layout.height - 430.0).clamp(150.0, 320.0).toDouble();
            final playerHeight = _chatVisible
                ? preferredPlayerHeight.clamp(150.0, maxPlayerHeightWithChat).toDouble()
                : layout.height;

            return Column(
              children: [
                SizedBox(
                  height: playerHeight,
                  width: double.infinity,
                  child: buildPlayerArea(),
                ),
                if (_chatVisible)
                  const Divider(height: 1, thickness: 1, color: Color(0xFF24242A)),
                if (_chatVisible) Expanded(child: buildChatPanel()),
              ],
            );
          }

          final effectiveChatWidth = _effectiveChatPanelWidthForViewport(layout);
          return Row(
            children: [
              Expanded(
                flex: layout.isPhoneLandscape ? 10 : 1,
                child: buildPlayerArea(),
              ),
              if (_chatVisible)
                SizedBox(
                  width: effectiveChatWidth,
                  child: Stack(
                    children: [
                      Positioned.fill(child: buildChatPanel()),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 10,
                        child: _ChatResizeHandle(
                          onDragUpdate: (delta) {
                            final currentChatWidth =
                                _chatPanelWidth > 0 ? _chatPanelWidth : effectiveChatWidth;
                            _setChatPanelWidthForViewport(
                              viewportWidth: layout.width,
                              value: currentChatWidth - delta.delta.dx,
                            );
                          },
                          onDragEnd: () {
                            _chatWidthPreferenceSaveDebounce?.cancel();
                            unawaited(_saveChatPanelWidthPreference());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: Stack(
        children: [
          Positioned.fill(child: buildMainBody()),
          if (_showBlockingStartupMask)
            Positioned.fill(
              child: _WatchBlockingStartupOverlay(
                title: _startupMaskTitle,
                subtitle: '正在啟動播放器與聊天室，互動資料會在背景載入。',
              ),
            ),
        ],
      ),
    );
  }
}
