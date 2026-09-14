// Shared discovery stream grid for FollowingPage and BrowsePage.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../../models/discovery/twitch_stream_header_metadata.dart';
import '../../../services/discovery/twitch_discovery_service.dart';
import '../../localization/vioclass_localizations.dart';
import '../../pages/twitch_watch_route_guard.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../../twitch_follow_status_resolver.dart';
import 'twitch_stream_card.dart';

class TwitchDiscoveryStreamGrid extends StatelessWidget {
  final ScrollController controller;
  final IconData sectionIcon;
  final String sectionTitle;
  final int streamCount;
  final List<TwitchLiveStream> streams;
  final Widget footer;
  final List<Widget> extraSliversAfterHeader;
  final List<Widget> extraSliversBeforeFooter;
  final Future<void> Function()? onReturnFromStream;
  final TwitchDiscoveryService? discoveryService;
  final bool showSectionCount;
  final bool? streamKnownFollowing;
  final TwitchFollowStatusResolver? followStatusFor;

  const TwitchDiscoveryStreamGrid({
    super.key,
    required this.controller,
    required this.sectionIcon,
    required this.sectionTitle,
    required this.streamCount,
    required this.streams,
    required this.footer,
    this.extraSliversAfterHeader = const <Widget>[],
    this.extraSliversBeforeFooter = const <Widget>[],
    this.onReturnFromStream,
    this.discoveryService,
    this.showSectionCount = true,
    this.streamKnownFollowing,
    this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mainAxisExtent = twitchStreamCardGridMainAxisExtent(
          constraints.maxWidth,
        );
        return ColoredBox(
          color: TwitchUiColors.appBackground,
          child: CustomScrollView(
            key: PageStorageKey<String>('twitch_discovery_grid_$sectionTitle'),
            controller: controller,
            scrollCacheExtent: const ScrollCacheExtent.pixels(840),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: TwitchDiscoverySectionHeader(
                  icon: sectionIcon,
                  title: sectionTitle,
                  count: streamCount,
                  showCount: showSectionCount,
                ),
              ),
              ...extraSliversAfterHeader,
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
              ...extraSliversBeforeFooter,
              SliverToBoxAdapter(child: footer),
            ],
          ),
        );
      },
    );
  }

  void _openStreamTarget(BuildContext context, TwitchLiveStream stream) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata.fromLiveStream(stream),
              initialOfflineChannel: TwitchFollowedChannel(
                broadcasterId: stream.userId,
                broadcasterLogin: stream.userLogin,
                broadcasterName: stream.userName,
                followedAt: null,
                profileImageUrl: stream.profileImageUrl,
              ),
              initialDiscoveryService: discoveryService,
              initialKnownFollowing: _knownFollowStatusFor(stream),
            ),
          ),
        )
        .then((_) {
          final callback = onReturnFromStream;
          if (callback != null) unawaited(callback());
        });
  }

  bool? _knownFollowStatusFor(TwitchLiveStream stream) {
    final explicitStatus = streamKnownFollowing;
    if (explicitStatus != null) return explicitStatus;
    return followStatusFor?.call(
      broadcasterId: stream.userId,
      broadcasterLogin: stream.channelLogin,
    );
  }
}

class TwitchDiscoveryStreamSliverSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<TwitchLiveStream> streams;
  final TwitchDiscoveryService? discoveryService;
  final Future<void> Function()? onReturnFromStream;
  final bool? streamKnownFollowing;
  final TwitchFollowStatusResolver? followStatusFor;

  const TwitchDiscoveryStreamSliverSection({
    super.key,
    required this.icon,
    required this.title,
    required this.streams,
    this.discoveryService,
    this.onReturnFromStream,
    this.streamKnownFollowing,
    this.followStatusFor,
  });

  @override
  Widget build(BuildContext context) {
    if (streams.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: TwitchDiscoverySectionHeader(
            icon: icon,
            title: title,
            count: streams.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final mainAxisExtent = twitchStreamCardGridMainAxisExtent(
                constraints.crossAxisExtent,
              );
              return SliverGrid(
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
                        onTap: () => _openStreamTarget(context, stream),
                      ),
                    );
                  },
                  childCount: streams.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openStreamTarget(BuildContext context, TwitchLiveStream stream) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TwitchWatchRouteGuard(
              initialMetadata: TwitchStreamHeaderMetadata.fromLiveStream(stream),
              initialOfflineChannel: TwitchFollowedChannel(
                broadcasterId: stream.userId,
                broadcasterLogin: stream.userLogin,
                broadcasterName: stream.userName,
                followedAt: null,
                profileImageUrl: stream.profileImageUrl,
              ),
              initialDiscoveryService: discoveryService,
              initialKnownFollowing: _knownFollowStatusFor(stream),
            ),
          ),
        )
        .then((_) {
          final callback = onReturnFromStream;
          if (callback != null) unawaited(callback());
        });
  }

  bool? _knownFollowStatusFor(TwitchLiveStream stream) {
    final explicitStatus = streamKnownFollowing;
    if (explicitStatus != null) return explicitStatus;
    return followStatusFor?.call(
      broadcasterId: stream.userId,
      broadcasterLogin: stream.channelLogin,
    );
  }
}

class TwitchDiscoverySectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final bool showCount;

  const TwitchDiscoverySectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TwitchUiColors.surfaceSelected,
              borderRadius: BorderRadius.circular(TwitchUiRadius.md),
              border: Border.all(color: TwitchUiColors.borderInteractive),
            ),
            child: Icon(icon, color: TwitchUiColors.primarySoft, size: 18),
          ),
          const SizedBox(width: TwitchUiSpacing.space12),
          Expanded(
            child: Text(
              showCount && count > 0 ? '$title · $count' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TwitchUiColors.textPrimary,
                fontSize: TwitchUiFontSize.title,
                height: 1.15,
                fontWeight: TwitchUiFontWeight.strong,
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
    final l10n = context.vio;
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorText != null && errorText!.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: () => unawaited(onLoadMore()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.t('載入更多失敗，重試')),
          ),
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Center(
          child: TextButton.icon(
            onPressed: () => unawaited(onLoadMore()),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            label: Text(l10n.t('載入更多')),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
      child: Center(
        child: Text(
          l10n.t('已經到底了'),
          style: const TextStyle(
            color: TwitchUiColors.textFaint,
            fontSize: TwitchUiFontSize.bodyCompact,
            fontWeight: TwitchUiFontWeight.medium,
          ),
        ),
      ),
    );
  }
}

class TwitchDiscoveryLowerContentState {
  final List<Widget> slivers;
  final Widget footer;

  const TwitchDiscoveryLowerContentState({
    required this.slivers,
    required this.footer,
  });
}

TwitchDiscoveryLowerContentState twitchDiscoveryLowerContentState({
  required bool loadingInitial,
  required bool hasAnyLoadedContent,
  required bool filteredEmpty,
  required Widget emptyState,
  required Widget filteredEmptyState,
  required List<Widget> contentSlivers,
  required Widget footer,
}) {
  if (loadingInitial) {
    return const TwitchDiscoveryLowerContentState(
      slivers: <Widget>[TwitchDiscoveryLoadingSliver()],
      footer: SizedBox.shrink(),
    );
  }
  if (!hasAnyLoadedContent) {
    return TwitchDiscoveryLowerContentState(
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: emptyState),
      ],
      footer: const SizedBox.shrink(),
    );
  }
  if (filteredEmpty) {
    return TwitchDiscoveryLowerContentState(
      slivers: <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: filteredEmptyState),
      ],
      footer: const SizedBox.shrink(),
    );
  }
  return TwitchDiscoveryLowerContentState(
    slivers: contentSlivers,
    footer: footer,
  );
}

class TwitchDiscoveryLoadingSliver extends StatelessWidget {
  const TwitchDiscoveryLoadingSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: CircularProgressIndicator()),
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
    final l10n = context.vio;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: TwitchUiColors.surfaceCard,
          borderRadius: BorderRadius.circular(TwitchUiRadius.xl),
          border: Border.all(color: TwitchUiColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TwitchUiColors.surfaceSelected,
                borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
                border: Border.all(color: TwitchUiColors.borderInteractive),
              ),
              child: Icon(icon, color: TwitchUiColors.primarySoft, size: 28),
            ),
            const SizedBox(height: TwitchUiSpacing.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwitchUiColors.textPrimary,
                fontSize: TwitchUiFontSize.title,
                fontWeight: TwitchUiFontWeight.strong,
              ),
            ),
            const SizedBox(height: TwitchUiSpacing.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TwitchUiColors.textSecondary,
                fontSize: TwitchUiFontSize.body,
                height: 1.45,
                fontWeight: TwitchUiFontWeight.regular,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: TwitchUiSpacing.space20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('重新整理')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
