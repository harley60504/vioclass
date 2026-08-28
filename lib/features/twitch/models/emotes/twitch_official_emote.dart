enum TwitchOfficialEmoteSource { global, channel, user }

class TwitchOfficialEmote {
  final String id;
  final String name;
  final String imageUrl;
  final String emoteType;
  final String tier;
  final String emoteSetId;
  final String ownerId;
  final String ownerDisplayName;
  final List<String> formats;
  final TwitchOfficialEmoteSource source;
  final bool unlocked;

  const TwitchOfficialEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.emoteType,
    required this.tier,
    required this.emoteSetId,
    required this.ownerId,
    this.ownerDisplayName = '',
    this.formats = const <String>[],
    required this.source,
    required this.unlocked,
  });

  factory TwitchOfficialEmote.fromHelixJson(
    Map<String, dynamic> json, {
    required TwitchOfficialEmoteSource source,
    required bool unlocked,
  }) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final images = json['images'];
    final formats = _readStringList(
      json['format'],
    ).map((value) => value.toLowerCase()).toSet().toList(growable: false);

    var imageUrl = '';
    if (images is Map) {
      imageUrl =
          (images['url_2x'] ?? images['url_4x'] ?? images['url_1x'])
              ?.toString() ??
          '';
    }

    if (imageUrl.isEmpty && id.isNotEmpty) {
      imageUrl =
          'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
    }

    return TwitchOfficialEmote(
      id: id,
      name: name,
      imageUrl: imageUrl,
      emoteType: json['emote_type']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      emoteSetId: json['emote_set_id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      ownerDisplayName:
          json['owner_name']?.toString() ??
          json['owner_display_name']?.toString() ??
          json['owner_login']?.toString() ??
          '',
      formats: formats,
      source: source,
      unlocked: unlocked,
    );
  }

  TwitchOfficialEmote copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? emoteType,
    String? tier,
    String? emoteSetId,
    String? ownerId,
    String? ownerDisplayName,
    List<String>? formats,
    TwitchOfficialEmoteSource? source,
    bool? unlocked,
  }) {
    return TwitchOfficialEmote(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      emoteType: emoteType ?? this.emoteType,
      tier: tier ?? this.tier,
      emoteSetId: emoteSetId ?? this.emoteSetId,
      ownerId: ownerId ?? this.ownerId,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      formats: formats ?? this.formats,
      source: source ?? this.source,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  bool get locked => !unlocked;

  bool get supportsAnimation {
    return formats.any((format) => format.toLowerCase() == 'animated');
  }

  String officialAnimatedImageUrl({String scale = '2.0'}) {
    final cleanId = id.trim();
    if (cleanId.isEmpty || !supportsAnimation) return '';
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/animated/dark/$scale';
  }

  String officialStaticImageUrl({String scale = '2.0'}) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return imageUrl.trim();
    return 'https://static-cdn.jtvnw.net/emoticons/v2/$cleanId/static/dark/$scale';
  }

  String preferredImageUrl({bool animated = true, String scale = '2.0'}) {
    if (animated) {
      final animatedUrl = officialAnimatedImageUrl(scale: scale);
      if (animatedUrl.isNotEmpty) return animatedUrl;
    }
    final direct = imageUrl.trim();
    if (direct.isNotEmpty) return direct;
    return officialStaticImageUrl(scale: scale);
  }

  bool get isSubscriptionLike {
    final type = emoteType.toLowerCase();
    return type.contains('subscription') ||
        type.contains('subscriptions') ||
        type.contains('follower') ||
        type.contains('bitstier') ||
        type.contains('bits');
  }

  String get sourceLabel {
    switch (source) {
      case TwitchOfficialEmoteSource.global:
        return 'Twitch Global';
      case TwitchOfficialEmoteSource.channel:
        return 'Channel';
      case TwitchOfficialEmoteSource.user:
        return ownerDisplayName.trim().isNotEmpty
            ? ownerDisplayName.trim()
            : 'Unlocked';
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'emoteType': emoteType,
      'tier': tier,
      'emoteSetId': emoteSetId,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'formats': formats,
      'source': source.name,
      'unlocked': unlocked,
    };
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
