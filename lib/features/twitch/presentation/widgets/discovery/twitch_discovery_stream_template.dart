// PATCH VERSION: twitch_discovery_stream_template_stage219m_emote_only_route_fix
// Shared discovery stream grid for FollowingPage and BrowsePage.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../pages/twitch_emote_only_test_page.dart';
import '../../pages/twitch_watch_route_guard.dart';
import 'twitch_stream_card.dart';

const bool _openEmoteOnlyFromDiscovery = bool.fromEnvironment(
  'TWITCH_EMOTE_ONLY_FROM_DISCOVERY',
  defaultValue: false,
);

class TwitchDiscoveryStreamGrid extends StatelessWidget {
  final ScrollController controller;
  final IconData sectionIcon;
  final String sectionTitle;
  final int streamCount;
  final List<TwitchLiveStream> streams;
  final Widget footer;
  final Future<void> Function()? onReturnFromStream;

  const TwitchDiscoveryStreamGrid({
    super.key,
    required this.controller,
    required this.sectionIcon,
    required this.sectionTitle,
    required this.streamCount,
    required this.streams,
    required this.footer,
    this.onReturnFromStream,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mainAxisExtent = twitchStreamCardGridMainAxisExtent(width);

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
          child: Stack(
            children: <Widget>[
              const Positioned(
                left: -140,
                top: -180,
                width: 520,
                height: 520,
                child: _DiscoveryGlowOrb(color: Color(0x559146FF)),
              ),
              const Positioned(
                right: -220,
                bottom: -240,
                width: 620,
                height: 620,
                child: _DiscoveryGlowOrb(color: Color(0x335B2D91)),
              ),
              CustomScrollView(
                key: PageStorageKey<String>(
                  'twitch_discovery_grid_$sectionTitle',
                ),
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
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            twitchStreamCardGridMaxCrossAxisExtent,
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
                              onTap: () => _openStreamTarget(context, stream),
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStreamTarget(BuildContext context, TwitchLiveStream stream) {
    if (_openEmoteOnlyFromDiscovery) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TwitchEmoteOnlyTestPage(
            initialChannelLogin: stream.channelLogin,
            initialChannelId: stream.userId,
            initialDisplayName: stream.userName,
            autoLoad: true,
          ),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata.fromLiveStream(
                stream,
              ),
            ),
          ),
        )
        .then((_) {
          final callback = onReturnFromStream;
          if (callback != null) unawaited(callback());
        });
  }
}

class _DiscoveryGlowOrb extends StatelessWidget {
  final Color color;

  const _DiscoveryGlowOrb({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0.0)],
          ),
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
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF9146FF).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBF94FF).withValues(alpha: 0.28),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF9146FF).withValues(alpha: 0.26),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFFBF94FF), size: 19),
          ),
          const SizedBox(width: 11),
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
