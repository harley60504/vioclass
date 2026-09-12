part of '../twitch_stream_page.dart';

class _TwitchChannelSearchPage extends StatelessWidget {
  final String query;
  final List<TwitchLiveStream> liveStreams;
  final List<TwitchFollowedChannel> offlineChannels;
  final List<_TwitchSearchVideoResult> videos;
  final List<_TwitchSearchClipResult> clips;
  final TwitchFollowStatusResolver followStatusFor;
  final bool loading;
  final String? errorText;
  final TwitchDiscoveryService discoveryService;
  final Future<void> Function() onRefresh;

  const _TwitchChannelSearchPage({
    super.key,
    required this.query,
    required this.liveStreams,
    required this.offlineChannels,
    required this.videos,
    required this.clips,
    required this.followStatusFor,
    required this.loading,
    required this.errorText,
    required this.discoveryService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults =
        liveStreams.isNotEmpty ||
        offlineChannels.isNotEmpty ||
        videos.isNotEmpty ||
        clips.isNotEmpty;
    final followedLiveStreams = liveStreams
        .where(_isFollowedStream)
        .toList(growable: false);
    final otherLiveStreams = liveStreams
        .where((stream) => !_isFollowedStream(stream))
        .toList(growable: false);
    final followedOfflineChannels = offlineChannels
        .where(_isFollowedChannel)
        .toList(growable: false);
    final otherOfflineChannels = offlineChannels
        .where((channel) => !_isFollowedChannel(channel))
        .toList(growable: false);
    final followedCount =
        followedLiveStreams.length + followedOfflineChannels.length;

    if (!loading && !hasResults) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.search_off_rounded,
        title: '找不到符合條件的頻道',
        message: errorText?.trim().isNotEmpty == true
            ? 'Twitch 頻道搜尋暫時失敗，稍後再試。'
            : '可以換個實況主名稱或登入名稱搜尋。',
        onRetry: onRefresh,
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.72, -0.92),
          radius: 1.35,
          colors: <Color>[
            Color(0xFF24133A),
            Color(0xFF14121E),
            Color(0xFF0A0A0F),
          ],
          stops: <double>[0.0, 0.46, 1.0],
        ),
      ),
      child: RefreshIndicator(
        color: TwitchUiColors.primary,
        onRefresh: onRefresh,
        child: CustomScrollView(
          key: const PageStorageKey<String>('twitch_channel_search_page'),
          physics: const AlwaysScrollableScrollPhysics(),
          scrollCacheExtent: const ScrollCacheExtent.pixels(840),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: TwitchDiscoverySectionHeader(
                icon: Icons.search_rounded,
                title: '搜尋結果',
                count:
                    liveStreams.length +
                    offlineChannels.length +
                    videos.length +
                    clips.length,
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(26, 0, 26, 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: TwitchUiColors.primary,
                          strokeWidth: 2.4,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        '正在搜尋...',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (followedCount > 0) ...[
              if (followedLiveStreams.isNotEmpty)
                TwitchDiscoveryStreamSliverSection(
                  icon: Icons.favorite_rounded,
                  title: '已追隨 · 直播中',
                  streams: followedLiveStreams,
                  discoveryService: discoveryService,
                  onReturnFromStream: onRefresh,
                  followStatusFor: followStatusFor,
                  streamKnownFollowing: true,
                ),
              if (followedOfflineChannels.isNotEmpty)
                ..._offlineChannelSlivers(
                  icon: Icons.favorite_border_rounded,
                  title: '已追隨 · 未開台',
                  channels: followedOfflineChannels,
                  knownFollowing: true,
                ),
            ],
            if (otherLiveStreams.isNotEmpty)
              TwitchDiscoveryStreamSliverSection(
                icon: Icons.live_tv_rounded,
                title: '其他頻道 · 直播中',
                streams: otherLiveStreams,
                discoveryService: discoveryService,
                onReturnFromStream: onRefresh,
                followStatusFor: followStatusFor,
              ),
            if (otherOfflineChannels.isNotEmpty)
              ..._offlineChannelSlivers(
                icon: Icons.tv_off_rounded,
                title: '其他頻道 · 未開台',
                channels: otherOfflineChannels,
              ),
            if (videos.isNotEmpty)
              _mediaSliverSection<_TwitchSearchVideoResult>(
                icon: Icons.video_library_outlined,
                title: '影片',
                items: videos,
                itemBuilder: (context, result) {
                  return _SearchVodCard(
                    discoveryService: discoveryService,
                    result: result,
                    followStatusFor: followStatusFor,
                  );
                },
              ),
            if (clips.isNotEmpty)
              _mediaSliverSection<_TwitchSearchClipResult>(
                icon: Icons.movie_filter_outlined,
                title: '片段',
                items: clips,
                itemBuilder: (context, result) {
                  return _SearchClipCard(
                    discoveryService: discoveryService,
                    result: result,
                    followStatusFor: followStatusFor,
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  bool _isFollowedStream(TwitchLiveStream stream) {
    final id = stream.userId.trim();
    final login = stream.channelLogin;
    return followStatusFor(broadcasterId: id, broadcasterLogin: login) == true;
  }

  bool _isFollowedChannel(TwitchFollowedChannel channel) {
    final id = channel.broadcasterId.trim();
    final login = channel.channelLogin;
    return followStatusFor(broadcasterId: id, broadcasterLogin: login) == true;
  }

  List<Widget> _offlineChannelSlivers({
    required IconData icon,
    required String title,
    required List<TwitchFollowedChannel> channels,
    bool? knownFollowing,
  }) {
    return <Widget>[
      SliverToBoxAdapter(
        child: TwitchDiscoverySectionHeader(
          icon: icon,
          title: title,
          count: channels.length,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisExtent: 168,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            return TwitchOfflineChannelCard(
              channel: channels[index],
              discoveryService: discoveryService,
              initialKnownFollowing:
                  knownFollowing ??
                  followStatusFor(
                    broadcasterId: channels[index].broadcasterId,
                    broadcasterLogin: channels[index].channelLogin,
                  ),
            );
          }, childCount: channels.length),
        ),
      ),
    ];
  }

  Widget _mediaSliverSection<T>({
    required IconData icon,
    required String title,
    required List<T> items,
    required Widget Function(BuildContext context, T item) itemBuilder,
  }) {
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: TwitchDiscoverySectionHeader(
            icon: icon,
            title: title,
            count: items.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 238,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return itemBuilder(context, items[index]);
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }
}

class _TwitchSearchMediaBundle {
  final List<_TwitchSearchVideoResult> videos;
  final List<_TwitchSearchClipResult> clips;

  const _TwitchSearchMediaBundle({required this.videos, required this.clips});

  const _TwitchSearchMediaBundle.empty()
    : videos = const <_TwitchSearchVideoResult>[],
      clips = const <_TwitchSearchClipResult>[];
}

class _TwitchSearchVideoResult {
  final TwitchFollowedChannel channel;
  final TwitchChannelVideo video;

  const _TwitchSearchVideoResult({required this.channel, required this.video});
}

class _TwitchSearchClipResult {
  final TwitchFollowedChannel channel;
  final TwitchChannelClip clip;

  const _TwitchSearchClipResult({required this.channel, required this.clip});
}

class _SearchVodCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final _TwitchSearchVideoResult result;
  final TwitchFollowStatusResolver followStatusFor;

  const _SearchVodCard({
    required this.discoveryService,
    required this.result,
    required this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    final video = result.video;
    final channel = result.channel;
    final isGrowingArchive = video.isLikelyGrowingArchive;

    return _SearchMediaCardFrame(
      thumbnailUrl: video.thumbnail(),
      fallbackIcon: Icons.video_library_outlined,
      topLeftPill: isGrowingArchive ? '直播存檔中' : 'VOD',
      bottomRightPill: video.duration,
      title: video.title.trim().isEmpty ? '未命名 VOD' : video.title,
      subtitle: '${channel.displayName} · ${_formatCount(video.viewCount)} 次觀看',
      avatarUrl: channel.profileImageUrl,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata(
                channelLogin: channel.channelLogin,
                streamTitle: video.title,
                language: video.language,
                profileImageUrl: channel.profileImageUrl,
              ),
              initialOfflineChannel: channel,
              initialDiscoveryService: discoveryService,
              initialActiveDvrVideo: isGrowingArchive ? video : null,
              initialVodVideo: isGrowingArchive ? null : video,
              initialVodPlaybackOnly: !isGrowingArchive,
              initialKnownFollowing: followStatusFor(
                broadcasterId: channel.broadcasterId,
                broadcasterLogin: channel.channelLogin,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchClipCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final _TwitchSearchClipResult result;
  final TwitchFollowStatusResolver followStatusFor;

  const _SearchClipCard({
    required this.discoveryService,
    required this.result,
    required this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    final clip = result.clip;
    final channel = result.channel;

    return _SearchMediaCardFrame(
      thumbnailUrl: clip.thumbnailUrl,
      fallbackIcon: Icons.movie_filter_outlined,
      topLeftPill: '片段',
      bottomRightPill: '${clip.duration.toStringAsFixed(1)}s',
      title: clip.title.trim().isEmpty ? '未命名片段' : clip.title,
      subtitle: '${channel.displayName} · ${_formatCount(clip.viewCount)} 次觀看',
      avatarUrl: channel.profileImageUrl,
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata(
                channelLogin: channel.channelLogin,
                streamTitle: clip.title,
                language: clip.language,
                profileImageUrl: channel.profileImageUrl,
              ),
              initialOfflineChannel: channel,
              initialDiscoveryService: discoveryService,
              initialClip: clip,
              initialKnownFollowing: followStatusFor(
                broadcasterId: channel.broadcasterId,
                broadcasterLogin: channel.channelLogin,
              ),
            ),
          ),
        );
      },
    );
  }
}
