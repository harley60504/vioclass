// Uses the same discovery template as FollowingPage and the actual project models/services.
// Refresh/re-enter keeps the grid visible, fetches the latest live window,
// removes offline streams, adds newly live streams, and preserves the latest
// Twitch API order through TwitchStreamRefreshReconciler.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/discovery/twitch_live_stream.dart';
import '../../services/discovery/twitch_discovery_service.dart';
import '../theme/twitch_ui_tokens.dart';
import '../widgets/discovery/twitch_game_filter_grid_sheet.dart';
import '../widgets/discovery/twitch_discovery_stream_template.dart';
import '../widgets/discovery/twitch_offline_channel_card.dart';
import '../widgets/responsive/twitch_responsive_sheet.dart';
import '../widgets/shared/twitch_login_required_view.dart';
import 'twitch_stream_refresh_reconciler.dart';

class TwitchBrowsePage extends StatefulWidget {
  final TwitchDiscoveryService discoveryService;
  final String searchText;
  final List<TwitchLiveStream> searchedLiveStreams;
  final List<TwitchFollowedChannel> searchedOfflineChannels;
  final bool loadingChannelSearch;
  final String? channelSearchError;
  final int reloadTick;
  final Future<void> Function() onLoginPressed;

  const TwitchBrowsePage({
    super.key,
    required this.discoveryService,
    required this.searchText,
    required this.searchedLiveStreams,
    required this.searchedOfflineChannels,
    required this.loadingChannelSearch,
    required this.channelSearchError,
    required this.reloadTick,
    required this.onLoginPressed,
  });

  @override
  State<TwitchBrowsePage> createState() => TwitchBrowsePageState();
}

class TwitchBrowsePageState extends State<TwitchBrowsePage> {
  static const int _browsePageSize = 100;
  static const int _tagFilterScanPageLimit = 12;

  final ScrollController scrollController = ScrollController();
  final TextEditingController tagSearchController = TextEditingController();

  List<TwitchLiveStream> loadedStreams = const <TwitchLiveStream>[];
  List<TwitchGameCategory> games = const <TwitchGameCategory>[];
  List<TwitchTagSuggestion> tagSuggestions = const <TwitchTagSuggestion>[];

  String? nextCursor;
  String? nextGameCursor;
  String? errorText;
  String? paginationError;
  String? gamePaginationError;
  String? tagSuggestionError;
  String currentLanguage = '';
  String? selectedGameId;
  String? selectedGameName;
  final List<String> selectedTags = <String>[];
  final Map<String, String> selectedTagLabels = <String, String>{};
  String tagSearchText = '';

  bool loadingFirstPage = true;
  bool loadingMore = false;
  bool hasMore = true;
  bool loadingGames = false;
  bool loadingMoreGames = false;
  bool hasMoreGames = true;
  bool loadingTagSuggestions = false;

  int _refreshGeneration = 0;
  int _tagSuggestionGeneration = 0;
  Timer? _tagSuggestionDebounce;

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
    }
  }

  @override
  void dispose() {
    _tagSuggestionDebounce?.cancel();
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    tagSearchController.dispose();
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
    collected.addAll(_applySelectedTags(page.streams));

    var cursor = page.cursor;
    var hasMorePage = page.hasMore;
    var scannedPages = 1;

    while (hasMorePage &&
        cursor != null &&
        cursor.trim().isNotEmpty &&
        collected.length < targetCount &&
        _shouldContinueScanningTags(scannedPages)) {
      page = await widget.discoveryService.fetchBrowseStreams(
        after: cursor,
        first: _browsePageSize,
        gameId: selectedGameId,
        language: currentLanguage,
      );
      collected.addAll(_applySelectedTags(page.streams));
      cursor = page.cursor;
      hasMorePage = page.hasMore;
      scannedPages++;
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
      var page = await widget.discoveryService.fetchBrowseStreams(
        after: cursor,
        first: _browsePageSize,
        gameId: selectedGameId,
        language: currentLanguage,
      );
      final matchedStreams = <TwitchLiveStream>[
        ..._applySelectedTags(page.streams),
      ];
      var nextPageCursor = page.cursor;
      var nextPageHasMore = page.hasMore;
      var scannedPages = 1;

      while (matchedStreams.length < _browsePageSize &&
          nextPageHasMore &&
          nextPageCursor != null &&
          nextPageCursor.trim().isNotEmpty &&
          _shouldContinueScanningTags(scannedPages)) {
        page = await widget.discoveryService.fetchBrowseStreams(
          after: nextPageCursor,
          first: _browsePageSize,
          gameId: selectedGameId,
          language: currentLanguage,
        );
        matchedStreams.addAll(_applySelectedTags(page.streams));
        nextPageCursor = page.cursor;
        nextPageHasMore = page.hasMore;
        scannedPages++;
      }

      final streamsWithProfiles = await _attachProfileImages(matchedStreams);
      if (!mounted) return;

      setState(() {
        loadedStreams = TwitchStreamRefreshReconciler.appendUniquePage(
          loaded: loadedStreams,
          nextPage: streamsWithProfiles,
          identityOf: _streamIdentity,
        );
        nextCursor = nextPageCursor;
        hasMore = nextPageHasMore;
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
        .where((stream) => _streamMatchesKeyword(stream, keyword))
        .toList(growable: false);
  }

  List<TwitchLiveStream> _filteredSearchLiveStreams() {
    final keyword = widget.searchText.trim().toLowerCase();
    if (keyword.isEmpty) return const <TwitchLiveStream>[];

    final existingIds = loadedStreams
        .map((stream) => stream.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingLogins = loadedStreams
        .map((stream) => stream.channelLogin)
        .where((login) => login.isNotEmpty)
        .toSet();

    return widget.searchedLiveStreams
        .where((stream) {
          final id = stream.userId.trim();
          final login = stream.channelLogin;
          if (id.isNotEmpty && existingIds.contains(id)) return false;
          if (login.isNotEmpty && existingLogins.contains(login)) return false;
          return _streamMatchesKeyword(stream, keyword);
        })
        .toList(growable: false);
  }

  List<TwitchFollowedChannel> _filteredSearchOfflineChannels() {
    final keyword = widget.searchText.trim().toLowerCase();
    if (keyword.isEmpty) return const <TwitchFollowedChannel>[];

    final existingIds = loadedStreams
        .map((stream) => stream.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingLogins = loadedStreams
        .map((stream) => stream.channelLogin)
        .where((login) => login.isNotEmpty)
        .toSet();

    return widget.searchedOfflineChannels
        .where((channel) {
          final id = channel.broadcasterId.trim();
          final login = channel.channelLogin;
          if (id.isNotEmpty && existingIds.contains(id)) return false;
          if (login.isNotEmpty && existingLogins.contains(login)) return false;

          final haystack = <String>[
            channel.broadcasterName,
            channel.broadcasterLogin,
            channel.description,
          ].join(' ').toLowerCase();
          return haystack.contains(keyword);
        })
        .toList(growable: false);
  }

  bool _streamMatchesKeyword(TwitchLiveStream stream, String keyword) {
    final haystack = <String>[
      stream.userName,
      stream.userLogin,
      stream.title,
      stream.gameName,
      stream.language,
      ...stream.tags,
    ].join(' ').toLowerCase();
    return haystack.contains(keyword);
  }

  bool _streamMatchesSelectedTags(TwitchLiveStream stream) {
    if (selectedTags.isEmpty) return true;
    final streamTags = stream.tags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    return selectedTags.every((tag) => streamTags.contains(tag.toLowerCase()));
  }

  List<TwitchLiveStream> _applySelectedTags(List<TwitchLiveStream> streams) {
    if (selectedTags.isEmpty) return streams;
    return streams.where(_streamMatchesSelectedTags).toList(growable: false);
  }

  bool _shouldContinueScanningTags(int scannedPages) {
    return selectedTags.isEmpty || scannedPages < _tagFilterScanPageLimit;
  }

  String _sectionTitle() {
    final parts = <String>['探索直播'];
    final gameName = selectedGameName?.trim();
    if (gameName != null && gameName.isNotEmpty) parts.add(gameName);
    if (selectedTags.isNotEmpty) parts.add(_selectedTagText());
    return parts.join(' · ');
  }

  String _selectedTagText() {
    return selectedTags.map((tag) => selectedTagLabels[tag] ?? tag).join('、');
  }

  void _updateTagSearchText(String value) {
    setState(() {
      tagSearchText = value;
      tagSuggestionError = null;
    });

    _tagSuggestionDebounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() {
        tagSuggestions = const <TwitchTagSuggestion>[];
        loadingTagSuggestions = false;
      });
      return;
    }

    _tagSuggestionDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_loadTagSuggestions(keyword));
    });
  }

  Future<void> _loadTagSuggestions(String keyword) async {
    final generation = ++_tagSuggestionGeneration;
    setState(() {
      loadingTagSuggestions = true;
      tagSuggestionError = null;
    });

    try {
      final suggestions = await widget.discoveryService
          .searchFreeformTagSuggestions(query: keyword, limit: 16);
      if (!mounted || generation != _tagSuggestionGeneration) return;
      setState(() {
        tagSuggestions = suggestions
            .where((tag) => !selectedTags.contains(tag.value))
            .toList(growable: false);
        loadingTagSuggestions = false;
      });
    } catch (_) {
      if (!mounted || generation != _tagSuggestionGeneration) return;
      setState(() {
        tagSuggestions = const <TwitchTagSuggestion>[];
        tagSuggestionError = '標籤建議暫時不可用';
        loadingTagSuggestions = false;
      });
    }
  }

  void _addSelectedTag(String label) {
    final cleanLabel = label.trim();
    if (cleanLabel.isEmpty) return;
    final value = cleanLabel.toLowerCase();
    _addSelectedTagValue(value: value, label: cleanLabel);
  }

  void _addSelectedTagSuggestion(TwitchTagSuggestion tag) {
    _addSelectedTagValue(value: tag.value, label: tag.label);
  }

  void _addSelectedTagValue({required String value, required String label}) {
    final cleanValue = value.trim().toLowerCase();
    final cleanLabel = label.trim();
    if (cleanValue.isEmpty || cleanLabel.isEmpty) return;
    if (selectedTags.contains(cleanValue)) {
      tagSearchController.clear();
      setState(() {
        tagSearchText = '';
        tagSuggestions = const <TwitchTagSuggestion>[];
      });
      return;
    }

    setState(() {
      selectedTags.add(cleanValue);
      selectedTagLabels[cleanValue] = cleanLabel;
      tagSearchText = '';
      tagSuggestions = const <TwitchTagSuggestion>[];
      tagSuggestionError = null;
    });
    tagSearchController.clear();
    _jumpToTop();
    unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
  }

  void _removeSelectedTag(String tag) {
    setState(() {
      selectedTags.remove(tag);
      selectedTagLabels.remove(tag);
      tagSuggestions = const <TwitchTagSuggestion>[];
      tagSuggestionError = null;
    });
    _jumpToTop();
    unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
  }

  void _clearSelectedTags() {
    if (selectedTags.isEmpty && tagSearchText.isEmpty) return;
    tagSearchController.clear();
    setState(() {
      selectedTags.clear();
      selectedTagLabels.clear();
      tagSearchText = '';
      tagSuggestions = const <TwitchTagSuggestion>[];
      tagSuggestionError = null;
    });
    _jumpToTop();
    unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
  }

  Widget _buildTagFilterSliver() {
    final hasTags = selectedTags.isNotEmpty;
    final hasTypedTag = tagSearchText.trim().isNotEmpty;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF18161F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: tagSearchController,
                textInputAction: TextInputAction.done,
                onSubmitted: _addSelectedTag,
                onChanged: _updateTagSearchText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '輸入標籤篩選',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.w800,
                  ),
                  prefixIcon: const Icon(
                    Icons.sell_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (loadingTagSuggestions)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: TwitchUiColors.primarySoft,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                      if (hasTypedTag)
                        IconButton(
                          tooltip: '加入標籤',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _addSelectedTag(tagSearchText),
                          icon: const Icon(
                            Icons.add_rounded,
                            color: TwitchUiColors.primarySoft,
                            size: 19,
                          ),
                        ),
                      if (hasTags || hasTypedTag)
                        IconButton(
                          tooltip: '清除標籤',
                          visualDensity: VisualDensity.compact,
                          onPressed: _clearSelectedTags,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            if (hasTags) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ...selectedTags.map((tag) {
                    return InputChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(selectedTagLabels[tag] ?? tag),
                      onDeleted: () => _removeSelectedTag(tag),
                      backgroundColor: TwitchUiColors.primary.withValues(
                        alpha: 0.18,
                      ),
                      deleteIconColor: Colors.white70,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      side: BorderSide(
                        color: TwitchUiColors.primarySoft.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
            if (tagSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tagSuggestions
                    .map((tag) {
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.sell_rounded, size: 14),
                        label: Text(tag.label),
                        onPressed: () => _addSelectedTagSuggestion(tag),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ] else if (tagSuggestionError != null && hasTypedTag) ...[
              const SizedBox(height: 8),
              Text(
                tagSuggestionError!,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> showGameMenu(BuildContext context) async {
    if (games.isEmpty && !loadingGames) {
      unawaited(loadGames());
    }

    await showTwitchGameFilterGridSheet(
      context: context,
      games: games,
      gamesProvider: () => games,
      selectedGameId: selectedGameId,
      selectedGameName: selectedGameName,
      loading: loadingGames,
      loadingProvider: () => loadingGames,
      onLoadMore: loadMoreGames,
      loadingMore: loadingMoreGames,
      loadingMoreProvider: () => loadingMoreGames,
      hasMore: hasMoreGames,
      hasMoreProvider: () => hasMoreGames,
      paginationError: gamePaginationError,
      paginationErrorProvider: () => gamePaginationError,
      emptySearchText: '目前已載入分類中找不到結果',
      onSelected: (game) {
        setState(() {
          selectedGameId = game?.id;
          selectedGameName = game?.name;
        });
        unawaited(refreshStreams(clearExisting: true, jumpToTop: true));
      },
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
    final filteredSearchLive = _filteredSearchLiveStreams();
    final filteredSearchOffline = _filteredSearchOfflineChannels();

    if (errorText != null && loadedStreams.isEmpty) {
      final message = errorText ?? '';
      final needsLogin =
          message.contains('OAuth') ||
          message.contains('登入') ||
          message.contains('授權');
      if (needsLogin) {
        return TwitchLoginRequiredView(
          statusText: '需要先完成 Twitch 登入授權，才能讀取探索直播。',
          loading: loadingFirstPage,
          onLoginPressed: () => unawaited(widget.onLoginPressed()),
          onRetryPressed: () => unawaited(refreshStreams(clearExisting: true)),
        );
      }

      return TwitchDiscoveryEmptyState(
        icon: Icons.error_outline_rounded,
        title: '探索直播讀取失敗',
        message: '探索直播暫時讀取失敗，稍後再試或重新整理。',
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      );
    }

    final lowerState = twitchDiscoveryLowerContentState(
      loadingInitial:
          loadingFirstPage &&
          loadedStreams.isEmpty &&
          widget.searchedLiveStreams.isEmpty &&
          widget.searchedOfflineChannels.isEmpty &&
          !widget.loadingChannelSearch,
      hasAnyLoadedContent:
          loadedStreams.isNotEmpty ||
          widget.searchedLiveStreams.isNotEmpty ||
          widget.searchedOfflineChannels.isNotEmpty,
      filteredEmpty:
          filtered.isEmpty &&
          filteredSearchLive.isEmpty &&
          filteredSearchOffline.isEmpty &&
          !widget.loadingChannelSearch,
      emptyState: TwitchDiscoveryEmptyState(
        icon: Icons.explore_off_rounded,
        title: '目前沒有可顯示直播',
        message: '可以清除分類、語言或標籤篩選後重新整理。',
        onRetry: () => unawaited(refreshStreams(clearExisting: true)),
      ),
      filteredEmptyState: TwitchDiscoveryEmptyState(
        icon: Icons.search_off_rounded,
        title: '找不到符合條件的頻道',
        message: widget.channelSearchError?.trim().isNotEmpty == true
            ? '已載入的直播沒有結果，Twitch 頻道搜尋暫時失敗。'
            : '可以清除搜尋文字、分類、語言或標籤篩選。',
      ),
      contentSlivers: _searchResultSlivers(
        liveStreams: filteredSearchLive,
        offlineChannels: filteredSearchOffline,
      ),
      footer: TwitchDiscoveryFooter(
        loadingMore: loadingMore,
        hasMore: hasMore,
        errorText: paginationError,
        onLoadMore: loadMore,
      ),
    );

    return RefreshIndicator(
      color: TwitchUiColors.primary,
      onRefresh: refreshStreams,
      child: TwitchDiscoveryStreamGrid(
        controller: scrollController,
        sectionIcon: Icons.explore_rounded,
        sectionTitle: _sectionTitle(),
        streamCount: filtered.length,
        streams: filtered,
        discoveryService: widget.discoveryService,
        onReturnFromStream: refreshStreams,
        showSectionCount: false,
        extraSliversAfterHeader: <Widget>[_buildTagFilterSliver()],
        extraSliversBeforeFooter: lowerState.slivers,
        footer: lowerState.footer,
      ),
    );
  }

  List<Widget> _searchResultSlivers({
    required List<TwitchLiveStream> liveStreams,
    required List<TwitchFollowedChannel> offlineChannels,
  }) {
    final slivers = <Widget>[];

    if (widget.loadingChannelSearch) {
      slivers.add(
        const SliverToBoxAdapter(
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
                  '正在搜尋更多頻道...',
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
      );
    }

    if (liveStreams.isNotEmpty) {
      slivers.add(
        TwitchDiscoveryStreamSliverSection(
          icon: Icons.search_rounded,
          title: '搜尋到的直播',
          streams: liveStreams,
          discoveryService: widget.discoveryService,
          onReturnFromStream: refreshStreams,
        ),
      );
    }

    if (offlineChannels.isNotEmpty) {
      slivers.addAll(
        _offlineChannelSlivers(
          icon: Icons.search_off_rounded,
          title: '搜尋到的未開台頻道',
          channels: offlineChannels,
        ),
      );
    }

    return slivers;
  }

  List<Widget> _offlineChannelSlivers({
    required IconData icon,
    required String title,
    required List<TwitchFollowedChannel> channels,
  }) {
    if (channels.isEmpty) return const <Widget>[];

    return <Widget>[
      SliverToBoxAdapter(
        child: TwitchDiscoverySectionHeader(
          icon: icon,
          title: title,
          count: channels.length,
          showCount: false,
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
              discoveryService: widget.discoveryService,
            );
          }, childCount: channels.length),
        ),
      ),
    ];
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
