part of '../twitch_channel_page.dart';

class _SocialLinkSection extends StatelessWidget {
  final List<TwitchChannelSocialLink> links;

  const _SocialLinkSection({required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.hub_outlined,
              color: TwitchUiColors.primarySoft,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              context.vio.t('社群連結'),
              style: const TextStyle(
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
              AspectRatio(
                aspectRatio: 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) => TwitchCachedImageLayer(
                    imageUrl: imageUrl,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    fit: BoxFit.contain,
                    fallbackColor: Colors.white.withValues(alpha: 0.045),
                    fallbackIcon: Icons.article_outlined,
                    fallbackIconColor: Colors.white38,
                    fallbackIconSize: 34,
                  ),
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
                          _panelLabel(context, panel),
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

  String _panelLabel(BuildContext context, TwitchChannelPanel panel) {
    if (panel.title.isNotEmpty) return panel.title;
    if (panel.description.isNotEmpty) return panel.description;
    return context.vio.t('開啟連結');
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

Widget _mediaSearchSliver({
  required BuildContext context,
  required TextEditingController controller,
  required String hintText,
  required ValueChanged<String> onChanged,
}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: TwitchCenteredTextField(
        controller: controller,
        hintText: hintText,
        prefixIcon: Icons.search_rounded,
        onChanged: onChanged,
        height: 42,
        radius: 14,
        fontSize: 13,
        fillColor: Colors.white.withValues(alpha: 0.055),
        borderColor: Colors.white.withValues(alpha: 0.10),
        hintColor: Colors.white38,
        iconColor: Colors.white54,
        suffixIcon: controller.text.trim().isNotEmpty
            ? IconButton(
                tooltip: context.vio.t('清空搜尋'),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              )
            : null,
      ),
    ),
  );
}

class _ClipTab extends StatelessWidget {
  final TwitchDiscoveryService discoveryService;
  final TwitchFollowedChannel channel;
  final List<TwitchChannelClip> clips;
  final TextEditingController searchController;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
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
    final filteredClips = _filterClips(clips, searchText);

    if (loadingFirstPage) {
      return const Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primary),
      );
    }

    final error = errorText?.trim();
    if (clips.isEmpty && error != null && error.isNotEmpty) {
      return _CenteredAction(
        icon: Icons.error_outline_rounded,
        title: l10n.t('片段讀取失敗'),
        message: l10n.t('片段暫時讀取失敗，稍後再試或重新整理。'),
        actionLabel: l10n.t('重試'),
        onPressed: onRetry,
      );
    }

    if (clips.isEmpty) {
      return _CenteredAction(
        icon: Icons.movie_filter_outlined,
        title: l10n.t('目前沒有片段'),
        message: l10n.t('這個頻道沒有可顯示的精華片段。'),
        actionLabel: l10n.t('重新整理'),
        onPressed: onRetry,
      );
    }

    if (filteredClips.isEmpty) {
      return CustomScrollView(
        slivers: [
          _mediaSearchSliver(
            context: context,
            controller: searchController,
            hintText: l10n.t('搜尋片段'),
            onChanged: onSearchChanged,
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CenteredAction(
              icon: Icons.search_off_rounded,
              title: l10n.t('找不到符合的片段'),
              message: l10n.t('可以換個關鍵字，或清空搜尋回到全部片段。'),
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
          hintText: l10n.t('搜尋片段'),
          onChanged: onSearchChanged,
        ),
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
                clip: filteredClips[index],
              );
            }, childCount: filteredClips.length),
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
                      l10n.t('已顯示目前可讀取的片段'),
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

  List<TwitchChannelClip> _filterClips(
    List<TwitchChannelClip> clips,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return clips;
    return clips
        .where((clip) {
          return clip.title.toLowerCase().contains(keyword) ||
              clip.creatorName.toLowerCase().contains(keyword) ||
              clip.broadcasterName.toLowerCase().contains(keyword);
        })
        .toList(growable: false);
  }
}
