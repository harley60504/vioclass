part of '../twitch_stream_page.dart';

extension _TwitchStreamPageStatePlaybackOps on _TwitchStreamPageState {
  void _syncRootAutoPip() {
    final pip = TwitchAndroidPipController.instance;
    final hasPlayback =
        TwitchPlaybackSessionController.instance.playableState != null ||
        TwitchMiniPlayerController.instance.isActive;
    final enabled =
        playerSettingsController.androidPipEnabled &&
        hasPlayback &&
        !pip.stoppedOutsidePictureInPicture;
    unawaited(TwitchAndroidPipController.instance.setAutoEnterEnabled(enabled));
  }

  Future<void> _suspendPlaybackOutsidePictureInPicture() async {
    TwitchAndroidPipController.instance
        .acknowledgeStoppedOutsidePictureInPicture();
    TwitchMiniPlayerController.instance.close(pausePlayback: true);
    TwitchPlaybackSessionController.instance.clear();
    await TwitchMediaKitPlayerHost.pauseShared();
    TwitchMediaKitPlayerHost.keepPlayingWithoutSession(null);
  }
}

extension _TwitchStreamPageStateCoreOps on _TwitchStreamPageState {
  Future<void> _enterPictureInPictureFromRootBack() async {
    if (!_shouldBackEnterPictureInPicture) return;
    await TwitchAndroidPipController.instance.enterPictureInPicture(
      aspectRatioWidth: 16,
      aspectRatioHeight: 9,
    );
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  Widget _buildDesktopShell(TwitchResponsiveLayout layout) {
    return Row(
      children: <Widget>[
        TwitchStreamHomeSidebar(
          selectedSection: selectedSection,
          viewerLabel: viewerLabel,
          loginStatus: loginStatus,
          loadingLoginState: loadingLoginState,
          onSelectSection: selectSection,
        ),
        Expanded(child: this._buildContentColumn(layout)),
      ],
    );
  }

  Widget _buildMobileShell(TwitchResponsiveLayout layout) {
    return Column(
      children: <Widget>[
        Expanded(child: this._buildContentColumn(layout)),
        TwitchStreamHomeBottomNavigation(
          selectedSection: selectedSection,
          onSelectSection: selectSection,
        ),
      ],
    );
  }

  Widget _buildContentColumn(TwitchResponsiveLayout layout) {
    return Column(
      children: <Widget>[
        TwitchStreamHomeToolbar(
          selectedSection: selectedSection,
          searchController: searchController,
          forceTwoRows: layout.shouldUseTwoRowHomeToolbar,
          onSearchChanged: updateSearchText,
          onClearSearch: () {
            searchController.clear();
            updateSearchText('');
          },
          onShowGameMenu: showCurrentGameMenu,
          onShowLanguageMenu: showCurrentLanguageMenu,
          onRefresh: refreshCurrentPage,
          onOpenDropsConnector: openDropsConnectorPage,
          onOpenSettings: openSettings,
        ),
        Expanded(child: this._buildHomeContent()),
      ],
    );
  }

  Widget _buildHomeContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: searchText.isNotEmpty
          ? _TwitchChannelSearchPage(
              key: const ValueKey<String>('twitch-channel-search-page'),
              query: searchText,
              liveStreams: searchedLiveStreams,
              offlineChannels: searchedOfflineChannels,
              videos: searchedVideos,
              clips: searchedClips,
              followStatusFor: knownFollowStatusFor,
              loading: loadingChannelSearch,
              errorText: channelSearchError,
              discoveryService: discoveryService,
              onRefresh: refreshChannelSearch,
            )
          : selectedSection == TwitchHomeSection.following
          ? TwitchFollowingPage(
              key: followingPageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              searchedLiveStreams: searchedLiveStreams,
              searchedOfflineChannels: searchedOfflineChannels,
              loadingChannelSearch: loadingChannelSearch,
              channelSearchError: channelSearchError,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
              onFollowedChannelsChanged: rememberFollowedChannels,
              followStatusFor: knownFollowStatusFor,
            )
          : TwitchBrowsePage(
              key: browsePageKey,
              discoveryService: discoveryService,
              searchText: searchText,
              searchedLiveStreams: searchedLiveStreams,
              searchedOfflineChannels: searchedOfflineChannels,
              loadingChannelSearch: loadingChannelSearch,
              channelSearchError: channelSearchError,
              reloadTick: reloadTick,
              onLoginPressed: runLinkedTwitchLoginFlow,
              followStatusFor: knownFollowStatusFor,
            ),
    );
  }
}

extension _TwitchStreamPageStateSessionOps on _TwitchStreamPageState {
  Future<void> _loadUpdateSettingsAndCheck() async {
    await updateController.load();
    if (!mounted || !updateController.autoCheckEnabled) return;
    final info = await updateController.checkNow();
    if (!mounted || info?.updateAvailable != true) return;
    unawaited(
      showVioClassUpdateSheet(
        context: context,
        controller: updateController,
        startupPrompt: true,
      ),
    );
  }
}

extension _TwitchStreamPageStateSearchOps on _TwitchStreamPageState {
  Future<_TwitchSearchMediaBundle> _searchChannelMedia({
    required String keyword,
    required List<TwitchLiveStream> liveStreams,
    required List<TwitchFollowedChannel> offlineChannels,
  }) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    if (cleanKeyword.isEmpty) return const _TwitchSearchMediaBundle.empty();

    final candidates = this._searchMediaCandidateChannels(
      liveStreams: liveStreams,
      offlineChannels: offlineChannels,
    );
    if (candidates.isEmpty) return const _TwitchSearchMediaBundle.empty();

    final videoResults = <_TwitchSearchVideoResult>[];
    final clipResults = <_TwitchSearchClipResult>[];

    for (final channel in candidates.take(8)) {
      if (videoResults.length < 12) {
        try {
          final page = await discoveryService.fetchChannelVideos(
            userId: channel.broadcasterId,
            first: 8,
          );
          videoResults.addAll(
            page.videos
                .where(
                  (video) => this._matchesSearchMediaVideo(video, cleanKeyword),
                )
                .take(4)
                .map(
                  (video) =>
                      _TwitchSearchVideoResult(channel: channel, video: video),
                ),
          );
        } catch (_) {}
      }

      if (clipResults.length < 12) {
        try {
          final page = await discoveryService.fetchChannelClips(
            broadcasterId: channel.broadcasterId,
            first: 8,
          );
          clipResults.addAll(
            page.clips
                .where(
                  (clip) => this._matchesSearchMediaClip(clip, cleanKeyword),
                )
                .take(4)
                .map(
                  (clip) =>
                      _TwitchSearchClipResult(channel: channel, clip: clip),
                ),
          );
        } catch (_) {}
      }

      if (videoResults.length >= 12 && clipResults.length >= 12) break;
    }

    return _TwitchSearchMediaBundle(
      videos: videoResults.take(12).toList(growable: false),
      clips: clipResults.take(12).toList(growable: false),
    );
  }

  List<TwitchFollowedChannel> _searchMediaCandidateChannels({
    required List<TwitchLiveStream> liveStreams,
    required List<TwitchFollowedChannel> offlineChannels,
  }) {
    final byId = <String, TwitchFollowedChannel>{};

    for (final channel in offlineChannels) {
      final id = channel.broadcasterId.trim();
      if (id.isEmpty) continue;
      byId[id] = channel;
    }

    for (final stream in liveStreams) {
      final id = stream.userId.trim();
      if (id.isEmpty || byId.containsKey(id)) continue;
      byId[id] = TwitchFollowedChannel(
        broadcasterId: id,
        broadcasterLogin: stream.channelLogin,
        broadcasterName: stream.displayName,
        followedAt: null,
        profileImageUrl: stream.profileImageUrl,
        description: stream.title,
      );
    }

    return byId.values.toList(growable: false);
  }

  bool _matchesSearchMediaVideo(TwitchChannelVideo video, String keyword) {
    return video.title.toLowerCase().contains(keyword) ||
        video.userName.toLowerCase().contains(keyword);
  }

  bool _matchesSearchMediaClip(TwitchChannelClip clip, String keyword) {
    return clip.title.toLowerCase().contains(keyword) ||
        clip.broadcasterName.toLowerCase().contains(keyword) ||
        clip.creatorName.toLowerCase().contains(keyword);
  }
}
