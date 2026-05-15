enum TwitchOfficialEmoteSource {
  global,
  channel,
  user,
}

class TwitchOfficialEmote {
  final String id;
  final String name;
  final String imageUrl;
  final String emoteType;
  final String tier;
  final String emoteSetId;
  final String ownerId;
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
      imageUrl = (images['url_2x'] ??
              images['url_4x'] ??
              images['url_1x'])
          ?.toString() ??
          '';
    }

    if (imageUrl.isEmpty && id.isNotEmpty) {
      imageUrl = 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0';
    }

    return TwitchOfficialEmote(
      id: id,
      name: name,
      imageUrl: imageUrl,
      emoteType: json['emote_type']?.toString() ?? '',
      tier: json['tier']?.toString() ?? '',
      emoteSetId: json['emote_set_id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      source: source,
      unlocked: unlocked,
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
        return 'Unlocked';
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
      'source': source.name,
      'unlocked': unlocked,
    };
  }
}
