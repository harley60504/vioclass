enum TwitchThirdPartyEmoteProvider {
  bttv,
  ffz,
  sevenTv,
}

class TwitchThirdPartyEmote {
  final String id;
  final String name;
  final String imageUrl;
  final TwitchThirdPartyEmoteProvider provider;
  final bool isZeroWidth;

  const TwitchThirdPartyEmote({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.provider,
    this.isZeroWidth = false,
  });

  String get providerLabel {
    switch (provider) {
      case TwitchThirdPartyEmoteProvider.bttv:
        return 'BTTV';
      case TwitchThirdPartyEmoteProvider.ffz:
        return 'FFZ';
      case TwitchThirdPartyEmoteProvider.sevenTv:
        return '7TV';
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'provider': provider.name,
      'isZeroWidth': isZeroWidth,
    };
  }
}
