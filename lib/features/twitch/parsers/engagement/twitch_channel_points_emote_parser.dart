/// Models and parser for Channel Points emote menus.
///
/// This parser mirrors Twitch boundaries:
/// - Choose-an-emote uses Twitch subscriptionProducts.
/// - Modify-a-single-emote uses Twitch ChannelPointsContext emoteVariants.
///
/// Do not merge normal chat emote caches, global emotes, third-party emotes, or
/// lockedChannelEmotes into these Channel Points menus.
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
      'modifications': modifications
          .map((modification) {
            return modification.toJson();
          })
          .toList(growable: false),
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

  /// Parse the Choose-an-emote whitelist from a Twitch-style
  /// subscriptionProducts response.
  ///
  /// Audit rules learned from the debug payload:
  /// - Only inspect explicit subscriptionProducts containers.
  /// - Do not recursively scan unrelated GQL siblings such as localEmoteSets.
  /// - For Choose menu, accept only Tier 1 product emotes.
  /// - For that product, accept only emotes whose setID equals product.emoteSetID.
  static TwitchChannelPointsChooseMenuParseResult parseChooseMenu(
    Object? raw, {
    required String channelOwnerId,
  }) {
    final rawCandidates = extractSubscriptionProductEmotes(
      raw,
      filterTier1000BaseSet: false,
    );
    final approved = dedupeChannelPointEmotes(
      extractSubscriptionProductEmotes(raw, filterTier1000BaseSet: true),
    );

    _debugMenuAudit(
      source: 'Twitch.subscriptionProducts.tier1000.baseSet',
      channel: channelOwnerId,
      rawCount: rawCandidates.length,
      approvedCount: approved.length,
    );

    return TwitchChannelPointsChooseMenuParseResult(
      rawCandidateEmotes: rawCandidates,
      approvedEmotes: approved,
    );
  }

  /// Parse the Modify-a-single-emote source used by StreamNook.
  ///
  /// Source shape:
  /// ChannelPointsContext -> communityPointsSettings.emoteVariants[]
  /// - variant.isUnlockable must be true.
  /// - variant.emote is the base emote.
  /// - variant.modifications[].emote.id is the final modified emote id, such
  ///   as `1022569_BW`. That final id is what Twitch expects as emoteID.
  /// - StreamNook keeps the base emote when `modifications` is empty; the UI
  ///   can surface that state instead of hiding the emote entirely.
  static List<TwitchChannelPointEmoteOption> parseModifiableEmoteVariants(
    Object? raw, {
    required String channelLogin,
  }) {
    final variants = <Map<String, dynamic>>[];

    void addVariantsAt(Object? root, List<String> path) {
      final list = _readList(root, path);
      for (final item in list) {
        final map = _asStringMap(item);
        if (map != null) variants.add(map);
      }
    }

    addVariantsAt(raw, const <String>[
      'data',
      'community',
      'channel',
      'communityPointsSettings',
      'emoteVariants',
    ]);
    addVariantsAt(raw, const <String>[
      'data',
      'channel',
      'communityPointsSettings',
      'emoteVariants',
    ]);
    addVariantsAt(raw, const <String>[
      'data',
      'user',
      'channel',
      'communityPointsSettings',
      'emoteVariants',
    ]);

    final output = <TwitchChannelPointEmoteOption>[];

    for (final variant in variants) {
      final unlockable =
          _readBool(variant, const <String>['isUnlockable']) ?? false;
      if (!unlockable) continue;

      final baseEmote = _asStringMap(variant['emote']);
      if (baseEmote == null) continue;

      final base = _readEmoteOption(
        baseEmote,
        productTier: 'SUBSCRIPTION',
        requiredSetId: '',
      );
      if (base == null) continue;

      final modifications = <TwitchChannelPointEmoteModification>[];
      final seen = <String>{};
      for (final item in _readList(variant, const <String>['modifications'])) {
        final map = _asStringMap(item);
        if (map == null) continue;
        final modification = _readVariantModification(map);
        if (modification != null && seen.add(modification.id)) {
          modifications.add(modification);
        }
      }

      final effectiveModifications = modifications.isEmpty
          ? _standardModifiedEmotes(base)
          : modifications;

      effectiveModifications.sort(
        (a, b) => a.token.toLowerCase().compareTo(b.token.toLowerCase()),
      );

      output.add(
        TwitchChannelPointEmoteOption(
          id: base.id,
          token: base.token,
          emoteType: base.emoteType.isEmpty ? 'SUBSCRIPTION' : base.emoteType,
          modifications: effectiveModifications,
        ),
      );
    }

    final approved = dedupeChannelPointEmotes(output);
    _debugMenuAudit(
      source: 'Twitch.ChannelPointsContext.emoteVariants',
      channel: channelLogin,
      rawCount: variants.length,
      approvedCount: approved.length,
    );
    return approved;
  }

  /// Narrow Twitch-style extraction from subscriptionProducts only.
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
    addProductsAt(raw, const <String>[
      'data',
      'currentUser',
      'subscriptionProducts',
    ]);
    addProductsAt(raw, const <String>[
      'data',
      'channel',
      'subscriptionProducts',
    ]);
    addProductsAt(raw, const <String>[
      'data',
      'community',
      'channel',
      'subscriptionProducts',
    ]);
    addProductsAt(raw, const <String>[
      'data',
      'user',
      'channel',
      'subscriptionProducts',
    ]);

    final output = <TwitchChannelPointEmoteOption>[];

    for (final product in products) {
      final productTier = _readProductTier(product);
      final productEmoteSetId = _readProductEmoteSetId(product);

      if (filterTier1000BaseSet) {
        if (!_isTier1000(productTier)) continue;
        if (productEmoteSetId.isEmpty) continue;
      }

      void readEmotesFromList(List<Object?> list, {String requiredSetId = ''}) {
        for (final item in list) {
          final itemMap = _asStringMap(item);
          if (itemMap == null) continue;
          for (final emoteMap in _candidateEmoteMaps(itemMap)) {
            final option = _readEmoteOption(
              emoteMap,
              productTier: productTier,
              requiredSetId: requiredSetId,
            );
            if (option != null) output.add(option);
          }
        }
      }

      readEmotesFromList(
        _readList(product, const <String>['emotes']),
        requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
      );
      readEmotesFromList(
        _readList(product, const <String>['emotes', 'edges']),
        requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
      );
      readEmotesFromList(
        _readList(product, const <String>['emotes', 'nodes']),
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
          readEmotesFromList(
            _readList(directEmoteSet, const <String>['emotes', 'edges']),
            requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
          );
          readEmotesFromList(
            _readList(directEmoteSet, const <String>['emotes', 'nodes']),
            requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
          );
        }
      }

      for (final setItem in _readList(product, const <String>['emoteSets'])) {
        final setMap = _asStringMap(setItem);
        if (setMap == null) continue;
        if (filterTier1000BaseSet &&
            _readEmoteSetId(setMap) != productEmoteSetId) {
          continue;
        }

        readEmotesFromList(
          _readList(setMap, const <String>['emotes']),
          requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
        );
        readEmotesFromList(
          _readList(setMap, const <String>['emotes', 'edges']),
          requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
        );
        readEmotesFromList(
          _readList(setMap, const <String>['emotes', 'nodes']),
          requiredSetId: filterTier1000BaseSet ? productEmoteSetId : '',
        );
      }
    }

    return output;
  }
}

List<TwitchChannelPointEmoteModification> _standardModifiedEmotes(
  TwitchChannelPointEmoteOption base,
) {
  // Twitch's built-in modified emote suffixes are documented as:
  // BW grayscale, HF horizontal flip, SQ squished, SG sunglasses, TK thinking.
  return const <String>['BW', 'HF', 'SQ', 'SG', 'TK']
      .map((suffix) {
        return TwitchChannelPointEmoteModification(
          id: '${base.id}_$suffix',
          modifierId: suffix,
          token: '${base.token}_$suffix',
        );
      })
      .toList(growable: false);
}

/// Backward-compatible top-level helper for code that already imports the old
/// API file and calls this function directly.
List<TwitchChannelPointEmoteOption> extractSubscriptionProductEmotes(
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
    <String>['emoteSet', 'setID'],
    <String>['emoteSet', 'setId'],
    <String>['emoteSet', 'emoteSetID'],
    <String>['emoteSet', 'emoteSetId'],
    <String>['emoteSet', 'id'],
  ]);

  return value?.trim() ?? '';
}

bool _isTier1000(String value) {
  final text = value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  return text == '1000' || text == 'tier1' || text == 'subtier1';
}

List<Map<String, dynamic>> _candidateEmoteMaps(Map<String, dynamic> map) {
  final node = _asStringMap(map['node']);
  if (node != null) return <Map<String, dynamic>>[_mergedEmoteMap(map, node)];

  final emote = _asStringMap(map['emote']);
  if (emote != null) return <Map<String, dynamic>>[_mergedEmoteMap(map, emote)];

  return <Map<String, dynamic>>[map];
}

Map<String, dynamic> _mergedEmoteMap(
  Map<String, dynamic> outer,
  Map<String, dynamic> inner,
) {
  return <String, dynamic>{...outer, ...inner};
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

TwitchChannelPointEmoteOption? _readEmoteOption(
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

  final emoteType =
      _firstNonEmptyString(map, const <List<String>>[
        <String>['type'],
        <String>['emote_type'],
        <String>['emoteType'],
        <String>['subscriptionProduct', 'tier'],
        <String>['product', 'tier'],
      ]) ??
      productTier;

  final modifications = _readModifications(map);

  return TwitchChannelPointEmoteOption(
    id: id,
    token: token,
    emoteType: emoteType,
    modifications: modifications,
  );
}

List<TwitchChannelPointEmoteModification> _readModifications(
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
      final modification = _readModification(map);
      if (modification != null && seen.add(modification.id)) {
        output.add(modification);
      }
    }
  }

  output.sort((a, b) => a.token.toLowerCase().compareTo(b.token.toLowerCase()));
  return output;
}

TwitchChannelPointEmoteModification? _readModification(
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

  final modifierId =
      _firstNonEmptyString(map, const <List<String>>[
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

  final token =
      _firstNonEmptyString(map, const <List<String>>[
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

TwitchChannelPointEmoteModification? _readVariantModification(
  Map<String, dynamic> map,
) {
  final emote = _asStringMap(map['emote']) ?? map;
  final modifier = _asStringMap(map['modifier']);

  final id = _firstNonEmptyString(emote, const <List<String>>[
    <String>['id'],
    <String>['emoteID'],
    <String>['emoteId'],
    <String>['modifiedEmoteID'],
    <String>['modifiedEmoteId'],
  ]);
  if (id == null || id.isEmpty || !_looksLikeTwitchEmoteId(id)) return null;

  final token =
      _firstNonEmptyString(emote, const <List<String>>[
        <String>['token'],
        <String>['name'],
        <String>['displayName'],
      ]) ??
      id;

  final modifierId =
      _firstNonEmptyString(modifier, const <List<String>>[
        <String>['id'],
        <String>['modifierID'],
        <String>['modifierId'],
        <String>['type'],
      ]) ??
      _firstNonEmptyString(map, const <List<String>>[
        <String>['modifierID'],
        <String>['modifierId'],
        <String>['type'],
      ]) ??
      '';

  return TwitchChannelPointEmoteModification(
    id: id,
    modifierId: modifierId,
    token: token,
  );
}

const bool _debugChannelPointEmoteMenu = true;

void _debugMenuAudit({
  required String source,
  required String channel,
  required int rawCount,
  required int approvedCount,
}) {
  if (!_debugChannelPointEmoteMenu) return;

  // ignore: avoid_print
  print(
    '[ChannelPointsEmoteMenu] source=$source channel=$channel '
    'raw=$rawCount approved=$approvedCount',
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

String? _firstNonEmptyString(Object? root, List<List<String>> paths) {
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

bool? _readBool(Object? root, List<String> path) {
  Object? current = root;
  for (final key in path) {
    final map = _asStringMap(current);
    if (map == null) return null;
    current = map[key];
  }

  if (current is bool) return current;
  if (current == null) return null;
  final text = current.toString().trim().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return null;
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
