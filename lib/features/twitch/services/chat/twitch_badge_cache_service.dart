import '../../models/chat/twitch_chat_badge.dart';

class TwitchBadgeCacheService {
  TwitchBadgeCatalog _catalog = const TwitchBadgeCatalog();

  TwitchBadgeCatalog get catalog => _catalog;

  void updateCatalog(TwitchBadgeCatalog catalog) {
    _catalog = catalog;
  }

  TwitchChatBadge? resolveBadgeToken(String token) {
    final parts = token.split('/');
    if (parts.length != 2) return null;

    return resolveBadge(
      setId: parts[0],
      version: parts[1],
    );
  }

  TwitchChatBadge? resolveBadge({
    required String setId,
    required String version,
  }) {
    return _catalog.findBadge(
      setId: setId,
      version: version,
    );
  }

  List<TwitchChatBadge> resolveBadgeTags(String rawBadges) {
    final clean = rawBadges.trim();
    if (clean.isEmpty) return const <TwitchChatBadge>[];

    final badges = <TwitchChatBadge>[];

    for (final token in clean.split(',')) {
      final badge = resolveBadgeToken(token);
      if (badge != null) {
        badges.add(badge);
      }
    }

    return badges;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'catalog': catalog.toJson(),
    };
  }
}
