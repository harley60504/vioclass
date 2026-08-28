import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discovery/twitch_stream_header_metadata.dart';
import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/responsive/twitch_responsive_layout.dart';
import '../widgets/shared/twitch_cached_image_layer.dart';
import 'twitch_watch_page.dart';

Future<void> showTwitchChannelSheet({
  required BuildContext context,
  required TwitchDiscoveryService discoveryService,
  required TwitchFollowedChannel channel,
  int initialTabIndex = 0,
}) {
  final layout = TwitchResponsiveLayout.fromContext(context);
  final media = MediaQuery.of(context);
  final viewport = media.size;
  final maxWidth = layout.isPhone
      ? viewport.width
      : (viewport.width * (layout.isDesktop ? 0.82 : 0.92)).clamp(
          720.0,
          1600.0,
        );
  final maxHeight =
      (viewport.height -
              media.padding.top -
              media.padding.bottom -
              (layout.isPhone ? 8.0 : 24.0))
          .clamp(360.0, viewport.height);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.26),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _ChannelMediaLibraryDialog(
        width: maxWidth.toDouble(),
        height: maxHeight.toDouble(),
        topPadding: media.padding.top,
        child: TwitchChannelPage(
          discoveryService: discoveryService,
          channel: channel,
          initialTabIndex: initialTabIndex,
          showCloseButton: true,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

class _ChannelMediaLibraryDialog extends StatelessWidget {
  final double width;
  final double height;
  final double topPadding;
  final Widget child;

  const _ChannelMediaLibraryDialog({
    required this.width,
    required this.height,
    required this.topPadding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, topPadding + 10, 12, 12),
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          const Color(0xA315171D),
                          const Color(0x8F0E1117),
                          const Color(0xA3111018),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TwitchChannelPage extends StatefulWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final int initialTabIndex;
  final bool showCloseButton;

  const TwitchChannelPage({
    super.key,
    required this.discoveryService,
    required this.channel,
    this.initialTabIndex = 0,
    this.showCloseButton = false,
  });

  @override
  State<TwitchChannelPage> createState() => _TwitchChannelPageState();
}

class _TwitchChannelPageState extends State<TwitchChannelPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  List<TwitchChannelVideo> videos = const <TwitchChannelVideo>[];
  List<TwitchChannelClip> clips = const <TwitchChannelClip>[];
  List<TwitchChannelPanel> panels = const <TwitchChannelPanel>[];
  List<TwitchChannelSocialLink> socialLinks = const <TwitchChannelSocialLink>[];
  String? nextCursor;
  String? clipsNextCursor;
  String? errorText;
  String? clipsErrorText;
  String? panelsErrorText;
  bool loadingFirstPage = false;
  bool loadingClipsFirstPage = false;
  bool loadingPanels = false;
  bool loadingMore = false;
  bool loadingMoreClips = false;
  bool videosLoaded = false;
  bool clipsLoaded = false;
  bool panelsLoaded = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      vsync: this,
    )..addListener(_loadActiveTab);
    _loadActiveTab();
  }

  @override
  void dispose() {
    tabController.removeListener(_loadActiveTab);
    tabController.dispose();
    super.dispose();
  }

  void _loadActiveTab() {
    switch (tabController.index) {
      case 0:
        if (!panelsLoaded && !loadingPanels) unawaited(_loadPanels());
        break;
      case 1:
        if (!clipsLoaded && !loadingClipsFirstPage) {
          unawaited(_loadClips(clearExisting: true));
        }
        break;
      case 2:
        if (!videosLoaded && !loadingFirstPage) {
          unawaited(_loadVideos(clearExisting: true));
        }
        break;
    }
  }

  Future<void> _loadPanels() async {
    setState(() {
      loadingPanels = true;
      panelsErrorText = null;
    });

    try {
      final loaded = await widget.discoveryService.fetchChannelAbout(
        login: widget.channel.channelLogin,
      );
      if (!mounted) return;
      setState(() {
        panels = loaded.panels;
        socialLinks = loaded.socialLinks;
        loadingPanels = false;
        panelsLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        panelsErrorText = error.toString();
        loadingPanels = false;
        panelsLoaded = true;
      });
    }
  }

  Future<void> _loadVideos({bool clearExisting = false}) async {
    if (loadingMore) return;
    final loadingMorePage = !clearExisting && videos.isNotEmpty;
    setState(() {
      loadingFirstPage = clearExisting && videos.isEmpty;
      loadingMore = loadingMorePage;
      errorText = null;
      if (clearExisting) {
        videos = const <TwitchChannelVideo>[];
        nextCursor = null;
      }
    });

    try {
      final page = await widget.discoveryService.fetchChannelVideos(
        userId: widget.channel.broadcasterId,
        after: clearExisting ? null : nextCursor,
      );
      if (!mounted) return;
      setState(() {
        videos = clearExisting
            ? page.videos
            : <TwitchChannelVideo>[...videos, ...page.videos];
        nextCursor = page.cursor;
        loadingFirstPage = false;
        loadingMore = false;
        videosLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = error.toString();
        loadingFirstPage = false;
        loadingMore = false;
        videosLoaded = true;
      });
    }
  }

  Future<void> _loadClips({bool clearExisting = false}) async {
    if (loadingMoreClips) return;
    final loadingMorePage = !clearExisting && clips.isNotEmpty;
    setState(() {
      loadingClipsFirstPage = clearExisting && clips.isEmpty;
      loadingMoreClips = loadingMorePage;
      clipsErrorText = null;
      if (clearExisting) {
        clips = const <TwitchChannelClip>[];
        clipsNextCursor = null;
      }
    });

    try {
      final page = await widget.discoveryService.fetchChannelClips(
        broadcasterId: widget.channel.broadcasterId,
        after: clearExisting ? null : clipsNextCursor,
      );
      if (!mounted) return;
      setState(() {
        clips = clearExisting
            ? page.clips
            : <TwitchChannelClip>[...clips, ...page.clips];
        clipsNextCursor = page.cursor;
        loadingClipsFirstPage = false;
        loadingMoreClips = false;
        clipsLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        clipsErrorText = error.toString();
        loadingClipsFirstPage = false;
        loadingMoreClips = false;
        clipsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0x4D18181B),
        foregroundColor: Colors.white,
        title: Text(widget.channel.displayName),
        automaticallyImplyLeading: !widget.showCloseButton,
        actions: [
          if (widget.showCloseButton)
            IconButton(
              tooltip: '關閉',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        bottom: TabBar(
          controller: tabController,
          indicatorColor: TwitchUiColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline_rounded), text: '關於'),
            Tab(icon: Icon(Icons.movie_filter_rounded), text: '片段'),
            Tab(icon: Icon(Icons.video_library_rounded), text: 'VOD'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _AboutTab(
            channel: widget.channel,
            panels: panels,
            socialLinks: socialLinks,
            loadingPanels: loadingPanels,
            panelsErrorText: panelsErrorText,
            onRetryPanels: () => unawaited(_loadPanels()),
          ),
          _ClipTab(
            discoveryService: widget.discoveryService,
            channel: widget.channel,
            clips: clips,
            loadingFirstPage: loadingClipsFirstPage,
            loadingMore: loadingMoreClips,
            hasMore:
                clipsNextCursor != null && clipsNextCursor!.trim().isNotEmpty,
            errorText: clipsErrorText,
            onRetry: () => unawaited(_loadClips(clearExisting: true)),
            onLoadMore: () => unawaited(_loadClips()),
          ),
          _VodTab(
            discoveryService: widget.discoveryService,
            channel: widget.channel,
            videos: videos,
            loadingFirstPage: loadingFirstPage,
            loadingMore: loadingMore,
            hasMore: nextCursor != null && nextCursor!.trim().isNotEmpty,
            errorText: errorText,
            onRetry: () => unawaited(_loadVideos(clearExisting: true)),
            onLoadMore: () => unawaited(_loadVideos()),
          ),
        ],
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final TwitchFollowedChannel channel;
  final List<TwitchChannelPanel> panels;
  final List<TwitchChannelSocialLink> socialLinks;
  final bool loadingPanels;
  final String? panelsErrorText;
  final VoidCallback onRetryPanels;

  const _AboutTab({
    required this.channel,
    required this.panels,
    required this.socialLinks,
    required this.loadingPanels,
    required this.panelsErrorText,
    required this.onRetryPanels,
  });

  @override
  Widget build(BuildContext context) {
    final description = channel.description.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Row(
          children: [
            _ChannelAvatar(channel: channel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (channel.channelLogin.isNotEmpty)
                    Text(
                      channel.channelLogin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _PanelSection(
          panels: panels,
          socialLinks: socialLinks,
          loading: loadingPanels,
          errorText: panelsErrorText,
          onRetry: onRetryPanels,
        ),
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  final List<TwitchChannelPanel> panels;
  final List<TwitchChannelSocialLink> socialLinks;
  final bool loading;
  final String? errorText;
  final VoidCallback onRetry;

  const _PanelSection({
    required this.panels,
    required this.socialLinks,
    required this.loading,
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: CircularProgressIndicator(color: TwitchUiColors.primary),
        ),
      );
    }

    final error = errorText?.trim();
    if (panels.isEmpty && error != null && error.isNotEmpty) {
      return _InlineRetry(
        icon: Icons.image_not_supported_outlined,
        text: '關於圖片讀取失敗',
        onRetry: onRetry,
      );
    }

    if (panels.isEmpty) {
      return const Text(
        '這個頻道目前沒有關於圖片面板。',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (socialLinks.isNotEmpty) ...[
          _SocialLinkSection(links: socialLinks),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            const Icon(
              Icons.dashboard_customize_rounded,
              color: TwitchUiColors.primarySoft,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '關於面板',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 330).floor().clamp(1, 3);
            final panelHeight = columns == 1 ? 340.0 : 314.0;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: panels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: panelHeight,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                return _PanelCard(panel: panels[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _SocialLinkSection extends StatelessWidget {
  final List<TwitchChannelSocialLink> links;

  const _SocialLinkSection({required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.hub_outlined,
              color: TwitchUiColors.primarySoft,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              '社群連結',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: links.map((link) => _SocialLinkCard(link: link)).toList(),
        ),
      ],
    );
  }
}

class _SocialLinkCard extends StatelessWidget {
  final TwitchChannelSocialLink link;

  const _SocialLinkCard({required this.link});

  @override
  Widget build(BuildContext context) {
    final visual = _socialVisualFor(link.name);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openExternalUrl(link.url),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.030),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: visual.color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(visual.icon, color: visual.color, size: 17),
              const SizedBox(width: 8),
              Text(
                link.title.isEmpty ? link.name : link.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.45),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final TwitchChannelPanel panel;

  const _PanelCard({required this.panel});

  @override
  Widget build(BuildContext context) {
    final imageUrl = panel.imageUrl.trim();
    final linkUrl = panel.linkUrl.trim();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: linkUrl.isEmpty ? null : () => _openExternalUrl(linkUrl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.045),
                Colors.white.withValues(alpha: 0.014),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.070)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return TwitchCachedImageLayer(
                      imageUrl: imageUrl,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      fit: BoxFit.contain,
                      fallbackColor: Colors.white.withValues(alpha: 0.045),
                      fallbackIcon: Icons.article_outlined,
                      fallbackIconColor: Colors.white38,
                      fallbackIconSize: 34,
                    );
                  },
                ),
              ),
              if (panel.title.isNotEmpty ||
                  panel.description.isNotEmpty ||
                  linkUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _panelLabel(panel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (linkUrl.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.open_in_new_rounded,
                          color: TwitchUiColors.primarySoft,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _panelLabel(TwitchChannelPanel panel) {
    if (panel.title.isNotEmpty) return panel.title;
    if (panel.description.isNotEmpty) return panel.description;
    return '開啟連結';
  }
}

class _SocialVisual {
  final IconData icon;
  final Color color;

  const _SocialVisual({required this.icon, required this.color});
}

class _InlineRetry extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  const _InlineRetry({
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onRetry,
      icon: Icon(icon, size: 16),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: TwitchUiColors.primarySoft,
        side: BorderSide(color: TwitchUiColors.primary.withValues(alpha: 0.45)),
      ),
    );
  }
}

_SocialVisual _socialVisualFor(String name) {
  final key = name.trim().toLowerCase();
  if (key.contains('youtube')) {
    return const _SocialVisual(
      icon: Icons.smart_display_rounded,
      color: Color(0xFFFF5A5F),
    );
  }
  if (key.contains('discord')) {
    return const _SocialVisual(
      icon: Icons.forum_rounded,
      color: Color(0xFF7B86FF),
    );
  }
  if (key.contains('facebook')) {
    return const _SocialVisual(
      icon: Icons.facebook_rounded,
      color: Color(0xFF5EA2FF),
    );
  }
  if (key.contains('instagram')) {
    return const _SocialVisual(
      icon: Icons.camera_alt_rounded,
      color: Color(0xFFFF7AC8),
    );
  }
  if (key.contains('twitter') || key == 'x') {
    return const _SocialVisual(
      icon: Icons.alternate_email_rounded,
      color: Color(0xFF9FB4C7),
    );
  }
  if (key.contains('tiktok')) {
    return const _SocialVisual(
      icon: Icons.music_note_rounded,
      color: Color(0xFF5FFFE0),
    );
  }
  if (key.contains('spotify')) {
    return const _SocialVisual(
      icon: Icons.library_music_rounded,
      color: Color(0xFF1ED760),
    );
  }
  return const _SocialVisual(
    icon: Icons.language_rounded,
    color: Color(0xFF9FB4C7),
  );
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ClipTab extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final List<TwitchChannelClip> clips;
  final bool loadingFirstPage;
  final bool loadingMore;
  final bool hasMore;
  final String? errorText;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  const _ClipTab({
    required this.discoveryService,
    required this.channel,
    required this.clips,
    required this.loadingFirstPage,
    required this.loadingMore,
    required this.hasMore,
    required this.errorText,
    required this.onRetry,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingFirstPage) {
      return const Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primary),
      );
    }

    final error = errorText?.trim();
    if (clips.isEmpty && error != null && error.isNotEmpty) {
      return _CenteredAction(
        icon: Icons.error_outline_rounded,
        title: '片段讀取失敗',
        message: error,
        actionLabel: '重試',
        onPressed: onRetry,
      );
    }

    if (clips.isEmpty) {
      return _CenteredAction(
        icon: Icons.movie_filter_outlined,
        title: '目前沒有片段',
        message: '這個頻道沒有可顯示的精華片段。',
        actionLabel: '重新整理',
        onPressed: onRetry,
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              childAspectRatio: 1.42,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return _ClipCard(
                discoveryService: discoveryService,
                channel: channel,
                clip: clips[index],
              );
            }, childCount: clips.length),
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
                      label: Text(loadingMore ? '載入中' : '載入更多'),
                    )
                  : const Text(
                      '已顯示目前可讀取的片段',
                      style: TextStyle(
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
}

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
                            clip.title.trim().isEmpty ? '未命名片段' : clip.title,
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
          child: _VodPill(text: _formatClipViews(clip.viewCount)),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: _VodPill(text: '${clip.duration.toStringAsFixed(1)}s'),
        ),
      ],
    );
  }

  String _formatClipViews(int value) {
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
    return Text(
      '${creator.isEmpty ? '已建立片段' : '由 $creator 建立片段'}'
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
    required this.loadingFirstPage,
    required this.loadingMore,
    required this.hasMore,
    required this.errorText,
    required this.onRetry,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingFirstPage) {
      return const Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primary),
      );
    }

    final error = errorText?.trim();
    if (videos.isEmpty && error != null && error.isNotEmpty) {
      return _CenteredAction(
        icon: Icons.error_outline_rounded,
        title: 'VOD 讀取失敗',
        message: error,
        actionLabel: '重試',
        onPressed: onRetry,
      );
    }

    if (videos.isEmpty) {
      return _CenteredAction(
        icon: Icons.video_library_outlined,
        title: '目前沒有 VOD',
        message: '這個頻道沒有可顯示的過去直播。',
        actionLabel: '重新整理',
        onPressed: onRetry,
      );
    }

    return CustomScrollView(
      slivers: [
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
                video: videos[index],
              );
            }, childCount: videos.length),
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
                      label: Text(loadingMore ? '載入中' : '載入更多'),
                    )
                  : const Text(
                      '已顯示目前可讀取的 VOD',
                      style: TextStyle(
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
                                ? '未命名 VOD'
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
          const Positioned(left: 8, top: 8, child: _VodPill(text: '直播存檔中')),
      ],
    );
  }
}

class _VodMetaText extends StatelessWidget {
  final TwitchChannelVideo video;
  final bool isGrowingArchive;

  const _VodMetaText({required this.video, required this.isGrowingArchive});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(video.publishedAt ?? video.createdAt);
    final views = _formatCount(video.viewCount);
    return Text(
      isGrowingArchive
          ? '目前直播中，點擊會進直播觀看頁'
          : '$views 次觀看${date.isEmpty ? '' : ' · $date'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11.5,
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

  String _formatCount(int value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(1)}萬';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _VodPill extends StatelessWidget {
  final String text;

  const _VodPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final label = text.trim();
    if (label.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  final TwitchFollowedChannel channel;

  const _ChannelAvatar({required this.channel});

  @override
  Widget build(BuildContext context) {
    const size = 58.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: TwitchCachedImageLayer.avatar(
        imageUrl: channel.profileImageUrl,
        size: size,
        cacheWidth: 116,
        cacheHeight: 116,
        fallbackColor: Colors.white.withValues(alpha: 0.07),
        fallbackIconColor: Colors.white38,
      ),
    );
  }
}

class _CenteredAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _CenteredAction({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white38, size: 42),
            const SizedBox(height: 12),
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
                color: Colors.white60,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
