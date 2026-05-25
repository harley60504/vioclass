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
      source: source ?? this.source,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  bool get locked => !unlocked;

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
      'source': source.name,
      'unlocked': unlocked,
    };
  }
}
