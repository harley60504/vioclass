typedef TwitchStreamIdentityResolver<T> = String Function(T stream);

/// Shared soft-refresh reconciliation utilities for live stream grids.
///
/// Purpose:
/// - Keep the current grid visible while a refresh request is running.
/// - After the new API window returns, replace the visible list with the latest
///   live streams in API order.
/// - Remove channels that are no longer present in the refreshed live window.
/// - Deduplicate overlapping pages by a stable stream/channel identity.
///
/// This intentionally does not fetch API data. FollowingPage and BrowsePage keep
/// their own API calls because their endpoints and query filters are different.
class TwitchStreamRefreshReconciler {
  const TwitchStreamRefreshReconciler._();

  /// Returns how many streams should be covered by a soft refresh.
  ///
  /// If the user has only loaded the first page, refresh one page. If they have
  /// scrolled farther, refresh enough pages to cover roughly the same visible
  /// window instead of shrinking the grid back to the first page.
  static int targetRefreshCount({
    required int loadedCount,
    required int pageSize,
  }) {
    if (pageSize <= 0) return loadedCount;
    if (loadedCount <= pageSize) return pageSize;

    final pages = (loadedCount / pageSize).ceil();
    return pages * pageSize;
  }

  /// Reconciles a refreshed live window into the UI list.
  ///
  /// The returned list is only based on [refreshedWindow]. This is intentional:
  /// old streams that did not appear in the latest live window are treated as
  /// offline / no longer matching current filters and are removed.
  static List<T> reconcileLatestWindow<T>({
    required List<T> refreshedWindow,
    required TwitchStreamIdentityResolver<T> identityOf,
  }) {
    if (refreshedWindow.isEmpty) return const <T>[];

    final seen = <String>{};
    final result = <T>[];

    for (final stream in refreshedWindow) {
      final identity = identityOf(stream).trim();
      if (identity.isEmpty) continue;
      if (seen.add(identity)) {
        result.add(stream);
      }
    }

    return List<T>.unmodifiable(result);
  }

  /// Appends a pagination page while avoiding duplicates already present in the
  /// loaded list.
  static List<T> appendUniquePage<T>({
    required List<T> loaded,
    required List<T> nextPage,
    required TwitchStreamIdentityResolver<T> identityOf,
  }) {
    if (loaded.isEmpty) {
      return reconcileLatestWindow(
        refreshedWindow: nextPage,
        identityOf: identityOf,
      );
    }
    if (nextPage.isEmpty) return List<T>.unmodifiable(loaded);

    final seen = loaded.map(identityOf).map((id) => id.trim()).toSet();
    final result = <T>[...loaded];

    for (final stream in nextPage) {
      final identity = identityOf(stream).trim();
      if (identity.isEmpty) continue;
      if (seen.add(identity)) {
        result.add(stream);
      }
    }

    return List<T>.unmodifiable(result);
  }
}
