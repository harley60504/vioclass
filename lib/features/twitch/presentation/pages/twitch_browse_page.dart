// PATCH VERSION: twitch_browse_page_stage242_reconciler_refresh
// Uses the same discovery template as FollowingPage and the actual project models/services.
// Stage 242: refresh/re-enter keeps the grid visible, fetches the latest live
// window, removes offline streams, adds newly live streams, and preserves the
// latest Twitch API order through TwitchStreamRefreshReconciler.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../widgets/discovery/twitch_discovery_stream_template.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_login_required_view.dart';
import 'twitch_stream_refresh_reconciler.dart';

class TwitchBrowsePage extends StatefulWidget {
  final TwitchDiscoveryService discoveryService;
  final String searchText;
  final int reloadTick;
  final Future<void> Function() onLoginPressed;

  const TwitchBrowsePage({
    super.key,
    required this.discoveryService,
    required this.searchText,
    required this.reloadTick,
    required this.onLoginPressed,
  });

  @override
  State<TwitchBrowsePage> createState() => TwitchBrowsePageState();
}

class TwitchBrowsePageState extends State<TwitchBrowsePage> {
  static const int _browsePageSize = 100;

  final ScrollController scrollController = ScrollController();

  List<TwitchLiveStream> loadedStreams = const <TwitchLiveStream>[];
  List<TwitchGameCategory> games = const <TwitchGameCategory>[];

  String? nextCursor;
  String? nextGameCursor;
  String? errorText;
  String? paginationError;
  String? gamePaginationError;
  String currentLanguage = '';
  String? selectedGameId;
  String? selectedGameName;

  bool loadingFirstPage = true;
  bool loadingMore = false;
  bool hasMore = true;
  bool loadingGames = false;
  bool loadingMoreGames = false;
  bool hasMoreGames = true;

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
        {'label': 'Svenska Swedish', 'value': 'sv'},
        {'label': 'Dansk Danish', 'value': 'da'},
        {'label': 'Suomi Finnish', 'value': 'fi'},
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
      unawaited(loadGames());
    });
  }

  @override
  void didUpdateWidget(covariant TwitchBrowsePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.reloadTick != widget.reloadTick) {
      unawaited(refreshStreams());
      if (games.isEmpty) unawaited(loadGames());
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
      if (clearExisting) {
        nextCursor = null;
        hasMore = true;
        loadedStreams = const <TwitchLiveStream>[];
      }
    });

    try {
      final refreshed = await _fetchRefreshedStreamWindow(
        targetCount: TwitchStreamRefreshReconciler.targetRefreshCount(
          loadedCount: hadExistingStreams
              ? loadedStreams.length
              : _browsePageSize,
          pageSize: _browsePageSize,
        ),
      );
      if (!mounted || generation != _refreshGeneration) return;

      setState(() {
        loadedStreams = refreshed.streams;
        nextCursor = refreshed.cursor;
        hasMore = refreshed.hasMore;
        loadingFirstPage = false;
        errorText = null;
        paginationError = null;
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
      });
    }
  }

  Future<_BrowseRefreshWindow> _fetchRefreshedStreamWindow({
    required int targetCount,
  }) async {
    final collected = <TwitchLiveStream>[];

    var page = await widget.discoveryService.fetchBrowseStreams(
      first: _browsePageSize,
      gameId: selectedGameId,
      language: currentLanguage,
    );
    collected.addAll(page.streams);

    var cursor = page.cursor;
    var hasMorePage = page.hasMore;

    while (hasMorePage &&
        cursor != null &&
        cursor.trim().isNotEmpty &&
        collected.length < targetCount) {
      page = await widget.discoveryService.fetchBrowseStreams(
        after: cursor,
        first: _browsePageSize,
        gameId: selectedGameId,
        language: currentLanguage,
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

    return _BrowseRefreshWindow(
      streams: streamsWithProfiles,
      cursor: cursor,
      hasMore: hasMorePage,
    );
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
      final page = await widget.discoveryService.fetchBrowseStreams(
        after: cursor,
        first: _browsePageSize,
        gameId: selectedGameId,
        language: currentLanguage,
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

  Future<void> loadGames() async {
    if (loadingGames) return;
    setState(() {
      loadingGames = true;
      gamePaginationError = null;
      nextGameCursor = null;
      hasMoreGames = true;
    });

    try {
      final page = await widget.discoveryService.fetchTopGames(first: 100);
      if (!mounted) return;
      setState(() {
        games = page.games;
        nextGameCursor = page.cursor;
        hasMoreGames = page.hasMore;
        loadingGames = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        gamePaginationError = error.toString();
        loadingGames = false;
      });
    }
  }

  Future<void> loadMoreGames() async {
    if (loadingMoreGames || !hasMoreGames) return;
    final cursor = nextGameCursor;
    if (cursor == null || cursor.trim().isEmpty) {
      setState(() => hasMoreGames = false);
      return;
    }

    setState(() {
      loadingMoreGames = true;
      gamePaginationError = null;
    });

    try {
      final page = await widget.discoveryService.fetchTopGames(
        after: cursor,
        first: 100,
      );
      if (!mounted) return;
      final existingIds = games.map((game) => game.id).toSet();
      final uniqueNewGames = page.games
          .where((game) => !existingIds.contains(game.id))
          .toList(growable: false);
      setState(() {
        games = <TwitchGameCategory>[...games, ...uniqueNewGames];
        nextGameCursor = page.cursor;
        hasMoreGames = page.hasMore;
        loadingMoreGames = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        gamePaginationError = error.toString();
        loadingMoreGames = false;
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
    if (keyword.isEmpty) return loadedStreams;

    return loadedStreams
        .where((stream) {
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

  Future<void> showGameMenu(BuildContext context) async {
    if (games.isEmpty && !loadingGames) {
      unawaited(loadGames());
    }

    final searchController = TextEditingController();
    final sheetScrollController = ScrollController();
    String keyword = '';
    StateSetter? setSheetStateRef;
    bool sheetClosed = false;

    Future<void> requestMoreGames() async {
      if (sheetClosed || loadingMoreGames || !hasMoreGames) return;
      await loadMoreGames();
      if (!sheetClosed) setSheetStateRef?.call(() {});
    }

    Future<void> reloadGamesForSheet() async {
      if (sheetClosed) return;
      await loadGames();
      if (!sheetClosed) setSheetStateRef?.call(() {});
    }

    void handleSheetScroll() {
      if (!sheetScrollController.hasClients) return;
      final position = sheetScrollController.position;
      if (position.pixels >= position.maxScrollExtent - 320) {
        unawaited(requestMoreGames());
      }
    }

    void selectSheetGame(BuildContext sheetContext, TwitchGameCategory? game) {
      setState(() {
        selectedGameId = game?.id;
        selectedGameName = game?.name;
      });
      Navigator.of(sheetContext).maybePop();
      unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
    }

    sheetScrollController.addListener(handleSheetScroll);

    await showTwitchUnifiedSheet<void>(
      context: context,
      title: '遊戲分類',
      subtitle: selectedGameName == null || selectedGameName!.isEmpty
          ? '全部分類'
          : selectedGameName,
      icon: Icons.grid_view_rounded,
      size: TwitchUnifiedSheetSize.large,
      loading: loadingGames,
      onRefresh: reloadGamesForSheet,
      showRefresh: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            setSheetStateRef = setSheetState;
            final lowerKeyword = keyword.trim().toLowerCase();
            final filteredGames = lowerKeyword.isEmpty
                ? games
                : games
                      .where(
                        (game) =>
                            game.name.toLowerCase().contains(lowerKeyword),
                      )
                      .toList(growable: false);
            final items = <TwitchGameCategory?>[null, ...filteredGames];

            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '搜尋遊戲分類',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white70,
                        ),
                        suffixIcon: keyword.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  setSheetState(() => keyword = '');
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white54,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => keyword = value),
                    ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (loadingGames && games.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF9146FF),
                          ),
                        );
                      }

                      if (filteredGames.isEmpty && lowerKeyword.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search_off_rounded,
                                  color: Colors.white38,
                                  size: 42,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '目前已載入分類中找不到結果',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (hasMoreGames) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        unawaited(requestMoreGames()),
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('繼續載入更多分類再搜尋'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth;
                          final crossAxisCount = maxWidth >= 680
                              ? 4
                              : maxWidth >= 500
                              ? 3
                              : 2;

                          return GridView.builder(
                            controller: sheetScrollController,
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.78,
                                ),
                            itemCount: items.length + 1,
                            itemBuilder: (context, index) {
                              if (index >= items.length) {
                                return _buildGameDialogFooter(requestMoreGames);
                              }

                              final game = items[index];
                              final selected = game == null
                                  ? selectedGameId == null
                                  : selectedGameId == game.id;

                              return _GameCategoryGridTile(
                                game: game,
                                selected: selected,
                                onTap: () =>
                                    selectSheetGame(sheetContext, game),
                              );
                            },
                          );
                        },
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
                        onPressed: () => selectSheetGame(sheetContext, null),
                        child: const Text('全部分類'),
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

    sheetClosed = true;
    sheetScrollController.removeListener(handleSheetScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        sheetScrollController.dispose();
        searchController.dispose();
      });
    });
  }

  Widget _buildGameDialogFooter(Future<void> Function() requestMoreGames) {
    if (loadingMoreGames) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF9146FF)),
        ),
      );
    }

    if (gamePaginationError != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: OutlinedButton.icon(
          onPressed: () => unawaited(requestMoreGames()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('載入分類失敗，重試'),
        ),
      );
    }

    if (hasMoreGames) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: TextButton.icon(
          onPressed: () => unawaited(requestMoreGames()),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          label: const Text('載入更多分類'),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(
        child: Text('分類已經到底了', style: TextStyle(color: Colors.white38)),
      ),
    );
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
              unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
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
                              ? const Color(0xFF9146FF)
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

    if (loadingFirstPage && loadedStreams.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9146FF)),
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
          statusText: message,
          loading: loadingFirstPage,
          onLoginPressed: () => unawaited(widget.onLoginPressed()),
          onRetryPressed: () => unawaited(refreshStreams(clearExisting: true)),
        );
      }

      return TwitchDiscoveryEmptyState(
        icon: Icons.error_outline_rounded,
        title: '探索直播讀取失敗',
        message: message,
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      );
    }

    if (loadedStreams.isEmpty) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.explore_off_rounded,
        title: '目前沒有可顯示直播',
        message: '可以清除分類或語言篩選後重新整理。',
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      );
    }

    if (filtered.isEmpty) {
      return TwitchDiscoveryEmptyState(
        icon: Icons.search_off_rounded,
        title: '找不到符合條件的直播',
        message: '可以清除搜尋文字、分類或語言篩選。',
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF9146FF),
      onRefresh: refreshStreams,
      child: TwitchDiscoveryStreamGrid(
        controller: scrollController,
        sectionIcon: Icons.explore_rounded,
        sectionTitle: selectedGameName == null || selectedGameName!.isEmpty
            ? '探索直播'
            : '探索直播 · $selectedGameName',
        streamCount: filtered.length,
        streams: filtered,
        onReturnFromStream: refreshStreams,
        footer: TwitchDiscoveryFooter(
          loadingMore: loadingMore,
          hasMore: hasMore,
          errorText: paginationError,
          onLoadMore: loadMore,
        ),
      ),
    );
  }
}

class _BrowseRefreshWindow {
  final List<TwitchLiveStream> streams;
  final String? cursor;
  final bool hasMore;

  const _BrowseRefreshWindow({
    required this.streams,
    required this.cursor,
    required this.hasMore,
  });
}

class _GameCategoryGridTile extends StatelessWidget {
  final TwitchGameCategory? game;
  final bool selected;
  final VoidCallback onTap;

  const _GameCategoryGridTile({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = game;
    final isAllCategories = item == null;

    return Material(
      color: selected
          ? const Color(0xFF9146FF).withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF9146FF).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.075),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: isAllCategories
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF9146FF,
                            ).withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(
                                0xFF9146FF,
                              ).withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFFBF94FF),
                            size: 42,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            item.boxArt(width: 188, height: 250),
                            fit: BoxFit.cover,
                            cacheWidth: 188,
                            cacheHeight: 250,
                            errorBuilder: (_, _, _) {
                              return Container(
                                alignment: Alignment.center,
                                color: Colors.black26,
                                child: const Icon(
                                  Icons.videogame_asset_rounded,
                                  color: Colors.white54,
                                  size: 34,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFBF94FF),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        item?.name ?? '全部分類',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFD8BFFF)
                              : Colors.white,
                          fontSize: 13.2,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
