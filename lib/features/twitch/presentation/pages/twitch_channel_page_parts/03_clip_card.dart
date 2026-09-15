part of '../twitch_channel_page.dart';

class _ClipCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final TwitchChannelClip clip;

  const _ClipCard({
    required this.discoveryService,
    required this.channel,
    required this.clip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: clip.id.trim().isEmpty
            ? null
            : () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TwitchWatchPage(
                      initialMetadata: TwitchStreamHeaderMetadata(
                        channelLogin: channel.channelLogin,
                        streamTitle: clip.title,
                        profileImageUrl: channel.profileImageUrl,
                      ),
                      initialOfflineChannel: channel,
                      initialDiscoveryService: discoveryService,
                      initialClip: clip,
                    ),
                  ),
                );
              },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.060),
                Colors.white.withValues(alpha: 0.020),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const infoHeight = 72.0;
              final thumbnailHeight = (constraints.maxHeight - infoHeight)
                  .clamp(1.0, constraints.maxHeight)
                  .toDouble();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: thumbnailHeight,
                    width: double.infinity,
                    child: _ClipThumbnail(clip: clip),
                  ),
                  SizedBox(
                    height: infoHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clip.title.trim().isEmpty
                                ? l10n.t('未命名片段')
                                : clip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(child: _ClipMetaText(clip: clip)),
                              const Icon(
                                Icons.play_circle_outline_rounded,
                                color: TwitchUiColors.primarySoft,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClipThumbnail extends StatelessWidget {
  final TwitchChannelClip clip;

  const _ClipThumbnail({required this.clip});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return TwitchCachedImageLayer(
              imageUrl: clip.thumbnailUrl,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fit: BoxFit.cover,
              fallbackColor: Colors.white.withValues(alpha: 0.06),
              fallbackIcon: Icons.movie_filter_outlined,
              fallbackIconColor: Colors.white38,
            );
          },
        ),
        Positioned(
          left: 8,
          top: 8,
          child: _VodPill(text: _formatClipViews(context, clip.viewCount)),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _VodPill(text: '${clip.duration.toStringAsFixed(1)}s'),
        ),
      ],
    );
  }

  String _formatClipViews(BuildContext context, int value) {
    if (context.vio.isEnglish && value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (context.vio.isEnglish && value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}萬';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _ClipMetaText extends StatelessWidget {
  final TwitchChannelClip clip;

  const _ClipMetaText({required this.clip});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(clip.createdAt);
    final creator = clip.creatorName.trim();
    final l10n = context.vio;
    return Text(
      '${creator.isEmpty ? l10n.t('已建立片段') : '${l10n.t('由')} $creator ${l10n.t('建立片段-meta')}'}'
      '${date.isEmpty ? '' : ' · $date'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _VodTab extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final List<TwitchChannelVideo> videos;
  final TextEditingController searchController;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final bool loadingFirstPage;
  final bool loadingMore;
  final bool hasMore;
  final String? errorText;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  const _VodTab({
    required this.discoveryService,
    required this.channel,
    required this.videos,
    required this.searchController,
    required this.searchText,
    required this.onSearchChanged,
    required this.loadingFirstPage,
    required this.loadingMore,
    required this.hasMore,
    required this.errorText,
    required this.onRetry,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final filteredVideos = _filterVideos(videos, searchText);

    if (loadingFirstPage) {
      return const Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primary),
      );
    }

    final error = errorText?.trim();
    if (videos.isEmpty && error != null && error.isNotEmpty) {
      return _CenteredAction(
        icon: Icons.error_outline_rounded,
        title: l10n.t('VOD 讀取失敗'),
        message: l10n.t('VOD 暫時讀取失敗，稍後再試或重新整理。'),
        actionLabel: l10n.t('重試'),
        onPressed: onRetry,
      );
    }

    if (videos.isEmpty) {
      return _CenteredAction(
        icon: Icons.video_library_outlined,
        title: l10n.t('目前沒有 VOD'),
        message: l10n.t('這個頻道沒有可顯示的過去直播。'),
        actionLabel: l10n.t('重新整理'),
        onPressed: onRetry,
      );
    }

    if (filteredVideos.isEmpty) {
      return CustomScrollView(
        slivers: [
          _mediaSearchSliver(
            context: context,
            controller: searchController,
            hintText: l10n.t('搜尋 VOD'),
            onChanged: onSearchChanged,
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CenteredAction(
              icon: Icons.search_off_rounded,
              title: l10n.t('找不到符合的 VOD'),
              message: l10n.t('可以換個關鍵字，或清空搜尋回到全部 VOD。'),
              actionLabel: l10n.t('清空搜尋'),
              onPressed: () {
                searchController.clear();
                onSearchChanged('');
              },
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        _mediaSearchSliver(
          context: context,
          controller: searchController,
          hintText: l10n.t('搜尋 VOD'),
          onChanged: onSearchChanged,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              childAspectRatio: 1.35,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return _VodCard(
                discoveryService: discoveryService,
                channel: channel,
                video: filteredVideos[index],
              );
            }, childCount: filteredVideos.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            child: Center(
              child: hasMore
                  ? FilledButton.icon(
                      onPressed: loadingMore ? null : onLoadMore,
                      icon: loadingMore
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TwitchUiColors.primarySoft,
                              ),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(l10n.t(loadingMore ? '載入中' : '載入更多')),
                    )
                  : Text(
                      l10n.t('已顯示目前可讀取的 VOD'),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  List<TwitchChannelVideo> _filterVideos(
    List<TwitchChannelVideo> videos,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return videos;
    return videos
        .where((video) {
          return video.title.toLowerCase().contains(keyword) ||
              video.description.toLowerCase().contains(keyword) ||
              video.userName.toLowerCase().contains(keyword);
        })
        .toList(growable: false);
  }
}

class _VodCard extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final TwitchChannelVideo video;

  const _VodCard({
    required this.discoveryService,
    required this.channel,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.vio;
    final thumbnail = video.thumbnail();
    final isGrowingArchive = video.isLikelyGrowingArchive;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => TwitchWatchPage(
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
              ),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.062),
                Colors.white.withValues(alpha: 0.022),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const infoHeight = 78.0;
              final thumbnailHeight = (constraints.maxHeight - infoHeight)
                  .clamp(1.0, constraints.maxHeight)
                  .toDouble();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: thumbnailHeight,
                    width: double.infinity,
                    child: _VodThumbnail(
                      thumbnail: thumbnail,
                      video: video,
                      isGrowingArchive: isGrowingArchive,
                    ),
                  ),
                  SizedBox(
                    height: infoHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title.trim().isEmpty
                                ? l10n.t('未命名 VOD')
                                : video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: _VodMetaText(
                                  video: video,
                                  isGrowingArchive: isGrowingArchive,
                                ),
                              ),
                              Icon(
                                isGrowingArchive
                                    ? Icons.sensors_rounded
                                    : Icons.play_circle_outline_rounded,
                                color: TwitchUiColors.primarySoft,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VodThumbnail extends StatelessWidget {
  final String thumbnail;
  final TwitchChannelVideo video;
  final bool isGrowingArchive;

  const _VodThumbnail({
    required this.thumbnail,
    required this.video,
    required this.isGrowingArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return TwitchCachedImageLayer(
              imageUrl: thumbnail,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fit: BoxFit.cover,
              fallbackColor: Colors.white.withValues(alpha: 0.06),
              fallbackIcon: Icons.video_library_outlined,
              fallbackIconColor: Colors.white38,
            );
          },
        ),
        Positioned(right: 8, bottom: 8, child: _VodPill(text: video.duration)),
        if (isGrowingArchive)
          Positioned(
            left: 8,
            top: 8,
            child: _VodPill(text: context.vio.t('直播存檔中')),
          ),
      ],
    );
  }
}
