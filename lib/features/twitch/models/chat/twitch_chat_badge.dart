class TwitchChatBadge {
  final String id;
  final String setId;
  final String version;
  final String title;
  final String image1x;
  final String image2x;
  final String image4x;
  final String clickAction;
  final String clickUrl;

  const TwitchChatBadge({
    required this.id,
    required this.setId,
    required this.version,
    required this.title,
    required this.image1x,
    required this.image2x,
    required this.image4x,
    required this.clickAction,
    required this.clickUrl,
  });

  factory TwitchChatBadge.fromJson(Map<String, dynamic> json) {
    return TwitchChatBadge(
      id: json['id']?.toString() ?? '',
      setId: json['setID']?.toString() ?? json['setId']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      image1x: json['image1x']?.toString() ?? '',
      image2x: json['image2x']?.toString() ?? '',
      image4x: json['image4x']?.toString() ?? '',
      clickAction: json['clickAction']?.toString() ?? '',
      clickUrl: json['clickURL']?.toString() ?? json['clickUrl']?.toString() ?? '',
    );
  }

  static List<TwitchChatBadge> listFromUnknown(Object? value) {
    if (value is! List) return const <TwitchChatBadge>[];

    return value
        .whereType<Map<String, dynamic>>()
        .map(TwitchChatBadge.fromJson)
        .where((badge) => badge.id.isNotEmpty || badge.setId.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'setId': setId,
      'version': version,
      'title': title,
      'image1x': image1x,
      'image2x': image2x,
      'image4x': image4x,
      'clickAction': clickAction,
      'clickUrl': clickUrl,
    };
  }
}

class TwitchBadgeCatalog {
  final List<TwitchChatBadge> globalBadges;
  final List<TwitchChatBadge> channelBadges;

  const TwitchBadgeCatalog({
    this.globalBadges = const <TwitchChatBadge>[],
    this.channelBadges = const <TwitchChatBadge>[],
  });

  int get totalCount => globalBadges.length + channelBadges.length;

  TwitchChatBadge? findBadge({
    required String setId,
    required String version,
  }) {
    final keySetId = setId.trim();
    final keyVersion = version.trim();

    for (final badge in channelBadges) {
      if (badge.setId == keySetId && badge.version == keyVersion) {
        return badge;
      }
    }

    for (final badge in globalBadges) {
      if (badge.setId == keySetId && badge.version == keyVersion) {
        return badge;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'globalBadgeCount': globalBadges.length,
      'channelBadgeCount': channelBadges.length,
      'totalCount': totalCount,
      'globalBadgesPreview': globalBadges.take(10).map((badge) => badge.toJson()).toList(),
      'channelBadgesPreview': channelBadges.take(10).map((badge) => badge.toJson()).toList(),
    };
  }
}
