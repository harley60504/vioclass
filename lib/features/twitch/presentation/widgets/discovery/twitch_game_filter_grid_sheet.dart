import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../responsive/twitch_responsive_sheet.dart';
import '../shared/twitch_centered_text_field.dart';

Future<void> showTwitchGameFilterGridSheet({
  required BuildContext context,
  required List<TwitchGameCategory> games,
  required String? selectedGameId,
  required String? selectedGameName,
  required ValueChanged<TwitchGameCategory?> onSelected,
  bool loading = false,
  bool showRefresh = false,
  Future<void> Function()? onRefresh,
  Future<void> Function()? onLoadMore,
  bool loadingMore = false,
  bool hasMore = false,
  String? paginationError,
  String emptySearchText = '目前找不到這個分類',
}) async {
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  String keyword = '';
  StateSetter? setSheetStateRef;
  bool sheetClosed = false;

  Future<void> requestMore() async {
    if (sheetClosed || loadingMore || !hasMore) return;
    await onLoadMore?.call();
    if (!sheetClosed) setSheetStateRef?.call(() {});
  }

  Future<void> refreshSheet() async {
    if (sheetClosed) return;
    await onRefresh?.call();
    if (!sheetClosed) setSheetStateRef?.call(() {});
  }

  void handleScroll() {
    if (onLoadMore == null || !scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      unawaited(requestMore());
    }
  }

  void selectGame(BuildContext sheetContext, TwitchGameCategory? game) {
    onSelected(game);
    Navigator.of(sheetContext).maybePop();
  }

  scrollController.addListener(handleScroll);

  await showTwitchUnifiedSheet<void>(
    context: context,
    title: '遊戲分類',
    subtitle: selectedGameName == null || selectedGameName.trim().isEmpty
        ? '全部分類'
        : selectedGameName,
    icon: Icons.grid_view_rounded,
    size: TwitchUnifiedSheetSize.large,
    loading: loading,
    onRefresh: onRefresh == null ? null : refreshSheet,
    showRefresh: showRefresh && onRefresh != null,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          setSheetStateRef = setSheetState;
          final lowerKeyword = keyword.trim().toLowerCase();
          final filteredGames = lowerKeyword.isEmpty
              ? games
              : games
                    .where(
                      (game) => game.name.toLowerCase().contains(lowerKeyword),
                    )
                    .toList(growable: false);
          final items = <TwitchGameCategory?>[null, ...filteredGames];

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: TwitchCenteredTextField(
                  height: 48,
                  radius: 16,
                  controller: searchController,
                  hintText: '搜尋遊戲分類',
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => setSheetState(() => keyword = value),
                  fillColor: const Color(0xFF0E0E10),
                  borderColor: Colors.white.withValues(alpha: 0.08),
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
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (loading && games.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: TwitchUiColors.primary,
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
                              Text(
                                emptySearchText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (hasMore && onLoadMore != null) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => unawaited(requestMore()),
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
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                          itemCount:
                              items.length + (onLoadMore == null ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              return _GameFilterGridFooter(
                                loadingMore: loadingMore,
                                hasMore: hasMore,
                                paginationError: paginationError,
                                onLoadMore: requestMore,
                              );
                            }

                            final game = items[index];
                            final selected = game == null
                                ? selectedGameId == null
                                : selectedGameId == game.id;
                            return _GameFilterGridTile(
                              game: game,
                              selected: selected,
                              onTap: () => selectGame(sheetContext, game),
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
                      onPressed: () => selectGame(sheetContext, null),
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
  scrollController.removeListener(handleScroll);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      scrollController.dispose();
      searchController.dispose();
    });
  });
}

class _GameFilterGridFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasMore;
  final String? paginationError;
  final Future<void> Function() onLoadMore;

  const _GameFilterGridFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.paginationError,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: CircularProgressIndicator(color: TwitchUiColors.primary),
        ),
      );
    }

    if (paginationError != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: OutlinedButton.icon(
          onPressed: () => unawaited(onLoadMore()),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('載入分類失敗，重試'),
        ),
      );
    }

    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: TextButton.icon(
          onPressed: () => unawaited(onLoadMore()),
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
}

class _GameFilterGridTile extends StatelessWidget {
  final TwitchGameCategory? game;
  final bool selected;
  final VoidCallback onTap;

  const _GameFilterGridTile({
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
          ? TwitchUiColors.primary.withValues(alpha: 0.18)
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
                  ? TwitchUiColors.primary.withValues(alpha: 0.72)
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
                            color: TwitchUiColors.primary.withValues(
                              alpha: 0.13,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: TwitchUiColors.primary.withValues(
                                alpha: 0.20,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: TwitchUiColors.primarySoft,
                            size: 42,
                          ),
                        )
                      : _GameFilterBoxArt(game: item),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: TwitchUiColors.primarySoft,
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
                              ? TwitchUiColors.primarySoft
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

class _GameFilterBoxArt extends StatelessWidget {
  final TwitchGameCategory game;

  const _GameFilterBoxArt({required this.game});

  @override
  Widget build(BuildContext context) {
    final imageUrl = game.boxArt(width: 188, height: 250).trim();
    if (imageUrl.isEmpty) return _fallback();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        cacheWidth: 188,
        cacheHeight: 250,
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.videogame_asset_rounded,
        color: Colors.white54,
        size: 34,
      ),
    );
  }
}
