/// Models and parser for Channel Points emote menus.
///
/// This parser mirrors the StreamNook boundary: the Channel Points Choose menu
/// should be built from Twitch's subscriptionProducts emote payload, not from
/// normal chat emote caches.  The parser is the only place where response-shape
/// normalization and whitelist filtering should live.
class TwitchChannelPointEmoteModification {
  final String id;
  final String modifierId;
  final String token;

  const TwitchChannelPointEmoteModification({
    required this.id,
    required this.modifierId,
    required this.token,
  });

  String get imageUrl {
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'modifierId': modifierId,
      'token': token,
      'imageUrl': imageUrl,
    };
  }
}

class TwitchChannelPointEmoteOption {
  final String id;
  final String token;
  final String emoteType;
  final List<TwitchChannelPointEmoteModification> modifications;

  const TwitchChannelPointEmoteOption({
    required this.id,
    required this.token,
    required this.emoteType,
    required this.modifications,
  });

  String get imageUrl {
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
  }

  bool get hasModifications => modifications.isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'token': token,
      'emoteType': emoteType,
      'imageUrl': imageUrl,
      'modifications': modifications.map((modification) {
        return modification.toJson();
      }).toList(growable: false),
    };
  }
}

class TwitchChannelPointsChooseMenuParseResult {
  final List<TwitchChannelPointEmoteOption> rawCandidateEmotes;
  final List<TwitchChannelPointEmoteOption> approvedEmotes;

  const TwitchChannelPointsChooseMenuParseResult({
    required this.rawCandidateEmotes,
    required this.approvedEmotes,
  });
}

class TwitchChannelPointsEmoteParser {
  const TwitchChannelPointsEmoteParser._();

  /// Parse the Choose-an-emote whitelist from a StreamNook-style
  /// subscriptionProducts response.
  ///
  /// Audit rules learned from the debug payload:
  /// - Only inspect explicit subscriptionProducts containers.
  /// - Do not recursively scan unrelated GQL siblings such as localEmoteSets.
  /// - For Choose menu, accept only Tier 1 product emotes.
  /// - For that product, accept only emotes whose setID equals product.emoteSetID.
  ///
  /// This removes animation/extra emote groups and higher-tier products that are
  /// real Twitch emotes but are not part of the Channel Points Choose menu.
  static TwitchChannelPointsChooseMenuParseResult parseChooseMenu(
    Object? raw, {
    required String channelOwnerId,
  }) {
    final rawCandidates = extractSubscriptionProductEmotes(
      raw,
      filterTier1000BaseSet: false,
    );
    final approved = dedupeChannelPointEmotes(
      extractSubscriptionProductEmotes(
        raw,
        filterTier1000BaseSet: true,
      ),
    );

    _debugMenuAudit(
      channelOwnerId: channelOwnerId,
      rawCount: rawCandidates.length,
      approvedCount: approved.length,
    );

    return TwitchChannelPointsChooseMenuParseResult(
      rawCandidateEmotes: rawCandidates,
      approvedEmotes: approved,
    );
  }

  /// Narrow StreamNook-style extraction from subscriptionProducts only.
  static List<TwitchChannelPointEmoteOption> extractSubscriptionProductEmotes(
    Object? raw, {
    required bool filterTier1000BaseSet,
  }) {
    final products = <Map<String, dynamic>>[];

    void addProductsAt(Object? root, List<String> path) {
      final list = _readList(root, path);
      for (final item in list) {
        final map = _asStringMap(item);
        if (map != null) products.add(map);
      }
    }

    addProductsAt(raw, const <String>['data', 'user', 'subscriptionProducts']);
    addProductsAt(
      raw,
      const <String>['data', 'currentUser', 'subscriptionProducts'],
    );
    addProductsAt(
      raw,
      const <String>['data', 'channel', 'subscriptionProducts'],
    );
    addProductsAt(
      raw,
      const <String>['data', 'community', 'channel', 'subscriptionProducts'],
    );
    addProductsAt(
      raw,
      const <String>['data', 'user', 'channel', 'subscriptionProducts'],
    );

    final output = <TwitchChannelPointEmoteOption>[];

    for (final product in products) {
      final productTier = _readProductTier(product);
      final productEmoteSetId = _readProductEmoteSetId(product);

      if (filterTier1000BaseSet) {
        if (productTier != '1000') continue;
        if (productEmoteSetId.isEmpty) continue;
      }

      void readEmotesFromList(List<Object?> list, {String requiredSetId = ''}) {
        for (final item in list) {
          final itemMap = _asStringMap(item);
          if (itemMap == null) continue;
          final option = _readStreamNookEmoteOption(
            itemMap,
            productTier: productTier,
            requiredSetId: requiredSetId,
          );
          if (option != null) output.add(option);
        }
      }

      readEmotesFromList(
        _readList(product, const <String>['emotes']),
        requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
      );

      final directEmoteSet = _asStringMap(product['emoteSet']);
      if (directEmoteSet != null) {
        if (!filterTier1000BaseSet ||
            _readEmoteSetId(directEmoteSet) == productEmoteSetId) {
          readEmotesFromList(
            _readList(directEmoteSet, const <String>['emotes']),
            requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
          );
        }
      }

      for (final setItem in _readList(product, const <String>['emoteSets'])) {
        final setMap = _asStringMap(setItem);
        if (setMap == null) continue;
        if (filterTier1000BaseSet && _readEmoteSetId(setMap) != productEmoteSetId) {
          continue;
        }

        readEmotesFromList(
          _readList(setMap, const <String>['emotes']),
          requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
        );
      }
    }

    return output;
  }
}

/// Backward-compatible top-level helper for code that already imports the old
/// API file and calls this function directly.
List<TwitchChannelPointEmoteOption> extractStreamNookSubscriptionProductEmotes(
  Object? raw,
) {
  return TwitchChannelPointsEmoteParser.extractSubscriptionProductEmotes(
    raw,
    filterTier1000BaseSet: true,
  );
}

List<TwitchChannelPointEmoteOption> dedupeChannelPointEmotes(
  List<TwitchChannelPointEmoteOption> emotes,
) {
  final byId = <String, TwitchChannelPointEmoteOption>{};
  for (final emote in emotes) {
    if (emote.id.trim().isEmpty || emote.token.trim().isEmpty) continue;
    final existing = byId[emote.id];
    if (existing == null ||
        existing.modifications.length < emote.modifications.length) {
      byId[emote.id] = emote;
    }
  }

  final output = byId.values.toList(growable: false);
  output.sort((a, b) => a.token.toLowerCase().compareTo(b.token.toLowerCase()));
  return output;
}

String _readProductTier(Map<String, dynamic> product) {
  final value = _firstNonEmptyString(product, const <List<String>>[
    <String>['tier'],
    <String>['subscriptionTier'],
    <String>['productTier'],
    <String>['type'],
  ]);

  return value?.trim() ?? '';
}

String _readProductEmoteSetId(Map<String, dynamic> product) {
  final value = _firstNonEmptyString(product, const <List<String>>[
    <String>['emoteSetID'],
    <String>['emoteSetId'],
    <String>['emote_set_id'],
    <String>['emoteSet', 'id'],
  ]);

  return value?.trim() ?? '';
}

String _readEmoteSetId(Map<String, dynamic> map) {
  final value = _firstNonEmptyString(map, const <List<String>>[
    <String>['setID'],
    <String>['setId'],
    <String>['emoteSetID'],
    <String>['emoteSetId'],
    <String>['emote_set_id'],
    <String>['id'],
  ]);

  return value?.trim() ?? '';
}

TwitchChannelPointEmoteOption? _readStreamNookEmoteOption(
  Map<String, dynamic> map, {
  required String productTier,
  required String requiredSetId,
}) {
  final id = _firstNonEmptyString(map, const <List<String>>[
    <String>['id'],
    <String>['emoteID'],
    <String>['emoteId'],
    <String>['emote', 'id'],
    <String>['node', 'id'],
  ]);

  final token = _firstNonEmptyString(map, const <List<String>>[
    <String>['token'],
    <String>['name'],
    <String>['displayName'],
    <String>['emote', 'token'],
    <String>['emote', 'name'],
    <String>['node', 'token'],
    <String>['node', 'name'],
  ]);

  if (id == null || id.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  if (!_looksLikeTwitchEmoteId(id)) return null;

  final emoteSetId = _readEmoteSetId(map);
  if (requiredSetId.isNotEmpty && emoteSetId != requiredSetId) {
    return null;
  }

  final emoteType = _firstNonEmptyString(map, const <List<String>>[
        <String>['type'],
        <String>['emote_type'],
        <String>['emoteType'],
        <String>['subscriptionProduct', 'tier'],
        <String>['product', 'tier'],
      ]) ??
      productTier;

  final modifications = _readStreamNookModifications(map);

  return TwitchChannelPointEmoteOption(
    id: id,
    token: token,
    emoteType: emoteType,
    modifications: modifications,
  );
}

List<TwitchChannelPointEmoteModification> _readStreamNookModifications(
  Map<String, dynamic> emote,
) {
  final output = <TwitchChannelPointEmoteModification>[];
  final seen = <String>{};

  for (final key in const <String>[
    'modifications',
    'emoteModifications',
    'availableModifications',
    'modifiers',
  ]) {
    final list = emote[key];
    if (list is! List) continue;
    for (final item in list) {
      final map = _asStringMap(item);
      if (map == null) continue;
      final modification = _readStreamNookModification(map);
      if (modification != null && seen.add(modification.id)) {
        output.add(modification);
      }
    }
  }

  output.sort((a, b) => a.token.toLowerCase().compareTo(b.token.toLowerCase()));
  return output;
}

TwitchChannelPointEmoteModification? _readStreamNookModification(
  Map<String, dynamic> map,
) {
  final id = _firstNonEmptyString(map, const <List<String>>[
    <String>['id'],
    <String>['emoteID'],
    <String>['emoteId'],
    <String>['modifiedEmoteID'],
    <String>['modifiedEmoteId'],
  ]);

  if (id == null || id.isEmpty || !_looksLikeTwitchEmoteId(id)) return null;

  final modifierId = _firstNonEmptyString(map, const <List<String>>[
        <String>['modifier_id'],
        <String>['modifierID'],
        <String>['modifierId'],
        <String>['emoteModifierID'],
        <String>['emoteModifierId'],
        <String>['modificationID'],
        <String>['modificationId'],
        <String>['type'],
      ]) ??
      '';

  final token = _firstNonEmptyString(map, const <List<String>>[
        <String>['token'],
        <String>['name'],
        <String>['displayName'],
      ]) ??
      id;

  return TwitchChannelPointEmoteModification(
    id: id,
    modifierId: modifierId,
    token: token,
  );
}

const bool _debugChannelPointEmoteMenu = false;

void _debugMenuAudit({
  required String channelOwnerId,
  required int rawCount,
  required int approvedCount,
}) {
  if (!_debugChannelPointEmoteMenu) return;

  // ignore: avoid_print
  print(
    '[ChannelPointsEmoteMenu] source=StreamNook.subscriptionProducts.tier1000.baseSet '
    'channelOwnerID=$channelOwnerId raw=$rawCount approved=$approvedCount',
  );
}

bool _looksLikeTwitchEmoteId(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  if (RegExp(r'^[0-9]+$').hasMatch(text)) return true;
  if (RegExp(r'^[0-9]+_[A-Za-z0-9]+$').hasMatch(text)) return true;
  if (RegExp(r'^emotesv2_[A-Za-z0-9]+$').hasMatch(text)) return true;
  return false;
}

String? _firstNonEmptyString(
  Object? root,
  List<List<String>> paths,
) {
  for (final path in paths) {
    final text = _readString(root, path);
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String? _readString(Object? root, List<String> path) {
  Object? current = root;
  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return null;
    current = map[key];
  }
  final text = current?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<Object?> _readList(Object? root, List<String> path) {
  Object? current = root;
  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return const <Object?>[];
    current = map[key];
  }

  if (current is List) return current.cast<Object?>();
  return const <Object?>[];
}

Map<String, dynamic>? _asStringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
