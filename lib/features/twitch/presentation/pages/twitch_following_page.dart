// Uses the same discovery template as BrowsePage and the actual project models/services.
// Refresh/re-enter keeps the grid visible, fetches the latest live window,
// removes offline streams, adds newly live streams, and preserves the latest
// Twitch API order through TwitchStreamRefreshReconciler.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/discovery/twitch_discovery_stream_template.dart';
import '../widgets/discovery/twitch_offline_channel_card.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_login_required_view.dart';
import 'twitch_stream_refresh_reconciler.dart';

class TwitchFollowingPage extends StatefulWidget {
  final TwitchDiscoveryService discoveryService;
  final String searchText;
  final int reloadTick;
  final Future<void> Function() onLoginPressed;

  const TwitchFollowingPage({
    super.key,
    required this.discoveryService,
    required this.searchText,
    required this.reloadTick,
    required this.onLoginPressed,
  });

  @override
  State<TwitchFollowingPage> createState() => TwitchFollowingPageState();
}

class TwitchFollowingPageState extends State<TwitchFollowingPage> {
  static const int _followedPageSize = 100;

  final ScrollController scrollController = ScrollController();

  List<TwitchLiveStream> loadedStreams = const <TwitchLiveStream>[];
  List<TwitchFollowedChannel> offlineFollowedChannels =
      const <TwitchFollowedChannel>[];
  String? nextCursor;
  String? errorText;
  String? paginationError;
  String? offlineError;
  String currentLanguage = '';

  bool loadingFirstPage = true;
  bool loadingMore = false;
  bool loadingOfflineChannels = false;
  bool hasMore = true;

  int _refreshGeneration = 0;

  static const List<Map<String, String>> languageFilters =
      <Map<String, String>>[
        {'label': '全部語言', 'value': ''},
        {'label': '中文 Chinese', 'value': 'zh'},
        {'label': 'English', 'value': 'en'},
        {'label': '日本語 Japanese', 'value': 'ja'},
        {'label': '한국어 Korean', 'value': 'ko'},
        {'label': 'Español Spanish', 'value': 'es'},
        {'label': 'Português Portuguese', 'value': 'pt'},
        {'label': 'Français French', 'value': 'fr'},
        {'label': 'Deutsch German', 'value': 'de'},
        {'label': 'Русский Russian', 'value': 'ru'},
        {'label': 'Italiano Italian', 'value': 'it'},
        {'label': 'Türkçe Turkish', 'value': 'tr'},
        {'label': 'Polski Polish', 'value': 'pl'},
        {'label': 'Nederlands Dutch', 'value': 'nl'},
        {'label': 'ไทย Thai', 'value': 'th'},
        {'label': 'Tiếng Việt Vietnamese', 'value': 'vi'},
        {'label': 'Bahasa Indonesia Indonesian', 'value': 'id'},
        {'label': 'العربية Arabic', 'value': 'ar'},
        {'label': 'हिन्दी Hindi', 'value': 'hi'},
      ];

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(refreshStreams());
    });
  }

  @override
  void didUpdateWidget(covariant TwitchFollowingPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reloadTick != widget.reloadTick) {
      unawaited(refreshStreams());
    } else if (oldWidget.searchText != widget.searchText) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!scrollController.hasClients || loadingMore || !hasMore) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 720) {
      unawaited(loadMore());
    }
  }

  Future<void> refreshStreams({
    bool clearExisting = false,
    bool jumpToTop = false,
  }) async {
    if (!mounted) return;

    final generation = ++_refreshGeneration;
    final hadExistingStreams = loadedStreams.isNotEmpty && !clearExisting;

    setState(() {
      loadingFirstPage = !hadExistingStreams;
      errorText = null;
      paginationError = null;
      offlineError = null;
      loadingOfflineChannels = true;
      if (clearExisting) {
        nextCursor = null;
        hasMore = true;
        loadedStreams = const <TwitchLiveStream>[];
        offlineFollowedChannels = const <TwitchFollowedChannel>[];
      }
    });

    try {
      final refreshed = await _fetchRefreshedStreamWindow(
        targetCount: TwitchStreamRefreshReconciler.targetRefreshCount(
          loadedCount: hadExistingStreams
              ? loadedStreams.length
              : _followedPageSize,
          pageSize: _followedPageSize,
        ),
      );
      if (!mounted || generation != _refreshGeneration) return;

      final offline = await _fetchOfflineFollowedChannels(refreshed.streams);
      if (!mounted || generation != _refreshGeneration) return;

      setState(() {
        loadedStreams = refreshed.streams;
        offlineFollowedChannels = offline.channels;
        nextCursor = refreshed.cursor;
        hasMore = refreshed.hasMore;
        loadingFirstPage = false;
        loadingOfflineChannels = false;
        errorText = null;
        paginationError = null;
        offlineError = offline.errorText;
      });

      if (jumpToTop || clearExisting) {
        _jumpToTop();
      }
    } catch (error) {
      if (!mounted || generation != _refreshGeneration) return;
      setState(() {
        if (loadedStreams.isEmpty || clearExisting) {
          errorText = error.toString();
        } else {
          paginationError = error.toString();
        }
        loadingFirstPage = false;
        loadingOfflineChannels = false;
      });
    }
  }

  Future<_FollowingRefreshWindow> _fetchRefreshedStreamWindow({
    required int targetCount,
  }) async {
    final collected = <TwitchLiveStream>[];

    var page = await widget.discoveryService.fetchFollowedStreams(
      first: _followedPageSize,
    );
    collected.addAll(page.streams);

    var cursor = page.cursor;
    var hasMorePage = page.hasMore;

    while (hasMorePage &&
        cursor != null &&
        cursor.trim().isNotEmpty &&
        collected.length < targetCount) {
      page = await widget.discoveryService.fetchFollowedStreams(
        after: cursor,
        first: _followedPageSize,
      );
      collected.addAll(page.streams);
      cursor = page.cursor;
      hasMorePage = page.hasMore;
    }

    final reconciled = TwitchStreamRefreshReconciler.reconcileLatestWindow(
      refreshedWindow: collected,
      identityOf: _streamIdentity,
    );
    final streamsWithProfiles = await _attachProfileImages(reconciled);

    return _FollowingRefreshWindow(
      streams: streamsWithProfiles,
      cursor: cursor,
      hasMore: hasMorePage,
    );
  }

  Future<_OfflineFollowedResult> _fetchOfflineFollowedChannels(
    List<TwitchLiveStream> liveStreams,
  ) async {
    try {
      final page = await widget.discoveryService.fetchFollowedChannels(
        first: _followedPageSize,
      );

      final liveIds = liveStreams
          .map((stream) => stream.userId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final liveLogins = liveStreams
          .map((stream) => stream.channelLogin)
          .where((login) => login.isNotEmpty)
          .toSet();

      final offline = page.channels
          .where((channel) {
            final id = channel.broadcasterId.trim();
            final login = channel.channelLogin;
            if (id.isNotEmpty && liveIds.contains(id)) return false;
            if (login.isNotEmpty && liveLogins.contains(login)) return false;
            return true;
          })
          .toList(growable: false);

      return _OfflineFollowedResult(channels: offline);
    } catch (error) {
      return _OfflineFollowedResult(
        channels: const <TwitchFollowedChannel>[],
        errorText: error.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    final cursor = nextCursor;
    if (cursor == null || cursor.trim().isEmpty) {
      setState(() => hasMore = false);
      return;
    }

    setState(() {
      loadingMore = true;
      paginationError = null;
    });

    try {
      final page = await widget.discoveryService.fetchFollowedStreams(
        after: cursor,
        first: _followedPageSize,
      );
      final streamsWithProfiles = await _attachProfileImages(page.streams);
      if (!mounted) return;

      setState(() {
        loadedStreams = TwitchStreamRefreshReconciler.appendUniquePage(
          loaded: loadedStreams,
          nextPage: streamsWithProfiles,
          identityOf: _streamIdentity,
        );
        nextCursor = page.cursor;
        hasMore = page.hasMore;
        loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        paginationError = error.toString();
        loadingMore = false;
      });
    }
  }

  Future<List<TwitchLiveStream>> _attachProfileImages(
    List<TwitchLiveStream> streams,
  ) async {
    final missingLogins = streams
        .where((stream) => stream.profileImageUrl.trim().isEmpty)
        .map((stream) => stream.channelLogin)
        .where((login) => login.trim().isNotEmpty)
        .toSet();

    if (missingLogins.isEmpty) return streams;

    try {
      final profileImages = await widget.discoveryService
          .fetchProfileImagesForLogins(missingLogins);
      if (profileImages.isEmpty) return streams;
      return streams
          .map(
            (stream) => stream.copyWith(
              profileImageUrl: stream.profileImageUrl.trim().isNotEmpty
                  ? stream.profileImageUrl
                  : profileImages[stream.channelLogin] ?? '',
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return streams;
    }
  }

  String _streamIdentity(TwitchLiveStream stream) {
    final id = stream.id.trim();
    if (id.isNotEmpty) return 'id:$id';

    final login = stream.channelLogin.trim().toLowerCase();
    if (login.isNotEmpty) return 'login:$login';

    return 'fallback:${stream.userName.trim().toLowerCase()}|${stream.title.trim()}';
  }

  void _jumpToTop() {
    if (!scrollController.hasClients) return;
    scrollController.jumpTo(0);
  }

  List<TwitchLiveStream> _filteredStreams() {
    final keyword = widget.searchText.trim().toLowerCase();
    final language = currentLanguage.trim().toLowerCase();

    return loadedStreams
        .where((stream) {
          if (language.isNotEmpty &&
              stream.language.toLowerCase() != language) {
            return false;
          }

          if (keyword.isEmpty) return true;

          final haystack = <String>[
            stream.userName,
            stream.userLogin,
            stream.title,
            stream.gameName,
            stream.language,
            ...stream.tags,
          ].join(' ').toLowerCase();

          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  List<TwitchFollowedChannel> _filteredOfflineChannels() {
    final keyword = widget.searchText.trim().toLowerCase();
    if (keyword.isEmpty) return offlineFollowedChannels;

    return offlineFollowedChannels
        .where((channel) {
          final haystack = <String>[
            channel.broadcasterName,
            channel.broadcasterLogin,
            channel.description,
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  Future<void> showLanguageMenu(BuildContext context) async {
    final searchController = TextEditingController();
    String keyword = '';

    await showTwitchUnifiedSheet<void>(
      context: context,
      title: '語言篩選',
      subtitle: currentLanguage.isEmpty ? '全部語言' : currentLanguage,
      icon: Icons.language_rounded,
      size: TwitchUnifiedSheetSize.medium,
      showRefresh: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final lowerKeyword = keyword.trim().toLowerCase();
            final filteredLanguages = lowerKeyword.isEmpty
                ? languageFilters
                : languageFilters
                      .where((item) {
                        final label = item['label']?.toLowerCase() ?? '';
                        final value = item['value']?.toLowerCase() ?? '';
                        return label.contains(lowerKeyword) ||
                            value.contains(lowerKeyword);
                      })
                      .toList(growable: false);

            void selectLanguage(String value) {
              setState(() => currentLanguage = value);
              Navigator.of(sheetContext).maybePop();
            }

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋語言或代碼，例如 zh / en / ja',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: keyword.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                searchController.clear();
                                setSheetState(() => keyword = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF0E0E10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setSheetState(() => keyword = value),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: filteredLanguages.length,
                    itemBuilder: (context, index) {
                      final item = filteredLanguages[index];
                      final value = item['value'] ?? '';
                      final label = item['label'] ?? value;
                      final selected = currentLanguage == value;
                      return ListTile(
                        selected: selected,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.language_rounded,
                          color: selected
                              ? TwitchUiColors.primary
                              : Colors.white54,
                        ),
                        title: Text(label),
                        subtitle: value.isEmpty ? null : Text(value),
                        onTap: () => selectLanguage(value),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111116),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => selectLanguage(''),
                        child: const Text('全部語言'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).maybePop(),
                        child: const Text('關閉'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        searchController.dispose();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStreams();
    final filteredOffline = _filteredOfflineChannels();

    if (loadingFirstPage &&
        loadedStreams.isEmpty &&
        offlineFollowedChannels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: TwitchUiColors.primary),
      );
    }

    if (errorText != null && loadedStreams.isEmpty) {
      final message = errorText ?? '';
      final needsLogin =
          message.contains('OAuth') ||
          message.contains('登入') ||
          message.contains('授權');
      if (needsLogin) {
        return TwitchLoginRequiredView(
          statusText: '需要先完成 Twitch 登入授權，才能讀取追隨直播。',
          loading: loadingFirstPage,
          onLoginPressed: () => unawaited(widget.onLoginPressed()),
          onRetryPressed: () => unawaited(refreshStreams(clearExisting: true)),
        );
      }

      return TwitchDiscoveryEmptyState(
        icon: Icons.error_outline_rounded,
        title: '追隨直播讀取失敗',
        message: '追隨直播暫時讀取失敗，稍後再試或重新整理。',
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      );
    }

    if (loadedStreams.isEmpty &&
        offlineFollowedChannels.isEmpty &&
        !loadingOfflineChannels) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.favorite_border_rounded,
        title: '目前追隨頻道沒有直播',
        message: offlineError?.trim().isNotEmpty == true
            ? '直播清單為空，離線追隨頻道也暫時讀取失敗。'
            : '稍後重新整理，或切到瀏覽頁探索其他直播。',
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      );
    }

    if (filtered.isEmpty &&
        filteredOffline.isEmpty &&
        !loadingOfflineChannels) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.search_off_rounded,
        title: '找不到符合條件的追隨直播',
        message: '可以清除搜尋文字或語言篩選。',
      );
    }

    return RefreshIndicator(
      color: TwitchUiColors.primary,
      onRefresh: refreshStreams,
      child: TwitchDiscoveryStreamGrid(
        controller: scrollController,
        sectionIcon: Icons.favorite_rounded,
        sectionTitle: '追隨中的直播',
        streamCount: filtered.length,
        streams: filtered,
        discoveryService: widget.discoveryService,
        onReturnFromStream: refreshStreams,
        extraSliversBeforeFooter: _offlineSlivers(filteredOffline),
        footer: TwitchDiscoveryFooter(
          loadingMore: loadingMore,
          hasMore: hasMore,
          errorText: paginationError,
          onLoadMore: loadMore,
        ),
      ),
    );
  }

  List<Widget> _offlineSlivers(List<TwitchFollowedChannel> channels) {
    if (loadingOfflineChannels) {
      return const <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(26, 0, 26, 24),
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
                  '正在整理未開台的追隨頻道...',
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
      ];
    }

    if (channels.isEmpty) return const <Widget>[];

    return <Widget>[
      TwitchDiscoverySectionHeader(
        icon: Icons.video_library_rounded,
        title: '未開台追隨頻道',
        count: channels.length,
      ).asSliverBox(),
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
              discoveryService: widget.discoveryService,
            );
          }, childCount: channels.length),
        ),
      ),
    ];
  }
}

class _FollowingRefreshWindow {
  final List<TwitchLiveStream> streams;
  final String? cursor;
  final bool hasMore;

  const _FollowingRefreshWindow({
    required this.streams,
    required this.cursor,
    required this.hasMore,
  });
}

class _OfflineFollowedResult {
  final List<TwitchFollowedChannel> channels;
  final String? errorText;

  const _OfflineFollowedResult({required this.channels, this.errorText});
}

extension _SliverBoxWidget on Widget {
  Widget asSliverBox() => SliverToBoxAdapter(child: this);
}
