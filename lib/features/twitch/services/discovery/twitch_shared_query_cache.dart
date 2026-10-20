/// Session-local coalescing and short-lived snapshots. Failed/obsolete requests
/// never become cache entries; no identities or credentials are persisted.
class TwitchSharedQueryCache<K, V> {
  final Duration lifetime;
  final DateTime Function() now;
  final _values = <K, (DateTime, V)>{};
  final _pending = <K, Future<V>>{};
  int _generation = 0;

  TwitchSharedQueryCache({
    this.lifetime = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  void clear() {
    _generation++;
    _values.clear();
    _pending.clear();
  }

  Future<V> read(K key, Future<V> Function() fetch) {
    final cached = _values[key];
    if (cached != null) {
      final age = now().difference(cached.$1);
      if (!age.isNegative && age < lifetime) return Future.value(cached.$2);
    }
    final existing = _pending[key];
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<V> request;
    request = Future<V>.sync(fetch)
        .then((value) {
          if (generation == _generation) {
            if (_values.length >= 128) _values.remove(_values.keys.first);
            _values[key] = (now(), value);
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], request)) _pending.remove(key);
        });
    _pending[key] = request;
    return request;
  }
}
