import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/discovery/twitch_live_stream.dart';
import '../../localization/vioclass_localizations.dart';
import '../../theme/twitch_ui_tokens.dart';
import '../responsive/twitch_responsive_sheet.dart';
import '../shared/twitch_centered_text_field.dart';

Future<void> showTwitchGameFilterGridSheet({
  required BuildContext context,
  required List<TwitchGameCategory> games,
  required String? selectedGameId,
  required String? selectedGameName,
  required ValueChanged<TwitchGameCategory?> onSelected,
  List<TwitchGameCategory> Function()? gamesProvider,
  bool Function()? loadingProvider,
  bool Function()? loadingMoreProvider,
  bool Function()? hasMoreProvider,
  String? Function()? paginationErrorProvider,
  bool loading = false,
  bool showRefresh = false,
  Future<void> Function()? onRefresh,
  Future<void> Function()? onLoadMore,
  bool loadingMore = false,
  bool hasMore = false,
  String? paginationError,
  String emptySearchText = '目前找不到這個分類',
}) async {
  final l10n = context.vio;
  final searchController = TextEditingController();
  final scrollController = ScrollController();
  String keyword = '';
  StateSetter? setSheetStateRef;
  bool sheetClosed = false;

  Future<void> requestMore() async {
    final currentLoadingMore = loadingMoreProvider?.call() ?? loadingMore;
    final currentHasMore = hasMoreProvider?.call() ?? hasMore;
    if (sheetClosed || currentLoadingMore || !currentHasMore) return;
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
    title: l10n.t('遊戲分類'),
    subtitle: selectedGameName == null || selectedGameName.trim().isEmpty
        ? l10n.t('全部分類')
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
          final currentGames = gamesProvider?.call() ?? games;
          final currentLoading = loadingProvider?.call() ?? loading;
          final currentLoadingMore = loadingMoreProvider?.call() ?? loadingMore;
          final currentHasMore = hasMoreProvider?.call() ?? hasMore;
          final currentPaginationError =
              paginationErrorProvider?.call() ?? paginationError;
          final lowerKeyword = keyword.trim().toLowerCase();
          final filteredGames = lowerKeyword.isEmpty
              ? currentGames
              : currentGames
                    .where((game) => game.name.toLowerCase().contains(lowerKeyword))
                    .toList(growable: false);
          final items = <TwitchGameCategory?>[null, ...filteredGames];

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                color: TwitchUiColors.surfacePanel,
                child: TwitchCenteredTextField(
                  height: 44,
                  radius: TwitchUiRadius.md,
                  controller: searchController,
                  hintText: l10n.t('搜尋遊戲分類'),
                  prefixIcon: Icons.search_rounded,
                  onChanged: (value) => setSheetState(() => keyword = value),
                  fillColor: TwitchUiColors.surfaceInteractive,
                  borderColor: TwitchUiColors.border,
                  suffixIcon: keyword.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();
                            setSheetState(() => keyword = '');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: TwitchUiColors.textMuted,
                          ),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (currentLoading && currentGames.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
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
                                color: TwitchUiColors.textFaint,
                                size: 40,
                              ),
                              const SizedBox(height: TwitchUiSpacing.space12),
                              Text(
                                emptySearchText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: TwitchUiColors.textSecondary,
                                  fontSize: TwitchUiFontSize.body,
                                  fontWeight: TwitchUiFontWeight.medium,
                                ),
                              ),
                              if (currentHasMore && onLoadMore != null) ...[
                                const SizedBox(height: TwitchUiSpacing.space12),
                                OutlinedButton.icon(
                                  onPressed: () => unawaited(requestMore()),
                                  icon: const Icon(Icons.download_rounded),
                                  label: Text(l10n.t('繼續載入更多分類再搜尋')),
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
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: items.length + (onLoadMore == null ? 0 : 1),
                          itemBuilder: (context, index) {
                            if (index >= items.length) {
                              return _GameFilterGridFooter(
                                loadingMore: currentLoadingMore,
                                hasMore: currentHasMore,
                                paginationError: currentPaginationError,
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
                decoration: const BoxDecoration(
                  color: TwitchUiColors.surfaceRaised,
                  border: Border(top: BorderSide(color: TwitchUiColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => selectGame(sheetContext, null),
                      child: Text(l10n.t('全部分類')),
                    ),
                    const SizedBox(width: TwitchUiSpacing.space8),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).maybePop(),
                      child: Text(l10n.t('關閉')),
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
    final l10n = context.vio;
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (paginationError != null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: OutlinedButton.icon(
          onPressed: () => unawaited(onLoadMore()),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.t('載入分類失敗，重試')),
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: TextButton.icon(
          onPressed: () => unawaited(onLoadMore()),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          label: Text(l10n.t('載入更多分類')),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          l10n.t('分類已經到底了'),
          style: const TextStyle(
            color: TwitchUiColors.textFaint,
            fontSize: TwitchUiFontSize.meta,
          ),
        ),
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
    final l10n = context.vio;
    final item = game;
    final isAllCategories = item == null;
    return Material(
      color: selected
          ? TwitchUiColors.surfaceSelected
          : TwitchUiColors.surfaceCard,
      borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwitchUiRadius.lg),
            border: Border.all(
              color: selected
                  ? TwitchUiColors.borderInteractive
                  : TwitchUiColors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: isAllCategories
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TwitchUiColors.surfaceInteractive,
                            borderRadius: BorderRadius.circular(TwitchUiRadius.md),
                            border: Border.all(color: TwitchUiColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: TwitchUiColors.primarySoft,
                            size: 38,
                          ),
                        )
                      : _GameFilterBoxArt(game: item),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                child: Row(
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: TwitchUiColors.primarySoft,
                        size: 15,
                      ),
                      const SizedBox(width: TwitchUiSpacing.space4),
                    ],
                    Expanded(
                      child: Text(
                        item?.name ?? l10n.t('全部分類'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? TwitchUiColors.primarySoft
                              : TwitchUiColors.textPrimary,
                          fontSize: TwitchUiFontSize.body,
                          height: 1.15,
                          fontWeight: TwitchUiFontWeight.strong,
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
      borderRadius: BorderRadius.circular(TwitchUiRadius.md),
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
        color: TwitchUiColors.surfaceRaised,
        borderRadius: BorderRadius.circular(TwitchUiRadius.md),
      ),
      child: const Icon(
        Icons.videogame_asset_rounded,
        color: TwitchUiColors.textFaint,
        size: 32,
      ),
    );
  }
}
