part of '../twitch_channel_page.dart';

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
  final TextEditingController clipSearchController = TextEditingController();
  final TextEditingController vodSearchController = TextEditingController();
  List<TwitchChannelVideo> videos = const <TwitchChannelVideo>[];
  List<TwitchChannelClip> clips = const <TwitchChannelClip>[];
  List<TwitchChannelPanel> panels = const <TwitchChannelPanel>[];
  List<TwitchChannelSocialLink> socialLinks = const <TwitchChannelSocialLink>[];
  String? nextCursor;
  String? clipsNextCursor;
  String? errorText;
  String? clipsErrorText;
  String? panelsErrorText;
  String clipSearchText = '';
  String vodSearchText = '';
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
    clipSearchController.dispose();
    vodSearchController.dispose();
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
    final l10n = context.vio;
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
              tooltip: l10n.t('關閉'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
        bottom: TabBar(
          controller: tabController,
          indicatorColor: TwitchUiColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              icon: const Icon(Icons.info_outline_rounded),
              text: l10n.t('關於'),
            ),
            Tab(
              icon: const Icon(Icons.movie_filter_rounded),
              text: l10n.t('片段'),
            ),
            const Tab(icon: Icon(Icons.video_library_rounded), text: 'VOD'),
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
            searchController: clipSearchController,
            searchText: clipSearchText,
            onSearchChanged: (value) {
              setState(() => clipSearchText = value.trim().toLowerCase());
            },
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
            searchController: vodSearchController,
            searchText: vodSearchText,
            onSearchChanged: (value) {
              setState(() => vodSearchText = value.trim().toLowerCase());
            },
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
        text: context.vio.t('關於圖片讀取失敗'),
        onRetry: onRetry,
      );
    }

    if (panels.isEmpty) {
      return Text(
        context.vio.t('這個頻道目前沒有關於圖片面板。'),
        style: const TextStyle(
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
              context.vio.t('關於面板'),
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
            final cardWidth =
                (constraints.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: panels
                  .map(
                    (panel) => SizedBox(
                      width: cardWidth,
                      child: _PanelCard(panel: panel),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}
