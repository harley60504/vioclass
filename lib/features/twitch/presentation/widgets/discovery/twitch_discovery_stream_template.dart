// PATCH VERSION: twitch_discovery_stream_template_stage135_watch_route_guard
// Shared discovery stream grid for FollowingPage and BrowsePage.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../pages/twitch_watch_route_guard.dart';
import 'twitch_stream_card.dart';

class TwitchDiscoveryStreamGrid extends StatelessWidget {
  final ScrollController controller;
  final IconData sectionIcon;
  final String sectionTitle;
  final int streamCount;
  final List<TwitchLiveStream> streams;
  final Widget footer;

  const TwitchDiscoveryStreamGrid({
    super.key,
    required this.controller,
    required this.sectionIcon,
    required this.sectionTitle,
    required this.streamCount,
    required this.streams,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mainAxisExtent = twitchStreamCardGridMainAxisExtent(width);

        return CustomScrollView(
          key: PageStorageKey<String>('twitch_discovery_grid_$sectionTitle'),
          controller: controller,
          cacheExtent: 840,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: TwitchDiscoverySectionHeader(
                icon: sectionIcon,
                title: sectionTitle,
                count: streamCount,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: twitchStreamCardGridMaxCrossAxisExtent,
                  mainAxisExtent: mainAxisExtent,
                  crossAxisSpacing: twitchStreamCardGridSpacing,
                  mainAxisSpacing: twitchStreamCardGridSpacing,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final stream = streams[index];
                    return RepaintBoundary(
                      child: TwitchStreamCard(
                        stream: stream,
                        onTap: () => _openWatchPage(context, stream),
                      ),
                    );
                  },
                  childCount: streams.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              ),
            ),
            SliverToBoxAdapter(child: footer),
          ],
        );
      },
    );
  }

  void _openWatchPage(BuildContext context, TwitchLiveStream stream) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TwitchWatchRouteGuard(
          initialMetadata: TwitchStreamHeaderMetadata.fromLiveStream(stream),
        ),
      ),
    );
  }
}

class TwitchDiscoverySectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const TwitchDiscoverySectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
      child: Row(
        children: <Widget>[
          Icon(icon, color: const Color(0xFF9146FF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count > 0 ? '$title · $count' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TwitchDiscoveryFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasMore;
  final String? errorText;
  final Future<void> Function() onLoadMore;

  const TwitchDiscoveryFooter({
    super.key,
    required this.loadingMore,
    required this.hasMore,
    required this.errorText,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF9146FF)),
        ),
      );
    }

    if (errorText != null && errorText!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () {
              unawaited(onLoadMore());
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('載入更多失敗，重試'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBF94FF),
              side: const BorderSide(color: Color(0xFF9146FF)),
            ),
          ),
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Center(
          child: TextButton.icon(
            onPressed: () {
              unawaited(onLoadMore());
            },
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            label: const Text('載入更多'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFBF94FF),
            ),
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 26),
      child: Center(
        child: Text(
          '已經到底了',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class TwitchDiscoveryEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const TwitchDiscoveryEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: const Color(0xFF9146FF), size: 46),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新整理'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBF94FF),
                  side: const BorderSide(color: Color(0xFF9146FF)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
