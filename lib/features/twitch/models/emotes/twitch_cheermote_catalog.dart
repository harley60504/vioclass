class TwitchCheermoteCatalog {
  final Map<(String, int), (int, Map<String, String>)> _tiers;
  const TwitchCheermoteCatalog.empty() : _tiers = const {};
  TwitchCheermoteCatalog._(this._tiers);

  factory TwitchCheermoteCatalog.parse(List<dynamic> rows) {
    final tiers = <(String, int), (int, Map<String, String>)>{};
    final duplicates = <(String, int)>{};
    for (final row in rows.whereType<Map>()) {
      final prefix = row['prefix'];
      final rawTiers = row['tiers'];
      if (prefix is! String || prefix.isEmpty || rawTiers is! List) continue;
      for (final tier in rawTiers.whereType<Map>()) {
        final id = int.tryParse(tier['id']?.toString() ?? '');
        final minBits = tier['min_bits'];
        final images = tier['images'];
        if (id == null ||
            id <= 0 ||
            minBits is! int ||
            minBits <= 0 ||
            images is! Map) {
          continue;
        }
        final urls = <String, String>{};
        for (final theme in ['dark', 'light']) {
          final themed = images[theme];
          if (themed is! Map) continue;
          for (final format in ['animated', 'static']) {
            final scales = themed[format];
            if (scales is! Map) continue;
            for (final scale in ['2', '1.5', '1', '3', '4']) {
              final url = scales[scale];
              if (url is! String) continue;
              final uri = Uri.tryParse(url);
              if (uri != null &&
                  uri.scheme == 'https' &&
                  uri.userInfo.isEmpty &&
                  uri.port == 443 &&
                  const {
                    'static-cdn.jtvnw.net',
                    'd3aqoihi2n8ty8.cloudfront.net',
                  }.contains(uri.host)) {
                urls['$theme/$format'] = url;
                break;
              }
            }
          }
        }
        final key = (prefix.toLowerCase(), id);
        if (tiers.containsKey(key)) duplicates.add(key);
        tiers[key] = (minBits, Map.unmodifiable(urls));
      }
    }
    for (final key in duplicates) {
      tiers.remove(key);
    }
    return TwitchCheermoteCatalog._(Map.unmodifiable(tiers));
  }

  String? image(String prefix, int tier, int bits, {required bool dark}) {
    final urls = imageUrls(prefix, tier, bits, dark: dark);
    return urls.isEmpty ? null : urls.first;
  }

  List<String> imageUrls(
    String prefix,
    int tier,
    int bits, {
    required bool dark,
  }) {
    final entry = _tiers[(prefix.toLowerCase(), tier)];
    if (entry == null || bits < entry.$1) return const [];
    final theme = dark ? 'dark' : 'light';
    return List.unmodifiable(<String>{
      for (final format in ['animated', 'static'])
        if (entry.$2['$theme/$format'] case final String url) url,
    });
  }
}
